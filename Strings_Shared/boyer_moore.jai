// @TODO last_index variants reverse indexing so they can use the mechanics of first_index variants
//       (using `get` etc.) - this makes logic simple but is slower than if it was coded directly,
//       so... code it directly!


boyer_moore_first_index :: (haystack: string, needle: string, start_index: int, compare: Character_Compare) -> index: int, found: bool {
    if needle == ""  return start_index, true;
    if start_index >= haystack.count - needle.count  return -1, false;

    if needle != thread_data[context.thread_index].last_used_needle || thread_data[context.thread_index].last_search_was_reversed {
        thread_data[context.thread_index].last_search_was_reversed = false;
        if thread_data[context.thread_index].last_used_needle  free(thread_data[context.thread_index].last_used_needle);
        thread_data[context.thread_index].last_used_needle = copy_string(needle);
        make_bad_character_delta(needle, compare, false);
        make_good_suffix_delta(needle, compare, false);
    }

    haystack_ptr := haystack.data + cast(u64)(needle.count - 1 + start_index);
    haystack_end := haystack.data + cast(u64)haystack.count;
    while haystack_ptr < haystack_end {
        needle_index := needle.count - 1;
        while needle_index >= 0 && compare.compare(<<cast(*u8)haystack_ptr, needle[needle_index]) {
            haystack_ptr -= 1;
            needle_index -= 1;
        }
        if needle_index < 0  return haystack_ptr + 1 - haystack.data, true;

        haystack_ptr += max(thread_data[context.thread_index].bad_character_delta[<<cast(*u8)haystack_ptr], thread_data[context.thread_index].good_suffix_delta[needle_index]);
    }

    return -1, false;
}


boyer_moore_last_index :: (haystack: string, needle: string, start_index: int, compare: Character_Compare) -> index: int, found: bool {
    if needle == ""  return start_index - 1, true;
    if start_index < needle.count  return -1, false;

    if needle != thread_data[context.thread_index].last_used_needle || !thread_data[context.thread_index].last_search_was_reversed {
        thread_data[context.thread_index].last_search_was_reversed = true;
        if thread_data[context.thread_index].last_used_needle  free(thread_data[context.thread_index].last_used_needle);
        thread_data[context.thread_index].last_used_needle = copy_string(needle);
        make_bad_character_delta(needle, compare, true);
        make_good_suffix_delta(needle, compare, true);
    }

    needle_end := needle.count - 1;

    /*  see @TODO up top
    haystack_ptr := cast(u64)haystack.data + cast(u64)start_index - cast(u64)(needle.count);
    end := cast(u64)haystack.data;

    while haystack_ptr >= end {
        needle_index := 0;
        while needle_index <= needle_end && compare.compare(<<cast(*u8)haystack_ptr, needle[needle_index]) {
            haystack_ptr += 1;
            needle_index += 1;
        }
        if needle_index > needle_end  return cast(int)(haystack_ptr - cast(u64)needle.count - cast(u64)haystack.data), true;

        haystack_ptr -= cast(u64)max(bad_character_delta[<<cast(*u8)haystack_ptr], thread_data[context.thread_index].good_suffix_delta[needle_index]);
    }
    */

    start_index = haystack.count - start_index;
    haystack_index := needle.count - 1 + start_index;
    while haystack_index < haystack.count {
        needle_index := needle_end;

        while needle_index >= 0 && compare.compare(get(haystack, haystack_index, true), get(needle, needle_index, true)) {
            haystack_index -= 1;
            needle_index -= 1;
        }
        if needle_index < 0  return haystack.count - needle.count - (haystack_index + 1), true;

        haystack_index += max(thread_data[context.thread_index].bad_character_delta[get(haystack, haystack_index, true)], thread_data[context.thread_index].good_suffix_delta[needle_index]);
    }

    return -1, false;
}


