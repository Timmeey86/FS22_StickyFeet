---@class PlayerMovementTracker
---This class tracks of the movement of players

PlayerMovementTracker = {}
local PlayerMovementTracker_mt = Class(PlayerMovementTracker)

---Creates a new object which keeps track of the movement of players
---@return table @The new instance
function PlayerMovementTracker.new()
    local self = setmetatable({}, PlayerMovementTracker_mt)
    self.playerMovingStates = {}
    self.playerMovementVectors = {}
    self.currentPlayerPositions = {}
    return self
end

---Keeps track of if the player is moving and which position they are currently at
---@param player table @The player to be tracked
function PlayerMovementTracker:after_player_updateTick(player)
    if player.playerStateMachine.playerStateWalk.isActive
        or player.playerStateMachine.playerStateRun.isActive
        or player.playerStateMachine.playerStateJump.isActive
        or player.playerStateMachine.playerStateFall.isActive
        or player.playerStateMachine.playerStateSwim.isActive -- you never konw
        then
        self.playerMovingStates[player] = true
        local playerData = {}
        playerData.x, playerData.y, playerData.z = player:getPositionData()
        self.currentPlayerPositions[player] = playerData
    else
        self.playerMovingStates[player] = false
    end
end