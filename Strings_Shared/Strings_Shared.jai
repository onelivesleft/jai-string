#import "Basic";
#import "Machine_X64";


Index_Proc :: #type(haystack: string, needle: string, boundary_index: int, reverse: bool) -> from_index: int, to_index: int, found: bool;
String_Index_Proc :: #type(haystack: string, needle: string, from_index: int, compare: Character_Compare) -> index: int, found: bool;

Character_Compare :: struct {
    kind : enum { CASE_SENSITIVE; IGNORE_CASE; CUSTOM; };
    compare : #type(a: u8, b: u8) -> bool;
}

operator== :: (a: Character_Compare, b: Character_Compare) -> bool {
    return a.kind == b.kind && a.compare == b.compare;
}


#scope_file
simd_mode : enum { OFF; AUTO; SSE; AVX2; } = .SSE;
#scope_export

get_simd_mode :: () -> type_of(simd_mode) {
    return simd_mode;
}

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


slice_index :: inline (str: string, index: int) -> normalized_index: int, valid_when_strict: bool {
    if index < 0  index += str.count;

    if index > str.count  return str.count, false;
    else if index < 0     return 0, false;
    else                  return index, true;
}


to_lower :: (str: string) {
    for 0 .. str.count - 1 {
        if str[it] >= #char "A" && str[it] <= #char "Z" {
            c : int = str[it] + #char "a" - #char "A";
            str[it] = cast(u8) c;
        }
    }
}


to_upper :: (str: string) {
    for 0 .. str.count - 1 {
        if str[it] >= #char "a" && str[it] <= #char "z" {
            c : int = str[it] + #char "A" - #char "a";
            str[it] = cast(u8) c;
        }
    }
}


to_capitalized :: (str: string, preserve_caps := true) {
    if !str  return;

    str[0] = to_upper(str[0]);
    if !preserve_caps
        for 1 .. str.count - 1
            str[it] = to_lower(str[it]);
}


is_lower :: inline (char: u8) -> bool {
    return char >= #char "a" && char <= #char "z";
}


is_upper :: inline (char: u8) -> bool {
    return char >= #char "A" && char <= #char "Z";
}


//bit_masks_16 := u8.[0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
//                    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
//                    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF];
//
//bit_mask_16_zero : *u8 = (cast(*u8)*bit_masks_16) + 16;

// @TODO why does this crash when declared here?

/*
bit_masks_32 := u8.[0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
                    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF];
bit_mask_32_zero := *bit_masks_32 + 32;
*/



equal :: (a: string, b: string, compare : Character_Compare) -> bool {
    if compare.kind == .CASE_SENSITIVE
        return a == b;

    if a.count != b.count  return false;

    for index: 0 .. a.count - 1
        if !compare.compare(a[index], b[index])
            return false;

    return true;
}



starts_with :: inline (haystack: string, needle: string, compare : Character_Compare) -> bool {
    if haystack.count < needle.count  return false;

    return equal(unsafe_slice(haystack, 0, needle.count), needle, compare);
}


starts_with :: inline (haystack: string, needle: u8, compare : Character_Compare) -> bool {
    return haystack.count > 0 && compare.compare(haystack[0], needle);
}


starts_with :: inline (haystack: string, needle: [] u8, compare : Character_Compare) -> bool {
    return haystack.count > 0 && is_any(haystack[0], needle, compare);
}


starts_with :: inline (haystack: string, needle: string, $$index: Index_Proc) -> bool {
    return index(haystack, needle, 0, false) == 0;
}


ends_with :: inline (haystack: string, needle: string, compare: Character_Compare) -> bool {
    if haystack.count < needle.count  return false;

    return equal(unsafe_slice(haystack, haystack.count - needle.count), needle, compare);
}


ends_with :: inline (haystack: string, needle: u8, compare: Character_Compare) -> bool {
    return haystack.count > 0 && compare.compare(haystack[haystack.count - 1], needle);
}


ends_with :: inline (haystack: string, needle: [] u8, compare: Character_Compare) -> bool {
    return haystack.count > 0 && is_any(haystack[haystack.count - 1], needle, compare);
}


