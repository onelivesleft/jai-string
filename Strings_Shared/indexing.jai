simple_first_index :: (haystack: string, needle: string, start_index: int, compare: Character_Compare) -> index: int, found: bool {
    if needle == ""  return start_index, true;
    if start_index > haystack.count - needle.count  return -1, false;

    end := cast(u64)haystack.data + cast(u64)(haystack.count - needle.count);
    needle_end := cast(u64)needle.count - 1;
    for start_of_match: cast(u64)haystack.data + cast(u64)start_index .. end {
        needle_index := needle.data;
        for character: start_of_match .. start_of_match + needle_end {
            if !compare.compare(<<cast(*u8)character, <<needle_index)
                continue start_of_match;
            needle_index += 1;
        }
        return cast(int)(start_of_match - cast(u64)haystack.data), true;
    }

    return -1, false;
}


simple_last_index :: (haystack: string, needle: string, start_index: int, compare: Character_Compare) -> index: int, found: bool {
    if needle == ""  return start_index - 1, true;
    if start_index < needle.count  return -1, false;

    start := cast(u64)haystack.data + cast(u64)(start_index - needle.count);
    needle_end := cast(u64)needle.count - 1;
    for < start_of_match: start .. cast(u64)haystack.data {
        needle_index := needle.data;
        for character: start_of_match .. start_of_match + needle_end {
            if !compare.compare(<<cast(*u8)character, <<needle_index)
                continue start_of_match;
            needle_index += 1;
        }
        return cast(int)(start_of_match - cast(u64)haystack.data), true;
    }

    return -1, false;
}



