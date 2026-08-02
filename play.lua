local packet = require("packet")
local types = require("types")
local play = {}
local loginpacket = require("loginpacket")

function play.handle(client, name, uuid)
    print("play mode entered!")
    
    client:send(loginpacket.encode{
        entityId = 1,
        viewDistance = 12,
        simulationDistance = 8,
        gameMode = 0,
    })

    local payload =
        types.writeIdentifier("minecraft:overworld") ..
        types.packPosition(0,0,0) ..
        types.writeFloat(0) ..
        types.writeFloat(0)

    client:send(packet.encode(97, payload))
    print("Loading terrain... is what you should see now.")
    
end

return play