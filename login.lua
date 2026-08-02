local login = {}
local types = require("types")
local packet = require("packet")

local md5 = require("md5")

local function offlineUUID(username)
    local data = md5.sum("OfflinePlayer:" .. username)

    -- convert to mutable byte table
    local bytes = {data:byte(1, 16)}

    -- UUID version 3
    bytes[7] = (bytes[7] & 0x0F) | 0x30

    -- UUID variant
    bytes[9] = (bytes[9] & 0x3F) | 0x80

    return string.char(table.unpack(bytes))
end

function login.handle(client)
    print("Login!")

    local pkt = packet.decode(client)
    if pkt.id ~= 0 then
        error("Expected login something idk")
    end
    local offset = pkt.offset

    local name
    name, offset = types.readStringFromString(pkt.data, offset)
    print(name)

    local uuid = offlineUUID(name)

    local sessionUUID = offlineUUID("session:" .. name)

    local payload =
        uuid ..
        types.writeString(name) ..
        types.writeVarInt(0) ..
        sessionUUID

    local loginSuccess = packet.encode(2, payload)

    client:send(loginSuccess)
end

return login