simple_sse2_first_index :: (haystack: string, needle: string, start_index: int, compare: Character_Compare) -> index: int, found: bool {
    if needle == ""  return start_index, true;
    if start_index > haystack.count - needle.count  return -1, false;

    if compare.kind == {
        case .CASE_SENSITIVE;
            end := cast(u64)haystack.data + cast(u64)(haystack.count - needle.count);
            needle_end := cast(u64)needle.count - 1;
            haystack_ptr := cast(u64)haystack.data + cast(u64)start_index;

            end_simd := end - 15;
            if haystack_ptr < end_simd {
                needle_buffer : [16] u8;
                needle_ptr := *needle_buffer;
                memset(needle_ptr, <<needle.data, 16);

                results : struct { index, found : u16; };
                results_data := *results;

                while haystack_ptr < end_simd {
                    #asm {
                        movdqu.x   needle_vec:, [needle_ptr];
                        movdqu.x   haystack_vec:, [haystack_ptr];

                        /* check for equality */
                        movdqu.x   results_vec:, haystack_vec;
                        pcmpeqb.x  results_vec, needle_vec;
                        pmovmskb.x found_gpr:, results_vec;

                        /* calculate index of first equal character */
                        tzcnt.w    index_gpr:, found_gpr;

                        /* pack found:index and export */
                        shl.d      found_gpr, 16;
                        or.w       found_gpr, index_gpr;
                        mov.d      [results_data], found_gpr;
                    }

                    if results.found {
                        word_index := haystack_ptr + results.index;
                        second_character_index := word_index + 1;
                        needle_index := needle.data + 1;
                        for character: second_character_index .. word_index + needle_end {
                            if <<cast(*u8)character != <<needle_index {
                                haystack_ptr = second_character_index;
                                break;
                            }
                            needle_index += 1;
                        }
                        if haystack_ptr < second_character_index {
                            return cast(int)(word_index - cast(u64)haystack.data), true;
                        }
                    }
                    else
                        haystack_ptr += 16;
                }
            }

            for index: haystack_ptr .. end {
                needle_index := needle.data;
                for character: index .. index + needle_end {
                    if <<cast(*u8)character != <<needle_index
                        continue index;
                    needle_index += 1;
                }
                return cast(int)(index - cast(u64)haystack.data), true;
            }

            return -1, false;


        case .IGNORE_CASE;
            end := cast(u64)haystack.data + cast(u64)(haystack.count - needle.count);
            needle_end := cast(u64)needle.count - 1;
            haystack_ptr := cast(u64)haystack.data + cast(u64)start_index;

            end_simd := end - 15;
            if haystack_ptr < end_simd {
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

                while haystack_ptr < end_simd {
                    #asm {
                        movdqu.x case_vec: vec, [case_ptr];
                        movdqu.x a_vec:, [a_ptr];
                        movdqu.x z_vec:, [z_ptr];

                        movdqu.x needle_vec:, [needle_ptr];
                        movdqu.x haystack_vec:, [haystack_ptr];

                        /* check for case-sensitive equality */
                        pcmpeqb.x result_cased_vec:, needle_vec, haystack_vec;

                        /* check for ignore-case equality */
                        por.x haystack_vec, case_vec;
                        por.x needle_vec, case_vec;
                        pcmpeqb.x result_nocase_vec:, needle_vec, haystack_vec;

                        /* generate mask for which bits should be case-sensitive */
                        movdqa.x mask_vec:, haystack_vec;
                        pcmpgtb.x mask_vec, z_vec;

                        movdqa.x bounds_vec:, a_vec;
                        pcmpgtb.x bounds_vec, haystack_vec;
                        por.x mask_vec, bounds_vec;

                        /* apply mask to keep case-sensitive bits */
                        pand.x result_cased_vec, mask_vec;

                        /* invert mask then apply it to keep ignore-case bits */
                        pcmpeqb.x bounds_vec, bounds_vec, bounds_vec;
                        pxor.x mask_vec, bounds_vec;
                        pand.x result_nocase_vec, mask_vec;

                        /* combine results */
                        por.x result_cased_vec, result_nocase_vec;

                        /* calculate index of first equal character */
                        pmovmskb.x found_gpr:, result_cased_vec;
                        tzcnt.w index_gpr:, found_gpr;

                        /* pack found:index and export */
                        shl.d found_gpr, 16;
                        or.w found_gpr, index_gpr;
                        mov.d [results_data], found_gpr;
                    }

                    if results.found {
                        word_index := haystack_ptr + results.index;
                        second_character_index := word_index + 1;
                        needle_index := needle.data + 1;
                        for character: second_character_index .. word_index + needle_end {
                            if !no_case_compare(<<cast(*u8)character, <<needle_index) {
                                haystack_ptr = second_character_index;
                                break;
                            }
                            needle_index += 1;
                        }
                        if haystack_ptr < second_character_index {
                            return cast(int)(word_index - cast(u64)haystack.data), true;
                        }
                    }
                    else
                        haystack_ptr += 16;
                }
            }

            for index: haystack_ptr .. end {
                needle_index := needle.data;
                for character: index .. index + needle_end {
                    if !no_case_compare(<<cast(*u8)character, <<needle_index)
                        continue index;
                    needle_index += 1;
                }
                return cast(int)(index - cast(u64)haystack.data), true;
            }

            return -1, false;


        case;
            end := cast(u64)haystack.data + cast(u64)(haystack.count - needle.count);
            needle_end := cast(u64)needle.count - 1;
            for haystack_ptr: cast(u64)haystack.data + cast(u64)start_index .. end {
                needle_index := needle.data;
                for character: haystack_ptr .. haystack_ptr + needle_end {
                    if !compare.compare(<<cast(*u8)character, <<needle_index)
                        continue haystack_ptr;
                    needle_index += 1;
                }
                return cast(int)(haystack_ptr - cast(u64)haystack.data), true;
            }

            return -1, false;
    }
}


