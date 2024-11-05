/*
Server implementation.
*/
Server :: struct {
    #as using base: BaseServer;
    base.disconnectClientFunction = server_disconnect_client;

    netServer    : *netcode_server_t;  // netcode server data.
    address      : IPAddress;          // original address passed to ctor
    boundAddress : IPAddress;          // address after socket bind, eg. valid port
    privateKey   : [KeyBytes] u8;      // server-side private key for encryption

    /*
    Override this to get a callback when a client connects on the server.
    */
    onClientConnected: (server: *Server, clientIndex: int);

    /*
    Override this to get a callback when a client disconnects from the server.
    */
    onClientDisconnected: (server: *Server, clientIndex: int);

    /*
    Override this callback to process packets sent from server to client over loopback.
    @param clientIndex The client index in range [0,maxClients-1]
    @param packetData The packet data (raw) to be sent to the server.
    @param packetBytes The number of packet bytes in the server.
    @param packetSequence The sequence number of the packet.
    @see Server::ConnectLoopbackClient
    */
    onServerSendLoopbackPacket: (server: *Server, clientIndex: int, packetData: [] u8, packetSequence: u64);

};

server_init :: (using server: *Server, _privateKey: [KeyBytes] u8, _address: IPAddress, _config: ClientServerConfig, _messageFactory: MessageFactory, _time: Apollo_Time) {
    server_init(*base, _config, _messageFactory, _time);
    assert(KeyBytes == NETCODE_KEY_BYTES);
    array_copy(privateKey, _privateKey);
    address = _address;
    boundAddress = _address;
    transmitPacketFunction = server_transmit_packet_function;
    processPacketFunction = server_process_packet_function;
}

server_free :: (using server: *Server) {
    // IMPORTANT: Please stop the server before destroying it!
    assert(netServer == null);

    server_free(*base);
}

/*
Start the server and allocate client slots.
Each client that connects to this server occupies one of the client slots allocated by this function.
@param maxClients The number of client slots to allocate. Must be in range [1,MaxClients]
@see Server::Stop
*/
server_start :: (using server: *Server, _maxClients: int) {
    if running {
        server_stop(server);
    }

    server_start(*base, _maxClients);

    addressString := address_to_string(address,, temp);

    netcodeConfig: netcode_server_config_t;
    netcodeConfig.protocol_id = config.protocolId;
    array_copy(netcodeConfig.private_key, privateKey);
    netcodeConfig.callback_context = cast(*void) server;
    netcodeConfig.connect_disconnect_callback = server_connect_disconnect_callback;
    netcodeConfig.send_loopback_packet_callback = server_send_loopback_packet_callback;

    netServer = netcode_server_create(addressString, *netcodeConfig, time);

    if netServer == null {
        server_stop(server);
        return;
    }

    netcode_server_start(netServer, maxClients);
    boundAddress.port = netcode_server_get_port(netServer);
}

/*
Stop the server and free client slots.
Any clients that are connected at the time you call stop will be disconnected.
When the server is stopped, clients cannot connect to the server.
@see Server::Start.
*/
server_stop :: (using server: *Server) {
    if netServer != null {
        boundAddress = address;
        netcode_server_stop(netServer);
        netcode_server_destroy(netServer);
        netServer = null;
    }
    server_stop(*base);
}

/*
Disconnect the client at the specified client index.
@param clientIndex The index of the client to disconnect in range [0,maxClients-1], where maxClients is the number of client slots allocated in Server::Start.
@see Server::IsClientConnected
*/
server_disconnect_client :: (_server: *BaseServer, clientIndex: int) {
    using server := cast(*Server) _server;

    assert(netServer != null);

    netcode_server_disconnect_client(netServer, clientIndex);
    server_reset_client(server, clientIndex);
}

/*
Disconnect all clients from the server.
Client slots remain allocated as per the last call to Server::Start, they are simply made available for new clients to connect.
*/
server_disconnect_all_clients :: (using server: *Server) {
    assert(netServer != null);

    netcode_server_disconnect_all_clients(netServer);
    for 0..maxClients-1 {
        server_reset_client(server, it);
    }
}

