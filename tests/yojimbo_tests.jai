#import "Unmapping_Allocator";

ENABLE_LOGGING :: true;
SOAK :: 0;

main :: () {
    // context.log_level = .VERBOSE;
    // context.log_level = .VERY_VERBOSE;
    context.logger = logger;

    // push_allocator(get_unmapping_allocator());

    random_seed(cast,no_check(u64) to_milliseconds(current_time_consensus()));

    iters := 0;
    while iters < 1 {
        #if !SOAK {
            iters += 1;
        }

        yojimbo_test();
    }

    report_memory_leaks();
}

yojimbo_test :: () {
#if 1 {
    address_test();
    serialize_test();
    netcode_test();
    reliable_test();

    log("\n--- Yojimbo --------------------------------------------------------------------\n");
    log("Running tests...\n");

    TEST(test_queue);
    TEST(test_address);
    TEST(test_bit_array);
    TEST(test_sequence_buffer);

    TEST(test_connection_reliable_ordered_messages);
    TEST(test_connection_reliable_ordered_blocks);
    TEST(test_connection_reliable_ordered_messages_and_blocks);
    TEST(test_connection_reliable_ordered_messages_and_blocks_multiple_channels);
    TEST(test_connection_unreliable_unordered_messages);
    TEST(test_connection_unreliable_unordered_blocks);

    TEST(test_client_server_messages);
    TEST(test_client_server_start_stop_restart);
    TEST(test_client_server_message_failed_to_serialize_reliable_ordered);
    TEST(test_client_server_message_failed_to_serialize_unreliable_unordered);
    // TODO(dlb): Should we re-introduce per-client allocators? It should be much simpler in Jai, because instead
    // of passing them explicitly everywhere we can push_allocator().
    // TEST(test_client_server_message_exhaust_stream_allocator);
    TEST(test_client_server_message_receive_queue_overflow);
    TEST(test_reliable_outbound_sequence_outdated);

    TEST(test_single_message_type_reliable);
    TEST(test_single_message_type_reliable_blocks);
    TEST(test_single_message_type_unreliable);

    TEST(test_client_server_messages_network_sim_leak);
} else {
    // These both seem to have memory leaks, but I can't find them, and they're both degenerate cases.
    // TEST(test_reliable_outbound_sequence_outdated);
    // TEST(test_client_server_message_receive_queue_overflow);

    /*
    =========================
    queue overflow
    =========================
    ----- 393,216 bytes in 1 allocation -----
    NewArray                          C:/dojo/jai/modules/Basic/module.jai:541
    resize                            C:/dojo/jai/modules/Hash_Table.jai:188
    expand                            C:/dojo/jai/modules/Hash_Table.jai:457
    table_add                         C:/dojo/jai/modules/Hash_Table.jai:284
    allocate_new_memory               C:/dojo/jai/modules/Unmapping_Allocator/module.jai:212
    unmapping_allocator_proc          C:/dojo/jai/modules/Unmapping_Allocator/module.jai:118
    alloc                             C:/dojo/jai/modules/Basic/module.jai:109
    New                               C:/dojo/jai/modules/Basic/module.jai:510
                                    c:/Users/User/Documents/Development/dlb_002/yojimbo_test_shared.jai:36
    message_factory_create_message    c:/Users/User/Documents/Development/dlb_002/modules/Yojimbo/message.jai:118
    serialize_messages                c:/Users/User/Documents/Development/dlb_002/modules/Yojimbo/channel_packet_data.jai:140
    channel_packet_data_serialize     c:/Users/User/Documents/Development/dlb_002/modules/Yojimbo/channel_packet_data.jai:75
    connection_packet_serialize       c:/Users/User/Documents/Development/dlb_002/modules/Yojimbo/connection.jai:49
    connection_read_packet            c:/Users/User/Documents/Development/dlb_002/modules/Yojimbo/connection.jai:183
    connection_process_packet         c:/Users/User/Documents/Development/dlb_002/modules/Yojimbo/connection.jai:198
    server_process_packet_function    c:/Users/User/Documents/Development/dlb_002/modules/Yojimbo/server.jai:311
    reliable_endpoint_receive_packet  c:/Users/User/Documents/Development/dlb_002/modules/Reliable/module.jai:356
    server_receive_packets            c:/Users/User/Documents/Development/dlb_002/modules/Yojimbo/server.jai:159
    pump_client_server_update         c:/Users/User/Documents/Development/dlb_002/yojimbo_tests.jai:1004
    test                              c:/Users/User/Documents/Development/dlb_002/yojimbo_tests.jai:1663
    yojimbo_test                      c:/Users/User/Documents/Development/dlb_002/yojimbo_tests.jai:64
    main                              c:/Users/User/Documents/Development/dlb_002/yojimbo_tests.jai:19

    Total: 393,216 bytes in 1 allocation.

    Marked as non-leaks: 96 bytes in 1 allocation.

    =========================
    sequence outdated
    =========================
    ----- 1,572,864 bytes in 1 allocation -----
    NewArray                                  C:/dojo/jai/modules/Basic/module.jai:541
    resize                                    C:/dojo/jai/modules/Hash_Table.jai:188
    expand                                    C:/dojo/jai/modules/Hash_Table.jai:457
    table_add                                 C:/dojo/jai/modules/Hash_Table.jai:284
    allocate_new_memory                       C:/dojo/jai/modules/Unmapping_Allocator/module.jai:212
    unmapping_allocator_proc                  C:/dojo/jai/modules/Unmapping_Allocator/module.jai:118
    alloc                                     C:/dojo/jai/modules/Basic/module.jai:109
    NewArray                                  C:/dojo/jai/modules/Basic/module.jai:541
    netcode_create_payload_packet             c:/Users/User/Documents/Development/dlb_002/modules/Netcode/module.jai:1805
    netcode_read_packet                       c:/Users/User/Documents/Development/dlb_002/modules/Netcode/module.jai:2268
    netcode_server_read_and_process_packet    c:/Users/User/Documents/Development/dlb_002/modules/Netcode/module.jai:3957
    netcode_server_receive_packets            c:/Users/User/Documents/Development/dlb_002/modules/Netcode/module.jai:4010
    netcode_server_update                     c:/Users/User/Documents/Development/dlb_002/modules/Netcode/module.jai:582
    server_advance_time                       c:/Users/User/Documents/Development/dlb_002/modules/Yojimbo/server.jai:172
    pump_client_server_update                 c:/Users/User/Documents/Development/dlb_002/yojimbo_tests.jai:1014
    test_reliable_outbound_sequence_outdated  c:/Users/User/Documents/Development/dlb_002/yojimbo_tests.jai:1761
    TEST                                      c:/Users/User/Documents/Development/dlb_002/yojimbo_tests.jai:81
    yojimbo_test                              c:/Users/User/Documents/Development/dlb_002/yojimbo_tests.jai:64
    main                                      c:/Users/User/Documents/Development/dlb_002/yojimbo_tests.jai:20

    Total: 1,572,864 bytes in 1 allocation.

    Marked as non-leaks: 96 bytes in 1 allocation.
    */
}
    log("Passed!\n");
}

#load "yojimbo_test_shared.jai";

#import "Bit_Array";
#import "Assertive";
#import "Reliable";

TEST :: (test: (), $call := #caller_code) {
    if !yojimbo_init() {
        log("error: failed to initialize yojimbo\n");
        exit(1);
    }
    assert_test(test, ENABLE_LOGGING, call);
    yojimbo_shutdown();
    reset_temporary_storage();
}

test_queue :: () {
    QueueSize :: 1024;

    queue: Queue(int);
    queue_init(*queue, QueueSize);
    defer queue_free(*queue);

    assert_equal(queue_empty(queue), true);
    assert_equal(queue_full(queue), false);
    assert_equal(queue.count, 0);
    assert_equal(queue.entries.count, QueueSize);

    NumEntries :: 100;

    for 0..NumEntries-1 {
        queue_push(*queue, it);
    }

    assert_equal(queue_empty(queue), false);
    assert_equal(queue_full(queue), false);
    assert_equal(queue.count, NumEntries);
    assert_equal(queue.entries.count, QueueSize);

    for 0..NumEntries-1 {
        assert_equal(queue[it], it);
    }

    for 0..NumEntries-1 {
        assert_equal(queue_pop(*queue), it);
    }

    assert_equal(queue_empty(queue), true);
    assert_equal(queue_full(queue), false);
    assert_equal(queue.count, 0);
    assert_equal(queue.entries.count, QueueSize);

    for 0..QueueSize-1 {
        queue_push(*queue, it);
    }

    assert_equal(queue_empty(queue), false);
    assert_equal(queue_full(queue), true);
    assert_equal(queue.count, QueueSize);
    assert_equal(queue.entries.count, QueueSize);

    queue_clear(*queue);

    assert_equal(queue_empty(queue), true);
    assert_equal(queue_full(queue), false);
    assert_equal(queue.count, 0);
    assert_equal(queue.entries.count, QueueSize);
}

