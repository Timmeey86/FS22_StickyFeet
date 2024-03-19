---@class VehicleFinder
---This class finds vehicles below the player
VehicleFinder = {}

-- meta table
local VehicleFinder_mt = Class(VehicleFinder)

---Creates a new instance
---@return table @The new instance
function VehicleFinder.new()
    local self = setmetatable({}, VehicleFinder_mt)
    self.currentVehicle = nil
    return self
end

function VehicleFinder:findVehicleBelowPlayer(player)
    if g_currentMission.controlledVehicle ~= nil then
        self.currentVehicle = nil
    else
        local x, y, z = player:getPositionData()

        -- Check for a vehicle below the player
        local maxDistance = 2 -- check at most 2 meters below the player
        local collisionMask = CollisionMask.VEHICLE
        raycastClosest(x, y, z, 0, -1, 0, "vehicleRaycastCallback", maxDistance, self, collisionMask)

        if self.currentVehicle ~= nil then
            print(self.currentVehicle.typeName)
        end
    end
end

function VehicleFinder:vehicleRaycastCallback(hitObjectId, x, y, z, distance)
    if hitObjectId ~= nil then
        local object = g_currentMission:getNodeObject(hitObjectId)
        if object ~= nil and object:isa(Vehicle) then
            self.currentVehicle = object
            -- Stop searching
            return false
        end
    end

    -- Continue searching
    return true
end


-- Delay method registration as otherwise mods which override but don't call superFunc would break our mod
-- If you use this approach in your own mod, please don't override anything without calling superFunc
Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, function(...)
    g_currentMission.vehicleFinder = VehicleFinder.new()
    Player.update = Utils.appendedFunction(Player.update, function(player, ...) g_currentMission.vehicleFinder:findVehicleBelowPlayer(player) end)
end)