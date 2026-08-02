local types = require("types")
local packet = require("packet")

local configuration = {}

function configuration.handle(client, name, uuid)

    while true do
        local pkt = packet.decode(client)


        if pkt.id == 2 then
            print("User has mods")
        else
            break
        end
    end

    local message = [[
    This server software is currently being worked on and may be buggy.

    If you encounter any bugs while playing,
    please report them here:
    https://github.com/Jimhasaburger/lua-mc-server/issues
    ]]

    -- send message
    client:send(packet.encode(19, types.writeString(message)))

    -- wait for accept
    local accept = packet.decode(client)

    if accept.id == 9 then
        print("OK")
    else
        print("Expected Code of Conduct accept, got:", accept.id)
    end
    -- this is needed
    local known_packs_payload = types.writeVarInt(1) 
                             .. types.writeString("minecraft") 
                             .. types.writeString("core") 
                             .. types.writeString("26.2")
    
    client:send(packet.encode(14, known_packs_payload))

    local client_packs_response = packet.decode(client)
    if client_packs_response.id == 7 then
        print("OK")
    else
        print("Warning: Expected Known Packs response (7), got:", client_packs_response.id)
    end
    
    local registry = require("registry")
    -- registry time!
    registry.send(client)

    local tags = require("tags")
    -- tag time!
    tags.send(client)
    -- finish
    client:send(packet.encode(3, ""))
    
    local ack = packet.decode(client)
    if ack.id == 3 then
        print("OK")
    else
        error("ERROR!")
    end
    
    local play = require("play")
    play.handle(client, name, uuid)
end

return configuration