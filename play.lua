local packet = require("packet")
local types = require("types")
local play = {}
local loginpacket = require("loginpacket")

function play.handle(client, name, uuid)
    
    client:send(loginpacket.encode{
        entityId = 1,
        viewDistance = 12,
        simulationDistance = 8,
        gameMode = 0,
    })

    local payload =
        types.writeIdentifier("minecraft:overworld") ..
        types.packPosition(0,64,0) ..
        types.writeFloat(0) ..
        types.writeFloat(0)

    client:send(packet.encode(97, payload))

    local brandData = types.writeString("luamcserver")
    
    local brandPayload = types.writeIdentifier("minecraft:brand") .. brandData
    
    client:send(packet.encode(24, brandPayload))

    local posPayload = 
        types.writeVarInt(1) ..          -- Teleport ID
        types.writeDouble(0.0) ..        -- X
        types.writeDouble(64.0) ..       -- Y
        types.writeDouble(0.0) ..        -- Z
        types.writeDouble(0.0) ..        -- Velocity X
        types.writeDouble(0.0) ..        -- Velocity Y
        types.writeDouble(0.0) ..        -- Velocity Z
        types.writeFloat(0.0) ..         -- Yaw
        types.writeFloat(0.0) ..         -- Pitch
        types.writeInt(0)                -- Flags (4-byte Int bitfield)

    client:send(packet.encode(72, posPayload))

    local abilitiesPayload = 
        types.writeByte(0x07) ..  -- Flags: Invulnerable (0x01), Flying (0x02), Allow Flying (0x04), Creative Mode (0x08)
        types.writeFloat(0.05) .. -- Flying Speed
        types.writeFloat(0.1)     -- Field of View / Walking Speed

    client:send(packet.encode(64, abilitiesPayload))

    
end

return play