test_address :: () {
    assert_equal(address_init_auto_detect("").type, IPType.None);
    assert_equal(address_init_auto_detect("[").type, IPType.None);
    assert_equal(address_init_auto_detect("[]").type, IPType.None);
    assert_equal(address_init_auto_detect("[]:").type, IPType.None);
    assert_equal(address_init_auto_detect(":").type, IPType.None);
    assert_equal(address_init_auto_detect("1").type, IPType.None);
    assert_equal(address_init_auto_detect("12").type, IPType.None);
    assert_equal(address_init_auto_detect("123").type, IPType.None);
    assert_equal(address_init_auto_detect("1234").type, IPType.None);
    assert_equal(address_init_auto_detect("1234.0.12313.0000").type, IPType.None);
    assert_equal(address_init_auto_detect("1234.0.12313.0000.0.0.0.0.0").type, IPType.None);
    assert_equal(address_init_auto_detect("1312313:123131:1312313:123131:1312313:123131:1312313:123131:1312313:123131:1312313:123131").type, IPType.None);
    assert_equal(address_init_auto_detect(".").type, IPType.None);
    assert_equal(address_init_auto_detect("..").type, IPType.None);
    assert_equal(address_init_auto_detect("...").type, IPType.None);
    assert_equal(address_init_auto_detect("....").type, IPType.None);
    assert_equal(address_init_auto_detect(".....").type, IPType.None);

    {
        address := address_init_auto_detect("107.77.207.77");
        assert_equal(address.type, IPType.IPv4);
        assert_equal(address.port, 0);
        assert_equal(address.data.v4[0], 107);
        assert_equal(address.data.v4[1], 77);
        assert_equal(address.data.v4[2], 207);
        assert_equal(address.data.v4[3], 77);
        assert_false(address_is_loopback(address));
    }

    {
        address := address_init_auto_detect("127.0.0.1");
        assert_equal(address.type, IPType.IPv4);
        assert_equal(address.port, 0);
        assert_equal(address.data.v4[0], 127);
        assert_equal(address.data.v4[1], 0);
        assert_equal(address.data.v4[2], 0);
        assert_equal(address.data.v4[3], 1);
        assert_true(address_is_loopback(address));
    }

    {
        address := address_init_auto_detect("107.77.207.77:40000");
        assert_equal(address.type, IPType.IPv4);
        assert_equal(address.port, 40000);
        assert_equal(address.data.v4[0], 107);
        assert_equal(address.data.v4[1], 77);
        assert_equal(address.data.v4[2], 207);
        assert_equal(address.data.v4[3], 77);
        assert_false(address_is_loopback(address));
    }

    {
        address := address_init_auto_detect("127.0.0.1:40000");
        assert_equal(address.type, IPType.IPv4);
        assert_equal(address.port, 40000);
        assert_equal(address.data.v4[0], 127);
        assert_equal(address.data.v4[1], 0);
        assert_equal(address.data.v4[2], 0);
        assert_equal(address.data.v4[3], 1);
        assert_true(address_is_loopback(address));
    }

    {
        address := address_init_auto_detect("fe80::202:b3ff:fe1e:8329");
        assert_equal(address.type, IPType.IPv6);
        assert_equal(address.port, 0);
        assert_equal(address.data.v6[0], 0xfe80);
        assert_equal(address.data.v6[1], 0x0000);
        assert_equal(address.data.v6[2], 0x0000);
        assert_equal(address.data.v6[3], 0x0000);
        assert_equal(address.data.v6[4], 0x0202);
        assert_equal(address.data.v6[5], 0xb3ff);
        assert_equal(address.data.v6[6], 0xfe1e);
        assert_equal(address.data.v6[7], 0x8329);
        assert_false(address_is_loopback(address));
    }

    {
        address := address_init_auto_detect("::");
        assert_equal(address.type, IPType.IPv6);
        assert_equal(address.port, 0);
        assert_equal(address.data.v6[0], 0x0000);
        assert_equal(address.data.v6[1], 0x0000);
        assert_equal(address.data.v6[2], 0x0000);
        assert_equal(address.data.v6[3], 0x0000);
        assert_equal(address.data.v6[4], 0x0000);
        assert_equal(address.data.v6[5], 0x0000);
        assert_equal(address.data.v6[6], 0x0000);
        assert_equal(address.data.v6[7], 0x0000);
        assert_false(address_is_loopback(address));
    }

    {
        address := address_init_auto_detect("::1");
        assert_equal(address.type, IPType.IPv6);
        assert_equal(address.port, 0);
        assert_equal(address.data.v6[0], 0x0000);
        assert_equal(address.data.v6[1], 0x0000);
        assert_equal(address.data.v6[2], 0x0000);
        assert_equal(address.data.v6[3], 0x0000);
        assert_equal(address.data.v6[4], 0x0000);
        assert_equal(address.data.v6[5], 0x0000);
        assert_equal(address.data.v6[6], 0x0000);
        assert_equal(address.data.v6[7], 0x0001);
        assert_true(address_is_loopback(address));
    }

    {
        address := address_init_auto_detect("[fe80::202:b3ff:fe1e:8329]:40000");
        assert_equal(address.type, IPType.IPv6);
        assert_equal(address.port, 40000);
        assert_equal(address.data.v6[0], 0xfe80);
        assert_equal(address.data.v6[1], 0x0000);
        assert_equal(address.data.v6[2], 0x0000);
        assert_equal(address.data.v6[3], 0x0000);
        assert_equal(address.data.v6[4], 0x0202);
        assert_equal(address.data.v6[5], 0xb3ff);
        assert_equal(address.data.v6[6], 0xfe1e);
        assert_equal(address.data.v6[7], 0x8329);
        assert_false(address_is_loopback(address));
    }

    {
        address := address_init_auto_detect("[::]:40000");
        assert_equal(address.type, IPType.IPv6);
        assert_equal(address.port, 40000);
        assert_equal(address.data.v6[0], 0x0000);
        assert_equal(address.data.v6[1], 0x0000);
        assert_equal(address.data.v6[2], 0x0000);
        assert_equal(address.data.v6[3], 0x0000);
        assert_equal(address.data.v6[4], 0x0000);
        assert_equal(address.data.v6[5], 0x0000);
        assert_equal(address.data.v6[6], 0x0000);
        assert_equal(address.data.v6[7], 0x0000);
        assert_false(address_is_loopback(address));
    }

    {
        address := address_init_auto_detect("[::1]:40000");
        assert_equal(address.type, IPType.IPv6);
        assert_equal(address.port, 40000);
        assert_equal(address.data.v6[0], 0x0000);
        assert_equal(address.data.v6[1], 0x0000);
        assert_equal(address.data.v6[2], 0x0000);
        assert_equal(address.data.v6[3], 0x0000);
        assert_equal(address.data.v6[4], 0x0000);
        assert_equal(address.data.v6[5], 0x0000);
        assert_equal(address.data.v6[6], 0x0000);
        assert_equal(address.data.v6[7], 0x0001);
        assert_true(address_is_loopback(address));
    }

    {
        address6: [8] u16 = .[0xFE80, 0x0000, 0x0000, 0x0000, 0x0202, 0xB3FF, 0xFE1E, 0x8329];

        address := address_init_v6(address6[0], address6[1], address6[2], address6[2],
                         address6[4], address6[5], address6[6], address6[7]);

        assert_equal(address.type, IPType.IPv6);
        assert_equal(address.port, 0);

        for address.data.v6
            assert_equal(it, address6[it_index]);

        assert_equal(address_to_string(address,, temp), "fe80:0:0:0:202:b3ff:fe1e:8329");
    }

    {
        address6: [8] u16 = .[0xFE80, 0x0000, 0x0000, 0x0000, 0x0202, 0xB3FF, 0xFE1E, 0x8329];

        address := address_init_v6(address6);

        assert_equal(address.type, IPType.IPv6);
        assert_equal(address.port, 0);

        for address.data.v6
            assert_equal(it, address6[it_index]);

        assert_equal(address_to_string(address,, temp), "fe80:0:0:0:202:b3ff:fe1e:8329");
    }

    {
        address6: [8] u16 = .[0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0001];

        address := address_init_v6(address6);

        assert_equal(address.type, IPType.IPv6);
        assert_equal(address.port, 0);

        for address.data.v6
            assert_equal(it, address6[it_index]);

        assert_equal(address_to_string(address,, temp), "0:0:0:0:0:0:0:1");
    }

    {
        address6: [8] u16 = .[0xFE80, 0x0000, 0x0000, 0x0000, 0x0202, 0xB3FF, 0xFE1E, 0x8329];

        address := address_init_v6(address6[0], address6[1], address6[2], address6[2],
                         address6[4], address6[5], address6[6], address6[7], 65535);

        assert_equal(address.type, IPType.IPv6);
        assert_equal(address.port, 65535);

        for address.data.v6
            assert_equal(it, address6[it_index]);

        assert_equal(address_to_string(address,, temp), "[fe80:0:0:0:202:b3ff:fe1e:8329]:65535");
    }

    {
        address6: [8] u16 = .[0xFE80, 0x0000, 0x0000, 0x0000, 0x0202, 0xB3FF, 0xFE1E, 0x8329];

        address := address_init_v6(address6, 65535);

        assert_equal(address.type, IPType.IPv6);
        assert_equal(address.port, 65535);

        for address.data.v6
            assert_equal(it, address6[it_index]);

        assert_equal(address_to_string(address,, temp), "[fe80:0:0:0:202:b3ff:fe1e:8329]:65535");
    }

    {
        address6: [8] u16 = .[0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0001];

        address := address_init_v6(address6, 65535);

        assert_equal(address.type, IPType.IPv6);
        assert_equal(address.port, 65535);

        for address.data.v6
            assert_equal(it, address6[it_index]);

        assert_equal(address_to_string(address,, temp), "[0:0:0:0:0:0:0:1]:65535");
    }

    {
        address := address_init_auto_detect("fe80::202:b3ff:fe1e:8329");
        assert_equal(address.type, IPType.IPv6);
        assert_equal(address.port, 0);
        assert_equal(address_to_string(address,, temp), "fe80:0:0:0:202:b3ff:fe1e:8329");
    }

    {
        address := address_init_auto_detect("::1");
        assert_equal(address.type, IPType.IPv6);
        assert_equal(address.port, 0);
        assert_equal(address_to_string(address,, temp), "0:0:0:0:0:0:0:1");
    }

    {
        address := address_init_auto_detect("[fe80::202:b3ff:fe1e:8329]:65535");
        assert_equal(address.type, IPType.IPv6);
        assert_equal(address.port, 65535);
        assert_equal(address_to_string(address,, temp), "[fe80:0:0:0:202:b3ff:fe1e:8329]:65535");
    }

    {
        address := address_init_auto_detect("[::1]:65535");
        assert_equal(address.type, IPType.IPv6);
        assert_equal(address.port, 65535);
        assert_equal(address_to_string(address,, temp), "[0:0:0:0:0:0:0:1]:65535");
    }
}

