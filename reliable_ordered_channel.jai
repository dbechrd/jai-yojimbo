#scope_module

/*
Messages sent across this channel are guaranteed to arrive in the order they were sent.
This channel type is best used for control messages and RPCs.
Messages sent over this channel are included in connection packets until one of those packets is acked. Messages are acked individually and remain in the send queue until acked.
Blocks attached to messages sent over this channel are split up into fragments. Each fragment of the block is included in a connection packet until one of those packets are acked. Eventually, all fragments are received on the other side, and block is reassembled and attached to the message.
Only one message block may be in flight over the network at any time, so blocks stall out message delivery slightly. Therefore, only use blocks for large data that won't fit inside a single connection packet where you actually need the channel to split it up into fragments. If your block fits inside a packet, just serialize it inside your message serialize via serialize_bytes instead.
*/
ReliableOrderedChannel :: struct {
    #as using base: Channel;

    sendMessageId          : u16;                                       // Id of the next message to be added to the send queue.
    receiveMessageId       : u16;                                       // Id of the next message to be added to the receive queue.
    oldestUnackedMessageId : u16;                                       // Id of the oldest unacked message in the send queue.
    sentPackets            : SequenceBuffer(SentPacketEntry);           // Stores information per sent connection packet about messages and block data included in each packet. Used to walk from connection packet level acks to message and data block fragment level acks.
    messageSendQueue       : SequenceBuffer(MessageSendQueueEntry);     // Message send queue.
    messageReceiveQueue    : SequenceBuffer(MessageReceiveQueueEntry);  // Message receive queue.
    sentPacketMessageIds   : [] u16;                                    // Array of n message ids per sent connection packet. Allows the maximum number of messages per-packet to be allocated dynamically.
    sendBlock              : *SendBlockData;                            // Data about the block being currently sent.
    receiveBlock           : *ReceiveBlockData;                         // Data about the block being currently received.
};

/*
Reliable ordered channel constructor.
@param allocator The allocator to use.
@param messageFactory Message factory for creating and destroying messages.
@param config The configuration for this channel.
@param channelIndex The channel index in [0,numChannels-1].
*/
channel_init :: (using channel: *ReliableOrderedChannel, _messageFactory: MessageFactory, _config: ChannelConfig, _channelIndex: int, _time: Apollo_Time) {
    assert(_config.type == .ReliableOrdered);

    channel_init(*base, _messageFactory, _config, _channelIndex, _time);

    assert((65536 % config.sentPacketBufferSize) == 0);
    assert((65536 % config.messageSendQueueSize) == 0);
    assert((65536 % config.messageReceiveQueueSize) == 0);

    sequence_buffer_init(*sentPackets, config.sentPacketBufferSize);
    sequence_buffer_init(*messageSendQueue, config.messageSendQueueSize);
    sequence_buffer_init(*messageReceiveQueue, config.messageReceiveQueueSize);
    sentPacketMessageIds = NewArray(config.maxMessagesPerPacket * config.sentPacketBufferSize, u16);

    if !config.disableBlocks {
        maxFragmentsPerBlock := channel_config_get_max_fragments_per_block(config);
        sendBlock = New(SendBlockData);
        send_block_data_init(sendBlock, maxFragmentsPerBlock);
        receiveBlock = New(ReceiveBlockData);
        receive_block_data_init(receiveBlock, config.maxBlockSize, maxFragmentsPerBlock);
    }

    // This seems pointless, everything is zero'd by default in Jai.
    //channel_reset(channel);
}

/*
Reliable ordered channel destructor.
Any messages still in the send or receive queues will be released.
*/
channel_free :: (using channel: *ReliableOrderedChannel) {
    channel_release_messages(channel);

    sequence_buffer_free(*sentPackets);
    sequence_buffer_free(*messageSendQueue);
    sequence_buffer_free(*messageReceiveQueue);
    array_free(sentPacketMessageIds);

    send_block_data_free(sendBlock);
    free(sendBlock);
    receive_block_data_free(receiveBlock);
    free(receiveBlock);
}

