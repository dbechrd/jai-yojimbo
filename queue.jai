/*
A simple queue.
This is a FIFO queue. First entry in, first entry out.
*/
Queue :: struct ($T: Type) {
    entries    : [] T;  // Array of entries backing the queue (circular buffer).
    startIndex : int;   // The start index for the queue. This is the next value that gets popped off.
    count      : int;   // The number of entries currently stored in the queue.
};

/*
Queue constructor.
@param capacity The maximum number of entries in the queue.
*/
queue_init :: (using queue: *Queue, capacity: int) {
    assert(capacity > 0);

    entries = NewArray(capacity, queue.T);
}

/*
Queue destructor.
*/
queue_free :: (using queue: *Queue) {
    array_free(entries);
}

/*
Get the size of the queue.
This is the maximum number of values that can be pushed on the queue.
@returns The size of the queue.
*/
queue_capacity :: inline (using queue: Queue) -> int {
    return entries.count;
}

/*
Is the queue currently empty?
@returns True if there are no entries in the queue.
*/
queue_empty :: inline (using queue: Queue) -> bool {
    return count == 0;
}

/*
Is the queue currently full?
@returns True if the queue is full. False otherwise.
*/
queue_full :: inline (using queue: Queue) -> bool {
    return count == entries.count;
}

/*
Push a value on to the queue.
@param value The value to push onto the queue.
IMPORTANT: Will assert if the queue is already full. Check queue_full before calling this!
*/
queue_push :: (using queue: *Queue, value: queue.T) {
    assert(count < entries.count);

    index := (startIndex + count) % entries.count;
    entries[index] = value;
    count += 1;
}

/*
Random access for entries in the queue.
@param index The index into the queue. 0 is the oldest entry, queue.count - 1 is the newest.
@returns The value in the queue at the index.
*/
operator [] :: (using queue: Queue, index: int) -> queue.T {
    assert(index >= 0);
    assert(index < entries.count);

    return entries[(startIndex + index) % entries.count];
}

/*
Pop a value off the queue.
IMPORTANT: This will assert if the queue is empty. Check queue_empty or queue.count first!
@returns The value popped off the queue.
*/
queue_pop :: (using queue: *Queue) -> queue.T {
    assert(count > 0);

    entry := entries[startIndex];
    startIndex = (startIndex + 1) % entries.count;
    count -= 1;
    return entry;
}

/*
Clear all entries in the queue and reset back to default state.
*/
queue_clear :: inline (using queue: *Queue) {
    startIndex = 0;
    count = 0;
}

queue_print :: (using queue: Queue) {
    builder: String_Builder;
    append(*builder, "[");
    for 0..count-1 {
        index := (startIndex + it) % entries.count;
        print_item_to_builder(*builder, entries[index]);
        if it < count-1 {
            append(*builder, ", ");
        }
    }
    append(*builder, "]");
    print("%\n", builder_to_string(*builder));
}

#scope_file

#import "Basic";