simple_sse2_last_index :: (haystack: string, needle: string, start_index: int, compare: Character_Compare) -> index: int, found: bool {
    if needle == ""  return start_index - 1, true;
    if start_index < needle.count  return -1, false;

    if compare.kind == {
        case .CASE_SENSITIVE;
            end := cast(u64)haystack.data;
            needle_end := needle.count - 1;
            haystack_ptr := cast(u64)haystack.data + cast(u64)(start_index - needle_end);

            end_simd := end + 15;
            if haystack_ptr > end_simd {
                needle_buffer : [16] u8;
                needle_ptr := *needle_buffer;
                memset(needle_ptr, <<needle.data, 16);

                results : struct { index, found : u16; };
                results_data := *results;

                while haystack_ptr > end_simd {
                    next_haystack_ptr := haystack_ptr - 16;
                    #asm {
                        movdqu.x   needle_vec:, [needle_ptr];
                        movdqu.x   haystack_vec:, [next_haystack_ptr];

                        /* check for equality */
                        movdqu.x   results_vec:, haystack_vec;
                        pcmpeqb.x  results_vec, needle_vec;
                        pmovmskb.x found_gpr:, results_vec;

                        /* calculate index of last equal character */
                        lzcnt.w    index_gpr:, found_gpr;

                        /* pack found:index and export */
                        shl.d      found_gpr, 16;
                        or.w       found_gpr, index_gpr;
                        mov.d      [results_data], found_gpr;
                    }

                    if results.found {
                        word_index := haystack_ptr - results.index - 1;
                        needle_index := needle.data + 1;
                        for character: word_index + 1 .. word_index + cast(u64)needle_end {
                            if <<cast(*u8)character != <<needle_index {
                                haystack_ptr = word_index;
                                break;
                            }
                            needle_index += 1;
                        }
                        if haystack_ptr > word_index {
                            return cast(int)(word_index - cast(u64)haystack.data), true;
                        }
                    }
                    else
                        haystack_ptr = next_haystack_ptr;
                }
            }

            for < index: haystack_ptr .. end {
                needle_index := needle.data;
                for character: index .. index + cast(u64)needle_end {
                    if <<cast(*u8)character != <<needle_index
                        continue index;
                    needle_index += 1;
                }
                return cast(int)(index - cast(u64)haystack.data), true;
            }

            return -1, false;


        case .IGNORE_CASE;
            needle_end := needle.count - 1;
            haystack_ptr := cast(u64)haystack.data + cast(u64)(start_index - needle_end);
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

                while haystack_ptr > end_simd {
                    next_haystack_ptr := haystack_ptr - 16;
                    #asm {
                        movdqu.x case_vec:, [case_ptr];
                        movdqu.x a_vec:, [a_ptr];
                        movdqu.x z_vec:, [z_ptr];

                        movdqu.x needle_vec:, [needle_ptr];
                        movdqu.x haystack_vec:, [next_haystack_ptr];

                        /* check for case-sensitive equality */
                        pcmpeqb.x result_cased_vec:, needle_vec, haystack_vec;

                        /* check for ignore-case equality */
                        por.x haystack_vec, case_vec;
                        por.x needle_vec, case_vec;
                        pcmpeqb.x result_nocase_vec:, needle_vec, haystack_vec;

                        /* generate mask for which bits should be case-sensitive */
                        movdqa.x mask_vec:, haystack_vec;
                        pcmpgtb.x mask_vec, z_vec;

                        movdqa.x bounds_vec:, a_vec;
                        pcmpgtb.x bounds_vec, haystack_vec;
                        por.x mask_vec, bounds_vec;

                        /* apply mask to keep case-sensitive bits */
                        pand.x result_cased_vec, mask_vec;

                        /* invert mask then apply it to keep ignore-case bits */
                        pcmpeqb.x bounds_vec, bounds_vec, bounds_vec;
                        pxor.x mask_vec, bounds_vec;
                        pand.x result_nocase_vec, mask_vec;

                        /* combine results */
                        por.x result_cased_vec, result_nocase_vec;

                        /* calculate index of last equal character */
                        pmovmskb.x found_gpr:, result_cased_vec;
                        lzcnt.w index_gpr:, found_gpr;

                        /* pack found:index and export */
                        shl.d found_gpr, 16;
                        or.w found_gpr, index_gpr;
                        mov.d [results_data], found_gpr;
                    }

                    if results.found {
                        word_index := haystack_ptr - results.index - 1;
                        needle_index := needle.data + 1;
                        for character: word_index + 1 .. word_index + cast(u64)needle_end {
                            if !no_case_compare(<<cast(*u8)character, <<needle_index) {
                                haystack_ptr = word_index;
                                break;
                            }
                            needle_index += 1;
                        }
                        if haystack_ptr > word_index {
                            return cast(int)(word_index - cast(u64)haystack.data), true;
                        }
                    }
                    else
                        haystack_ptr = next_haystack_ptr;
                }
            }

            for < index: haystack_ptr .. end {
                needle_index := needle.data;
                for character: index .. index + cast(u64)needle_end {
                    if !no_case_compare(<<cast(*u8)character, <<needle_index)
                        continue index;
                    needle_index += 1;
                }
                return cast(int)(index - cast(u64)haystack.data), true;
            }

            return -1, false;


        case;
            needle_end := needle.count - 1;
            start := cast(u64)haystack.data + cast(u64)(start_index - needle.count);
            for < start_of_match: start .. cast(u64)haystack.data {
                needle_index := needle.data;
                for character: start_of_match .. start_of_match + cast(u64)needle_end {
                    if !compare.compare(<<cast(*u8)character, <<needle_index)
                        continue start_of_match;
                    needle_index += 1;
                }
                return cast(int)(start_of_match - cast(u64)haystack.data), true;
            }

            return -1, false;
    }
}




