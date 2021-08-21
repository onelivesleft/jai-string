// All functions return allocated data, and take `allocator` + `allocator_data` optional parameters,
// (defaulting to using the allocator specified in the module parameters).


#module_parameters (
    default_allocator : Allocator = null,             // default allocator: null will use context.allocator
    default_allocator_data : *void = null,

    //default_compare_proc := strings.case_sensitive,   // default compare function used when matching strings
    //                                                  // other provided option is `ignore_case`
    //default_first_index := strings.boyer_moore_first_index,   // default proc to find first index of substring in string
    //default_last_index  := strings.boyer_moore_last_index,    // default proc to find last index of substring in string

    add_convenience_functions := false,               // Adds `print`, `init_string_builder`, & `builder_to_string`
                                                      // set to behave the same as every other allocated proc
                                                      // (i.e. if null use module allocator, which if null uses context
                                                      //  allocator)

    strict := false,                                  // Asserts when indices fall outside the range of the string

    debug := false                                    // Provides some debug output
);




#load "Strings_Alloc.jai";
