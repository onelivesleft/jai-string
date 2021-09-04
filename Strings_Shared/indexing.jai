naive_first_index :: (haystack: string, needle: string, start_index: int, compare: Character_Compare) -> index: int, found: bool {
    if start_index > haystack.count - needle.count  return -1, false;

    end := cast(u64)haystack.data + cast(u64)(haystack.count - needle.count);
    needle_end := cast(u64)needle.count - 1;
    for test_index: cast(u64)haystack.data + cast(u64)start_index .. end {
        needle_index := needle.data;
        for character: test_index .. test_index + needle_end {
            if !compare.compare(<<cast(*u8)character, <<needle_index)
                continue test_index;
            needle_index += 1;
        }
        return cast(int)(test_index - cast(u64)haystack.data), true;
    }

    return -1, false;
}


naive_last_index :: (haystack: string, needle: string, start_index: int, compare: Character_Compare) -> index: int, found: bool {
    if start_index < needle.count  return -1, false;

    start := cast(u64)haystack.data + cast(u64)(start_index - needle.count);
    needle_end := cast(u64)needle.count - 1;
    for < test_index: start .. cast(u64)haystack.data {
        needle_index := needle.data;
        for character: test_index .. test_index + needle_end {
            if !compare.compare(<<cast(*u8)character, <<needle_index)
                continue test_index;
            needle_index += 1;
        }
        return cast(int)(test_index - cast(u64)haystack.data), true;
    }

    return -1, false;
}

/*

naive_with_sse_first_index :: (haystack: string, needle: string, start_index: int, compare: Character_Compare) -> index: int, found: bool {
    if start_index > haystack.count - needle.count  return -1, false;

    if compare.kind == {
        case .CASE_SENSITIVE;
                    end := cast(u64)haystack.data + cast(u64)(haystack.count - needle.count);
                    needle_end := cast(u64)needle.count - 1;
                    test_index := cast(u64)haystack.data + cast(u64)start_index;

                    end_simd := end - 15;
                    if test_index < end_simd {
                        needle_buffer : [16] u8;
                        needle_ptr := *needle_buffer;
                        memset(needle_ptr, <<needle.data, 16);

                        results : struct { index, found : u16; };
                        results_data := *results;

                        while test_index < end_simd {
                            #asm {
                                movdqu.x   needle_vec:, [needle_ptr];
                                movdqu.x   haystack_vec:, [test_index];

                                /* check for equality */
                                pcmpeqb.x  results_vec:, haystack_vec, needle_vec;
                                pmovmskb.x found_gpr:, results_vec;

                                /* calculate index of first equal character */
                                tzcnt.w    index_gpr:, found_gpr;

                                /* pack found:index and export */
                                shl.d      found_gpr, 16;
                                or.d       found_gpr, index_gpr;
                                mov.d      [results_data], found_gpr;
                            }

                            if results.found {
                                word_index := test_index + results.index;
                                second_index := word_index + 1;
                                needle_index := needle.data + 1;
                                for character: second_index .. word_index + needle_end {
                                    if <<cast(*u8)character != <<needle_index {
                                        test_index = second_index;
                                        break;
                                    }
                                    needle_index += 1;
                                }
                                if test_index < second_index {
                                    return cast(int)(word_index - cast(u64)haystack.data), true;
                                }
                            }
                            else
                                test_index += 16;
                        }
                    }

                    for index: test_index .. end {
                        needle_index := needle.data;
                        for character: test_index .. test_index + needle_end {
                            if !compare.compare(<<cast(*u8)character, <<needle_index)
                                continue index;
                            needle_index += 1;
                        }
                        return cast(int)(test_index - cast(u64)haystack.data), true;
                    }

    if !handled {
        end := cast(u64)haystack.data + cast(u64)(haystack.count - needle.count);
        needle_end := cast(u64)needle.count - 1;
        for test_index: cast(u64)haystack.data + cast(u64)start_index .. end {
            needle_index := needle.data;
            for character: test_index .. test_index + needle_end {
                if !compare.compare(<<cast(*u8)character, <<needle_index)
                    continue test_index;
                needle_index += 1;
            }
            return cast(int)(test_index - cast(u64)haystack.data), true;
        }
    }

    return -1, false;
}
*/
