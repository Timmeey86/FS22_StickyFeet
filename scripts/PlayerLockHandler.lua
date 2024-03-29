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
    self.desiredPlayerLocations[player] = nil
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
        end
    else
        self.playerLockStates[player].isLocked = false
        -- Add the vehicle direction to the player movement data
        if directionVector ~= nil and (directionVector.x ~= 0 or directionVector.y ~= 0 or directionVector.z ~= 0) then
            local x,y,z = localToWorld(player.rootNode, 0, 0, 0)
            x = x + directionVector.x
            y = y + directionVector.y
            z = z + directionVector.z
            self.desiredPlayerLocations[player] = { x = x, y = y, z = z }
        end
    end
end

---Adjusts the player movement so the player ends up in the desired location
---@param player table @The player to be moved
---@param superFunc function @The existing implementation (base game or already adjusted by mods)
---@param dt number @The delta time
---@param movementX number @The X movement component
---@param movementY number @The Y movement component
---@param movementZ number @The Z movement component
function PlayerLockHandler:instead_of_player_movePlayer(player, superFunc, dt, movementX, movementY, movementZ)
    local desiredLocation = self.desiredPlayerLocations[player]
    if desiredLocation ~= nil then
        local x,y,z = localToWorld(player.rootNode, 0,0,0)
        local xDiff, yDiff, zDiff = desiredLocation.x - x, desiredLocation.y - y, desiredLocation.z - z
        movementX = movementX + xDiff
        movementY = movementY + yDiff
        movementZ = movementZ + zDiff
    end

    superFunc(player, dt, movementX, movementY, movementZ)
end