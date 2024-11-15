#import "Basic"()(MEMORY_DEBUGGER=true);
#import "Random";
Math :: #import "Math";
#import "IPAddress"; //()(ENABLE_LOGGING=true);
#import "Yojimbo"()(ENABLE_LOGGING=true);
#import "Netcode"()(ENABLE_LOGGING=true);
#import "Reliable"()(ENABLE_LOGGING=true);
#import "Serialize";

ProtocolId :: cast(u64) 0x11223344556677;

ClientPort :: 30000;
ServerPort :: 40000;

GetNumBitsForMessage :: (sequence: u16) -> int {
    messageBitsArray :: int.[ 1, 320, 120, 4, 256, 45, 11, 13, 101, 100, 84, 95, 203, 2, 3, 8, 512, 5, 3, 7, 50 ];
    index := sequence % messageBitsArray.count;
    return messageBitsArray[index];
}

TestMessageType :: enum u16 {
    TEST_MESSAGE;
    TEST_BLOCK_MESSAGE;
    TEST_SERIALIZE_FAIL_ON_READ_MESSAGE;
    TEST_EXHAUST_STREAM_ALLOCATOR_ON_READ_MESSAGE;
    NUM_TEST_MESSAGE_TYPES;
}
using TestMessageType;

TestMessage :: struct {
    using #as base: Message;

    sequence: u16;

    serializer :: MessageSerializer.{
        create = () -> *Message {
            return New(TestMessage);
        },
        serialize = (stream: *Stream, message: *Message) -> bool {
            m := cast(*TestMessage) message;
            serialize_bits(stream, *m.sequence, 16);

            numBits := GetNumBitsForMessage(m.sequence);
            numWords := numBits / 32;
            dummy: u32;
            for 0..numWords-1 {
                serialize_bits(stream, *dummy, 32);
            }
            numRemainderBits := numBits - numWords * 32;
            if numRemainderBits > 0 {
                serialize_bits(stream, *dummy, numRemainderBits);
            }

            return true;
        }
    };
}

TestBlockMessage :: struct {
    using #as base: Message;

    sequence: u16;

    serializer :: MessageSerializer.{
        create = () -> *Message {
            return New(TestBlockMessage);
        },
        serialize = (stream: *Stream, message: *Message) -> bool {
            m := cast(*TestBlockMessage) message;
            serialize_bits(stream, *m.sequence, 16);
            return true;
        }
    };
}

TestSerializeFailOnReadMessage :: struct {
    using #as base: Message;

    serializer :: MessageSerializer.{
        create = () -> *Message {
            return New(TestSerializeFailOnReadMessage);
        },
        serialize = (stream: *Stream, message: *Message) -> bool {
            return !stream.isReading;
        }
    };
}

TestExhaustStreamAllocatorOnReadMessage :: struct {
    using #as base: Message;

    serializer :: MessageSerializer.{
        create = () -> *Message {
            return New(TestExhaustStreamAllocatorOnReadMessage);
        },
        serialize = (stream: *Stream, message: *Message) -> bool {
            if stream.isReading {
                buffers: [100] [] u8;

                for * buffers {
                    it.* = NewArray(1024 * 1024, u8);
                }

                for * buffers {
                    array_free(it.*);
                }
            }

            return true;
        }
    };
}

TestMessageFactory: MessageFactory : MessageSerializer.[
    TestMessage.serializer,
    TestBlockMessage.serializer,
    TestSerializeFailOnReadMessage.serializer,
    TestExhaustStreamAllocatorOnReadMessage.serializer
];

SingleTestMessageType :: enum u16 {
    SINGLE_TEST_MESSAGE;
    NUM_SINGLE_TEST_MESSAGE_TYPES;
}
using SingleTestMessageType;

SingleTestMessageFactory: MessageFactory : MessageSerializer.[
    TestMessage.serializer
];

SingleBlockTestMessageType :: enum u16 {
    SINGLE_BLOCK_TEST_MESSAGE;
    NUM_SINGLE_BLOCK_TEST_MESSAGE_TYPES;
}
using SingleBlockTestMessageType;

SingleBlockTestMessageFactory: MessageFactory : MessageSerializer.[
    TestBlockMessage.serializer
];

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