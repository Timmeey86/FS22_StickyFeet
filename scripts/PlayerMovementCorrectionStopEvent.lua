---@class PlayerMovementCorrectionStopEvent
---This event is sent from a client to the server (and ultimately all other clients) when player position correction shall stop
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
---@return table @The new instance
function PlayerMovementCorrectionStopEvent.new(player)
	assert(player, "Player is nil in PlayerMovementCorrectionStopEvent")
	local self = PlayerMovementCorrectionStopEvent.emptyNew()
	self.player = player
	return self
end

---Reads an event from the network. This can happen in two cases:
---1) This is executed on the server, and a client sent the event
---2) This is executed on the client, and the server forwarded a client event to all other clients
---@param streamId table @The ID of the network stream
---@param connection table @Details about the network connection
function PlayerMovementCorrectionStopEvent:readStream(streamId, connection)
	self.player = NetworkUtil.readNodeObject(streamId)

	if self.player ~= nil then
		self:run(connection)
	else
		Logging.warning(MOD_NAME .. ": Received a movement correction stop event with nil data. Player might be unable to move")
	end
end

---Sends event data to other network participants. This can happen in two cases:
---1) This is executed on the client which initially sends the event
---2) This is executed on the server which broadcasts a copy of the event to all other clients
---@param streamId table @The ID of the network stream
function PlayerMovementCorrectionStopEvent:writeStream(streamId, _)
	NetworkUtil.writeNodeObject(streamId, self.player)
end

---Executes the event, and on the server, also broadcasts the event to all other clients
function PlayerMovementCorrectionStopEvent:run(connection)
	self.player.syncedLockVehicle = nil
	self.player.syncedLockCoords = nil
	self.player.syncedCoordsAreGlobalCoords = false
	self.player.syncedForwardVelocity = nil

	if not connection:getIsServer() then
		-- If we are not connected to the server, that means we are the server. Distribute the event to other players
		g_server:broadcastEvent(PlayerMovementCorrectionStopEvent.new(self.player), nil, connection, self.player)
	end
end