simple_avx2_first_index :: (haystack: string, needle: string, start_index: int, compare: Character_Compare) -> index: int, found: bool {
    if needle == ""  return start_index, true;
    if start_index > haystack.count - needle.count  return -1, false;

    if compare.kind == {
        case .CASE_SENSITIVE;
            end := cast(u64)haystack.data + cast(u64)(haystack.count - needle.count);
            needle_end := cast(u64)needle.count - 1;
            haystack_ptr := cast(u64)haystack.data + cast(u64)start_index;

            end_simd := end - 31;
            if haystack_ptr < end_simd {
                needle_buffer : [32] u8;
                needle_ptr := *needle_buffer;
                memset(needle_ptr, <<needle.data, 32);

                results : struct { index, found : u32; };
                results_data := *results;

                while haystack_ptr < end_simd {
                    #asm {
                        movdqu.y   needle_vec:, [needle_ptr];
                        movdqu.y   haystack_vec:, [haystack_ptr];

                        /* check for equality */
                        pcmpeqb.y  results_vec:, haystack_vec, needle_vec;

                        /* calculate index of first equal character */
                        pmovmskb.y found_gpr:, results_vec;
                        xor.q      index_gpr:, index_gpr;
                        tzcnt.d    index_gpr, found_gpr;

                        /* pack found:index and export */
                        shl.q      found_gpr, 32;
                        or.q       found_gpr, index_gpr;
                        mov.q      [results_data], found_gpr;
                    }

                    if results.found {
                        word_index := haystack_ptr + results.index;
                        second_character_index := word_index + 1;
                        needle_index := needle.data + 1;
                        for character: second_character_index .. word_index + needle_end {
                            if <<cast(*u8)character != <<needle_index {
                                haystack_ptr = second_character_index;
                                break;
                            }
                            needle_index += 1;
                        }
                        if haystack_ptr < second_character_index {
                            return cast(int)(word_index - cast(u64)haystack.data), true;
                        }
                    }
                    else
                        haystack_ptr += 32;
                }
            }

            for index: haystack_ptr .. end {
                needle_index := needle.data;
                for character: index .. index + needle_end {
                    if <<cast(*u8)character != <<needle_index
                        continue index;
                    needle_index += 1;
                }
                return cast(int)(index - cast(u64)haystack.data), true;
            }

            return -1, false;


        case .IGNORE_CASE;
            end := cast(u64)haystack.data + cast(u64)(haystack.count - needle.count);
            needle_end := cast(u64)needle.count - 1;
            haystack_ptr := cast(u64)haystack.data + cast(u64)start_index;

            end_simd := end - 31;
            if haystack_ptr < end_simd {
                needle_buffer : [32] u8;
                needle_ptr := *needle_buffer;
                memset(needle_ptr, <<needle.data, 32);

                case_bit :: 32;
                case_bytes := #insert #run make_32(case_bit);
                a_bytes    := #insert #run make_32(#char "a");
                z_bytes    := #insert #run make_32(#char "z");

                case_ptr := *case_bytes;
                a_ptr := *a_bytes;
                z_ptr := *z_bytes;

                results : struct { index, found : u32; };
                results_data := *results;

                while haystack_ptr < end_simd {
                    #asm {
                        movdqu.y case_vec: vec, [case_ptr];
                        movdqu.y a_vec:, [a_ptr];
                        movdqu.y z_vec:, [z_ptr];

                        movdqu.y needle_vec:, [needle_ptr];
                        movdqu.y haystack_vec:, [haystack_ptr];

                        /* check for case-sensitive equality */
                        pcmpeqb.y result_cased_vec:, needle_vec, haystack_vec;

                        /* check for ignore-case equality */
                        por.y haystack_vec, haystack_vec, case_vec;
                        por.y needle_vec, needle_vec, case_vec;
                        pcmpeqb.y result_nocase_vec:, needle_vec, haystack_vec;

                        /* generate mask for which bits should be case-sensitive */
                        pcmpgtb.y mask_vec:, haystack_vec, z_vec;

                        pcmpgtb.y bounds_vec:, a_vec, haystack_vec;
                        por.y mask_vec, mask_vec, bounds_vec;

                        /* apply mask to keep case-sensitive bits */
                        pand.y result_cased_vec, result_cased_vec, mask_vec;

                        /* invert mask then apply it to keep ignore-case bits */
                        pcmpeqb.y bounds_vec, bounds_vec, bounds_vec;
                        pxor.y mask_vec, mask_vec, bounds_vec;
                        pand.y result_nocase_vec, result_nocase_vec, mask_vec;

                        /* combine results */
                        por.y result_cased_vec, result_cased_vec, result_nocase_vec;

                        /* calculate index of first equal character */
                        pmovmskb.y found_gpr:, result_cased_vec;
                        xor.q index_gpr:, index_gpr;
                        tzcnt.d index_gpr, found_gpr;

                        /* pack found:index and export */
                        shl.q found_gpr, 32;
                        or.q found_gpr, index_gpr;
                        mov.q [results_data], found_gpr;
                    }

                    if results.found {
                        word_index := haystack_ptr + results.index;
                        second_character_index := word_index + 1;
                        needle_index := needle.data + 1;
                        for character: second_character_index .. word_index + needle_end {
                            if !no_case_compare(<<cast(*u8)character, <<needle_index) {
                                haystack_ptr = second_character_index;
                                break;
                            }
                            needle_index += 1;
                        }
                        if haystack_ptr < second_character_index {
                            return cast(int)(word_index - cast(u64)haystack.data), true;
                        }
                    }
                    else
                        haystack_ptr += 32;
                }
            }

            for index: haystack_ptr .. end {
                needle_index := needle.data;
                for character: index .. index + needle_end {
                    if !no_case_compare(<<cast(*u8)character, <<needle_index)
                        continue index;
                    needle_index += 1;
                }
                return cast(int)(index - cast(u64)haystack.data), true;
            }

            return -1, false;


        case;
            end := cast(u64)haystack.data + cast(u64)(haystack.count - needle.count);
            needle_end := cast(u64)needle.count - 1;
            for haystack_ptr: cast(u64)haystack.data + cast(u64)start_index .. end {
                needle_index := needle.data;
                for character: haystack_ptr .. haystack_ptr + needle_end {
                    if !compare.compare(<<cast(*u8)character, <<needle_index)
                        continue haystack_ptr;
                    needle_index += 1;
                }
                return cast(int)(haystack_ptr - cast(u64)haystack.data), true;
            }

            return -1, false;
    }
}


