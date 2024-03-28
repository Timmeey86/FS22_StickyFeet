---@class PlayerLockHandler
---This class automatically locks the player in place while they are above a vehicle which is moving and they're not moving themselves

PlayerLockHandler = {}
local PlayerLockHandler_mt = Class(PlayerLockHandler)

---Creates a new object which locks the player in place while they are above a vehicle and not moving, and adjusts their speed when moving above a vehicle
---@param playerMovementTracker table @The object which keeps track of whether or not the player is moving
---@param vehicleMovementTracker table @The object which keeps track of whether or not the vehicle is moving
---@param playerVehicleTracker table @The object which keeps track of which player is above which vehicle
---@return table @The new instance
function PlayerLockHandler.new(playerMovementTracker, vehicleMovementTracker, playerVehicleTracker)
    local self = setmetatable({}, PlayerLockHandler_mt)
    self.playerMovementTracker = playerMovementTracker
    self.vehicleMovementTracker = vehicleMovementTracker
    self.playerVehicleTracker = playerVehicleTracker
    self.playerLockStates = {}
    self.desiredPlayerLocations = {}
    return self
end

function PlayerLockHandler:before_player_updateTick(player)
    if not player.isClient or player ~= g_currentMission.player then return end

    local playerToVehicleData = self.playerVehicleTracker.playerToVehicleData[player]
    if playerToVehicleData == nil then
        return
    end

    local vehicleBelowPlayer = playerToVehicleData.vehicle
    local vehicleMovementData = self.vehicleMovementTracker.vehicleMovementData[vehicleBelowPlayer]
    if vehicleMovementData == nil then
        -- most likely vehicle:updateTick hasn't been called for that vehicle yet, e.g. because the vehicle is not moving
        return -- and the next updateTick() call should no longer end up here
    end

    local playerIsMoving = self.playerMovementTracker.playerMovingStates[player]

    -- At this point: The player movement is being tracked, the vehicle movement is being tracked, and the player is above the vehicle
    if not player.isEntered then
        -- player is inside a vehicle or something. This can happen dependent on the order of updateTick calls
        return
    end

    -- Initialize the locking state (less if clauses later on)
    if self.playerLockStates[player] == nil then
        self.playerLockStates[player] = {
            isLocked = false,
            lockPosition = nil
        }
    end

    local directionVector = vehicleMovementData.directionVector
    if not playerIsMoving then

        if not self.playerLockStates[player].isLocked then
            local playerPosition = self.playerMovementTracker.currentPlayerPositions[player]
            -- player is now becoming locked, remember the local position of the player on the vehicle
            local xVehicleLocal, yVehicleLocal, zVehicleLocal = worldToLocal(vehicleBelowPlayer.rootNode, playerPosition.x, playerPosition.y, playerPosition.z)
            self.playerLockStates[player].isLocked = true
            self.playerLockStates[player].lockPosition = {
                x = xVehicleLocal,
                y = yVehicleLocal,
                z = zVehicleLocal
            }
        end

        if directionVector ~= nil and (directionVector.x ~= 0 or directionVector.y ~= 0 or directionVector.z ~= 0) then
            -- Lock the player in place
            local lockPosition = self.playerLockStates[player].lockPosition
            local worldX, worldY, worldZ = localToWorld(vehicleBelowPlayer.rootNode, lockPosition.x, lockPosition.y, lockPosition.z)
            self.desiredPlayerLocations[player] = { x = worldX, y = worldY, z = worldZ }
            -- In addition to sending the event, move the player locally already so the player zaps around less
            setTranslation(player.rootNode, worldX, worldY, worldZ)
        end
    else
        self.playerLockStates[player].isLocked = false
        -- Add the vehicle direction to the player movement data
        if directionVector ~= nil then
            if directionVector.x ~= 0 or directionVector.y ~= 0 or directionVector.z ~= 0 then
                local x,y,z = localToWorld(player.rootNode, 0, 0, 0)
                x = x + directionVector.x
                y = y + directionVector.y
                z = z + directionVector.z
                self.desiredPlayerLocations[player] = { x = x, y = y, z = z }
                -- In addition to sending the event, move the player locally already so the player zaps around less
                setTranslation(player.rootNode, x, y, z)
            end
        end
    end
end

function PlayerLockHandler:after_player_writeUpdateStream(player, streamId, connection, dirtyMask)
    local desiredPlayerLocation = self.desiredPlayerLocations[player]
    local desiredLocationShallBeSent = connection:getIsServer() and player.isOwner and desiredPlayerLocation ~= nil
    streamWriteBool(streamId, desiredLocationShallBeSent)

    if desiredLocationShallBeSent then
        print(("%s: Asking server to move player to %.3f, %.3f, %.3f"):format(MOD_NAME, desiredPlayerLocation.x, desiredPlayerLocation.y, desiredPlayerLocation.z))
        streamWriteFloat32(streamId, desiredPlayerLocation.x)
        streamWriteFloat32(streamId, desiredPlayerLocation.y)
        streamWriteFloat32(streamId, desiredPlayerLocation.z)
        -- Reset the desired location so it doesn't get sent endlessly
        self.desiredPlayerLocations[player] = nil
    end
end

function PlayerLockHandler:after_player_readUpdateStream(player, streamId, timestamp, connection)
    local desiredLocationWasSent = streamReadBool(streamId)

    if desiredLocationWasSent then
        -- This should only ever happen on the server since the flag will be false in all other cases
        local x, y, z = streamReadFloat32(streamId), streamReadFloat32(streamId), streamReadFloat32(streamId)
        print(("%s: Client wants to move player to %.3f, %.3f, %.3f"):format(MOD_NAME, x, y, z))
        setTranslation(player.rootNode, x, y, z)
    end
end