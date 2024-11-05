/*
Native port of Glenn Fielder's yojimbo library, as of this commit:
https://github.com/mas-bandwidth/yojimbo/commit/c6c02dfec105b36b9cbefd82f86f11f894f6de51

------------------------------------------------------------------------------------------------------------------------
| Original BSD-3 license
------------------------------------------------------------------------------------------------------------------------
    Yojimbo Client/Server Network Library.

    Copyright © 2016 - 2024, Mas Bandwidth LLC.

    Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

        1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

        2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer
        in the documentation and/or other materials provided with the distribution.

        3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived
        from this software without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
    INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
    SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
    SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
    WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
    USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
---------------------------------------------------------------------------------------------------------------------
*/

#module_parameters () (ENABLE_LOGGING := false);

YOJIMBO_MAJOR_VERSION :: 1;
YOJIMBO_MINOR_VERSION :: 0;
YOJIMBO_PATCH_VERSION :: 0;

/**
Initialize the yojimbo library.
Call this before calling any yojimbo library functions.
@returns True if the library was successfully initialized, false otherwise.
*/
yojimbo_init :: () -> bool {
    if netcode_init() != NETCODE_OK {
        return false;
    }

    // Not using this, it was empty
    //if ( reliable_init() != RELIABLE_OK )
    //    return false;

    return true;
}

/*
Shutdown the yojimbo library.
*/
yojimbo_shutdown :: () {
    // Not using this, it was empty
    //reliable_term();
    netcode_term();
}

#scope_module

#import "Basic";
Math :: #import "Math";
#import "Assertive";
#import "IPAddress";
#import "Reliable";
#import "Netcode";
#import "Trivial";

#load "base_client.jai";
#load "base_server.jai";
#load "channel.jai";
#load "channel_packet_data.jai";
#load "client.jai";
#load "config.jai";
#load "connection.jai";
#load "constants.jai";
#load "message.jai";
#load "network_info.jai";
#load "network_simulator.jai";
#load "queue.jai";
#load "reliable_ordered_channel.jai";
#load "sequence_buffer.jai";
#load "server.jai";
#load "unreliable_unordered_channel.jai";
#load "utils.jai";

yojimbo_log :: (flags: Log_Flags, format_string: string, args: .. Any, loc := #caller_location) {
    #if ENABLE_LOGGING {
        log(format_string, ..args, loc, flags,, temp);
    }
}