simple_avx2_last_index :: (haystack: string, needle: string, start_index: int, compare: Character_Compare) -> index: int, found: bool {
    if needle == ""  return start_index - 1, true;
    if start_index < needle.count  return -1, false;

    if compare.kind == {
        case .CASE_SENSITIVE;
            needle_end := needle.count - 1;
            haystack_ptr := cast(u64)haystack.data + cast(u64)(start_index - needle_end);
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
                    #asm {
                        movdqu.y   needle_vec:, [needle_ptr];
                        movdqu.y   haystack_vec:, [next_haystack_ptr];

                        /* check for equality */
                        pcmpeqb.y  results_vec:, haystack_vec, needle_vec;

                        /* calculate index of last equal character */
                        pmovmskb.y found_gpr:, results_vec;
                        xor.q      index_gpr:, index_gpr;
                        lzcnt.d    index_gpr, found_gpr;

                        /* pack found:index and export */
                        shl.q      found_gpr, 32;
                        or.q       found_gpr, index_gpr;
                        mov.q      [results_data], found_gpr;
                    }

                    if results.found {
                        word_index := haystack_ptr - results.index - 1;
                        needle_index := needle.data + 1;
                        for character: word_index + 1 .. word_index + cast(u64)needle_end {
                            if <<cast(*u8)character != <<needle_index {
                                haystack_ptr = word_index;
                                break;
                            }
                            needle_index += 1;
                        }
                        if haystack_ptr > word_index {
                            return cast(int)(word_index - cast(u64)haystack.data), true;
                        }
                    }
                    else
                        haystack_ptr = next_haystack_ptr;
                }
            }

            for < index: haystack_ptr .. end {
                needle_index := needle.data;
                for character: index .. index + cast(u64)needle_end {
                    if <<cast(*u8)character != <<needle_index
                        continue index;
                    needle_index += 1;
                }
                return cast(int)(index - cast(u64)haystack.data), true;
            }

            return -1, false;


        case .IGNORE_CASE;
            needle_end := needle.count - 1;
            haystack_ptr := cast(u64)haystack.data + cast(u64)(start_index - needle_end);
            end := cast(u64)haystack.data;

            end_simd := end + 31;
            if haystack_ptr > end_simd {
                needle_buffer : [32] u8;
                needle_ptr := *needle_buffer;
                memset(needle_ptr, <<needle.data, 32);

                case_bit :: 32;
                case_bytes := #insert #run make_32(case_bit);
                a_bytes    := #insert #run make_32(#char "a");
                z_bytes    := #insert #run make_32(#char "z");

                case_ptr := *case_bytes;
                a_ptr := *a_bytes;
                z_ptr := *z_bytes;

                results : struct { index, found : u32; };
                results_data := *results;

                while haystack_ptr > end_simd {
                    next_haystack_ptr := haystack_ptr - 32;
                    #asm {
                        movdqu.y case_vec:, [case_ptr];
                        movdqu.y a_vec:, [a_ptr];
                        movdqu.y z_vec:, [z_ptr];

                        movdqu.y needle_vec:, [needle_ptr];
                        movdqu.y haystack_vec:, [next_haystack_ptr];

                        /* check for case-sensitive equality */
                        pcmpeqb.y result_cased_vec:, needle_vec, haystack_vec;

                        /* check for ignore-case equality */
                        por.y haystack_vec, haystack_vec, case_vec;
                        por.y needle_vec, needle_vec, case_vec;
                        pcmpeqb.y result_nocase_vec:, needle_vec, haystack_vec;

                        /* generate mask for which bits should be case-sensitive */
                        pcmpgtb.y mask_vec:, haystack_vec, z_vec;
                        pcmpgtb.y bounds_vec:, a_vec, haystack_vec;
                        por.y mask_vec, mask_vec, bounds_vec;

                        /* apply mask to keep case-sensitive bits */
                        pand.y result_cased_vec, result_cased_vec, mask_vec;

                        /* invert mask then apply it to keep ignore-case bits */
                        pcmpeqb.y bounds_vec, bounds_vec, bounds_vec;
                        pxor.y mask_vec, mask_vec, bounds_vec;
                        pand.y result_nocase_vec, result_nocase_vec, mask_vec;

                        /* combine results */
                        por.y result_cased_vec, result_cased_vec, result_nocase_vec;

                        /* calculate index of first equal character */
                        pmovmskb.y found_gpr:, result_cased_vec;
                        xor.q index_gpr:, index_gpr;
                        lzcnt.d index_gpr, found_gpr;

                        /* pack found:index and export */
                        shl.q found_gpr, 32;
                        or.q found_gpr, index_gpr;
                        mov.q [results_data], found_gpr;
                    }

                    if results.found {
                        word_index := haystack_ptr - results.index - 1;
                        needle_index := needle.data + 1;
                        for character: word_index + 1 .. word_index + cast(u64)needle_end {
                            if !no_case_compare(<<cast(*u8)character, <<needle_index) {
                                haystack_ptr = word_index;
                                break;
                            }
                            needle_index += 1;
                        }
                        if haystack_ptr > word_index {
                            return cast(int)(word_index - cast(u64)haystack.data), true;
                        }
                    }
                    else
                        haystack_ptr = next_haystack_ptr;
                }
            }

            for < index: haystack_ptr .. end {
                needle_index := needle.data;
                for character: index .. index + cast(u64)needle_end {
                    if !no_case_compare(<<cast(*u8)character, <<needle_index)
                        continue index;
                    needle_index += 1;
                }
                return cast(int)(index - cast(u64)haystack.data), true;
            }

            return -1, false;


        case;
            needle_end := needle.count - 1;
            start := cast(u64)haystack.data + cast(u64)(start_index - needle_end);
            for < start_of_match: start .. cast(u64)haystack.data {
                needle_index := needle.data;
                for character: start_of_match .. start_of_match + cast(u64)needle_end {
                    if !compare.compare(<<cast(*u8)character, <<needle_index)
                        continue start_of_match;
                    needle_index += 1;
                }
                return cast(int)(start_of_match - cast(u64)haystack.data), true;
            }

            return -1, false;
    }
}





