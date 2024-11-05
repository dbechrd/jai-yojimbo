/*
Client implementation
*/
Client :: struct {
    #as using base: BaseClient;

    netClient    : *netcode_client_t;  // netcode client data.
    address      : IPAddress;          // Original address passed to ctor.
    boundAddress : IPAddress;          // Address after socket bind, eg. with valid port
    clientId     : u64;                // The globally unique client id (set on each call to connect)

    /*
    Override this callback to process packets sent from client to server over loopback.
    @param clientIndex The client index in range [0,maxClients-1]
    @param packetData The packet data (raw) to be sent to the server.
    @param packetSequence The sequence number of the packet.
    @see Client::ConnectLoopback
    */
    onClientSendLoopbackPacket: (client: *Client, clientIndex: int, packetData: [] u8, packetSequence: u64);
};

/**
The client constructor.
@param address The address the client should bind to.
@param config The client/server configuration.
@param time The current time in seconds. See ClientInterface::AdvanceTime
*/
client_init :: (using client: *Client, _address: IPAddress, _config: ClientServerConfig, _messageFactory: MessageFactory, _time: Apollo_Time) {
    client_init(*base, _config, _messageFactory, _time);
    address = _address;
    boundAddress = address;
    transmitPacketFunction = client_transmit_packet_function;
    processPacketFunction = client_process_packet_function;
}

client_free :: (using client: *Client) {
    // IMPORTANT: Please disconnect the client before destroying it
    assert(netClient == null);

    client_free(*base);
}

client_insecure_connect :: (client: *Client, privateKey: [KeyBytes] u8, clientId: u64, address: IPAddress) {
    client_insecure_connect(client, privateKey, clientId, .{ 1, *address });
}

client_insecure_connect :: (using client: *Client, privateKey: [KeyBytes] u8, _clientId: u64, serverAddresses: [] IPAddress) {
    assert(serverAddresses.count > 0);
    assert(serverAddresses.count <= NETCODE_MAX_SERVERS_PER_CONNECT);

    client_disconnect(client);
    client_create_internal(client);
    clientId = _clientId;
    client_create_net_client(client, address);
    if netClient == null {
        client_disconnect(client);
        return;
    }

    connectToken: [NETCODE_CONNECT_TOKEN_BYTES] u8;
    if !client_generate_insecure_connect_token(client, connectToken, privateKey, clientId, serverAddresses) {
        yojimbo_log(.ERROR, "error: failed to generate insecure connect token\n");
        clientState = .Error;
        return;
    }
    netcode_client_connect(netClient, connectToken);
    clientState = .Connecting;
}

client_generate_insecure_connect_token :: (using client: *Client, connectToken: [NETCODE_CONNECT_TOKEN_BYTES] u8, privateKey: [KeyBytes] u8, _clientId: u64, serverAddresses: [] IPAddress) -> bool {
    assert(serverAddresses.count <= NETCODE_MAX_SERVERS_PER_CONNECT);

    serverAddressStrings := NewArray(serverAddresses.count, string,, temp);
    for serverAddresses {
        serverAddressStrings[it_index] = address_to_string(it,, temp);
    }

    userData: [NETCODE_USER_DATA_BYTES] u8;
    err := netcode_generate_connect_token(
        serverAddressStrings,
        serverAddressStrings,
        config.timeout,
        config.timeout,
        _clientId,
        config.protocolId,
        privateKey,
        userData,
        connectToken
    );
    return err == NETCODE_OK;
}

client_connect :: (using client: *Client, _clientId: u64, connectToken: [] u8) {
    assert(connectToken != null);

    client_disconnect(client);
    client_create_internal(client);
    clientId = _clientId;
    client_create_net_client(client, address);
    netcode_client_connect(netClient, connectToken);
    if netcode_client_state(netClient) > NETCODE_CLIENT_STATE_DISCONNECTED {
        clientState = .Connecting;
    } else {
        client_disconnect(client);
    }
}

client_disconnect :: (using client: *Client) {
    client_disconnect(*base);
    client_destroy_net_client(client);
    client_destroy_internal(client);
    clientId = 0;
}

client_send_packets :: (using client: *Client) {
    if !client_is_connected(client) {
        return;
    }

    // This is a bit indirect, but it's asserting because reliable_endpoint_send_packet will call TransmitPacketFunction
    assert(netClient != null);

    packetBytes: int;
    packetSequence := reliable_endpoint_next_packet_sequence(endpoint);
    if connection_generate_packet(connection, packetSequence, packetBuffer, *packetBytes) {
        reliable_endpoint_send_packet(endpoint, .{ packetBytes, packetBuffer.data });
    }
}

