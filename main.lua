package.path  = package.path  .. ';./?.lua;./luasocket/?.lua'
package.cpath = package.cpath .. ';./?.dll;./luasocket/?.dll'
local socket = require("socket")
local types = require("types")
local packet = require("packet")
local serverlist = require("serverlist")
local login = require("login")

local path = "config.json"
local json = require("dkjson")
local f = assert(io.open(path, "r"))
local content = f:read("*a")
f:close()
local config = json.decode(content)

local server = assert(socket.bind(config.socket.host, config.socket.port))
server:settimeout(nil)

print("Listening...")

while true do
    local client = server:accept()

    print("Client connected:", client:getpeername())

    local ok, err = pcall(function()
        local pkt = packet.decode(client)
        if pkt.id ~= 0 then
            error("Expected Handshake packet")
        else
            local offset = pkt.offset

            local protocol
            protocol, offset = types.readVarIntFromString(pkt.data, offset)

            local address
            address, offset = types.readStringFromString(pkt.data, offset)

            local port
            port, offset = types.readUShortFromString(pkt.data, offset)

            local nextState
            nextState, offset = types.readVarIntFromString(pkt.data, offset)

            if nextState == 1 then
                serverlist.handle(client)
                client:close()
            elseif nextState == 2 then
                login.handle(client)
            else
                error("Unknown next state: " .. tostring(nextState))
            end
        end
    end)

    if not ok then
        print("Client error:", err)
    end
end