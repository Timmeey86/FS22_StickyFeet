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

---Adjusts player position and movement relative to the vehicle speed while the vehicle is moving.
---@param player table @The player to be handled
function PlayerLockHandler:before_player_update(player)
    -- If the players position shall be adjusted, do it now. At this point, it is irrelevant whether or not this is our own player or a network participant
    -- The move is applied on both client and server in multiplayer

    -- This method may get called more often than the network synchronisation happens. Recalculate the position if necessary
    if player.trackedVehicle ~= nil and player.trackedVehicle.isMoving and (player.id ~= g_currentMission.player.id or not player.isMoving) then
        dbgPrint("Updating desired pos of player ID " .. tostring(player.id))
        local desiredGlobalPos = {}
        desiredGlobalPos.x, desiredGlobalPos.y, desiredGlobalPos.z =
            localToWorld(player.trackedVehicle.rootNode, player.trackedVehicleCoords.x, player.trackedVehicleCoords.y, player.trackedVehicleCoords.z)
        player.desiredGlobalPos = desiredGlobalPos
    end

    -- Adjust the movement speed of the controlled player if they are moving on a moving vehicle
    -- Otherwise, they would move very slowly in vehicle movement direction and very quickly in the opposite direction
    if player.trackedVehicle ~= nil and player.trackedVehicle.isMoving and player.id == g_currentMission.player.id and player.isMoving then
        local directionVector = player.trackedVehicle.directionVector
        if player.isMoving and directionVector ~= nil then
            player.movementCorrection = directionVector
        end
    end

    -- "Teleport" the player whenever necessary
    if player.desiredGlobalPos ~= nil and player.desiredGlobalPos.y ~= nil then
        dbgPrint("Force moving player ID " .. tostring(player.id) .. " to desired position")
        player:moveToAbsoluteInternal(player.desiredGlobalPos.x, player.desiredGlobalPos.y + 0.01, player.desiredGlobalPos.z)
        -- reset the position so the player can move during the next frame
        player.desiredGlobalPos = nil
    end
end

---Adjusts the player movement while they are moving on a moving vehicle so the movement speed is equal in any direction
---@param player table @The player to be moved
---@param superFunc function @The existing implementation (base game or already adjusted by mods)
---@param dt number @The delta time
---@param movementX number @The X movement component
---@param movementY number @The Y movement component
---@param movementZ number @The Z movement component
function PlayerLockHandler:instead_of_player_movePlayer(player, superFunc, dt, movementX, movementY, movementZ)

    if player.movementCorrection ~= nil then
        -- Add the vehicle movement vector to the player movement vector
        movementX = movementX + player.movementCorrection.x
        movementY = movementY + player.movementCorrection.y
        movementZ = movementZ + player.movementCorrection.z

        -- Reset the correction so it doesn't get applied again
        player.movementCorrection = nil
    end

    -- Call the base game behavior with a potentially modified movement vector
    superFunc(player, dt, movementX, movementY, movementZ)
end