#scope_module

// If the channel gets into an error state, it sets an error state on the corresponding connection. See yojimbo::CONNECTION_ERROR_CHANNEL.
// This way if any channel on a client/server connection gets into a bad state, that client is automatically kicked from the server.
ChannelErrorLevel :: enum {
    None;                 // All is well.
    Desync;               // The connection protocol has desynced and cannot recover. The client should be disconnected.
    SendQueueFull;        // The user tried to send a message but the send queue was full. This will assert out in development, but in production it sets this error on the channel.
    BlocksDisabled;       // The channel received a packet containing data for blocks, but this channel is configured to disable blocks. See ChannelConfig::disableBlocks.
    FailedToDeserialize;  // Deserialize failed for a message sent to this channel. Check your message serialize functions, one of them is returning false when reading. This can also be caused by mismatched read/write logic.
    OutOfMemory;          // The channel tried to allocate some memory but couldn't.
};

// Channel counters provide insight into the number of times an action was performed by a channel.
// They are intended for use in a telemetry system, eg. reported to some backend logging system to track behavior in a production environment.
ChannelCounter :: enum {
    MessagesSent;      // Number of messages sent over this channel.
    MessagesReceived;  // Number of messages received over this channel.
    Count;             // The number of channel counters.
};

// Common functionality shared across all channel types.
Channel :: struct {
    config         : ChannelConfig;               // Channel configuration data.
    channelIndex   : int;                         // The channel index in [0,numChannels-1].
    time           : Apollo_Time;                 // The current time.
    errorLevel     : ChannelErrorLevel;           // The channel error level.
    messageFactory : MessageFactory;              // Message factory for creating and destroying messages.
    counters       : [ChannelCounter.Count] u64;  // Counters for unit testing, stats etc.
};

channel_init :: (channel: *Channel, messageFactory: MessageFactory, config: ChannelConfig, channelIndex: int, time: Apollo_Time) {
    assert(channelIndex >= 0);
    assert(channelIndex < MaxChannels);

    channel.messageFactory = messageFactory;
    channel.config = config;
    channel.channelIndex = channelIndex;
    channel.time = time;
}

channel_free :: (channel: *Channel) {
    if #complete channel.config.type == {
        case .ReliableOrdered;      channel_free(cast(*ReliableOrderedChannel) channel);
        case .UnreliableUnordered;  channel_free(cast(*UnreliableUnorderedChannel) channel);
        case; assert(false, "Invalid channel type");
    }
}

channel_reset :: (channel: *Channel) {
    if #complete channel.config.type == {
        case .ReliableOrdered;      channel_reset(cast(*ReliableOrderedChannel) channel);
        case .UnreliableUnordered;  channel_reset(cast(*UnreliableUnorderedChannel) channel);
        case; assert(false, "Invalid channel type");
    }
}

channel_can_send_message :: (channel: *Channel) -> bool {
    if #complete channel.config.type == {
        case .ReliableOrdered;      return channel_can_send_message(cast(*ReliableOrderedChannel) channel);
        case .UnreliableUnordered;  return channel_can_send_message(cast(*UnreliableUnorderedChannel) channel);
        case; assert(false, "Invalid channel type");
    }
    return false;
}

channel_has_messages_to_send :: (channel: *Channel) -> bool {
    if #complete channel.config.type == {
        case .ReliableOrdered;      return channel_has_messages_to_send(cast(*ReliableOrderedChannel) channel);
        case .UnreliableUnordered;  return channel_has_messages_to_send(cast(*UnreliableUnorderedChannel) channel);
        case; assert(false, "Invalid channel type");
    }
    return false;
}

// Queue a message for send
channel_send_message :: (channel: *Channel, message: *Message) {
    if #complete channel.config.type == {
        case .ReliableOrdered;      channel_send_message(cast(*ReliableOrderedChannel) channel, message);
        case .UnreliableUnordered;  channel_send_message(cast(*UnreliableUnorderedChannel) channel, message);
        case; assert(false, "Invalid channel type");
    }
}

