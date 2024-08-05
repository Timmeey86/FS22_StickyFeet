---@class StickyFeetStateMachine
---This is the main state machine of the mod
---The states here follow the state machine which is available as an image in the "doc" folder in the GitHub repository (not in the released zip file)
StickyFeetStateMachine = {
    STATES = {
        NO_PLAYER = 1,
        NO_VEHICLE = 2,
        IDLE_ON_VEHICLE = 3,
        PLAYER_MOVING = 4,
        VEHICLE_MOVING = 5,
        BOTH_MOVING = 6,
        JUMPING_ABOVE_VEHICLE = 7,
        FALLING_ABOVE_VEHICLE = 8,
        JUMPING_ONTO_VEHICLE = 9,
        JUMPING_FROM_MOVING_VEHICLE = 10
    }
}
local StickyFeetStateMachine_mt = Class(StickyFeetStateMachine)

---Creates a new state machine
---@return table @The new instance
function StickyFeetStateMachine.new(debugStateMachineSwitch)
    local self = setmetatable({}, StickyFeetStateMachine_mt)
    self:reset()
    self.vehicleMovementStates = {}
    self.debugStateMachineSwitch = debugStateMachineSwitch
    return self
end

---Prints the current state
---@param reason string @The reason for the state switch (no message if still the same state)
function StickyFeetStateMachine:printState(reason)
    if self.debugStateMachineSwitch and self.state ~= self.previouslyPrintedState then
        local newState = "UNKNOWN State"
        if self.state == StickyFeetStateMachine.STATES.NO_PLAYER then
            newState = "NO_PLAYER"
        elseif self.state == StickyFeetStateMachine.STATES.NO_VEHICLE then
            newState = "NO_VEHICLE"
        elseif self.state == StickyFeetStateMachine.STATES.IDLE_ON_VEHICLE then
            newState = "IDLE_ON_VEHICLE"
        elseif self.state == StickyFeetStateMachine.STATES.PLAYER_MOVING then
            newState = "PLAYER_MOVING"
        elseif self.state == StickyFeetStateMachine.STATES.VEHICLE_MOVING then
            newState = "VEHICLE_MOVING"
        elseif self.state == StickyFeetStateMachine.STATES.BOTH_MOVING then
            newState = "BOTH_MOVING"
        elseif self.state == StickyFeetStateMachine.STATES.JUMPING_ABOVE_VEHICLE then
            newState = "JUMPING_ABOVE_VEHICLE"
        elseif self.state == StickyFeetStateMachine.STATES.FALLING_ABOVE_VEHICLE then
            newState = "FALLING_ABOVE_VEHICLE"
        elseif self.state == StickyFeetStateMachine.STATES.JUMPING_ONTO_VEHICLE then
            newState = "JUMPING_ONTO_VEHICLE"
        elseif self.state == StickyFeetStateMachine.STATES.JUMPING_FROM_MOVING_VEHICLE then
            newState = "JUMPING_FROM_MOVING_VEHICLE"
        end
        self.previouslyPrintedState = self.state
        print(("%s: Switching state machine to '%s' because '%s'"):format(MOD_NAME, newState, reason))
    end
end

---Switches to a new state and remembers the previous one
---@param newState integer @The new state
function StickyFeetStateMachine:setState(newState)
    self.previousState = self.state
    self.state = newState
end

---Call this if the state of the state machine is no longer valid
function StickyFeetStateMachine:reset()
    self.state = StickyFeetStateMachine.STATES.NO_PLAYER
    self.previousState = nil
    self.trackedVehicle = nil
    self.playerIsMoving = false
    self.playerIsJumping = false
    self.playerIsFalling = false
    self.previouslyPrintedState = 0
end

---Call this when the isEntered state of the player might have changed
---@param isEntered boolean @True if the player is entered, i.e. active as a character in the game and not inside a vehicle
function StickyFeetStateMachine:onPlayerIsEnteredStateUpdated(isEntered)
    if not isEntered then
        -- if the player is not entered, all the internal flags are invalid and must be updated as soon as they are entered again
        self:reset()
    elseif self.state == StickyFeetStateMachine.STATES.NO_PLAYER then
        self:setState(StickyFeetStateMachine.STATES.NO_VEHICLE)
    -- else: Stay in current state
    end
    self:printState("player.isEntered == " .. tostring(isEntered))
end