channel_reset :: (using channel: *ReliableOrderedChannel) {
    channel_release_messages(channel);

    errorLevel = .None;

    sendMessageId = 0;
    receiveMessageId = 0;
    oldestUnackedMessageId = 0;

    sequence_buffer_reset(*sentPackets);
    sequence_buffer_reset(*messageSendQueue);
    sequence_buffer_reset(*messageReceiveQueue);

    if sendBlock != null {
        send_block_data_reset(sendBlock);
    }

    if receiveBlock != null {
        receive_block_data_reset(receiveBlock);
    }

    channel_reset_counters(channel);
}

channel_can_send_message :: (using channel: *ReliableOrderedChannel) -> bool {
    return sequence_buffer_available(*messageSendQueue, sendMessageId);
}

channel_send_message :: (using channel: *ReliableOrderedChannel, message: *Message) {
    assert(message != null);
    assert(channel_can_send_message(channel));

    if errorLevel != .None {
        message_release(message);
        return;
    }

    if !channel_can_send_message(channel) {
        // Increase your send queue size!
        errorLevel = .SendQueueFull;
        message_release(message);
        return;
    }

    message.id = sendMessageId;

    sendQueueEntry := sequence_buffer_insert(*messageSendQueue, sendMessageId);
    assert(sendQueueEntry != null);

    // Overwrite any previous values because sequence buffer entries get reused
    sendQueueEntry.* = .{ message = message_acquire(message) };

    assert(message.blockData.count <= config.maxBlockSize);

    measureStream: MeasureStream;
    messageFactory[message.type].serialize(*measureStream, message);
    sendQueueEntry.measuredBits = stream_get_bits_processed(*measureStream);
    counters[ChannelCounter.MessagesSent] += 1;
    sendMessageId += 1;
}

channel_receive_message :: (using channel: *ReliableOrderedChannel) -> *Message {
    if errorLevel != .None {
        return null;
    }

    entry := sequence_buffer_find(*messageReceiveQueue, receiveMessageId);
    if entry == null {
        return null;
    }

    message := entry.message;
    assert(message != null);
    assert(message.id == receiveMessageId);
    sequence_buffer_remove(*messageReceiveQueue, receiveMessageId);
    counters[ChannelCounter.MessagesReceived] += 1;
    receiveMessageId += 1;

    return message;
}

channel_advance_time :: (using channel: *ReliableOrderedChannel, _time: Apollo_Time) {
    time = _time;
}

channel_generate_packet_data :: (using channel: *ReliableOrderedChannel, packetData: *ChannelPacketData, packetSequence: u16, availableBits: int) -> int {
    if !channel_has_messages_to_send(channel) {
        return 0;
    }

    if channel_sending_block_message(channel) {
        if config.blockFragmentSize * 8 > availableBits {
            return 0;
        }

        fragmentData, messageId, fragmentId, numFragments, messageType := channel_get_fragment_to_send(channel);
        if fragmentData.count > 0 {
            fragmentBits := channel_get_fragment_packet_data(channel, packetData, messageId, fragmentId, fragmentData, numFragments, messageType);
            channel_add_fragment_packet_entry(channel, messageId, fragmentId, packetSequence);
            return fragmentBits;
        }
    } else {
        messageIds := NewArray(config.maxMessagesPerPacket, u16,, temp);
        numMessageIds, messageBits := channel_get_messages_to_send(channel, messageIds, availableBits);
        messageIds.count = numMessageIds;

        if numMessageIds > 0 {
            channel_get_message_packet_data(channel, packetData, messageIds);
            channel_add_message_packet_entry(channel, messageIds, packetSequence);
            return messageBits;
        }
    }

    return 0;
}

/*
Are there any unacked messages in the send queue?
Messages are acked individually and remain in the send queue until acked.
@returns True if there is at least one unacked message in the send queue.
*/
channel_has_messages_to_send :: (using channel: *ReliableOrderedChannel) -> bool {
    return oldestUnackedMessageId != sendMessageId;
}

