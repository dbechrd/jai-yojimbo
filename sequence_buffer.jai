/*
Data structure that stores data indexed by sequence number.
Entries may or may not exist. If they don't exist the sequence value for the entry at that index is set to 0xFFFFFFFF.
This provides a constant time lookup for an entry by sequence number. If the entry at sequence modulo buffer size doesn't have the same sequence number, that sequence number is not stored.
This is used as the foundation of the packet level ack system and the reliable message send and receive queues.
@see Connection
*/
SequenceBuffer :: struct ($T: Type) {
    nextSequence  : u16;        // The next sequence number we expect to be inserted.
    entryValid    : Bit_Array;  // Occupation bitset for each entry. 0 = free, 1 = in use
    entrySequence : [] u16;     // Array of sequence numbers corresponding to each sequence buffer entry for fast lookup.
    entryData     : [] T;       // The sequence buffer entries. This is where the data is stored per-entry. Separate from the sequence numbers for fast lookup (hot/cold split) when the data per-sequence number is relatively large.
}

/*
Sequence buffer constructor.
@param size The size of the sequence buffer.
*/
sequence_buffer_init :: (using sequenceBuffer: *SequenceBuffer, capacity: int) {
    assert(capacity > 0);

    init_bit_array(*entryValid, capacity);
    entrySequence = NewArray(capacity, u16);
    entryData = NewArray(capacity, sequenceBuffer.T);
    sequence_buffer_reset(sequenceBuffer);
}

/*
Sequence buffer destructor.
*/
sequence_buffer_free :: (using sequenceBuffer: *SequenceBuffer) {
    deinit(*entryValid);
    array_free(entrySequence);
    array_free(entryData);
}

/*
Reset the sequence buffer.
Removes all entries from the sequence buffer and restores it to initial state.
*/
sequence_buffer_reset :: (using sequenceBuffer: *SequenceBuffer) {
    clear_all_bits(*entryValid);
    nextSequence = 0;
}

/*
Insert an entry in the sequence buffer.
IMPORTANT: If another entry exists at the sequence modulo buffer size, it is overwritten.
@param sequence The sequence number.
@param guaranteedOrder Whether sequence is always the newest value (when sending) or can be out of order (when receiving).
@returns The sequence buffer entry, which you must fill with your data. NULL if a sequence buffer entry could not be added for your sequence number (if the sequence number is too old for example).
*/
sequence_buffer_insert :: (using sequenceBuffer: *SequenceBuffer, sequence: u16, guaranteedOrder: bool = false) -> *sequenceBuffer.T {
    if guaranteedOrder || yojimbo_sequence_greater_than(sequence + 1, nextSequence) {
        sequence_buffer_remove_entries(sequenceBuffer, nextSequence, sequence);
        nextSequence = sequence + 1;
    } else if yojimbo_sequence_less_than(sequence, nextSequence - cast(u16) entrySequence.count) {
        return null;
    }

    index := sequence % entryValid.count;
    entryValid[index] = true;
    entrySequence[index] = sequence;
    return *entryData[index];
}

/*
Remove an entry from the sequence buffer.
@param sequence The sequence number of the entry to remove.
*/
sequence_buffer_remove :: (using sequenceBuffer: *SequenceBuffer, sequence: u16) {
    index := sequence % entryValid.count;
    entryValid[index] = false;
    entrySequence[index] = 0;
    //entryData[index] = sequenceBuffer.T.{};
}

/*
Is the entry corresponding to the sequence number available? eg. Currently unoccupied.
This works because older entries are automatically set back to unoccupied state as the sequence buffer advances forward.
@param sequence The sequence number.
@returns True if the sequence buffer entry is available, false if it is already occupied.
*/
sequence_buffer_available :: (using sequenceBuffer: *SequenceBuffer, sequence: u16) -> bool {
    index := sequence % entryValid.count;
    return !entryValid[index];
}

/*
Does an entry exist for a sequence number?
@param sequence The sequence number.
@returns True if an entry exists for this sequence number.
*/
sequence_buffer_exists :: (using sequenceBuffer: *SequenceBuffer, sequence: u16) -> bool {
    index := sequence % entryValid.count;
    return entryValid[index] && entrySequence[index] == sequence;
}

/*
Get the entry corresponding to a sequence number.
@param sequence The sequence number.
@returns The entry if it exists. NULL if no entry is in the buffer for this sequence number.
*/
sequence_buffer_find :: (using sequenceBuffer: *SequenceBuffer, sequence: u16) -> *sequenceBuffer.T {
    index := sequence % entryValid.count;
    if entryValid[index] && entrySequence[index] == sequence {
        return *entryData[index];
    } else {
        return null;
    }
}

/*
Get the entry at the specified index.
Use this to iterate across entries in the sequence buffer.
@param index The entry index in [0,GetSize()-1].
@returns The entry if it exists. NULL if no entry is in the buffer at the specified index.
*/
sequence_buffer_get_at_index :: (using sequenceBuffer: *SequenceBuffer, index: int) -> *sequenceBuffer.T {
    assert(index >= 0);
    assert(index < entryValid.count);

    return ifx entryValid[index] then *entryData[index] else null;
}

/*
Get the most recent sequence number added to the buffer.
This sequence number can wrap around, so if you are at 65535 and add an entry for sequence 0, then 0 becomes the new "most recent" sequence number.
@returns The most recent sequence number.
@see yojimbo::sequence_greater_than
@see yojimbo::sequence_less_than
*/
sequence_buffer_get_next_sequence :: (using sequenceBuffer: *SequenceBuffer) -> u16 {
    return nextSequence;
}

/*
Get the entry index for a sequence number.
This is simply the sequence number modulo the sequence buffer size.
@param sequence The sequence number.
@returns The sequence buffer index corresponding of the sequence number.
*/
sequence_buffer_get_index :: (using sequenceBuffer: *SequenceBuffer, sequence: u16) -> int {
    return sequence % entryValid.count;
}

/*
Get the capacity of the sequence buffer.
@returns The capacity of the sequence buffer (number of entries).
*/
sequence_buffer_get_capacity :: (using sequenceBuffer: *SequenceBuffer) -> int {
    return entryValid.count;
}

#scope_file

/*
Helper function to remove entries.
@param sequenceStart The first sequence number to remove.
@param sequenceEnd The last sequence number to remove (inclusive).
This is used to remove old entries as we advance the sequence buffer forward.
Otherwise, if when entries are added with holes (eg. receive buffer for packets or messages, where not all sequence numbers are added to the buffer because we have high packet loss),
and we are extremely unlucky, we can have old sequence buffer entries from the previous sequence # wrap around still in the buffer, which corrupts our internal connection state.
This actually happened in the soak test at high packet loss levels (>90%). It took me days to track it down :)
*/
sequence_buffer_remove_entries :: (using sequenceBuffer: *SequenceBuffer, sequenceStart: int, sequenceEnd: int) {
    if sequenceEnd < sequenceStart {
        sequenceEnd += 65535;
    }
    assert(sequenceEnd >= sequenceStart);

    if sequenceEnd - sequenceStart < entryValid.count {
        for sequenceStart..sequenceEnd {
            entryValid[it % entryValid.count] = false;
        }
    } else {
        sequence_buffer_reset(sequenceBuffer);
    }
}