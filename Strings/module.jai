#module_parameters (
    // Default compare function used to check for character equality.
    // Can be overridden with `set_default_compare`.
    compare : enum { CASE_SENSITIVE; IGNORE_CASE; } = .CASE_SENSITIVE,

    // Index algorithm used to find instance of string in other string.
    // Can be overriden with `set_index_algorithm`
    index_algorithm : enum {
        SUPER_SIMPLE;
        SIMPLE; SIMPLE_SSE2; SIMPLE_AVX2; SIMPLE_UNSAFE;
        BOYER_MOORE; BOYER_MOORE_SSE2; BOYER_MOORE_AVX2;
        KNUTH_MORRIS_PRATT; } = .BOYER_MOORE
);


#if compare == .CASE_SENSITIVE
    default_compare :: case_sensitive;
else #if compare == .IGNORE_CASE
    default_compare :: ignore_case;


#if index_algorithm == .SUPER_SIMPLE {
    default_first_index :: super_simple_first_index;
    default_last_index  :: super_simple_last_index;
}
else #if index_algorithm == .SIMPLE {
    default_first_index :: simple_first_index;
    default_last_index  :: simple_last_index;
}
else #if index_algorithm == .SIMPLE_SSE2 {
    default_first_index :: simple_sse2_first_index;
    default_last_index  :: simple_sse2_last_index;
}
else #if index_algorithm == .SIMPLE_AVX2 {
    default_first_index :: simple_avx2_first_index;
    default_last_index  :: simple_avx2_last_index;
}
else #if index_algorithm == .SIMPLE_UNSAFE {
    default_first_index :: unsafe_simple_first_index;
    default_last_index  :: unsafe_simple_last_index;
}
else #if index_algorithm == .BOYER_MOORE {
    #load "boyer_moore.jai";
    default_first_index :: boyer_moore_first_index;
    default_last_index  :: boyer_moore_last_index;
}
else #if index_algorithm == .BOYER_MOORE_SSE2 {
    #load "boyer_moore.jai";
    default_first_index :: boyer_moore_sse2_first_index;
    default_last_index  :: boyer_moore_sse2_last_index;
}
else #if index_algorithm == .BOYER_MOORE_AVX2 {
    #load "boyer_moore.jai";
    default_first_index :: boyer_moore_avx2_first_index;
    default_last_index  :: boyer_moore_avx2_last_index;
}
else #if index_algorithm == .KNUTH_MORRIS_PRATT {
    #load "knuth_morris_pratt.jai";
    default_first_index :: knuth_morris_pratt_first_index;
    default_last_index  :: knuth_morris_pratt_last_index;
}

#load "Strings.jai";
#load "indexing.jai";
#load "splitting.jai";
