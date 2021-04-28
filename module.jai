#module_parameters (
    default_allocator : Allocator = No_Allocator,
    default_allocator_data : *void = null,
    allocate := true,
    default_compare := case_sensitive,
    default_first_index := boyer_moore_first_index,   // default proc to find first index of substring in string
    default_last_index  := boyer_moore_last_index,    // default proc to find last index of substring in string
    add_convenience_functions := false,
    strict := false,                                  // Asserts when indices fall outside the range of the string
    debug := false
);

No_Allocator :: (mode: Allocator_Mode, size: s64, old_size: s64, old_memory_pointer: *void, allocator_data: *void) -> *void { return null; }

#load "src/non_allocated.jai";
#load "src/boyer_moore.jai";

#if allocate {
    #load "src/allocated.jai";
}
