local json = require("dkjson")

local datapack = {}

local META_DIR = "data/minecraft"

-- The synchronized registries for the 26.2 protocol (wiki "Java Edition
-- protocol/Registries"): only these are sent to the client via Registry Data
-- packets. Keys are the folder paths under data/minecraft.
local SYNCED_REGISTRIES = {
    banner_pattern = true,
    cat_sound_variant = true,
    cat_variant = true,
    chat_type = true,
    chicken_sound_variant = true,
    chicken_variant = true,
    cow_sound_variant = true,
    cow_variant = true,
    damage_type = true,
    dialog = true,
    dimension_type = true,
    enchantment = true,
    frog_variant = true,
    instrument = true,
    jukebox_song = true,
    painting_variant = true,
    pig_sound_variant = true,
    pig_variant = true,
    sulfur_cube_archetype = true,
    test_environment = true,
    test_instance = true,
    timeline = true,
    trim_material = true,
    trim_pattern = true,
    wolf_sound_variant = true,
    wolf_variant = true,
    world_clock = true,
    zombie_nautilus_variant = true,
    ["worldgen/biome"] = true,
}

local WINDOWS = os.getenv("OS") == "Windows_NT"

-- List .json entry names (without extension) in `dir`, sorted.
local function listFiles(dir)
    local names = {}
    local cmd = WINDOWS and ('dir /b /a-d "' .. dir .. '" 2>nul')
        or ('ls -1 "' .. dir .. '" 2>/dev/null')
    local p = io.popen(cmd)
    if p then
        for line in p:lines() do
            local name = line:gsub("[\r\n]+", "")
            if name:sub(-5) == ".json" then
                names[#names + 1] = name:sub(1, -6)
            end
        end
        p:close()
    end
    table.sort(names)
    return names
end

-- List subdirectory names in `dir`, sorted.
local function listDirectories(dir)
    local names = {}
    local cmd = WINDOWS and ('dir /b /ad "' .. dir .. '" 2>nul')
        or ('find "' .. dir .. '" -mindepth 1 -maxdepth 1 -type d 2>/dev/null')
    local p = io.popen(cmd)
    if p then
        for line in p:lines() do
            local name = line:gsub("[\r\n]+", "")
            if not WINDOWS then
                name = name:match("[^/\\]+$")
            end
            if name and name ~= "" then
                names[#names + 1] = name
            end
        end
        p:close()
    end
    table.sort(names)
    return names
end

-- Recursively collect .json entry names (relative paths without extension)
-- under `dir`, sorted. `rel` accumulates the relative path.
local function walkJSON(dir, rel)
    local out = {}
    for _, sub in ipairs(listDirectories(dir)) do
        local childRel = rel == "" and sub or (rel .. "/" .. sub)
        for _, name in ipairs(walkJSON(dir .. "/" .. sub, childRel)) do
            out[#out + 1] = name
        end
    end
    for _, name in ipairs(listFiles(dir)) do
        out[#out + 1] = rel == "" and name or (rel .. "/" .. name)
    end
    table.sort(out)
    return out
end

local function readJSON(path)
    local f = assert(io.open(path, "r"))
    local data = json.decode(f:read("*a"))
    f:close()
    return data
end

-- All entries of a registry, named "minecraft:<path>" with their data.
local function loadRegistry(registryPath)
    local entries = {}
    for _, name in ipairs(walkJSON(META_DIR .. "/" .. registryPath, "")) do
        entries[#entries + 1] = {
            name = "minecraft:" .. name,
            data = readJSON(META_DIR .. "/" .. registryPath .. "/" .. name .. ".json"),
        }
    end
    return entries
end

local registries
local registryByID

-- All synchronized registries: array of { id, entries }.
function datapack.registries()
    if not registries then
        registries = {}
        for _, dir in ipairs(listDirectories(META_DIR)) do
            if SYNCED_REGISTRIES[dir] then
                local entries = loadRegistry(dir)
                if #entries > 0 then
                    registries[#registries + 1] = { id = "minecraft:" .. dir, entries = entries }
                end
            elseif dir == "worldgen" then
                local entries = loadRegistry("worldgen/biome")
                if #entries > 0 then
                    registries[#registries + 1] = { id = "minecraft:worldgen/biome", entries = entries }
                end
            end
        end
    end
    return registries
end

-- Ordered entries of a synchronized registry, or nil for built-in registries.
function datapack.registryEntries(registryID)
    if not registryByID then
        registryByID = {}
        for _, reg in ipairs(datapack.registries()) do
            registryByID[reg.id] = reg.entries
        end
    end
    return registryByID[registryID]
end

-- name -> numeric entry ID for a registry. Synchronized registries get their
-- IDs from the order the entries are sent in (as the client assigns them);
-- built-in registries use the protocol IDs in data/registries.json.
local builtins

function datapack.idMap(registryID, syncEntries)
    local map = {}
    if syncEntries then
        for i, entry in ipairs(syncEntries) do
            map[entry.name] = i - 1
        end
        return map
    end
    if not builtins then
        builtins = readJSON("data/registries.json")
    end
    local entries = builtins[registryID]
    if entries then
        for name, info in pairs(entries.entries) do
            map[name] = info.protocol_id
        end
    end
    return map
end

local tagData
local builtinRegistryNames

-- True if `registryID` (e.g. "minecraft:block") is a built-in registry the
-- client knows about, i.e. it has protocol IDs in data/registries.json.
local function isBuiltin(registryID)
    if not builtinRegistryNames then
        builtinRegistryNames = {}
        for name in pairs(readJSON("data/registries.json")) do
            builtinRegistryNames[name] = true
        end
    end
    return builtinRegistryNames[registryID]
end

-- All tags grouped by registry: array of { registry, tags = { name, values } }.
-- Only includes registries the client knows about: synchronized registries and
-- built-in registries (tags for unknown registries would break the client).
function datapack.tags()
    if not tagData then
        tagData = {}
        local function addRegistry(registryPath, registryID)
            if not SYNCED_REGISTRIES[registryPath] and not isBuiltin(registryID) then
                return
            end
            local tagList = {}
            for _, name in ipairs(walkJSON("data/minecraft/tags/" .. registryPath, "")) do
                local tag = readJSON("data/minecraft/tags/" .. registryPath .. "/" .. name .. ".json")
                tagList[#tagList + 1] = { name = "minecraft:" .. name, values = tag.values }
            end
            if #tagList > 0 then
                tagData[#tagData + 1] = { registry = registryID, tags = tagList }
            end
        end
        for _, dir in ipairs(listDirectories("data/minecraft/tags")) do
            if dir == "worldgen" then
                for _, sub in ipairs(listDirectories("data/minecraft/tags/worldgen")) do
                    addRegistry("worldgen/" .. sub, "minecraft:worldgen/" .. sub)
                end
            else
                addRegistry(dir, "minecraft:" .. dir)
            end
        end
    end
    return tagData
end

return datapack
