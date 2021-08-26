#import "Basic";
#import "Machine_X64";


Character_Compare :: struct {
    kind : enum { CASE_SENSITIVE; IGNORE_CASE; CUSTOM; };
    compare : #type(a: u8, b: u8) -> bool;
}

Index_Proc :: #type(haystack: string, needle: string, boundary_index: int, reverse: bool) -> from_index: int, to_index: int, found: bool;


#scope_file

String_Index_Proc :: #type(haystack: string, needle: string, start_index: int, compare: Character_Compare) -> index: int, found: bool;

simd_mode : enum { OFF; AUTO; SSE; AVX2; } = .SSE;

#scope_export


set_simd_mode :: (mode: type_of(simd_mode)) {
    if mode == .AUTO {
        if get_cpu_info().AVX2
            simd_mode = .AVX2;
        else
            simd_mode = .SSE;
    }
    else
        simd_mode = mode;
}


is_any :: inline (needle: u8, characters: [] u8, compare : Character_Compare) -> bool {
    for character: characters
        if compare.compare(needle, character)  return true;

    return false;
}


case_sensitive :: Character_Compare.{
    .CASE_SENSITIVE,
    (a: u8, b: u8) -> bool {
        return a == b;
    }
};


ignore_case :: Character_Compare.{
    .IGNORE_CASE,
    (a: u8, b: u8) -> bool {
        return (ifx a >= #char "A" && a <= #char "Z" then a | 32 else a)
            == (ifx b >= #char "A" && b <= #char "Z" then b | 32 else b);
    }
};

// ignore_case in asm, but it's slower...
/*
ptr_a := *a;
ptr_b := *b;
result : u8 = 0; // true
ptr_result := *result;
#asm {
    a : gpr;
    b : gpr;
    low : gpr;
    high : gpr;
    mov.b   a, [ptr_a];
    mov.b   b, [ptr_b];
    or.b    a, 32;
    or.b    b, 32;
    xor.b   a, b;
    cmp.b   b, 97;  // a
    setl    low;
    cmp.b   b, 122; // z
    setg    high;
    or.b    a, low;
    or.b    a, high;
    mov.b   [ptr_result], a;
}
return result == 0;
*/


string_from_char :: inline (char: *u8) -> string {
    result : string = ---;
    result.data = char;
    result.count = 1;
    return result;
}


unsafe_slice :: inline (str: string, from_index: int, to_index: int) -> string {
    // @Note Handles positive indexes only!
    assert(from_index >= 0 && from_index <= str.count, "Cannot slice; from_index falls outwith range of string.");
    assert(to_index >= from_index, "Cannot slice; to_index is ahead of from_index.");
    assert(to_index <= str.count, "Cannot slice; to_index falls outwith range of string.");

    result : string = ---;
    result.data = str.data + from_index;
    result.count = to_index - from_index;
    return result;
}


unsafe_slice :: inline (str: string, from_index: int) -> string {
    // @Note Handles positive index only!
    assert(from_index >= 0 && from_index <= str.count, "Cannot slice; from_index falls outwith range of string.");

    result : string = ---;
    result.data = str.data + from_index;
    result.count = str.count - from_index;
    return result;
}


validate_start_index :: (str: string) #expand {
    if `start_index < 0  `start_index = clamp(str.count + `start_index, 0, str.count);
    else                 `start_index = clamp(`start_index, 0, str.count);
}


#scope_file

make_16 :: (value: u8) -> string {
    return sprint("u8.[%1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1];", value);
}

make_32 :: (value: u8) -> string {
    return sprint("u8.[%1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1];", value);
}

make_64 :: (value: u8) -> string {
    return sprint("u8.[%1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1, %1];", value);
}

#scope_export


first_index :: (haystack: string, needle: u8, start_index: int, compare: Character_Compare) -> index: int, found: bool {
    validate_start_index(haystack);

    handled := false;

    if compare.kind == {
        case .CASE_SENSITIVE;
            data := cast(u64)haystack.data + cast(u64)start_index;
            end := cast(u64)haystack.data + cast(u64)haystack.count;

            if simd_mode == {
                case .SSE;
                    handled = true;

                    needles : [16] u8 = ---;
                    memset(needles.data, needle, 16);
                    needle_data := needles.data;

                    // @TODO Update to use two asm blocks - setup + loop - when compiler supports it

                    results : struct { index, found : u16; };
                    results_data := *results;

                    loop_until := end - 15;

                    while data < loop_until {
                        #asm {
                            needle_vec: vec;
                            haystack_vec: vec;
                            results_vec: vec;
                            found_gpr: gpr;
                            index_gpr: gpr;

                            movdqu.x needle_vec, [needle_data];
                            movdqu.x haystack_vec, [data];
                            pcmpeqb.x results_vec, haystack_vec, needle_vec;
                            pmovmskb.x found_gpr, results_vec;
                            tzcnt.w index_gpr, found_gpr;
                            shl.d found_gpr, 16;
                            or.w found_gpr, index_gpr;
                            mov.d [results_data], found_gpr;
                        }

                        if results.found
                            return cast(int)(data - cast(u64)haystack.data + results.index), true;
                        else
                            data += 16;
                    }

                    for data .. min(data + 15, end - 1)
                        if compare.compare(<<cast(*u8)it, needle)
                            return cast(int)(it - cast(u64)haystack.data), true;

                case .AVX2;
                    handled = true;

                    needles : [32] u8 = ---;
                    memset(needles.data, needle, 32);
                    needle_data := needles.data;

                    results : struct { index, found : u32; };
                    results_data := *results;

                    loop_until := end - 31;

                    while data < loop_until {
                        #asm {
                            needle_vec: vec;
                            haystack_vec: vec;
                            results_vec: vec;
                            found_gpr: gpr;
                            index_gpr: gpr;

                            movdqu.y needle_vec, [needle_data];
                            movdqu.y haystack_vec, [data];
                            pcmpeqb.y results_vec, haystack_vec, needle_vec;
                            pmovmskb.y found_gpr, results_vec;
                            xor.q index_gpr, index_gpr;
                            tzcnt.d index_gpr, found_gpr;
                            shl.q found_gpr, 32;
                            or.q found_gpr, index_gpr;
                            mov.q [results_data], found_gpr;
                        }

                        if results.found
                            return cast(int)(data - cast(u64)haystack.data + results.index), true;
                        else
                            data += 32;
                    }

                    for data .. min(data + 31, end - 1)
                        if compare.compare(<<cast(*u8)it, needle)
                            return cast(int)(it - cast(u64)haystack.data), true;
            }

        case .IGNORE_CASE;
            data := cast(u64)haystack.data + cast(u64)start_index;
            end := cast(u64)haystack.data + cast(u64)haystack.count;

            if simd_mode == {
                case .SSE;
                    handled = true;
                    needles : [16] u8 = ---;
                    memset(needles.data, needle, 16);
                    needle_data := needles.data;

                    case_bit :: 32;
                    case_bytes := #insert #run make_16(case_bit);
                    a_bytes    := #insert #run make_16(#char "a");
                    z_bytes    := #insert #run make_16(#char "z");

                    case_data := *case_bytes;
                    a_data := *a_bytes;
                    z_data := *z_bytes;

                    results : struct { index, found : u16; };
                    results_data := *results;

                    loop_until := end - 15;

                    while data < loop_until {
                        #asm {
                            needle_vec: vec;
                            haystack_vec: vec;
                            case_vec: vec;
                            a_vec: vec;
                            z_vec: vec;
                            result_cased_vec: vec;
                            result_nocase_vec: vec;
                            bounds_vec: vec;
                            mask_vec: vec;
                            found_gpr: gpr;
                            index_gpr: gpr;

                            movdqu.x case_vec, [case_data];
                            movdqu.x a_vec, [a_data];
                            movdqu.x z_vec, [z_data];

                            movdqu.x needle_vec, [needle_data];
                            movdqu.x haystack_vec, [data];
                            pcmpeqb.x result_cased_vec, needle_vec, haystack_vec;

                            por.x haystack_vec, case_vec;
                            por.x needle_vec, case_vec;
                            pcmpeqb.x result_nocase_vec, needle_vec, haystack_vec;

                            movdqa.x mask_vec, haystack_vec;
                            pcmpgtb.x mask_vec, z_vec;

                            movdqa.x bounds_vec, a_vec;
                            pcmpgtb.x bounds_vec, haystack_vec;
                            por.x mask_vec, bounds_vec;
                            pand.x result_cased_vec, mask_vec;

                            pcmpeqb.x bounds_vec, bounds_vec, bounds_vec;
                            pxor.x mask_vec, bounds_vec;

                            pand.x result_nocase_vec, mask_vec;
                            por.x result_cased_vec, result_nocase_vec;

                            pmovmskb.x found_gpr, result_cased_vec;
                            tzcnt.w index_gpr, found_gpr;
                            shl.d found_gpr, 16;
                            or.w found_gpr, index_gpr;
                            mov.d [results_data], found_gpr;
                        }

                        if results.found
                            return cast(int)(data - cast(u64)haystack.data + results.index), true;
                        else
                            data += 16;
                    }

                    for data .. min(data + 15, end - 1)
                        if compare.compare(<<cast(*u8)it, needle)
                            return cast(int)(it - cast(u64)haystack.data), true;

                case .AVX2;
                    handled = true;

                    needles : [32] u8 = ---;
                    memset(needles.data, needle, 32);
                    needle_data := needles.data;

                    case_bit :: 32;
                    case_bytes := #insert #run make_32(case_bit);
                    a_bytes    := #insert #run make_32(#char "a");
                    z_bytes    := #insert #run make_32(#char "z");

                    case_data := *case_bytes;
                    a_data := *a_bytes;
                    z_data := *z_bytes;

                    results : struct { index, found : u32; };
                    results_data := *results;

                    loop_until := end - 31;

                    while data < loop_until {
                        #asm {
                            needle_vec: vec;
                            haystack_vec: vec;
                            case_vec: vec;
                            a_vec: vec;
                            z_vec: vec;
                            result_cased_vec: vec;
                            result_nocase_vec: vec;
                            bounds_vec: vec;
                            mask_vec: vec;
                            found_gpr: gpr;
                            index_gpr: gpr;

                            movdqu.y case_vec, [case_data];
                            movdqu.y a_vec, [a_data];
                            movdqu.y z_vec, [z_data];

                            movdqu.y needle_vec, [needle_data];
                            movdqu.y haystack_vec, [data];
                            pcmpeqb.y result_cased_vec, needle_vec, haystack_vec;


                            por.y haystack_vec, haystack_vec, case_vec;
                            por.y needle_vec, needle_vec, case_vec;
                            pcmpeqb.y result_nocase_vec, needle_vec, haystack_vec;

                            pcmpgtb.y mask_vec, haystack_vec, z_vec;

                            pcmpgtb.y bounds_vec, a_vec, haystack_vec;
                            por.y mask_vec, mask_vec, bounds_vec;
                            pand.y result_cased_vec, result_cased_vec, mask_vec;

                            pcmpeqb.y bounds_vec, bounds_vec, bounds_vec;
                            pxor.y mask_vec, mask_vec, bounds_vec;

                            pand.y result_nocase_vec, result_nocase_vec, mask_vec;
                            por.y result_cased_vec, result_cased_vec, result_nocase_vec;

                            pmovmskb.y found_gpr, result_cased_vec;
                            xor.q index_gpr, index_gpr;
                            tzcnt.d index_gpr, found_gpr;
                            shl.q found_gpr, 32;
                            or.q found_gpr, index_gpr;
                            mov.q [results_data], found_gpr;
                        }

                        if results.found
                            return cast(int)(data - cast(u64)haystack.data + results.index), true;
                        else
                            data += 32;
                    }

                    for data .. min(data + 31, end - 1)
                        if compare.compare(<<cast(*u8)it, needle)
                            return cast(int)(it - cast(u64)haystack.data), true;
            }
    }

    if !handled {
        for cast(u64)haystack.data + cast(u64)start_index .. cast(u64)haystack.data + cast(u64)haystack.count - 1
            if compare.compare(<<cast(*u8)it, needle)
                return cast(int)(it - cast(u64)haystack.data), true;
    }

    return -1, false;
}


first_index :: inline (haystack: string, needle: u8, compare: Character_Compare) -> index: int, found: bool {
    index, found := first_index(haystack, needle, 0, compare);
    return index, found;
}


first_index :: (haystack: string, needle: [] u8, start_index := 0, compare: Character_Compare) -> index: int, found: bool {
    validate_start_index(haystack);

    for cast(u64)haystack.data + cast(u64)start_index .. cast(u64)haystack.data + cast(u64)haystack.count - 1
        if is_any(<<cast(*u8)it, needle, compare)
            return cast(int)(it - cast(u64)haystack.data), true;

    return -1, false;
}


first_index :: inline (haystack: string, needle: string, start_index: int, string_index_proc: String_Index_Proc, compare : Character_Compare) -> index: int, found: bool {
    validate_start_index(haystack);
    if needle.count == 0 {
        return start_index, true;
    }
    else if needle.count == 1 {
        index, found := first_index(haystack, << needle.data, start_index, compare);
        return index, found;
    }
    else {
        index, found := string_index_proc(haystack, needle, start_index, compare);
        return index, found;
    }
}


first_index :: inline (haystack: string, needle: string, string_index_proc: String_Index_Proc, compare: Character_Compare) -> index: int, found: bool {
    index, found := first_index(haystack, needle, 0, string_index_proc, compare);
    return index, found;
}


first_index :: inline (haystack: string, needle: string, start_index := 0, $$index: Index_Proc) -> from_index: int, found: bool, to_index: int {
    from_index, to_index, found := index(haystack, needle, start_index, false);
    return from_index, found, to_index;
}



last_index :: inline (haystack: string, needle: u8, compare: Character_Compare) -> index: int, found: bool {
    index, found := last_index(haystack, needle, haystack.count, compare);
    return index, found;
}


last_index :: (haystack: string, needle: u8, start_index: int, compare: Character_Compare) -> index: int, found: bool {
    if start_index == 0  return -1, false;

    start_index -= 1;
    validate_start_index(haystack);

    handled := false;

    if compare.kind == {
        case .CASE_SENSITIVE;
            if simd_mode == {
                case .SSE;
                    if start_index >= 15 {
                        handled = true;

                        data := cast(u64)haystack.data + cast(u64)start_index - 15;
                        end := cast(u64)haystack.data;

                        needles : [16] u8 = ---;
                        memset(needles.data, needle, 16);
                        needle_data := needles.data;

                        results : struct { index, found : u16; };
                        results_data := *results;

                        while data >= end {
                            #asm {
                                needle_vec: vec;
                                haystack_vec: vec;
                                results_vec: vec;
                                found_gpr: gpr;
                                index_gpr: gpr;

                                movdqu.x needle_vec, [needle_data];
                                movdqu.x haystack_vec, [data];
                                pcmpeqb.x results_vec, haystack_vec, needle_vec;
                                pmovmskb.x found_gpr, results_vec;
                                lzcnt.w index_gpr, found_gpr;
                                shl.d found_gpr, 16;
                                or.w found_gpr, index_gpr;
                                mov.d [results_data], found_gpr;
                            }

                            if results.found
                                return cast(int)(data - cast(u64)haystack.data + 15 - results.index), true;
                            else
                                data -= 16;
                        }

                        for < data + 15 .. max(data, end)
                            if compare.compare(<<cast(*u8)it, needle)
                                return cast(int)(it - cast(u64)haystack.data), true;
                    }

                case .AVX2;
                    if start_index >= 31 {
                        handled = true;

                        data := cast(u64)haystack.data + cast(u64)start_index - 31;
                        end := cast(u64)haystack.data;

                        needles : [32] u8 = ---;
                        memset(needles.data, needle, 32);
                        needle_data := needles.data;

                        results : struct { index, found : u32; };
                        results_data := *results;

                        while data >= end {
                            #asm {
                                needle_vec: vec;
                                haystack_vec: vec;
                                results_vec: vec;
                                found_gpr: gpr;
                                index_gpr: gpr;

                                movdqu.y needle_vec, [needle_data];
                                movdqu.y haystack_vec, [data];
                                pcmpeqb.y results_vec, haystack_vec, needle_vec;
                                pmovmskb.y found_gpr, results_vec;
                                xor.q index_gpr, index_gpr;
                                lzcnt.d index_gpr, found_gpr;
                                shl.q found_gpr, 32;
                                or.q found_gpr, index_gpr;
                                mov.q [results_data], found_gpr;
                            }

                            if results.found
                                return cast(int)(data - cast(u64)haystack.data + 31 - results.index), true;
                            else
                                data -= 32;
                        }

                        for < data + 32 .. max(data, end)
                            if compare.compare(<<cast(*u8)it, needle)
                                return cast(int)(it - cast(u64)haystack.data), true;
                    }
            }

        case .IGNORE_CASE;
            if simd_mode == {
                case .SSE;
                    if start_index >= 15 {
                        handled = true;

                        data := cast(u64)haystack.data + cast(u64)start_index - 15;
                        end := cast(u64)haystack.data;

                        needles : [16] u8 = ---;
                        memset(needles.data, needle, 16);
                        needle_data := needles.data;

                        case_bit :: 32;
                        case_bytes := #insert #run make_16(case_bit);
                        a_bytes    := #insert #run make_16(#char "a");
                        z_bytes    := #insert #run make_16(#char "z");

                        case_data := *case_bytes;
                        a_data := *a_bytes;
                        z_data := *z_bytes;

                        results : struct { index, found : u16; };
                        results_data := *results;

                        while data >= end {
                            #asm {
                                needle_vec: vec;
                                haystack_vec: vec;
                                case_vec: vec;
                                a_vec: vec;
                                z_vec: vec;
                                result_cased_vec: vec;
                                result_nocase_vec: vec;
                                bounds_vec: vec;
                                mask_vec: vec;
                                found_gpr: gpr;
                                index_gpr: gpr;

                                movdqu.x case_vec, [case_data];
                                movdqu.x a_vec, [a_data];
                                movdqu.x z_vec, [z_data];

                                movdqu.x needle_vec, [needle_data];
                                movdqu.x haystack_vec, [data];
                                pcmpeqb.x result_cased_vec, needle_vec, haystack_vec;

                                por.x haystack_vec, case_vec;
                                por.x needle_vec, case_vec;
                                pcmpeqb.x result_nocase_vec, needle_vec, haystack_vec;

                                movdqa.x mask_vec, haystack_vec;
                                pcmpgtb.x mask_vec, z_vec;

                                movdqa.x bounds_vec, a_vec;
                                pcmpgtb.x bounds_vec, haystack_vec;
                                por.x mask_vec, bounds_vec;
                                pand.x result_cased_vec, mask_vec;

                                pcmpeqb.x bounds_vec, bounds_vec, bounds_vec;
                                pxor.x mask_vec, bounds_vec;

                                pand.x result_nocase_vec, mask_vec;
                                por.x result_cased_vec, result_nocase_vec;

                                pmovmskb.x found_gpr, result_cased_vec;
                                lzcnt.w index_gpr, found_gpr;
                                shl.d found_gpr, 16;
                                or.w found_gpr, index_gpr;
                                mov.d [results_data], found_gpr;
                            }

                            if results.found
                                return cast(int)(data - cast(u64)haystack.data + 15 - results.index), true;
                            else
                                data -= 16;
                        }

                        for < data + 15 .. max(data, end)
                            if compare.compare(<<cast(*u8)it, needle)
                                return cast(int)(it - cast(u64)haystack.data), true;
                    }

                case .AVX2;
                    if start_index >= 31 {
                        handled = true;

                        data := cast(u64)haystack.data + cast(u64)start_index - 31;
                        end := cast(u64)haystack.data;

                        needles : [32] u8 = ---;
                        memset(needles.data, needle, 32);
                        needle_data := needles.data;

                        case_bit :: 32;
                        case_bytes := #insert #run make_32(case_bit);
                        a_bytes    := #insert #run make_32(#char "a");
                        z_bytes    := #insert #run make_32(#char "z");

                        case_data := *case_bytes;
                        a_data := *a_bytes;
                        z_data := *z_bytes;

                        results : struct { index, found : u32; };
                        results_data := *results;

                        while data >= end {
                            #asm {
                                needle_vec: vec;
                                haystack_vec: vec;
                                case_vec: vec;
                                a_vec: vec;
                                z_vec: vec;
                                result_cased_vec: vec;
                                result_nocase_vec: vec;
                                bounds_vec: vec;
                                mask_vec: vec;
                                found_gpr: gpr;
                                index_gpr: gpr;

                                movdqu.y case_vec, [case_data];
                                movdqu.y a_vec, [a_data];
                                movdqu.y z_vec, [z_data];

                                movdqu.y needle_vec, [needle_data];
                                movdqu.y haystack_vec, [data];
                                pcmpeqb.y result_cased_vec, needle_vec, haystack_vec;

                                por.y haystack_vec, haystack_vec, case_vec;
                                por.y needle_vec, needle_vec, case_vec;
                                pcmpeqb.y result_nocase_vec, needle_vec, haystack_vec;

                                pcmpgtb.y mask_vec, haystack_vec, z_vec;

                                pcmpgtb.y bounds_vec, a_vec, haystack_vec;
                                por.y mask_vec, mask_vec, bounds_vec;
                                pand.y result_cased_vec, result_cased_vec, mask_vec;

                                pcmpeqb.y bounds_vec, bounds_vec, bounds_vec;
                                pxor.y mask_vec, mask_vec, bounds_vec;

                                pand.y result_nocase_vec, result_nocase_vec, mask_vec;
                                por.y result_cased_vec, result_cased_vec, result_nocase_vec;

                                pmovmskb.y found_gpr, result_cased_vec;
                                xor.q index_gpr, index_gpr;
                                lzcnt.d index_gpr, found_gpr;
                                shl.q found_gpr, 32;
                                or.q found_gpr, index_gpr;
                                mov.q [results_data], found_gpr;
                            }

                            if results.found
                                return cast(int)(data - cast(u64)haystack.data + 31 - results.index), true;
                            else
                                data -= 32;
                        }

                        for < data + 31 .. max(data, end)
                            if compare.compare(<<cast(*u8)it, needle)
                                return cast(int)(it - cast(u64)haystack.data), true;
                    }
            }
    }

    if !handled {
        for < cast(u64)haystack.data + cast(u64)start_index .. cast(u64)haystack.data
            if compare.compare(<<cast(*u8)it, needle)
                return cast(int)(it - cast(u64)haystack.data), true;
    }

    return -1, false;
}


last_index :: (haystack: string, needle: [] u8, compare: Character_Compare) -> index: int, found: bool {
    for < cast(u64)haystack.data + cast(u64)haystack.count - 1 .. cast(u64)haystack.data
        if is_any(<<cast(*u8)it, needle, compare)
            return cast(int)(it - cast(u64)haystack.data), true;

    return -1, false;
}


last_index :: (haystack: string, needle: [] u8, start_index : int, compare: Character_Compare) -> index: int, found: bool {
    if start_index == 0  return -1, false;

    start_index -= 1;
    validate_start_index(haystack);

    for < cast(u64)haystack.data + cast(u64)start_index .. cast(u64)haystack.data
        if is_any(<<cast(*u8)it, needle, compare)
            return cast(int)(it - cast(u64)haystack.data), true;

    return -1, false;
}


last_index :: inline (haystack: string, needle: string, start_index: int, index_proc : String_Index_Proc, compare: Character_Compare) -> index: int, found: bool {
    validate_start_index(haystack);
    if needle.count == 0 {
        return start_index, true;
    }
    else if needle.count == 1 {
        index, found := last_index(haystack, << needle.data, start_index, compare);
        return index, found;
    }
    else {
        index, found := index_proc(haystack, needle, start_index, compare);
        return index, found;
    }
}


last_index :: inline (haystack: string, needle: string, index_proc : String_Index_Proc, compare: Character_Compare) -> index: int, found: bool {
    index, found := last_index(haystack, needle, haystack.count, index_proc, compare);
    return index, found;
}


last_index :: inline (haystack: string, needle: string, start_index: int, $$index: Index_Proc) -> from_index: int, found: bool, to_index: int {
    from_index, to_index, found := index(haystack, needle, start_index, true);
    return from_index, found, to_index;
}


last_index :: inline (haystack: string, needle: string, $$index: Index_Proc) -> from_index: int, found: bool, to_index: int {
    from_index, to_index, found := index(haystack, needle, haystack.count, true);
    return from_index, found, to_index;
}



Split_By :: struct {
    text        : string;
    max_results : int;
    skip_empty  : bool;
    first_index : String_Index_Proc;
    last_index  : String_Index_Proc;
    compare     : Character_Compare;
}


Split_By_String :: struct {
    using base: Split_By;
    separator : string;
}


Split_By_Chars :: struct {
    using base: Split_By;
    separator : [] u8;
}


Split_By_Char :: struct {
    using base: Split_By;
    separator : u8;
}


Split_By_Index :: struct {
    using base: Split_By;
    indexes : [] int;
}


Split_By_Line :: struct {
    using base: Split_By;
    keep_eol := false;
}


Split_By_Proc :: struct {
    using base: Split_By;
    separator : string;
    index_proc : Index_Proc;
}


for_expansion :: (splitter: *Split_By_String, body: Code, flags: For_Flags) #expand {
	#assert(!(flags & .POINTER));
    reverse := flags & .REVERSE;

    `it : string = ---;
    `it_index : int = -1;

    if splitter.max_results != 0 && splitter.max_results < 2 {
        it = splitter.text;
        it_index = 0;

        #insert body;
    }
    else {
        max_it_index := ifx splitter.max_results == 0 then 0 else splitter.max_results - 2;
        process_remainder := true;

        if reverse {
            end_index := splitter.text.count;
            index, found := last_index(splitter.text, splitter.separator, splitter.last_index, splitter.compare);
            while found {
                it = unsafe_slice(splitter.text, index + splitter.separator.count, end_index);
                end_index = index;

                if splitter.skip_empty && it == ""  continue;

                it_index += 1;

                #insert body;

                if splitter.max_results != 0 && it_index >= max_it_index
                    break;

                index, found = last_index(splitter.text, splitter.separator, index, splitter.last_index, splitter.compare);
            }

            if process_remainder  it = unsafe_slice(splitter.text, 0, end_index);
        }
        else {
            start_index := 0;
            index, found := first_index(splitter.text, splitter.separator, splitter.first_index, splitter.compare);
            while found {
                it = unsafe_slice(splitter.text, start_index, index);
                start_index = index + splitter.separator.count;

                if splitter.skip_empty && it == ""  continue;

                it_index += 1;

                #insert body;

                if splitter.max_results != 0 && it_index >= max_it_index
                    break;

                index, found = first_index(splitter.text, splitter.separator, start_index, splitter.first_index, splitter.compare);
            }

            if process_remainder  it = unsafe_slice(splitter.text, start_index);
        }

        if process_remainder && (!splitter.skip_empty || it != "") {
            it_index += 1;

            #insert body;
        }
    }
}


// @TODO update these for <

for_expansion :: (splitter: *Split_By_Proc, body: Code, flags: For_Flags) #expand {
	#assert(!(flags & .POINTER));
    reverse := flags & .REVERSE;

    `it : string = ---;
    `it_index : int = -1;

    if splitter.max_results != 0 && splitter.max_results < 2 {
        it = splitter.text;
        it_index = 0;

        #insert body;
    }
    else {
        max_it_index := ifx splitter.max_results == 0 then 0 else splitter.max_results - 2;
        process_remainder := true;

        if reverse {
            end_index := splitter.text.count;
            from_index, to_index, found := splitter.index_proc(splitter.text, splitter.separator, splitter.text.count, true);
            while found {
                it = unsafe_slice(splitter.text, to_index, end_index);
                end_index = from_index;

                if splitter.skip_empty && it == ""  continue;

                it_index += 1;

                #insert body;

                if splitter.max_results != 0 && it_index >= max_it_index
                    break;

                from_index, to_index, found = splitter.index_proc(splitter.text, splitter.separator, from_index, true);
            }

            if process_remainder  it = unsafe_slice(splitter.text, 0, end_index);
        }
        else {
            start_index := 0;
            from_index, to_index, found := splitter.index_proc(splitter.text, splitter.separator, 0, false);
            while found {
                it = unsafe_slice(splitter.text, start_index, from_index);
                start_index = to_index;

                if splitter.skip_empty && it == ""  continue;

                it_index += 1;

                #insert body;

                if splitter.max_results != 0 && it_index >= max_it_index
                    break;

                from_index, to_index, found = splitter.index_proc(splitter.text, splitter.separator, to_index, false);
            }

            if process_remainder  it = unsafe_slice(splitter.text, start_index);
        }

        if process_remainder && (!splitter.skip_empty || it != "") {
            it_index += 1;

            #insert body;
        }
    }
}


for_expansion :: (splitter: *Split_By_Chars, body: Code, flags: For_Flags) #expand {
    #assert(!(flags & .POINTER));
    reverse := flags & .REVERSE;

    `it : string = ---;
    `it_index : int = -1;

    if splitter.max_results != 0 && splitter.max_results < 2 {
        it = splitter.text;
        it_index = 0;

        #insert body;
    }
    else {
        max_it_index := ifx splitter.max_results == 0 then 0 else splitter.max_results - 2;
        process_remainder := true;

        if reverse {
            end_index := splitter.text.count;
            for < index: splitter.text.count - 1 .. 0 {
                if is_any(splitter.text[index], splitter.separator) {
                    it = unsafe_slice(splitter.text, index + 1, end_index);
                    end_index = index;

                    if splitter.skip_empty && it == ""  continue;

                    it_index += 1;

                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;
                }
            }

            if process_remainder  it = unsafe_slice(splitter.text, 0, end_index);
        }
        else {
            start_index := 0;
            for index: 0 .. splitter.text.count - 1 {
                if is_any(splitter.text[index], splitter.separator) {
                    it = unsafe_slice(splitter.text, start_index, index);
                    start_index = index + 1;

                    if splitter.skip_empty && it == ""  continue;

                    it_index += 1;

                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;
                }
            }

            if process_remainder  it = unsafe_slice(splitter.text, start_index);
        }

        if process_remainder && (!splitter.skip_empty || it != "") {
            it_index += 1;

            #insert body;
        }
    }
}



for_expansion :: (splitter: *Split_By_Char, body: Code, flags: For_Flags) #expand {
	#assert(!(flags & .POINTER));
    reverse := flags & .REVERSE;

    `it : string = ---;
    `it_index : int = -1;

    if splitter.max_results != 0 && splitter.max_results < 2 {
        it = splitter.text;
        it_index = 0;

        #insert body;
    }
    else {
        max_it_index := ifx splitter.max_results == 0 then 0 else splitter.max_results - 2;
        process_remainder := true;

        if reverse {
            end_index := splitter.text.count;
            for < index: splitter.text.count - 1 .. 0 {
                if splitter.text[index] == splitter.separator {
                    it = unsafe_slice(splitter.text, index + 1, end_index);
                    end_index = index;

                    if splitter.skip_empty && it == ""  continue;

                    it_index += 1;

                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;;
                }
            }

            if process_remainder  it = unsafe_slice(splitter.text, 0, end_index);
        }
        else {
            start_index := 0;
            for index: 0 .. splitter.text.count - 1 {
                if splitter.text[index] == splitter.separator {
                    it = unsafe_slice(splitter.text, start_index, index);
                    start_index = index + 1;

                    if splitter.skip_empty && it == ""  continue;

                    it_index += 1;

                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;
                }
            }

            if process_remainder  it = unsafe_slice(splitter.text, start_index);
        }

        if process_remainder && (!splitter.skip_empty || it != "") {
            it_index += 1;

            #insert body;
        }
    }
}


for_expansion :: (splitter: *Split_By_Index, body: Code, flags: For_Flags) #expand {
	#assert(!(flags & .POINTER));
    reverse := flags & .REVERSE;

    `it : string = ---;
    `it_index : int = -1;

    if splitter.max_results != 0 && splitter.max_results < 2 {
        it = splitter.text;
        it_index = 0;

        #insert body;
    }
    else {
        max_it_index := ifx splitter.max_results == 0 then 0 else splitter.max_results - 2;
        process_remainder := true;

        if reverse {
            end_index := splitter.text.count;
            upper_bound := splitter.text.count;
            for < index, splitter_index: splitter.indexes {
                it, end_index = slice(splitter.text, index, end_index);
                if end_index < upper_bound
                    upper_bound = end_index;
                else
                    end_index = upper_bound;

                if splitter.skip_empty && it == ""  continue;

                it_index += 1;

                #insert body;

                if splitter.max_results != 0 && it_index >= max_it_index
                    break;
            }

            if process_remainder  it = unsafe_slice(splitter.text, 0, end_index);
        }
        else {
            start_index := 0;
            lower_bound := 0;
            for index, splitter_index: splitter.indexes {
                _ : int;
                it, _, start_index = slice(splitter.text, start_index, index);
                if start_index > lower_bound
                    lower_bound = start_index;
                else
                    start_index = lower_bound;

                if splitter.skip_empty && it == ""  continue;

                it_index += 1;

                #insert body;

                if splitter.max_results != 0 && it_index >= max_it_index
                    break;
            }

            if process_remainder  it = unsafe_slice(splitter.text, start_index);
        }

        if process_remainder && (!splitter.skip_empty || it != "") {
            it_index += 1;

            #insert body;
        }
    }
}


for_expansion :: (splitter: *Split_By_Line, body: Code, flags: For_Flags) #expand {
	#assert(!(flags & .POINTER));
    reverse := flags & .REVERSE;

    `it : string = ---;
    `it_index : int = -1;

    if splitter.max_results != 0 && splitter.max_results < 2 {
        it = splitter.text;
        it_index = 0;

        #insert body;
    }
    else {
        max_it_index := ifx splitter.max_results == 0 then 0 else splitter.max_results - 2;
        process_remainder := true;

        if reverse {
            end_index := splitter.text.count;

            for < index: splitter.text.count - 1 .. 0 {
                if splitter.text[index] == LF {
                    if splitter.keep_eol {
                        it = unsafe_slice(splitter.text, index + 1, end_index);
                    }
                    else {
                        it = unsafe_slice(splitter.text, end_index, index);
                        if ends_with(it, .[LF, CR])  it = unsafe_slice(it, 0, it.count - 1);
                    }
                    end_index = index + 1;

                    if splitter.skip_empty && it == ""  continue;

                    it_index += 1;

                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;
                }
            }
        }
        else {
            start_index := 0;

            for index: 0 .. splitter.text.count - 1 {
                if splitter.text[index] == LF {
                    if splitter.keep_eol {
                        it = unsafe_slice(splitter.text, start_index, index + 1);
                    }
                    else {
                        it = unsafe_slice(splitter.text, start_index, index);
                        if ends_with(it, CR)  it = unsafe_slice(it, 0, it.count - 1);
                    }
                    start_index = index + 1;

                    if splitter.skip_empty && it == ""  continue;

                    it_index += 1;

                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;
                }
            }

            if process_remainder  it = unsafe_slice(splitter.text, start_index);
        }

        if process_remainder && (!splitter.skip_empty || it != "") {
            it_index += 1;

            #insert body;
        }
    }
}