---Call this after finding out whether or not there is a vehicle below the player
---@param trackedVehicle table @The vehicle below the player (may be nil)
function StickyFeetStateMachine:onVehicleBelowPlayerUpdated(trackedVehicle)
    if self.trackedVehicle ~= nil and trackedVehicle == nil then
        if not self.playerIsFalling and not self.playerIsJumping then
            -- Player lost the vehicle => reset to NO_VEHICLE state, no matter where the state machine was
            self:setState(StickyFeetStateMachine.STATES.NO_VEHICLE)
            self:printState("player lost the vehicle")
        elseif self.state == StickyFeetStateMachine.STATES.JUMPING_ABOVE_VEHICLE or self.state == StickyFeetStateMachine.STATES.FALLING_ABOVE_VEHICLE then
            -- Player was jumping above a vehicle, but lost it, transition through an intermediate state until they are on the ground
            self:setState(StickyFeetStateMachine.STATES.JUMPING_FROM_MOVING_VEHICLE)
            self.originVehicle = self.trackedVehicle
            self:printState("player lost the vehicle mid jump")
        else
            -- Player jumped from a stationary vehicle, and other cases
            self:setState(StickyFeetStateMachine.STATES.NO_VEHICLE)
            self:printState("player jumped from a stationary vehicle, or otherwise left the vehicle")
        end
    elseif self.state == StickyFeetStateMachine.STATES.NO_VEHICLE and trackedVehicle ~= nil then
        -- There was no vehicle, but there is now:
        if not self.playerIsFalling and not self.playerIsJumping then
            -- Player somehow managed to get onto a vehicle without jumping or falling. Advance the state machine
            self:setState(StickyFeetStateMachine.STATES.IDLE_ON_VEHICLE)
            self:printState("player suddenly found vehicle")
        else
            -- This is the default case: The player is jumping onto a vehicle (doesn't matter if still jumping or already falling)
            -- Stay in an intermediate state until they have landed
            self:setState(StickyFeetStateMachine.STATES.JUMPING_ONTO_VEHICLE)
            self:printState("player is jumping onto vehicle")
        end
    elseif self.state == StickyFeetStateMachine.STATES.JUMPING_FROM_MOVING_VEHICLE
        and self.originVehicle ~= nil and trackedVehicle ~= nil
        and self.originVehicle ~= trackedVehicle then
        -- Special case: The player is jumping from a moving vehicle but has found another vehicle
        self:setState(StickyFeetStateMachine.STATES.JUMPING_ONTO_VEHICLE)
        self:printState("player is jumping from one vehicle to another")
    end
    if self.debugStateMachineSwitch and self.trackedVehicle ~= nil and trackedVehicle ~= nil and self.trackedVehicle ~= trackedVehicle then
        print(("%s: Tracked vehicle has changed from %d to %d"):format(MOD_NAME, self.trackedVehicle.id, trackedVehicle.id))
    end
    -- Remember the tracked vehicle in any case
    self.trackedVehicle = trackedVehicle
end

---Call this after figuring out whether or not the player is moving
---@param isMoving boolean @True if the player is moving
function StickyFeetStateMachine:onPlayerMovementUpdated(isMoving)
    if isMoving then
        if self.state == StickyFeetStateMachine.STATES.IDLE_ON_VEHICLE then
            self:setState(StickyFeetStateMachine.STATES.PLAYER_MOVING)
            self:printState("player is now moving on an idle vehicle")
        elseif self.state == StickyFeetStateMachine.STATES.VEHICLE_MOVING then
            self:setState(StickyFeetStateMachine.STATES.BOTH_MOVING)
            self:printState("player is now moving on a moving vehicle")
        end
    else
        if self.state == StickyFeetStateMachine.STATES.PLAYER_MOVING then
            self:setState(StickyFeetStateMachine.STATES.IDLE_ON_VEHICLE)
            self:printState("player is no longer moving on an idle vehicle")
        elseif self.state == StickyFeetStateMachine.STATES.BOTH_MOVING then
            self:setState(StickyFeetStateMachine.STATES.VEHICLE_MOVING)
            self:printState("player is no longer moving on a moving vehicle")
        end
    end
    -- Movement state does not matter in any other case

    -- Remember the moving state in any case
    self.playerIsMoving = isMoving
end

---Call this after figuring out whether or not the vehicle is moving
---@param vehicle table @The vehicle which was updated.
---@param isMoving boolean @True if the vehicle is moving
function StickyFeetStateMachine:onVehicleMovementUpdated(vehicle, isMoving)
    -- Note: This method will be called for any vehicle, and on every update, not just on state changes
    if vehicle == nil then
        return
    else
        -- Store the movement states for all vehicles. The player might jump onto a moving one, for example.
        self.vehicleMovementStates[vehicle] = isMoving
    end

    -- The player is still on the same vehicle
    if vehicle == self.trackedVehicle then
        if isMoving then
            if self.state == StickyFeetStateMachine.STATES.IDLE_ON_VEHICLE then
                self:setState(StickyFeetStateMachine.STATES.VEHICLE_MOVING)
                self:printState("tracked vehicle is now moving")
            elseif self.state == StickyFeetStateMachine.STATES.PLAYER_MOVING then
                self:setState(StickyFeetStateMachine.STATES.BOTH_MOVING)
                self:printState("both player and tracked vehicle are now moving")
            end
        else
            if self.state == StickyFeetStateMachine.STATES.VEHICLE_MOVING then
                self:setState(StickyFeetStateMachine.STATES.IDLE_ON_VEHICLE)
                self:printState("tracked vehicle is no longer moving")
            elseif self.state == StickyFeetStateMachine.STATES.BOTH_MOVING then
                self:setState(StickyFeetStateMachine.STATES.PLAYER_MOVING)
                self:printState("tracked vehicle is no longer moving (but player is)")
            end
        end
    end
    -- If the vehicle suddenly changed, the next tracked vehicle update will advance the state machine
end

---Call this when the jumping state of the player changes
---@param isJumping any
function StickyFeetStateMachine:onPlayerJumpingStateUpdated(isJumping)
    if isJumping then
        -- Note: Transition from NO_VEHICLE to JUMPING_ONTO_VEHICLE is handled by onVehicleBelowPlayerUpdated

        if self.state == StickyFeetStateMachine.STATES.VEHICLE_MOVING or self.state == StickyFeetStateMachine.STATES.BOTH_MOVING then
            self:setState(StickyFeetStateMachine.STATES.JUMPING_ABOVE_VEHICLE)
            self:printState("player is jumping above moving vehicle")
        end
    end
    self.playerIsJumping = isJumping
end

---Call this when the falling state of the player changes
---@param isFalling boolean @True if the player is falling
---@param isOnGround boolean @True if the player is on the ground
function StickyFeetStateMachine:onPlayerFallingStateUpdated(isFalling, isOnGround)
    if isFalling then
        if self.state == StickyFeetStateMachine.STATES.JUMPING_ABOVE_VEHICLE then
            self:setState(StickyFeetStateMachine.STATES.FALLING_ABOVE_VEHICLE)
            self:printState("player is now falling above moving vehicle")
        end
    elseif not self.playerIsJumping then
        -- Neither jumping nor falling => If the player is in a state which was triggered by a jump, they have landed
        if self.state == StickyFeetStateMachine.STATES.FALLING_ABOVE_VEHICLE then
            if self.playerIsMoving then
                self:setState(StickyFeetStateMachine.STATES.BOTH_MOVING)
                self:printState("player has landed, but is still moving")
            else
                self:setState(StickyFeetStateMachine.STATES.VEHICLE_MOVING)
                self:printState("player has landed, and isn't moving")
            end
        -- Note: We need to check if the player is on the ground since at the peak of a jump, they are neither falling nor jumping (just like on the ground)
        --       even though they are still mid air
        elseif self.state == StickyFeetStateMachine.STATES.JUMPING_FROM_MOVING_VEHICLE and isOnGround then
            self:setState(StickyFeetStateMachine.STATES.NO_VEHICLE)
            if self.trackedVehicle == nil then
                self:printState("player has landed on ground after jumping from vehicle")
            else
                -- transition through states
                local switchWasActive = self.debugStateMachineSwitch
                self.debugStateMachineSwitch = false
                self:setState(StickyFeetStateMachine.STATES.NO_VEHICLE)
                self:onVehicleBelowPlayerUpdated(self.trackedVehicle)
                self:onVehicleMovementUpdated(self.trackedVehicle, self.vehicleMovementStates[self.trackedVehicle] or false)
                self:onPlayerMovementUpdated(self.playerIsMoving)
                -- Note: we already know the player isn't moving or jumping
                self.debugStateMachineSwitch = switchWasActive
                self:printState("player has lost a vehicle mid jump, but landed on a vehicle anyway")
            end
        elseif self.state == StickyFeetStateMachine.STATES.JUMPING_ONTO_VEHICLE and isOnGround then
            if self.trackedVehicle ~= nil and self.vehicleMovementStates[self.trackedVehicle] == true then
                self:setState(StickyFeetStateMachine.STATES.VEHICLE_MOVING)
                self:printState("player has landed on a moving vehicle")
            elseif self.trackedVehicle ~= nil and self.vehicleMovementStates[self.trackedVehicle] == false then
                self:setState(StickyFeetStateMachine.STATES.IDLE_ON_VEHICLE)
                self:printState("player has landed on a stationary vehicle")
            elseif self.trackedVehicle == nil then
                Logging.error(MOD_NAME .. ": State machine is in JUMPING_ONTO_VEHICLE state with a nil vehicle. Resetting")
                self:reset()
                self:printState("state machine is recovering from an error")
            end
        end
    end
    self.playerIsFalling = isFalling
end

---Convenience function which checks if the player is in one of several possible states which describe movement above a moving vehicle
---@return boolean @True in case of BOTH_MOVING, JUMPING_ABOVE_VEHICLE and FALLING_ABOVE_VEHICLE states
function StickyFeetStateMachine:playerIsMovingAboveMovingVehicle()
    return self.state == StickyFeetStateMachine.STATES.BOTH_MOVING
        or self.state == StickyFeetStateMachine.STATES.JUMPING_ABOVE_VEHICLE
        or self.state == StickyFeetStateMachine.STATES.FALLING_ABOVE_VEHICLE
end