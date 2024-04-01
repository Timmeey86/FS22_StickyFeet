---@class PlayerMovementStateChangedEvent
---This event is sent when the movement state of the controlled player changes on their own client
PlayerMovementStateChangedEvent = {}
local PlayerMovementStateChangedEvent_mt = Class(PlayerMovementStateChangedEvent, Event)

InitEventClass(PlayerMovementStateChangedEvent, "PlayerMovementStateChangedEvent")

---Creates a new empty event
---@return table @The new instance
function PlayerMovementStateChangedEvent.emptyNew()
	return Event.new(PlayerMovementStateChangedEvent_mt)
end

---Creates a new event
---@param player table @The player which changed their state
---@param isMoving boolean @True if the player is now moving
---@return table @The new instance
function PlayerMovementStateChangedEvent.new(player, isMoving)
	local self = PlayerMovementStateChangedEvent.emptyNew()
    self.player = player
    self.isMoving = isMoving
    return self
end

---Reads settings which were sent by another network participant and then applies them locally
---@param streamId any @The ID of the stream to read from.
---@param connection any @The connection to use.
function PlayerMovementStateChangedEvent:readStream(streamId, connection)
    local player = NetworkUtil.readNodeObject(streamId)
    local isMoving = streamReadBool(streamId)
    local x,y,z = streamReadFloat32(streamId), streamReadFloat32(streamId), streamReadFloat32(streamId)
    if player.isMoving ~= isMoving then
        dbgPrint(("Changing moving state for player id %d to %s due to a received event"):format(player.id, isMoving))
        local x1,y1,z1 = localToWorld(player.rootNode, 0,0,0)
        dbgPrint(("Server location: %.1f, %.1f, %.1f; Event location: %.1f, %.1f, %.1f"):format(x1,y1,z1,x,y,z))
    end
    player.isMoving = isMoving
    if not connection:getIsServer() then
        -- if we are not connected to the server, i.e. we are the server: broadcast to other clients
        g_server:broadcastEvent(PlayerMovementStateChangedEvent.new(player, isMoving), nil, connection, nil)
        dbgPrint(("Received moving state %s for player id %d from the client of that player"):format(isMoving, player.id))
    else
        -- We are another client
        dbgPrint(("Received moving state %s for player id %d from the server"):format(isMoving, player.id))
    end
end

---Sends event data from a client to the server
---@param streamId any @The ID of the stream to write to.
---@param connection any @The connection to use.
function PlayerMovementStateChangedEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.player)
    streamWriteBool(streamId, self.isMoving)
    local x,y,z = localToWorld(self.player.rootNode,0,0,0)
    streamWriteFloat32(streamId, x)
    streamWriteFloat32(streamId, y)
    streamWriteFloat32(streamId, z)
end