/*
Send packets to connected clients.
This function drives the sending of packets that transmit messages to clients.
*/
server_send_packets :: (using server: *Server) {
    if netServer != null {
        for 0..maxClients-1 {
            if server_is_client_connected(server, it) {
                packetBytes: int;
                packetSequence := reliable_endpoint_next_packet_sequence(clientEndpoint[it]);
                if connection_generate_packet(clientConnection[it], packetSequence, packetBuffer, *packetBytes) {
                    reliable_endpoint_send_packet(clientEndpoint[it], .{ packetBytes, packetBuffer.data });
                }
            }
        }
    }
}

/*
Receive packets from connected clients.
This function drives the procesing of messages included in packets received from connected clients.
*/
server_receive_packets :: (using server: *Server) {
    if netServer != null {
        for 0..maxClients-1 {
            while true {
                packetData, packetSequence := netcode_server_receive_packet(netServer, it);
                if packetData.count == 0 {
                    break;
                }

                reliable_endpoint_receive_packet(clientEndpoint[it], packetData);
                netcode_server_free_packet(netServer, packetData);
            }
        }
    }
}

/*
Advance server time.
Call this at the end of each frame to advance the server time forward.
*/
server_advance_time :: (using server: *Server, _time: Apollo_Time) {
    if netServer != null {
        netcode_server_update(netServer, _time);
    }
    server_advance_time(*base, _time);
    if networkSimulator != null && network_simulator_is_active(networkSimulator) {
        packetData := NewArray(config.maxSimulatorPackets, [] u8,, temp);
        to := NewArray(config.maxSimulatorPackets, int,, temp);
        numPackets := network_simulator_receive_packets(networkSimulator, packetData, to);
        for 0..numPackets-1 {
            netcode_server_send_packet(netServer, to[it], packetData[it]);
        }
    }
}

/*
Is a client connected to a client slot?
@param clientIndex the index of the client slot in [0,maxClients-1], where maxClients corresponds to the value passed into the last call to Server::Start.
@returns True if the client is connected.
*/
server_is_client_connected :: (using server: *Server, clientIndex: int) -> bool {
    return netcode_server_client_connected(netServer, clientIndex);
}

/*
Get the unique id of the client
@param clientIndex the index of the client slot in [0,maxClients-1], where maxClients corresponds to the value passed into the last call to Server::Start.
@returns The unique id of the client.
*/
server_get_client_id :: (using server: *Server, clientIndex: int) -> u64 {
    return netcode_server_client_id(netServer, clientIndex);
}

/*
Get the user data of the client.
@param clientIndex the index of the client slot in [0,maxClients-1], where maxClients corresponds to the value passed into the last call to Server::Start.
@returns The user data of the client.
*/
server_get_client_user_data :: (using server: *Server, clientIndex: int) -> [] u8 {
    return netcode_server_client_user_data(netServer, clientIndex);
}

/*
Get the address of the client
@param clientIndex the index of the client slot in [0,maxClients-1], where maxClients corresponds to the value passed into the last call to Server::Start.
@returns The address of the client.
*/
server_get_client_address :: (using server: *Server, clientIndex: int) -> *netcode_address_t {
    return netcode_server_client_address(netServer, clientIndex);
}

/*
Get the number of clients that are currently connected to the server.
@returns the number of connected clients.
*/
server_get_num_connected_clients :: (using server: *Server) -> int {
    return netcode_server_num_connected_clients(netServer);
}

/*
Connect a loopback client.
This allows you to have local clients connected to a server, for example for integrated server or singleplayer.
@param clientIndex The index of the client.
@param clientId The unique client id.
@param userData User data for this client. Optional. Pass NULL if not needed.
*/
server_connect_loopback_client :: (using server: *Server, clientIndex: int, clientId: u64, userData: [256] u8) {
    netcode_server_connect_loopback_client(netServer, clientIndex, clientId, userData);
}

