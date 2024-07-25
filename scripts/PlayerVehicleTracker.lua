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

---Updates internal states based on whether or not a vehicle is below that player.
---@param player table @The player to be inspected
function PlayerVehicleTracker:checkForVehicleBelow(player)

    -- Handle only the own player on each client
    if not player.isClient or player ~= g_currentMission.player then return end

    -- Check if the player is active in the game or sitting in a vehicle (or other reasons not to be "entered")
    self.mainStateMachine:onPlayerIsEnteredStateUpdated(player.isEntered)
    if not player.isEntered then return end
    -- TOOD maybe split INACTIVE into two states (NO_PLAYER and INACTIVE, for example)

    -- Find the first vehicle below the player
    self.lastVehicleMatch = nil
    local playerWorldX, playerWorldY, playerWorldZ = player:getPositionData()
    local maxDistance = 2
    raycastAll(playerWorldX, playerWorldY, playerWorldZ, 0,-1,0, "vehicleRaycastCallback", maxDistance, self, CollisionMask.VEHICLE)

    -- Update the state machine
    local trackedVehicle = nil
    if self.lastVehicleMatch ~= nil then
        trackedVehicle = self.lastVehicleMatch.object
    end
    self.mainStateMachine:onVehicleBelowPlayerUpdated(trackedVehicle)

    -- Depending on the state, do different things:
    -- If there is no vehicle below the player, or neither player nor vehicle are moving, nothing has to be done
    -- If there is a vehicle, and only the player is moving: Update the tracked vehicle coordinates
    -- If there is a vehicle, and only the vehicle is moving: Calculate the desired player position/movement vector based on where the tracked vehicle coordinates are now
    -- If both are moving, update the tracked vehicle coordinates, but also add the direction vector
    local state = self.mainStateMachine.state

    if state == StickyFeetStateMachine.STATES.PLAYER_MOVING then
        dbgPrint("Updating tracked vehicle coordinates")
        local xVehicle, yVehicle, zVehicle = worldToLocal(self.lastVehicleMatch.object.rootNode, self.lastVehicleMatch.x, self.lastVehicleMatch.y, self.lastVehicleMatch.z)
        player.trackedVehicleCoords = { x = xVehicle, y = yVehicle, z = zVehicle }
    end

    if (state == StickyFeetStateMachine.STATES.VEHICLE_MOVING and player.trackedVehicleCoords ~= nil) or state == StickyFeetStateMachine.STATES.BOTH_MOVING then
        dbgPrint("Moving player to target location")
        local x,y,z =
            localToWorld(self.mainStateMachine.trackedVehicle.rootNode, player.trackedVehicleCoords.x, player.trackedVehicleCoords.y + player.model.capsuleTotalHeight * 0.5, player.trackedVehicleCoords.z)
        -- Teleport the player
        player:moveToAbsoluteInternal(x,y,z)
        -- Fix grahpics node position (moveToAbsoluteInternal puts it in the same spot as the root node while it must be half a player height below that)
        setTranslation(player.graphicsRootNode, x,y - player.model.capsuleTotalHeight / 2,z)
    end

    -- TODO: In BOTH_MOVING, move the player first, then update the tracked vehicle coordinates to the new player position
    if state == StickyFeetStateMachine.STATES.BOTH_MOVING then
        print(("%.3f/%.3f/%.3f"):format(player.motionInformation.currentSpeedX, player.motionInformation.currentSpeedY, player.motionInformation.currentSpeedZ))
    end

    -- Nothing to do in IDLE or INACTIVE states
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
    --[[-- Send vehicle tracking data only for the own player on each client
    local positionNeedsToBeAdjusted = player.desiredGlobalPos ~= nil and player.trackedVehicle ~= nil and player.trackedVehicleCoords ~= nil
    streamWriteBool(streamId, positionNeedsToBeAdjusted)
    if positionNeedsToBeAdjusted then
       -- Transmit the reference of the tracked vehicle to other network participants (the ID is different on every client, but NetworkUtil seems to map that for us)
       NetworkUtil.writeNodeObject(streamId, player.trackedVehicle)
       -- distribute the player position in relation to the vehicle
       streamWriteFloat32(streamId, player.trackedVehicleCoords.x)
       streamWriteFloat32(streamId, player.trackedVehicleCoords.y)
       streamWriteFloat32(streamId, player.trackedVehicleCoords.z)
    end]]--
end

function PlayerVehicleTracker:after_player_readUpdateStream(player, streamId, timestamp, connection)
    --[[local positionNeedsToBeAdjusted = streamReadBool(streamId)
    if positionNeedsToBeAdjusted then
        -- Due to when player data is being written, this should only ever be called for other players on the client, and for all players on the dedi server
        if player == g_currentMission.player then
            Logging.warning(MOD_NAME .. ": A client received vehicle tracking data for their own player. This shouldn't have happened, so please report this to the mod author via github")
            return
        end
        player.trackedVehicle = NetworkUtil.readNodeObject(streamId)
        local trackedVehicleCoords = {
            x = streamReadFloat32(streamId),
            y = streamReadFloat32(streamId),
            z = streamReadFloat32(streamId)
        }
        player.trackedVehicleCoords = trackedVehicleCoords
        player.desiredGlobalPos = {}
        player.desiredGlobalPos.x, player.desiredGlobalPos.y, player.desiredGlobalPos.z =
            localToWorld(player.trackedVehicle.rootNode, trackedVehicleCoords.x, trackedVehicleCoords.y, trackedVehicleCoords.z)
        -- The position will be applied through PlayerLockhandler
    end]]--
end