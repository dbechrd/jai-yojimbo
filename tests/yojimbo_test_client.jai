#load "yojimbo_test_shared.jai";

client_main :: () {
    log("connecting client (insecure)\n");

    time := seconds_to_apollo(100);

    clientId := random_get();
    log("client id is %\n", clientId);

    config: ClientServerConfig;

    clientAddress := address_init_v4("0.0.0.0");
    client := New(Client);
    client_init(client, clientAddress, config, TestMessageFactory, time);

    serverAddress := address_init_v4("127.0.0.1", ServerPort);

    privateKey: [KeyBytes] u8;

    client_insecure_connect(client, privateKey, clientId, serverAddress);

    log("client address is %\n", address_to_string(client.boundAddress,, temp));

    deltaTime := milliseconds_to_apollo(500);

    // dunno how to capture SIGINT in Jai, who cares
    while true {
        client_send_packets(client);
        client_receive_packets(client);

        log("client: %\n", client.clientState);

        if client.clientState == .Disconnected {
            break;
        }

        time += deltaTime;
        client_advance_time(client, time);

        if client.clientState == .Error {
            break;
        }

        reset_temporary_storage();
        sleep_milliseconds(cast(s32) to_milliseconds(deltaTime));
    }

    client_disconnect(client);
}

main :: () {
    context.logger = logger;
    context.log_level = .VERY_VERBOSE;

    if !yojimbo_init() {
        log("error: failed to initialize Yojimbo!\n");
        return;
    }

    //yojimbo_log_level( YOJIMBO_LOG_LEVEL_INFO );
    random_seed(cast,no_check(u64) to_milliseconds(current_time_consensus()));

    client_main();

    yojimbo_shutdown();
}