local modDirectory = g_currentModDirectory or ""
MOD_NAME = g_currentModName or "unknown"

StayOnTrailer = {}

-- Create an object which finds and keeps track of the current vehicle below the player
local playerVehicleTracker = PlayerVehicleTracker.new()
local playerMovementTracker = PlayerMovementTracker.new()
local vehicleMovementTracker = VehicleMovementTracker.new(playerVehicleTracker)
local playerLockHandler = PlayerLockHandler.new(playerMovementTracker, vehicleMovementTracker, playerVehicleTracker)


-- Delay method registration as otherwise mods which override but don't call superFunc would break our mod
-- If you use this approach in your own mod, please don't override anything without calling superFunc
Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, function(...)
    Player.updateTick = Utils.prependedFunction(Player.updateTick, function(player, ...)
        playerLockHandler:before_player_updateTick(player)
    end)
    Player.updateTick = Utils.appendedFunction(Player.updateTick, function(player, ...)
        playerVehicleTracker:after_player_updateTick(player)
        playerMovementTracker:after_player_updateTick(player)
     end)
    Vehicle.updateTick = Utils.appendedFunction(Vehicle.updateTick, function(vehicle, ...)
        vehicleMovementTracker:after_vehicle_updateTick(vehicle)
    end)
end)