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

    if player.isClient and player == g_localPlayer then
        local onFootState = player.stateMachine.currentState
        if onFootState.name ~= "onFoot" then
            dbgPrint("Player is not on foot")
            return
        end
        if onFootState.currentState == onFootState.states["walking"]
            or onFootState.currentState == onFootState.states["falling"]
            or onFootState.currentState == onFootState.states["jumping"]
            or onFootState.currentState == onFootState.states["crouching"] then
            dbgPrint("Player is moving")
            self.mainStateMachine:onPlayerMovementUpdated(true)
        else
            dbgPrint("Player is not moving")
            self.mainStateMachine:onPlayerMovementUpdated(false)
        end
        self.mainStateMachine:onPlayerJumpingStateUpdated(onFootState.currentState == onFootState.states["jumping"])
        self.mainStateMachine:onPlayerFallingStateUpdated(onFootState.currentState == onFootState.states["falling"], player.graphicsState.isGrounded)
    -- else: Server and other clients won't know the state machine state.
    end
end