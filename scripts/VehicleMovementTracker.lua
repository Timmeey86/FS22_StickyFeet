---@class VehicleMovementTracker
---This class tracks the movement of any vehicle on the map

VehicleMovementTracker = {}
local VehicleMovementTracker_mt = Class(VehicleMovementTracker)

---Creates a new tracker for vehicles
---@param pathDebugger table @Used for debugging teleportation issues
---@return table @the new instance
function VehicleMovementTracker.new(pathDebugger)
    local self = setmetatable({}, VehicleMovementTracker_mt)
    self.pathDebugger = pathDebugger
    return self
end

function VehicleMovementTracker:updateVehicleData(vehicle, position, directionVector)
    vehicle.currentPosition = position
    vehicle.directionVector = directionVector
    vehicle.isMoving = math.abs(directionVector.x) > 0.001 or math.abs(directionVector.y) > 0.001 or math.abs(directionVector.z) > 0.0010
    -- Nothing else for now
    self.pathDebugger:recordVehicleUpdateCall()
    self.pathDebugger:addVehiclePos(vehicle)
end

---Keeps track of the location and direction of any vehicle
---@param vehicle table @The vehicle to be potentially tracked
function VehicleMovementTracker:after_vehicle_updateTick(vehicle)

    local currentPosition = {}
    currentPosition.x, currentPosition.y, currentPosition.z = localToWorld(vehicle.rootNode, 0, 0, 0)
    if vehicle.isClient then
        if vehicle.currentPosition ~= nil then
            -- Calculate the difference to the previous vehicle position
            local xDiff, yDiff, zDiff = currentPosition.x - vehicle.currentPosition.x, currentPosition.y - vehicle.currentPosition.y, currentPosition.z - vehicle.currentPosition.z
            -- Calculate the direction (includes speed) the vehicle is moving at
            local directionVector = { x = xDiff, y = yDiff, z = zDiff }
            self:updateVehicleData(vehicle, currentPosition, directionVector)
        else
            self:updateVehicleData(vehicle, currentPosition, { x = 0, y = 0, z = 0 })
        end
    end
end
