local packet = require("packet")
local types = require("types")
local json = require("dkjson")
local nbt = require("nbt")

local registry = {}

-- Load registries.json
local file = assert(io.open("registries.json", "r"))
local registries = json.decode(file:read("*a"))
file:close()


-- Convert normal Lua tables into NBT
local function tableToNBT(value)

    local t = type(value)

    if t == "table" then

        -- If table is a list (only integer keys 1..n), make an NBT list
        local list = {}
        for i, v in ipairs(value) do
            list[i] = tableToNBT(v)
        end

        if #list > 0 then
            -- Pass raw values, not TagClass objects: nbt.newList() re-wraps
            -- them via tostring(), corrupting strings (nbt.lua bug).
            local raw = {}
            for i, v in ipairs(list) do
                raw[i] = v:getValue()
            end
            return nbt.newList(list[1]:getTypeID(), raw)
        else
            local compound = {}

            for k, v in pairs(value) do
                compound[k] = tableToNBT(v)
            end

            return nbt.newCompound(compound)
        end

    elseif t == "string" then
        return nbt.newString(value)

    elseif t == "boolean" then
        return nbt.newByte(value and 1 or 0)

    elseif t == "number" then

        if math.floor(value) == value then
            return nbt.newInt(value)
        else
            return nbt.newDouble(value)
        end

    else
        error("Unsupported NBT type: " .. t)
    end
end


function registry.send(client)

    for registryID, entries in pairs(registries) do

        local payload = ""

        -- Registry identifier
        payload = payload .. types.writeString(registryID)

        -- Entry count
        payload = payload .. types.writeVarInt(#entries)


        for _, entry in ipairs(entries) do

            -- Entry identifier
            payload = payload .. types.writeString(entry.name)


            -- Optional NBT
            if entry.data then

                payload = payload .. types.writeBoolean(true)

                local tag = tableToNBT(entry.data)

                -- Network NBT: type byte + value, no root name (NbtIo.writeAnyTag, 26.x)
                payload = payload .. string.char(tag:getTypeID()) .. tag:encode(true)

            else

                payload = payload .. types.writeBoolean(false)

            end
        end


        -- One registry per packet
        client:send(packet.encode(7, payload))

    end

end


return registry