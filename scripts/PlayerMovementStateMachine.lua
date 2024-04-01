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
        local x,y,z = localToWorld(player.rootNode, 0,0,0)
        if state then
            dbgPrint(("Player ID %s has started moving at (%.1f,%.1f,%.1f)"):format(player.id, x, y, z))
        else
            dbgPrint(("Player ID %s has stopped moving and is now at (%.1f,%.1f,%.1f)"):format(player.id, x, y, z))
        end
        if player == g_currentMission.player then
            --dbgPrint(("Sending an event to the server so they know that player ID %s has moving state %s"):format(player.id, state))
            --g_client:getServerConnection():sendEvent(PlayerMovementStateChangedEvent.new(player, state))
        end
    -- else: ignore; same state
    end
end

---Keeps track of if the player is moving and which position they are currently at
---@param player table @The player to be tracked
function PlayerMovementStateMachine:after_player_updateTick(player)
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
    if player.id ~= g_currentMission.player.id then
        self:updateMovementState(player, isMoving)
    else
        if isMoving ~= player.isMoving then
            dbgPrint(("Server thinks our client's player has movement state %s while it is %s"):format(isMoving, player.isMoving))
        end
    end
end