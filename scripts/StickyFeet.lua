local modDirectory = g_currentModDirectory or ""
MOD_NAME = g_currentModName or "unknown"

StickyFeet = {}

local mainStateMachine = StickyFeetStateMachine.new()
local playerVehicleTracker = PlayerVehicleTracker.new(mainStateMachine)
local vehicleMovementTracker = VehicleMovementTracker.new(mainStateMachine)
local playerMovementStateMachine = PlayerMovementStateMachine.new(mainStateMachine)
local debugSwitch = false
function dbgPrint(text)
    if debugSwitch then
        print(("%s [%.4f]: %s"):format(MOD_NAME, g_currentMission.environment.dayTime / 1000, text))
    end
end

-- Delay method registration as otherwise mods which override but don't call superFunc would break our mod
-- If you use this approach in your own mod, please don't override anything without calling superFunc
Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, function(...)

    -- Track player movement and vehicle below player
    Player.update = Utils.appendedFunction(Player.update, function(player, dt)
        playerMovementStateMachine:checkMovementState(player)
        playerVehicleTracker:checkForVehicleBelow(player, dt)
    end)
    Player.writeUpdateStream = Utils.appendedFunction(Player.writeUpdateStream, function(player, streamId, connection, dirtyMask)
        playerVehicleTracker:after_player_writeUpdateStream(player, streamId, connection, dirtyMask)
    end)
    Player.readUpdateStream = Utils.appendedFunction(Player.readUpdateStream, function(player, streamId, timestamp, connection)
        playerVehicleTracker:after_player_readUpdateStream(player, streamId, timestamp, connection)
    end)

    -- Track vehicle movement
    Vehicle.update = Utils.appendedFunction(Vehicle.update, function(vehicle, ...)
        vehicleMovementTracker:checkVehicle(vehicle)
    end)
end)