// Determines the reliability and ordering guarantees for a channel.
ChannelType :: enum {
    ReliableOrdered;      // Messages are received reliably and in the same order they were sent.
    UnreliableUnordered;  // Messages are sent unreliably. Messages may arrive out of order, or not at all.
}

/*
Configuration properties for a message channel.

Channels let you specify different reliability and ordering guarantees for messages sent across a connection.

They may be configured as one of two types: reliable-ordered or unreliable-unordered.

Reliable ordered channels guarantee that messages (see Message) are received reliably and in the same order they were sent.
This channel type is designed for control messages and RPCs sent between the client and server.

Unreliable unordered channels are like UDP. There is no guarantee that messages will arrive, and messages may arrive out of order.
This channel type is designed for data that is time critical and should not be resent if dropped, like snapshots of world state sent rapidly
from server to client, or cosmetic events such as effects and sounds.

Both channel types support blocks of data attached to messages (see BlockMessage), but their treatment of blocks is quite different.

Reliable ordered channels are designed for blocks that must be received reliably and in-order with the rest of the messages sent over the channel.
Examples of these sort of blocks include the initial state of a level, or server configuration data sent down to a client on connect. These blocks
are sent by splitting them into fragments and resending each fragment until the other side has received the entire block. This allows for sending
blocks of data larger that maximum packet size quickly and reliably even under packet loss.

Unreliable-unordered channels send blocks as-is without splitting them up into fragments. The idea is that transport level packet fragmentation
should be used on top of the generated packet to split it up into into smaller packets that can be sent across typical Internet MTU (<1500 bytes).
Because of this, you need to make sure that the maximum block size for an unreliable-unordered channel fits within the maximum packet size.

Channels are typically configured as part of a ConnectionConfig, which is included inside the ClientServerConfig that is passed into the Client and Server constructors.
*/
ChannelConfig :: struct {
    type                    : ChannelType = .ReliableOrdered;  // Channel type: reliable-ordered or unreliable-unordered.
    disableBlocks           : bool        = false;             // Disables blocks being sent across this channel.
    sentPacketBufferSize    : int         = 1024;              // Number of packet entries in the sent packet sequence buffer. Please consider your packet send rate and make sure you have at least a few seconds worth of entries in this buffer.
    messageSendQueueSize    : int         = 1024;              // Number of messages in the send queue for this channel.
    messageReceiveQueueSize : int         = 1024;              // Number of messages in the receive queue for this channel.
    maxMessagesPerPacket    : int         = 256;               // Maximum number of messages to include in each packet. Will write up to this many messages, provided the messages fit into the channel packet budget and the number of bytes remaining in the packet.
    packetBudget            : int         = -1;                // Maximum amount of message data to write to the packet for this channel (bytes). Specifying -1 means the channel can use up to the rest of the bytes remaining in the packet.
    maxBlockSize            : int         = 256 * 1024;        // The size of the largest block that can be sent across this channel (bytes).
    blockFragmentSize       : int         = 1024;              // Blocks are split up into fragments of this size (bytes). Reliable-ordered channel only.
    messageResendTime       : Apollo_Time = #run milliseconds_to_apollo(100);  // Minimum delay between message resends (seconds). Avoids sending the same message too frequently. Reliable-ordered channel only.
    blockFragmentResendTime : Apollo_Time = #run milliseconds_to_apollo(250);  // Minimum delay between block fragment resends (seconds). Avoids sending the same fragment too frequently. Reliable-ordered channel only.
}

channel_config_get_max_fragments_per_block :: inline (using channelConfig: ChannelConfig) -> int {
    return maxBlockSize / blockFragmentSize;
}

/*
Configures connection properties and the set of channels for sending and receiving messages.
Specifies the maximum packet size to generate, and the number of message channels, and the per-channel configuration data. See ChannelConfig for details.
Typically configured as part of a ClientServerConfig which is passed into Client and Server constructors.
*/
ConnectionConfig :: struct {
    numChannels   : int                         = 1;         // Number of message channels in [1,MaxChannels]. Each message channel must have a corresponding configuration below.
    maxPacketSize : int                         = 8 * 1024;  // The maximum size of packets generated to transmit messages between client and server (bytes).
    channel       : [MaxChannels] ChannelConfig;             // Per-channel configuration. See ChannelConfig for details.
}

/*
Configuration shared between client and server.
Passed to Client and Server constructors to configure their behavior.
Please make sure that the message configuration is identical between client and server.
*/
ClientServerConfig :: struct {
    #as using base: ConnectionConfig;

    protocolId                 : u64         = 0;                           // Clients can only connect to servers with the same protocol id. Use this for versioning.
    timeout                    : Apollo_Time = #run seconds_to_apollo(10);  // Timeout value in seconds. Set to negative value to disable timeouts (for debugging only).
    clientMemory               : int         = 10 * 1024 * 1024;            // Memory allocated inside Client for packets, messages and stream allocations (bytes)
    serverGlobalMemory         : int         = 10 * 1024 * 1024;            // Memory allocated inside Server for global connection request and challenge response packets (bytes)
    serverPerClientMemory      : int         = 10 * 1024 * 1024;            // Memory allocated inside Server for packets, messages and stream allocations per-client (bytes)
    networkSimulator           : bool        = true;                        // If true then a network simulator is created for simulating latency, jitter, packet loss and duplicates.
    maxSimulatorPackets        : int         = 4 * 1024;                    // Maximum number of packets that can be stored in the network simulator. Additional packets are dropped.
    fragmentPacketsAbove       : int         = 1024;                        // Packets above this size (bytes) are split apart into fragments and reassembled on the other side.
    packetFragmentSize         : int         = 1024;                        // Size of each packet fragment (bytes).
    packetReassemblyBufferSize : int         = 64;                          // Number of packet entries in the fragmentation reassembly buffer.
    ackedPacketsBufferSize     : int         = 256;                         // Number of packet entries in the acked packet buffer. Consider your packet send rate and aim to have at least a few seconds worth of entries.
    receivedPacketsBufferSize  : int         = 256;                         // Number of packet entries in the received packet sequence buffer. Consider your packet send rate and aim to have at least a few seconds worth of entries.
    rttSmoothingFactor         : float       = 0.0025;                      // Round-Trip Time (RTT) smoothing factor over time.
}

// Maximum number of fragments a packet can be split up into.
client_server_config_get_max_packet_fragments :: inline (using clientServerConfig: *ClientServerConfig) -> int {
    return cast(int) Math.ceil(cast(float) maxPacketSize / packetFragmentSize);
}
