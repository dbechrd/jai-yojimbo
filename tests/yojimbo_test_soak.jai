#load "yojimbo_test_shared.jai";

MaxPacketSize   :: 16 * 1024;
MaxSnapshotSize :: 8 * 1024;
MaxBlockSize    :: 10 * 1024;

// these are not the enum, these are just this application's channel names. not confusing at all, Glenn. :D
UNRELIABLE_UNORDERED_CHANNEL :: 0;
RELIABLE_ORDERED_CHANNEL     :: 1;

soak_main :: () {
    config: ClientServerConfig;
    config.maxPacketSize = MaxPacketSize;
    config.clientMemory = 100 * 1024 * 1024;
    config.serverGlobalMemory = 10 * 1024 * 1024;
    config.serverPerClientMemory = 100 * 1024 * 1024;
    config.numChannels = 2;
    config.channel[UNRELIABLE_UNORDERED_CHANNEL].type = .UnreliableUnordered;
    config.channel[UNRELIABLE_UNORDERED_CHANNEL].maxBlockSize = MaxSnapshotSize;
    config.channel[RELIABLE_ORDERED_CHANNEL].type = .ReliableOrdered;
    config.channel[RELIABLE_ORDERED_CHANNEL].maxBlockSize = MaxBlockSize;
    config.channel[RELIABLE_ORDERED_CHANNEL].blockFragmentSize = 1024;

    privateKey: [KeyBytes] u8;

    time: Apollo_Time;

    serverAddress := address_init_v4("127.0.0.1", ServerPort);
    server: Server;
    server_init(*server, privateKey, serverAddress, config, TestMessageFactory, time);

    server_start(*server, 1);

    network_simulator_set_latency(server.networkSimulator, 1000);
    network_simulator_set_jitter(server.networkSimulator, 100);
    network_simulator_set_packet_loss(server.networkSimulator, 25.0);
    network_simulator_set_duplicates(server.networkSimulator, 25.0);

    clientAddress := address_init_v4("0.0.0.0");
    client: Client;
    client_init(*client, clientAddress, config, TestMessageFactory, time);

    clientId := random_get();
    client_insecure_connect(*client, privateKey, clientId, serverAddress);

    network_simulator_set_latency(client.networkSimulator, 1000);
    network_simulator_set_jitter(client.networkSimulator, 100);
    network_simulator_set_packet_loss(client.networkSimulator, 25.0);
    network_simulator_set_duplicates(client.networkSimulator, 25.0);

    numMessagesSentToServer: int;
    numMessagesSentToClient: int;
    numMessagesReceivedFromClient: int;
    numMessagesReceivedFromServer: int;

    clientConnected := false;
    serverConnected := false;

    timeForNextClientMessage: Apollo_Time;
    timeForNextServerMessage: Apollo_Time;

    deltaTime := milliseconds_to_apollo(100);

    client_message_send_iter := 0;

    iters := 0;
    while iters < 500 {
        iters += 1;

        client_send_packets(*client);
        server_send_packets(*server);

        client_receive_packets(*client);
        server_receive_packets(*server);

        if client_connection_failed(*client) {
            log("error: client connect failed!\n");
            break;
        }

        time += deltaTime;

        if client_is_connected(*client) {
            // Rarely, drop the client and reconnect
            if yojimbo_random_int(1, 10_000) == 1 {
                log("client reconnect\n");
                client_disconnect(*client);
                clientId = random_get();
                client_insecure_connect(*client, privateKey, clientId, serverAddress);
                clientConnected = false;
                numMessagesSentToServer = 0;
                numMessagesSentToClient = 0;
                numMessagesReceivedFromClient = 0;
                numMessagesReceivedFromServer = 0;
            }
        }

        if client_is_connected(*client) {
            clientConnected = true;

            // Occasionally, stall the packet stream for up to 1 second
            if timeForNextClientMessage < time && yojimbo_random_int(1, 1000) == 1 {
                stallMs := yojimbo_random_int(1, 1000);
                timeForNextClientMessage = time + milliseconds_to_apollo(stallMs);
            }

            if timeForNextClientMessage <= time {
				messagesToSend := yojimbo_random_int(0, 64);

				for 0..messagesToSend-1 {
					if !client_can_send_message(*client, RELIABLE_ORDERED_CHANNEL) {
						break;
                    }

					if yojimbo_random_int(1, 100) != 1 {
						message := cast(*TestMessage) client_create_message(*client, xx TEST_MESSAGE);
						if message != null {
							message.sequence = cast,no_check(u16) numMessagesSentToServer;
                            client_send_message(*client, RELIABLE_ORDERED_CHANNEL, message);
							numMessagesSentToServer += 1;
						}
					} else {
                        numBlocks := yojimbo_random_int(1, 3);

                        for k: 0..numBlocks-1 {
                            if !client_can_send_message(*client, RELIABLE_ORDERED_CHANNEL) {
                                break;
                            }

    						blockMessage := cast(*TestBlockMessage) client_create_message(*client, xx TEST_BLOCK_MESSAGE);
    						if blockMessage != null {
    							blockMessage.sequence = cast,no_check(u16) numMessagesSentToServer;
    							blockSize := 1 + (numMessagesSentToServer * 33) % MaxBlockSize;
    							blockData := client_allocate_block(*client, blockSize);
    							if blockData.count > 0 {
                                    for * blockData {
                                        it.* = cast,no_check(u8) (numMessagesSentToServer + it_index);
                                    }
                                    client_attack_block_to_message(*client, blockMessage, blockData);
                                    client_send_message(*client, RELIABLE_ORDERED_CHANNEL, blockMessage);
    								numMessagesSentToServer += 1;
    							} else {
                                    client_release_message(*client, blockMessage);
    							}
    						}
    					}
    				}
                }
			}

            clientIndex := client_get_client_index(*client);

            if timeForNextServerMessage < time && yojimbo_random_int(1, 1000) == 1 {
                delayMs := yojimbo_random_int(1, 1000);
                timeForNextServerMessage = time + milliseconds_to_apollo(delayMs);
            }

            if server_is_client_connected(*server, clientIndex) {
                serverConnected = true;

                if timeForNextServerMessage <= time {
                    messagesToSend := yojimbo_random_int(0, 64);

                    for 0..messagesToSend-1 {
                        if !server_can_send_message(*server, clientIndex, RELIABLE_ORDERED_CHANNEL) {
                            break;
                        }

                        if yojimbo_random_int(1, 100) != 1 {
                            message := cast(*TestMessage) server_create_message(*server, clientIndex, xx TEST_MESSAGE);
                            if message != null {
                                message.sequence = cast,no_check(u16) numMessagesSentToClient;
                                server_send_message(*server, clientIndex, RELIABLE_ORDERED_CHANNEL, message);
                                numMessagesSentToClient += 1;
                            }
                        } else {
                            // 1 in 100 messages will have block data attached
                            numBlocks := yojimbo_random_int(1, 3);

                            for 0..numBlocks-1 {
                                if server_can_send_message(*server, clientIndex, RELIABLE_ORDERED_CHANNEL) {
                                    break;
                                }

                                blockMessage := cast(*TestBlockMessage) server_create_message(*server, clientIndex, xx TEST_BLOCK_MESSAGE);
                                if blockMessage != null {
                                    blockMessage.sequence = cast,no_check(u16) numMessagesSentToClient;
                                    blockSize := 1 + (numMessagesSentToClient * 33) % MaxBlockSize;
                                    blockData := server_allocate_block(*server, clientIndex, blockSize);
                                    if blockData.count > 0 {
                                        for * blockData {
                                            it.* = cast,no_check(u8) (numMessagesSentToClient + it_index);
                                        }
                                        server_attack_block_to_message(*server, clientIndex, blockMessage, blockData);
                                        server_send_message(*server, clientIndex, RELIABLE_ORDERED_CHANNEL, blockMessage);
                                        numMessagesSentToClient += 1;
                                    } else {
                                        server_release_message(*server, clientIndex, blockMessage);
                                    }
                                }
                            }
                        }
                    }
                }

                while true {
                    message := server_receive_message(*server, clientIndex, RELIABLE_ORDERED_CHANNEL);
                    if message == null {
                        break;
                    }

                    assert(message.id == cast,no_check(u16) numMessagesReceivedFromClient);

                    if cast(TestMessageType) message.type == {
                        case TEST_MESSAGE;
                            testMessage := cast(*TestMessage) message;
                            assert(testMessage.sequence == cast,no_check(u16) numMessagesReceivedFromClient);
                            log("server received message %\n", testMessage.sequence);
                            server_release_message(*server, clientIndex, message);
                            numMessagesReceivedFromClient += 1;
                        case TEST_BLOCK_MESSAGE;
                            blockMessage := cast(*TestBlockMessage) message;
                            assert(blockMessage.sequence == cast,no_check(u16) numMessagesReceivedFromClient);
                            blockSize := blockMessage.blockData.count;
                            expectedBlockSize := 1 + (numMessagesReceivedFromClient * 33) % MaxBlockSize;
                            if blockSize != expectedBlockSize {
                                log("error: block size mismatch. expected %, got %\n", expectedBlockSize, blockSize);
                                exit(1);
                            }
                            blockData := blockMessage.blockData;
                            assert(blockData.count > 0);
                            for blockData {
                                if it != cast,no_check(u8) (numMessagesReceivedFromClient + it_index) {
                                    log("error: block data mismatch. expected %, but blockData[%] = %\n", cast,no_check(u8) (numMessagesReceivedFromClient + it_index), it_index, it);
                                    exit(1);
                                }
                            }
                            log("server received block message %\n", numMessagesReceivedFromClient);
                            server_release_message(*server, clientIndex, message);
                            numMessagesReceivedFromClient += 1;
                        case;
                            assert(false, "Server received bad message type %", message.type);
                    }
                }
            }

            while true {
                message := client_receive_message(*client, RELIABLE_ORDERED_CHANNEL);
                if message == null {
                    break;
                }

                assert(message.id == cast,no_check(u16) numMessagesReceivedFromServer);

                if cast(TestMessageType) message.type == {
                    case TEST_MESSAGE;
                        testMessage := cast(*TestMessage) message;
                        assert(testMessage.sequence == cast,no_check(u16) numMessagesReceivedFromServer);
                        // log("client received message %\n", testMessage.sequence);
                        client_release_message(*client, message);
                        numMessagesReceivedFromServer += 1;
                    case TEST_BLOCK_MESSAGE;
                        blockMessage := cast(*TestBlockMessage) message;
                        assert(blockMessage.sequence == cast,no_check(u16) numMessagesReceivedFromServer);
                        blockSize := blockMessage.blockData.count;
                        expectedBlockSize := 1 + (numMessagesReceivedFromServer * 33) % MaxBlockSize;
                        if blockSize != expectedBlockSize {
                            log("error: block size mismatch. expected %, got %\n", expectedBlockSize, blockSize);
                            exit(1);
                        }
                        blockData := blockMessage.blockData;
                        assert(blockData.count > 0);
                        for blockData {
                            if it != cast,no_check(u8) (numMessagesReceivedFromServer + it_index) {
                                log("error: block data mismatch. expected %, but blockData[%] = %\n", cast,no_check(u8) (numMessagesReceivedFromServer + it_index), it_index, it);
                                exit(1);
                            }
                        }
                        // log("client received block message %\n", numMessagesReceivedFromServer);
                        client_release_message(*client, message);
                        numMessagesReceivedFromServer += 1;
                    case;
                        assert(false, "Client received bad message type %", message.type);
                }
            }

            if clientConnected && !client_is_connected(*client) {
                break;
            }
            if serverConnected && server_get_num_connected_clients(*server) == 0 {
                break;
            }
        }

        client_advance_time(*client, time);
        server_advance_time(*server, time);

        reset_temporary_storage();
        memory_visualizer_per_frame_update();
        // sleep_milliseconds(1);  // prevent computer from exploding
    }

    client_disconnect(*client);
    server_stop(*server);

    client_free(*client);
    server_free(*server);
}

