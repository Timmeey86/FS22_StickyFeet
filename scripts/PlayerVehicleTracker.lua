---This class keeps track of which player is above which vehicle
---@class PlayerVehicleTracker
---@field mainStateMachine StickyFeetStateMachine @The state machine of this mod
---@field vehicleRaycastHelper VehicleRaycastHelper @A helper class for finding vehicles below players
---@field debugVehicleDetection boolean @True if additional logging shall be turned on in case of vehicle detection
---@field lastVehicleMatch table|nil @The last vehicle which was found
---@field lastObjectMatch table|nil @The last object which was found
PlayerVehicleTracker = {}
local PlayerVehicleTracker_mt = Class(PlayerVehicleTracker)

---Creates a new object which keeps track of which player is above which vehicle
---@param mainStateMachine StickyFeetStateMachine @The main state machine of the mod
---@param vehicleRaycastHelper VehicleRaycastHelper @A helper class for finding vehicles below players
---@param debugVehicleDetection boolean @True if additional logging shall be turned on in case of vehicle detection
---@return PlayerVehicleTracker @The new instance
function PlayerVehicleTracker.new(mainStateMachine, vehicleRaycastHelper, debugVehicleDetection)
	local self = setmetatable({}, PlayerVehicleTracker_mt)
	self.mainStateMachine = mainStateMachine
	self.vehicleRaycastHelper = vehicleRaycastHelper
	self.debugVehicleDetection = debugVehicleDetection
	-- The current vehicle which was found by the algorithm. This is only valid temporarily
	self.lastVehicleMatch = nil
	self.lastObjectMatch = nil
	return self
end

---Finds the first vehicle below the given location
---@param player table @The player which might have a vehicle below them
---@param x number @the X coordinate
---@param y number @the Y coordinate
---@param z number @the Z coordinate
function PlayerVehicleTracker:updateTrackedVehicleAt(player, x,y,z)
	self.lastVehicleMatch, self.lastObjectMatch = self.vehicleRaycastHelper:getVehicleBelowPlayer(player, x,y,z)
	local trackedVehicle = nil
	if self.lastVehicleMatch ~= nil then
		trackedVehicle = self.lastVehicleMatch.object
	end
	self.mainStateMachine:onVehicleBelowPlayerUpdated(trackedVehicle)
end

---Updates the local coordinates of the vehicle which shall be tracked based on the previous vehicle match
---@param player table @The player
function PlayerVehicleTracker:updateTrackedLocation(player)
	dbgPrint("Updating tracked vehicle coordinates")
	local xVehicle, yVehicle, zVehicle = worldToLocal(self.lastVehicleMatch.object.rootNode, self.lastVehicleMatch.x, self.lastVehicleMatch.y, self.lastVehicleMatch.z)
	if self.lastObjectMatch ~= nil then
		-- An object is between the player and the trailer. Use the top Y coordinate of that object instead of the trailer
		local _, yObject, _ = worldToLocal(self.lastVehicleMatch.object.rootNode, self.lastObjectMatch.x, self.lastObjectMatch.y, self.lastObjectMatch.z)
		if yObject > yVehicle then
			-- Object is above the vehicle. Use the Y coordinate of the object
			yVehicle = yObject
		end
	end
	player.trackedVehicleCoords = { x = xVehicle, y = yVehicle, z = zVehicle }
	dbgPrint(("Tracked vehicle local coordinates are %.3f/%.3f/%.3f"):format(xVehicle, yVehicle, zVehicle))
	dbgPrint(("Tracked vehicle global coordinates are %.3f/%.3f/%.3f"):format(self.lastVehicleMatch.x, self.lastVehicleMatch.y, self.lastVehicleMatch.z))
end

---Applies a prepared player move. This is a non-member function so it can be called from events, too
---@param player table @The player to be moved
---@param x number @The X coordinate of the target graphics root node position
---@param y number @The Y coordinate of the target graphics root node position
---@param z number @The Z coordinate of the target graphics root node position
function PlayerVehicleTracker.applyMove(player, x, y, z)
	player.mover:setPosition(x, y, z, true)
end

---Sends an event to the server, or broadcasts it when hosting a multiplayer game
---@param player table @The player (should be the controlled player)
---@param event table @The event to be sent
function PlayerVehicleTracker.sendOrBroadcastEvent(player, event)
	if g_server ~= nil then
		-- We are either the host of a multiplayer game or in single player
		-- g_server is also valid on a dedicated server, but the state machine won't be used there
		-- Note: In single player, broadcastEvent will do nothing
		g_server:broadcastEvent(event, nil, nil, player)
	else
		-- We are a client of either a hosted multiplayer game or a dedicated server. Send the event to the server
		g_client:getServerConnection():sendEvent(event)
	end
