MaxClients                     :: 64;    // The maximum number of clients supported by this library. You can increase this if you want, but this library is designed around patterns that work best for [2,64] player games. If your game has less than 64 clients, reducing this will save memory.
MaxChannels                    :: 64;    // The maximum number of message channels supported by this library. If you need less than 64 channels per-packet, reducing this will save memory.
KeyBytes                       :: 32;    // Size of encryption key for dedicated client/server in bytes. Must be equal to key size for libsodium encryption primitive. Do not change.
ConnectTokenBytes              :: 2048;  // Size of the encrypted connect token data return from the matchmaker. Must equal size of NETCODE_CONNECT_TOKEN_BYTE (2048).
ConservativeMessageHeaderBits  :: 32;    // Conservative number of bits per-message header.
ConservativeFragmentHeaderBits :: 64;    // Conservative number of bits per-fragment header.
ConservativeChannelHeaderBits  :: 32;    // Conservative number of bits per-channel header.
ConservativePacketHeaderBits   :: 16;    // Conservative number of bits per-packet header.
MaxAddressLength               :: 256;   // The maximum length of an address when converted to a string (includes terminating NULL). @see Address::ToString
