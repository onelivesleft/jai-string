// All functions return allocated data, and take `allocator` + `allocator_data` optional parameters,
// (defaulting to using the allocator specified in the module parameters).

// Recommended use is to import this module into a namespace, named after the allocator used. i.e.
// heap :: #import "Strings_Alloc";
// temp :: #import "Strings_Alloc"(__temporary_allocator);


#module_parameters (
    // Default allocator: null will use `context.allocator`
    default_allocator : Allocator = null,
    default_allocator_data : *void = null,

    // Adds `print` and `builder_to_string`set to behave the
    // same as every other allocated proc (i.e. if null use module allocator, which
    // if null uses the context allocator)
    add_convenience_functions := false,

    // Default compare function used to check for character equality.
    // Can be overridden with `set_default_compare`.
    compare : enum { CASE_SENSITIVE; IGNORE_CASE; } = .CASE_SENSITIVE,

    // Index algorithm used to find instance of string in other string.
    // Can be overriden with `set_index_algorithm`
    index_algorithm : enum {
        SIMPLE; SIMPLE_SSE; SIMPLE_AVX2;
        BOYER_MOORE; BOYER_MOORE_SSE; BOYER_MOORE_AVX2;
        KNUTH_MORRIS_PRATT; } = .BOYER_MOORE,

    // When strict mode is enabled asserts will fail when indices fall outside
    // the range of the string.
    strict := false
);


#if compare == .CASE_SENSITIVE
    default_compare :: case_sensitive;
else #if compare == .IGNORE_CASE
    default_compare :: ignore_case;


#if index_algorithm      == .SIMPLE {
    default_first_index :: simple_first_index;
    default_last_index  :: simple_last_index;
}
else #if index_algorithm == .SIMPLE_SSE {
    default_first_index :: simple_sse_first_index;
    default_last_index  :: simple_sse_last_index;
}
else #if index_algorithm == .SIMPLE_AVX2 {
    default_first_index :: simple_avx2_first_index;
    default_last_index  :: simple_avx2_last_index;
}
else #if index_algorithm == .BOYER_MOORE {
    default_first_index :: boyer_moore_first_index;
    default_last_index  :: boyer_moore_last_index;
}
else #if index_algorithm == .BOYER_MOORE_SSE {
    default_first_index :: boyer_moore_sse_first_index;
    default_last_index  :: boyer_moore_sse_last_index;
}
else #if index_algorithm == .BOYER_MOORE_AVX2 {
    default_first_index :: boyer_moore_avx2_first_index;
    default_last_index  :: boyer_moore_avx2_last_index;
}
else #if index_algorithm == .KNUTH_MORRIS_PRATT {
    default_first_index :: knuth_morris_pratt_first_index;
    default_last_index  :: knuth_morris_pratt_last_index;
}



#load "Strings_Alloc.jai";
