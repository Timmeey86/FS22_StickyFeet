local modDirectory = g_currentModDirectory or ""
MOD_NAME = g_currentModName or "unknown"

StickyFeet = {}

-- Create an object which finds and keeps track of the current vehicle below the player
local debugSwitch = true
local pathDebuggerSwitch = true
local pathDebugger = PathDebugger.new(pathDebuggerSwitch)
local playerVehicleTracker = PlayerVehicleTracker.new()
local vehicleMovementTracker = VehicleMovementTracker.new(pathDebugger)
local playerMovementStateMachine = PlayerMovementStateMachine.new(pathDebugger)
local playerLockHandler = PlayerLockHandler.new(pathDebugger)
function dbgPrint(text)
    if debugSwitch then
        print(("%s [%.4f]: %s"):format(MOD_NAME, g_currentMission.environment.dayTime / 1000, text))
    end
end

-- Delay method registration as otherwise mods which override but don't call superFunc would break our mod
-- If you use this approach in your own mod, please don't override anything without calling superFunc
Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, function(...)

    -- Track player movement and vehicle below player
    -- Note to self: State Machines should always be updated first so any state changes can be processed within the same update() call
    Player.update = Utils.appendedFunction(Player.update, function(player, ...)
    end)
    Player.writeUpdateStream = Utils.appendedFunction(Player.writeUpdateStream, function(player, streamId, connection, dirtyMask)
        playerMovementStateMachine:after_player_writeUpdateStream(player, streamId, connection, dirtyMask)
        playerVehicleTracker:after_player_writeUpdateStream(player, streamId, connection, dirtyMask)
    end)
    Player.readUpdateStream = Utils.appendedFunction(Player.readUpdateStream, function(player, streamId, timestamp, connection)
        playerMovementStateMachine:after_player_readUpdateStream(player, streamId, timestamp, connection)
        playerVehicleTracker:after_player_readUpdateStream(player, streamId, timestamp, connection)
    end)
    Player.update = Utils.prependedFunction(Player.update, function(player, ...)
        pathDebugger:update()
        playerMovementStateMachine:before_player_update(player)
        playerVehicleTracker:before_player_update(player)
        playerLockHandler:before_player_update(player)
    end)
    Player.movePlayer = Utils.overwrittenFunction(Player.movePlayer, function(player, superFunc, dt, movementX, movementY, movementZ)
        playerLockHandler:instead_of_player_movePlayer(player, superFunc, dt, movementX, movementY, movementZ)
    end)
    Player.draw = Utils.appendedFunction(Player.draw, function(...)
        pathDebugger:draw()
    end)
    Player.updateTick = Utils.prependedFunction(Player.updateTick, function(player, ...)
        pathDebugger:recordPlayerUpdateTickCall()
    end)

    -- Track vehicle movement
    Vehicle.update = Utils.appendedFunction(Vehicle.update, function(vehicle, ...)
        vehicleMovementTracker:after_vehicle_updateTick(vehicle)
    end)
end)