/*
Get messages to include in a packet.
Messages are measured to see how many bits they take, and only messages that fit within the channel packet budget will be included. See ChannelConfig::packetBudget.
Takes care not to send messages too rapidly by respecting ChannelConfig::messageResendTime for each message, and to only include messages that that the receiver is able to buffer in their receive queue. In other words, won't run ahead of the receiver.
@param messageIds Array of message ids to be filled [out]. Fills up to ChannelConfig::maxMessagesPerPacket messages, make sure your array is at least this size.
@param numMessageIds The number of message ids written to the array.
@param remainingPacketBits Number of bits remaining in the packet. Considers this as a hard limit when determining how many messages can fit into the packet.
@returns Estimate of the number of bits required to serialize the messages (upper bound).
@see GetMessagePacketData
*/
channel_get_messages_to_send :: (using channel: *ReliableOrderedChannel, messageIds: [] u16, availableBits: int) -> numMessageIds: int, usedBits: int {
    assert(channel_has_messages_to_send(channel));

    numMessageIds := 0;

    budgetedBits := availableBits;
    if config.packetBudget > 0 {
        budgetedBits = min(config.packetBudget * 8, availableBits);
    }

    giveUpBits := 4 * 8;
    giveUpCounter := 0;

    assert(messageFactory.count > 0);
    messageTypeBits := bits_required(0, cast(u64) messageFactory.count-1);

    messageLimit := min(config.messageSendQueueSize, config.messageReceiveQueueSize);
    previousMessageId: u16 = 0;
    usedBits := ConservativeMessageHeaderBits;
    maxBits := availableBits;

    for 0..messageLimit-1 {
        if availableBits - usedBits < giveUpBits {
            break;
        }
        if giveUpCounter > config.messageSendQueueSize {
            break;
        }
        if numMessageIds == config.maxMessagesPerPacket {
            break;
        }

        messageId := oldestUnackedMessageId + cast(u16) it;
        entry := sequence_buffer_find(*messageSendQueue, messageId);
        if entry == null {
            continue;
        }
        if entry.message.blockData.count > 0 {
            break;
        }

        assert(entry.measuredBits <= maxBits, "Increase your max packet size!");

        if entry.timeLastSent + config.messageResendTime <= time && availableBits >= entry.measuredBits {
            messageBits := entry.measuredBits + messageTypeBits;

            if numMessageIds == 0 {
                messageBits += 16;
            } else {
                stream: MeasureStream;
                serialize_sequence_relative(*stream, previousMessageId, *messageId);
                messageBits += stream_get_bits_processed(*stream);
            }

            if usedBits + messageBits > availableBits {
                giveUpCounter += 1;
                continue;
            }

            usedBits += messageBits;
            messageIds[numMessageIds] = messageId;
            numMessageIds += 1;
            previousMessageId = messageId;
            entry.timeLastSent = time;
        }
    }

    return numMessageIds, usedBits;
}

/*
Fill channel packet data with messages.
This is the payload function to fill packet data while sending regular messages (without blocks attached).
Messages have references added to them when they are added to the packet. They also have a reference while they are stored in a send or receive queue. Messages are cleaned up when they are no longer in a queue, and no longer referenced by any packets.
@param packetData The packet data to fill [out]
@param messageIds Array of message ids identifying which messages to add to the packet from the message send queue.
@param numMessageIds The number of message ids in the array.
@see GetMessagesToSend
*/
channel_get_message_packet_data :: (using channel: *ReliableOrderedChannel, packetData: *ChannelPacketData, messageIds: [] u16) {
    packetData.channelIndex = cast(u16) channelIndex;

    if messageIds.count == 0 {
        return;
    }

    packetData.message.messages = NewArray(messageIds.count, *Message);

    for 0..messageIds.count-1 {
        entry := sequence_buffer_find(*messageSendQueue, messageIds[it]);
        assert(entry != null);
        assert(entry.message != null);

        packetData.message.messages[it] = message_acquire(entry.message);
    }
}

