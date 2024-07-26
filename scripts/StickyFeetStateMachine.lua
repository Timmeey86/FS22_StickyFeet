---@class StickyFeetStateMachine
---This is the main state machine of the mod
---The states here follow the state machine which is available as an image in the "doc" folder in the GitHub repository (not in the released zip file)
StickyFeetStateMachine = {
    STATES = {
        NO_PLAYER = 1,
        NO_VEHICLE = 2,
        NOT_MOVING = 3,
        PLAYER_MOVING = 4,
        VEHICLE_MOVING = 5,
        BOTH_MOVING = 6,
        JUMPING_ABOVE_VEHICLE = 7,
        FALLING_ABOVE_VEHICLE = 8
    }
}
local StickyFeetStateMachine_mt = Class(StickyFeetStateMachine)

---Creates a new state machine
---@return table @The new instance
function StickyFeetStateMachine.new()
    local self = setmetatable({}, StickyFeetStateMachine_mt)
    self:reset()
    self.vehicleMovingStates = {}
    return self
end

---Prints the current state
---@param reason string @The reason for the state switch (no message if still the same state)
function StickyFeetStateMachine:printState(reason)
    if self.state ~= self.previouslyPrintedState then
        local newState = "UNKNOWN State"
        if self.state == StickyFeetStateMachine.STATES.NO_PLAYER then
            newState = "NO_PLAYER"
        elseif self.state == StickyFeetStateMachine.STATES.NO_VEHICLE then
            newState = "NO_VEHICLE"
        elseif self.state == StickyFeetStateMachine.STATES.NOT_MOVING then
            newState = "NOT_MOVING"
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
        end
        self.previouslyPrintedState = self.state
        print(("%s: Switching state machine to '%s' because '%s'"):format(MOD_NAME, newState, reason))
    end
end

---Call this if the state of the state machine is no longer valid
function StickyFeetStateMachine:reset()
    self.state = StickyFeetStateMachine.STATES.NO_PLAYER
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
        self.state = StickyFeetStateMachine.STATES.NO_VEHICLE
    -- else: Stay in current state
    end
    self:printState("player.isEntered == " .. tostring(isEntered))
end

---Call this after finding out whether or not there is a vehicle below the player
---@param trackedVehicle table @The vehicle below the player (may be nil)
function StickyFeetStateMachine:onVehicleBelowPlayerUpdated(trackedVehicle)
    local triggerSubTransitions = false
    if trackedVehicle == nil and self.state ~= StickyFeetStateMachine.STATES.NO_PLAYER then
        -- Interrupt event: Transition to NO_VEHICLE, except if in NO_PLAYER state (in which case this method should not be called)
        self.state = StickyFeetStateMachine.STATES.NO_VEHICLE
    elseif trackedVehicle ~= nil and self.state == StickyFeetStateMachine.STATES.NO_VEHICLE then
        self.state = StickyFeetStateMachine.STATES.NOT_MOVING
        triggerSubTransitions = true
    end
    self.trackedVehicle = trackedVehicle
    self:printState("trackedVehicle is " .. tostring(trackedVehicle))

    if triggerSubTransitions then
        -- maybe transition to other states based on current flags
        self:onPlayerMovementUpdated(self.playerIsMoving)
        self:onVehicleMovementUpdated(self.trackedVehicle, self.vehicleIsMoving)
        self:onPlayerJumpingStateUpdated(self.playerIsJumping)
        self:onPlayerFallingStateUpdated(self.playerIsFalling)
    end
end

---Call this after figuring out whether or not the player is moving
---@param isMoving boolean @True if the player is moving
function StickyFeetStateMachine:onPlayerMovementUpdated(isMoving)
    self:printState("checking if a print is missing")
    if isMoving then
        if self.state == StickyFeetStateMachine.STATES.NOT_MOVING then
            self.state = StickyFeetStateMachine.STATES.PLAYER_MOVING
        elseif self.state == StickyFeetStateMachine.STATES.VEHICLE_MOVING then
            self.state = StickyFeetStateMachine.STATES.BOTH_MOVING
        -- else: remain in same state
        end
    else
        if self.state == StickyFeetStateMachine.STATES.PLAYER_MOVING then
            self.state = StickyFeetStateMachine.STATES.NOT_MOVING
        elseif self.state == StickyFeetStateMachine.STATES.BOTH_MOVING then
            self.state = StickyFeetStateMachine.STATES.VEHICLE_MOVING
        -- else: remain in same state
        end
    end
    self.playerIsMoving = isMoving
    self:printState("player.isMoving == " .. tostring(isMoving))