ends_with :: inline (haystack: string, needle: string, $$index: Index_Proc) -> bool {
    from_index, to_index, found := index(haystack, needle, haystack.count, true);
    return to_index == haystack.count;
}


advance_to :: (haystack: *string, needle: u8, compare: Character_Compare) -> characters_skipped: int {
    index, found := first_index(<<haystack, needle, compare);

    if !found  index = haystack.count;
    haystack.data += index;
    haystack.count -= index;

    return index;
}

advance_to :: (haystack: *string, needle: [] u8, compare: Character_Compare) -> characters_skipped: int {
    if needle.count == 0  return 0;

    index, found := first_index(<<haystack, needle, compare);

    if !found  index = haystack.count;
    haystack.data += index;
    haystack.count -= index;

    return index;
}

advance_to :: (haystack: *string, needle: string, compare: Character_Compare, string_index_proc: String_Index_Proc) -> characters_skipped: int {
    if needle.count == 0  return 0;

    index, found := first_index(<<haystack, needle, compare, string_index_proc);

    if !found  index = haystack.count;
    haystack.data += index;
    haystack.count -= index;

    return index;
}

advance_to :: (haystack: *string, needle: string, $$index_proc: Index_Proc) -> characters_skipped: int {
    index, found := first_index(<<haystack, needle, index_proc);

    if !found  index = haystack.count;
    haystack.data += index;
    haystack.count -= index;

    return index;
}


advance_past :: (haystack: *string, needle: u8, compare: Character_Compare) -> characters_skipped: int {
    index, found := first_index(<<haystack, needle, compare);

    if found  index += 1;
    else      index = haystack.count;

    haystack.data += index;
    haystack.count -= index;

    return index;
}

advance_past :: (haystack: *string, needle: [] u8, compare: Character_Compare) -> characters_skipped: int {
    if needle.count == 0  return 0;

    index, found := first_index(<<haystack, needle, compare);

    if found {
        while index < haystack.count && is_any((<<haystack)[index], needle, compare)
            index += 1;
        index += 1;
    }
    else
        index = haystack.count;

    haystack.data += index;
    haystack.count -= index;

    return index;
}

advance_past :: (haystack: *string, needle: string, compare: Character_Compare, string_index_proc: String_Index_Proc) -> characters_skipped: int {
    if needle.count == 0  return 0;

    index, found := first_index(<<haystack, needle, compare, string_index_proc);

    if found  index += needle.count;
    else      index = haystack.count;

    haystack.data += index;
    haystack.count -= index;

    return index;
}

advance_past :: (haystack: *string, needle: string, $$index_proc: Index_Proc) -> characters_skipped: int {
    index, found, to_index := first_index(<<haystack, needle, index_proc);

    if found  index = to_index;
    else      index = haystack.count;

    haystack.data += index;
    haystack.count -= index;

    return index;
}


trim :: (str: string, char: u8, compare: Character_Compare) -> string {
    low_index := 0;
    high_index := str.count - 1;

    while low_index < str.count && compare.compare(str[low_index], char)
        low_index += 1;

    if low_index >= str.count  return "";

    while compare.compare(str[high_index], char)
        high_index -= 1;

    return unsafe_slice(str, low_index, high_index + 1);
}


trim :: (str: string, chars : [] u8, compare: Character_Compare) -> string {
    if chars.count == 0  return str;

    low_index := 0;
    high_index := str.count - 1;

    while low_index < str.count && is_any(str[low_index], chars, compare)
        low_index += 1;

    if low_index >= str.count  return "";

    while is_any(str[high_index], chars, compare)
        high_index -= 1;

    return unsafe_slice(str, low_index, high_index + 1);
}


trim :: (str: string, string_to_remove: string, compare : Character_Compare) -> string {
    s := str;
    while starts_with(s, string_to_remove, compare)
        s = unsafe_slice(s, string_to_remove.count);

    if !s  return "";

    while ends_with(s, string_to_remove, compare)
        s = unsafe_slice(s, 0, s.count - string_to_remove.count);

    return s;
}


