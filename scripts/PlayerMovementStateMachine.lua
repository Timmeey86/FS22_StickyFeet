---@class PlayerMovementStateMachine
---This class tracks of the movement of players

PlayerMovementStateMachine = {}
local PlayerMovementStateMachine_mt = Class(PlayerMovementStateMachine)

---Creates a new object which keeps track of the movement of players
---@param mainStateMachine table @The main state machine of the mod
---@return table @The new instance
function PlayerMovementStateMachine.new(mainStateMachine)
    local self = setmetatable({}, PlayerMovementStateMachine_mt)
    self.mainStateMachine = mainStateMachine
    return self
end


---Updates the movement state and prints a debug message if the state has changed.
---@param state any
function PlayerMovementStateMachine:updateMovementState(state)
    self.mainStateMachine:onPlayerMovementUpdated(state)
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

            self:updateMovementState(true)
        else
            self:updateMovementState(false)
        end
    -- else: Server and other clients won't know the state machine state.
    end
end