/*
Add a packet entry for the set of messages included in a packet.
This lets us look up the set of messages that were included in that packet later on when it is acked, so we can ack those messages individually.
@param messageIds The set of message ids that were included in the packet.
@param numMessageIds The number of message ids in the array.
@param sequence The sequence number of the connection packet the messages were included in.
*/
channel_add_message_packet_entry :: (using channel: *ReliableOrderedChannel, messageIds: [] u16, sequence: u16) {
    sentPacket := sequence_buffer_insert(*sentPackets, sequence, guaranteedOrder = true);
    assert(sentPacket != null);
    if sentPacket != null {
        sentPacket.acked = false;
        sentPacket.block = false;
        sentPacket.timeSent = time;
        sentPacket.messageIds = *sentPacketMessageIds[(sequence % config.sentPacketBufferSize) * config.maxMessagesPerPacket];
        sentPacket.numMessageIds = messageIds.count;
        for 0..messageIds.count-1 {
            sentPacket.messageIds[it] = messageIds[it];
        }
    }
}

/*
Process messages included in a packet.
Any messages that have not already been received are added to the message receive queue. Messages that are added to the receive queue have a reference added. See Message::AddRef.
@param messages Array of pointers to messages.
*/
channel_process_packet_messages :: (using channel: *ReliableOrderedChannel, messages: [] *Message) {
    minMessageId := receiveMessageId;
    maxMessageId := receiveMessageId + cast(u16) config.messageReceiveQueueSize - 1;

    for message: messages {
        assert(message != null);

        if yojimbo_sequence_less_than(message.id, minMessageId) {
            continue;
        }

        if yojimbo_sequence_greater_than(message.id, maxMessageId) {
            // Did you forget to dequeue messages on the receiver?
            yojimbo_log(.ERROR, "sequence overflow: % vs. [%,%]\n", message.id, minMessageId, maxMessageId);
            errorLevel = .Desync;
            return;
        }

        if sequence_buffer_find(*messageReceiveQueue, message.id) {
            continue;
        }

        assert(sequence_buffer_get_at_index(*messageReceiveQueue, sequence_buffer_get_index(*messageReceiveQueue, message.id)) == null);

        entry := sequence_buffer_insert(*messageReceiveQueue, message.id);
        if entry == null {
            // For some reason we can't insert the message in the receive queue
            yojimbo_log(.ERROR, "failed to insert message % into receive queue\n", message.id);
            errorLevel = .Desync;
            return;
        }

        entry.message = message_acquire(message);
    }
}

channel_process_packet_data :: (using channel: *ReliableOrderedChannel, packetData: *ChannelPacketData, packetSequence: u16) {
    if errorLevel != .None {
        return;
    }

    if packetData.flags & .FailedToSerialize {
        // A message failed to deserialize for some reason, eg. mismatched read/write.
        errorLevel = .FailedToDeserialize;
        return;
    }

    if packetData.flags & .BlockMessage {
        // TODO(dlb): Wtf is this shit? Just pass the block, bro. -_-
        channel_process_packet_fragment(
            channel,
            packetData.block.messageType,
            packetData.block.messageId,
            packetData.block.numFragments,
            packetData.block.fragmentId,
            packetData.block.fragmentData,
            packetData.block.message
        );
    } else {
        channel_process_packet_messages(channel, packetData.message.messages);
    }
}

channel_process_ack :: (using channel: *ReliableOrderedChannel, ack: u16) {
    sentPacketEntry := sequence_buffer_find(*sentPackets, ack);
    if sentPacketEntry == null {
        return;
    }

    assert(!sentPacketEntry.acked);

    for 0..sentPacketEntry.numMessageIds-1 {
        messageId := sentPacketEntry.messageIds[it];
        sendQueueEntry := sequence_buffer_find(*messageSendQueue, messageId);
        if sendQueueEntry != null {
            assert(sendQueueEntry.message != null);
            assert(sendQueueEntry.message.id == messageId);

            message_release(sendQueueEntry.message);
            sequence_buffer_remove(*messageSendQueue, messageId);
            channel_update_oldest_unacked_message_id(channel);
        }
    }

    if !config.disableBlocks && sentPacketEntry.block && sendBlock.active && sendBlock.blockMessageId == sentPacketEntry.blockMessageId {
        messageId := sentPacketEntry.blockMessageId;
        fragmentId := sentPacketEntry.blockFragmentId;

        if !sendBlock.ackedFragment[fragmentId] {
            sendBlock.ackedFragment[fragmentId] = true;
            sendBlock.numAckedFragments += 1;

            if sendBlock.numAckedFragments == sendBlock.numFragments {
                send_block_data_reset(sendBlock);

                sendQueueEntry := sequence_buffer_find(*messageSendQueue, messageId);
                assert(sendQueueEntry != null);

                message_release(sendQueueEntry.message);
                sequence_buffer_remove(*messageSendQueue, messageId);
                channel_update_oldest_unacked_message_id(channel);
            }
        }
    }
}

