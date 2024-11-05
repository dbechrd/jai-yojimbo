/*
Generate a random integer between a and b (inclusive).
IMPORTANT: This is not a cryptographically secure random. It's used only for test functions and in the network simulator.
@param a The minimum integer value to generate.
@param b The maximum integer value to generate.
@returns A pseudo random integer value in [a,b].
*/
yojimbo_random_int :: inline (a: int, b: int) -> int {
    assert(a < b);
    result := a + cast(int) (random_get() % cast(u64)(b - a + 1));
    assert(result >= a);
    assert(result <= b);
    return result;
}

/*
Generate a random float between a and b.
IMPORTANT: This is not a cryptographically secure random. It's used only for test functions and in the network simulator.
@param a The minimum integer value to generate.
@param b The maximum integer value to generate.
@returns A pseudo random float value in [a,b].
*/
yojimbo_random_float :: inline (a: float, b: float) -> float {
    assert(a < b);
    result := a + random_get_zero_to_one() * (b - a);
    assert(result >= a);
    assert(result <= b);
    return result;
}

/*
Compares two 16 bit sequence numbers and returns true if the first one is greater than the second (considering wrapping).
IMPORTANT: This is not the same as s1 > s2!
Greater than is defined specially to handle wrapping sequence numbers.
If the two sequence numbers are close together, it is as normal, but they are far apart, it is assumed that they have wrapped around.
Thus, sequence_greater_than( 1, 0 ) returns true, and so does sequence_greater_than( 0, 65535 )!
@param s1 The first sequence number.
@param s2 The second sequence number.
@returns True if the s1 is greater than s2, with sequence number wrapping considered.
*/
yojimbo_sequence_greater_than :: inline (s1: u16, s2: u16) -> bool {
    return ((s1 > s2) && (s1 - s2 <= 32768)) ||
           ((s1 < s2) && (s2 - s1  > 32768));
}

/*
Compares two 16 bit sequence numbers and returns true if the first one is less than the second (considering wrapping).
IMPORTANT: This is not the same as s1 < s2!
Greater than is defined specially to handle wrapping sequence numbers.
If the two sequence numbers are close together, it is as normal, but they are far apart, it is assumed that they have wrapped around.
Thus, sequence_less_than( 0, 1 ) returns true, and so does sequence_greater_than( 65535, 0 )!
@param s1 The first sequence number.
@param s2 The second sequence number.
@returns True if the s1 is less than s2, with sequence number wrapping considered.
*/
yojimbo_sequence_less_than :: inline (s1: u16, s2: u16) -> bool {
    return yojimbo_sequence_greater_than(s2, s1);
}

#scope_file

#import "Random";