boyer_moore_sse2_first_index :: (haystack: string, needle: string, start_index: int, compare: Character_Compare) -> index: int, found: bool {
    if needle == ""  return start_index, true;
    if start_index > haystack.count - needle.count  return -1, false;

    if needle != thread_data[context.thread_index].last_used_needle || thread_data[context.thread_index].last_search_was_reversed {
        thread_data[context.thread_index].last_search_was_reversed = false;
        if thread_data[context.thread_index].last_used_needle  free(thread_data[context.thread_index].last_used_needle);
        thread_data[context.thread_index].last_used_needle = copy_string(needle);
        make_bad_character_delta(needle, compare, false);
        make_good_suffix_delta(needle, compare, false);
    }

    needle_end := needle.count - 1;

    if compare.kind == {
        case .CASE_SENSITIVE;
            end := cast(u64)haystack.data + cast(u64)(haystack.count);
            haystack_ptr := cast(u64)haystack.data + cast(u64)start_index + cast(u64)needle_end;

            end_simd := end - 15;
            if haystack_ptr < end_simd {
                needle_buffer : [16] u8;
                needle_ptr := *needle_buffer;
                memset(needle_ptr, needle[needle_end], 16);

                results : struct { index, found : u16; };
                results_data := *results;

                while haystack_ptr < end_simd {
                    #insert_internal asm_sse2_case_sensitive_first_index_inner;

                    if results.found {
                        //print("% %", results.index, results.found);
                        haystack_ptr += results.index;
                        needle_index := needle_end;
                        while needle_index >= 0 && compare.compare(<<cast(*u8)haystack_ptr, needle[needle_index]) {
                            haystack_ptr -= 1;
                            needle_index -= 1;
                        }
                        if needle_index < 0  return cast(int)haystack_ptr + 1 - cast(int)haystack.data, true;

                        haystack_ptr += cast(u64)max(thread_data[context.thread_index].bad_character_delta[<<cast(*u8)haystack_ptr], thread_data[context.thread_index].good_suffix_delta[needle_index]);
                    }
                    else
                        haystack_ptr += 16;
                }
            }

            while haystack_ptr < end {
                needle_index := needle_end;
                while needle_index >= 0 && compare.compare(<<cast(*u8)haystack_ptr, needle[needle_index]) {
                    haystack_ptr -= 1;
                    needle_index -= 1;
                }
                if needle_index < 0  return cast(int)haystack_ptr + 1 - cast(int)haystack.data, true;

                haystack_ptr += cast(u64)max(thread_data[context.thread_index].bad_character_delta[<<cast(*u8)haystack_ptr], thread_data[context.thread_index].good_suffix_delta[needle_index]);
            }

            return -1, false;


        case .IGNORE_CASE;
            end := cast(u64)haystack.data + cast(u64)haystack.count;
            haystack_ptr := cast(u64)haystack.data + cast(u64)start_index + cast(u64)needle_end;

            end_simd := end - 15;
            if haystack_ptr < end_simd {
                needle_buffer : [16] u8;
                needle_ptr := *needle_buffer;
                memset(needle_ptr, needle[needle_end], 16);

                case_bit :: 32;
                case_bytes := #insert #run make_16(case_bit);
                a_bytes    := #insert #run make_16(#char "a");
                z_bytes    := #insert #run make_16(#char "z");

                case_ptr := *case_bytes;
                a_ptr := *a_bytes;
                z_ptr := *z_bytes;

                results : struct { index, found : u16; };
                results_data := *results;

                while haystack_ptr < end_simd {
                    #insert_internal asm_sse2_ignore_case_first_index_inner;

                    if results.found {
                        haystack_ptr += results.index;
                        needle_index := needle_end;
                        while needle_index >= 0 && compare.compare(<<cast(*u8)haystack_ptr, needle[needle_index]) {
                            haystack_ptr -= 1;
                            needle_index -= 1;
                        }
                        if needle_index < 0  return cast(int)haystack_ptr + 1 - cast(int)haystack.data, true;

                        haystack_ptr += cast(u64)max(thread_data[context.thread_index].bad_character_delta[<<cast(*u8)haystack_ptr], thread_data[context.thread_index].good_suffix_delta[needle_index]);
                    }
                    else
                        haystack_ptr += 16;
                }
            }

            while haystack_ptr < end {
                needle_index := needle_end;
                while needle_index >= 0 && compare.compare(<<cast(*u8)haystack_ptr, needle[needle_index]) {
                    haystack_ptr -= 1;
                    needle_index -= 1;
                }
                if needle_index < 0  return cast(int)haystack_ptr + 1 - cast(int)haystack.data, true;

                haystack_ptr += cast(u64)max(thread_data[context.thread_index].bad_character_delta[<<cast(*u8)haystack_ptr], thread_data[context.thread_index].good_suffix_delta[needle_index]);
            }

            return -1, false;


        case;
            haystack_ptr := haystack.data + cast(u64)(needle.count - 1 + start_index);
            haystack_end := haystack.data + cast(u64)haystack.count;
            while haystack_ptr < haystack_end {
                needle_index := needle.count - 1;
                while needle_index >= 0 && compare.compare(<<cast(*u8)haystack_ptr, needle[needle_index]) {
                    haystack_ptr -= 1;
                    needle_index -= 1;
                }
                if needle_index < 0  return haystack_ptr + 1 - haystack.data, true;

                haystack_ptr += max(thread_data[context.thread_index].bad_character_delta[<<cast(*u8)haystack_ptr], thread_data[context.thread_index].good_suffix_delta[needle_index]);
            }

            return -1, false;
    }
}


