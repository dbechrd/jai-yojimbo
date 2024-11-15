#load "yojimbo_test_shared.jai";

server_main :: () {
    log("started server on port % (insecure)\n", ServerPort);

    time := seconds_to_apollo(100);

    config: ClientServerConfig;

    privateKey: [KeyBytes] u8;

    server_address := address_init_v4("127.0.0.1", ServerPort);
    server := New(Server);
    server_init(server, privateKey, server_address, config, TestMessageFactory, time);

    server_start(server, MaxClients);

    log("server address is %\n", address_to_string(server_address,, temp));

    deltaTime := milliseconds_to_apollo(500);

    // dunno how to capture SIGINT in Jai, who cares
    while true {
        server_send_packets(server);
        server_receive_packets(server);

        time += deltaTime;
        server_advance_time(server, time);

        log("clients: %\n", server_get_num_connected_clients(server));

        if !server.running {
            break;
        }

        reset_temporary_storage();
        sleep_milliseconds(cast(s32) to_milliseconds(deltaTime));
    }

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

    server_main();

    yojimbo_shutdown();
}