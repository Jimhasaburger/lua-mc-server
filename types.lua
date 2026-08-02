-- types.lua
local types = {}

local function readExact(sock, n)
    local data, err = sock:receive(n)
    if not data then
        error(err)
    end
    return data
end

function types.writeVarInt(value)
    local out = {}

    repeat
        local temp = value & 0x7F
        value = value >> 7

        if value ~= 0 then
            temp = temp | 0x80
        end

        out[#out + 1] = string.char(temp)
    until value == 0

    return table.concat(out)
end

function types.readVarInt(sock)
    local value = 0
    local position = 0

    while true do
        local current = readExact(sock, 1):byte()

        value = value | ((current & 0x7F) << position)

        if (current & 0x80) == 0 then
            break
        end

        position = position + 7

        if position >= 35 then
            error("VarInt too big")
        end
    end

    return value
end

function types.readVarIntFromString(data, offset)
    offset = offset or 1

    local value = 0
    local position = 0

    while true do
        local current = data:byte(offset)
        offset = offset + 1

        value = value | ((current & 0x7F) << position)

        if (current & 0x80) == 0 then
            break
        end

        position = position + 7

        if position >= 35 then
            error("VarInt too big")
        end
    end

    return value, offset
end

function types.writeBoolean(v)
    return string.char(v and 1 or 0)
end

function types.readBoolean(sock)
    return readExact(sock, 1):byte() ~= 0
end

function types.writeByte(v)
    return string.pack(">i1", v)
end

function types.readByte(sock)
    return string.unpack(">i1", readExact(sock, 1))
end

function types.writeUByte(v)
    return string.pack(">I1", v)
end

function types.readUByte(sock)
    return string.unpack(">I1", readExact(sock, 1))
end

function types.writeShort(v)
    return string.pack(">i2", v)
end

function types.readShort(sock)
    return string.unpack(">i2", readExact(sock, 2))
end

function types.writeUShort(v)
    return string.pack(">I2", v)
end

function types.readUShort(sock)
    return string.unpack(">I2", readExact(sock, 2))
end

function types.writeInt(v)
    return string.pack(">i4", v)
end

function types.readInt(sock)
    return string.unpack(">i4", readExact(sock, 4))
end

function types.writeLong(v)
    return string.pack(">i8", v)
end

function types.readLong(sock)
    return string.unpack(">i8", readExact(sock, 8))
end

function types.writeFloat(v)
    return string.pack(">f", v)
end

function types.readFloat(sock)
    return string.unpack(">f", readExact(sock, 4))
end

function types.writeDouble(v)
    return string.pack(">d", v)
end

function types.readDouble(sock)
    return string.unpack(">d", readExact(sock, 8))
end

function types.writeString(str)
    return types.writeVarInt(#str) .. str
end

function types.readString(sock)
    local len = types.readVarInt(sock)
    return readExact(sock, len)
end

function types.writeBytes(data)
    return data
end

function types.readBytes(sock, count)
    return readExact(sock, count)
end

function types.readBooleanFromString(data, offset)
    offset = offset or 1
    return data:byte(offset) ~= 0, offset + 1
end

function types.readByteFromString(data, offset)
    return string.unpack(">i1", data, offset or 1)
end

function types.readUByteFromString(data, offset)
    return string.unpack(">I1", data, offset or 1)
end

function types.readShortFromString(data, offset)
    return string.unpack(">i2", data, offset or 1)
end

function types.readUShortFromString(data, offset)
    return string.unpack(">I2", data, offset or 1)
end

function types.readIntFromString(data, offset)
    return string.unpack(">i4", data, offset or 1)
end

function types.readLongFromString(data, offset)
    return string.unpack(">i8", data, offset or 1)
end

function types.readFloatFromString(data, offset)
    return string.unpack(">f", data, offset or 1)
end

function types.readDoubleFromString(data, offset)
    return string.unpack(">d", data, offset or 1)
end

function types.readStringFromString(data, offset)
    local len
    len, offset = types.readVarIntFromString(data, offset)
    return data:sub(offset, offset + len - 1), offset + len
end

function types.readBytesFromString(data, offset, count)
    offset = offset or 1
    return data:sub(offset, offset + count - 1), offset + count
end

function types.writeIdentifier(value)
    return types.writeString(value)
end

function types.readIdentifierFromString(data, offset)
    return types.readStringFromString(data, offset)
end
function types.packPosition(x, y, z)
    local val = ((x & 0x3FFFFFF) << 38) | ((z & 0x3FFFFFF) << 12) | (y & 0xFFF)
    if val >= 2 ^ 63 then
        val = val - 2 ^ 64
    end
    return types.writeLong(val)
end


return types