boyer_moore_sse2_last_index :: (haystack: string, needle: string, start_index: int, compare: Character_Compare) -> index: int, found: bool {
    if needle == ""  return start_index - 1, true;
    if start_index < needle.count  return -1, false;

    if needle != thread_data[context.thread_index].last_used_needle || !thread_data[context.thread_index].last_search_was_reversed {
        thread_data[context.thread_index].last_search_was_reversed = true;
        if thread_data[context.thread_index].last_used_needle  free(thread_data[context.thread_index].last_used_needle);
        thread_data[context.thread_index].last_used_needle = copy_string(needle);
        make_bad_character_delta(needle, compare, true);
        make_good_suffix_delta(needle, compare, true);
    }

    needle_end := needle.count - 1;

    if compare.kind == {
        case .CASE_SENSITIVE;
            haystack_ptr := cast(u64)haystack.data + 1 + cast(u64)(start_index - needle.count);
            end := cast(u64)haystack.data;

            end_simd := end + 15;
            if haystack_ptr > end_simd {
                needle_buffer : [16] u8;
                needle_ptr := *needle_buffer;
                memset(needle_ptr, <<needle.data, 16);

                results : struct { index, found : u16; };
                results_data := *results;

                while haystack_ptr > end_simd {
                    next_haystack_ptr := haystack_ptr - 16;

                    #insert_internal asm_sse2_case_sensitive_last_index_inner;

                    if results.found {
                        needle_index := needle_end;
                        haystack_index := cast(u64)haystack.count - (haystack_ptr - cast(u64)haystack.data);
                        while needle_index >= 0 && get(haystack, xx haystack_index, true) == get(needle, needle_index, true) {
                            haystack_index -= 1;
                            needle_index -= 1;
                        }
                        if needle_index < 0  return cast(int)(cast(u64)haystack.count - cast(u64)needle.count - cast(u64)(haystack_index + 1)), true;

                        haystack_index += cast(u64)max(thread_data[context.thread_index].bad_character_delta[get(haystack, xx haystack_index, true)], thread_data[context.thread_index].good_suffix_delta[needle_index]);
                        haystack_ptr = cast(u64)haystack.data + cast(u64)haystack.count - cast(u64)haystack_index;
                    }
                    else
                        haystack_ptr = next_haystack_ptr;
                }
            }

            while haystack_ptr > cast(u64)haystack.data {
                needle_index := needle_end;
                haystack_index := cast(u64)haystack.count - (haystack_ptr - cast(u64)haystack.data);
                while needle_index >= 0 && get(haystack, xx haystack_index, true) == get(needle, needle_index, true) {
                    haystack_index -= 1;
                    needle_index -= 1;
                }
                if needle_index < 0  return cast(int)(cast(u64)haystack.count - cast(u64)needle.count - cast(u64)(haystack_index + 1)), true;

                haystack_index += cast(u64)max(thread_data[context.thread_index].bad_character_delta[get(haystack, xx haystack_index, true)], thread_data[context.thread_index].good_suffix_delta[needle_index]);
                haystack_ptr = cast(u64)haystack.data + cast(u64)haystack.count - cast(u64)haystack_index;
            }

            return -1, false;


        case .IGNORE_CASE;
            haystack_ptr := cast(u64)haystack.data + 1 + cast(u64)(start_index - needle.count);
            end := cast(u64)haystack.data;

            end_simd := end + 15;
            if haystack_ptr > end_simd {
                needle_buffer : [16] u8;
                needle_ptr := *needle_buffer;
                memset(needle_ptr, <<needle.data, 16);

                case_bit :: 32;
                case_bytes := #insert #run make_16(case_bit);
                a_bytes    := #insert #run make_16(#char "a");
                z_bytes    := #insert #run make_16(#char "z");

                case_ptr := *case_bytes;
                a_ptr := *a_bytes;
                z_ptr := *z_bytes;

                results : struct { index, found : u16; };
                results_data := *results;

                while haystack_ptr > end_simd && false {
                    next_haystack_ptr := haystack_ptr - 16;

                    #insert_internal asm_sse2_ignore_case_last_index_inner;

                     if results.found {
                        needle_index := needle_end;
                        haystack_index := cast(u64)haystack.count - (haystack_ptr - cast(u64)haystack.data);
                        while needle_index >= 0 && compare.compare(get(haystack, xx haystack_index, true), get(needle, needle_index, true)) {
                            haystack_index -= 1;
                            needle_index -= 1;
                        }
                        if needle_index < 0  return cast(int)(cast(u64)haystack.count - cast(u64)needle.count - cast(u64)(haystack_index + 1)), true;

                        haystack_index += cast(u64)max(thread_data[context.thread_index].bad_character_delta[get(haystack, xx haystack_index, true)], thread_data[context.thread_index].good_suffix_delta[needle_index]);
                        haystack_ptr = cast(u64)haystack.data + cast(u64)haystack.count - cast(u64)haystack_index;
                    }
                    else
                        haystack_ptr = next_haystack_ptr;
                }
            }

            while haystack_ptr > cast(u64)haystack.data {
                needle_index := needle_end;
                haystack_index := cast(u64)haystack.count - (haystack_ptr - cast(u64)haystack.data);
                while needle_index >= 0 && compare.compare(get(haystack, xx haystack_index, true), get(needle, needle_index, true)) {
                    haystack_index -= 1;
                    needle_index -= 1;
                }
                if needle_index < 0  return cast(int)(cast(u64)haystack.count - cast(u64)needle.count - cast(u64)(haystack_index + 1)), true;

                haystack_index += cast(u64)max(thread_data[context.thread_index].bad_character_delta[get(haystack, xx haystack_index, true)], thread_data[context.thread_index].good_suffix_delta[needle_index]);
                haystack_ptr = cast(u64)haystack.data + cast(u64)haystack.count - cast(u64)haystack_index;
            }

            return -1, false;


        case;
            start_index = haystack.count - start_index;
            haystack_index := needle.count - 1 + start_index;
            while haystack_index < haystack.count {
                needle_index := needle_end;

                while needle_index >= 0 && compare.compare(get(haystack, haystack_index, true), get(needle, needle_index, true)) {
                    haystack_index -= 1;
                    needle_index -= 1;
                }
                if needle_index < 0  return haystack.count - needle.count - (haystack_index + 1), true;

                haystack_index += max(thread_data[context.thread_index].bad_character_delta[get(haystack, haystack_index, true)], thread_data[context.thread_index].good_suffix_delta[needle_index]);
            }

            return -1, false;
    }
}


