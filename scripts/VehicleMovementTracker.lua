---@class VehicleMovementTracker
---This class tracks the movement of any vehicle on the map

VehicleMovementTracker = {}
local VehicleMovementTracker_mt = Class(VehicleMovementTracker)

---Creates a new tracker for vehicles
---@return table @the new instance
function VehicleMovementTracker.new()
    local self = setmetatable({}, VehicleMovementTracker_mt)
    return self
end

function VehicleMovementTracker:updateVehicleData(vehicle, position, directionVector)
    vehicle.currentPosition = position
    vehicle.directionVector = directionVector
    vehicle.isMoving = math.abs(directionVector.x) > 0.001 or math.abs(directionVector.y) > 0.001 or math.abs(directionVector.z) > 0.001
    -- Nothing else for now
end

---Keeps track of the location and direction of any vehicle
---@param vehicle table @The vehicle to be potentially tracked
function VehicleMovementTracker:after_vehicle_updateTick(vehicle)

    local currentPosition = {}
    currentPosition.x, currentPosition.y, currentPosition.z = localToWorld(vehicle.rootNode, 0, 0, 0)
    if vehicle.isServer then
        if vehicle.currentPosition ~= nil then
            -- Calculate the difference to the previous vehicle position
            local xDiff, yDiff, zDiff = currentPosition.x - vehicle.currentPosition.x, currentPosition.y - vehicle.currentPosition.y, currentPosition.z - vehicle.currentPosition.z
            -- Calculate the direction (includes speed) the vehicle is moving at
            local directionVector = { x = xDiff, y = yDiff, z = zDiff }
            self:updateVehicleData(vehicle, currentPosition, directionVector)
        else
            self:updateVehicleData(vehicle, currentPosition, { x = 0, y = 0, z = 0 })
        end
    else
        -- Assumption: Client receives position from server (to be verified)
    end
end

function VehicleMovementTracker:after_vehicle_writeUpdateStream(vehicle, streamId, connection, dirtyMask)
    -- Send tracking data if data are available and we are not connected to a server (= we are the server)
    local hasTrackingData = not connection.isServer and vehicle.currentPosition ~= nil
    streamWriteBool(streamId, hasTrackingData)
    if hasTrackingData then
        streamWriteFloat32(streamId, vehicle.currentPosition.x)
        streamWriteFloat32(streamId, vehicle.currentPosition.y)
        streamWriteFloat32(streamId, vehicle.currentPosition.z)
        streamWriteFloat32(streamId, vehicle.directionVector.x)
        streamWriteFloat32(streamId, vehicle.directionVector.y)
        streamWriteFloat32(streamId, vehicle.directionVector.z)
        streamWriteBool(streamId, vehicle.isMoving)
    end
end

function VehicleMovementTracker:after_vehicle_readUpdateStream(vehicle, streamId, timestamp, connection)
    local hasTrackingData = streamReadBool(streamId)
    if hasTrackingData then
        vehicle.currentPosition = {
            x = streamReadFloat32(streamId),
            y = streamReadFloat32(streamId),
            z = streamReadFloat32(streamId)
        }
        vehicle.directionVector = {
            x = streamReadFloat32(streamId),
            y = streamReadFloat32(streamId),
            z = streamReadFloat32(streamId)
        }
        vehicle.isMoving = streamReadBool(streamId)
    else
        vehicle.isMoving = false
    end
end
