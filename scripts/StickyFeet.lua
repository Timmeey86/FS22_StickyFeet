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

local debugPlugin = "C:/Temp/DebugPlugin.lua"
if fileExists(debugPlugin) then
    print("Loading debug plugin")
    source(debugPlugin)
end

-- Delay method registration as otherwise mods which override but don't call superFunc would break our mod
-- If you use this approach in your own mod, please don't override anything without calling superFunc
Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, function(...)

    -- Track player movement and vehicle below player
    Player.update = Utils.appendedFunction(Player.update, function(player, ...)
        playerMovementStateMachine:checkMovementState(player)
        playerVehicleTracker:checkForVehicleBelow(player)

        local pX,pY,pZ = localToWorld(player.rootNode, 0, 0, 0)
        local gfxX, gfxY, gfxZ = localToWorld(player.graphicsRootNode, 0, 0, 0)
        
        if player.desiredGlobalPos ~= nil then
            local playerNodeDiff = {
                x = player.desiredGlobalPos.x - pX,
                y = player.desiredGlobalPos.y - pY,
                z = player.desiredGlobalPos.z - pZ
            }
            local gfxNodeDiff = {
                x = gfxX - pX,
                y = gfxY - pY,
                z = gfxZ - pZ
            }
            print(("Player to Desired Pos offset is %.3f, %.3f, %.3f"):format(playerNodeDiff.x, playerNodeDiff.y, playerNodeDiff.z))
            print(("Gfx to Player Pos offset is %.3f, %.3f, %.3f"):format(gfxNodeDiff.x, gfxNodeDiff.y, gfxNodeDiff.z))
        end
    end)
    Player.writeUpdateStream = Utils.appendedFunction(Player.writeUpdateStream, function(player, streamId, connection, dirtyMask)
        playerMovementStateMachine:after_player_writeUpdateStream(player, streamId, connection, dirtyMask)
        playerVehicleTracker:after_player_writeUpdateStream(player, streamId, connection, dirtyMask)
    end)
    Player.readUpdateStream = Utils.appendedFunction(Player.readUpdateStream, function(player, streamId, timestamp, connection)
        playerMovementStateMachine:after_player_readUpdateStream(player, streamId, timestamp, connection)
        playerVehicleTracker:after_player_readUpdateStream(player, streamId, timestamp, connection)
    end)

    -- Track vehicle movement
    Vehicle.update = Utils.appendedFunction(Vehicle.update, function(vehicle, ...)
        vehicleMovementTracker:checkVehicle(vehicle)
    end)
end)

Player.draw = Utils.overwrittenFunction(Player.draw, function(player, superFunc)
    superFunc(player)

    DebugUtil.drawDebugNode(player.rootNode, "Player", false)
    DebugUtil.drawDebugNode(player.graphicsRootNode, "GfxNode", false)
    if player.trackedVehicleCoords ~= nil and mainStateMachine.trackedVehicle ~= nil then
        local x,y,z = localToWorld(mainStateMachine.trackedVehicle.rootNode, player.trackedVehicleCoords.x, player.trackedVehicleCoords.y, player.trackedVehicleCoords.z)
        DebugUtil.drawDebugCircle(x, y, z, 0.05, 32, {1,0,0})
    end
    if player.desiredGlobalPos ~= nil then
        DebugUtil.drawDebugCircle(player.desiredGlobalPos.x, player.desiredGlobalPos.y, player.desiredGlobalPos.z, 0.05, 32, {0,0,1})
    end
    if mainStateMachine.trackedVehicle ~= nil then
        local vehicle = mainStateMachine.trackedVehicle
        DebugUtil.drawDebugNode(vehicle.rootNode, "Vehicle", false)
    end
end)

-- TEMP
local DebugHelper = {}
local DebugHelper_mt = Class(DebugHelper)
g_movementBehavior = 0
function DebugHelper.new()
    return setmetatable({}, DebugHelper_mt)
end
function DebugHelper:keyEvent(unicode, sym, modifier, isDown)
    if sym == Input["KEY_home"] and isDown == true then
        --g_movementBehavior = (g_movementBehavior + 1) % 5
        --print("Movement behavior is now " .. tostring(g_movementBehavior))
        if g_currentMission and g_currentMission.player then
            print("Moving ten meters in X direction")
            g_currentMission.player:movePlayer(0, 10, 0, 0)
        end
    end
end

local debugHelper = DebugHelper.new()
FSBaseMission.load = Utils.prependedFunction(FSBaseMission.load, function() addModEventListener(debugHelper) end)
FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, function() removeModEventListener(debugHelper) end)