boyer_moore_avx2_first_index :: (haystack: string, needle: string, start_index: int, compare: Character_Compare) -> index: int, found: bool {
    if needle == ""  return start_index, true;
    if start_index > haystack.count - needle.count  return -1, false;

    if needle != thread_data[context.thread_index].last_used_needle || thread_data[context.thread_index].last_search_was_reversed {
        thread_data[context.thread_index].last_search_was_reversed = false;
        if thread_data[context.thread_index].last_used_needle  free(thread_data[context.thread_index].last_used_needle);
        thread_data[context.thread_index].last_used_needle = copy_string(needle);
        make_bad_character_delta(needle, compare, false);
        make_good_suffix_delta(needle, compare, false);
    }

    needle_end := needle.count - 1;

    if compare.kind == {
        case .CASE_SENSITIVE;
            end := cast(u64)haystack.data + cast(u64)(haystack.count);
            haystack_ptr := cast(u64)haystack.data + cast(u64)start_index + cast(u64)needle_end;

            end_simd := end - 31;
            if haystack_ptr < end_simd {
                needle_buffer : [32] u8;
                needle_ptr := *needle_buffer;
                memset(needle_ptr, needle[needle_end], 32);

                results : struct { index, found : u32; };
                results_data := *results;

                while haystack_ptr < end_simd {
                    #insert_internal asm_avx2_case_sensitive_first_index_inner;

                    if results.found {
                        //print("% %", results.index, results.found);
                        haystack_ptr += results.index;
                        needle_index := needle_end;
                        while needle_index >= 0 && compare.compare(<<cast(*u8)haystack_ptr, needle[needle_index]) {
                            haystack_ptr -= 1;
                            needle_index -= 1;
                        }
                        if needle_index < 0  return cast(int)haystack_ptr + 1 - cast(int)haystack.data, true;

                        haystack_ptr += cast(u64)max(thread_data[context.thread_index].bad_character_delta[<<cast(*u8)haystack_ptr], thread_data[context.thread_index].good_suffix_delta[needle_index]);
                    }
                    else
                        haystack_ptr += 32;
                }
            }

            while haystack_ptr < end {
                needle_index := needle_end;
                while needle_index >= 0 && compare.compare(<<cast(*u8)haystack_ptr, needle[needle_index]) {
                    haystack_ptr -= 1;
                    needle_index -= 1;
                }
                if needle_index < 0  return cast(int)haystack_ptr + 1 - cast(int)haystack.data, true;

                haystack_ptr += cast(u64)max(thread_data[context.thread_index].bad_character_delta[<<cast(*u8)haystack_ptr], thread_data[context.thread_index].good_suffix_delta[needle_index]);
            }

            return -1, false;


        case .IGNORE_CASE;
            end := cast(u64)haystack.data + cast(u64)haystack.count;
            haystack_ptr := cast(u64)haystack.data + cast(u64)start_index + cast(u64)needle_end;

            end_simd := end - 31;
            if haystack_ptr < end_simd {
                needle_buffer : [32] u8;
                needle_ptr := *needle_buffer;
                memset(needle_ptr, needle[needle_end], 32);

                case_bit :: 32;
                case_bytes := #insert #run make_16(case_bit);
                a_bytes    := #insert #run make_16(#char "a");
                z_bytes    := #insert #run make_16(#char "z");

                case_ptr := *case_bytes;
                a_ptr := *a_bytes;
                z_ptr := *z_bytes;

                results : struct { index, found : u32; };
                results_data := *results;

                while haystack_ptr < end_simd {
                    #insert_internal asm_avx2_ignore_case_first_index_inner;

                    if results.found {
                        haystack_ptr += results.index;
                        needle_index := needle_end;
                        while needle_index >= 0 && compare.compare(<<cast(*u8)haystack_ptr, needle[needle_index]) {
                            haystack_ptr -= 1;
                            needle_index -= 1;
                        }
                        if needle_index < 0  return cast(int)haystack_ptr + 1 - cast(int)haystack.data, true;

                        haystack_ptr += cast(u64)max(thread_data[context.thread_index].bad_character_delta[<<cast(*u8)haystack_ptr], thread_data[context.thread_index].good_suffix_delta[needle_index]);
                    }
                    else
                        haystack_ptr += 32;
                }
            }

            while haystack_ptr < end {
                needle_index := needle_end;
                while needle_index >= 0 && compare.compare(<<cast(*u8)haystack_ptr, needle[needle_index]) {
                    haystack_ptr -= 1;
                    needle_index -= 1;
                }
                if needle_index < 0  return cast(int)haystack_ptr + 1 - cast(int)haystack.data, true;

                haystack_ptr += cast(u64)max(thread_data[context.thread_index].bad_character_delta[<<cast(*u8)haystack_ptr], thread_data[context.thread_index].good_suffix_delta[needle_index]);
            }

            return -1, false;


        case;
            haystack_ptr := haystack.data + cast(u64)(needle.count - 1 + start_index);
            haystack_end := haystack.data + cast(u64)haystack.count;
            while haystack_ptr < haystack_end {
                needle_index := needle.count - 1;
                while needle_index >= 0 && compare.compare(<<cast(*u8)haystack_ptr, needle[needle_index]) {
                    haystack_ptr -= 1;
                    needle_index -= 1;
                }
                if needle_index < 0  return haystack_ptr + 1 - haystack.data, true;

                haystack_ptr += max(thread_data[context.thread_index].bad_character_delta[<<cast(*u8)haystack_ptr], thread_data[context.thread_index].good_suffix_delta[needle_index]);
            }

            return -1, false;
    }
}


