#scope_module

/*
Network information for a connection.
Contains statistics like round trip time (RTT), packet loss %, bandwidth estimates, number of packets sent, received and acked.
*/
NetworkInfo :: struct {
    numPacketsSent     : u64;    // Number of packets sent.
    numPacketsReceived : u64;    // Number of packets received.
    numPacketsAcked    : u64;    // Number of packets acked.
    RTT                : float;  // Round trip time estimate (milliseconds).
    packetLoss         : float;  // Packet loss percent.
    sentBandwidth      : float;  // Sent bandwidth (kbps).
    receivedBandwidth  : float;  // Received bandwidth (kbps).
    ackedBandwidth     : float;  // Acked bandwidth (kbps).
};
