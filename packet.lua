-- packet.lua
local types = require("types")

local packet = {}

function packet.encode(id, payload)
    payload = payload or ""

    local body = types.writeVarInt(id) .. payload
    return types.writeVarInt(#body) .. body
end

function packet.decode(client)
    local length = types.readVarInt(client)

    local data = types.readBytes(client, length)

    local id, offset = types.readVarIntFromString(data)

    return {
        length = length,
        id = id,
        data = data,
        offset = offset
    }
end

return packet