
---@class PlayerLockMoveEvent
---This event is sent when a client wants to move the player which is being controlled by that client,
---or when the server wants all clients to update the position of such a player
PlayerLockMoveEvent = {}
local PlayerLockMoveEvent_mt = Class(PlayerLockMoveEvent, Event)

InitEventClass(PlayerLockMoveEvent, "PlayerLockMoveEvent")

---Creates a new empty event
---@return table @The new instance
function PlayerLockMoveEvent.emptyNew()
	return Event.new(PlayerLockMoveEvent_mt)
end

---Creates a new event
---@param player table @The player to be moved
---@param position table @A table of X, Y and Z coordinates to move the player to
---@return table @The new instance
function PlayerLockMoveEvent.new(player, position)
    local self = PlayerLockMoveEvent.emptyNew()
    self.player = player
    self.position = position
	return self
end

---Reads event data which was sent by either the client which changed values or the server which distributes them
---@param streamId any @The ID of the stream to read from.
---@param connection any @The connection to use.
function PlayerLockMoveEvent:readStream(streamId, connection)
    self.player = NetworkUtil.readNodeObject(streamId)
    self.position = {
        x = streamReadFloat32(streamId),
        y = streamReadFloat32(streamId),
        z = streamReadFloat32(streamId)
    }
    if connection:getIsServer() then
        -- Connected to a server => The client is reading the event => We might not have to do anything (to be verified)
    else
        -- Server is reading the event => Move the player (this should distribute the position back to the clients)
        self:executeMove()
    end
end

---Sends event data from the client to the server, or from the server to other clients
---@param streamId any @The ID of the stream to write to.
---@param connection any @The connection to use.
function PlayerLockMoveEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.player)
    streamWriteFloat32(streamId, self.position.x)
    streamWriteFloat32(streamId, self.position.y)
    streamWriteFloat32(streamId, self.position.z)
end

---Moves the player to the position stored in the event
function PlayerLockMoveEvent:executeMove()
    if self.player ~= nil then
        -- Set the player position
        --local playerX, playerY, playerZ = localToWorld(self.player.rootNode, 0, 0, 0)
        --local playerDiffX, playerDiffY, playerDiffZ = self.position.x - playerX, self.position.y - playerY, self.position.z - playerZ
        --self.player:movePlayer(1, playerDiffX, playerDiffY, playerDiffZ)
        --setTranslation(self.player.rootNode, playerX, playerY, playerZ)

        -- Move the graphics root node by the same relative amount
        -- Without this, the player would zap up and down 30x per second
        --local graphicsX, graphicsY, graphicsZ = localToWorld(self.player.graphicsRootNode, 0, 0, 0)
        --local graphicsNewX, graphicsNewY, graphicsNewZ = graphicsX + playerDiffX, graphicsY + playerDiffY, graphicsZ + playerDiffZ
        --setTranslation(self.player.graphicsRootNode, playerX, graphicsNewY, playerZ)
    else
        print("player is nil")
    end
end