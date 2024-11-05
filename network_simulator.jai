/*
Simulates packet loss, latency, jitter and duplicate packets.
This is useful during development, so your game is tested and played under real world conditions, instead of ideal LAN conditions.
This simulator works on packet send. This means that if you want 125ms of latency (round trip), you must to add 125/2 = 62.5ms of latency to each side.
*/
NetworkSimulator :: struct {
    latency       : Apollo_Time;  // Latency in milliseconds
    jitter        : Apollo_Time;  // Jitter in milliseconds +/-
    packetLossPct : float;        // Packet loss percentage.
    duplicatePct  : float;        // Duplicate packet percentage
    active        : bool;         // True if network simulator is active, eg. if any of the network settings above are enabled.
    time          : Apollo_Time;  // Current time from last call to advance time.

    // A packet buffered in the network simulator.
    PacketEntry :: struct {
        to           : int;          // To index this packet should be sent to (for server -> client packets).
        deliveryTime : Apollo_Time;  // Delivery time for this packet (seconds).
        packetData   : [] u8;        // Packet data (owns this pointer).
    };

    currentIndex  : int;             // Current index in the packet entry array. New packets are inserted here.
    packetEntries : [] PacketEntry;  // Pointer to dynamically allocated packet entries. This is where buffered packets are stored.
}

/*
Create a network simulator.
Initial network conditions are set to:
Latency: 0ms
Jitter: 0ms
Packet Loss: 0%
Duplicates: 0%
@param allocator The allocator to use.
@param numPackets The maximum number of packets that can be stored in the simulator at any time.
@param time The initial time value in seconds.
*/
network_simulator_init :: (using networkSimulator: *NetworkSimulator, numPackets: int, _time: Apollo_Time) {
    assert(numPackets > 0);

    packetEntries = NewArray(numPackets, PacketEntry);
    time = _time;
}

/*
Network simulator destructor.
Any packet data still in the network simulator is destroyed.
*/
network_simulator_free :: (using networkSimulator: *NetworkSimulator) {
    network_simulator_discard_packets(networkSimulator);
    array_free(packetEntries);
}

/*
Set the latency in milliseconds.
This latency is added on packet send. To simulate a round trip time of 100ms, add 50ms of latency to both sides of the connection.
@param milliseconds The latency to add in milliseconds.
*/
network_simulator_set_latency :: (using networkSimulator: *NetworkSimulator, milliseconds: int) {
    latency = milliseconds_to_apollo(milliseconds);
    network_simulator_update_active(networkSimulator);
}

/*
Set the packet jitter in milliseconds.
Jitter is applied +/- this amount in milliseconds. To be truly effective, jitter must be applied together with some latency.
@param milliseconds The amount of jitter to add in milliseconds (+/-).
*/
network_simulator_set_jitter :: (using networkSimulator: *NetworkSimulator, milliseconds: int) {
    jitter = milliseconds_to_apollo(milliseconds);
    network_simulator_update_active(networkSimulator);
}

/*
Set the amount of packet loss to apply on send.
@param percent The packet loss percentage. 0% = no packet loss. 100% = all packets are dropped.
*/
network_simulator_set_packet_loss :: (using networkSimulator: *NetworkSimulator, percent: float) {
    packetLossPct = percent;
    network_simulator_update_active(networkSimulator);
}

/*
Set percentage chance of packet duplicates.
If the duplicate chance succeeds, a duplicate packet is added to the queue with a random delay of up to 1 second.
@param percent The percentage chance of a packet duplicate being sent. 0% = no duplicate packets. 100% = all packets have a duplicate sent.
*/
network_simulator_set_duplicates :: (using networkSimulator: *NetworkSimulator, percent: float) {
    duplicatePct = percent;
    network_simulator_update_active(networkSimulator);
}

/*
Is the network simulator active?
The network simulator is active when packet loss, latency, duplicates or jitter are non-zero values.
This is used by the transport to know whether it should shunt packets through the simulator, or send them directly to the network. This is a minor optimization.
*/
network_simulator_is_active :: inline (using networkSimulator: *NetworkSimulator) -> bool {
    return active;
}