// NOTE(dlb): This is kinda silly, cus we didn't port Yojimbo's BitArray class and are using the Jai module, but hey,
// the more tests the better, right?
test_bit_array :: () {
    Size := 300;

    bit_array := make_bit_array(Size);
    defer deinit(*bit_array);

    // verify initial conditions

    assert_equal(bit_array.count, Size);

    for bit_array {
        assert_false(it);
    }

    // set every third bit and verify correct bits are set on read

    for bit_array {
        if (it_index % 3) == 0 {
            bit_array[it_index] = true;
        }
    }

    for bit_array {
        if (it_index % 3) == 0 {
            assert_true(it);
        } else {
            assert_false(it);
        }
    }

    // now clear every third bit to zero and verify all bits are zero

    for bit_array {
        if (it_index % 3) == 0 {
            bit_array[it_index] = false;
        }
    }

    for bit_array {
        assert_false(it);
    }

    // now set some more bits

    for bit_array {
        if (it_index % 10) == 0 {
            bit_array[it_index] = true;
        }
    }

    for bit_array {
        if (it_index % 10) == 0 {
            assert_true(it);
        } else {
            assert_false(it);
        }
    }

    // clear and verify all bits are zero

    clear_all_bits(*bit_array);

    for bit_array {
        assert_false(it);
    }
}

test_sequence_buffer :: () {
    TestSequenceData :: struct {
        sequence: u16 = 0xFFFF;
    };

    Size :: 256;

    sequence_buffer: SequenceBuffer(TestSequenceData);
    sequence_buffer_init(*sequence_buffer, Size);
    defer sequence_buffer_free(*sequence_buffer);

    for 0..Size-1 {
        entry := sequence_buffer_find(*sequence_buffer, xx it);
        assert_null(entry);
    }

    for 0..Size*4 {
        entry := sequence_buffer_insert(*sequence_buffer, xx it);
        entry.sequence = xx it;
        assert_equal(sequence_buffer_get_next_sequence(*sequence_buffer), cast(u16) it + 1);
    }

    for 0..Size {
        entry := sequence_buffer_insert(*sequence_buffer, xx it);
        assert_null(entry);
    }

    index := Size * 4;
    for 0..Size-1 {
        entry := sequence_buffer_find(*sequence_buffer, xx index);
        assert_not_null(entry);
        assert_equal(entry.sequence, xx index);
        index -= 1;
    }

    for 0..Size {
        entry := sequence_buffer_insert(*sequence_buffer, xx it, true);
        assert_not_null(entry);
        entry.sequence = xx it;
        assert_equal(sequence_buffer_get_next_sequence(*sequence_buffer), cast(u16) it + 1);
    }

    sequence_buffer_reset(*sequence_buffer);

    assert_equal(sequence_buffer_get_next_sequence(*sequence_buffer), 0);

    for 0..Size-1 {
        assert_null(sequence_buffer_find(*sequence_buffer, xx it));
    }
}

APOLLO_100_MS :: #run milliseconds_to_apollo(100);

pump_connection_update :: (connectionConfig: ConnectionConfig, time: *Apollo_Time, sender: *Connection,
                           receiver: *Connection, senderSequence: *u16, receiverSequence: *u16,
                           deltaTime: Apollo_Time = APOLLO_100_MS, packetLossPercent := 0) { //90) {

    packetData := NewArray(connectionConfig.maxPacketSize, u8,, temp);

    if connection_generate_packet(sender, senderSequence.*, packetData, *packetData.count) {
        if yojimbo_random_int(0, 100) >= packetLossPercent {
            connection_process_packet(receiver, senderSequence.*, packetData);
            connection_process_acks(sender, .[senderSequence.*]);
        }
    }

    packetData.count = connectionConfig.maxPacketSize;

    if connection_generate_packet(receiver, receiverSequence.*, packetData, *packetData.count) {
        if yojimbo_random_int(0, 100) >= packetLossPercent {
            connection_process_packet(sender, receiverSequence.*, packetData);
            connection_process_acks(receiver, .[receiverSequence.*]);
        }
    }

    time.* += deltaTime;

    connection_advance_time(sender, time);
    connection_advance_time(receiver, time);

    senderSequence.* += 1;
    receiverSequence.* += 1;
}

test_connection_reliable_ordered_messages :: () {
    sender: Connection;
    receiver: Connection;
    connectionConfig: ConnectionConfig;
    time := seconds_to_apollo(100);

    connection_init(*sender, TestMessageFactory, connectionConfig, time);
    defer connection_free(*sender);
    connection_init(*receiver, TestMessageFactory, connectionConfig, time);
    defer connection_free(*receiver);

    NumMessagesSent :: 64;

    for 0..NumMessagesSent-1 {
        message := cast(*TestMessage) message_factory_create_message(TestMessageFactory, xx TEST_MESSAGE);
        assert_not_null(message);
        message.sequence = xx it;
        connection_send_message(*sender, 0, message);
    }

    senderSequence: u16;
    receiverSequence: u16;

    NumIterations :: 1000;
    numMessagesReceived := 0;

    for 0..NumIterations-1 {
        pump_connection_update(connectionConfig, *time, *sender, *receiver, *senderSequence, *receiverSequence);

        while true {
            message := connection_receive_message(*receiver, 0);
            if message == null {
                break;
            }

            assert_equal(message.id, xx numMessagesReceived);
            assert_equal(message.type, xx TEST_MESSAGE);

            testMessage := cast(*TestMessage) message;
            assert_equal(testMessage.sequence, xx numMessagesReceived);

            message_release(message);
            numMessagesReceived += 1;
        }

        if numMessagesReceived == NumMessagesSent {
            break;
        }
    }

    assert_equal(numMessagesReceived, NumMessagesSent);
}

test_connection_reliable_ordered_blocks :: () {
    sender: Connection;
    receiver: Connection;
    connectionConfig: ConnectionConfig;
    time := seconds_to_apollo(100);

    connection_init(*sender, TestMessageFactory, connectionConfig, time);
    defer connection_free(*sender);
    connection_init(*receiver, TestMessageFactory, connectionConfig, time);
    defer connection_free(*receiver);

    NumMessagesSent :: 32;

    for msgIndex: 0..NumMessagesSent-1 {
        message := cast(*TestBlockMessage) message_factory_create_message(TestMessageFactory, xx TEST_BLOCK_MESSAGE);
        assert_not_null(message);
        message.sequence = xx msgIndex;

        blockSize := 1 + ((msgIndex * 901) % 3333);
        blockData := NewArray(blockSize, u8);
        for * blockData {
            it.* = cast,no_check(u8) (msgIndex + it_index);
        }
        message.blockData = blockData;
        connection_send_message(*sender, 0, message);
    }

    senderSequence: u16;
    receiverSequence: u16;

    NumIterations :: 10000;
    numMessagesReceived := 0;

    for iter: 0..NumIterations-1 {
        pump_connection_update(connectionConfig, *time, *sender, *receiver, *senderSequence, *receiverSequence);

        while true {
            message := connection_receive_message(*receiver, 0);
            if message == null {
                break;
            }

            assert_equal(message.id, xx numMessagesReceived);
            assert_equal(message.type, xx TEST_BLOCK_MESSAGE);

            blockMessage := cast(*TestBlockMessage) message;
            assert_equal(blockMessage.sequence, xx numMessagesReceived);

            blockSize := blockMessage.blockData.count;
            assert_equal(blockSize, 1 + ((numMessagesReceived * 901) % 3333));

            assert_not_null(blockMessage.blockData.data);

            for blockMessage.blockData {
                assert_equal(it, cast,no_check(u8) (numMessagesReceived + it_index));
            }

            message_release(message);
            numMessagesReceived += 1;
        }

        if numMessagesReceived == NumMessagesSent {
            break;
        }
    }

    assert_equal(numMessagesReceived, NumMessagesSent);
}

