---This class tracks of the movement of players
---@class PlayerMovementStateMachine
---@field mainStateMachine StickyFeetStateMachine @The state machine of this mod
PlayerMovementStateMachine = {}
local PlayerMovementStateMachine_mt = Class(PlayerMovementStateMachine)

---Creates a new object which keeps track of the movement of players
---@param mainStateMachine table @The main state machine of the mod
---@return PlayerMovementStateMachine @The new instance
function PlayerMovementStateMachine.new(mainStateMachine)
	local self = setmetatable({}, PlayerMovementStateMachine_mt)
	self.mainStateMachine = mainStateMachine
	return self
end


---Keeps track of if the player is moving and which position they are currently at
---@param player table @The player to be tracked
function PlayerMovementStateMachine:checkMovementState(player)
	-- Remarks: updateTick gets called on both server and client, with different player IDs, but the player states seem to always be false on the server
	if player.isClient and player == g_localPlayer then
		if player.mover.currentSpeed > .0 then
			self.mainStateMachine:onPlayerMovementUpdated(true)
		else
			self.mainStateMachine:onPlayerMovementUpdated(false)
		end
		local isJumping = player.mover.currentVelocityY > 0
		local isFalling = player.mover.currentVelocityY <= 0 and player.mover.currentGroundTime == 0
		local isOnGround = player.mover.currentGroundTime > 0
		self.mainStateMachine:onPlayerJumpingStateUpdated(isJumping)
		self.mainStateMachine:onPlayerFallingStateUpdated(isFalling, isOnGround)
	-- else: Server and other clients won't know the state machine state.
	end
end