/*
Track the oldest unacked message id in the send queue.
Because messages are acked individually, the send queue is not a true queue and may have holes.
Because of this it is necessary to periodically walk forward from the previous oldest unacked message id, to find the current oldest unacked message id.
This lets us know our starting point for considering messages to include in the next packet we send.
@see GetMessagesToSend
*/
channel_update_oldest_unacked_message_id :: (using channel: *ReliableOrderedChannel) {
    stopMessageId := messageSendQueue.nextSequence;

    while true {
        if oldestUnackedMessageId == stopMessageId || sequence_buffer_exists(*messageSendQueue, oldestUnackedMessageId) {
            break;
        }
        oldestUnackedMessageId += 1;
    }

    assert(!yojimbo_sequence_greater_than(oldestUnackedMessageId, stopMessageId));
}

/*
True if we are currently sending a block message.
Block messages are treated differently to regular messages.
Regular messages are small so we try to fit as many into the packet we can. See ReliableChannelData::GetMessagesToSend.
Blocks attached to block messages are usually larger than the maximum packet size or channel budget, so they are split up fragments.
While in the mode of sending a block message, each channel packet data generated has exactly one fragment from the current block in it. Fragments keep getting included in packets until all fragments of that block are acked.
@returns True if currently sending a block message over the network, false otherwise.
@see BlockMessage
@see GetFragmentToSend
*/
channel_sending_block_message :: (using channel: *ReliableOrderedChannel) -> bool {
    assert(channel_has_messages_to_send(channel));

    entry := sequence_buffer_find(*messageSendQueue, oldestUnackedMessageId);
    return ifx entry != null then entry.message.blockData.count > 0 else false;
}

/*
Get the next block fragment to send.
The next block fragment is selected by scanning left to right over the set of fragments in the block, skipping over any fragments that have already been acked or have been sent within ChannelConfig::fragmentResendTime.
@param messageId The id of the message that the block is attached to [out].
@param fragmentId The id of the fragment to send [out].
@param fragmentBytes The size of the fragment in bytes.
@param numFragments The total number of fragments in this block.
@param messageType The type of message the block is attached to. See MessageFactory.
@returns Pointer to the fragment data.
*/
channel_get_fragment_to_send :: (using channel: *ReliableOrderedChannel) -> fragmentData: [] u8, messageId: u16, fragmentId: u16, numFragments: int, messageType: u16 {
    entry := sequence_buffer_find(*messageSendQueue, oldestUnackedMessageId);
    assert(entry != null);

    message := entry.message;
    assert(message.blockData.count > 0);

    if !sendBlock.active {
        // start sending this block
        sendBlock.active = true;
        sendBlock.blockSize = message.blockData.count;
        sendBlock.blockMessageId = message.id;
        sendBlock.numFragments = cast(int) Math.ceil(message.blockData.count / cast(float) config.blockFragmentSize);

        maxFragmentsPerBlock := channel_config_get_max_fragments_per_block(config);
        assert(sendBlock.numFragments > 0);
        assert(sendBlock.numFragments <= maxFragmentsPerBlock);
    }

    // find the next fragment to send (there may not be one)
    fragmentId: u16 = 0xFFFF;
    for 0..sendBlock.numFragments-1 {
        if !sendBlock.ackedFragment[it] && sendBlock.fragmentSendTime[it] + config.blockFragmentResendTime < time {
            fragmentId = cast(u16) it;
            break;
        }
    }

    if fragmentId == 0xFFFF {
        return .{}, 0, 0, 0, 0;
    }

    // allocate and return a copy of the fragment data
    fragmentBytes := config.blockFragmentSize;
    fragmentRemainder := message.blockData.count % config.blockFragmentSize;
    if fragmentRemainder && fragmentId == sendBlock.numFragments-1 {
        fragmentBytes = fragmentRemainder;
    }

    fragmentData := NewArray(fragmentBytes, u8);
    if fragmentData.count > 0 {
        memcpy(fragmentData.data, message.blockData.data + fragmentId * config.blockFragmentSize, fragmentBytes);
        sendBlock.fragmentSendTime[fragmentId] = time;
    }

    // TODO(dlb): The return value here is absolutely ridiculous.. maybe make a struct?
    return fragmentData, message.id, fragmentId, sendBlock.numFragments, message.type;
}

