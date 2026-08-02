-- loginpacket.lua
local types = require("types")
local packet = require("packet")
local json = require("dkjson")

local loginpacket = {}

local config = {}
do
    local f = io.open("config.json", "r")
    if f then
        local content = f:read("*a")
        f:close()
        config = json.decode(content) or {}
    end
end

local world = config.world or {}
local server = config.server or {}
local auth = config.authentication or {}

local defaults = {
    isHardcore = false,
    dimensionNames = { "minecraft:overworld" },
    maxPlayers = server.maxPlayers,
    viewDistance = world.viewDistance,
    simulationDistance = world.simulationDistance,
    reducedDebugInfo = world.reducedDebugInfo,
    enableRespawnScreen = world.enableRespawnScreen,
    doLimitedCrafting = world.doLimitedCrafting,
    dimensionType = world.dimensionType,
    dimensionName = world.dimensionName,
    hashedSeed = world.hashedSeed,
    gameMode = world.gameMode,
    previousGameMode = world.previousGameMode,
    isDebug = world.isDebug,
    isFlat = world.isFlat,
    portalCooldown = world.portalCooldown,
    seaLevel = world.seaLevel,
    onlineMode = auth.onlineMode,
    enforcesSecureChat = world.enforcesSecureChat,
}

local function packPosition(x, y, z)
    return types.packPosition(x, y, z)
end

function loginpacket.encode(f)
    f = f or {}
    local merged = {}
    for k, v in pairs(defaults) do
        merged[k] = v
    end
    for k, v in pairs(f) do
        if v ~= nil then
            merged[k] = v
        end
    end

    local payload = {}

    payload[#payload + 1] = types.writeInt(merged.entityId)
    payload[#payload + 1] = types.writeBoolean(merged.isHardcore)

    local names = merged.dimensionNames
    if type(names) == "string" then
        names = {names}
    end
    payload[#payload + 1] = types.writeVarInt(#names)
    for _, name in ipairs(names) do
        payload[#payload + 1] = types.writeIdentifier(name)
    end

    payload[#payload + 1] = types.writeVarInt(merged.maxPlayers)
    payload[#payload + 1] = types.writeVarInt(merged.viewDistance)
    payload[#payload + 1] = types.writeVarInt(merged.simulationDistance)
    payload[#payload + 1] = types.writeBoolean(merged.reducedDebugInfo)
    payload[#payload + 1] = types.writeBoolean(merged.enableRespawnScreen)
    payload[#payload + 1] = types.writeBoolean(merged.doLimitedCrafting)
    payload[#payload + 1] = types.writeVarInt(merged.dimensionType)
    payload[#payload + 1] = types.writeIdentifier(merged.dimensionName)
    payload[#payload + 1] = types.writeLong(merged.hashedSeed)
    payload[#payload + 1] = types.writeUByte(merged.gameMode)
    payload[#payload + 1] = types.writeByte(merged.previousGameMode)
    payload[#payload + 1] = types.writeBoolean(merged.isDebug)
    payload[#payload + 1] = types.writeBoolean(merged.isFlat)

    local hasDeath = merged.hasDeathLocation
    payload[#payload + 1] = types.writeBoolean(hasDeath)
    if hasDeath then
        payload[#payload + 1] = types.writeIdentifier(merged.deathDimensionName)
        payload[#payload + 1] = packPosition(merged.deathLocation.x, merged.deathLocation.y, merged.deathLocation.z)
    end

    payload[#payload + 1] = types.writeVarInt(merged.portalCooldown)
    payload[#payload + 1] = types.writeVarInt(merged.seaLevel)
    payload[#payload + 1] = types.writeBoolean(merged.onlineMode)
    payload[#payload + 1] = types.writeBoolean(merged.enforcesSecureChat)

    return packet.encode(0x31, table.concat(payload))
end

return loginpacket
