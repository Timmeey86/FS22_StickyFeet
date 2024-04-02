---@class PlayerVehicleTracker
---This class keeps track of which player is above which vehicle

PlayerVehicleTracker = {}
local PlayerVehicleTracker_mt = Class(PlayerVehicleTracker)

---Creates a new object which keeps track of which player is above which vehicle
---@return table @The new instance
function PlayerVehicleTracker.new()
    local self = setmetatable({}, PlayerVehicleTracker_mt)

    -- The current vehicle which was found by the algorithm. This is only valid temporarily
    self.lastVehicleMatch = nil
    return self
end

---Updates internal states based on whether or not a vehicle is below that player.
---@param player table @The player to be inspected
function PlayerVehicleTracker:after_player_updateTick(player)
    if not player.isClient or player ~= g_currentMission.player then return end

    -- If the player is not active as a person in the map, e.g. because they are sitting inside a vehicle, stop tracking
    if not player.isEntered then
        if player.trackedVehicle ~= nil then
            dbgPrint(("Player ID %d is no longer tracking vehicle ID %d since player.isEntered = false"):format(player.id, player.trackedVehicle.id))
            player.trackedVehicle = nil
            player.trackedVehicleCoords = nil
        end
        return
    end

    -- Find the first vehicle below the player
    self.lastVehicleMatch = nil
    local playerWorldX, playerWorldY, playerWorldZ = player:getPositionData()
    local maxDistance = 2
    raycastAll(playerWorldX, playerWorldY, playerWorldZ, 0,-1,0, "vehicleRaycastCallback", maxDistance, self, CollisionMask.VEHICLE)

    -- Remember data about the matched location (if any)
    if self.lastVehicleMatch ~= nil then
        local isStillTheSameVehicle = player.trackedVehicle ~= nil and player.trackedVehicle.id == self.lastVehicleMatch.object.id
        if not isStillTheSameVehicle then
            dbgPrint(("Player ID %d is now tracking vehicle ID %d"):format(player.id, self.lastVehicleMatch.object.id))
        end
        -- Find the local coordinates of the vehicle at the matched location
        local xVehicle, yVehicle, zVehicle = worldToLocal(self.lastVehicleMatch.object.rootNode, self.lastVehicleMatch.x, self.lastVehicleMatch.y, self.lastVehicleMatch.z)
        player.trackedVehicle = self.lastVehicleMatch.object
        if not isStillTheSameVehicle or player.isMoving then
            -- Only update the tracking location if the player is moving or if this is the first call for this vehicle.
            -- While the player is stationary, these coordinates mustn't be changed.
            dbgPrint("Updating tracked vehicle coordinates")
            player.trackedVehicleCoords = { x = xVehicle, y = yVehicle, z = zVehicle }
        end
    else
        if player.trackedVehicle ~= nil then
            dbgPrint(("Player ID %d is no longer tracking vehicle ID %d since they are no longer on the vehicle"):format(player.id, player.trackedVehicle.id))
            player.trackedVehicle = nil
            player.trackedVehicleCoords = nil
        end
    end
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
    local isTrackingVehicle = player.trackedVehicle ~= nil and player.isClient and player == g_currentMission.player
    streamWriteBool(streamId, isTrackingVehicle)
    if isTrackingVehicle then
       NetworkUtil.writeNodeObject(streamId, player.trackedVehicle)
       streamWriteFloat32(streamId, player.trackedVehicleCoords.x)
       streamWriteFloat32(streamId, player.trackedVehicleCoords.y)
       streamWriteFloat32(streamId, player.trackedVehicleCoords.z)
    end
end

function PlayerVehicleTracker:after_player_readUpdateStream(player, streamId, timestamp, connection)
    local isTrackingVehicle = streamReadBool(streamId)
    if isTrackingVehicle then
        -- Due to when player data is being written, this can only mean this is another player or it was sent from the server
        if player == g_currentMission.player then
            Logging.warning(MOD_NAME .. ": A client received vehicle tracking data for their own player. This shouldn't have happened, so please report this to the mod author via github")
            return
        end
        local wasTracking = player.trackedVehicle ~= nil
        player.trackedVehicle = NetworkUtil.readNodeObject(streamId)
        if not wasTracking then
            dbgPrint(("Another network participant informed us that player ID %d is now tracking vehicle ID %d"):format(player.id, player.trackedVehicle.id))
        end
        player.trackedVehicleCoords = {
            x = streamReadFloat32(streamId),
            y = streamReadFloat32(streamId),
            z = streamReadFloat32(streamId)
        }
    else
        if player ~= g_currentMission.player then
            if player.trackedVehicle ~= nil then
                dbgPrint(("Another client informed us that player ID %d is no longer tracking vehicle id %d"):format(player.id, player.trackedVehicle.id))
            end
            player.trackedVehicle = nil
            player.trackedVehicleCoords = nil
        end
    end
end