/*
Queue a packet to send.
IMPORTANT: Ownership of the packet data pointer is *not* transferred to the network simulator. It makes a copy of the data instead.
@param to The slot index the packet should be sent to.
@param packetData The packet data.
@param packetBytes The packet size (bytes).
*/
network_simulator_send_packet :: (using networkSimulator: *NetworkSimulator, to: int, packetData: [] u8) {
    assert(packetData.count > 0);

    if yojimbo_random_float(0.0, 100.0) <= packetLossPct {
        return;
    }

    packetEntry := *packetEntries[currentIndex];

    if packetEntry.packetData.count > 0 {
        array_free(packetEntry.packetData);
        packetEntry.* = .{};
    }

    #if 0 {
        delay := latency;
        if jitter > .{} {
            mult := yojimbo_random_float(-1.0, 1.0);
            rand_jitter := milliseconds_to_apollo(cast(int) (to_milliseconds(jitter) * mult));
            delay += rand_jitter;
        }

        packetEntry.to = to;
        packetEntry.deliveryTime = time + delay;
        packetEntry.packetData = array_copy(packetData);
        currentIndex = (currentIndex + 1) % packetEntries.count;

        if yojimbo_random_float(0.0, 100.0) <= duplicatePct {
            dupe_delay := milliseconds_to_apollo(yojimbo_random_int(0, 1000));
            nextPacketEntry := *packetEntries[currentIndex];
            nextPacketEntry.to = to;
            nextPacketEntry.deliveryTime = time + delay + dupe_delay;
            nextPacketEntry.packetData = array_copy(packetData);
            currentIndex = (currentIndex + 1) % packetEntries.count;
        }
    } else {
        packetEntry.to = to;
        packetEntry.deliveryTime = time;
        packetEntry.packetData = array_copy(packetData);
        currentIndex = (currentIndex + 1) % packetEntries.count;
    }
}

/*
Receive packets sent to any address.
IMPORTANT: You take ownership of the packet data you receive and are responsible for freeing it. See NetworkSimulator::GetAllocator.
@param maxPackets The maximum number of packets to receive.
@param packetData Array of packet data pointers to be filled [out].
@param to Array of to indices to be filled [out].
@returns The number of packets received.
*/
network_simulator_receive_packets :: (using networkSimulator: *NetworkSimulator, packetData: [][] u8, to: [] int) -> int {
    assert(packetData.count > 0);
    assert(to.count == 0 || to.count == packetData.count);

    if !network_simulator_is_active(networkSimulator) {
        return 0;
    }

    numPackets := 0;

    for * packetEntries {
        if it.packetData.count == 0 {
            continue;
        }

        if it.deliveryTime < time {
            packetData[numPackets] = it.packetData;
            if to.count > 0 {
                to[numPackets] = it.to;
            }
            it.* = .{};
            numPackets += 1;
        }
    }

    return numPackets;
}

/*
Discard all packets in the network simulator.
This is useful if the simulator needs to be reset and used for another purpose.
*/
network_simulator_discard_packets :: (using networkSimulator: *NetworkSimulator) {
    array_zero(packetEntries);
}

/*
Discard packets sent to a particular client index.
This is called when a client disconnects from the server.
*/
network_simulator_discard_client_packets :: (using networkSimulator: *NetworkSimulator, clientIndex: int) {
    for * packetEntries {
        if (it.packetData.count == 0 || it.to != clientIndex) {
            continue;
        }
        it.* = .{};
    }
}

/*
Advance network simulator time.
You must pump this regularly otherwise the network simulator won't work.
@param time The current time value. Please make sure you use double values for time so you retain sufficient precision as time increases.
*/
network_simulator_advance_time :: (using networkSimulator: *NetworkSimulator, _time: Apollo_Time) {
    time = _time;
}

#scope_file

/*
Helper function to update the active flag whenever network settings are changed.
Active is set to true if any of the network conditions are non-zero. This allows you to quickly check if the network simulator is active and would actually do something.
*/
network_simulator_update_active :: (using networkSimulator: *NetworkSimulator) {
    wasActive := active;
    active = latency != .{} || jitter != .{} || packetLossPct != 0.0 || duplicatePct != 0.0;
    if !active && wasActive {
        network_simulator_discard_packets(networkSimulator);
    }
}