main :: () {
    logger :: (message: string, data: *void, info: Log_Info) {
        if !message then return;

        if info.common_flags & .VERY_VERBOSE_ONLY && context.log_level < .VERY_VERBOSE {
            return;
        }
        if info.common_flags & .VERBOSE_ONLY && context.log_level < .VERBOSE {
            return;
        }

        to_standard_error := false; //(info.common_flags & .ERROR) != 0;

        if message[message.count-1] != #char "\n" {
            write_strings(message, "\n", to_standard_error = to_standard_error);
        } else {
            write_string(message, to_standard_error = to_standard_error);
        }
    }
    context.logger = logger;

    // push_allocator(get_unmapping_allocator());
    context.print_style.default_format_struct.use_long_form_if_more_than_this_many_members = -1;
    context.print_style.default_format_struct.use_newlines_if_long_form = true;
    context.print_style.default_format_array.stop_printing_after_this_many_elements = 1000;

    log("soak\n");

    if (!yojimbo_init()) {
        log("error: failed to initialize Yojimbo!\n");
        exit(1);
    }

    // yojimbo_log_level(YOJIMBO_LOG_LEVEL_INFO);
    random_seed(cast,no_check(u64) to_milliseconds(current_time_consensus()));
    soak_main();
    yojimbo_shutdown();
    log("fin.\n");

    report_memory_leaks();
}

#scope_file

#import "Unmapping_Allocator";