test_connection_reliable_ordered_messages_and_blocks :: () {
    sender: Connection;
    receiver: Connection;
    connectionConfig: ConnectionConfig;
    time := seconds_to_apollo(100);

    connection_init(*sender, TestMessageFactory, connectionConfig, time);
    defer connection_free(*sender);
    connection_init(*receiver, TestMessageFactory, connectionConfig, time);
    defer connection_free(*receiver);

    NumMessagesSent :: 32;

    for msgIndex: 0..NumMessagesSent-1 {
        if yojimbo_random_int(0, 1) == 1 {
            message := cast(*TestMessage) message_factory_create_message(TestMessageFactory, xx TEST_MESSAGE);
            assert_not_null(message);
            message.sequence = xx msgIndex;
            connection_send_message(*sender, 0, message);
        } else {
            message := cast(*TestBlockMessage) message_factory_create_message(TestMessageFactory, xx TEST_BLOCK_MESSAGE);
            assert_not_null(message);
            message.sequence = xx msgIndex;
            blockSize := 1 + ((msgIndex * 901) % 3333);
            blockData := NewArray(blockSize, u8);
            for * blockData {
                it.* = cast,no_check(u8) (msgIndex + it_index);
            }
            message.blockData = blockData;
            connection_send_message(*sender, 0, message);
        }
    }

    senderSequence: u16;
    receiverSequence: u16;

    NumIterations :: 10000;
    numMessagesReceived := 0;

    for iter: 0..NumIterations-1 {
        pump_connection_update(connectionConfig, *time, *sender, *receiver, *senderSequence, *receiverSequence);

        while true {
            message := connection_receive_message(*receiver, 0);
            if message == null {
                break;
            }

            assert_equal(message.id, xx numMessagesReceived);

            if cast(TestMessageType) message.type == {
                case TEST_MESSAGE;
                    testMessage := cast(*TestMessage) message;

                    assert_equal(testMessage.sequence, xx numMessagesReceived);

                    numMessagesReceived += 1;
                case TEST_BLOCK_MESSAGE;
                    blockMessage := cast(*TestBlockMessage) message;

                    assert_equal(blockMessage.sequence, xx numMessagesReceived);
                    assert_equal(blockMessage.blockData.count, 1 + ((numMessagesReceived * 901) % 3333));
                    assert_not_null(blockMessage.blockData.data);

                    for blockMessage.blockData {
                        assert_equal(it, cast,no_check(u8) (numMessagesReceived + it_index));
                    }

                    numMessagesReceived += 1;
            }

            message_release(message);
        }

        if numMessagesReceived == NumMessagesSent {
            break;
        }
    }

    assert_equal(numMessagesReceived, NumMessagesSent);
}

test_connection_reliable_ordered_messages_and_blocks_multiple_channels :: () {
    NumChannels :: 2;

    sender: Connection;
    receiver: Connection;
    connectionConfig: ConnectionConfig;
    connectionConfig.numChannels = NumChannels;
    connectionConfig.channel[0].type = .ReliableOrdered;
    connectionConfig.channel[0].maxMessagesPerPacket = 8;
    connectionConfig.channel[1].type = .ReliableOrdered;
    connectionConfig.channel[1].maxMessagesPerPacket = 8;
    time := seconds_to_apollo(100);

    connection_init(*sender, TestMessageFactory, connectionConfig, time);
    defer connection_free(*sender);
    connection_init(*receiver, TestMessageFactory, connectionConfig, time);
    defer connection_free(*receiver);

    NumMessagesSent :: 32;

    for channelIndex: 0..NumChannels-1 {
        for msgIndex: 0..NumMessagesSent-1 {
            if yojimbo_random_int(0, 1) == 1 {
                message := cast(*TestMessage) message_factory_create_message(TestMessageFactory, xx TEST_MESSAGE);
                assert_not_null(message);
                message.sequence = xx msgIndex;
                connection_send_message(*sender, channelIndex, message);
            } else {
                message := cast(*TestBlockMessage) message_factory_create_message(TestMessageFactory, xx TEST_BLOCK_MESSAGE);
                assert_not_null(message);
                message.sequence = xx msgIndex;
                blockSize := 1 + ((msgIndex * 901) % 3333);
                blockData := NewArray(blockSize, u8);
                for * blockData {
                    it.* = cast,no_check(u8) (msgIndex + it_index);
                }
                message.blockData = blockData;
                connection_send_message(*sender, channelIndex, message);
            }
        }
    }

    senderSequence: u16;
    receiverSequence: u16;

    NumIterations :: 10000;
    numMessagesReceived: [NumChannels] int;

    for iter: 0..NumIterations-1 {
        pump_connection_update(connectionConfig, *time, *sender, *receiver, *senderSequence, *receiverSequence);

        for channelIndex: 0..NumChannels-1 {
            while true {
                message := connection_receive_message(*receiver, channelIndex);
                if message == null {
                    break;
                }

                assert_equal(message.id, xx numMessagesReceived[channelIndex]);

                if cast(TestMessageType) message.type == {
                    case TEST_MESSAGE;
                        testMessage := cast(*TestMessage) message;

                        assert_equal(testMessage.sequence, xx numMessagesReceived[channelIndex]);

                        numMessagesReceived[channelIndex] += 1;
                    case TEST_BLOCK_MESSAGE;
                        blockMessage := cast(*TestBlockMessage) message;

                        assert_equal(blockMessage.sequence, xx numMessagesReceived[channelIndex]);

                        assert_equal(blockMessage.blockData.count, 1 + ((numMessagesReceived[channelIndex] * 901) % 3333));
                        assert_not_null(blockMessage.blockData.data);

                        for blockMessage.blockData {
                            assert_equal(it, cast,no_check(u8) (numMessagesReceived[channelIndex] + it_index));
                        }

                        numMessagesReceived[channelIndex] += 1;
                }

                message_release(message);
            }
        }

        receivedAllMessages := true;

        for channelIndex: 0..NumChannels-1 {
            if numMessagesReceived[channelIndex] != NumMessagesSent {
                receivedAllMessages = false;
                break;
            }
        }

        if receivedAllMessages {
            break;
        }
    }

    for channelIndex: 0..NumChannels-1 {
        assert_equal(numMessagesReceived[channelIndex], NumMessagesSent);
    }
}

test_connection_unreliable_unordered_messages :: () {
    sender: Connection;
    receiver: Connection;
    connectionConfig: ConnectionConfig;
    connectionConfig.numChannels = 1;
    connectionConfig.channel[0].type = .UnreliableUnordered;
    time := seconds_to_apollo(100);

    connection_init(*sender, TestMessageFactory, connectionConfig, time);
    defer connection_free(*sender);
    connection_init(*receiver, TestMessageFactory, connectionConfig, time);
    defer connection_free(*receiver);

    NumMessagesSent :: 16;

     for 0..NumMessagesSent-1 {
        message := cast(*TestMessage) message_factory_create_message(TestMessageFactory, xx TEST_MESSAGE);
        assert_not_null(message);
        message.sequence = xx it;
        connection_send_message(*sender, 0, message);
    }

    senderSequence: u16;
    receiverSequence: u16;

    NumIterations :: 256;
    numMessagesReceived := 0;

    for 0..NumIterations-1 {
        pump_connection_update(connectionConfig, *time, *sender, *receiver, *senderSequence, *receiverSequence, APOLLO_100_MS, 0);

        while true {
            message := connection_receive_message(*receiver, 0);
            if message == null {
                break;
            }

            assert_equal(message.type, xx TEST_MESSAGE);

            testMessage := cast(*TestMessage) message;
            assert_equal(testMessage.sequence, xx numMessagesReceived);

            message_release(message);
            numMessagesReceived += 1;
        }

        if numMessagesReceived == NumMessagesSent {
            break;
        }
    }

    assert_equal(numMessagesReceived, NumMessagesSent);
}

