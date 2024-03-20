local modDirectory = g_currentModDirectory or ""
MOD_NAME = g_currentModName or "unknown"

StayOnTrailer = {}

-- Create an object which finds and keeps track of the current vehicle below the player
local vehicleTracker = VehicleTracker.new()


-- Delay method registration as otherwise mods which override but don't call superFunc would break our mod
-- If you use this approach in your own mod, please don't override anything without calling superFunc
Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, function(...)
    -- Find the vehicle below the player on each update call
    Player.update = Utils.appendedFunction(Player.update, function(player, ...)
        vehicleTracker:findVehicleBelowPlayer(player)
    end)

    Player.registerActionEvents = Utils.appendedFunction(Player.registerActionEvents, function(...) vehicleTracker:registerActionEvents() end)
    Player.updateActionEvents = Utils.appendedFunction(Player.updateActionEvents, function(...) vehicleTracker:updateActionEvents() end)
    Player.updateTick = Utils.appendedFunction(Player.updateTick, function(player, ...) vehicleTracker:updateTick(player) end)
end)