/*
Fill the packet data with block and fragment data.
This is the payload function that fills the channel packet data while we are sending a block message.
@param packetData The packet data to fill [out]
@param messageId The id of the message that the block is attached to.
@param fragmentId The id of the block fragment being sent.
@param fragmentData The fragment data.
@param numFragments The number of fragments in the block.
@param messageType The type of message the block is attached to.
@returns An estimate of the number of bits required to serialize the block message and fragment data (upper bound).
*/
channel_get_fragment_packet_data :: (using channel: *ReliableOrderedChannel, packetData: *ChannelPacketData, messageId: u16, fragmentId: u16, fragmentData: [] u8, numFragments: int, messageType: u16) -> int {
    packetData.channelIndex = cast(u16) channelIndex;
    packetData.flags |= .BlockMessage;
    packetData.block.fragmentData = fragmentData;
    packetData.block.messageId = messageId;
    packetData.block.fragmentId = fragmentId;
    packetData.block.numFragments = cast(u16) numFragments;
    packetData.block.messageType = messageType;

    assert(messageFactory.count > 0);
    messageTypeBits := bits_required(0, cast(u64) messageFactory.count-1);
    fragmentBits := ConservativeFragmentHeaderBits + fragmentData.count * 8;

    if fragmentId == 0 {
        entry := sequence_buffer_find(*messageSendQueue, packetData.block.messageId);
        assert(entry != null);
        assert(entry.message != null);

        packetData.block.message = message_acquire(entry.message);
        fragmentBits += entry.measuredBits + messageTypeBits;
    } else {
        packetData.block.message = null;
    }

    return fragmentBits;
}

/*
Adds a packet entry for the fragment.
This lets us look up the fragment that was in the packet later on when it is acked, so we can ack that block fragment.
@param messageId The message id that the block was attached to.
@param fragmentId The fragment id.
@param sequence The sequence number of the packet the fragment was included in.
*/
channel_add_fragment_packet_entry :: (using channel: *ReliableOrderedChannel, messageId: u16, fragmentId: u16, sequence: u16) {
    sentPacket := sequence_buffer_insert(*sentPackets, sequence, true);
    assert(sentPacket != null);

    if sentPacket != null {
        sentPacket.timeSent = time;
        sentPacket.messageIds = null;
        sentPacket.numMessageIds = 0;
        sentPacket.acked = false;
        sentPacket.block = true;
        sentPacket.blockMessageId = messageId;
        sentPacket.blockFragmentId = fragmentId;
    }
}

