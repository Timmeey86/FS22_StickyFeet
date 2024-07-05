local modDirectory = g_currentModDirectory or ""
MOD_NAME = g_currentModName or "unknown"

RideAlong = {}

-- Create an object which finds and keeps track of the current vehicle below the player
local playerVehicleTracker = PlayerVehicleTracker.new()
local vehicleMovementTracker = VehicleMovementTracker.new()
local playerMovementStateMachine = PlayerMovementStateMachine.new()
local playerLockHandler = PlayerLockHandler.new()

function dbgPrint(text)
    print(("%s [%.4f]: %s"):format(MOD_NAME, g_currentMission.environment.dayTime / 1000, text))
end

-- Delay method registration as otherwise mods which override but don't call superFunc would break our mod
-- If you use this approach in your own mod, please don't override anything without calling superFunc
Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, function(...)

    -- Track player movement and vehicle below player
    Player.updateTick = Utils.appendedFunction(Player.updateTick, function(player, ...)
        playerMovementStateMachine:after_player_updateTick(player)
        playerVehicleTracker:after_player_updateTick(player)
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
        playerLockHandler:before_player_update(player)
    end)
    Player.movePlayer = Utils.overwrittenFunction(Player.movePlayer, function(player, superFunc, dt, movementX, movementY, movementZ)
        playerLockHandler:instead_of_player_movePlayer(player, superFunc, dt, movementX, movementY, movementZ)
    end)

    -- Track vehicle movement
    Vehicle.updateTick = Utils.appendedFunction(Vehicle.updateTick, function(vehicle, ...)
        vehicleMovementTracker:after_vehicle_updateTick(vehicle)
    end)

    -- TEMP
    Player.registerActionEvents = Utils.appendedFunction(Player.registerActionEvents, function(player) playerVehicleTracker:temp_registerActionEvents() end)
    Player.updateActionEvents = Utils.appendedFunction(Player.updateActionEvents, function(player) playerVehicleTracker:temp_updateActionEvents() end)
end)