ClientState :: enum {
    Error :: -1;
    Disconnected;
    Connecting;
    Connected;
};

/*
Functionality that is common across all client implementations.
*/
BaseClient :: struct {
    config           : ClientServerConfig;    // The client/server configuration.
    time             : Apollo_Time;           // The current client time. See ClientInterface::AdvanceTime
    clientIndex      : int;                   // The client slot index on the server [0,maxClients-1]. -1 if not connected.
    clientState      : ClientState;           // The current client state. See ClientInterface::GetClientState
    messageFactory   : MessageFactory;        // The client message factory. Created and destroyed on each connection attempt.
    connection       : *Connection;           // The client connection for exchanging messages with the server.
    endpoint         : *reliable_endpoint_t;  // reliable endpoint.
    networkSimulator : *NetworkSimulator;     // The network simulator used to simulate packet loss, latency, jitter etc. Optional.
    packetBuffer     : [] u8;                 // Buffer used to read and write packets.

    // callbacks for packet read/write
    transmitPacketFunction : TransmitPacketFunction;
    processPacketFunction  : ProcessPacketFunction;
}

/*
Base client constructor.
@param config The base client/server configuration.
@param time The current time in seconds. See ClientInterface::AdvanceTime
*/
client_init :: (using client: *BaseClient, _config: ClientServerConfig, _messageFactory: MessageFactory, _time: Apollo_Time) {
    config = _config;
    messageFactory = _messageFactory;
    time = _time;
    clientIndex = -1;
    packetBuffer = NewArray(config.maxPacketSize, u8);
}

/*
Clean up.
*/
client_free :: (using client: *BaseClient) {
    // IMPORTANT: Please disconnect the client before destroying it
    assert(clientState <= .Disconnected);
    array_free(packetBuffer);
}

/*
Disconnect from the server.
*/
client_disconnect :: (using client: *BaseClient) {
    clientState = .Disconnected;
    client_reset(client);
}

/*
Send packets to server.
*/
client_send_packets :: (using client: *BaseClient) {
    assert(false, "Call this on the subtype");
}

/*
Receive packets from the server.
*/
client_receive_packets :: (using client: *BaseClient) {
    assert(false, "Call this on the subtype");
}

/*
Advance client time.
Call this at the end of each frame to advance the client time forward.
IMPORTANT: Please use a double for your time value so it maintains sufficient accuracy as time increases.
*/
client_advance_time :: (using client: *BaseClient, _time: Apollo_Time) {
    time = _time;
    if endpoint != null {
        connection_advance_time(connection, time);
        if connection.errorLevel != .None {
            yojimbo_log(.VERBOSE_ONLY, "connection error. disconnecting client\n" );
            client_disconnect(client);
            return;
        }
        reliable_endpoint_update(endpoint, time);
        acks := reliable_endpoint_get_acks(endpoint);
        connection_process_acks(connection, acks);
        reliable_endpoint_clear_acks(endpoint);
    }
    if networkSimulator != null {
        network_simulator_advance_time(networkSimulator, time);
    }
}

/*
Is the client connecting to a server?
This is true while the client is negotiation connection with a server.
@returns true if the client is currently connecting to, but is not yet connected to a server.
*/
client_is_connecting :: (using client: *BaseClient) -> bool {
    return clientState == .Connecting;
}

/*
Is the client connected to a server?
This is true once a client successfully finishes connection negotiation, and connects to a server. It is false while connecting to a server.
@returns true if the client is connected to a server.
*/
client_is_connected :: (using client: *BaseClient) -> bool {
    return clientState == .Connected;
}

/*
Is the client in a disconnected state?
A disconnected state corresponds to the client being in the disconnected, or in an error state. Both are logically "disconnected".
@returns true if the client is disconnected.
*/
client_is_disconnected :: (using client: *BaseClient) -> bool {
    return clientState <= .Disconnected;
}

/*
Is the client in an error state?
When the client disconnects because of an error, it enters into this error state.
@returns true if the client is in an error state.
*/
client_connection_failed :: (using client: *BaseClient) -> bool {
    return clientState == .Error;
}

/*
Create a message of the specified type.
@param type The type of the message to create. The message types correspond to the message factory set on this client.
*/
client_create_message :: (using client: *BaseClient, type: u16) -> *Message {
    return message_factory_create_message(messageFactory, type);
}

// TODO(dlb)[cleanup]: This is kinda dumb, but maybe I'll keep it for compatibility reasons.
/*
Allocate a data block for a message.
@param bytes Length of the block of data in bytes.
*/
client_allocate_block :: (using client: *BaseClient, bytes: int) -> [] u8 {
    assert(bytes > 0);

    return NewArray(bytes, u8);
}

// TODO(dlb)[cleanup]: This is kinda dumb, but maybe I'll keep it for compatibility reasons.
/*
Attach data block to message.
@param message The message to attach the block to. This message must be derived from BlockMessage.
@param block Pointer to the block of data to attach. Must be created via Client::AllocateBlock.
@param bytes Length of the block of data in bytes.
*/
client_attack_block_to_message :: (using client: *BaseClient, message: *Message, block: [] u8) {
    assert(message != null);
    assert(block.count > 0);

    message.blockData = block;
}

/*
Can we send a message on a channel?
@param channelIndex The channel index in range [0,numChannels-1].
@returns True if a message can be sent over the channel, false otherwise.
*/
client_can_send_message :: (using client: *BaseClient, channelIndex: int) -> bool {
    assert(connection != null);
    return connection_can_send_message(connection, channelIndex);
}