/*
Process a packet fragment.
The fragment is added to the set of received fragments for the block. When all packet fragments are received, that block is reconstructed, attached to the block message and added to the message receive queue.
@param messageType The type of the message this block fragment is attached to. This is used to make sure this message type actually allows blocks to be attached to it.
@param messageId The id of the message the block fragment belongs to.
@param numFragments The number of fragments in the block.
@param fragmentId The id of the fragment in [0,numFragments-1].
@param fragmentData The fragment data.
@param fragmentBytes The size of the fragment data in bytes.
@param blockMessage Pointer to the block message. Passed this in only with the first fragment (0), pass NULL for all other fragments.
*/
channel_process_packet_fragment :: (using channel: *ReliableOrderedChannel, messageType: int, messageId: u16, numFragments: int, fragmentId: u16, fragmentData: [] u8, blockMessage: *Message) {
    assert(!config.disableBlocks);

    if fragmentData.count > 0 {
        expectedMessageId := messageReceiveQueue.nextSequence;
        if messageId != expectedMessageId {
            return;
        }

        // start receiving a new block
        if !receiveBlock.active {
            maxFragmentsPerBlock := channel_config_get_max_fragments_per_block(config);
            assert(numFragments >= 0);
            assert(numFragments <= maxFragmentsPerBlock);

            receiveBlock.active = true;
            receiveBlock.numFragments = numFragments;
            receiveBlock.messageId = messageId;
        }

        // validate fragment
        if fragmentId >= receiveBlock.numFragments {
            // The fragment id is out of range.
            errorLevel = .Desync;
            return;
        }

        if numFragments != receiveBlock.numFragments {
            // The number of fragments is out of range.
            errorLevel = .Desync;
            return;
        }

        // receive the fragment
        if !receiveBlock.receivedFragment[fragmentId] {
            receiveBlock.receivedFragment[fragmentId] = true;

            memcpy(receiveBlock.blockData.data + fragmentId * config.blockFragmentSize, fragmentData.data, fragmentData.count);

            // first fragment
            if fragmentId == 0 {
                receiveBlock.messageType = messageType;
            }

            // last fragment
            if fragmentId == receiveBlock.numFragments-1 {
                receiveBlock.blockSize = (receiveBlock.numFragments-1) * config.blockFragmentSize + fragmentData.count;

                if receiveBlock.blockSize > config.maxBlockSize {
                    // The block size is outside range
                    errorLevel = .Desync;
                    return;
                }
            }

            receiveBlock.numReceivedFragments += 1;

            if fragmentId == 0 {
                // save block message (sent with fragment 0)
                receiveBlock.blockMessage = message_acquire(blockMessage);
            }

            if receiveBlock.numReceivedFragments == receiveBlock.numFragments {
                // finished receiving block
                if sequence_buffer_exists(*messageReceiveQueue, messageId) {
                    // Did you forget to dequeue messages on the receiver?
                    errorLevel = .Desync;
                    return;
                }

                assert(receiveBlock.blockMessage != null);

                blockData := NewArray(receiveBlock.blockSize, u8);
                if blockData.count == 0 {
                    // Not enough memory to allocate block data
                    errorLevel = .OutOfMemory;
                    return;
                }
                memcpy(blockData.data, receiveBlock.blockData.data, receiveBlock.blockSize);

                receiveBlock.blockMessage.id = messageId;
                receiveBlock.blockMessage.blockData = blockData;

                entry := sequence_buffer_insert(*messageReceiveQueue, messageId);
                assert(entry != null);

                entry.message = message_acquire(receiveBlock.blockMessage);
                receive_block_data_reset(receiveBlock);
            }
        }
    }
}

// TODO: Revert this, need for debug
//#scope_file

#import "Bit_Array";

/*
An entry in the send queue of the reliable-ordered channel.
Messages stay into the send queue until acked. Each message is acked individually, so there can be "holes" in the message send queue.
*/
MessageSendQueueEntry :: struct {
    message      : *Message;     // Pointer to the message. When inserted in the send queue the message has one reference. It is released when the message is acked and removed from the send queue.
    timeLastSent : Apollo_Time;  // The time the message was last sent. Used to implement ChannelConfig::messageResendTime.
    measuredBits : int;          // The number of bits the message takes up in a bit stream.
};

/*
An entry in the receive queue of the reliable-ordered channel.
*/
MessageReceiveQueueEntry :: struct {
    message: *Message;  // The message pointer. Has at a reference count of at least 1 while in the receive queue. Ownership of the message is passed back to the caller when the message is dequeued.
};

/*
Maps packet level acks to messages and fragments for the reliable-ordered channel.
*/
SentPacketEntry :: struct {
    timeSent        : Apollo_Time;  // The time the packet was sent. Used to estimate round trip time.
    messageIds      : *u16;         // Pointer to sub-array of ReliableOrderedChannel.sentPacketMessageIds (do not alloc/free this here!). Dynamically allocated because the user can configure the maximum number of messages in a packet per-channel with ChannelConfig::maxMessagesPerPacket.
    numMessageIds   : int;          // The number of message ids in the array.
    acked           : bool;         // true if this packet has been acked.
    block           : bool;         // true if this packet contains a fragment of a block message.
    blockMessageId  : u16;          // The block message id. Valid only if "block" is true.
    blockFragmentId : u16;          // The block fragment id. Valid only if "block" is true.
};

