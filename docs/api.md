# XPacket API

## XPacket.Enqueue(packet_metadata: Dictionary, packet: Dictionary)

#### [Client & Server-Side]

This method takes in 2 dictionaries that then get enqueued in order
to be sent across the boundary.

The template for `packet_metadata`:
```lua
{
    -- Version = string: Use it as a unique handle to identify action.
    -- FlowType = string: Either Data or Event, Data = RemoteFunction; Event = RemoteEvent.
    -- Protocol = string: Self Explanatory, (['ClientToServer', 'ServerToClient'])
    -- TimeToLive = number: Timeout in Seconds
    -- DataLength = number: Length of data in bytes.
    -- Source = string: Where it comes from, (['SERVER','CLIENT'])
    -- Destination = string: Where it should be sent to. In event of ServerToClient have it as Player.
    -- Id = GUID: Unqiue Identifier
    -- Callback = function: Called when RemoteFunction returns in the other side.
}
```

The template for `packet`:
```lua
{
    -- Arguments = table: A table or dictionary with arguments passed onto the other side
}
```

## XPacket.HandleQueue()

#### [Client & Server-Side]

This method handles the queue and sends a remote to complete all requests in queue.

**This method shall always be called last, or it wont handle queue entries after the fact.**