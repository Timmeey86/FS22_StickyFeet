---@class VehicleTracker
---This class finds vehicles below the player
VehicleTracker = {}

-- meta table
local VehicleTracker_mt = Class(VehicleTracker)

---Creates a new instance
---@return table @The new instance
function VehicleTracker.new()
    local self = setmetatable({}, VehicleTracker_mt)
    self.vehicleBelowPlayer = nil
    self.lockedVehicleLocalCoords = { x = 0, y = 0, z = 0 }
    self.currentVehicleLocalCoords = { x = 0, y = 0, z = 0 }
    self.lockedVehicleId = nil
    self.playerIsLocked = false
    return self
end

function VehicleTracker:findVehicleBelowPlayer(player)
    if g_currentMission.controlledVehicle ~= nil then
        self.vehicleBelowPlayer = nil
    else
        local x, y, z = player:getPositionData()

        -- Check for a vehicle below the player
        local maxDistance = 2 -- check at most 2 meters below the player
        local collisionMask = CollisionMask.VEHICLE

        self.vehicleBelowPlayer = nil
        raycastClosest(x, y, z, 0, -1, 0, "vehicleRaycastCallback", maxDistance, self, collisionMask)
    end
end

function VehicleTracker:vehicleRaycastCallback(hitObjectId, x, y, z, distance)
    if hitObjectId ~= nil then
        local object = g_currentMission:getNodeObject(hitObjectId)
        if object ~= nil and object:isa(Vehicle) then

            self.vehicleBelowPlayer = object
            self.currentVehicleLocalCoords.x, self.currentVehicleLocalCoords.y, self.currentVehicleLocalCoords.z = worldToLocal(hitObjectId, x, y, z)
            -- Stop searching
            return false
        end
    end

    -- Continue searching
    return true
end

---Makes the player ride along with the vehicle or stop doing so
function VehicleTracker:toggleVehicleSnapping()
    if self.playerIsLocked then
        -- stop riding along
        self.playerIsLocked = false
        self.lockedVehicleLocalCoords = { x = 0, y = 0, z = 0 }
        self.lockedVehicleId = 0
        print("No longer locked")
    else
        -- start riding along
        self.playerIsLocked = true
        self.lockedVehicleLocalCoords = {
            x = self.currentVehicleLocalCoords.x,
            y = self.currentVehicleLocalCoords.y,
            z = self.currentVehicleLocalCoords.z
        }
        self.lockedVehicleId = self.vehicleBelowPlayer.rootNode
        print(("Now locked: %.3f, %.3f, %.3f"):format(self.lockedVehicleLocalCoords.x, self.lockedVehicleLocalCoords.y, self.lockedVehicleLocalCoords.z))
    end
end

---Registers the "Ride along" action
function VehicleTracker:registerActionEvents()
    _, self.lockActionEventId = g_inputBinding:registerActionEvent("LOCK_ONTO_VEHICLE", self, VehicleTracker.toggleVehicleSnapping, false, true, false, true)
    g_inputBinding:setActionEventTextPriority(self.lockActionEventId, GS_PRIO_HIGH)
    g_inputBinding:setActionEventActive(self.lockActionEventId, false)
    g_inputBinding:setActionEventText(self.lockActionEventId, g_i18n:getText("input_LOCK_ONTO_VEHICLE"))
end

---Enabhles the "Ride along" action whenever there is a vehicle below the player
function VehicleTracker:updateActionEvents()
    g_inputBinding:setActionEventActive(self.lockActionEventId, self.vehicleBelowPlayer ~= nil or self.playerIsLocked)
end

---Updates the player position while the vehicle is moving and the player is locked
function VehicleTracker:updateTick(player, superFunc, ...)
    -- TODO: Detect vehicle deletion before accessing localToWorld
    local positionShallBeAdjusted = false
    if self.playerIsLocked then
        if player.inputInformation.moveForward ~= 0 or player.inputInformation.moveRight ~= 0 then
            -- player is moving, don't lock in place

            -- translate the new player position to the coordinate system of the locked vehicle and remember it
            local playerX, playerY, playerZ = localToWorld(player.rootNode, 0, 0, 0)
            self.lockedVehicleLocalCoords.x, self.lockedVehicleLocalCoords.y, self.lockedVehicleLocalCoords.z = worldToLocal(self.lockedVehicleId, playerX, playerY - player.model.capsuleTotalHeight / 2.0, playerZ)
        else
            positionShallBeAdjusted = true
        end
    end
    superFunc(player, ...)

    if positionShallBeAdjusted then
        -- player is stationary, keep player at the same spot relative to the trailer

        -- Find the world coordinates of the snapshotted local vehicle coordinates
        local worldX, worldY, worldZ = localToWorld(self.lockedVehicleId, self.lockedVehicleLocalCoords.x, self.lockedVehicleLocalCoords.y, self.lockedVehicleLocalCoords.z)
        -- Force move the player to these coordinates
        setTranslation(player.rootNode, worldX, worldY + player.model.capsuleTotalHeight / 2.0, worldZ)
    end
end