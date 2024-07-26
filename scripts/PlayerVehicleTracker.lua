---@class PlayerVehicleTracker
---This class keeps track of which player is above which vehicle

PlayerVehicleTracker = {}
local PlayerVehicleTracker_mt = Class(PlayerVehicleTracker)

---Creates a new object which keeps track of which player is above which vehicle
---@param mainStateMachine table @The main state machine of the mod
---@return table @The new instance
function PlayerVehicleTracker.new(mainStateMachine)
    local self = setmetatable({}, PlayerVehicleTracker_mt)
    self.mainStateMachine = mainStateMachine

    -- The current vehicle which was found by the algorithm. This is only valid temporarily
    self.lastVehicleMatch = nil
    return self
end

---Finds the first vehicle below the given location
---@param x number @the X coordinate
---@param y number @the Y coordinate
---@param z number @the Z coordinate
function PlayerVehicleTracker:updateTrackedVehicleAt(x,y,z)
    -- Find the first vehicle below the player
    self.lastVehicleMatch = nil
    local maxDistance = 5
    raycastAll(x, y + 0.05, z, 0,-1,0, "vehicleRaycastCallback", maxDistance, self, CollisionMask.VEHICLE)

    -- Update the state machine
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
    player.trackedVehicleCoords = { x = xVehicle, y = yVehicle, z = zVehicle }
end

---Force moves the player to the given location. This also stores network synchronisation values.
---@param player table @The player to be moved
---@param x number @The X coordinate of the target graphics root node position
---@param y number @The Y coordinate of the target graphics root node position
---@param z number @The Z coordinate of the target graphics root node position
function PlayerVehicleTracker:forceMovePlayer(player, x, y, z)
    setTranslation(player.rootNode, x, y + player.model.capsuleTotalHeight * 0.5, z)
    setTranslation(player.graphicsRootNode, x, y, z)
    if self.mainStateMachine.trackedVehicle then
        local xl, yl, zl = worldToLocal(self.mainStateMachine.trackedVehicle.rootNode, x, y, z)
        -- Synchronize the local coordinates to other network participants since by the time they receive the update, the global coordinates will be wrong already
        player.forceMoveVehicle = self.mainStateMachine.trackedVehicle
        player.forceMoveLocalCoords = {xl, yl, zl}
    else
        Logging.warning(MOD_NAME .. ": Player was force moved without a tracked vehicle. This should not happen.")
    end
end


---Updates internal states based on whether or not a vehicle is below that player.
---@param player table @The player to be inspected
---@param dt number @The time delta since the previous call
function PlayerVehicleTracker:checkForVehicleBelow(player, dt)

    -- Handle only the own player on each client
    if not player.isClient or player ~= g_currentMission.player then return end

    -- Check if the player is active in the game or sitting in a vehicle (or other reasons not to be "entered")
    self.mainStateMachine:onPlayerIsEnteredStateUpdated(player.isEntered)
    -- If the player is not enterd, they can by definition not be on a vehicle, so we can skip the remaining function
    if not player.isEntered then return end

    -- Find the first vehicle below the player
    local playerWorldX, playerWorldY, playerWorldZ = player:getPositionData()
    self:updateTrackedVehicleAt(playerWorldX, playerWorldY, playerWorldZ)

    -- Depending on the state, do different things:
    -- If there is no vehicle below the player, or neither player nor vehicle are moving, nothing has to be done
    -- If there is a vehicle, and only the player is moving: Update the tracked vehicle coordinates
    -- If there is a vehicle, and only the vehicle is moving: Drag the player along with the vehicle so that they stick to the tracked location on the vehicle
    -- If both are moving, add the player movement vector to the vehicle vector and move the player to that calculated location
    local state = self.mainStateMachine.state

    if self.mainStateMachine.trackedVehicle == nil then
        player.trackedVehicleCoords = nil
    elseif state == StickyFeetStateMachine.STATES.PLAYER_MOVING or player.trackedVehicleCoords == nil then
        -- Note: Tracking a vehicle without coordinates can happen when falling onto a vehicle without transitioning through PLAYER_MOVING
        self:updateTrackedLocation(player)
    end

    if player.trackedVehicleCoords ~= nil then
        local targetX,targetY,targetZ = localToWorld(self.mainStateMachine.trackedVehicle.rootNode, player.trackedVehicleCoords.x, player.trackedVehicleCoords.y, player.trackedVehicleCoords.z)

        if (state == StickyFeetStateMachine.STATES.VEHICLE_MOVING and player.trackedVehicleCoords ~= nil) then
            dbgPrint("Moving player to target location")
            -- Teleport the player
            player:moveToAbsoluteInternal(targetX,targetY + player.model.capsuleTotalHeight * 0.5,targetZ)
            -- Fix graphics node position (moveToAbsoluteInternal puts it in the same spot as the root node while it must be half a player height below that)
            setTranslation(player.graphicsRootNode, targetX, targetY, targetZ)
        end

        if state == StickyFeetStateMachine.STATES.BOTH_MOVING then
            -- Calculate the desired player movement
            local desiredSpeed = player:getDesiredSpeed()
            local dtInSeconds = dt * 0.001
            local desiredSpeedX = player.motionInformation.currentWorldDirX * desiredSpeed * dtInSeconds
            local desiredSpeedZ = player.motionInformation.currentWorldDirZ * desiredSpeed * dtInSeconds
            -- Calculate the target world coordinates
            targetX = targetX + desiredSpeedX
            targetZ = targetZ + desiredSpeedZ
            -- Find the vehicle at those coordinates in order to be able to obtain a new target Y value (in case the vehicle is moving uphill or downhill)
            self:updateTrackedVehicleAt(targetX, targetY + 0.2, targetZ)
            state = self.mainStateMachine.state
            -- Note: if that location is no longer above a vehicle, the state machine will be in a NO_VEHICLE state now
            if state == StickyFeetStateMachine.STATES.BOTH_MOVING then
                -- Remember the new tracked location
                self:updateTrackedLocation(player)
                -- Convert to new world coordinates
                targetX,targetY,targetZ = localToWorld(self.mainStateMachine.trackedVehicle.rootNode, player.trackedVehicleCoords.x, player.trackedVehicleCoords.y, player.trackedVehicleCoords.z)
            end
            -- Move the player to those coordinates (even if the state machine in NO_VEHICLE since the player could otherwise not leave the vehicle)
            setTranslation(player.rootNode, targetX, targetY + player.model.capsuleTotalHeight * 0.5, targetZ)
            setTranslation(player.graphicsRootNode, targetX, targetY, targetZ)
        end
    end

    if state == StickyFeetStateMachine.STATES.JUMPING_ABOVE_VEHICLE or state == StickyFeetStateMachine.STATES.FALLING_ABOVE_VEHICLE then
        -- Stop tracking until the player has landed (too many issues otherwise)
        player.trackedVehicleCoords = nil
    end

    -- Nothing to do in other states
