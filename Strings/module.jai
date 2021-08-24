// All functions return a string view and/or mutate a string view in-place


#module_parameters (
    // Default compare function used to check for character equality.
    // Can be overridden with `set_default_compare`.
    compare : enum { CASE_SENSITIVE; IGNORE_CASE; } = .CASE_SENSITIVE,

    // Index algorithm used to find instance of string in other string.
    // Can be overriden with `set_index_algorithm`
    index_algorithm : enum { NAIVE; BOYER_MOORE; KNUTH_MORRIS_PRATT; } = .BOYER_MOORE,

    // When strict mode is enabled asserts will fail when indices fall outside
    // the range of the string.
    strict := false
);


#if compare == .CASE_SENSITIVE
    default_compare :: case_sensitive;
else #if compare == .IGNORE_CASE
    default_compare :: ignore_case;

#if index_algorithm == .NAIVE {
    default_first_index :: (haystack: string, needle: string, start_index: int, compare: Character_Compare) -> index: int, found: bool {
        if start_index > haystack.count - needle.count  return -1, false;

        end := cast(u64)haystack.data + cast(u64)(haystack.count - needle.count);
        needle_end := cast(u64)needle.count - 1;
        for start_of_word: cast(u64)haystack.data + cast(u64)start_index .. end {
            needle_index := needle.data;
            for character: start_of_word .. start_of_word + needle_end {
                if !compare(<<cast(*u8)character, <<needle_index)
                    continue start_of_word;
                needle_index += 1;
            }
            return cast(int)(start_of_word - cast(u64)haystack.data), true;
        }

        return -1, false;
    }


    default_last_index :: (haystack: string, needle: string, start_index: int, compare: Character_Compare) -> index: int, found: bool {
        if start_index < needle.count  return -1, false;

        start := cast(u64)haystack.data + cast(u64)(start_index - needle.count);
        needle_end := cast(u64)needle.count - 1;
        for < start_of_word: start .. cast(u64)haystack.data {
            needle_index := needle.data;
            for character: start_of_word .. start_of_word + needle_end {
                if !compare(<<cast(*u8)character, <<needle_index)
                    continue start_of_word;
                needle_index += 1;
            }
            return cast(int)(start_of_word - cast(u64)haystack.data), true;
        }

        return -1, false;
    }
}
else #if index_algorithm == .BOYER_MOORE {
    #load "boyer_moore.jai";
    default_first_index :: boyer_moore_first_index;
    default_last_index  :: boyer_moore_last_index;
}
else #if index_algorithm == .KNUTH_MORRIS_PRATT {
    #load "knuth_morris_pratt.jai";
    default_first_index :: knuth_morris_pratt_first_index;
    default_last_index  :: knuth_morris_pratt_last_index;
}


#load "Strings.jai";