/*
Disconnect a loopback client.
Loopback clients are not disconnected by regular Disconnect or DisconnectAllClient calls. You need to call this function instead.
@param clientIndex The index of the client to disconnect. Must already be a connected loopback client.
*/
server_disconnect_loopback_client :: (using server: *Server, clientIndex: int) {
    netcode_server_disconnect_loopback_client(netServer, clientIndex);
}

/*
Is this client a loopback client?
@param clientIndex The client index.
@returns true if the client is a connected loopback client, false otherwise.
*/
server_is_loopback_client :: (using server: *Server, clientIndex: int) -> bool {
    return netcode_server_client_loopback(netServer, clientIndex) != 0;
}

/*
Process loopback packet.
Use this to pass packets from a client directly to the loopback client slot on the server.
@param clientIndex The client index. Must be an already connected loopback client.
@param packetData The packet data to process.
@param packetBytes The number of bytes of packet data.
@param packetSequence The packet sequence number.
*/
server_process_loopback_packet :: (using server: *Server, clientIndex: int, packetData: [] u8, packetSequence: u64) {
    netcode_server_process_loopback_packet(netServer, clientIndex, packetData, packetSequence);
}

/*
Get client network info.
Call this to receive information about the client network connection, eg. round trip time, packet loss %, # of packets sent and so on.
@param clientIndex The index of the client.
@param info The struct to be filled with network info [out].
*/
server_get_network_info :: (using server: *Server, clientIndex: int, info: *NetworkInfo) {
    assert(running);
    assert(clientIndex >= 0);
    assert(clientIndex < maxClients);

    if server_is_client_connected(server, clientIndex) {
        assert(clientEndpoint[clientIndex] != null);

        counters := reliable_endpoint_counters(clientEndpoint[clientIndex]);
        info.numPacketsSent = counters[RELIABLE_ENDPOINT_COUNTER_NUM_PACKETS_SENT];
        info.numPacketsReceived = counters[RELIABLE_ENDPOINT_COUNTER_NUM_PACKETS_RECEIVED];
        info.numPacketsAcked = counters[RELIABLE_ENDPOINT_COUNTER_NUM_PACKETS_ACKED];
        info.RTT = reliable_endpoint_rtt(clientEndpoint[clientIndex]);
        info.packetLoss = reliable_endpoint_packet_loss(clientEndpoint[clientIndex]);
        info.sentBandwidth, info.receivedBandwidth, info.ackedBandwidth = reliable_endpoint_bandwidth(clientEndpoint[clientIndex]);
    }
}

#scope_file

server_transmit_packet_function :: (ctx: *void, _clientIndex: u64, packetSequence: u16, packetData: [] u8) {
    using server := cast(*Server) ctx;
    clientIndex := cast(int) _clientIndex;

    if networkSimulator != null && network_simulator_is_active(networkSimulator) {
        network_simulator_send_packet(networkSimulator, clientIndex, packetData);
    } else {
        netcode_server_send_packet(netServer, clientIndex, packetData);
    }
}

server_process_packet_function :: (ctx: *void, _clientIndex: u64, packetSequence: u16, packetData: [] u8) -> bool {
    using server := cast(*Server) ctx;
    clientIndex := cast(int) _clientIndex;

    return connection_process_packet(clientConnection[clientIndex], packetSequence, packetData);
}

server_connect_disconnect_callback :: (ctx: *void, clientIndex: int, connected: bool) {
    using server := cast(*Server) ctx;

    if connected {
        if onClientConnected != null {
            onClientConnected(server, clientIndex);
        }
    } else {
        if onClientDisconnected != null {
            onClientDisconnected(server, clientIndex);
        }
        reliable_endpoint_reset(clientEndpoint[clientIndex]);
        connection_reset(clientConnection[clientIndex]);
        if networkSimulator != null && network_simulator_is_active(networkSimulator) {
            network_simulator_discard_client_packets(networkSimulator, clientIndex);
        }
    }
}

server_send_loopback_packet_callback :: (ctx: *void, clientIndex: int, packetData: [] u8, packetSequence: u64) {
    using server := cast(*Server) ctx;

    if onServerSendLoopbackPacket != null {
        onServerSendLoopbackPacket(server, clientIndex, packetData, packetSequence);
    }
}
