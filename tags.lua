local packet = require("packet")
local types = require("types")
local datapack = require("datapack")

local tags = {}

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

    -- 1. Registries that actually define tags
    local tagData = datapack.tags()

    local registryCount = 0
    for _, group in ipairs(tagData) do
        if #group.tags > 0 then
            registryCount = registryCount + 1
        end
    end
    payload = payload .. types.writeVarInt(registryCount)

    -- 2. Loop registries
    for _, group in ipairs(tagData) do
        if #group.tags > 0 then
            payload = payload .. types.writeIdentifier(group.registry)
            payload = payload .. types.writeVarInt(#group.tags) -- Number of tag groups

            -- Entry IDs: synced registries use the order we send them in;
            -- built-in registries use their protocol IDs.
            local ids = datapack.idMap(group.registry, datapack.registryEntries(group.registry))

            -- Build a lookup of tag name -> tag object for # references
            local tagByName = {}
            for _, tagObj in ipairs(group.tags) do
                tagByName[tagObj.name] = tagObj
            end

            -- 3. Loop tag groups (e.g., "minecraft:is_fire")
            for _, tagObj in ipairs(group.tags) do
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
end

return tags
