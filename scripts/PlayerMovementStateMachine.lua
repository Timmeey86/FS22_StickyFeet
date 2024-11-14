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


---Keeps track of if the player is moving and which position they are currently at
---@param player table @The player to be tracked
function PlayerMovementStateMachine:checkMovementState(player)
    -- Remarks: updateTick gets called on both server and client, with different player IDs, but the player states seem to always be false on the server
    local ic = player.inputComponent
    if ic then
        setTextColor(1, 1, 1, 1)
        local line = 0.95
        line = line - 0.015
        renderText(.005, line, .015, ("crouchValue: %s"):format(ic.crouchValue))
        line = line - 0.015
        renderText(.005, line, .015, ("flightAxis: %s"):format(ic.flightAxis))
        line = line - 0.015
        renderText(.005, line, .015, ("walkAxis: %s"):format(ic.walkAxis))
        line = line - 0.015
        renderText(.005, line, .015, ("lastJumpPower: %s"):format(ic.lastJumpPower))
        line = line - 0.015
        renderText(.005, line, .015, ("worldDirectionX: %s"):format(ic.worldDirectionX))
        line = line - 0.015
        renderText(.005, line, .015, ("worldDirectionY: %s"):format(ic.worldDirectionY))
        line = line - 0.015
        renderText(.005, line, .015, ("worldDirectionZ: %s"):format(ic.worldDirectionZ))
        line = line - 0.015
        renderText(.005, line, .015, ("lastHasMovementInputs: %s"):format(ic.lastHasMovementInputs))
        line = line - 0.015
        renderText(.005, line, .015, ("currentVelocityY: %s"):format(player.mover.currentVelocityY))
        line = line - 0.015
    end
    if player.isClient and player == g_localPlayer then
        if player.mover.currentSpeed > .0 then
            self.mainStateMachine:onPlayerMovementUpdated(true)
        else
            self.mainStateMachine:onPlayerMovementUpdated(false)
        end
        self.mainStateMachine:onPlayerJumpingStateUpdated(player.mover.currentVelocityY > 0)
        self.mainStateMachine:onPlayerFallingStateUpdated(player.mover.currentVelocityY <= 0 and player.mover.currentGroundTime == 0, player.mover.currentGroundTime > 0)
    -- else: Server and other clients won't know the state machine state.
    end
end