test_connection_unreliable_unordered_blocks :: () {
    sender: Connection;
    receiver: Connection;
    connectionConfig: ConnectionConfig;
    connectionConfig.numChannels = 1;
    connectionConfig.channel[0].type = .UnreliableUnordered;
    time := seconds_to_apollo(100);

    connection_init(*sender, TestMessageFactory, connectionConfig, time);
    defer connection_free(*sender);
    connection_init(*receiver, TestMessageFactory, connectionConfig, time);
    defer connection_free(*receiver);

    NumMessagesSent :: 8;

    for msgIndex: 0..NumMessagesSent-1 {
        message := cast(*TestBlockMessage) message_factory_create_message(TestMessageFactory, xx TEST_BLOCK_MESSAGE);
        assert_not_null(message);
        message.sequence = xx msgIndex;

        blockSize := 1 + (msgIndex * 7);
        blockData := NewArray(blockSize, u8);
        for * blockData {
            it.* = cast,no_check(u8) (msgIndex + it_index);
        }
        message.blockData = blockData;
        connection_send_message(*sender, 0, message);
    }

    senderSequence: u16;
    receiverSequence: u16;

    NumIterations :: 256;
    numMessagesReceived := 0;

    for iter: 0..NumIterations-1 {
        pump_connection_update(connectionConfig, *time, *sender, *receiver, *senderSequence, *receiverSequence, APOLLO_100_MS, 0);

        while true {
            message := connection_receive_message(*receiver, 0);
            if message == null {
                break;
            }

            assert_equal(message.type, xx TEST_BLOCK_MESSAGE);

            blockMessage := cast(*TestBlockMessage) message;
            assert_equal(blockMessage.sequence, xx numMessagesReceived);

            blockSize := blockMessage.blockData.count;
            assert_equal(blockSize, 1 + (numMessagesReceived * 7));

            assert_not_null(blockMessage.blockData.data);

            for blockMessage.blockData {
                assert_equal(it, cast,no_check(u8) (numMessagesReceived + it_index));
            }

            message_release(message);
            numMessagesReceived += 1;
        }

        if numMessagesReceived == NumMessagesSent {
            break;
        }
    }

    assert_equal(numMessagesReceived, NumMessagesSent);
}

pump_client_server_update :: (time: *Apollo_Time, clients: [] *Client, servers: [] *Server, deltaTime: Apollo_Time = APOLLO_100_MS) {
    for clients {
        client_send_packets(it);
    }
    for servers {
        server_send_packets(it);
    }

    for clients {
        client_receive_packets(it);
    }
    for servers {
        server_receive_packets(it);
    }

    time.* += deltaTime;

    for clients {
        client_advance_time(it, time.*);
    }
    for servers {
        server_advance_time(it, time.*);
    }

    // sleep_milliseconds(0);  // Don't ask me.. it was already here. Maybe it helps yield to WinSock.. idk.
}

send_client_to_server_messages :: (client: *Client, numMessagesToSend: int, channelIndex := 0) {
    for msgIndex: 0..numMessagesToSend-1 {
        if !client_can_send_message(client, channelIndex) {
            break;
        }

        // 90% normal, 10% blocks
        if (yojimbo_random_int(1, 10) != 1) {
            message := cast(*TestMessage) message_factory_create_message(TestMessageFactory, xx TEST_MESSAGE);
            assert_not_null(message);
            message.sequence = xx msgIndex;
            client_send_message(client, channelIndex, message);
        } else {
            message := cast(*TestBlockMessage) message_factory_create_message(TestMessageFactory, xx TEST_BLOCK_MESSAGE);
            assert_not_null(message);
            message.sequence = xx msgIndex;

            blockSize := 1 + ((msgIndex * 901) % 1001);
            blockData := NewArray(blockSize, u8);
            for * blockData {
                it.* = cast,no_check(u8) (msgIndex + it_index);
            }
            message.blockData = blockData;
            client_send_message(client, channelIndex, message);
        }
    }
}

send_server_to_client_messages :: (server: *Server, clientIndex: int, numMessagesToSend: int, channelIndex := 0) {
    for msgIndex: 0..numMessagesToSend-1 {
        if !server_can_send_message(server, clientIndex, channelIndex) {
            break;
        }

        // 90% normal, 10% blocks
        if (yojimbo_random_int(1, 10) != 1) {
            message := cast(*TestMessage) message_factory_create_message(TestMessageFactory, xx TEST_MESSAGE);
            assert_not_null(message);
            message.sequence = xx msgIndex;
            server_send_message(server, clientIndex, channelIndex, message);
        } else {
            message := cast(*TestBlockMessage) message_factory_create_message(TestMessageFactory, xx TEST_BLOCK_MESSAGE);
            assert_not_null(message);
            message.sequence = xx msgIndex;

            blockSize := 1 + ((msgIndex * 901) % 1001);
            blockData := NewArray(blockSize, u8);
            for * blockData {
                it.* = cast,no_check(u8) (msgIndex + it_index);
            }
            message.blockData = blockData;
            server_send_message(server, clientIndex, channelIndex, message);
        }
    }
}

process_server_to_client_messages :: (client: *Client, numMessagesReceivedFromServer: *int) {
    while true {
        message := client_receive_message(client, 0);
        if message == null {
            break;
        }

        assert_equal(message.id, xx numMessagesReceivedFromServer.*);

        if cast(TestMessageType) message.type == {
            case TEST_MESSAGE;
                assert_equal(message.blockData.count, 0);
                testMessage := cast(*TestMessage) message;

                assert_equal(testMessage.sequence, xx numMessagesReceivedFromServer.*);
                numMessagesReceivedFromServer.* += 1;
            case TEST_BLOCK_MESSAGE;
                blockMessage := cast(*TestBlockMessage) message;
                assert_equal(blockMessage.sequence, xx numMessagesReceivedFromServer.*);

                assert_equal(blockMessage.blockData.count, 1 + ((numMessagesReceivedFromServer.* * 901) % 1001));
                assert_not_null(blockMessage.blockData.data);
                for * blockMessage.blockData {
                    it.* = cast,no_check(u8) (numMessagesReceivedFromServer.* + it_index);
                }
                numMessagesReceivedFromServer.* += 1;
        }

        client_release_message(client, message);
    }
}

process_client_to_server_messages :: (server: *Server, clientIndex: int, numMessagesReceivedFromClient: *int) {
    while true {
        message := server_receive_message(server, clientIndex, 0);
        if message == null {
            break;
        }

        assert_equal(message.id, xx numMessagesReceivedFromClient.*);

        if cast(TestMessageType) message.type == {
            case TEST_MESSAGE;
                assert_equal(message.blockData.count, 0);
                testMessage := cast(*TestMessage) message;

                assert_equal(testMessage.sequence, xx numMessagesReceivedFromClient.*);
                numMessagesReceivedFromClient.* += 1;
            case TEST_BLOCK_MESSAGE;
                blockMessage := cast(*TestBlockMessage) message;
                assert_equal(blockMessage.sequence, xx numMessagesReceivedFromClient.*);

                assert_equal(blockMessage.blockData.count, 1 + ((numMessagesReceivedFromClient.* * 901) % 1001));
                assert_not_null(blockMessage.blockData.data);
                for * blockMessage.blockData {
                    it.* = cast,no_check(u8) (numMessagesReceivedFromClient.* + it_index);
                }
                numMessagesReceivedFromClient.* += 1;
        }

        server_release_message(server, clientIndex, message);
    }
}

test_client_server_messages :: () {
    clientId: u64 = 1;

    clientAddress := address_init_v4("0.0.0.0", ClientPort);
    serverAddress := address_init_v4("127.0.0.1", ServerPort);

    config: ClientServerConfig;
    config.channel[0].messageSendQueueSize = 32;
    config.channel[0].maxMessagesPerPacket = 8;
    config.channel[0].maxBlockSize = 1024;
    config.channel[0].blockFragmentSize = 200;
    time := seconds_to_apollo(100);

    client: Client;
    client_init(*client, clientAddress, config, TestMessageFactory, time);
    defer client_free(*client);

    privateKey: [KeyBytes] u8;

    server: Server;
    server_init(*server, privateKey, serverAddress, config, TestMessageFactory, time);
    defer server_free(*server);

    server_start(*server, MaxClients);

    network_simulator_set_latency(server.networkSimulator, 250);
    network_simulator_set_jitter(server.networkSimulator, 100);
    network_simulator_set_packet_loss(server.networkSimulator, 25.0);
    network_simulator_set_duplicates(server.networkSimulator, 25.0);

    clients := *Client.[ *client ];
    servers := *Server.[ *server ];

    for 0..1 {
        client_insecure_connect(*client, privateKey, clientId, serverAddress);

        network_simulator_set_latency(client.networkSimulator, 250);
        network_simulator_set_jitter(client.networkSimulator, 100);
        network_simulator_set_packet_loss(client.networkSimulator, 25.0);
        network_simulator_set_duplicates(client.networkSimulator, 25.0);

        NumIterations :: 10000;

        for 0..NumIterations-1 {
            pump_client_server_update(*time, clients, servers);

            if client_connection_failed(*client) {
                break;
            }

            if client_is_connected(*client) && server_get_num_connected_clients(*server) == 1 {
                break;
            }
        }

        assert_false(client_is_connecting(*client));
        assert_true(client_is_connected(*client));
        assert_equal(server_get_num_connected_clients(*server), 1);
        assert_equal(client_get_client_index(*client), 0);
        assert_true(server_is_client_connected(*server, 0));

        NumMessagesSent := config.channel[0].messageSendQueueSize;

        send_client_to_server_messages(*client, NumMessagesSent);

        send_server_to_client_messages(*server, client_get_client_index(*client), NumMessagesSent);

        numMessagesReceivedFromClient := 0;
        numMessagesReceivedFromServer := 0;

        for 0..NumIterations-1 {
            if !client_is_connected(*client) {
                break;
            }

            pump_client_server_update(*time, clients, servers);

            process_server_to_client_messages(*client, *numMessagesReceivedFromServer);
            process_client_to_server_messages(*server, client_get_client_index(*client), *numMessagesReceivedFromClient);

            if numMessagesReceivedFromClient == NumMessagesSent && numMessagesReceivedFromServer == NumMessagesSent {
                break;
            }
        }

        assert_true(client_is_connected(*client));
        assert_true(server_is_client_connected(*server, client_get_client_index(*client)));

        assert_equal(numMessagesReceivedFromClient, NumMessagesSent);
        assert_equal(numMessagesReceivedFromServer, NumMessagesSent);

        client_disconnect(*client);

        for 0..NumIterations-1 {
            pump_client_server_update(*time, clients, servers);

            if !client_is_connected(*client) && server_get_num_connected_clients(*server) == 0 {
                break;
            }
        }

        assert_false(client_is_connected(*client));
        assert_equal(server_get_num_connected_clients(*server), 0);
    }

    server_stop(*server);
}

