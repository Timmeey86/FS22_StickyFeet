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

    if player.desiredGlobalPos ~= nil and player.desiredGlobalPos.y ~= nil then
        dbgPrint("Force moving player ID " .. tostring(player.id) .. " to desired position")
        setTranslation(player.rootNode, player.desiredGlobalPos.x, player.desiredGlobalPos.y, player.desiredGlobalPos.z)
        -- reset the position so the player can move during the next frame
        player.desiredGlobalPos = nil
    end
end