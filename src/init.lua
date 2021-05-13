-- xPacket (v.0.0.8-alpha)
-- RootEntry
-- May 13, 2021

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Initialise Remotes
if RunService:IsServer() then
	local new = Instance.new("RemoteFunction")
	new.Name = "PacketSender_Func"
	new.Parent = game:GetService("ReplicatedStorage")

	new = Instance.new("RemoteEvent")
	new.Name = "PacketSender_Event"
	new.Parent = game:GetService("ReplicatedStorage")
end

local EnumList = require(script.EnumList)
local Thread = require(script.Thread)
local RemoteFloodCheck = require(script.RemoteFloodCheck)
local Maid = require(script.Maid)
local TableUtil = require(script.TableUtil)
local Signal = require(script.Signal)

--[[
	TODO:
	
	- In-Built Compression
	- ServerToServer/ClientToClient Management
	- Packet Loss Prevention Methods
	- Make use of Packet Buffer
	
	- Way to easily handle incoming requests instead of arbitary:
		Event/Func.OnServerInvoke/OnServerEvent
	
		Idea: XPacket.HookFunc() / XPacket.HookEvent
]]

-- Local Variables
local MODULE = {}
local PACKET_QUEUE = table.create(50) -- If > 50 packets then reject.
local PACKET_BUFFER = {} -- Create a Packet Buffer
local PACKET_LOSS_BUFFER = {} -- Keep Track of Packet Losses.
local PACKETS_RECEIVED_BUFFER = {}
local BUILTIN_COMPRESSION = false -- Work in Progress!
local PACKET_PROTOCOLS = EnumList.new(
	"PacketProtocols",
	{ "ClientToServer", "ServerToClient", "ServerToServer", "ClientToClient", "Unspecified" }
)
local PACKET_FLOW_TYPES = EnumList.new("PacketFlowInfo", { "Data", "Event" })
local DEFAULT_PACKET = {
	Arguments = {},
	Callback = nil,
}

local function Enqueue(PACKET_METADATA, PACKET)
	assert(PACKET_METADATA, "MISSING PACKET METADATA")
	assert(PACKET, "MISSING PACKET")

	-- Check if Packet is too big.
	if (PACKET_METADATA.DataLength / 1024) > 1 then
		warn(("Packet #%s is too big. Max: 1kb per packet.\nPacket Size: %.5f kb."):format(PACKET_METADATA.Id, PACKET_METADATA.DataLength / 1024))
		table.insert(PACKET_LOSS_BUFFER, #PACKET_LOSS_BUFFER + 1, 0x1)

		return false
	end

	-- Check if Queue Is Full
	if PACKET_QUEUE[50] ~= nil then
		warn("Queue is full, adding to buffer! Packet Info:\n" .. TableUtil.EncodeJSON(PACKET_METADATA))

		-- Packet to buffer.
		PACKET_BUFFER[#PACKET_BUFFER + 1] = { PACKET_METADATA, PACKET }
		table.insert(PACKET_LOSS_BUFFER, #PACKET_LOSS_BUFFER + 1, 0x1)
		return false
	end

	-- Add packet to queue
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

		-- Add Packaged Packet to Temporary queue
		-- Remove from Packet Queue.
		_Packets[#_Packets + 1] = { v.Meta, Packaged }
		PACKET_QUEUE[i] = {}
		PACKET_QUEUE[i] = nil
	end

	-- Loop Through Packets and commit requests accordingly.
	for k, v in pairs(_Packets) do
		if v[1].FlowType == "Data" then
			if v[1].Protocol == "ClientToServer" then
				local response = nil

				-- TODO: Add Compression Methods

				response = ReplicatedStorage.PacketSender_Func:InvokeServer(v[1])
				table.insert(PACKETS_RECEIVED_BUFFER, #PACKETS_RECEIVED_BUFFER + 1, 0x1)
				warn(("Packet #%s has been recieved successfully."):format(v[1].Id))
				v[1].Callback(response)
			elseif v[1].Protocol == "ServerToClient" then
				assert(v[1].Destination, "MISSING DESTINATION")

				-- TODO: Add Compression Methods

				local response = nil
				response = ReplicatedStorage.PacketSender_Func:InvokeClient(v[1].Destination, v[1])
				table.insert(PACKETS_RECEIVED_BUFFER, #PACKETS_RECEIVED_BUFFER + 1, 0x1)
				warn(("Packet #%s has been recieved successfully."):format(v[1].Id))
				v[1].Callback(response)
			end
		elseif v[1].FlowType == PACKET_FLOW_TYPES.Event then
			if v[1].Protocol == PACKET_PROTOCOLS.ClientToServer then
				-- TODO: Add Compression Methods

				ReplicatedStorage.PacketSender_Event:FireServer(v[1])
				table.insert(PACKETS_RECEIVED_BUFFER, #PACKETS_RECEIVED_BUFFER + 1, 0x1)
				warn(("Packet #%s has been recieved successfully."):format(v[1].Id))
			elseif v[1].Protocol == PACKET_PROTOCOLS.ServerToClient then
				assert(v[1].Destination, "MISSING DESTINATION")

				-- TODO: Add Compression Methods

				ReplicatedStorage.PacketSender_Event:FireClient(v[1].Destination, v[1])
				table.insert(PACKETS_RECEIVED_BUFFER, #PACKETS_RECEIVED_BUFFER + 1, 0x1)
				warn(("Packet #%s has been recieved successfully."):format(v[1].Id))
			end
		end
	end

	-- Loop Through Packet Buffer and
	-- add it to the queue next round.
	local index, value = next(PACKET_BUFFER)
	while index ~= nil do
		if PACKET_QUEUE[50] ~= nil then
			warn("Packet Queue Full, retrying next round.")
			break
		end

		-- Adding to Queue
		PACKET_QUEUE[#PACKET_QUEUE + 1] = {
			Meta = value[1],
			Data = value[2],
		}

		-- DEBUG Print; Removing from buffer.
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
