---@class PlayerVehicleTracker
---This class keeps track of which player is above which vehicle

PlayerVehicleTracker = {}
local PlayerVehicleTracker_mt = Class(PlayerVehicleTracker)

---Creates a new object which keeps track of which player is above which vehicle
---@return table @The new instance
function PlayerVehicleTracker.new()
    local self = setmetatable({}, PlayerVehicleTracker_mt)

    -- The current vehicle which was found by the algorithm. This is only valid temporarily
    self.lastVehicleMatch = nil

    self.debugPlayerPos = true

    self.debugTempSwitch = false
    self.debugTempSwitch2 = false
    self.debugTempSwitchId = nil
    self.debugTempSwitchId2 = nil
    return self
end

-- TEMP
---Registers an action event which will trigger on key press
---@param eventKey string @The event key from the modDesc.xml
---@param callbackFunction function @The function to be called on press
---@return boolean @True if event registration was succesful, false if events had been registered already
---@return string @The ID of the action event
function PlayerVehicleTracker:registerOnPressAction(eventKey, callbackFunction)
    -- Register the action. Bool variables: Trigger on key release, trigger on key press, trigger always, unknown
    local registrationSuccessful, actionEventId = g_inputBinding:registerActionEvent(eventKey, self, callbackFunction, false, true, false, true)
    if registrationSuccessful then
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGHEST)
        g_inputBinding:setActionEventActive(actionEventId, true)
        g_inputBinding:setActionEventText(actionEventId, "Debug switch")
    end
    return registrationSuccessful, actionEventId
end
function PlayerVehicleTracker:temp_registerActionEvents()
    local isValid, actionEventId = self:registerOnPressAction('RA_DEBUG_BUTTON', PlayerVehicleTracker.activateDebugSwitch)
    if isValid then self.debugTempSwitchId = actionEventId end
    isValid, actionEventId = self:registerOnPressAction('RA_DEBUG_BUTTON2', PlayerVehicleTracker.activateDebugSwitch2)
    if isValid then self.debugTempSwitchId2 = actionEventId end
end
function PlayerVehicleTracker:temp_updateActionEvents()
    if self.debugTempSwitchId ~= nil then
        g_inputBinding:setActionEventActive(self.debugTempSwitchId, true)
        g_inputBinding:setActionEventActive(self.debugTempSwitchId2, true)
    end
end
function PlayerVehicleTracker:activateDebugSwitch()
    dbgPrint("Enabling switch 1")
    self.debugTempSwitch = true
end
function PlayerVehicleTracker:activateDebugSwitch2()
    dbgPrint("Enabling switch 2")
    self.debugTempSwitch2 = true
end

