---@class PlayerMovementStateMachine
---This class tracks of the movement of players

PlayerMovementStateMachine = {}
local PlayerMovementStateMachine_mt = Class(PlayerMovementStateMachine)

---Creates a new object which keeps track of the movement of players
---@return table @The new instance
function PlayerMovementStateMachine.new()
    local self = setmetatable({}, PlayerMovementStateMachine_mt)
    return self
end


---Updates the movement state and prints a debug message if the state has changed.
---@param player table @The player which changed
---@param state any
function PlayerMovementStateMachine:updateMovementState(player, state)
    if player.isMoving ~= state then
        player.isMoving = state
        -- Nothing else for now; the movement state will be synchronised through writeUpdateStream
    end
end

---Keeps track of if the player is moving and which position they are currently at
---@param player table @The player to be tracked
function PlayerMovementStateMachine:checkMovementState(player)
    -- Remarks: updateTick gets called on both server and client, with different player IDs, but the player states seem to always be false on the server

    if player.isClient and player == g_currentMission.player then
        if player.isEntered and (
               player.playerStateMachine.playerStateWalk.isActive
            or player.playerStateMachine.playerStateRun.isActive
            or player.playerStateMachine.playerStateJump.isActive
            or player.playerStateMachine.playerStateFall.isActive
            or player.playerStateMachine.playerStateSwim.isActive)
            then

            self:updateMovementState(player, true)
        else
            self:updateMovementState(player, false)
        end
    -- else: Server and other clients won't know the state machine state.
    end
end

function PlayerMovementStateMachine:after_player_writeUpdateStream(player, streamId, connection, dirtyMask)
    streamWriteBool(streamId, player.isMoving or false)
end

function PlayerMovementStateMachine:after_player_readUpdateStream(player, streamId, timestamp, connection)
    local isMoving = streamReadBool(streamId)
    if player ~= nil and g_currentMission.player ~= nil and player.id ~= g_currentMission.player.id then
        self:updateMovementState(player, isMoving)
        -- Ignore movement state updates for our own player but update any other player (on server and all clients)
    end
end