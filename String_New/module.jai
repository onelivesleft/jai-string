// Every proc in this module allocates, so every proc should take an `allocator` parameter!
// as well as an `allocator_data` parameter.


#module_parameters (
    default_allocator : Allocator = null,
    default_allocator_data : *void = null,
    default_compare := case_sensitive,
    add_convenience_functions  := false,
    strict := false,                         // Asserts when indices fall outside the range of the string
    debug := false
);


#load "String_New.jai";