---Updates internal states based on whether or not a vehicle is below that player.
---@param player table @The player to be inspected
function PlayerVehicleTracker:after_player_updateTick(player)
    -- TEMP
    if not self.debugTempSwitch then

        -- Render position information for debugging when desired
        if self.debugPlayerPos then
            if player.trackedVehicle ~= nil then
                local playerRadius, playerHeight = player.model:getCapsuleSize()
                DebugUtil.drawDebugNode(player.rootNode, "Player", false, 0)
                local playerWorldX, playerWorldY, playerWorldZ = player:getPositionData()
                DebugUtil.drawDebugCubeAtWorldPos(
                    playerWorldX, playerWorldY, playerWorldZ,
                    1,0,0, 0,1,0, playerRadius, playerHeight * 2, playerRadius, 1,0,0)

                if self.lastVehicleMatch ~= nil then
                    DebugUtil.drawDebugCubeAtWorldPos(
                        self.lastVehicleMatch.x, self.lastVehicleMatch.y + playerHeight, self.lastVehicleMatch.z,
                        1,0,0, 0,1,0, playerRadius, playerHeight * 2, playerRadius, 0,0,1)

                    if self.debugTempSwitch2 then
                        -- teleport once
                        player.desiredGlobalPos = {
                            x = self.lastVehicleMatch.x, y = self.lastVehicleMatch.y + playerHeight, z = self.lastVehicleMatch.z
                        }
                        self.debugTempSwitch2 = false
                    end
                end
            end
        end
        return
    else
        dbgPrint("Raycasting vehicle once")
        self.debugTempSwitch = false -- only once
    end

    if not player.isClient or player ~= g_currentMission.player then return end

    -- If the player is not active as a person in the map, e.g. because they are sitting inside a vehicle, stop tracking
    if not player.isEntered then
        if player.trackedVehicle ~= nil then
            dbgPrint(("Player ID %d is no longer tracking vehicle ID %d since player.isEntered = false"):format(player.id, player.trackedVehicle.id))
            player.trackedVehicle = nil
            player.trackedVehicleCoords = nil
            player.desiredGlobalPos = nil
        end
        return
    end

    -- Find the first vehicle below the player
    self.lastVehicleMatch = nil
    local playerWorldX, playerWorldY, playerWorldZ = player:getPositionData()
    local maxDistance = 2
    raycastAll(playerWorldX, playerWorldY, playerWorldZ, 0,-1,0, "vehicleRaycastCallback", maxDistance, self, CollisionMask.VEHICLE)

    -- Remember data about the matched location (if any)
    if self.lastVehicleMatch ~= nil then
        local isStillTheSameVehicle = player.trackedVehicle ~= nil and player.trackedVehicle.id == self.lastVehicleMatch.object.id
        if not isStillTheSameVehicle then
            dbgPrint(("Player ID %d is now tracking vehicle ID %d"):format(player.id, self.lastVehicleMatch.object.id))
        end
        -- Find the local coordinates of the vehicle at the matched location
        local xVehicle, yVehicle, zVehicle = worldToLocal(self.lastVehicleMatch.object.rootNode, self.lastVehicleMatch.x, self.lastVehicleMatch.y + player.model.capsuleHeight, self.lastVehicleMatch.z)
        player.trackedVehicle = self.lastVehicleMatch.object
        if not isStillTheSameVehicle or player.isMoving then
            -- Only update the tracking location if the player is moving or if this is the first call for this vehicle.
            -- While the player is stationary, these coordinates mustn't be changed.
            dbgPrint("Updating tracked vehicle coordinates")
            player.trackedVehicleCoords = { x = xVehicle, y = yVehicle, z = zVehicle }
            player.desiredGlobalPos = nil
        elseif player.trackedVehicle.isMoving then
            dbgPrint("Updating desired global pos since player is locked and not moving, but the vehicle is moving")
            local desiredGlobalPos = {}
            desiredGlobalPos.x, desiredGlobalPos.y, desiredGlobalPos.z =
                localToWorld(player.trackedVehicle.rootNode, player.trackedVehicleCoords.x, player.trackedVehicleCoords.y, player.trackedVehicleCoords.z)
            player.desiredGlobalPos = desiredGlobalPos
        else
            -- Neither player or vehicle are moving; nothing to do
            player.desiredGlobalPos = nil
        end
    else
        if player.trackedVehicle ~= nil then
            dbgPrint(("Player ID %d is no longer tracking vehicle ID %d since they are no longer on the vehicle"):format(player.id, player.trackedVehicle.id))
            player.trackedVehicle = nil
            player.trackedVehicleCoords = nil
            player.desiredGlobalPos = nil
        end
    end
end

---This is called by the game engine when an object which matches the VEHICLE collision mask was found below the player
---@param potentialVehicleId number @The ID of the object which was found
---@param x number @The world X coordinate of the match location
---@param y number @The world Y coordinate of the match location
---@param z number @The world Z coordinate of the match location
---@param distance number @The distance between the player and the match location
---@return boolean @False if the search should be stopped, true if it should be continued
function PlayerVehicleTracker:vehicleRaycastCallback(potentialVehicleId, x, y, z, distance)
    if potentialVehicleId ~= nil and potentialVehicleId ~= 0 then
        local object = g_currentMission:getNodeObject(potentialVehicleId)
        if object ~= nil and object:isa(Vehicle) then
            self.lastVehicleMatch = { object = object, x = x, y = y, z = z, distance = distance }

            -- Stop searching
            return false
        end
    end

    -- Any other case: continue searching
    return true
end

function PlayerVehicleTracker:after_player_writeUpdateStream(player, streamId, connection, dirtyMask)
    -- Send vehicle tracking data only for the own player on each client
    local positionNeedsToBeAdjusted = player.desiredGlobalPos ~= nil
    streamWriteBool(streamId, positionNeedsToBeAdjusted)
    if positionNeedsToBeAdjusted then
       -- distribute the desired global position to the server and other clients
       streamWriteFloat32(streamId, player.desiredGlobalPos.x)
       streamWriteFloat32(streamId, player.desiredGlobalPos.y)
       streamWriteFloat32(streamId, player.desiredGlobalPos.z)
    end
end

function PlayerVehicleTracker:after_player_readUpdateStream(player, streamId, timestamp, connection)
    local positionNeedsToBeAdjusted = streamReadBool(streamId)
    if positionNeedsToBeAdjusted then
        -- Due to when player data is being written, this can only mean this is another player or it was sent from the server
        if player == g_currentMission.player then
            Logging.warning(MOD_NAME .. ": A client received vehicle tracking data for their own player. This shouldn't have happened, so please report this to the mod author via github")
            return
        end
        player.desiredGlobalPos = {
            x = streamReadFloat32(streamId),
            y = streamReadFloat32(streamId),
            z = streamReadFloat32(streamId)
        }
        -- The position will be applied through PlayerLockhandler
    end
end