// Pops the next message off the receive queue if one is available.
// @returns A pointer to the received message, NULL if there are no messages to receive. The caller owns the message object returned by this function and is responsible for releasing it via Message::Release.
channel_receive_message :: (channel: *Channel) -> *Message {
    if #complete channel.config.type == {
        case .ReliableOrdered;      return channel_receive_message(cast(*ReliableOrderedChannel) channel);
        case .UnreliableUnordered;  return channel_receive_message(cast(*UnreliableUnorderedChannel) channel);
        case; assert(false, "Invalid channel type");
    }
    return null;
}

// Advance channel time
// Called by connection_advance_time for each channel configured on the connection.
channel_advance_time :: (channel: *Channel, time: Apollo_Time) {
    if #complete channel.config.type == {
        case .ReliableOrdered;      channel_advance_time(cast(*ReliableOrderedChannel) channel, time);
        case .UnreliableUnordered;  channel_advance_time(cast(*UnreliableUnorderedChannel) channel, time);
        case; assert(false, "Invalid channel type");
    }
}

// Get channel packet data for this channel.
// @param packetData The channel packet data to be filled [out]
// @param packetSequence The sequence number of the packet being generated.
// @param availableBits The maximum number of bits of packet data the channel is allowed to write.
// @returns The number of bits of packet data written by the channel.
// @see ConnectionPacket
// @see Connection::GeneratePacket
channel_generate_packet_data :: (channel: *Channel, packetData: *ChannelPacketData, packetSequence: u16, availableBits: int) -> int {
    if #complete channel.config.type == {
        case .ReliableOrdered;      return channel_generate_packet_data(cast(*ReliableOrderedChannel) channel, packetData, packetSequence, availableBits);
        case .UnreliableUnordered;  return channel_generate_packet_data(cast(*UnreliableUnorderedChannel) channel, packetData, packetSequence, availableBits);
        case; assert(false, "Invalid channel type");
    }
    return 0;
}

// Process packet data included in a connection packet.
// @param packetData The channel packet data to process.
// @param packetSequence The sequence number of the connection packet that contains the channel packet data.
// @see ConnectionPacket
// @see Connection::ProcessPacket
channel_process_packet_data :: (channel: *Channel, packetData: *ChannelPacketData, packetSequence: u16) {
    if #complete channel.config.type == {
        case .ReliableOrdered;      channel_process_packet_data(cast(*ReliableOrderedChannel) channel, packetData, packetSequence);
        case .UnreliableUnordered;  channel_process_packet_data(cast(*UnreliableUnorderedChannel) channel, packetData, packetSequence);
        case; assert(false, "Invalid channel type");
    }
}

// Process a connection packet ack.
// Depending on the channel type:
//     1. Acks messages and block fragments so they stop being included in outgoing connection packets (reliable-ordered channel),
//     2. Does nothing at all (unreliable-unordered).
// @param sequence The sequence number of the connection packet that was acked.
channel_process_ack :: (channel: *Channel, ack: u16) {
    if #complete channel.config.type == {
        case .ReliableOrdered;      channel_process_ack(cast(*ReliableOrderedChannel) channel, ack);
        case .UnreliableUnordered;  channel_process_ack(cast(*UnreliableUnorderedChannel) channel, ack);
        case; assert(false, "Invalid channel type");
    }
}

// Gets the channel index.
// @returns The channel index in [0,numChannels-1].
channel_get_index :: (channel: *Channel) -> int {
    return channel.channelIndex;
}

// Get the channel error level.
// @returns The channel error level.
channel_get_error_level :: (channel: *Channel) -> ChannelErrorLevel {
    return channel.errorLevel;
}

// Set the channel error level.
// All errors go through this function to make debug logging easier.
channel_set_error_level :: (channel: *Channel, errorLevel: ChannelErrorLevel) {
    if errorLevel != channel.errorLevel && errorLevel != .None {
        yojimbo_log(.ERROR, "channel went into error state: %\n", errorLevel);
    }
    channel.errorLevel = errorLevel;
}

// Get a counter value.
// @param index The index of the counter to retrieve. See ChannelCounters.
// @returns The value of the counter.
// @see ResetCounters
channel_get_counter :: (channel: *Channel, counter: ChannelCounter) -> u64 {
    return channel.counters[counter];
}

// Resets all counter values to zero.
channel_reset_counters :: (channel: *Channel) {
    array_zero(channel.counters);
}
