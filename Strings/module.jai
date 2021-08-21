// All functions return a string view and/or mutate a string view in-place


#module_parameters (
    the_default_compare := case_sensitive,           // default compare function used when matching strings
                                                      // other provided option is `ignore_case`

    default_first_index := boyer_moore_first_index,   // default proc to find first index of substring in string
    default_last_index  := boyer_moore_last_index,    // default proc to find last index of substring in string

    strict := false                                   // Asserts when indices fall outside the range of the string
);

default_compare :: the_default_compare;

#load "Strings.jai";
#load "boyer_moore.jai";
