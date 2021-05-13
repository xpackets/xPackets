-- xPacket
-- RootEntry
-- May 12, 2021

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local EnumList = require(script.EnumList)
local Thread = require(script.Thread)
local RemoteFloodCheck = require(script.RemoteFloodCheck)
local Maid = require(script.Maid)
local TableUtil = require(script.TableUtil)
local Signal = require(script.Signal)

-- Local Variables
local MODULE = {}
local PACKET_QUEUE = table.create(50) -- If > 50 packets then reject.
local PACKET_BUFFER = table.create(10) -- Create a Packet Buffer with length 10.
local PACKET_LOSS_BUFFER = {}
local PACKETS_RECEIVED_BUFFER = {}
local BUILTIN_COMPRESSION = false
local PACKET_PROTOCOLS = EnumList.new(
	"PacketProtocols",
	{ "ClientToServer", "ServerToClient", "ServerToServer", "ClientToClient", "Unspecified" }
)
local PACKET_FLOW_TYPES = EnumList.new("PacketFlowInfo", { "Data", "Event" })
local DEFAULT_PACKET = {
	Arguments = {},
	Callback = nil,
}

local function getFreeIndexInQueue()
	local index = nil
	for i, v in ipairs(PACKET_QUEUE) do
		if v == nil then
			index = i
			break
		end
	end

	return index
end

local function Enqueue(PACKET_METADATA, PACKET)
	assert(PACKET_METADATA, "MISSING PACKET METADATA")
	assert(PACKET, "MISSING PACKET")

	if (PACKET_METADATA.DataLength / 1024) > 1 then
		warn(("Packet #%s is too big. Max: 1kb per packet.\nPacket Size: %.5f kb."):format(PACKET_METADATA.Id, PACKET_METADATA.DataLength / 1024))
		table.insert(PACKET_LOSS_BUFFER, #PACKET_LOSS_BUFFER + 1, 0x1)

		return false
	end

	if PACKET_QUEUE[50] ~= nil then
		-- Queue is Full
		warn("Queue is full, adding to buffer! Packet Info:\n" .. TableUtil.EncodeJSON(PACKET_METADATA))

		PACKET_BUFFER[#PACKET_BUFFER + 1] = { PACKET_METADATA, PACKET }
		table.insert(PACKET_LOSS_BUFFER, #PACKET_LOSS_BUFFER + 1, 0x1)
		return false
	end

	PACKET_QUEUE[#PACKET_QUEUE + 1] = {
		Meta = PACKET_METADATA,
		Data = PACKET,
	}
end

local function HandleQueue()
	local _Packets = {}

	if #PACKET_QUEUE <= 0 and #PACKET_BUFFER <= 0 then
		warn("PACKET QUEUE IS EMPTY")
	end

	for i, v in pairs(PACKET_QUEUE) do
		warn("Handling Packet #" .. v.Meta.Id .. ";")

		local Packaged = v.Data

		_Packets[#_Packets + 1] = { v.Meta, Packaged }
		PACKET_QUEUE[i] = {}
		PACKET_QUEUE[i] = nil
	end

	for k, v in pairs(_Packets) do
		if v[1].FlowType == "Data" then
			if v[1].Protocol == "ClientToServer" then
				local response = nil
				response = ReplicatedStorage.PacketSender_Func:InvokeServer(v[1])

				table.insert(PACKETS_RECEIVED_BUFFER, #PACKETS_RECEIVED_BUFFER + 1, 0x1)
				warn(("Packet #%s has been recieved successfully."):format(v[1].Id))
				v[1].Callback(response)
			elseif v[1].Protocol == "ServerToClient" then
				assert(v[1].Destination, "MISSING DESTINATION")

				local response = nil

				response = ReplicatedStorage.PacketSender_Func:InvokeClient(v[1].Destination, v[1])
				table.insert(PACKETS_RECEIVED_BUFFER, #PACKETS_RECEIVED_BUFFER + 1, 0x1)
				warn(("Packet #%s has been recieved successfully."):format(v[1].Id))
				v[1].Callback(response)
			end
		elseif v[1].FlowType == PACKET_FLOW_TYPES.Event then
			if v[1].Protocol == PACKET_PROTOCOLS.ClientToServer then
				ReplicatedStorage.PacketSender_Event:FireServer(v[2])
			elseif v[1].Protocol == PACKET_PROTOCOLS.ServerToClient then
				assert(v[1].Destination, "MISSING DESTINATION")
				ReplicatedStorage.PacketSender_Event:FireClient(v[1].Destination, v[2])
			end
		end
	end

	local index, value = next(PACKET_BUFFER)
	while index ~= nil do
		if PACKET_QUEUE[50] ~= nil then
			warn("Packet Queue Full, retrying next round.")
			break
		end

		PACKET_QUEUE[#PACKET_QUEUE + 1] = {
			Meta = value[1],
			Data = value[2],
		}

		print("Enqueued buffer entry: " .. index .. " successfully.")
		PACKET_BUFFER[index] = {}
		PACKET_BUFFER[index] = nil

		index, value = next(PACKET_BUFFER)
	end
end

return {
	HandleQueue = HandleQueue,
	Enqueue = Enqueue,
}
