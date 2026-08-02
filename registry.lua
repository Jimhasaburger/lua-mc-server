local packet = require("packet")
local types = require("types")
local nbt = require("nbt")
local datapack = require("datapack")

local registry = {}

local TagClass = nbt.TagClass

-- Convert JSON-decoded entry data into NBT tags.
local function tableToNBT(value, name)

    local t = type(value)

    if t == "table" then

        -- dkjson tags decoded arrays/objects with __jsontype so empty
        -- [] and {} can be told apart.
        local mt = getmetatable(value)

        if mt and mt.__jsontype == "array" then

            local elements = {}
            for i, v in ipairs(value) do
                elements[i] = tableToNBT(v)
            end

            -- NBT lists are homogeneous; normalize mixed int/double lists
            -- to all doubles (NbtOps is lenient about numeric types).
            local allNumeric = #elements > 0
            local allInts = true
            for _, el in ipairs(elements) do
                local id = el:getTypeID()
                if id ~= nbt.TAG_INT and id ~= nbt.TAG_DOUBLE then
                    allNumeric = false
                    break
                end
                if id ~= nbt.TAG_INT then
                    allInts = false
                end
            end

            if allNumeric and not allInts then
                for i, el in ipairs(elements) do
                    if el:getTypeID() == nbt.TAG_INT then
                        elements[i] = nbt.newDouble(el:getValue())
                    end
                end
            end

            return TagClass.new(nbt.TAG_LIST, elements, name)

        else
            local compound = {}

            for k, v in pairs(value) do
                compound[#compound + 1] = tableToNBT(v, k)
            end

            return TagClass.new(nbt.TAG_COMPOUND, compound, name)
        end

    elseif t == "string" then
        return TagClass.new(nbt.TAG_STRING, value, name)

    elseif t == "boolean" then
        return TagClass.new(nbt.TAG_BYTE, value and 1 or 0, name)

    elseif t == "number" then

        if math.floor(value) == value then
            return TagClass.new(nbt.TAG_INT, value, name)
        else
            return TagClass.new(nbt.TAG_DOUBLE, value, name)
        end

    else
        error("Unsupported NBT type: " .. t)
    end
end


function registry.send(client)

    for _, reg in ipairs(datapack.registries()) do

        local payload = ""

        -- Registry identifier
        payload = payload .. types.writeString(reg.id)

        -- Entry count
        payload = payload .. types.writeVarInt(#reg.entries)


        for _, entry in ipairs(reg.entries) do

            -- Entry identifier
            payload = payload .. types.writeString(entry.name)


            -- Optional NBT
            if next(entry.data) then

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
