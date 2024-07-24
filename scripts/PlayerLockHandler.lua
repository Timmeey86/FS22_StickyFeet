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
function PlayerLockHandler:adjustPlayerPositionIfNecessary(player)

    -- Add the direction change of the vehicle to the player movement in all cases
    if player.vehicleDirectionVector ~= nil and player.trackedVehicle.isMoving and player.id == g_currentMission.player.id then
        local directionVector = player.vehicleDirectionVector
        if player.movementCorrection == nil then
            -- No movement correction pending, just store the vector
            player.movementCorrection = directionVector
        else
            -- Movement correction has not been applied yet, add the new vector to the existing correction
            player.movementCorrection = {
                x = player.movementCorrection.x + directionVector.x,
                y = player.movementCorrection.y + directionVector.y,
                z = player.movementCorrection.z + directionVector.z
            }
        end
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
        dbgPrint("Correcting player movement speed")

        -- Add the movement correction vector to the player movement vector (which is 0 if the player is not moving)
        movementX = movementX + player.movementCorrection.x
        movementY = movementY + player.movementCorrection.y
        movementZ = movementZ + player.movementCorrection.z

        -- Reset the correction so it doesn't get applied again
        player.movementCorrection = nil
    end

    -- Call the base game behavior with a potentially modified movement vector
    superFunc(player, dt, movementX, movementY, movementZ)
end