boyer_moore_avx2_last_index :: (haystack: string, needle: string, start_index: int, compare: Character_Compare) -> index: int, found: bool {
    if needle == ""  return start_index - 1, true;
    if start_index < needle.count  return -1, false;

    if needle != thread_data[context.thread_index].last_used_needle || !thread_data[context.thread_index].last_search_was_reversed {
        thread_data[context.thread_index].last_search_was_reversed = true;
        if thread_data[context.thread_index].last_used_needle  free(thread_data[context.thread_index].last_used_needle);
        thread_data[context.thread_index].last_used_needle = copy_string(needle);
        make_bad_character_delta(needle, compare, true);
        make_good_suffix_delta(needle, compare, true);
    }

    needle_end := needle.count - 1;

    if compare.kind == {
        case .CASE_SENSITIVE;
            haystack_ptr := cast(u64)haystack.data + 1 + cast(u64)(start_index - needle.count);
            end := cast(u64)haystack.data;

            end_simd := end + 31;
            if haystack_ptr > end_simd {
                needle_buffer : [32] u8;
                needle_ptr := *needle_buffer;
                memset(needle_ptr, <<needle.data, 32);

                results : struct { index, found : u32; };
                results_data := *results;

                while haystack_ptr > end_simd {
                    next_haystack_ptr := haystack_ptr - 32;

                    #insert_internal asm_avx2_case_sensitive_last_index_inner;

                    if results.found {
                        needle_index := needle_end;
                        haystack_index := cast(u64)haystack.count - (haystack_ptr - cast(u64)haystack.data);
                        while needle_index >= 0 && get(haystack, xx haystack_index, true) == get(needle, needle_index, true) {
                            haystack_index -= 1;
                            needle_index -= 1;
                        }
                        if needle_index < 0  return cast(int)(cast(u64)haystack.count - cast(u64)needle.count - cast(u64)(haystack_index + 1)), true;

                        haystack_index += cast(u64)max(thread_data[context.thread_index].bad_character_delta[get(haystack, xx haystack_index, true)], thread_data[context.thread_index].good_suffix_delta[needle_index]);
                        haystack_ptr = cast(u64)haystack.data + cast(u64)haystack.count - cast(u64)haystack_index;
                    }
                    else
                        haystack_ptr = next_haystack_ptr;
                }
            }

            while haystack_ptr > cast(u64)haystack.data {
                needle_index := needle_end;
                haystack_index := cast(u64)haystack.count - (haystack_ptr - cast(u64)haystack.data);
                while needle_index >= 0 && get(haystack, xx haystack_index, true) == get(needle, needle_index, true) {
                    haystack_index -= 1;
                    needle_index -= 1;
                }
                if needle_index < 0  return cast(int)(cast(u64)haystack.count - cast(u64)needle.count - cast(u64)(haystack_index + 1)), true;

                haystack_index += cast(u64)max(thread_data[context.thread_index].bad_character_delta[get(haystack, xx haystack_index, true)], thread_data[context.thread_index].good_suffix_delta[needle_index]);
                haystack_ptr = cast(u64)haystack.data + cast(u64)haystack.count - cast(u64)haystack_index;
            }

            return -1, false;


        case .IGNORE_CASE;
            haystack_ptr := cast(u64)haystack.data + 1 + cast(u64)(start_index - needle.count);
            end := cast(u64)haystack.data;

            end_simd := end + 31;
            if haystack_ptr > end_simd {
                needle_buffer : [32] u8;
                needle_ptr := *needle_buffer;
                memset(needle_ptr, <<needle.data, 32);

                case_bit :: 32;
                case_bytes := #insert #run make_16(case_bit);
                a_bytes    := #insert #run make_16(#char "a");
                z_bytes    := #insert #run make_16(#char "z");

                case_ptr := *case_bytes;
                a_ptr := *a_bytes;
                z_ptr := *z_bytes;

                results : struct { index, found : u32; };
                results_data := *results;

                while haystack_ptr > end_simd && false {
                    next_haystack_ptr := haystack_ptr - 32;

                    #insert_internal asm_avx2_ignore_case_last_index_inner;

                    if results.found {
                        needle_index := needle_end;
                        haystack_index := cast(u64)haystack.count - (haystack_ptr - cast(u64)haystack.data);
                        while needle_index >= 0 && compare.compare(get(haystack, xx haystack_index, true), get(needle, needle_index, true)) {
                            haystack_index -= 1;
                            needle_index -= 1;
                        }
                        if needle_index < 0  return cast(int)(cast(u64)haystack.count - cast(u64)needle.count - cast(u64)(haystack_index + 1)), true;

                        haystack_index += cast(u64)max(thread_data[context.thread_index].bad_character_delta[get(haystack, xx haystack_index, true)], thread_data[context.thread_index].good_suffix_delta[needle_index]);
                        haystack_ptr = cast(u64)haystack.data + cast(u64)haystack.count - cast(u64)haystack_index;
                    }
                    else
                        haystack_ptr = next_haystack_ptr;
                }
            }

            while haystack_ptr > cast(u64)haystack.data {
                needle_index := needle_end;
                haystack_index := cast(u64)haystack.count - (haystack_ptr - cast(u64)haystack.data);
                while needle_index >= 0 && compare.compare(get(haystack, xx haystack_index, true), get(needle, needle_index, true)) {
                    haystack_index -= 1;
                    needle_index -= 1;
                }
                if needle_index < 0  return cast(int)(cast(u64)haystack.count - cast(u64)needle.count - cast(u64)(haystack_index + 1)), true;

                haystack_index += cast(u64)max(thread_data[context.thread_index].bad_character_delta[get(haystack, xx haystack_index, true)], thread_data[context.thread_index].good_suffix_delta[needle_index]);
                haystack_ptr = cast(u64)haystack.data + cast(u64)haystack.count - cast(u64)haystack_index;
            }

            return -1, false;


        case;
            start_index = haystack.count - start_index;
            haystack_index := needle.count - 1 + start_index;
            while haystack_index < haystack.count {
                needle_index := needle_end;

                while needle_index >= 0 && compare.compare(get(haystack, haystack_index, true), get(needle, needle_index, true)) {
                    haystack_index -= 1;
                    needle_index -= 1;
                }
                if needle_index < 0  return haystack.count - needle.count - (haystack_index + 1), true;

                haystack_index += max(thread_data[context.thread_index].bad_character_delta[get(haystack, haystack_index, true)], thread_data[context.thread_index].good_suffix_delta[needle_index]);
            }

            return -1, false;
    }
}