create_clients :: (clients: [] *Client, address: IPAddress, config: ClientServerConfig, messageFactory: MessageFactory, time: Apollo_Time) {
    for * clients {
        it.* = New(Client);
        client_init(it.*, address, config, messageFactory, time);
    }
}

connect_clients :: (clients: [] *Client, privateKey: [KeyBytes] u8, serverAddress: IPAddress) {
    for clients {
        client_insecure_connect(it, privateKey, cast(u64) it_index + 1, serverAddress);
        network_simulator_set_latency(it.networkSimulator, 250);
        network_simulator_set_jitter(it.networkSimulator, 100);
        network_simulator_set_packet_loss(it.networkSimulator, 25.0);
        network_simulator_set_duplicates(it.networkSimulator, 25.0);
    }
}

destroy_clients :: (clients: [] *Client) {
    for clients {
        client_disconnect(it);
        client_free(it);
        free(it);
    }
}

all_clients_connected :: (server: *Server, clients: [] *Client) -> bool {
    if server_get_num_connected_clients(server) != clients.count {
        return false;
    }

    for clients {
        if !client_is_connected(it) {
            return false;
        }
    }

    return true;
}

any_client_disconnected :: (clients: [] *Client) -> bool {
    for clients {
        if client_is_disconnected(it) {
            return true;
        }
    }

    return false;
}

test_client_server_start_stop_restart :: () {
    clientAddress := address_init_v4("0.0.0.0", 0);
    serverAddress := address_init_v4("127.0.0.1", ServerPort);

    time := seconds_to_apollo(100);

    config: ClientServerConfig;
    config.channel[0].messageSendQueueSize = 32;
    config.channel[0].maxMessagesPerPacket = 8;
    config.channel[0].maxBlockSize = 1024;
    config.channel[0].blockFragmentSize = 200;

    privateKey: [KeyBytes] u8;

    server: Server;
    server_init(*server, privateKey, serverAddress, config, TestMessageFactory, time);

    server_start(*server, MaxClients);

    network_simulator_set_latency(server.networkSimulator, 250);
    network_simulator_set_jitter(server.networkSimulator, 100);
    network_simulator_set_packet_loss(server.networkSimulator, 25);
    network_simulator_set_duplicates(server.networkSimulator, 25);

    numClients := int.[1, 1]; //int.[3, 5, 1];
    NumIterations := numClients.count;

    for iter: 0..NumIterations-1 {
        clients := NewArray(numClients[iter], *Client,, temp);
        create_clients(clients, clientAddress, config, TestMessageFactory, time);

        server_start(*server, clients.count);
        connect_clients(clients, privateKey, serverAddress);

        while true {
            servers := *Server.[*server];

            pump_client_server_update(*time, clients, servers);

            if any_client_disconnected(clients) {
                break;
            }
            if all_clients_connected(*server, clients) {
                break;
            }
        }

        assert_true(all_clients_connected(*server, clients));

        NumMessagesSent := config.channel[0].messageSendQueueSize;

        for clients {
            send_client_to_server_messages(it, NumMessagesSent);
            send_server_to_client_messages(*server, it_index, NumMessagesSent);
        }

        numMessagesReceivedFromClient: [MaxClients] int;
        numMessagesReceivedFromServer: [MaxClients] int;

		NumInternalIterations := 10000;

        for 0..NumInternalIterations-1 {
            servers := *Server.[*server];

            pump_client_server_update(*time, clients, servers);

            allMessagesReceived := true;

            for clients {
                process_server_to_client_messages(it, *numMessagesReceivedFromServer[it_index]);

                if numMessagesReceivedFromServer[it_index] != NumMessagesSent {
                    allMessagesReceived = false;
                }

                clientIndex := client_get_client_index(it);
                process_client_to_server_messages(*server, clientIndex, *numMessagesReceivedFromClient[clientIndex]);

                if numMessagesReceivedFromClient[clientIndex] != NumMessagesSent {
                    allMessagesReceived = false;
                }
            }

            if allMessagesReceived {
                break;
            }
        }

        for clients {
            assert_equal(numMessagesReceivedFromClient[it_index], NumMessagesSent);
            assert_equal(numMessagesReceivedFromServer[it_index], NumMessagesSent);
        }

        destroy_clients(clients);

        server_stop(*server);
    }
}

test_client_server_message_failed_to_serialize_reliable_ordered :: () {
    clientId: u64 = 1;

    clientAddress := address_init_v4("0.0.0.0", ClientPort);
    serverAddress := address_init_v4("127.0.0.1", ServerPort);

    time := seconds_to_apollo(100);

    config: ClientServerConfig;
    config.maxPacketSize = 1100;
    config.numChannels = 1;
    config.channel[0].type = .ReliableOrdered;
    config.channel[0].maxBlockSize = 1024;
    config.channel[0].blockFragmentSize = 200;

    privateKey: [KeyBytes] u8;

    server: Server;
    server_init(*server, privateKey, serverAddress, config, TestMessageFactory, time);
    server_start(*server, MaxClients);

    client: Client;
    client_init(*client, clientAddress, config, TestMessageFactory, time);
    client_insecure_connect(*client, privateKey, clientId, serverAddress);

    clients := *Client.[*client];
    servers := *Server.[*server];

    NumIterations := 10000;

    for 0..NumIterations-1 {
        pump_client_server_update(*time, clients, servers);

        if client_connection_failed(*client) {
            break;
        }
        if client_is_connected(*client) && server_get_num_connected_clients(*server) == 1 {
            break;
        }
    }

    assert_false(client_is_connecting(*client));
    assert_true(client_is_connected(*client));
    assert_equal(server_get_num_connected_clients(*server), 1);
    assert_equal(client_get_client_index(*client), 0);
    assert_true(server_is_client_connected(*server, 0));

    // send a message from client to server that fails to serialize on read, this should disconnect the client from the server

    message := message_factory_create_message(TestMessageFactory, xx TEST_SERIALIZE_FAIL_ON_READ_MESSAGE);
    assert_not_null(message);
    client_send_message(*client, 0, message);

    for 0..255 {
        pump_client_server_update(*time, clients, servers);

        if !client_is_connected(*client) && server_get_num_connected_clients(*server) == 0 {
            break;
        }
    }

    assert_false(client_is_connected(*client));
    assert_equal(server_get_num_connected_clients(*server), 0);

    client_disconnect(*client);
    server_stop(*server);

    client_free(*client);
    server_free(*server);
}

test_client_server_message_failed_to_serialize_unreliable_unordered :: () {
    clientId: u64 = 1;

    clientAddress := address_init_v4("0.0.0.0", ClientPort);
    serverAddress := address_init_v4("127.0.0.1", ServerPort);

    time := seconds_to_apollo(100);

    config: ClientServerConfig;
    config.maxPacketSize = 1100;
    config.numChannels = 1;
    config.channel[0].type = .UnreliableUnordered;
    config.channel[0].maxBlockSize = 1024;
    config.channel[0].blockFragmentSize = 200;

    privateKey: [KeyBytes] u8;

    server: Server;
    server_init(*server, privateKey, serverAddress, config, TestMessageFactory, time);
    server_start(*server, MaxClients);

    client: Client;
    client_init(*client, clientAddress, config, TestMessageFactory, time);
    client_insecure_connect(*client, privateKey, clientId, serverAddress);

    clients := *Client.[*client];
    servers := *Server.[*server];

    NumIterations := 10000;

    for 0..NumIterations-1 {
        pump_client_server_update(*time, clients, servers);

        if client_connection_failed(*client) {
            break;
        }
        if client_is_connected(*client) && server_get_num_connected_clients(*server) == 1 {
            break;
        }
    }

    assert_false(client_is_connecting(*client));
    assert_true(client_is_connected(*client));
    assert_equal(server_get_num_connected_clients(*server), 1);
    assert_equal(client_get_client_index(*client), 0);
    assert_true(server_is_client_connected(*server, 0));

    // send a message from client to server that fails to serialize on read, this should disconnect the client from the server

    for 0..255 {
        message := message_factory_create_message(TestMessageFactory, xx TEST_SERIALIZE_FAIL_ON_READ_MESSAGE);
        assert_not_null(message);
        client_send_message(*client, 0, message);

        pump_client_server_update(*time, clients, servers);

        if !client_is_connected(*client) && server_get_num_connected_clients(*server) == 0 {
            break;
        }
    }

    assert_false(client_is_connected(*client));
    assert_equal(server_get_num_connected_clients(*server), 0);

    client_disconnect(*client);
    server_stop(*server);

    client_free(*client);
    server_free(*server);
}

