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
}
using TestMessageType;

TestMessage :: struct {
    using #as base: Message;

    sequence: u16;

    serialize :: (stream: *Stream, message: *Message) -> bool {
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
}

TestBlockMessage :: struct {
    using #as base: Message;

    sequence: u16;

    serialize :: (stream: *Stream, message: *Message) -> bool {
        m := cast(*TestBlockMessage) message;
        serialize_bits(stream, *m.sequence, 16);
        return true;
    }
}

TestSerializeFailOnReadMessage :: struct {
    using #as base: Message;

    serialize :: (stream: *Stream, message: *Message) -> bool {
        return !stream.isReading;
    }
}

TestExhaustStreamAllocatorOnReadMessage :: struct {
    using #as base: Message;

    serialize :: (stream: *Stream, message: *Message) -> bool {
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
}

TestMessageFactory :: MessageFactory.{
    max_message_type = #run enum_highest_value(TestMessageType),
    create = (messageType: u16) -> *Message {
        type := messageType.(TestMessageType);
        if type == {
            case .TEST_MESSAGE;                                  return New(TestMessage);
            case .TEST_BLOCK_MESSAGE;                            return New(TestBlockMessage);
            case .TEST_SERIALIZE_FAIL_ON_READ_MESSAGE;           return New(TestSerializeFailOnReadMessage);
            case .TEST_EXHAUST_STREAM_ALLOCATOR_ON_READ_MESSAGE; return New(TestExhaustStreamAllocatorOnReadMessage);
        }
        return null;
    },
    serialize = (stream: *Stream, message: *Message) -> bool {
        type := message.type.(TestMessageType);
        if type == {
            case .TEST_MESSAGE;                                  return TestMessage.serialize(stream, message);
            case .TEST_BLOCK_MESSAGE;                            return TestBlockMessage.serialize(stream, message);
            case .TEST_SERIALIZE_FAIL_ON_READ_MESSAGE;           return TestSerializeFailOnReadMessage.serialize(stream, message);
            case .TEST_EXHAUST_STREAM_ALLOCATOR_ON_READ_MESSAGE; return TestExhaustStreamAllocatorOnReadMessage.serialize(stream, message);
        }
        return false;
    }
};

SingleTestMessageType :: enum u16 {
    SINGLE_TEST_MESSAGE;
}
using SingleTestMessageType;

SingleTestMessageFactory :: MessageFactory.{
    max_message_type = #run enum_highest_value(SingleTestMessageType),
    create = (messageType: u16) -> *Message {
        type := messageType.(SingleTestMessageType);
        if type == {
            case .SINGLE_TEST_MESSAGE; return New(TestMessage);
        }
        return null;
    },
    serialize = (stream: *Stream, message: *Message) -> bool {
        type := message.type.(SingleTestMessageType);
        if type == {
            case .SINGLE_TEST_MESSAGE; return TestMessage.serialize(stream, message);
        }
        return false;
    }
};

SingleBlockTestMessageType :: enum u16 {
    SINGLE_BLOCK_TEST_MESSAGE;
}
using SingleBlockTestMessageType;

SingleBlockTestMessageFactory :: MessageFactory.{
    max_message_type = #run enum_highest_value(SingleBlockTestMessageType),
    create = (messageType: u16) -> *Message {
        type := messageType.(SingleBlockTestMessageType);
        if type == {
            case .SINGLE_BLOCK_TEST_MESSAGE; return New(TestBlockMessage);
        }
        return null;
    },
    serialize = (stream: *Stream, message: *Message) -> bool {
        type := message.type.(SingleBlockTestMessageType);
        if type == {
            case .SINGLE_BLOCK_TEST_MESSAGE; return TestBlockMessage.serialize(stream, message);
        }
        return false;
    }
};

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