#scope_file

#import "Strings_Shared";

alphabet_count :: 256;
max_thread_count :: strings_shared_max_thread_count;

thread_data : [max_thread_count] struct {
    bad_character_delta : [alphabet_count] int;
    good_suffix_delta : [..] int;
    last_used_needle : string;
    last_search_was_reversed : bool;
};


get :: inline (str: string, index: int, $reversed: bool) -> u8 {
    #if reversed  return str[str.count - 1 - index];
    else          return str[index];
}


make_bad_character_delta :: (needle: string, compare: Character_Compare, $reversed: bool) {
    for i: 0 .. alphabet_count - 1
        thread_data[context.thread_index].bad_character_delta[i] = needle.count;
    for i: 0 .. needle.count - 1 {
        needle_char := get(needle, i, reversed);
        for alphabet_char: 0 .. alphabet_count - 1
            if compare.compare(needle_char, cast,no_check(u8)alphabet_char)
                thread_data[context.thread_index].bad_character_delta[alphabet_char] = max(1, needle.count - 1 - i);
    }
}


is_prefix :: (word: string, index: int, compare: Character_Compare, $reversed: bool) -> bool {
    for word_index: 0 .. word.count - index - 1
        if !compare.compare(get(word, word_index, reversed), get(word, index + word_index, reversed))
            return false;

    return true;
}