/*
Checks if the connection has any messages queued for send.
@param channelIndex The channel index in range [0,numChannels-1].
@returns True if at least one message is queued for send.
*/
client_has_messages_to_send :: (using client: *BaseClient, channelIndex: int) -> bool {
    assert(connection != null);
    return connection_has_messages_to_send(connection, channelIndex);
}

/*
Send a message on a channel.
@param channelIndex The channel index in range [0,numChannels-1].
@param message The message to send.
*/
client_send_message :: (using client: *BaseClient, channelIndex: int, message: *Message) {
    assert(connection != null);
    connection_send_message(connection, channelIndex, message);
}

/*
Receive a message from a channel.
@param channelIndex The channel index in range [0,numChannels-1].
@returns The message received, or NULL if no message is available. Make sure to release this message by calling Client::ReleaseMessage.
*/
client_receive_message :: (using client: *BaseClient, channelIndex: int) -> *Message {
    assert(connection != null);
    return connection_receive_message(connection, channelIndex);
}

/*
Release a message.
Call this for messages received by Client::ReceiveMessage.
@param message The message to release.
*/
client_release_message :: (using client: *BaseClient, message: *Message) {
    message_release(message);
}

/*
Get client network info.
Call this to receive information about the client network connection to the server, eg. round trip time, packet loss %, # of packets sent and so on.
@param info The struct to be filled with network info [out].
*/
client_get_network_info :: (using client: *BaseClient, info: *NetworkInfo) {
    if connection != null {
        assert(endpoint != null);

        counters := reliable_endpoint_counters(endpoint);
        info.numPacketsSent = counters[RELIABLE_ENDPOINT_COUNTER_NUM_PACKETS_SENT];
        info.numPacketsReceived = counters[RELIABLE_ENDPOINT_COUNTER_NUM_PACKETS_RECEIVED];
        info.numPacketsAcked = counters[RELIABLE_ENDPOINT_COUNTER_NUM_PACKETS_ACKED];
        info.RTT = reliable_endpoint_rtt(endpoint);
        info.packetLoss = reliable_endpoint_packet_loss(endpoint);
        info.sentBandwidth, info.receivedBandwidth, info.ackedBandwidth = reliable_endpoint_bandwidth(endpoint);
    }
}

/*
Connect to server over loopback.
This allows you to have local clients connected to a server, for example for integrated server or singleplayer.
@param clientIndex The index of the client.
@param clientId The unique client id.
@param maxClients The maximum number of clients supported by the server.
*/
client_connect_loopback :: (using client: *BaseClient, clientIndex: int, clientId: u64, maxClients: int) {
    assert(false, "Call this on the subtype");
}

/*
Disconnect from server over loopback.
*/
client_disconnect_loopback :: (using client: *BaseClient) {
    assert(false, "Call this on the subtype");
}

/*
Is this a loopback client?
@returns true if the client is a loopback client, false otherwise.
*/
client_is_loopback :: (using client: *BaseClient) -> bool {
    assert(false, "Call this on the subtype");
}

/*
Process loopback packet.
Use this to pass packets from a server directly to the loopback client.
@param packetData The packet data to process.
@param packetBytes The number of bytes of packet data.
@param packetSequence The packet sequence number.
*/
client_process_loopback_packet :: (using client: *BaseClient, packetData: [] u8, packetSequence: u64) {
    assert(false, "Call this on the subtype");
};

// TODO(dlb): Everything below should be in #scope_file, but we can't do that until we merge BaseClient into Client.jai.
// #scope_file

client_create_internal :: (using client: *BaseClient) {
    assert(transmitPacketFunction != null);
    assert(processPacketFunction != null);

    // TODO(dlb): We could probably combine some of these allocs? The logic is a bit weird right now because the
    // original code frees and reallocs these when the connection is dropped. I'm not sure what state would have
    // to be reset or re-init()ed if you wanted to re-use the memory.
    connection = New(Connection);
    connection_init(connection, messageFactory, config, time);
    if config.networkSimulator {
        networkSimulator = New(NetworkSimulator);
        network_simulator_init(networkSimulator, config.maxSimulatorPackets, time);
    }

    reliable_config: reliable_config_t;
    reliable_config.name = "client endpoint";
    reliable_config.ctx = cast(*void) client;
    reliable_config.max_packet_size = config.maxPacketSize;
    reliable_config.fragment_above = config.fragmentPacketsAbove;
    reliable_config.max_fragments = client_server_config_get_max_packet_fragments(*config);
    reliable_config.fragment_size = config.packetFragmentSize;
    reliable_config.ack_buffer_size = config.ackedPacketsBufferSize;
    reliable_config.received_packets_buffer_size = config.receivedPacketsBufferSize;
    reliable_config.fragment_reassembly_buffer_size = config.packetReassemblyBufferSize;
    reliable_config.rtt_smoothing_factor = config.rttSmoothingFactor;
    reliable_config.transmit_packet_function = transmitPacketFunction;
    reliable_config.process_packet_function = processPacketFunction;

    endpoint = reliable_endpoint_create(*reliable_config, time);
    reliable_endpoint_reset(endpoint);
}

client_destroy_internal :: (using client: *BaseClient) {
    if endpoint != null {
        reliable_endpoint_destroy(endpoint);
        endpoint = null;
    }

    if networkSimulator != null {
        network_simulator_free(networkSimulator);
        free(networkSimulator);
        networkSimulator = null;
    }

    if connection != null {
        connection_free(connection);
        free(connection);
        connection = null;
    }
}

client_reset :: (using client: *BaseClient) {
    if connection {
        connection_reset(connection);
    }
}
