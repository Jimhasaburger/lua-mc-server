-- chunks.lua
local types = require("types")

local chunks = {}

chunks.SECTIONS = 24          -- world height / 16 (default overworld: -64 to 320)
chunks.SECTION_HEIGHT = 16

-- Encodes a single paletted container using the "single value" scheme
-- (bits_per_entry = 0 -> whole section is one block/biome id)
local function singleValuedContainer(id)
    return types.writeByte(0) ..     -- bits per entry
           types.writeVarInt(id) ..  -- the single palette entry
           types.writeVarInt(0)      -- data array length
end

-- One empty (all-air) section
-- NOTE: Block count AND Fluid count are BOTH present (two Shorts)
local function emptySection()
    local s = types.writeShort(0)            -- block count (non-air)
    s = s .. types.writeShort(0)              -- fluid count
    s = s .. singleValuedContainer(0)         -- block states -> air (id 0)
    s = s .. singleValuedContainer(0)         -- biomes -> id 0
    return s
end

-- One fully-solid section
local function solidSection(blockStateId)
    local s = types.writeShort(4096)          -- block count (full section)
    s = s .. types.writeShort(0)              -- fluid count
    s = s .. singleValuedContainer(blockStateId)
    s = s .. singleValuedContainer(0)
    return s
end

-- shared trailer: block entities + light data (used by all chunk builders)
local function appendTrailer(payload)
    payload = payload .. types.writeVarInt(0) -- block entities: prefixed array, 0 entries

    -- Light Data
    payload = payload .. types.writeVarInt(0) -- sky light mask (BitSet, 0 longs)
    payload = payload .. types.writeVarInt(0) -- block light mask (BitSet, 0 longs)
    payload = payload .. types.writeVarInt(0) -- empty sky light mask (BitSet, 0 longs)
    payload = payload .. types.writeVarInt(0) -- empty block light mask (BitSet, 0 longs)
    payload = payload .. types.writeVarInt(0) -- sky light arrays count
    payload = payload .. types.writeVarInt(0) -- block light arrays count

    return payload
end

-- Builds a full "all air" chunk column
function chunks.blank(chunkX, chunkZ)
    local payload = types.writeInt(chunkX) .. types.writeInt(chunkZ)

    payload = payload .. types.writeVarInt(0) -- Heightmaps: 0 entries (not required)

    local sectionData = ""
    for i = 1, chunks.SECTIONS do
        sectionData = sectionData .. emptySection()
    end
    payload = payload .. types.writeVarInt(#sectionData) .. sectionData

    return appendTrailer(payload)
end

-- Builds a flat superflat-style chunk: solid block from bottom up to fillSections
function chunks.flat(chunkX, chunkZ, blockStateId, fillSections)
    blockStateId = blockStateId or 1
    fillSections = fillSections or 4

    local payload = types.writeInt(chunkX) .. types.writeInt(chunkZ)

    payload = payload .. types.writeVarInt(0) -- Heightmaps: 0 entries

    local sectionData = ""
    for i = 1, chunks.SECTIONS do
        if i <= fillSections then
            sectionData = sectionData .. solidSection(blockStateId)
        else
            sectionData = sectionData .. emptySection()
        end
    end
    payload = payload .. types.writeVarInt(#sectionData) .. sectionData

    return appendTrailer(payload)
end

-- Sends a chunk to a client using the correct packet ID for your version
function chunks.send(client, packet, packetId, chunkX, chunkZ, generator)
    generator = generator or chunks.blank
    client:send(packet.encode(packetId, generator(chunkX, chunkZ)))
end

return chunks