end

---Call this after figuring out whether or not the vehicle is moving
---@param vehicle table @The vehicle which was updated.
---@param isMoving boolean @True if the vehicle is moving
function StickyFeetStateMachine:onVehicleMovementUpdated(vehicle, isMoving)
    -- Note: This method will be called for any vehicle, and on every update, not just on state changes
    if vehicle == nil then
        return
    else
        -- Store the movement states for all vehicles in case the player 
        self.vehicleMovingStates[vehicle] = isMoving
    end

    -- Only update the state machine if the state of the tracked vehicle changes.
    if vehicle == self.trackedVehicle then
        if isMoving then
            if self.state == StickyFeetStateMachine.STATES.NOT_MOVING then
                self.state = StickyFeetStateMachine.STATES.VEHICLE_MOVING
            elseif self.state == StickyFeetStateMachine.STATES.PLAYER_MOVING then
                self.state = StickyFeetStateMachine.STATES.BOTH_MOVING
            -- else: remain in same state
            end
        else
            if self.state == StickyFeetStateMachine.STATES.VEHICLE_MOVING then
                self.state = StickyFeetStateMachine.STATES.NOT_MOVING
            elseif self.state == StickyFeetStateMachine.STATES.BOTH_MOVING then
                self.state = StickyFeetStateMachine.STATES.PLAYER_MOVING
            -- else: remain in same state
            end
        end
    end
    self:printState("vehicle.isMoving == " .. tostring(isMoving) .. " (vehicle: " .. tostring(vehicle) .. ")")
end

---Call this when the jumping state of the player changes
---@param isJumping any
function StickyFeetStateMachine:onPlayerJumpingStateUpdated(isJumping)
    if isJumping then
       if self.state == StickyFeetStateMachine.STATES.VEHICLE_MOVING
            or self.state == StickyFeetStateMachine.STATES.BOTH_MOVING
            or self.state == StickyFeetStateMachine.STATES.FALLING_ABOVE_VEHICLE then

            self.state = StickyFeetStateMachine.STATES.JUMPING_ABOVE_VEHICLE
        -- else: Ignore
        end
    else
        -- In theory, this should always be followed by a falling state
    end
    self.playerIsJumping = isJumping
    self:printState("player.isJumping == " .. tostring(isJumping))
end

---Call this when the falling state of the player changes
---@param isFalling any
function StickyFeetStateMachine:onPlayerFallingStateUpdated(isFalling)
    local triggerSubTransitions = false
    if isFalling then
       if self.state == StickyFeetStateMachine.STATES.VEHICLE_MOVING
            or self.state == StickyFeetStateMachine.STATES.BOTH_MOVING
            or self.state == StickyFeetStateMachine.STATES.JUMPING_ABOVE_VEHICLE then

            self.state = StickyFeetStateMachine.STATES.FALLING_ABOVE_VEHICLE
        -- else: Ignore
        end
    else
        if self.state == StickyFeetStateMachine.STATES.FALLING_ABOVE_VEHICLE then
            self.state = StickyFeetStateMachine.STATES.VEHICLE_MOVING
            triggerSubTransitions = true
        end
    end
    self.playerIsFalling = isFalling
    self:printState("player.isFalling == " .. tostring(isFalling))

    if triggerSubTransitions then
        -- Transition to BOTH_MOVING state now if the player was moving mid jump
        self:onPlayerMovementUpdated(self.playerIsMoving)
    end
end

---Convenience function which checks if the player is in one of several possible states which describe movement above a moving vehicle
---@return boolean @True in case of BOTH_MOVING, JUMPING_ABOVE_VEHICLE and FALLING_ABOVE_VEHICLE states
function StickyFeetStateMachine:playerIsMovingAboveVehicle()
    return self.state == StickyFeetStateMachine.STATES.BOTH_MOVING
        or self.state == StickyFeetStateMachine.STATES.JUMPING_ABOVE_VEHICLE
        or self.state == StickyFeetStateMachine.STATES.FALLING_ABOVE_VEHICLE
end