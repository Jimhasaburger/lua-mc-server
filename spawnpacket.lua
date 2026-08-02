-- spawnpacket.lua
local types = require("types")
local packet = require("packet")

local spawnpacket = {}

local function packPosition(x, y, z)
    local val = ((x & 0x3FFFFFF) << 38) | ((z & 0x3FFFFFF) << 12) | (y & 0xFFF)
    if val >= 2 ^ 63 then
        val = val - 2 ^ 64
    end
    return types.writeLong(val)
end

function spawnpacket.encode(f)
    local payload =
        types.writeIdentifier(f.dimensionName) ..
        packPosition(f.location.x, f.location.y, f.location.z) ..
        types.writeFloat(f.yaw) ..
        types.writeFloat(f.pitch)

    return packet.encode(0x61, payload)
end

return spawnpacket
