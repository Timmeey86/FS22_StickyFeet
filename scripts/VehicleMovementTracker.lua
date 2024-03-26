---@class VehicleMovementTracker
---This class tracks the movement of any vehicle on the map which has a player above it

VehicleMovementTracker = {}
local VehicleMovementTracker_mt = Class(VehicleMovementTracker)

---Creates a new tracker for vehicles
---@param playerVehicleTracker table @The object which knows which player is above which vehicle
---@return table @the new instance
function VehicleMovementTracker.new(playerVehicleTracker)
    local self = setmetatable({}, VehicleMovementTracker_mt)
    self.playerVehicleTracker = playerVehicleTracker
    self.vehicleMovementData = {}
    return self
end

---Keeps track of the location and direction of any vehicle which has a player above it
---@param vehicle table @The vehicle to be potentially tracked
function VehicleMovementTracker:after_vehicle_updateTick(vehicle)
    -- Don't analyze vehicles which don't have a player above them
    if not self.playerVehicleTracker.trackedVehicles[vehicle] then
        if self.vehicleMovementData[vehicle] ~= nil then
            print(MOD_NAME .. "/VehicleMovementTracker: No longer tracking vehicle id " .. tostring(vehicle.rootNode))
            self.vehicleMovementData[vehicle] = nil
        end
        return
    end

    local currentPosition = {}
    currentPosition.x, currentPosition.y, currentPosition.z = localToWorld(vehicle.rootNode, 0, 0, 0)
    if self.vehicleMovementData[vehicle] ~= nil then
        local movementData = self.vehicleMovementData[vehicle]
        local xDiff, yDiff, zDiff =
            currentPosition.x - movementData.currentPosition.x,
            currentPosition.y - movementData.currentPosition.y,
            currentPosition.z - movementData.currentPosition.z
        movementData.currentPosition = currentPosition
        movementData.directionVector = { x = xDiff, y = yDiff, z = zDiff }
    else
        print(MOD_NAME .. "/VehicleMovementTracker: Starting to track vehicle id " .. tostring(vehicle.rootNode))
        self.vehicleMovementData[vehicle] = {
            currentPosition = currentPosition,
            directionVector = nil
        }
    end
end
