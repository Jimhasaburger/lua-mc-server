local serverlist = {}
local types = require("types")
local packet = require("packet")

local path = "config.json"
local json = require("dkjson")
local f = assert(io.open(path, "r"))
local content = f:read("*a")
f:close()
local config = json.decode(content)

function serverlist.handle(client, handshake)
    local pkt = packet.decode(client)
    if pkt.id ~= 0 then
        error("Expected Status Request")
    end

    local json = string.format(
        [[{"version":{"name":"%s","protocol":%d},"players":{"max":%d,"online":%d,"sample":[]},"description":{"text":"%s"}}]],
        config.server.versionName,
        config.server.protocol,
        config.server.maxPlayers,
        config.server.onlinePlayers,
        config.server.motd
    )

    local response = packet.encode(
        0x00,
        types.writeString(json)
    )

    client:send(response)

    -- Ping
    local ping = packet.decode(client)

    if ping.id ~= 0x01 then
        error("Expected Ping")
    end

    -- packet data after ID is the payload
    local pong = packet.encode(0x01, ping.data:sub(ping.offset))

    client:send(pong)
end
return serverlist