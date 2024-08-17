---@class VehicleRaycastHelper
---This class is responsible for finding the vehicle below the player
VehicleRaycastHelper = {}
local VehicleRaycastHelper_mt = Class(VehicleRaycastHelper)

---Creates a new vehicle raycast helper
---@param debugVehicleDetection boolean @True if vehicle detection shall be debugged
---@return table @The new instance
function VehicleRaycastHelper.new(debugVehicleDetection)
    local self = setmetatable({}, VehicleRaycastHelper_mt)
    self.debugVehicleDetection = debugVehicleDetection
    return self
end

---Finds the first vehicle below the given location
---@param player table @The player instance
---@param x number @the X coordinate
---@param y number @the Y coordinate
---@param z number @the Z coordinate
---@return table @The topmost vehicle which was matched, or nil
---@return table @The topmost bale which was matched, or nil
function VehicleRaycastHelper:getVehicleBelowPlayer(player, x,y,z)
    -- Calculate four locations around the player based on the given position and the player's capsule radius
    local radius = player.model.capsuleRadius

    -- Get a vector in the player's X and Z direction, but in world coordinates. We don't get a unit vector here, but one which is exactly as long as radius
    local xx,xy,xz = localDirectionToWorld(player.graphicsRootNode, radius,0,0)
    local zx,zy,zz = localDirectionToWorld(player.graphicsRootNode, 0,0,radius)

    -- Calculate four points in front of, behind, left and right of the player
    local coords = {
        center = { x = x, y = y, z = z },
        back = { x = x - xx, y = y - xy, z = z - xz },
        front = { x = x + xx, y = y + xy, z = z + xz },
        left = { x = x - zx, y = y - zy, z = z - zz },
        right = { x = x + zx, y = y + zy, z = z + zz }
    }
    if self.debugVehicleDetection then
        local yx,yy,yz = localDirectionToWorld(player.graphicsRootNode, 0,radius,0)
        DebugUtil.drawDebugGizmoAtWorldPos(coords["center"].x, coords["center"].y, coords["center"].z, zx,zy,zz, yx,yy,yz, "Center", false, {1,1,1})
        DebugUtil.drawDebugGizmoAtWorldPos(coords["back"].x, coords["back"].y, coords["back"].z, zx,zy,zz, yx,yy,yz, "Back", false, {1,1,1})
        DebugUtil.drawDebugGizmoAtWorldPos(coords["front"].x, coords["front"].y, coords["front"].z, zx,zy,zz, yx,yy,yz, "Front", false, {1,1,1})
        DebugUtil.drawDebugGizmoAtWorldPos(coords["left"].x, coords["left"].y, coords["left"].z, zx,zy,zz, yx,yy,yz, "Left", false, {1,1,1})
        DebugUtil.drawDebugGizmoAtWorldPos(coords["right"].x, coords["right"].y, coords["right"].z, zx,zy,zz, yx,yy,yz, "Right", false, {1,1,1})
    end

    -- Raycast at every point and remember the topmost vehicle and bale
    self.topmostVehicleMatch = nil
    self.bottommostVehicleMatch = nil
    self.lastObjectMatch = nil
    local collisionMask = CollisionFlag.STATIC_OBJECT + CollisionFlag.DYNAMIC_OBJECT + CollisionFlag.VEHICLE + CollisionFlag.PLAYER
    -- Look 4 meters above and 10 below the player to account for jumping and being stuck inside a vehicle
    local topBuffer = 4
    local maxDistance = 14
    for side, location in pairs(coords) do
        if self.debugVehicleDetection then
            dbgPrint(("Looking for vehicle on %s side of %.3f/%.3f/%.3f"):format(side, x,y,z))
        end
        raycastAll(location.x, location.y + topBuffer, location.z, 0, -1, 0, "vehicleRaycastCallback", maxDistance, self, collisionMask)
    end

    -- replace any found X/Z coordinates by the original player location and use Y of the topmost vehicle match
    if self.bottommostVehicleMatch ~= nil then
        self.bottommostVehicleMatch.x = x
        self.bottommostVehicleMatch.y = self.topmostVehicleMatch.y
        self.bottommostVehicleMatch.z = z
    end
    if self.lastObjectMatch ~= nil then
        self.lastObjectMatch.x = x
        self.lastObjectMatch.z = z
    end
    return self.bottommostVehicleMatch, self.lastObjectMatch
end

---This is called by the game engine when an object which matches the VEHICLE collision mask was found below the player
---@param potentialVehicleId number @The ID of the object which was found
---@param x number @The world X coordinate of the match location
---@param y number @The world Y coordinate of the match location
---@param z number @The world Z coordinate of the match location
---@param distance number @The distance between the player and the match location
---@param nx number @The X part of a unit vector along the local X axis
---@param ny number @The Y part of a unit vector along the local X axis
---@param nz number @The Z part of a unit vector along the local X axis
---@param subShapeIndex number @The index of the shape which was found
---@param shapeId number @The ID of the shape which was found
---@param isLast boolean @True if this is the last match
---@return boolean @False if the search should be stopped, true if it should be continued
function VehicleRaycastHelper:vehicleRaycastCallback(potentialVehicleId, x, y, z, distance, nx,ny,nz, subShapeIndex, shapeId, isLast)
    if potentialVehicleId ~= nil and potentialVehicleId ~= 0 then
        local object = g_currentMission:getNodeObject(potentialVehicleId)
        if object ~= nil and object:isa(Vehicle) and CollisionFlag.getHasFlagSet(shapeId, CollisionFlag.VEHICLE) then
            -- Update the vehicle match only if this is the topmost match so far
            if self.topmostVehicleMatch == nil or y > self.topmostVehicleMatch.y then
                self.topmostVehicleMatch = { object = object, x = x, y = y, z = z, distance = distance }
                if self.debugVehicleDetection then
                    print(("%s: Found new topmost vehicle with ID %d at %.3f/%.3f/%.3f, %.3fm below player location"):format(MOD_NAME, object.id, x, y, z, distance - g_currentMission.player.model.capsuleTotalHeight/2 - 4 ))
                end
                -- Continue searching anyway in order to find the bottommost vehicle, too
            end
            if self.bottommostVehicleMatch == nil or y < self.bottommostVehicleMatch.y then
                self.bottommostVehicleMatch = { object = object, x = x, y = y, z = z, distance = distance }
                if self.debugVehicleDetection then
                    print(("%s: Found new bottommost vehicle with ID %d at %.3f/%.3f/%.3f, %.3fm below player location"):format(MOD_NAME, object.id, x, y, z, distance - g_currentMission.player.model.capsuleTotalHeight/2 - 4 ))
                end
            end
        elseif object ~= nil and (object:isa(Bale)) and (self.lastObjectMatch == nil or y > self.lastObjectMatch.y) then

            self.lastObjectMatch = { object = object, x = x, y = y, z = z, distance = distance }
            -- Continue searching anyway
        end
    end

    -- Any other case: continue searching
    return true
end