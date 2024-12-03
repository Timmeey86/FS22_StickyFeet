---@class PlayerMovementCorrectionEvent
---This event is sent from a client to the server (and ultimately all other clients) when the player position needs to be corrected because
---of the StickyFeet mod moving them.
PlayerMovementCorrectionEvent = {}
local PlayerMovementCorrectionEvent_mt = Class(PlayerMovementCorrectionEvent, Event)

InitEventClass(PlayerMovementCorrectionEvent, "PlayerMovementCorrectionEvent")

---Creates an empty event with the correct meta table
---@return table @The new instance
function PlayerMovementCorrectionEvent.emptyNew()
	return Event.new(PlayerMovementCorrectionEvent_mt)
end

---Creates a new movement correction event using global coordinates. All arguments must be non-nil
---@param player table @The player to be moved
---@param coordinates table @The X/Y/Z global coordinates
---@param forwardSpeed number @The current forward speed of the player (affects the model animation)
---@return table @The new instance
function PlayerMovementCorrectionEvent.fromGlobalCoords(player, coordinates, forwardSpeed)
	assert(player, "Player is nil in PlayerMovementCorrectionEvent")
	assert(coordinates, "Coordinates are nil in PlayerMovementCorrectionEvent")
	assert(forwardSpeed, "Forward speed is nil in PlayerMovementCorrectionEvent")
	local self = PlayerMovementCorrectionEvent.emptyNew()
	self.player = player
	self.vehicle = nil
	self.coordinates = coordinates
	self.forwardSpeed = forwardSpeed
	self.isGlobalCoords = true
	return self
end
---Creates a new movement correction event using local vehicle coordinates. All arguments must be non-nil
---@param player table @The player to be moved
---@param vehicle table @The vehicle below the player
---@param coordinates table @The X/Y/Z coordinates in local vehicle coordinates 
---@param forwardSpeed number @The current forward speed of the player (affects the model animation)
---@return table @The new instance
function PlayerMovementCorrectionEvent.fromVehicleCoords(player, vehicle, coordinates, forwardSpeed)
	assert(player, "Player is nil in PlayerMovementCorrectionEvent")
	assert(vehicle, "Vehicle is nil in PlayerMovementCorrectionEvent")
	assert(coordinates, "Coordinates are nil in PlayerMovementCorrectionEvent")
	assert(forwardSpeed, "Forward speed is nil in PlayerMovementCorrectionEvent")
	local self = PlayerMovementCorrectionEvent.emptyNew()
	self.player = player
	self.vehicle = vehicle
	self.coordinates = coordinates
	self.forwardSpeed = forwardSpeed
	self.isGlobalCoords = false
	return self
end

---Reads an event from the network. This can happen in two cases:
---1) This is executed on the server, and a client sent the event
---2) This is executed on the client, and the server forwarded a client event to all other clients
---@param streamId number @The ID of the network stream
---@param connection table @Details about the network connection
function PlayerMovementCorrectionEvent:readStream(streamId, connection)
	self.player = NetworkUtil.readNodeObject(streamId)
	self.isGlobalCoords = streamReadBool(streamId)
	if not self.isGlobalCoords then
		self.vehicle = NetworkUtil.readNodeObject(streamId)
	end
	self.coordinates = {
		x = streamReadFloat32(streamId),
		y = streamReadFloat32(streamId),
		z = streamReadFloat32(streamId)
	}
	self.forwardSpeed = streamReadFloat32(streamId)

	if self.player ~= nil and (self.isGlobalCoords or self.vehicle ~= nil) and self.coordinates.x ~= nil and self.coordinates.y ~= nil and self.coordinates.z ~= nil and self.forwardSpeed ~= nil then
		self:run(connection)
	else
		Logging.warning(MOD_NAME .. ": Received a movement correction event with nil data")
	end
end

---Sends event data to other network participants. This can happen in two cases:
---1) This is executed on the client which initially sends the event
---2) This is executed on the server which broadcasts a copy of the event to all other clients
---@param streamId number @The ID of the network stream
function PlayerMovementCorrectionEvent:writeStream(streamId, _)
	NetworkUtil.writeNodeObject(streamId, self.player)
	streamWriteBool(streamId, self.isGlobalCoords)
	if not self.isGlobalCoords then
		NetworkUtil.writeNodeObject(streamId, self.vehicle)
	end
	streamWriteFloat32(streamId, self.coordinates.x)
	streamWriteFloat32(streamId, self.coordinates.y)
	streamWriteFloat32(streamId, self.coordinates.z)
	streamWriteFloat32(streamId, self.forwardSpeed)
end

---Executes the event, and on the server, also broadcasts the event to all other clients
function PlayerMovementCorrectionEvent:run(connection)
	-- Only store the network values now. This way, we can update the player position in update() several times per network tick
	self.player.syncedLockVehicle = self.vehicle
	self.player.syncedLockCoords = self.coordinates
	self.player.syncedCoordsAreGlobalCoords = self.isGlobalCoords
	self.player.syncedForwardVelocity = self.forwardSpeed

	if not connection:getIsServer() then
		-- If we are not connected to the server, that means we are the server. Distribute the event to other players
		g_server:broadcastEvent(self, nil, connection, self.player)
	end
end