test_client_server_message_exhaust_stream_allocator :: () {
    clientId: u64 = 1;

    clientAddress := address_init_v4("0.0.0.0", ClientPort);
    serverAddress := address_init_v4("127.0.0.1", ServerPort);

    time := seconds_to_apollo(100);

    config: ClientServerConfig;
    config.maxPacketSize = 1100;
    config.numChannels = 1;
    config.channel[0].type = .ReliableOrdered;
    config.channel[0].maxBlockSize = 1024;
    config.channel[0].blockFragmentSize = 200;

    privateKey: [KeyBytes] u8;

    server: Server;
    server_init(*server, privateKey, serverAddress, config, TestMessageFactory, time);
    server_start(*server, MaxClients);

    client: Client;
    client_init(*client, clientAddress, config, TestMessageFactory, time);
    client_insecure_connect(*client, privateKey, clientId, serverAddress);

    clients := *Client.[*client];
    servers := *Server.[*server];

    NumIterations := 10000;

    for 0..NumIterations-1 {
        pump_client_server_update(*time, clients, servers);

        if client_connection_failed(*client) {
            break;
        }
        if client_is_connected(*client) && server_get_num_connected_clients(*server) == 1 {
            break;
        }
    }

    assert_false(client_is_connecting(*client));
    assert_true(client_is_connected(*client));
    assert_equal(server_get_num_connected_clients(*server), 1);
    assert_equal(client_get_client_index(*client), 0);
    assert_true(server_is_client_connected(*server, 0));

    // send a message from client to server that exhausts the stream allocator on read, this should disconnect the client from the server

    message := message_factory_create_message(TestMessageFactory, xx TEST_EXHAUST_STREAM_ALLOCATOR_ON_READ_MESSAGE);
    assert_not_null(message);
    client_send_message(*client, 0, message);

    for 0..255 {
        pump_client_server_update(*time, clients, servers);

        if !client_is_connected(*client) && server_get_num_connected_clients(*server) == 0 {
            break;
        }
    }

    assert_false(client_is_connected(*client));
    assert_equal(server_get_num_connected_clients(*server), 0);

    client_disconnect(*client);
    server_stop(*server);

    client_free(*client);
    server_free(*server);
}

test_client_server_message_receive_queue_overflow :: () {
    clientId: u64 = 1;

    clientAddress := address_init_v4("0.0.0.0", ClientPort);
    serverAddress := address_init_v4("127.0.0.1", ServerPort);

    time := seconds_to_apollo(100);

    config: ClientServerConfig;
    config.maxPacketSize = 1100;
    config.numChannels = 1;
    config.channel[0].type = .ReliableOrdered;
    config.channel[0].maxBlockSize = 1024;
    config.channel[0].blockFragmentSize = 200;
    config.channel[0].messageSendQueueSize = 1024;
    config.channel[0].messageReceiveQueueSize = 256;

    privateKey: [KeyBytes] u8;

    server: Server;
    server_init(*server, privateKey, serverAddress, config, TestMessageFactory, time);
    server_start(*server, MaxClients);

    client: Client;
    client_init(*client, clientAddress, config, TestMessageFactory, time);
    client_insecure_connect(*client, privateKey, clientId, serverAddress);

    clients := *Client.[*client];
    servers := *Server.[*server];

    while true {
        pump_client_server_update(*time, clients, servers);

        if client_connection_failed(*client) {
            break;
        }
        if client_is_connected(*client) && server_get_num_connected_clients(*server) == 1 {
            break;
        }
    }

    assert_false(client_is_connecting(*client));
    assert_true(client_is_connected(*client));
    assert_equal(server_get_num_connected_clients(*server), 1);
    assert_equal(client_get_client_index(*client), 0);
    assert_true(server_is_client_connected(*server, 0));

    // send a lot of messages, but don't dequeue them, this tests that the receive queue is able to handle overflow
    // eg. the receiver should detect an error and disconnect the client, because the message is out of bounds.

    NumMessagesSent := config.channel[0].messageSendQueueSize;

    send_client_to_server_messages(*client, NumMessagesSent);

    for 0..(NumMessagesSent*4)-1 {
        pump_client_server_update(*time, clients, servers);
    }

    client_disconnect(*client);
    server_stop(*server);

    client_free(*client);
    server_free(*server);
}

test_reliable_outbound_sequence_outdated :: () {
    clientId: u64 = 1;

    clientAddress := address_init_v4("0.0.0.0", ClientPort);
    serverAddress := address_init_v4("127.0.0.1", ServerPort);

    time := seconds_to_apollo(100);
    deltaTime := milliseconds_to_apollo(16);

    config: ClientServerConfig;
    config.numChannels = 2;
    config.timeout = APOLLO_TIME_INVALID;

    BlockSize := config.channel[0].blockFragmentSize * 2;

    privateKey: [KeyBytes] u8;

    server: Server;
    server_init(*server, privateKey, serverAddress, config, TestMessageFactory, time);
    server_start(*server, MaxClients);

    client: Client;
    client_init(*client, clientAddress, config, TestMessageFactory, time);
    client_insecure_connect(*client, privateKey, clientId, serverAddress);

    clients := *Client.[*client];
    servers := *Server.[*server];

    NumIterations :: 50000;

    for 0..NumIterations-1 {
        pump_client_server_update(*time, clients, servers);

        if client_connection_failed(*client) {
            break;
        }
        if client_is_connected(*client) && server_get_num_connected_clients(*server) == 1 {
            break;
        }
    }

    assert_false(client_is_connecting(*client));
    assert_true(client_is_connected(*client));
    assert_equal(server_get_num_connected_clients(*server), 1);
    assert_equal(client_get_client_index(*client), 0);
    assert_true(server_is_client_connected(*server, 0));

    numMessagesSent := 0;

    message := message_factory_create_message(TestMessageFactory, xx TEST_MESSAGE);
    assert_not_null(message);
    client_send_message(*client, 0, message);

    numMessagesSent += 1;

    blockMessage := message_factory_create_message(TestMessageFactory, xx TEST_BLOCK_MESSAGE);
    assert_not_null(blockMessage);
    blockMessage.blockData = NewArray(BlockSize, u8);
    client_send_message(*client, 1, blockMessage);

    numMessagesSent += 1;

    // Simulate packet sequence being incremented by unreliable messages until it appears outdated.
    for 0..32768-1 {
        client_send_packets(*client);
    }

    message2 := message_factory_create_message(TestMessageFactory, xx TEST_MESSAGE);
    assert_not_null(message2);
    client_send_message(*client, 0, message2);

    numMessagesSent += 1;

    blockMessage2 := message_factory_create_message(TestMessageFactory, xx TEST_BLOCK_MESSAGE);
    assert_not_null(blockMessage2);
    blockMessage2.blockData = NewArray(BlockSize, u8);
    client_send_message(*client, 1, blockMessage2);

    numMessagesSent += 1;

    numMessagesReceived := 0;

    for 0..NumIterations-1 {
        if !client_is_connected(*client) {
            break;
        }

        pump_client_server_update(*time, clients, servers, deltaTime);

        for channelIndex: 0..config.numChannels-1 {
            messageFromClient := server_receive_message(*server, 0, channelIndex);
            if messageFromClient != null {
                message_release(messageFromClient);
                numMessagesReceived += 1;
             }
        }

        if numMessagesReceived == numMessagesSent {
            break;
        }
    }

    assert_true(client_is_connected(*client));
    assert_true(server_is_client_connected(*server, client_get_client_index(*client)));
    assert_equal(numMessagesReceived, numMessagesSent);

    client_disconnect(*client);

    for 0..NumIterations-1 {
        pump_client_server_update(*time, clients, servers);

        if !client_is_connected(*client) && server_get_num_connected_clients(*server) == 0 {
            break;
        }
    }

    assert_false(client_is_connected(*client));
    assert_equal(server_get_num_connected_clients(*server), 0);

    server_stop(*server);

    client_free(*client);
    server_free(*server);
}

test_single_message_type_reliable :: () {
    sender: Connection;
    receiver: Connection;
    connectionConfig: ConnectionConfig;
    time := seconds_to_apollo(100);

    connection_init(*sender, SingleTestMessageFactory, connectionConfig, time);
    defer connection_free(*sender);
    connection_init(*receiver, SingleTestMessageFactory, connectionConfig, time);
    defer connection_free(*receiver);

    NumMessagesSent :: 64;

    for 0..NumMessagesSent-1 {
        message := cast(*TestMessage) message_factory_create_message(SingleTestMessageFactory, xx SINGLE_TEST_MESSAGE);
        assert_not_null(message);
        message.sequence = xx it;
        connection_send_message(*sender, 0, message);
    }

    senderSequence: u16;
    receiverSequence: u16;

    NumIterations :: 1000;
    numMessagesReceived := 0;

    for 0..NumIterations-1 {
        pump_connection_update(connectionConfig, *time, *sender, *receiver, *senderSequence, *receiverSequence);

        while true {
            message := connection_receive_message(*receiver, 0);
            if message == null {
                break;
            }

            assert_equal(message.id, xx numMessagesReceived);
            assert_equal(message.type, xx SINGLE_TEST_MESSAGE);

            testMessage := cast(*TestMessage) message;
            assert_equal(testMessage.sequence, xx numMessagesReceived);

            message_release(message);
            numMessagesReceived += 1;
        }

        if numMessagesReceived == NumMessagesSent {
            break;
        }
    }

    assert_equal(numMessagesReceived, NumMessagesSent);
}

