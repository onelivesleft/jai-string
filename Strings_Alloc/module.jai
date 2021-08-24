// All functions return allocated data, and take `allocator` + `allocator_data` optional parameters,
// (defaulting to using the allocator specified in the module parameters).


#module_parameters (
    // default allocator: null will use context.allocator
    default_allocator : Allocator = null,
    default_allocator_data : *void = null,

    // Adds `print`, `init_string_builder`, & `builder_to_string`set to behave the
    // same as every other allocated proc (i.e. if null use module allocator, which
    // if null uses the context allocator)
    add_convenience_functions := false,

    // Default compare function used to check for character equality.
    // Can be overridden with `set_default_compare`.
    //compare : enum { CASE_SENSITIVE; IGNORE_CASE; } = .CASE_SENSITIVE,

    // Index algorithm used to find instance of string in other string.
    // Can be overriden with `set_index_algorithm`
    //index_algorithm : enum { NAIVE; BOYER_MOORE; KNUTH_MORRIS_PRATT; } = .BOYER_MOORE,

    // When strict mode is enabled asserts will fail when indices fall outside
    // the range of the string.
    strict := false,

    // Provides some debug output
    debug := false
);




#load "Strings_Alloc.jai";
