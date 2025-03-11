#scope_module

/*
A single channel packet. Can contain multiple messages, or a single block message fragment.
*/
ChannelPacketData :: struct {
    Flags :: enum_flags u8 {
        BlockMessage;
        FailedToSerialize;
    }

    MessageData :: struct {
        messages: [] *Message;
    }

    BlockData :: struct {
        message      : *Message;
        fragmentData : [] u8;
        messageId    : u16;
        fragmentId   : u16;
        numFragments : u16;
        messageType  : u16;
    }

    channelIndex: u16;
    flags: Flags;
    union {
        message : MessageData;
        block   : BlockData;
    }
};

channel_packet_data_free :: (using packetData: *ChannelPacketData) {
    if !(flags & .BlockMessage) {
        for message.messages {
            if it != null {
                message_release(it);
            }
        }
        array_reset(*message.messages);
    } else {
        if block.message != null {
            message_release(block.message);
            block.message = null;
        }
        array_reset(*block.fragmentData);
    }
}

channel_packet_data_serialize :: (packetData: *ChannelPacketData, stream: *Stream, messageFactory: MessageFactory, channelConfigs: [MaxChannels] ChannelConfig, numChannels: int) -> bool {
    startBits := stream_get_bits_processed(stream);

    if numChannels > 1 {
        serialize_int(stream, *packetData.channelIndex, cast(u16) 0, cast(u16) numChannels - 1);
    }

    channelConfig := channelConfigs[packetData.channelIndex];

    blockMessage := (packetData.flags & .BlockMessage) != 0;
    serialize_bool(stream, *blockMessage);

    if blockMessage {
        packetData.flags |= .BlockMessage;

        if channelConfig.disableBlocks {
            return false;
        }

        if !serialize_block_fragment(stream, messageFactory, *packetData.block, channelConfig) {
            return false;
        }
    } else {
        if channelConfig.type == {
            case .ReliableOrdered;
                if !serialize_ordered_messages(stream, messageFactory, *packetData.message.messages, channelConfig.maxMessagesPerPacket) {
                    packetData.flags |= .FailedToSerialize;
                    return true;
                }
            case .UnreliableUnordered;
                if !serialize_unordered_messages(stream, messageFactory, *packetData.message.messages, channelConfig.maxMessagesPerPacket, channelConfig.maxBlockSize) {
                    packetData.flags |= .FailedToSerialize;
                    return true;
                }
        }

        if channelConfig.packetBudget > 0 {
            assert(stream_get_bits_processed(stream) - startBits <= channelConfig.packetBudget * 8);
        }
    }

    return true;
}

#scope_file

serialize_ordered_messages :: #bake_arguments serialize_messages(ordered = true, maxBlockSize = 0);
serialize_unordered_messages :: #bake_arguments serialize_messages(ordered = false);

// NOTE: maxBlockSize is unused for ordered messages
serialize_messages :: (stream: *Stream, messageFactory: MessageFactory, messages: *[] *Message, maxMessagesPerPacket: int, maxBlockSize: int, $ordered: bool) -> bool {
    hasMessages := stream.isWriting && messages.count > 0;
    serialize_bool(stream, *hasMessages);
    if !hasMessages {
        return true;
    }

    msgCount := messages.count;
    serialize_int(stream, *msgCount, 1, maxMessagesPerPacket);
    if stream.isReading {
        messages.* = NewArray(msgCount, *Message);
    }

    messageTypes := NewArray(messages.count, u16,, temp);
    #if ordered {
        messageIds := NewArray(messages.count, u16,, temp);
    }

    if stream.isWriting {
        for 0..messages.count-1 {
            assert(messages.*[it] != null);
            messageTypes[it] = messages.*[it].type;
            #if ordered {
                messageIds[it] = messages.*[it].id;
            }
        }
    }

    #if ordered {
        serialize_bits(stream, *messageIds[0], 16);
        for 1..messages.count-1 {
            serialize_sequence_relative(stream, messageIds[it-1], *messageIds[it]);
        }
    }

    for 0..messages.count-1 {
        serialize_int(stream, *messageTypes[it], 0, messageFactory.max_message_type);

        if stream.isReading {
            messages.*[it] = message_acquire(message_factory_create_message(messageFactory, messageTypes[it]));
            if messages.*[it] == null {
                yojimbo_log(.ERROR, "error: failed to create message of type % (serialize_messages[ordered = %]\n", messageTypes[it], ordered);
                return false;
            }

            #if ordered {
                messages.*[it].id = messageIds[it];
            }
        }

        assert(messages.*[it] != null);

        if !messageFactory.serialize(stream, messages.*[it]) {
            yojimbo_log(.ERROR, "error: failed to serialize message of type % (serialize_messages[ordered = %])\n", messageTypes[it], ordered);
            return false;
        }

        #if !ordered {
            if !serialize_message_block(stream, messages.*[it], maxBlockSize) {
                yojimbo_log(.ERROR, "error: failed to serialize unordered block message (serialize_messages)\n");
                return false;
            }
        }
    }

    return true;
}

serialize_block_fragment :: (stream: *Stream, messageFactory: MessageFactory, block: *ChannelPacketData.BlockData, channelConfig: ChannelConfig) -> bool {
    if stream.isReading {
        block.message = null;
        array_free(block.fragmentData);
    }

    serialize_bits(stream, *block.messageId, 16);

    max_fragments_per_block := channel_config_get_max_fragments_per_block(channelConfig);
    if max_fragments_per_block > 1 {
        serialize_int(stream, *block.numFragments, 1, cast(u16) max_fragments_per_block);
    } else {
        if stream.isReading {
            block.numFragments = 1;
        }
    }

    if block.numFragments > 1 {
        serialize_int(stream, *block.fragmentId, 0, block.numFragments - 1);
    } else {
        if stream.isReading {
            block.fragmentId = 0;
        }
    }

    fragmentSize: u32 = cast(u32) block.fragmentData.count;
    serialize_int(stream, *fragmentSize, 1, cast(u32) channelConfig.blockFragmentSize);

    if stream.isReading {
        block.fragmentData = NewArray(fragmentSize, u8);
    }

    serialize_bytes(stream, block.fragmentData);

    if block.fragmentId == 0 {
        // block message
        serialize_int(stream, *block.messageType, 0, messageFactory.max_message_type);

        if stream.isReading {
            block.message = message_acquire(message_factory_create_message(messageFactory, block.messageType));
        }

        assert(block.message != null);

        if !messageFactory.serialize(stream, block.message) {
            yojimbo_log(.ERROR, "error: failed to serialize block message of type % (serialize_block_fragment)\n", block.messageType);
            return false;
        }
    }

    return true;
}