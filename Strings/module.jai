#module_parameters (
    // Default compare function used to check for character equality.
    CHARACTER_COMPARE : enum { CASE_SENSITIVE; IGNORE_CASE; } = .CASE_SENSITIVE,

    // Index algorithm used to find instance of string in other string.
    // Can be overriden with `set_index_algorithm`
    INDEX_ALGORITHM : enum {
        SUPER_SIMPLE;
        SIMPLE; SIMPLE_SSE2; SIMPLE_AVX2; SIMPLE_UNSAFE;
        BOYER_MOORE; BOYER_MOORE_SSE2; BOYER_MOORE_AVX2;
        KNUTH_MORRIS_PRATT;
    } = .BOYER_MOORE
);


#if CHARACTER_COMPARE == .CASE_SENSITIVE
    default_character_compare :: case_sensitive;
else #if CHARACTER_COMPARE == .IGNORE_CASE
    default_character_compare :: ignore_case;


#if INDEX_ALGORITHM == .SUPER_SIMPLE {
    default_first_index :: super_simple_first_index;
    default_last_index  :: super_simple_last_index;
}
else #if INDEX_ALGORITHM == .SIMPLE {
    default_first_index :: simple_first_index;
    default_last_index  :: simple_last_index;
}
else #if INDEX_ALGORITHM == .SIMPLE_SSE2 {
    default_first_index :: simple_sse2_first_index;
    default_last_index  :: simple_sse2_last_index;
}
else #if INDEX_ALGORITHM == .SIMPLE_AVX2 {
    default_first_index :: simple_avx2_first_index;
    default_last_index  :: simple_avx2_last_index;
}
else #if INDEX_ALGORITHM == .SIMPLE_UNSAFE {
    default_first_index :: unsafe_simple_first_index;
    default_last_index  :: unsafe_simple_last_index;
}
else #if INDEX_ALGORITHM == .BOYER_MOORE {
    default_first_index :: boyer_moore_first_index;
    default_last_index  :: boyer_moore_last_index;
}
else #if INDEX_ALGORITHM == .BOYER_MOORE_SSE2 {
    default_first_index :: boyer_moore_sse2_first_index;
    default_last_index  :: boyer_moore_sse2_last_index;
}
else #if INDEX_ALGORITHM == .BOYER_MOORE_AVX2 {
    default_first_index :: boyer_moore_avx2_first_index;
    default_last_index  :: boyer_moore_avx2_last_index;
}
else #if INDEX_ALGORITHM == .KNUTH_MORRIS_PRATT {
    default_first_index :: knuth_morris_pratt_first_index;
    default_last_index  :: knuth_morris_pratt_last_index;
}

#load "Strings.jai";
#load "indexing.jai";
#load "splitting.jai";
#load "boyer_moore.jai";
#load "knuth_morris_pratt.jai";