trim :: (str: string, string_to_remove: string, $$index: Index_Proc) -> string {
    s := str;
    from_index, to_index, found := index(s, string_to_remove, 0, false);
    while s && from_index == 0 {
        s = unsafe_slice(s, to_index);
        from_index, to_index, found = index(s, string_to_remove, 0, false);
    }

    if !s  return "";

    from_index, to_index, found = index(s, string_to_remove, s.count, true);
    while s && to_index == s.count {
        s = unsafe_slice(s, 0, from_index);
        from_index, to_index, found = index(s, string_to_remove, s.count, true);
    }

    return s;
}


trim_start :: (str: string, char: u8, compare: Character_Compare) -> string {
    index := 0;

    while index < str.count && compare.compare(str[index], char)
        index += 1;

    if index >= str.count  return "";

    return unsafe_slice(str, index);
}


trim_start :: (str: string, chars : [] u8, compare: Character_Compare) -> string {
    if chars.count == 0  return str;

    index := 0;

    while index < str.count && is_any(str[index], chars, compare)
        index += 1;

    if index >= str.count  return "";

    return unsafe_slice(str, index);
}


trim_start :: (str: string, string_to_remove: string, compare : Character_Compare) -> string {
    if string_to_remove == ""  return str;

    s := str;
    while starts_with(s, string_to_remove, compare)
        s = unsafe_slice(s, string_to_remove.count);

    return s;
}


trim_start :: (str: string, string_to_remove: string, $$index: Index_Proc) -> string {
    s := str;
    from_index, to_index, found := index(s, string_to_remove, 0, false);
    while s && from_index == 0 {
        s = unsafe_slice(s, to_index);
        from_index, to_index, found = index(s, string_to_remove, 0, false);
    }

    return s;
}


trim_start_to :: (str: string, char: u8, compare: Character_Compare) -> string {
    index := 0;

    while index < str.count && compare.compare(str[index], char)
        index += 1;

    if index >= str.count  return "";

    return unsafe_slice(str, index);
}


trim_end :: inline (str: string, char: u8, compare: Character_Compare) -> string {
    index := str.count - 1;

    while index >= 0 && compare.compare(str[index], char)
        index -= 1;

    if index < 0  return "";

    return unsafe_slice(str, 0, index + 1);
}


trim_end :: inline (str: string, chars : [] u8, compare: Character_Compare) -> string {
    if chars.count == 0  return str;

    index := str.count - 1;

    while index >= 0 && is_any(str[index], chars, compare)
        index -= 1;

    if index < 0  return "";

    return unsafe_slice(str, 0, index + 1);
}


trim_end :: (str: string, string_to_remove: string, compare : Character_Compare) -> string {
    if string_to_remove == ""  return str;

    s := str;
    while ends_with(s, string_to_remove, compare)
        s = unsafe_slice(s, 0, s.count - string_to_remove.count);

    return s;
}