end

---Force moves the player to the given location. This also stores network synchronisation values.
---@param player table @The player to be moved
---@param x number @The X coordinate of the target graphics root node position
---@param y number @The Y coordinate of the target graphics root node position
---@param z number @The Z coordinate of the target graphics root node position
function PlayerVehicleTracker:forceMovePlayer(player, x, y, z)
	dbgPrint("Force moving player")
	if self.debugVehicleDetection then
		local vehicleId = nil
		if self.mainStateMachine.trackedVehicle ~= nil then
			vehicleId = self.mainStateMachine.trackedVehicle.id
		end
		print(("%s: Moving player to %.3f/%.3f/%.3f. Tracked vehicle: %s"):format(MOD_NAME, x, y, z, tostring(vehicleId)))
	end

	PlayerVehicleTracker.applyMove(player, x, y, z)
	player.wasForceMoved = true

	assert(player == g_localPlayer)
	-- Synchronize coords to other network participants
	local event
	if self.mainStateMachine.trackedVehicle ~= nil then
		-- Player is in a state which has a vehicle
		local xl, yl, zl = worldToLocal(self.mainStateMachine.trackedVehicle.rootNode, x, y, z)
		event = PlayerMovementCorrectionEvent.fromVehicleCoords(player, self.mainStateMachine.trackedVehicle, { x = xl, y = yl, z = zl }, player.mover.currentSpeed)
	else
		-- Player is not tracking a vehicle, but the position is being corrected anyway (maybe jumping off, or similar)
		event = PlayerMovementCorrectionEvent.fromGlobalCoords(player, { x = x, y = y, z = z }, player.mover.currentSpeed)
	end
	PlayerVehicleTracker.sendOrBroadcastEvent(player, event)
end

---Updates the model of another multiplayer participant on each client, if necessary
---@param player table @The player to be udpated
function PlayerVehicleTracker.updateRemotePlayerModel(player)
	-- Note: The additional check for the root node is required since it can be nil while the player is still connecting
	if player.syncedLockCoords ~= nil and (player.syncedCoordsAreGlobalCoords or (player.syncedLockVehicle ~= nil and player.syncedLockVehicle.rootNode ~= nil)) then
		assert(player ~= g_localPlayer)
		local x, y, z = player.syncedLockCoords.x, player.syncedLockCoords.y, player.syncedLockCoords.z
		if not player.syncedCoordsAreGlobalCoords then
			-- Convert to global coords based on the position of the tracked vehicle
			x, y, z = localToWorld(player.syncedLockVehicle.rootNode, x, y, z)
		end
		PlayerVehicleTracker.applyMove(player, x, y, z)
		-- Flag the player object as dirty again so it keeps updating this player on our local client as long as they are locked to the vehicle.
		-- That way, we get can use the lock coordinates to move the player ourselves, which results in a way smoother player movement than reacting only to server update ticks.
		player:raiseActive()
	end
end

-- Prevent the server from sending outdated positioning data while a player is being locked.
-- Also prevent it while the local player is being force moved by this mod.
-- This method will only toggle a boolean flag, however
function PlayerVehicleTracker:blockNetworkMovementIfNecessary(component, superFunc, streamId, connection, timestamp)
	component.player.blockMover = component.player.syncedLockCoords ~= nil or (component.player == g_localPlayer and self.mainStateMachine:playerIsDraggedByVehicle())
	superFunc(component, streamId, connection, timestamp)
	component.player.blockMover = false
end

-- Block a player position update if necessary
PlayerMover.setPosition = Utils.overwrittenFunction(PlayerMover.setPosition, function(mover, superFunc, ...)
	if not mover.player.blockMover then
		superFunc(mover, ...)
	end
end)

