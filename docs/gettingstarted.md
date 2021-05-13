# Getting Started

## Install

Installing XPackets is very simple. Just drop the module into ReplicatedStorage. XPackets can also be used within a Rojo project.

**Roblox Studio workflow:**
1. Get XPackets from the Roblox library.
2. Place XPackets directly within ReplicatedStorage.

**Rojo workflow:**
1. Download XPackets from the latest release on GitHub.
2. Extract the XPackets directory from the zipped file.
3. Place XPackets within your project.
4. Use Rojo to point XPackets to ReplicatedStorage.

## Setting Up The Environment

In order to start using XPackets you need to setup an environment for it.
Do as following:
1. Create a RemoteFunction within ReplicatedStorage called "PacketSender_Func"
2. Create a Script in ServerScriptService

The script's contents should be:

```lua
-- Server
local xPacket = require(game:GetService("ReplicatedStorage").xPacket)
game:GetService("ReplicatedStorage").PacketSender_Func.OnServerInvoke = function(Player, Request)
    if Request.Version == "PrintHelloWorld" then
        print("[Server] Hello World!")
    end
end
```

3. Create a Local Script in StarterPlayerScripts

The script's contents should be:

```lua
--Client
local xPacket = require(game:GetService("ReplicatedStorage").xPacket)
game:GetService("ReplicatedStorage").PacketSender_Func.OnClientInvoke = function(Request)
    if Request.Version == "PrintHelloWorld" then
        print("[Client] Hello World!")
    end
end
```

## Examples

### Client To Server

Local Script:
```lua
-- Client
local xPacket = require(game.ReplicatedStorage.xPacket)

xPacket.Enqueue({
	Version = "PrintHelloWorld",
	FlowType = "Data",
	Protocol = "ClientToServer",
	TimeToLive = 5, -- Timeout
	DataLength = 0,
	Source = "CLIENT", -- Source
	Destination = nil,
	Id = game.HttpService:GenerateGUID(false),
	Callback = function(args) -- Called when server recieved request.
        print("It also passes arguments from server: " .. table.unpack(args))

        print("The server has printed hello world")
	end,
}, {
	Arguments = {} -- Arguments passed on to server.
})

xPacket.HandleQueue() -- Should always be called last, after you enqueued the packets.
```

Then in a server script:
```lua
-- Server
local xPacket = require(game.ReplicatedStorage.xPacket)

game:GetService("ReplicatedStorage").PacketSender_Func.OnServerInvoke = function(Player, Request)
    if Request.Version == "PrintHelloWorld" then
        print("[Server] Hello World!")

        return {"This will be passed onto the callback function", "this too", "and this."}
    end
end
```

### Server To Client

Server Script:
```lua
-- Server
local xPacket = require(game.ReplicatedStorage.xPacket)

xPacket.Enqueue({
    Version = "GetCameraFOV",
    FlowType = "Data",
    Protocol = "ServerToClient",
    TimeToLive = 5, -- Timeout
    DataLength = 0,
    Source = "SERVER", -- Source
    Destination = PLAYEROBJECT, -- Make sure to put the player who will recieved the packet.
    Id = game.HttpService:GenerateGUID(false),
    Callback = function(FOV) -- Called when client recieved request.
        print("Client recieved request")

        print("Client's FOV is: " .. FOV)
    end,
}, {
    Arguments = {} -- Arguments passed on to client.
})

xPacket.HandleQueue() -- Should always be called last, after you enqueued the packets. 
```

Then in a Client script:
```lua
-- Client
local xPacket = require(game.ReplicatedStorage.xPacket)

game:GetService("ReplicatedStorage").PacketSender_Func.OnClientInvoke = function(Request)
    if Request.Version == "GetCameraFOV" then
        return workspace.CurrentCamera.FieldOfView
    end
end
```