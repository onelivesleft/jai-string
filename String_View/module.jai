// All functions return a string view and/or mutate a string view in-place


#module_parameters (
    default_first_index : = boyer_moore_first_index,   // default proc to find first index of substring in string
    default_last_index  : = boyer_moore_last_index,    // default proc to find last index of substring in string
    default_compare     : = case_sensitive,            // default character comparison check
    strict              : = false                      // Asserts when indices fall outside the range of the string
);


#load "String_View.jai";
#load "boyer_moore.jai";
