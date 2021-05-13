-->> Settings
local DefaultMaxRatePerSec = 10
local DefaultIdentifier = "Identifier"
-->>

-- Made by XandertjeKnal
--[[ Documentation:
This module can be used to make sure rates of Remotes are not exceeded.

FloodCheck:Check(Player_Object, Event, RatePerSec, Unique_Identifier) -- Will return false if the limit is exceeded, otherwise will return true.

- Player_Object
Reference the player that is making the request.

- Event
Reference the event that you are listening to.

- RatePerSec:
RatePerSec > 1
If the RatePerSec variable x is set higher than 1, it will allow x requests in the first second after the first request was made. E.g. if RatePerSec is set to 5, a player can send 5 consecutive requests in any time that is less than a second, for example within the first 200ms even. All other requests in that second will be blocked. After that second, the request count will be reset.
RatePerSec <= 1
If the RatePerSec variable x is set lower or equal to 1, it will only allow a consecutive request (1/x) seconds after the first request. E.g. if RatePerSec is set to 0.2, a player has to wait (1/0.2) = 5 seconds after sending the first request before any consecutive requests will be processed. All other requests in between will be blocked.
The RatePerSec should not be changed after the first request has been checked.
If left nil, the DefaultMaxRatePerSec will be used.

- Unique_Identifier:
This variable is optional to use and can most often be left nil. You only have to use this if there are multiple scripts listening to the same RemoteEvent/RemoteFunction.
E.g. 2 scripts are listening to an 'ExplodeTNT' event. You can set one Unique_Identifier to '1' and the other to '2'. If you are using clones of the same script (or packages) listening to the same event then you may want to use a random number or string that is randomized only once(!) per script as the Unique_Identifier instead.
This identifier is used to prevent multiple checks from filling up the flood check.
You could in theory also use this identifier to have different Rates for different scripts listening to the same remote. Example usage: throttle resource-intensive scripts more than the game-critical scripts, even if they are listening to the same event.

- Example usage:
local FloodCheck = require(game.ServerScriptService.RemoteFloodCheck) -- Reference this module
MyEvent.OnServerEvent:Connect(function(Player)
	if FloodCheck:Check(Player, MyEvent, 10) then
		-- Process the request
	end
end
--]]

local FloodCheck = {}

local Requests = {}

function FloodCheck:Check(Player_Object, Remote, RatePerSec, Unique_Identifier)
	local Rate = RatePerSec or DefaultMaxRatePerSec
	local Identifier = Unique_Identifier or DefaultIdentifier

	if not Requests[Player_Object] then
		Requests[Player_Object] = {}
		local connection
		local function PlayerLeft(player)
			if player == Player_Object then
				Requests[Player_Object] = nil
				connection:Disconnect()
			end
		end
		connection = game.Players.PlayerRemoving:Connect(PlayerLeft)
	end
	if not Requests[Player_Object][Remote] then
		Requests[Player_Object][Remote] = {}
	end
	if not Requests[Player_Object][Remote][Identifier] then
		Requests[Player_Object][Remote][Identifier] = {}
	end

	if Rate > 1 then
		if Requests[Player_Object][Remote][Identifier]["Count"] then
			local TimeElapsed = tick() - Requests[Player_Object][Remote][Identifier]["StartTime"]
			if TimeElapsed >= 1 then
				Requests[Player_Object][Remote][Identifier]["Count"] = 1
				Requests[Player_Object][Remote][Identifier]["StartTime"] = tick()
				return true
			else
				Requests[Player_Object][Remote][Identifier]["Count"] = Requests[Player_Object][Remote][Identifier]["Count"]
					+ 1
				return Requests[Player_Object][Remote][Identifier]["Count"] <= Rate
			end
		else
			Requests[Player_Object][Remote][Identifier]["Count"] = 1
			Requests[Player_Object][Remote][Identifier]["StartTime"] = tick()
			return true
		end
	end
	if Rate <= 1 then
		if Requests[Player_Object][Remote][Identifier]["LastTime"] then
			local TimeElapsed = tick() - Requests[Player_Object][Remote][Identifier]["LastTime"]
			if TimeElapsed >= (1 / Rate) then
				Requests[Player_Object][Remote][Identifier]["LastTime"] = tick()
				return true
			else
				return false
			end
		else
			Requests[Player_Object][Remote][Identifier]["LastTime"] = tick()
			return true
		end
	end
end

return FloodCheck