test_single_message_type_reliable_blocks :: () {
    sender: Connection;
    receiver: Connection;
    connectionConfig: ConnectionConfig;
    time := seconds_to_apollo(100);

    connection_init(*sender, SingleBlockTestMessageFactory, connectionConfig, time);
    defer connection_free(*sender);
    connection_init(*receiver, SingleBlockTestMessageFactory, connectionConfig, time);
    defer connection_free(*receiver);

    NumMessagesSent :: 32;

    for msgIndex: 0..NumMessagesSent-1 {
        message := cast(*TestBlockMessage) message_factory_create_message(SingleBlockTestMessageFactory, xx SINGLE_BLOCK_TEST_MESSAGE);

        assert(message.type == xx SINGLE_BLOCK_TEST_MESSAGE);

        assert_not_null(message);
        message.sequence = xx msgIndex;
        blockSize := 1 + ((msgIndex * 901) % 3333);
        blockData := NewArray(blockSize, u8);
        for * blockData {
            it.* = cast,no_check(u8) (msgIndex + it_index);
        }
        message.blockData = blockData;
        connection_send_message(*sender, 0, message);
    }

    senderSequence: u16;
    receiverSequence: u16;

    NumIterations :: 10000;
    numMessagesReceived := 0;

    for iter: 0..NumIterations-1 {
        pump_connection_update(connectionConfig, *time, *sender, *receiver, *senderSequence, *receiverSequence);

        while true {
            message := connection_receive_message(*receiver, 0);
            if message == null {
                break;
            }

            assert_equal(message.id, xx numMessagesReceived);
            assert_equal(message.type, xx SINGLE_BLOCK_TEST_MESSAGE);

            blockMessage := cast(*TestBlockMessage) message;
            assert_equal(blockMessage.sequence, xx numMessagesReceived);

            blockSize := blockMessage.blockData.count;
            assert_equal(blockSize, 1 + ((numMessagesReceived * 901) % 3333));

            assert_not_null(blockMessage.blockData.data);

            for blockMessage.blockData {
                assert_equal(it, cast,no_check(u8) (numMessagesReceived + it_index));
            }

            message_release(message);
            numMessagesReceived += 1;
        }

        if numMessagesReceived == NumMessagesSent {
            break;
        }
    }

    assert_equal(numMessagesReceived, NumMessagesSent);
}

test_single_message_type_unreliable :: () {
    sender: Connection;
    receiver: Connection;
    time := seconds_to_apollo(100);

    connectionConfig: ConnectionConfig;
    connectionConfig.numChannels = 1;
    connectionConfig.channel[0].type = .UnreliableUnordered;

    connection_init(*sender, SingleTestMessageFactory, connectionConfig, time);
    defer connection_free(*sender);
    connection_init(*receiver, SingleTestMessageFactory, connectionConfig, time);
    defer connection_free(*receiver);

    NumMessagesSent :: 16;

    for 0..NumMessagesSent-1 {
        message := cast(*TestMessage) message_factory_create_message(SingleTestMessageFactory, xx SINGLE_TEST_MESSAGE);
        assert_not_null(message);
        message.sequence = xx it;
        connection_send_message(*sender, 0, message);
    }

    senderSequence: u16;
    receiverSequence: u16;

    NumIterations :: 256;
    numMessagesReceived := 0;

    for 0..NumIterations-1 {
        pump_connection_update(connectionConfig, *time, *sender, *receiver, *senderSequence, *receiverSequence, APOLLO_100_MS, 0);

        while true {
            message := connection_receive_message(*receiver, 0);
            if message == null {
                break;
            }

            assert_equal(message.type, xx SINGLE_TEST_MESSAGE);

            testMessage := cast(*TestMessage) message;
            assert_equal(testMessage.sequence, xx numMessagesReceived);

            message_release(message);
            numMessagesReceived += 1;
        }

        if numMessagesReceived == NumMessagesSent {
            break;
        }
    }

    assert_equal(numMessagesReceived, NumMessagesSent);
}

send_client_to_server_messages_sample :: (client: *Client, numMessagesToSend: int, channelIndex := 0) {
    for 0..numMessagesToSend-1 {
        if !client_can_send_message(client, channelIndex) {
            break;
        }

        message := cast(*TestMessage) client_create_message(client, xx TEST_MESSAGE);
        assert_not_null(message);
        message.sequence = xx it;
        client_send_message(client, channelIndex, message);
    }
}

send_server_to_client_messages_sample :: (server: *Server, clientIndex: int, numMessagesToSend: int, channelIndex := 0) {
    for 0..numMessagesToSend-1 {
        if !server_can_send_message(server, clientIndex, channelIndex) {
            break;
        }

        message := cast(*TestMessage) server_create_message(server, clientIndex, xx TEST_MESSAGE);
        assert_not_null(message);
        message.sequence = xx it;
        server_send_message(server, clientIndex, channelIndex, message);
    }
}

process_server_to_client_messages_sample :: (client: *Client, numMessagesReceivedFromServer: *int) {
    while true {
        message := client_receive_message(client, 0);
        if message == null {
            break;
        }

        if cast(TestMessageType) message.type == {
            case TEST_MESSAGE;
                numMessagesReceivedFromServer += 1;
        }

        client_release_message(client, message);
    }
}

process_client_to_server_messages_sample :: (server: *Server, clientIndex: int, numMessagesReceivedFromClient: *int) {
    while true {
        message := server_receive_message(server, clientIndex, 0);
        if message == null {
            break;
        }

        if cast(TestMessageType) message.type == {
            case TEST_MESSAGE;
                assert_equal(message.blockData.count, 0);
                numMessagesReceivedFromClient += 1;
        }

        server_release_message(server, clientIndex, message);
    }
}

test_client_server_messages_network_sim_leak :: () {
    clientId: u64 = 1;

    clientAddress := address_init_v4("0.0.0.0", ClientPort);
    serverAddress := address_init_v4("127.0.0.1", ServerPort);

    time := seconds_to_apollo(100);

    config: ClientServerConfig;
    config.networkSimulator = true;
    config.channel[0].type = .UnreliableUnordered;

    client: Client;
    client_init(*client, clientAddress, config, TestMessageFactory, time);
    defer client_free(*client);

    privateKey: [KeyBytes] u8;

    server: Server;
    server_init(*server, privateKey, serverAddress, config, TestMessageFactory, time);
    defer server_free(*server);

    server_start(*server, MaxClients);

    network_simulator_set_latency(server.networkSimulator, 500);
    network_simulator_set_jitter(server.networkSimulator, 100);
    network_simulator_set_packet_loss(server.networkSimulator, 5.0);
    network_simulator_set_duplicates(server.networkSimulator, 5.0);

    clients := *Client.[ *client ];
    servers := *Server.[ *server ];

    for 0..1 {
        client_insecure_connect(*client, privateKey, clientId, serverAddress);

        network_simulator_set_latency(client.networkSimulator, 500);
        network_simulator_set_jitter(client.networkSimulator, 100);
        network_simulator_set_packet_loss(client.networkSimulator, 5.0);
        network_simulator_set_duplicates(client.networkSimulator, 5.0);

        NumIterations :: 10000;

        for 0..NumIterations-1 {
            pump_client_server_update(*time, clients, servers);

            if client_connection_failed(*client) {
                break;
            }

            if client_is_connected(*client) && server_get_num_connected_clients(*server) == 1 {
                break;
            }
        }

        assert_false(client_is_connecting(*client));
        assert_true(client_is_connected(*client));
        assert_equal(server_get_num_connected_clients(*server), 1);
        assert_equal(client_get_client_index(*client), 0);
        assert_true(server_is_client_connected(*server, 0));

        NumMessagesSent :: 2000;

        send_client_to_server_messages_sample(*client, NumMessagesSent);
        send_server_to_client_messages_sample(*server, client_get_client_index(*client), NumMessagesSent);

        numMessagesReceivedFromClient := 0;
        numMessagesReceivedFromServer := 0;

        for 0..99 {
            if !client_is_connected(*client) {
                break;
            }

            pump_client_server_update(*time, clients, servers);

            process_server_to_client_messages_sample(*client, *numMessagesReceivedFromServer);
            process_client_to_server_messages_sample(*server, client_get_client_index(*client), *numMessagesReceivedFromClient);
        }

        assert_true(client_is_connected(*client));
        assert_true(server_is_client_connected(*server, client_get_client_index(*client)));

        client_disconnect(*client);

        for 0..NumIterations-1 {
            pump_client_server_update(*time, clients, servers);

            if !client_is_connected(*client) && server_get_num_connected_clients(*server) == 0 {
                break;
            }
        }

        assert_false(client_is_connected(*client));
        assert_equal(server_get_num_connected_clients(*server), 0);
    }

    server_stop(*server);
}