get_suffix_count :: (word: string, index: int, compare: Character_Compare, $reversed: bool) -> int {
    word_index := 0;
    while compare.compare(get(word, index - word_index, reversed), get(word, word.count - 1 - word_index, reversed)) && word_index < index
        word_index += 1;

    return word_index;
}


make_good_suffix_delta :: (needle: string, compare: Character_Compare, $reversed: bool) {
    if thread_data[context.thread_index].good_suffix_delta.count < needle.count
        array_resize(*thread_data[context.thread_index].good_suffix_delta, needle.count, false);

    last_prefix_index := needle.count - 1;

    for < index: needle.count - 1 .. 0 {
        if is_prefix(needle, index + 1, compare, reversed)
            last_prefix_index = index + 1;
        thread_data[context.thread_index].good_suffix_delta.data[index] = last_prefix_index + needle.count - 1 - index;
    }

    for index: 0 .. needle.count - 2 {
        suffix_count := get_suffix_count(needle, index, compare, reversed);
        if !compare.compare(get(needle, index - suffix_count, reversed), get(needle, needle.count - 1 - suffix_count, reversed))
            thread_data[context.thread_index].good_suffix_delta.data[needle.count - 1 - suffix_count] = needle.count - 1 - index + suffix_count;
    }
}


make_16 :: (value: u8) -> string {
    return sprint("u8.[%1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1];", value);
}

make_32 :: (value: u8) -> string {
    return sprint("u8.[%1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1];", value);
}