client_receive_packets :: (using client: *Client) {
    if !client_is_connected(client) {
        return;
    }

    assert(netClient != null);
    while true {
        packetData, packetSequence := netcode_client_receive_packet(netClient);
        if packetData.count == 0 {
            break;
        }

        reliable_endpoint_receive_packet(endpoint, packetData);
        netcode_client_free_packet(netClient, packetData);
    }
}

client_advance_time :: (using client: *Client, _time: Apollo_Time) {
    client_advance_time(*base, _time);
    if netClient == null {
        return;
    }

    netcode_client_update(netClient, time);
    state := netcode_client_state(netClient);
    if state < NETCODE_CLIENT_STATE_DISCONNECTED {
        client_disconnect(client);
        clientState = .Error;
    } else if state == NETCODE_CLIENT_STATE_DISCONNECTED {
        client_disconnect(client);
        clientState = .Disconnected;
    } else if state == NETCODE_CLIENT_STATE_SENDING_CONNECTION_REQUEST || state == NETCODE_CLIENT_STATE_SENDING_CONNECTION_RESPONSE {
        clientState = .Connecting;
    } else {
        clientState = .Connected;
    }

    if networkSimulator != null && network_simulator_is_active(networkSimulator) {
        packetData := NewArray(config.maxSimulatorPackets, [] u8,, temp);
        numPackets := network_simulator_receive_packets(networkSimulator, packetData, .{});
        for 0..numPackets-1 {
            netcode_client_send_packet(netClient, packetData[it]);
        }
    }
}

// TODO(dlb): This is really stupid, because BaseClient always has clientIndex == -1, even when we're connected.
// We should clean this up somehow.. either by deleting clientIndex from the base, or by always syncing it when we
// connect/disconnect. Maybe we just delete the base class entirely, nobody is ever going to subclass this themselves.
client_get_client_index :: (using client: *Client) -> int {
    return ifx netClient != null then netcode_client_index(netClient) else -1;
}

client_connect_loopback :: (using client: *Client, _clientIndex: int, _clientId: u64, maxClients: int) {
    client_disconnect(client);
    client_create_internal(client);
    clientId = _clientId;
    client_create_net_client(client, address);
    netcode_client_connect_loopback(netClient, _clientIndex, maxClients);
    clientState = .Connected;
}

client_disconnect_loopback :: (using client: *Client) {
    netcode_client_disconnect_loopback(netClient);
    client_disconnect(client);
    client_destroy_net_client(client);
    client_destroy_internal(client);
    clientId = 0;
}

client_is_loopback :: (using client: *Client) -> bool {
    return netcode_client_loopback(netClient) != 0;
}

// TODO(dlb): I'm pretty sure this is the loopback_send function? It's named very confusingly. Figure out what it does and improve the name.
client_process_loopback_packet :: (using client: *Client, packetData: [] u8, packetSequence: u64) {
    netcode_client_process_loopback_packet(netClient, packetData, packetSequence);
}

#scope_file

client_create_net_client :: (using client: *Client, _address: IPAddress) {
    client_destroy_net_client(client);

    // TODO(dlb): Could we maybe.. *not* convert our addresses back to strings just to call into another library? :/
    addressString := address_to_string(_address,, temp);

    netcodeConfig: netcode_client_config_t;
    netcodeConfig.callback_context              = cast(*void) client;
    netcodeConfig.state_change_callback         = client_state_change_callback;
    netcodeConfig.send_loopback_packet_callback = client_send_loopback_packet_callback;
    netClient = netcode_client_create(addressString, *netcodeConfig, time);

    if netClient != null {
        boundAddress.port = netcode_client_get_port(netClient);
    }
}

client_destroy_net_client :: (using client: *Client) {
    if netClient != null {
        boundAddress = address;
        netcode_client_destroy(netClient);
        netClient = null;
    }
}

client_transmit_packet_function :: (ctx: *void, id: u64, packetSequence: u16, packetData: [] u8) {
    using client := cast(*Client) ctx;

    assert(netClient != null);

    if networkSimulator != null && network_simulator_is_active(networkSimulator) {
        network_simulator_send_packet(networkSimulator, 0, packetData);
    } else {
        netcode_client_send_packet(netClient, packetData);
    }
}

client_process_packet_function :: (ctx: *void, id: u64, packetSequence: u16, packetData: [] u8) -> bool {
    using client := cast(*Client) ctx;

    return ifx connection_process_packet(connection, packetSequence, packetData) then true else false;
}

client_state_change_callback :: (ctx: *void, previous: int, current: int) {
    // intentionally empty callback, we don't care about these events
}

client_send_loopback_packet_callback :: (ctx: *void, _clientIndex: int, packetData: [] u8, packetSequence: u64) {
    using client := cast(*Client) ctx;

    if onClientSendLoopbackPacket != null {
        onClientSendLoopbackPacket(client, _clientIndex, packetData, packetSequence);
    }
}
