local modDirectory = g_currentModDirectory or ""
MOD_NAME = g_currentModName or "unknown"

StickyFeet = {}

local debugStateMachineSwitch = false
local debugSwitch = false
local debugVehicleDetection = false
local mainStateMachine = StickyFeetStateMachine.new(debugStateMachineSwitch)
local vehicleRaycastHelper = VehicleRaycastHelper.new(debugVehicleDetection)
local playerVehicleTracker = PlayerVehicleTracker.new(mainStateMachine, vehicleRaycastHelper, debugVehicleDetection)
local vehicleMovementTracker = VehicleMovementTracker.new(mainStateMachine)
local playerMovementStateMachine = PlayerMovementStateMachine.new(mainStateMachine)
function dbgPrint(text)
	if debugSwitch then
		print(("%s [%.4f]: %s"):format(MOD_NAME, g_currentMission.environment.dayTime / 1000, text))
	end
end

-- Remove the PLAYER bit from the AI collision mask so field workers don't stop working when the player is near the vehicle
AICollisionTriggerHandler.COLLISION_MASK = bitAND(AICollisionTriggerHandler.COLLISION_MASK, bitNOT(CollisionFlag.PLAYER))

-- Prevent AI drivers from treating the player as an obstacle
Player.show = Utils.appendedFunction(Player.show, function(player,...)
	if g_currentMission and g_currentMission.aiSystem then
		g_currentMission.aiSystem:removeObstacle(player.rootNode)
	end
end)

-- Delay method registration as otherwise mods which override but don't call superFunc would break our mod
-- If you use this approach in your own mod, please don't override anything without calling superFunc
Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, function(...)

	-- Track player movement and vehicle below player
	Player.update = Utils.appendedFunction(Player.update, function(player, dt)
		playerMovementStateMachine:checkMovementState(player)
		playerVehicleTracker:checkForVehicleBelow(player, dt)
	end)
	PlayerGraphicsState.updateRemote = Utils.appendedFunction(PlayerGraphicsState.updateRemote, function(graphicsState, player)
		playerVehicleTracker:adjustAnimationParameters(graphicsState, player)
	end)

	-- Track vehicle movement
	Vehicle.update = Utils.appendedFunction(Vehicle.update, function(vehicle, ...)
		vehicleMovementTracker:checkVehicle(vehicle)
	end)

	if debugVehicleDetection then
		-- Draw vehicle root nodes to help understand debugging output bettter
		BaseMission.draw = Utils.appendedFunction(BaseMission.draw, function(baseMission)
			for _, vehicle in pairs(baseMission.vehicleSystem.vehicles) do
				DebugUtil.drawDebugNode(vehicle.rootNode, tostring(vehicle.id), false)
			end
		end)
	end
end)