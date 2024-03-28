---@class PlayerVehicleTracker
---This class keeps track of which player is above which vehicle

PlayerVehicleTracker = {}
local PlayerVehicleTracker_mt = Class(PlayerVehicleTracker)

---Creates a new object which keeps track of which player is above which vehicle
---@return table @The new instance
function PlayerVehicleTracker.new()
    local self = setmetatable({}, PlayerVehicleTracker_mt)
    self.playerToVehicleData = {}
    self.trackedVehicles = {}

    -- The current vehicle which was found by the algorithm. This is only valid temporarily
    self.lastVehicleMatch = nil
    return self
end

---Updates internal states based on whether or not a vehicle is below that player.
---@param player table @The player to be inspected
function PlayerVehicleTracker:after_player_updateTick(player)
    if not player.isClient or player ~= g_currentMission.player then return end

    if not player.isEntered then
        -- The player is not active as a person in the map, e.g. because they are sitting inside a vehicle
        if self.playerToVehicleData[player] ~= nil then
            -- stop tracking the vhicle
            self.trackedVehicles[self.playerToVehicleData[player].vehicle] = false
        end
        self.playerToVehicleData[player] = nil
        return
    end

    -- Find the first vehicle below the player
    self.lastVehicleMatch = nil
    local playerWorldX, playerWorldY, playerWorldZ = player:getPositionData()
    local maxDistance = 2
    raycastClosest(playerWorldX, playerWorldY, playerWorldZ, 0,-1,0, "vehicleRaycastCallback", maxDistance, self, CollisionMask.VEHICLE)

    -- Remember data about the matched location (if any)
    if self.lastVehicleMatch ~= nil then
        -- Find the local coordinates of the vehicle at the matched location
        local xVehicle, yVehicle, zVehicle = worldToLocal(self.lastVehicleMatch.object.rootNode, self.lastVehicleMatch.x, self.lastVehicleMatch.y, self.lastVehicleMatch.z)
        self.playerToVehicleData[player] = {
            vehicle = self.lastVehicleMatch.object,
            xLocal = xVehicle,
            yLocal = yVehicle,
            zLocal = zVehicle,
            distance = self.lastVehicleMatch.distance }
        self.trackedVehicles[self.lastVehicleMatch.object] = true
    else
        if self.playerToVehicleData[player] ~= nil then
            self.trackedVehicles[self.playerToVehicleData[player].vehicle] = false
        end
        self.playerToVehicleData[player] = nil
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