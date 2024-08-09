---@class PlayerMovementCorrectionStopEvent
---This event is sent from a client to the server (and ultimately all other clients) when the player position needs to be corrected because
---of the StickyFeet mod moving them.
PlayerMovementCorrectionStopEvent = {}
local PlayerMovementCorrectionStopEvent_mt = Class(PlayerMovementCorrectionStopEvent, Event)

InitEventClass(PlayerMovementCorrectionStopEvent, "PlayerMovementCorrectionStopEvent")

---Creates an empty event with the correct meta table
---@return table @The new instance
function PlayerMovementCorrectionStopEvent.emptyNew()
    return Event.new(PlayerMovementCorrectionStopEvent_mt)
end

---Creates a new movement correction event. All arguments must be non-nil
---@param player table @The player to be moved
---@param vehicle table @The vehicle below the player
---@param coordinatesOnVehicle table @The X/Y/Z coordinates in local vehicle coordinates
---@param forwardSpeed number @The current forward speed of the player (affects the model animation)
---@return table @The new instance
function PlayerMovementCorrectionStopEvent.new(player, vehicle, coordinatesOnVehicle, forwardSpeed)
    assert(player, "Player is nil in PlayerMovementCorrectionStopEvent")
    assert(vehicle, "Vehicle is nil in PlayerMovementCorrectionStopEvent")
    assert(coordinatesOnVehicle, "Coordinates are nil in PlayerMovementCorrectionStopEvent")
    assert(forwardSpeed, "Forward speed is nil in PlayerMovementCorrectionStopEvent")
    local self = PlayerMovementCorrectionStopEvent.emptyNew()
    self.player = player
    self.vehicle = vehicle
    self.coordinatesOnVehicle = coordinatesOnVehicle
    self.forwardSpeed = forwardSpeed
    return self
end

---Reads an event from the network. This can happen in two cases:
---1) This is executed on the server, and a client sent the event
---2) This is executed on the client, and the server forwarded a client event to all other clients
---@param streamId table @The ID of the network stream
---@param connection table @Details about the network connection
function PlayerMovementCorrectionStopEvent:readStream(streamId, connection)
    self.player = NetworkUtil.readNodeObject(streamId)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.coordinatesOnVehicle = {
        x = streamReadFloat32(streamId),
        y = streamReadFloat32(streamId),
        z = streamReadFloat32(streamId)
    }
    self.forwardSpeed = streamReadFloat32(streamId)

    if self.player ~= nil and self.vehicle ~= nil and self.coordinatesOnVehicle.x ~= nil and self.coordinatesOnVehicle.y ~= nil and self.coordinatesOnVehicle.z ~= nil and self.forwardSpeed ~= nil then
        self:run(connection)
    else
        Logging.warning(MOD_NAME .. ": Received a movement correction event with nil data")
    end
end

---Sends event data to other network participants. This can happen in two cases:
---1) This is executed on the client which initially sends the event
---2) This is executed on the server which broadcasts a copy of the event to all other clients
---@param streamId table @The ID of the network stream
function PlayerMovementCorrectionStopEvent:writeStream(streamId, _)
    NetworkUtil.writeNodeObject(streamId, self.player)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteFloat32(streamId, self.coordinatesOnVehicle.x)
    streamWriteFloat32(streamId, self.coordinatesOnVehicle.y)
    streamWriteFloat32(streamId, self.coordinatesOnVehicle.z)
    streamWriteFloat32(streamId, self.forwardSpeed)
end

---Executes the event, and on the server, also broadcasts the event to all other clients
function PlayerMovementCorrectionStopEvent:run(connection)
    assert(self.vehicle.rootNode, "Vehicle is valid but has no root node")
    -- Only store the network values now. This way, we can update the player position in update() several times per network tick
    self.player.syncedLockVehicle = self.vehicle
    self.player.syncedLockCoords = self.coordinatesOnVehicle
    self.player.syncedForwardVelocity = self.forwardSpeed

    if not connection:getIsServer() then
        -- If we are not connected to the server, that means we are the server. Distribute the event to other players
        g_server:broadcastEvent(PlayerMovementCorrectionStopEvent.new(self.player, self.vehicle, self.coordinatesOnVehicle, self.forwardSpeed), nil, connection, self.player)
    end
end