local packet = require("packet")
local types = require("types")
local json = require("dkjson")

local tags = {}

-- Load JSON data
local file = assert(io.open("tags.json", "r"))
local content = file:read("*a")
file:close()
local tagData = json.decode(content)

-- Load the registries so we can map entry names to their numeric IDs.
-- The order of the entries in each registry (as sent in the Registry Data
-- packets) defines the IDs, starting from 0, so tags must reference those
-- same IDs to stay consistent with the registry.
local regFile = assert(io.open("registries.json", "r"))
local regData = json.decode(regFile:read("*a"))
regFile:close()

-- Static registries (e.g. block) are baked into the client and not sent via
-- Registry Data packets, so their entry IDs come from a separate name -> ID
-- map generated from the client's own registry order.
local staticFile = assert(io.open("block_ids.json", "r"))
local staticIds = json.decode(staticFile:read("*a"))
staticFile:close()

-- Build a name -> numeric ID lookup for a given registry
local function idMap(registryName)
    local map = {}
    local entries = regData[registryName]
    if entries then
        for i, entry in ipairs(entries) do
            map[entry.name] = i - 1
        end
    elseif registryName == "minecraft:block" then
        map = {}
        for name, id in pairs(staticIds) do
            map["minecraft:" .. name] = id
        end
    end
    return map
end

-- Expand tag entries into a concrete list. Values starting with "#" reference
-- another tag in the same registry; the client only understands numeric IDs,
-- so references must be resolved server-side first.
local function expand(values, tagByName, seen)
    seen = seen or {}
    local out = {}
    for _, v in ipairs(values) do
        if v:sub(1, 1) == "#" then
            local ref = v:sub(2)
            if not seen[ref] then
                seen[ref] = true
                local refTag = tagByName[ref]
                if refTag then
                    for _, e in ipairs(expand(refTag.values, tagByName, seen)) do
                        out[#out + 1] = e
                    end
                else
                    error("Unknown tag reference: " .. tostring(ref))
                end
            end
        else
            out[#out + 1] = v
        end
    end
    return out
end

function tags.send(client)
    local payload = ""

    -- 1. Count registries that actually define tags
    local registryCount = 0
    for _, tagArray in pairs(tagData) do
        if #tagArray > 0 then
            registryCount = registryCount + 1
        end
    end
    payload = payload .. types.writeVarInt(registryCount)

    -- 2. Loop registries
    for registryName, tagArray in pairs(tagData) do
        if #tagArray > 0 then
            payload = payload .. types.writeIdentifier(registryName)
            payload = payload .. types.writeVarInt(#tagArray) -- Number of tag groups

            local ids = idMap(registryName)

            -- Build a lookup of tag name -> tag object for # references
            local tagByName = {}
            for _, tagObj in ipairs(tagArray) do
                tagByName[tagObj.name] = tagObj
            end

            -- 3. Loop tag groups (e.g., "minecraft:is_fire")
            for _, tagObj in ipairs(tagArray) do
                payload = payload .. types.writeIdentifier(tagObj.name)

                -- 4. Expand # references, then convert entries to numeric IDs
                local expanded = expand(tagObj.values, tagByName)
                payload = payload .. types.writeVarInt(#expanded)
                for _, entryName in ipairs(expanded) do
                    local numericId = ids[entryName]
                    if not numericId then
                        error("Unknown registry element name: " .. tostring(entryName))
                    end

                    -- Pass the integer ID to the VarInt encoder
                    payload = payload .. types.writeVarInt(numericId)
                end
            end
        end
    end

    client:send(packet.encode(13, payload))
    print("Sent " .. registryCount .. " tag registries successfully.")
end

return tags
