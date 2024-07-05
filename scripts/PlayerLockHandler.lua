---@class PlayerLockHandler
---This class automatically locks the player in place while they are above a vehicle which is moving and they're not moving themselves

PlayerLockHandler = {}
local PlayerLockHandler_mt = Class(PlayerLockHandler)

---Creates a new object which locks the player in place while they are above a vehicle and not moving, and adjusts their speed when moving above a vehicle
---@return table @The new instance
function PlayerLockHandler.new()
    local self = setmetatable({}, PlayerLockHandler_mt)
    return self
end

function PlayerLockHandler:after_player_update(player)
    -- If the players position shall be adjusted, do it now. At this point, it is irrelevant whether or not this is our own player or a network participant
    -- The move is applied on both client and server in multiplayer

    if player.trackedVehicle ~= nil and player.trackedVehicle.isMoving and (player.id ~= g_currentMission.player.id or not player.isMoving) then
        dbgPrint("Updating desired pos of player ID " .. tostring(player.id))
        local desiredGlobalPos = {}
        desiredGlobalPos.x, desiredGlobalPos.y, desiredGlobalPos.z =
            localToWorld(player.trackedVehicle.rootNode, player.trackedVehicleCoords.x, player.trackedVehicleCoords.y, player.trackedVehicleCoords.z)
        player.desiredGlobalPos = desiredGlobalPos
    end

    -- TEMP
    -- Render position information for debugging when desired
    if player.trackedVehicle ~= nil then
        local playerRadius, playerHeight = player.model:getCapsuleSize()
        --DebugUtil.drawDebugNode(player.rootNode, "Player", false, 0)
        --local playerWorldX, playerWorldY, playerWorldZ = player:getPositionData()
        --DebugUtil.drawDebugCubeAtWorldPos(
        --    playerWorldX, playerWorldY, playerWorldZ,
        --    1,0,0, 0,1,0, playerRadius, playerHeight * 2, playerRadius, 1,0,0)
        DebugUtil.drawDebugNode(player.rootNode, "Player Root", false, 0)
        DebugUtil.drawDebugNode(player.graphicsRootNode, "Player Gfx", false, 0)
        if player.desiredGlobalPos ~= nil then
            local yx, yy, yz = localDirectionToWorld(player.rootNode, 0, 1, 0)
            local zx, zy, zz = localDirectionToWorld(player.rootNode, 0, 0, 1)
            DebugUtil.drawDebugGizmoAtWorldPos(
                player.desiredGlobalPos.x, player.desiredGlobalPos.y, player.desiredGlobalPos.z,
                yx, yy, yz, zx, zy, zz,
                "Desired Pos", false)
        end
        if player.trackedVehicleCoords ~= nil then
            local yx, yy, yz = localDirectionToWorld(player.trackedVehicle.rootNode, 0, 1, 0)
            local zx, zy, zz = localDirectionToWorld(player.trackedVehicle.rootNode, 0, 0, 1)
            local x,y,z = localToWorld(player.trackedVehicle.rootNode, player.trackedVehicleCoords.x, player.trackedVehicleCoords.y, player.trackedVehicleCoords.z)
            DebugUtil.drawDebugGizmoAtWorldPos(x,y,z, zx,zy,zz, yx,yy,yz, "Tracked coords", false)
        end
    end

    if player.desiredGlobalPos ~= nil and player.desiredGlobalPos.y ~= nil then
        dbgPrint("Force moving player ID " .. tostring(player.id) .. " to desired position")
        player:moveToAbsoluteInternal(player.desiredGlobalPos.x, player.desiredGlobalPos.y + 0.01, player.desiredGlobalPos.z)
        -- reset the position so the player can move during the next frame
        player.desiredGlobalPos = nil
    end
end