---@class StickyFeetStateMachine
---This is the main state machine of the mod
StickyFeetStateMachine = {
    STATES = {
        INACTIVE = 1,
        IDLE = 2,
        PLAYER_MOVING = 3,
        VEHICLE_MOVING = 4,
        BOTH_MOVING = 5
    }
}
local StickyFeetStateMachine_mt = Class(StickyFeetStateMachine)

---Creates a new state machine
---@return table @The new instance
function StickyFeetStateMachine.new()
    local self = setmetatable({}, StickyFeetStateMachine_mt)
    self:reset()
    return self
end

---Prints the current state
function StickyFeetStateMachine:printState()
    if true then
        if self.state == StickyFeetStateMachine.STATES.INACTIVE then
            print(MOD_NAME .. ": INACTIVE")
        elseif self.state == StickyFeetStateMachine.STATES.IDLE then
            print(MOD_NAME .. ": IDLE")
        elseif self.state == StickyFeetStateMachine.STATES.PLAYER_MOVING then
            print(MOD_NAME .. ": PLAYER_MOVING")
        elseif self.state == StickyFeetStateMachine.STATES.VEHICLE_MOVING then
            print(MOD_NAME .. ": VEHICLE_MOVING")
        elseif self.state == StickyFeetStateMachine.STATES.BOTH_MOVING then
            print(MOD_NAME .. ": BOTH_MOVING")
        else
            print(MOD_NAME .. ": UNKNOWN STATE")
        end
    end
end

---Call this if the state of the state machine is no longer valid
function StickyFeetStateMachine:reset()
    self.state = StickyFeetStateMachine.STATES.INACTIVE
    self.trackedVehicle = nil
    self.playerIsMoving = false
    self.vehicleIsMoving = false
end

---Call this when the isEntered state of the player might have changed
---@param isEntered boolean @True if the player is entered, i.e. active as a character in the game and not inside a vehicle
function StickyFeetStateMachine:onPlayerIsEnteredStateUpdated(isEntered)
    if not isEntered then
        -- if the player is not entered, all the internal flags are invalid and must be updated as soon as they are entered again
        self:reset()
        self:printState()
    elseif self.state == StickyFeetStateMachine.STATES.INACTIVE then
        -- maybe transition to other states based on current flags
        -- usually, this would stay in INACTIVE, however
        self:onVehicleBelowPlayerUpdated(self.trackedVehicle)
        self:onPlayerMovementUpdated(self.playerIsMoving)
        self:onVehicleMovementUpdated(self.trackedVehicle, self.vehicleIsMoving)
        self:printState()
    -- else: Stay in current state
    end
end

---Call this after finding out whether or not there is a vehicle below the player
---@param trackedVehicle table @The vehicle below the player (may be nil)
function StickyFeetStateMachine:onVehicleBelowPlayerUpdated(trackedVehicle)
    if trackedVehicle ~= nil and self.state == StickyFeetStateMachine.STATES.INACTIVE then
        self.state = StickyFeetStateMachine.STATES.IDLE
        -- maybe transition to other states based on current flags
        self:onPlayerMovementUpdated(self.playerIsMoving)
        self:onVehicleMovementUpdated(self.trackedVehicle, self.vehicleIsMoving)
        self:printState()
    elseif trackedVehicle == nil then
        local printState = self.state ~= StickyFeetStateMachine.STATES.INACTIVE
        self.state = StickyFeetStateMachine.STATES.INACTIVE
        if printState then self:printState() end
    -- else: remain in same state
    end
    self.trackedVehicle = trackedVehicle
end

---Call this after figuring out whether or not the player is moving
---@param isMoving boolean @True if the player is moving
function StickyFeetStateMachine:onPlayerMovementUpdated(isMoving)
    if isMoving then
        if self.state == StickyFeetStateMachine.STATES.IDLE then
            self.state = StickyFeetStateMachine.STATES.PLAYER_MOVING
            self:printState()
        elseif self.state == StickyFeetStateMachine.STATES.VEHICLE_MOVING then
            self.state = StickyFeetStateMachine.STATES.BOTH_MOVING
            self:printState()
        -- else: remain in same state
        end
    else
        if self.state == StickyFeetStateMachine.STATES.PLAYER_MOVING then
            self.state = StickyFeetStateMachine.STATES.IDLE
            self:printState()
        elseif self.state == StickyFeetStateMachine.STATES.BOTH_MOVING then
            self.state = StickyFeetStateMachine.STATES.VEHICLE_MOVING
            self:printState()
        -- else: remain in same state
        end
    end
    self.playerIsMoving = isMoving
end

---Call this after figuring out whether or not the vehicle is moving
---@param vehicle table @The vehicle which was updated.
---@param isMoving boolean @True if the vehicle is moving
function StickyFeetStateMachine:onVehicleMovementUpdated(vehicle, isMoving)
    if vehicle == nil or vehicle ~= self.trackedVehicle then
        -- Only update the state machine if the state of the tracked vehicle changes
        return
    end
    if isMoving then
        if self.state == StickyFeetStateMachine.STATES.IDLE then
            self.state = StickyFeetStateMachine.STATES.VEHICLE_MOVING
            self:printState()
        elseif self.state == StickyFeetStateMachine.STATES.PLAYER_MOVING then
            self.state = StickyFeetStateMachine.STATES.BOTH_MOVING
            self:printState()
        -- else: remain in same state
        end
    else
        if self.state == StickyFeetStateMachine.STATES.VEHICLE_MOVING then
            self.state = StickyFeetStateMachine.STATES.IDLE
            self:printState()
        elseif self.state == StickyFeetStateMachine.STATES.BOTH_MOVING then
            self.state = StickyFeetStateMachine.STATES.PLAYER_MOVING
            self:printState()
        -- else: remain in same state
        end
    end
    self.vehicleIsMoving = isMoving
end