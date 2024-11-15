#load "yojimbo_test_shared.jai";

client_send_loopback_packet :: (server: *Server, clientIndex: int, packetData: [] u8, packetSequence: u64) {
    assert(server != null);

    server_process_loopback_packet(server, clientIndex, packetData, packetSequence);
}

server_send_loopback_packet :: (client: *Client, clientIndex: int, packetData: [] u8, packetSequence: u64) {
    assert(client != null);
    assert(clientIndex == 0);

    client_process_loopback_packet(client, packetData, packetSequence);
}

client_server_main :: () {
    time := seconds_to_apollo(100);

    config: ClientServerConfig;

    privateKey: [KeyBytes] u8;

    log("starting server on port %\n", ServerPort);

    server_address := address_init_v4("127.0.0.1", ServerPort);
    server := New(Server);
    server_init(server, privateKey, server_address, config, TestMessageFactory, time);

    server_start(server, MaxClients);

    if !server.running {
        log("server failed to start.\n");
        return;
    }

    log("started server\n");

    clientId := random_get();
    log("client id is %\n", clientId);

    client_address := address_init_v4("0.0.0.0");
    client := New(Client);
    client_init(client, client_address, config, TestMessageFactory, time);

    client_connect_loopback(client, 0, clientId, MaxClients);

    user_data: [256] u8;
    server_connect_loopback_client(server, 0, clientId, user_data);

    deltaTime := milliseconds_to_apollo(100);

    // dunno how to capture SIGINT in Jai, who cares
    while true {
        server_send_packets(server);
        client_send_packets(client);

        server_receive_packets(server);
        client_receive_packets(client);

        if client.clientState == .Disconnected {
            break;
        }

        time += deltaTime;
        client_advance_time(client, time);

        if client.clientState == .Error {
            break;
        }

        server_advance_time(server, time);

        reset_temporary_storage();
        sleep_milliseconds(cast(s32) to_milliseconds(deltaTime));
    }

    client_disconnect_loopback(client);
    server_stop(server);
}

main :: () {
    context.logger = logger;
    context.log_level = .VERY_VERBOSE;

    if !yojimbo_init() {
        log("error: failed to initialize Yojimbo!\n");
        return;
    }

    //yojimbo_log_level(YOJIMBO_LOG_LEVEL_INFO);
    random_seed(cast,no_check(u64) to_milliseconds(current_time_consensus()));

    client_server_main();

    yojimbo_shutdown();
}