/*
Internal state for a block being sent across the reliable ordered channel.
Stores the block data and tracks which fragments have been acked. The block send completes when all fragments have been acked.
IMPORTANT: Although there can be multiple block messages in the message send and receive queues, only one data block can be in flights over the wire at a time.
*/
SendBlockData :: struct {
    active            : bool;            // True if we are currently sending a block.
    blockSize         : int;             // The size of the block (bytes).
    numFragments      : int;             // Number of fragments in the block being sent.
    numAckedFragments : int;             // Number of acked fragments in the block being sent.
    blockMessageId    : u16;             // The message id the block is attached to.
    ackedFragment     : Bit_Array;       // Has fragment n been received?
    fragmentSendTime  : [] Apollo_Time;  // Last time fragment was sent.
};

send_block_data_init :: (using sendBlockData: *SendBlockData, maxFragmentsPerBlock: int) {
    init_bit_array(*ackedFragment, maxFragmentsPerBlock);
    fragmentSendTime = NewArray(maxFragmentsPerBlock, Apollo_Time);
}

send_block_data_free :: (using sendBlockData: *SendBlockData) {
    deinit(*ackedFragment);
    array_free(fragmentSendTime);
}

send_block_data_reset :: (using sendBlockData: *SendBlockData) {
    active = false;
    blockSize = 0;
    numFragments = 0;
    numAckedFragments = 0;
    blockMessageId = 0;
    clear_all_bits(*ackedFragment);
    array_zero(fragmentSendTime);
}

/*
Internal state for a block being received across the reliable ordered channel.
Stores the fragments received over the network for the block, and completes once all fragments have been received.
IMPORTANT: Although there can be multiple block messages in the message send and receive queues, only one data block can be in flight over the wire at a time.
*/
ReceiveBlockData :: struct {
    active               : bool;       // True if we are currently receiving a block.
    numFragments         : int;        // The number of fragments in this block
    numReceivedFragments : int;        // The number of fragments received.
    messageId            : u16;        // The message id corresponding to the block.
    messageType          : int;        // Message type of the block being received.
    blockSize            : int;        // Block size in bytes (we re-use the blockData buffer)
    receivedFragment     : Bit_Array;  // Has fragment n been received?
    blockData            : [] u8;      // Block data for receive.
    blockMessage         : *Message;   // Block message (sent with fragment 0).
};

receive_block_data_init :: (using receiveBlockData: *ReceiveBlockData, maxBlockSize: int, maxFragmentsPerBlock: int) {
    init_bit_array(*receivedFragment, maxFragmentsPerBlock);
    blockData = NewArray(maxBlockSize, u8);
}

receive_block_data_free :: (using receiveBlockData: *ReceiveBlockData) {
    deinit(*receivedFragment);
    array_free(blockData);
}

receive_block_data_reset :: (using receiveBlockData: *ReceiveBlockData) {
    active = false;
    numFragments = 0;
    numReceivedFragments = 0;
    messageId = 0;
    messageType = 0;
    blockSize = 0;
    clear_all_bits(*receivedFragment);
    array_zero(blockData);
    if blockMessage != null {
        message_release(blockMessage);
        blockMessage = null;
    }
}

#scope_file

Math :: #import "Math";

// Shared by both channel_reset and channel_free. To save a bunch unnecessary zero'ing when we're about to free.
channel_release_messages :: (using channel: *ReliableOrderedChannel) {
    for 0..sequence_buffer_get_capacity(*messageSendQueue)-1 {
        entry := sequence_buffer_get_at_index(*messageSendQueue, it);
        if entry != null && entry.message != null {
            message_release(entry.message);
        }
    }

    for 0..sequence_buffer_get_capacity(*messageReceiveQueue)-1 {
        entry := sequence_buffer_get_at_index(*messageReceiveQueue, it);
        if entry != null && entry.message != null {
            message_release(entry.message);
        }
    }

    if receiveBlock != null {
        if receiveBlock.blockMessage != null {
            message_release(receiveBlock.blockMessage);
            receiveBlock.blockMessage = null;
        }
    }
}