#scope_file



make_16 :: (value: u8) -> string {
    return sprint("u8.[%1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1];", value);
}

make_32 :: (value: u8) -> string {
    return sprint("u8.[%1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1];", value);
}

no_case_compare :: inline (a: u8, b: u8) -> bool {
    return (ifx a >= #char "A" && a <= #char "Z" then a | 32 else a)
        == (ifx b >= #char "A" && b <= #char "Z" then b | 32 else b);
}



/*
naive_with_simd_test_first_index :: (haystack: string, needle: string, start_index: int, compare: Character_Compare) -> index: int, found: bool {
    if start_index > haystack.count - needle.count  return -1, false;

    handled := false;

    if compare.kind == {
        case .CASE_SENSITIVE;
            handled = true;

            if simd_mode == {
                case .OFF;
                    end := cast(u64)haystack.data + cast(u64)(haystack.count - needle.count);
                    needle_end := cast(u64)needle.count - 1;
                    for test_index: cast(u64)haystack.data + cast(u64)start_index .. end {
                        needle_index := needle.data;
                        for character: test_index .. test_index + needle_end {
                            if <<cast(*u8)character != <<needle_index
                                continue test_index;
                            needle_index += 1;
                        }
                        return cast(int)(test_index - cast(u64)haystack.data), true;
                    }
                case .SSE2;
                    end := cast(u64)haystack.data + cast(u64)(haystack.count - needle.count);
                    needle_end := cast(u64)needle.count - 1;
                    test_index := cast(u64)haystack.data + cast(u64)start_index;

                    end_simd := end - 15;
                    if test_index < end_simd {
                        needle_buffer : [16] u8;
                        needle_ptr := *needle_buffer;
                        memset(needle_ptr, <<needle.data, 16);

#if true {
                        // 13.051240    13.722530
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
else {
                        // 14.304011    15.433144
                        results : struct { found : u16; index : u16; } #align 16;
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

                                /* pack index:found and export */
                                shl.d      index_gpr, 16;
                                or.d       index_gpr, found_gpr;
                                mov.d      [results_data], index_gpr;
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
                case .AVX2;
                    end := cast(u64)haystack.data + cast(u64)(haystack.count - needle.count);
                    needle_end := cast(u64)needle.count - 1;
                    test_index := cast(u64)haystack.data + cast(u64)start_index;

                    end_simd := end - 31;
                    if test_index < end_simd {
                        needle_buffer : [32] u8;
                        needle_ptr := *needle_buffer;
                        memset(needle_ptr, <<needle.data, 32);

                        results : struct { index, found : u32; };
                        results_data := *results;

                        while test_index < end_simd {
                            #asm {
                                movdqu.y   needle_vec:, [needle_ptr];
                                movdqu.y   haystack_vec:, [test_index];

                                /* check for equality */
                                pcmpeqb.y  results_vec:, haystack_vec, needle_vec;
                                pmovmskb.y found_gpr:, results_vec;

                                /* calculate index of first equal character */
                                xor.q      index_gpr:, index_gpr;
                                tzcnt.d    index_gpr, found_gpr;

                                /* pack found:index and export */
                                shl.q      found_gpr, 32;
                                or.q       found_gpr, index_gpr;
                                mov.q      [results_data], found_gpr;
                            }

#if true {
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
                                test_index += 32;
}
else {
                            while results.found {
                                //print("% %\n", results.found, results.index);
                                word_index := test_index + results.index;
                                second_index := word_index + 1;
                                needle_index := needle.data + 1;
                                found := true;
                                for character: second_index .. word_index + needle_end {
                                    if <<cast(*u8)character != <<needle_index {
                                        found = false;
                                        break;
                                    }
                                    needle_index += 1;
                                }
                                if found  return cast(int)(word_index - cast(u64)haystack.data), true;

                                //results.index = ~(cast(u32)1 << results.index);
                                //print("%\n", results.index);

                                debug : u16;

                                #asm {
                                    /* load result back in*/
                                    mov.q found_gpr:, [results_data];
                                    mov.d index_gpr:, found_gpr;
                                    shr.q found_gpr, 32;

                                    /* get index bit */
                                    cl : gpr === c;
                                    mov.b cl, index_gpr;
                                    mov.d index_gpr, 1;
                                    shl.d index_gpr, cl;

                                    /* remove index bit from found flags */
                                    not.d index_gpr;
                                    and.d found_gpr, index_gpr;

                                    /* calculate index */
                                    tzcnt.d index_gpr, found_gpr;
                                    shl.q found_gpr, 32;
                                    or.q found_gpr, index_gpr;
                                    mov.q [results_data], found_gpr;
                                }
                            }

                            test_index += 32;
}
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
            }

        case .IGNORE_CASE;
            if simd_mode == {
                case .SSE2;
                case .AVX2;
            }
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