trim_end :: (str: string, string_to_remove: string, $$index: Index_Proc) -> string {
    s := str;
    from_index, to_index, found := index(s, string_to_remove, s.count, true);
    while s && to_index == s.count {
        s = unsafe_slice(s, 0, from_index);
        from_index, to_index, found = index(s, string_to_remove, s.count, true);
    }

    return s;
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

validate_from_index :: (str: string) #expand {
    if `from_index < 0  `from_index = clamp(str.count + `from_index, 0, str.count);
    else                 `from_index = clamp(`from_index, 0, str.count);
}

#scope_export


first_index :: (haystack: string, needle: u8, from_index: int, compare: Character_Compare) -> index: int, found: bool {
    validate_from_index(haystack);

    handled := false;

    if compare.kind == {
        case .CASE_SENSITIVE;
            data := cast(u64)haystack.data + cast(u64)from_index;
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
                            movdqu.x   needle_vec:, [needle_data];
                            movdqu.x   haystack_vec:, [data];
                            pcmpeqb.x  results_vec:, haystack_vec, needle_vec;
                            pmovmskb.x found_gpr:, results_vec;
                            tzcnt.w    index_gpr:, found_gpr;
                            shl.d      found_gpr, 16;
                            or.w       found_gpr, index_gpr;
                            mov.d      [results_data], found_gpr;
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
                            movdqu.y   needle_vec:,    [needle_data];
                            movdqu.y   haystack_vec:,  [data];
                            pcmpeqb.y  results_vec:,   haystack_vec, needle_vec;
                            pmovmskb.y found_gpr:,     results_vec;
                            xor.q      index_gpr:,     index_gpr;
                            tzcnt.d    index_gpr,      found_gpr;
                            shl.q      found_gpr,      32;
                            or.q       found_gpr,      index_gpr;
                            mov.q      [results_data], found_gpr;
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
            data := cast(u64)haystack.data + cast(u64)from_index;
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
                            movdqu.x case_vec: vec, [case_data];
                            movdqu.x a_vec:, [a_data];
                            movdqu.x z_vec:, [z_data];

                            movdqu.x needle_vec:, [needle_data];
                            movdqu.x haystack_vec:, [data];
                            pcmpeqb.x result_cased_vec:, needle_vec, haystack_vec;

                            por.x haystack_vec, case_vec;
                            por.x needle_vec, case_vec;
                            pcmpeqb.x result_nocase_vec:, needle_vec, haystack_vec;

                            movdqa.x mask_vec:, haystack_vec;
                            pcmpgtb.x mask_vec, z_vec;

                            movdqa.x bounds_vec:, a_vec;
                            pcmpgtb.x bounds_vec, haystack_vec;
                            por.x mask_vec, bounds_vec;
                            pand.x result_cased_vec, mask_vec;

                            pcmpeqb.x bounds_vec, bounds_vec, bounds_vec;
                            pxor.x mask_vec, bounds_vec;

                            pand.x result_nocase_vec, mask_vec;
                            por.x result_cased_vec, result_nocase_vec;

                            pmovmskb.x found_gpr:, result_cased_vec;
                            tzcnt.w index_gpr:, found_gpr;
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
                            movdqu.y case_vec:, [case_data];
                            movdqu.y a_vec:, [a_data];
                            movdqu.y z_vec:, [z_data];

                            movdqu.y needle_vec:, [needle_data];
                            movdqu.y haystack_vec:, [data];
                            pcmpeqb.y result_cased_vec:, needle_vec, haystack_vec;


                            por.y haystack_vec, haystack_vec, case_vec;
                            por.y needle_vec, needle_vec, case_vec;
                            pcmpeqb.y result_nocase_vec:, needle_vec, haystack_vec;

                            pcmpgtb.y mask_vec:, haystack_vec, z_vec;

                            pcmpgtb.y bounds_vec:, a_vec, haystack_vec;
                            por.y mask_vec, mask_vec, bounds_vec;
                            pand.y result_cased_vec, result_cased_vec, mask_vec;

                            pcmpeqb.y bounds_vec, bounds_vec, bounds_vec;
                            pxor.y mask_vec, mask_vec, bounds_vec;

                            pand.y result_nocase_vec, result_nocase_vec, mask_vec;
                            por.y result_cased_vec, result_cased_vec, result_nocase_vec;

                            pmovmskb.y found_gpr:, result_cased_vec;
                            xor.q index_gpr:, index_gpr;
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

    // @TODO make case_sensitive and ignore_case versions of below loop

    if !handled {
        for cast(u64)haystack.data + cast(u64)from_index .. cast(u64)haystack.data + cast(u64)haystack.count - 1
            if compare.compare(<<cast(*u8)it, needle)
                return cast(int)(it - cast(u64)haystack.data), true;
    }

    return -1, false;
}


first_index :: inline (haystack: string, needle: u8, compare: Character_Compare) -> index: int, found: bool {
    index, found := first_index(haystack, needle, 0, compare);
    return index, found;
}


first_index :: (haystack: string, needle: [] u8, from_index: int, compare: Character_Compare) -> index: int, found: bool {
    validate_from_index(haystack);

    for cast(u64)haystack.data + cast(u64)from_index .. cast(u64)haystack.data + cast(u64)haystack.count - 1
        if is_any(<<cast(*u8)it, needle, compare)
            return cast(int)(it - cast(u64)haystack.data), true;

    return -1, false;
}

first_index :: inline (haystack: string, needle: [] u8, compare: Character_Compare) -> index: int, found: bool {
    index, found := first_index(haystack, needle, 0, compare);
    return index, found;
}


first_index :: (haystack: string, needle: string, from_index: int, compare : Character_Compare, string_index_proc: String_Index_Proc) -> index: int, found: bool {
    validate_from_index(haystack);
    if needle.count == 0 {
        return from_index, true;
    }
    else if needle.count == 1 {
        index, found := first_index(haystack, << needle.data, from_index, compare);
        return index, found;
    }
    else {
        index, found := string_index_proc(haystack, needle, from_index, compare);
        return index, found;
    }
}


first_index :: inline (haystack: string, needle: string, compare: Character_Compare, string_index_proc: String_Index_Proc) -> index: int, found: bool {
    index, found := first_index(haystack, needle, 0, compare, string_index_proc);
    return index, found;
}


first_index :: inline (haystack: string, needle: string, from_index: int, $$index: Index_Proc) -> from_index: int, found: bool, to_index: int {
    from_index, to_index, found := index(haystack, needle, from_index, false);
    return from_index, found, to_index;
}


first_index :: inline (haystack: string, needle: string, $$index: Index_Proc) -> from_index: int, found: bool, to_index: int {
    from_index, to_index, found := index(haystack, needle, 0, false);
    return from_index, found, to_index;
}


last_index :: inline (haystack: string, needle: u8, compare: Character_Compare) -> index: int, found: bool {
    index, found := last_index(haystack, needle, haystack.count, compare);
    return index, found;
}


last_index :: (haystack: string, needle: u8, from_index: int, compare: Character_Compare) -> index: int, found: bool {
    if from_index == 0  return -1, false;

    from_index -= 1;
    validate_from_index(haystack);

    handled := false;

    if compare.kind == {
        case .CASE_SENSITIVE;
            if simd_mode == {
                case .SSE;
                    if from_index >= 15 {
                        handled = true;

                        data := cast(u64)haystack.data + cast(u64)from_index - 15;
                        end := cast(u64)haystack.data;

                        needles : [16] u8 = ---;
                        memset(needles.data, needle, 16);
                        needle_data := needles.data;

                        results : struct { index, found : u16; };
                        results_data := *results;

                        while data >= end {
                            #asm {
                                movdqu.x needle_vec:, [needle_data];
                                movdqu.x haystack_vec:, [data];
                                pcmpeqb.x results_vec:, haystack_vec, needle_vec;
                                pmovmskb.x found_gpr:, results_vec;
                                lzcnt.w index_gpr:, found_gpr;
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
                    if from_index >= 31 {
                        handled = true;

                        data := cast(u64)haystack.data + cast(u64)from_index - 31;
                        end := cast(u64)haystack.data;

                        needles : [32] u8 = ---;
                        memset(needles.data, needle, 32);
                        needle_data := needles.data;

                        results : struct { index, found : u32; };
                        results_data := *results;

                        while data >= end {
                            #asm {
                                movdqu.y needle_vec:, [needle_data];
                                movdqu.y haystack_vec:, [data];
                                pcmpeqb.y results_vec:, haystack_vec, needle_vec;
                                pmovmskb.y found_gpr:, results_vec;
                                xor.q index_gpr:, index_gpr;
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
                    if from_index >= 15 {
                        handled = true;

                        data := cast(u64)haystack.data + cast(u64)from_index - 15;
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
                                movdqu.x case_vec:, [case_data];
                                movdqu.x a_vec:, [a_data];
                                movdqu.x z_vec:, [z_data];

                                movdqu.x needle_vec:, [needle_data];
                                movdqu.x haystack_vec:, [data];
                                pcmpeqb.x result_cased_vec:, needle_vec, haystack_vec;

                                por.x haystack_vec, case_vec;
                                por.x needle_vec, case_vec;
                                pcmpeqb.x result_nocase_vec:, needle_vec, haystack_vec;

                                movdqa.x mask_vec:, haystack_vec;
                                pcmpgtb.x mask_vec, z_vec;

                                movdqa.x bounds_vec:, a_vec;
                                pcmpgtb.x bounds_vec, haystack_vec;
                                por.x mask_vec, bounds_vec;
                                pand.x result_cased_vec, mask_vec;

                                pcmpeqb.x bounds_vec, bounds_vec, bounds_vec;
                                pxor.x mask_vec, bounds_vec;

                                pand.x result_nocase_vec, mask_vec;
                                por.x result_cased_vec, result_nocase_vec;

                                pmovmskb.x found_gpr:, result_cased_vec;
                                lzcnt.w index_gpr:, found_gpr;
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
                    if from_index >= 31 {
                        handled = true;

                        data := cast(u64)haystack.data + cast(u64)from_index - 31;
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
                                movdqu.y case_vec:, [case_data];
                                movdqu.y a_vec:, [a_data];
                                movdqu.y z_vec:, [z_data];

                                movdqu.y needle_vec:, [needle_data];
                                movdqu.y haystack_vec:, [data];
                                pcmpeqb.y result_cased_vec:, needle_vec, haystack_vec;

                                por.y haystack_vec, haystack_vec, case_vec;
                                por.y needle_vec, needle_vec, case_vec;
                                pcmpeqb.y result_nocase_vec:, needle_vec, haystack_vec;

                                pcmpgtb.y mask_vec:, haystack_vec, z_vec;

                                pcmpgtb.y bounds_vec:, a_vec, haystack_vec;
                                por.y mask_vec, mask_vec, bounds_vec;
                                pand.y result_cased_vec, result_cased_vec, mask_vec;

                                pcmpeqb.y bounds_vec, bounds_vec, bounds_vec;
                                pxor.y mask_vec, mask_vec, bounds_vec;

                                pand.y result_nocase_vec, result_nocase_vec, mask_vec;
                                por.y result_cased_vec, result_cased_vec, result_nocase_vec;

                                pmovmskb.y found_gpr:, result_cased_vec;
                                xor.q index_gpr:, index_gpr;
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
        for < cast(u64)haystack.data + cast(u64)from_index .. cast(u64)haystack.data
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


last_index :: (haystack: string, needle: [] u8, from_index : int, compare: Character_Compare) -> index: int, found: bool {
    if from_index == 0  return -1, false;

    from_index -= 1;
    validate_from_index(haystack);

    for < cast(u64)haystack.data + cast(u64)from_index .. cast(u64)haystack.data
        if is_any(<<cast(*u8)it, needle, compare)
            return cast(int)(it - cast(u64)haystack.data), true;

    return -1, false;
}


last_index :: inline (haystack: string, needle: string, from_index: int, compare: Character_Compare, last_string_index : String_Index_Proc) -> index: int, found: bool {
    validate_from_index(haystack);
    if needle.count == 0 {
        return from_index, true;
    }
    else if needle.count == 1 {
        index, found := last_index(haystack, << needle.data, from_index, compare);
        return index, found;
    }
    else {
        index, found := last_string_index(haystack, needle, from_index, compare);
        return index, found;
    }
}


last_index :: inline (haystack: string, needle: string, compare: Character_Compare, last_string_index : String_Index_Proc) -> index: int, found: bool {
    index, found := last_index(haystack, needle, haystack.count, compare, last_string_index);
    return index, found;
}


last_index :: inline (haystack: string, needle: string, from_index: int, $$index: Index_Proc) -> from_index: int, found: bool, to_index: int {
    from_index, to_index, found := index(haystack, needle, from_index, true);
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
    compare     : Character_Compare;
}


Split_By_String :: struct {
    using base: Split_By;
    separator : string;
    first_index : String_Index_Proc;
    last_index  : String_Index_Proc;
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
    keep_end := false;
}


Split_By_Proc :: struct {
    using base: Split_By;
    separator : string;
    index_proc : Index_Proc;
}


#scope_file

fill_split_struct :: () #expand {
    `split_struct.text        = `text;
    `split_struct.max_results = `max_results;
    `split_struct.skip_empty  = `skip_empty;
}

#scope_export



make_split :: (text: string, separator: string, compare: Character_Compare, first_index_proc: String_Index_Proc, last_index_proc: String_Index_Proc, skip_empty := false, max_results := 0) -> Split_By_String {
    split_struct : Split_By_String = ---;
    fill_split_struct();
    split_struct.separator = separator;
    split_struct.compare = compare;
    split_struct.first_index = first_index_proc;
    split_struct.last_index = last_index_proc;
    return split_struct;
}


make_split :: (text: string, separator: [] u8, compare: Character_Compare, skip_empty := false, max_results := 0) -> Split_By_Chars {
    split_struct : Split_By_Chars = ---;
    fill_split_struct();
    split_struct.compare = compare;
    split_struct.separator = separator;
    return split_struct;
}


make_split :: (text: string, separator: u8, compare: Character_Compare, skip_empty := false, max_results := 0) -> Split_By_Char {
    split_struct : Split_By_Char = ---;
    fill_split_struct();
    split_struct.compare = compare;
    split_struct.separator = separator;
    return split_struct;
}


make_split :: (text: string, indexes: [] int, skip_empty := false, max_results := 0) -> Split_By_Index {
    split_struct : Split_By_Index = ---;
    fill_split_struct();
    split_struct.indexes = indexes;
    return split_struct;
}


make_split :: (text: string, separator: string, index_proc: Index_Proc, skip_empty := false, max_results := 0) -> Split_By_Proc {
    split_struct : Split_By_Proc = ---;
    fill_split_struct();
    split_struct.separator = separator;
    split_struct.index_proc = index_proc;
    return split_struct;
}


make_line_split :: (text: string, keep_end := false, skip_empty := false, max_results := 0) -> Split_By_Line {
    split_struct : Split_By_Line = ---;
    fill_split_struct();
    split_struct.compare = case_sensitive;
    split_struct.keep_end = keep_end;
    return split_struct;
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

        if reverse {
            end_index := splitter.text.count;
            index, found := last_index(splitter.text, splitter.separator, splitter.compare, splitter.last_index);
            while found {
                it = unsafe_slice(splitter.text, index + splitter.separator.count, end_index);
                end_index = index;

                if splitter.skip_empty && it == ""  continue;

                it_index += 1;

                #insert body;

                if splitter.max_results != 0 && it_index >= max_it_index
                    break;

                index, found = last_index(splitter.text, splitter.separator, index, splitter.compare, splitter.last_index);
            }

            it = unsafe_slice(splitter.text, 0, end_index);
        }
        else {
            start_index := 0;
            index, found := first_index(splitter.text, splitter.separator, splitter.compare, splitter.first_index);
            while found {
                it = unsafe_slice(splitter.text, start_index, index);
                start_index = index + splitter.separator.count;

                if splitter.skip_empty && it == ""  continue;

                it_index += 1;

                #insert body;

                if splitter.max_results != 0 && it_index >= max_it_index
                    break;

                index, found = first_index(splitter.text, splitter.separator, start_index, splitter.compare, splitter.first_index);
            }

            it = unsafe_slice(splitter.text, start_index);
        }

        if !splitter.skip_empty || it != "" {
            it_index += 1;

            #insert body;
        }
    }
}


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

            it = unsafe_slice(splitter.text, 0, end_index);
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

            it = unsafe_slice(splitter.text, start_index);
        }

        if !splitter.skip_empty || it != "" {
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

        if reverse {
            end_index := splitter.text.count;
            for < index: splitter.text.count - 1 .. 0 {
                if is_any(splitter.text[index], splitter.separator, splitter.compare) {
                    it = unsafe_slice(splitter.text, index + 1, end_index);
                    end_index = index;

                    if splitter.skip_empty && it == ""  continue;

                    it_index += 1;

                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;
                }
            }

            it = unsafe_slice(splitter.text, 0, end_index);
        }
        else {
            start_index := 0;
            for index: 0 .. splitter.text.count - 1 {
                if is_any(splitter.text[index], splitter.separator, splitter.compare) {
                    it = unsafe_slice(splitter.text, start_index, index);
                    start_index = index + 1;

                    if splitter.skip_empty && it == ""  continue;

                    it_index += 1;

                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;
                }
            }

            it = unsafe_slice(splitter.text, start_index);
        }

        if !splitter.skip_empty || it != "" {
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

            it = unsafe_slice(splitter.text, 0, end_index);
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

            it = unsafe_slice(splitter.text, start_index);
        }

        if !splitter.skip_empty || it != "" {
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

        if reverse {
            end_index := splitter.text.count;
            for < index, splitter_index: splitter.indexes {
                start_index := slice_index(splitter.text, ifx index < end_index then index else end_index);
                it = unsafe_slice(splitter.text, start_index, end_index);
                end_index = start_index;

                if splitter.skip_empty && it == ""  continue;

                it_index += 1;

                #insert body;

                if splitter.max_results != 0 && it_index >= max_it_index
                    break;
            }

            it = unsafe_slice(splitter.text, 0, end_index);
        }
        else {
            start_index := 0;
            for index, splitter_index: splitter.indexes {
                start_index = slice_index(splitter.text, start_index);
                end_index := slice_index(splitter.text, ifx index > start_index then index else start_index);
                it = unsafe_slice(splitter.text, start_index, end_index);
                start_index = end_index;

                if splitter.skip_empty && it == ""  continue;

                it_index += 1;

                #insert body;

                if splitter.max_results != 0 && it_index >= max_it_index
                    break;
            }

            it = unsafe_slice(splitter.text, start_index);
        }

        if !splitter.skip_empty || it != "" {
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

    if splitter.text == "" || (splitter.max_results != 0 && splitter.max_results < 2) {
        it = splitter.text;
        it_index = 0;

        #insert body;
    }
    else {
        max_it_index := ifx splitter.max_results == 0 then 0 else splitter.max_results - 2;
        complete := false;

        if reverse {
            end_index := splitter.text.count;
            start_index := splitter.text.count - 1;
            if splitter.text[start_index] == Chars.LF
                start_index -= 1;

            for < index: start_index .. 0 {
                if splitter.text[index] == Chars.LF {
                    if splitter.keep_end {
                        it = unsafe_slice(splitter.text, index + 1, end_index);
                    }
                    else {
                        it = unsafe_slice(splitter.text, index + 1, end_index - 1);
                        if it && it[it.count - 1] == Chars.CR
                            it.count -= 1;
                    }
                    end_index = index + 1;

                    if splitter.skip_empty && it_is_empty()  continue;

                    it_index += 1;
                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;
                }
            }

            if splitter.keep_end {
                it = unsafe_slice(splitter.text, 0, end_index);
            }
            else {
                it = unsafe_slice(splitter.text, 0, end_index - 1);
                if it && it[it.count - 1] == Chars.CR
                    it.count -= 1;
            }

            if !splitter.skip_empty || !it_is_empty() {
                it_index += 1;
                #insert body;
            }
        }
        else {
            start_index := 0;

            for index: 0 .. splitter.text.count - 1 {
                if splitter.text[index] == Chars.LF {
                    if splitter.keep_end {
                        it = unsafe_slice(splitter.text, start_index, index + 1);
                    }
                    else {
                        it = unsafe_slice(splitter.text, start_index, index);
                        if it && it[it.count - 1] == Chars.CR
                            it.count -= 1;
                    }
                    start_index = index + 1;

                    if splitter.skip_empty && it_is_empty()  continue;

                    it_index += 1;
                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;
                }
            }

            if start_index < splitter.text.count {
                it = unsafe_slice(splitter.text, start_index);
                if it && it[it.count - 1] == Chars.CR  it.count -= 1;

                if !splitter.skip_empty || !it_is_empty() {
                    it_index += 1;
                    #insert body;
                }
            }
        }
    }

    it_is_empty :: () -> bool #expand {
        if `splitter.keep_end
            return `it.count == 1 || `it.count == 2 && `it[0] == Chars.CR;
        else
            return `it == "";
    }
}


Chars :: struct {
    SPACE :: #char " ";
    TAB   :: #char "\t";
    CR    :: #char "\r";
    LF    :: #char "\n";
    NBSP  :: #char " "; // careful!
    WHITESPACE :: u8.[SPACE, TAB, CR, LF];
}