---Updates internal states based on whether or not a vehicle is below that player.
---@param player table @The player to be inspected
---@param dt number @The time delta since the previous call
function PlayerVehicleTracker:checkForVehicleBelow(player, dt)

	-- Other players: Just move them along with the vehicle as long as that's possible
	PlayerVehicleTracker.updateRemotePlayerModel(player)

	-- Otherwise only handle the local client player
	if not player.isClient or player ~= g_localPlayer then return end

	-- Check if the player is active in the game or sitting in a vehicle (or other reasons not to be "entered")
	local isInVehicle = player:getIsInVehicle()
	self.mainStateMachine:onPlayerIsInVehicleStateUpdated(isInVehicle)
	-- The player can't be on a vehicle if they're in a vehicle => skip the remaining code
	if isInVehicle then return end

	-- Find the first vehicle below the player
	local previousVehicle = self.mainStateMachine.trackedVehicle
	local playerWorldX, playerWorldY, playerWorldZ = player:getPosition()
	if (self.mainStateMachine.state == StickyFeetStateMachine.STATES.VEHICLE_MOVING or
	   self.mainStateMachine.state == StickyFeetStateMachine.STATES.BOTH_MOVING or
	   self.mainStateMachine.state == StickyFeetStateMachine.STATES.JUMPING_ABOVE_VEHICLE or
	   self.mainStateMachine.state == StickyFeetStateMachine.STATES.FALLING_ABOVE_VEHICLE) and
	   self.mainStateMachine.trackedVehicle ~= nil and player.trackedVehicleCoords ~= nil then

		-- If the state machine is in a state where the player needs to be dragged along:
		-- The vehicle will have moved already, but not the player => Find out where the player would be moved, and check which vehicle is at that location.
		-- Otherwise the player could jump up and down while running towards the edge of a pallet on a trailer, for example
		dbgPrint("Adjusting vehicle search location")
		playerWorldX, playerWorldY, playerWorldZ = localToWorld(self.mainStateMachine.trackedVehicle.rootNode, player.trackedVehicleCoords.x, player.trackedVehicleCoords.y, player.trackedVehicleCoords.z)
	end
	dbgPrint(("Updating tracked vehicle in :checkForVehicleBelow (default case) based on player pos %.3f/%.3f/%.3f"):format(playerWorldX, playerWorldY, playerWorldZ))
	self:updateTrackedVehicleAt(player, playerWorldX, playerWorldY, playerWorldZ)

	-- Depending on the state, do different things:
	-- If there is no vehicle below the player, or neither player nor vehicle are moving, nothing has to be done
	-- If there is a vehicle, and only the player is moving: Update the tracked vehicle coordinates
	-- If there is a vehicle, and only the vehicle is moving: Drag the player along with the vehicle so that they stick to the tracked location on the vehicle
	-- If both are moving, add the player movement vector to the vehicle vector and move the player to that calculated location
	local state = self.mainStateMachine.state
	local playerWasForceMovedBefore = player.wasForceMoved
	player.wasForceMoved = false

	if self.mainStateMachine.trackedVehicle == nil then
		player.trackedVehicleCoords = nil
	elseif state == StickyFeetStateMachine.STATES.PLAYER_MOVING
		or state == StickyFeetStateMachine.STATES.JUMPING_ONTO_VEHICLE
		or (previousVehicle ~= nil and self.mainStateMachine.trackedVehicle ~= previousVehicle)
		or (state == StickyFeetStateMachine.STATES.IDLE_ON_VEHICLE and self.mainStateMachine.previousState == StickyFeetStateMachine.STATES.PLAYER_MOVING)
		or (state == StickyFeetStateMachine.STATES.VEHICLE_MOVING and player.trackedVehicleCoords == nil)
		then

		dbgPrint("Updating tracked vehicle coordinates since player is moving above a vehicle in some way (or because the vehicle changed)")

		-- Always update the tracked location if the player is moving in any way (and for one update after stopping, so we get the position they are stopped at)
		self:updateTrackedLocation(player)
	end

	local vehicle = self.mainStateMachine.trackedVehicle
	if player.trackedVehicleCoords ~= nil and vehicle ~= nil
		and state ~= StickyFeetStateMachine.STATES.JUMPING_FROM_MOVING_VEHICLE
		and state ~= StickyFeetStateMachine.STATES.JUMPING_ONTO_VEHICLE then

		local targetX,targetY,targetZ = localToWorld(vehicle.rootNode, player.trackedVehicleCoords.x, player.trackedVehicleCoords.y, player.trackedVehicleCoords.z)
		dbgPrint(("Current target coordinates are %.3f/%.3f/%.3f based on vehicle ID %d"):format(targetX, targetY, targetZ, vehicle.id))

		if (state == StickyFeetStateMachine.STATES.VEHICLE_MOVING and player.trackedVehicleCoords ~= nil) then
			dbgPrint("Moving player to target location")
			self:forceMovePlayer(player, targetX, targetY, targetZ)

			-- Rotate the player around the Y axis by the same amount the vehicle has rotated
			local dirX, _, dirZ = localDirectionToWorld(vehicle.rootNode, 0, 0, 1)
			local newRotation = MathUtil.getYRotationFromDirection(dirX, dirZ)
			if vehicle.previousRotation ~= nil then
				local rotationDiff = newRotation - vehicle.previousRotation
				-- Rotate the player model
				player.mover.movementDirectionYaw = player.mover.movementDirectionYaw + rotationDiff
				-- Rotate the first/third person camera (looks like that's the same node)
				local yawNode = player.camera.yawNode
				local rotationX, rotationY, rotationZ = getRotation(yawNode)
				setRotation(yawNode, rotationX, rotationY + rotationDiff, rotationZ)
			end
			vehicle.previousRotation = newRotation
		end

		-- If the vehicle is moving and the player is either moving, jumping up or falling down above a moving vehicle
		if self.mainStateMachine:playerIsMovingAboveMovingVehicle() then
			dbgPrint("Player is moving above vehicle - adding player vector to target coordinates")
			-- Calculate the target world coordinates
			local deltaX = player.mover.positionDeltaX
			local deltaY = player.mover.positionDeltaY
			local deltaZ = player.mover.positionDeltaZ
			targetX = targetX + deltaX
			targetY = targetY + deltaY
			targetZ = targetZ + deltaZ
			dbgPrint(("New target coordinates are %.3f/%.3f/%.3f based on vehicle ID %d"):format(targetX, targetY, targetZ, vehicle.id))
			-- Find the vehicle at those coordinates to check wether or not the location is still on the vehicle
			dbgPrint("Updating tracked vehicle in :checkForVehicleBelow ('player is moving' case)")
			self:updateTrackedVehicleAt(player, targetX, targetY, targetZ)
			state = self.mainStateMachine.state
			vehicle = self.mainStateMachine.trackedVehicle
			-- Note: if that location is no longer above a vehicle, the state machine will be in a NO_VEHICLE state now
			if self.mainStateMachine:playerIsMovingAboveMovingVehicle() and vehicle ~= nil then
				dbgPrint("Target location is still above vehicle. Updating tracked vehicle coordinates")
				-- Remember the new tracked location
				self:updateTrackedLocation(player)
				-- Retrieve target world coordinates
				targetX,targetY,targetZ = localToWorld(vehicle.rootNode, player.trackedVehicleCoords.x, player.trackedVehicleCoords.y, player.trackedVehicleCoords.z)
				dbgPrint(("Final target coordinates are %.3f/%.3f/%.3f based on vehicle ID %d"):format(targetX, targetY, targetZ, vehicle.id))
				-- Adjust for jumping or falling
				if state == StickyFeetStateMachine.STATES.JUMPING_ABOVE_VEHICLE or state == StickyFeetStateMachine.STATES.FALLING_ABOVE_VEHICLE then
					local adjustedYCoordinate = targetY + player.mover.currentVelocityY * dt * 0.001
					if adjustedYCoordinate > targetY then
						-- TODO Only seems to work for a single frame, then the upwards speed gets cancelled
						targetY = adjustedYCoordinate
					elseif state == StickyFeetStateMachine.STATES.FALLING_ABOVE_VEHICLE then
						-- the player is still considered falling, but they landed on the trailer or something else 
						-- => we need to convince the game engine that the player is in fact no longer falling
						print("TODO: Stop falling motion")
					end
				end
			else
				dbgPrint("Target location is no longer above vehicle")
				-- Keep Y coordinate so the next force move does not force the player down on the trailer again
				-- This is required only once since the state machine will prevent further position manipulations from happening
				local _, graphicsY, _ = localToWorld(player.capsuleController.rootNode, 0, 0, 0)
				targetY = graphicsY
			end
			dbgPrint("Moving player to target location")
			-- Apply an appropriate movement velocity relative to the vehicle
			self:forceMovePlayer(player, targetX, targetY, targetZ)
		end
	end

	-- Nothing to do in other states

	if playerWasForceMovedBefore and not player.wasForceMoved then
		-- If there are other network participants, they need to be told to stop correcting the player position (especially the server)
		PlayerVehicleTracker.sendOrBroadcastEvent(player, PlayerMovementCorrectionStopEvent.new(player))
	end
end

---Overrides the animation velocity especially for other players in order to prevent them from looking as if they were running on the spot
---@param graphicsState PlayerGraphicsState @The graphics state to be changed
---@param player Player @The affected player
function PlayerVehicleTracker:adjustAnimationParameters(graphicsState, player)
	if player.syncedForwardVelocity ~= nil then
		-- TODO: Remote players are still lagging behind
		player.lastEstimatedForwardVelocity = syncedForwardVelocity
		graphicsState.relativeVelocityX = 0
		graphicsState.relativeVelocityZ = 0
		graphicsState.absSpeed = 0
	end
end