end

---This is called by the game engine when an object which matches the VEHICLE collision mask was found below the player
---@param potentialVehicleId number @The ID of the object which was found
---@param x number @The world X coordinate of the match location
---@param y number @The world Y coordinate of the match location
---@param z number @The world Z coordinate of the match location
---@param distance number @The distance between the player and the match location
---@return boolean @False if the search should be stopped, true if it should be continued
function PlayerVehicleTracker:vehicleRaycastCallback(potentialVehicleId, x, y, z, distance)
    if potentialVehicleId ~= nil and potentialVehicleId ~= 0 then
        local object = g_currentMission:getNodeObject(potentialVehicleId)
        if object ~= nil and object:isa(Vehicle) then
            self.lastVehicleMatch = { object = object, x = x, y = y, z = z, distance = distance }

            -- Stop searching
            return false
        end
    end

    -- Any other case: continue searching
    return true
end

function PlayerVehicleTracker:after_player_writeUpdateStream(player, streamId, connection, dirtyMask)
    -- Send vehicle tracking data only for the own player on each client
    local forceMoveIsValid = player.forceMoveVehicle ~= nil
    if streamWriteBool(streamId, forceMoveIsValid) then
        -- Transmit the reference of the tracked vehicle to other network participants (the ID is different on every client, but NetworkUtil seems to map that for us)
        NetworkUtil.writeNodeObject(streamId, player.trackedVehicle)
        -- distribute the player position in relation to the vehicle
        streamWriteFloat32(streamId, player.forceMoveLocalCoords.x)
        streamWriteFloat32(streamId, player.forceMoveLocalCoords.y)
        streamWriteFloat32(streamId, player.forceMoveLocalCoords.z)
        -- Reset values so they don't get sent again
        player.forceMoveVehicle = nil
        player.forceMoveLocalCoords = nil
    end
end

function PlayerVehicleTracker:after_player_readUpdateStream(player, streamId, timestamp, connection)
    if streamReadBool(streamId) then
        local vehicle = NetworkUtil.readNodeObject(streamId)
        local xl = streamReadFloat32(streamId)
        local yl = streamReadFloat32(streamId)
        local zl = streamReadFloat32(streamId)

        if vehicle ~= nil and xl ~= nil and yl ~= nil and zl ~= nil then
            local x,y,z = localToWorld(vehicle.rootNode, xl, yl, zl)
            setTranslation(player.rootNode, x, y + player.model.capsuleTotalHeight * 0.5, z)
            setTranslation(player.graphicsRootNode, x, y, z)
        end
    end
end