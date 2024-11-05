/*
Common functionality across all server implementations.
*/
BaseServer :: struct {
    config           : ClientServerConfig;                 // Base client/server config.
    time             : Apollo_Time;                        // Current server time in seconds.
    maxClients       : int;                                // Maximum number of clients supported.
    running          : bool;                               // True if server is currently running, eg. after "Start" is called, before "Stop".
    messageFactory   : MessageFactory;                     // Message factory.
    clientConnection : [MaxClients] *Connection;           // Array of per-client connection classes. This is how messages are exchanged with clients.
    clientEndpoint   : [MaxClients] *reliable_endpoint_t;  // Array of per-client reliable endpoints.
    networkSimulator : *NetworkSimulator;                  // The network simulator used to simulate packet loss, latency, jitter etc. Optional.
    packetBuffer     : [] u8;                              // Buffer used when writing packets.

    // callbacks for packet read/write
    transmitPacketFunction : TransmitPacketFunction;
    processPacketFunction  : ProcessPacketFunction;
    disconnectClientFunction : (server: *BaseServer, clientIndex: int);
};

server_init :: (using server: *BaseServer, _config: ClientServerConfig, _messageFactory: MessageFactory, _time: Apollo_Time) {
    config = _config;
    messageFactory = _messageFactory;
    time = _time;
}

server_free :: (using server: *BaseServer) {
    // IMPORTANT: Please stop the server before destroying it!
    assert(!running);
}

// TODO(dlb): It seems weird to me that we pass `time` to server_init instead of to server_start. Perhaps
// we could consider refactoring that later. For now, it's parity with the C++ version.
server_start :: (using server: *BaseServer, _maxClients: int) {
    server_stop(server);
    running = true;
    maxClients = _maxClients;
    if config.networkSimulator {
        networkSimulator = New(NetworkSimulator);
        network_simulator_init(networkSimulator, config.maxSimulatorPackets, time);
    }
    for 0..maxClients-1 {
        clientConnection[it] = New(Connection);
        connection_init(clientConnection[it], messageFactory, config, time);

        reliable_config: reliable_config_t;
        reliable_config.name = "server endpoint";
        reliable_config.ctx = cast(*void) server;
        reliable_config.id = cast(u64) it;
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

        clientEndpoint[it] = reliable_endpoint_create(*reliable_config, time);
        reliable_endpoint_reset(clientEndpoint[it]);
    }
    packetBuffer = NewArray(config.maxPacketSize, u8);
}

server_stop :: (using server: *BaseServer) {
    if !running {
        return;
    }

    array_reset(*packetBuffer);
    if networkSimulator != null {
        network_simulator_free(networkSimulator);
        free(networkSimulator);
        networkSimulator = null;
    }
    for 0..maxClients-1 {
        reliable_endpoint_destroy(clientEndpoint[it]);
        clientEndpoint[it] = null;

        connection_free(clientConnection[it]);
        free(clientConnection[it]);
        clientConnection[it] = null;
    }
    maxClients = 0;
    running = false;
}

server_advance_time :: (using server: *BaseServer, _time: Apollo_Time) {
    time = _time;
    if !running {
        return;
    }

    for 0..maxClients-1 {
        connection_advance_time(clientConnection[it], time);
        if clientConnection[it].errorLevel != .None {
            yojimbo_log(.ERROR, "client % connection is in error state. disconnecting client\n", it);
            disconnectClientFunction(server, it);
            continue;
        }
        reliable_endpoint_update(clientEndpoint[it], time);
        acks := reliable_endpoint_get_acks(clientEndpoint[it]);
        connection_process_acks(clientConnection[it], acks);
        reliable_endpoint_clear_acks(clientEndpoint[it]);
    }
    if networkSimulator != null {
        network_simulator_advance_time(networkSimulator, time);
    }
}

/*
Create a message of the specified type for a specific client.
@param clientIndex The index of the client this message belongs to. Determines which client heap is used to allocate the message.
@param type The type of the message to create. The message types corresponds to the message factory set on the server.
*/
server_create_message :: (using server: *BaseServer, clientIndex: int, type: u16) -> *Message {
    assert(clientIndex >= 0);
    assert(clientIndex < maxClients);

    return message_factory_create_message(messageFactory, type);
}

// TODO(dlb)[cleanup]: This is kinda dumb, but maybe I'll keep it for compatibility reasons.
server_allocate_block :: (server: *BaseServer, clientIndex: int, bytes: int) -> [] u8 {
    return NewArray(bytes, u8);
}

// TODO(dlb)[cleanup]: This is kinda dumb, but maybe I'll keep it for compatibility reasons.
server_attack_block_to_message :: (server: *BaseServer, clientIndex: int, message: *Message, block: [] u8) {
    assert(message != null);
    assert(block.count > 0);

    message.blockData = block;
}

server_release_message :: (using server: *BaseServer, clientIndex: int, message: *Message) {
    message_release(message);
}

server_get_network_info :: (using server: *BaseServer, clientIndex: int, info: *NetworkInfo) {
    assert(false, "Call this on the subtype");
}

/*
Can we send a message to a particular client on a channel?
@param clientIndex The index of the client to send a message to.
@param channelIndex The channel index in range [0,numChannels-1].
@returns True if a message can be sent over the channel, false otherwise.
*/
server_can_send_message :: (using server: *BaseServer, clientIndex: int, channelIndex: int) -> bool {
    assert(clientIndex >= 0);
    assert(clientIndex < maxClients);
    assert(clientConnection[clientIndex] != null);

    return connection_can_send_message(clientConnection[clientIndex], channelIndex);
}

server_has_messages_to_send :: (using server: *BaseServer, clientIndex: int, channelIndex: int) -> bool {
    assert(clientIndex >= 0);
    assert(clientIndex < maxClients);
    assert(clientConnection[clientIndex] != null);

    return connection_has_messages_to_send(clientConnection[clientIndex], channelIndex);
}

/*
Send a message to a client over a channel.
@param clientIndex The index of the client to send a message to.
@param channelIndex The channel index in range [0,numChannels-1].
@param message The message to send.
*/
server_send_message :: (using server: *BaseServer, clientIndex: int, channelIndex: int, message: *Message) {
    assert(clientIndex >= 0);
    assert(clientIndex < maxClients);
    assert(clientConnection[clientIndex] != null);

    connection_send_message(clientConnection[clientIndex], channelIndex, message);
}

/*
Receive a message from a client over a channel.
@param clientIndex The index of the client to receive messages from.
@param channelIndex The channel index in range [0,numChannels-1].
@returns The message received, or NULL if no message is available. Make sure to release this message by calling Server::ReleaseMessage.
*/
server_receive_message :: (using server: *BaseServer, clientIndex: int, channelIndex: int) -> *Message {
    assert(clientIndex >= 0);
    assert(clientIndex < maxClients);
    assert(clientConnection[clientIndex] != null);

    return connection_receive_message(clientConnection[clientIndex], channelIndex);
}

// TODO(dlb): Everything below should be in #scope_file, but we can't do that until we merge BaseClient into Client.jai.
// #scope_file

server_reset_client :: (using server: *BaseServer, clientIndex: int) {
    assert(clientIndex >= 0);
    assert(clientIndex < maxClients);
    assert(clientConnection[clientIndex] != null);

    connection_reset(clientConnection[clientIndex]);
}
