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


Keep_Separator :: enum {
    NO; AS_PREFIX; AS_POSTFIX;
}



#scope_file

simd_mode : enum { OFF; AUTO; SSE2; AVX2; } = .SSE2;

#scope_export



set_simd_mode :: (mode: type_of(simd_mode)) {
    if mode == {
        case .AUTO;
        cpu_info := get_cpu_info();
        if check_feature(cpu_info.feature_leaves, .AVX2)
            simd_mode = .AVX2;
        else
            simd_mode = .SSE2;

        case .AVX2;
        simd_mode = .AVX2;

        case .SSE2;
        simd_mode = .SSE2;

        case .OFF;
        simd_mode = .OFF;
    }
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
    assert(to_index >= from_index, "Cannot slice; to_index is lower than from_index.");
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



// @TODO look at simding this again when we have data blocks in #asm

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


trim_to :: (str: string, needle: u8, compare: Character_Compare) -> string, found: bool {
    low_index, high_index : int = ---;
    found : bool = ---;

    low_index, found = first_index(str, needle, compare);
    if !found  return str, false;

    high_index = last_index(str, needle, compare);

    return unsafe_slice(str, low_index, high_index + 1), true;
}

trim_to :: (str: string, needle : [] u8, compare: Character_Compare) -> string, found: bool {
    low_index, high_index : int = ---;
    found : bool = ---;

    low_index, found = first_index(str, needle, compare);
    if !found  return str, false;

    high_index = last_index(str, needle, compare);

    return unsafe_slice(str, low_index, high_index + 1), true;
}

trim_to :: (str: string, needle: string, compare : Character_Compare, first_index_proc: String_Index_Proc, last_index_proc: String_Index_Proc) -> string, found: bool {
    low_index, high_index : int = ---;
    found : bool = ---;

    low_index, found = first_index(str, needle, compare, first_index_proc);
    if !found  return str, false;

    high_index = last_index(str, needle, compare, last_index_proc);

    return unsafe_slice(str, low_index, high_index + needle.count), true;
}

trim_to :: (str: string, needle: string, $$index: Index_Proc) -> string, found: bool {
    low_index, high_index, _ : int = ---;
    found : bool = ---;

    low_index, _, found = index(str, needle, 0, false);
    if !found  return str, false;

    _, high_index, found = index(str, needle, str.count, true);
    if !found  return str, false;

    return unsafe_slice(str, low_index, high_index), true;
}


trim_past :: (str: string, needle: u8, compare: Character_Compare) -> string, found: bool {
    low_index, high_index : int = ---;
    found : bool = ---;

    low_index, found = first_index(str, needle, compare);
    if !found  return str, false;

    high_index = last_index(str, needle, compare);

    return unsafe_slice(str, low_index + 1, high_index), true;
}

trim_past :: (str: string, needle : [] u8, compare: Character_Compare) -> string, found: bool {
    low_index, high_index : int = ---;
    found : bool = ---;

    low_index, found = first_index(str, needle, compare);
    if !found  return str, false;

    high_index = last_index(str, needle, compare);

    return unsafe_slice(str, low_index + 1, high_index), true;
}

trim_past :: (str: string, needle: string, compare : Character_Compare, first_index_proc: String_Index_Proc, last_index_proc: String_Index_Proc) -> string, found: bool {
    low_index, high_index : int = ---;
    found : bool = ---;

    low_index, found = first_index(str, needle, compare, first_index_proc);
    if !found  return str, false;

    high_index = last_index(str, needle, compare, last_index_proc);

    return unsafe_slice(str, low_index + needle.count, high_index), true;
}

trim_past :: (str: string, needle: string, $$index: Index_Proc) -> string, found: bool {
    low_index, high_index, _ : int = ---;
    found : bool = ---;

    _, low_index, found = index(str, needle, 0, false);
    if !found  return str, false;

    high_index, _, found = index(str, needle, str.count, true);
    if !found  return str, false;

    return unsafe_slice(str, low_index, high_index), true;
}


trim_start :: (str: string, char: u8, compare: Character_Compare) -> string {
    index := 0;

    while index < str.count && compare.compare(str[index], char)
        index += 1;

    if index >= str.count  return "";

    return unsafe_slice(str, index);
}

trim_start :: (str: string, chars: [] u8, compare: Character_Compare) -> string {
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


trim_start_to :: (str: string, needle: u8, compare: Character_Compare) -> string, found: bool {
    index, found := first_index(str, needle, 0, compare);
    if !found  return str, false;
    return unsafe_slice(str, index), true;
}

trim_start_to :: (str: string, needle: [] u8, compare: Character_Compare) -> string, found: bool {
    index, found := first_index(str, needle, 0, compare);
    if !found  return str, false;
    return unsafe_slice(str, index), true;
}

trim_start_to :: (str: string, needle: string, compare: Character_Compare, string_index_proc: String_Index_Proc) -> string, found: bool {
    if needle == ""  return str, true;
    index, found := first_index(str, needle, 0, compare, string_index_proc);
    if !found  return str, false;
    return unsafe_slice(str, index), true;
}

trim_start_to :: (str: string, needle: string, $$index: Index_Proc) -> string, found: bool {
    index, found := first_index(str, needle, 0, index);
    if !found  return str, false;
    return unsafe_slice(str, index), true;
}


trim_start_past :: (str: string, needle: u8, compare: Character_Compare) -> string, found: bool {
    index, found := first_index(str, needle, 0, compare);
    if !found  return str, false;
    return unsafe_slice(str, index + 1), true;
}

trim_start_past :: (str: string, needle: [] u8, compare: Character_Compare) -> string, found: bool {
    index, found := first_index(str, needle, 0, compare);
    if !found  return str, false;
    return unsafe_slice(str, index + 1), true;
}

trim_start_past :: (str: string, needle: string, compare: Character_Compare, string_index_proc: String_Index_Proc) -> string, found: bool {
    if needle == ""  return str, true;
    index, found := first_index(str, needle, 0, compare, string_index_proc);
    if !found  return str, false;
    return unsafe_slice(str, index + needle.count), true;
}

trim_start_past :: (str: string, needle: string, $$index: Index_Proc) -> string, found: bool {
    from_index, found, to_index := first_index(str, needle, 0, index);
    if !found  return str, false;
    return unsafe_slice(str, to_index), true;
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


trim_end_after :: (str: string, needle: u8, compare: Character_Compare) -> string, found: bool {
    index, found := last_index(str, needle, str.count, compare);
    if !found  return str, false;
    return unsafe_slice(str, 0, index + 1), true;
}

trim_end_after :: (str: string, needle: [] u8, compare: Character_Compare) -> string, found: bool {
    index, found := last_index(str, needle, str.count, compare);
    if !found  return str, false;
    return unsafe_slice(str, 0, index + 1), true;
}

trim_end_after :: (str: string, needle: string, compare: Character_Compare, string_index_proc: String_Index_Proc) -> string, found: bool {
    if needle == ""  return str, true;
    index, found := last_index(str, needle, str.count, compare, string_index_proc);
    if !found  return str, false;
    return unsafe_slice(str, 0, index + needle.count), true;
}

trim_end_after :: (str: string, needle: string, $$index: Index_Proc) -> string, found: bool {
    from_index, found, to_index := last_index(str, needle, str.count, index);
    if !found  return str, false;
    return unsafe_slice(str, 0, to_index), true;
}



trim_end_from :: (str: string, needle: u8, compare: Character_Compare) -> string, found: bool {
    index, found := last_index(str, needle, str.count, compare);
    if !found  return str, false;
    return unsafe_slice(str, 0, index), true;
}

trim_end_from :: (str: string, needle: [] u8, compare: Character_Compare) -> string, found: bool {
    index, found := last_index(str, needle, str.count, compare);
    if !found  return str, false;
    return unsafe_slice(str, 0, index), true;
}

trim_end_from :: (str: string, needle: string, compare: Character_Compare, string_index_proc: String_Index_Proc) -> string, found: bool {
    if needle == ""  return str, true;
    index, found := last_index(str, needle, str.count, compare, string_index_proc);
    if !found  return str, false;
    return unsafe_slice(str, 0, index), true;
}

trim_end_from :: (str: string, needle: string, $$index: Index_Proc) -> string, found: bool {
    from_index, found, to_index := last_index(str, needle, str.count, index);
    if !found  return str, false;
    return unsafe_slice(str, 0, from_index), true;
}


count :: (haystack: string, needle: u8, user_compare: Character_Compare) -> total: int {
    if haystack == ""  return 0;

    compare : Character_Compare = ---;
    if user_compare.kind == .IGNORE_CASE {
        if is_upper(needle) {
            compare = user_compare;
        }
        else if is_lower(needle) {
            needle = to_upper(needle);
            compare = user_compare;
        }
        else {
            compare = case_sensitive;
        }
    }
    else {
        compare = user_compare;
    }

    total := 0;

    if compare.kind == {
        case .CASE_SENSITIVE;
            if simd_mode == {
                case .SSE2;
                    data := cast(u64)haystack.data;
                    end := cast(u64)haystack.data + cast(u64)haystack.count;

                    needles : [16] u8 = ---;
                    memset(needles.data, needle, 16);
                    needle_data := needles.data;

                    // @TODO Update to use two asm blocks - setup + loop - when compiler supports it

                    result : u16 = ---;
                    result_data := *result;

                    loop_until := end - 15;

                    while data < loop_until {
                        #asm {
                            /* check for equality */
                            movdqu.x   needle_vec:, [needle_data];
                            movdqu.x   results_vec:, [data];
                            pcmpeqb.x  results_vec, needle_vec;

                            /* coalesce and count bits */
                            pmovmskb.x found_gpr:, results_vec;
                            popcnt.w   total_gpr:, found_gpr;

                            /* export */
                            mov.w      [result_data], total_gpr;
                        }

                        total += result;
                        data += 16;
                    }

                    for data .. min(data + 15, end - 1)
                        if <<cast(*u8)it == needle
                            total += 1;

                    return total;


                case .AVX2;
                    data := cast(u64)haystack.data;
                    end := cast(u64)haystack.data + cast(u64)haystack.count;

                    needles : [32] u8 = ---;
                    memset(needles.data, needle, 32);
                    needle_data := needles.data;

                    // @TODO Update to use two asm blocks - setup + loop - when compiler supports it

                    result : u32 = ---;
                    result_data := *result;

                    loop_until := end - 31;

                    while data < loop_until {
                        #asm {
                            /* check for equality */
                            movdqu.y   needle_vec:, [needle_data];
                            movdqu.y   results_vec:, [data];
                            pcmpeqb.y  results_vec, results_vec, needle_vec;

                            /* coalesce and count bits */
                            pmovmskb.y found_gpr:, results_vec;
                            popcnt.d   total_gpr:, found_gpr;

                            /* export */
                            mov.d      [result_data], total_gpr;
                        }

                        total += result;
                        data += 32;
                    }

                    for data .. min(data + 31, end - 1)
                        if <<cast(*u8)it == needle
                            total += 1;

                    return total;

            }

        case .IGNORE_CASE;
            if simd_mode == {
                case .SSE2;
                    data := cast(u64)haystack.data;
                    end := cast(u64)haystack.data + cast(u64)haystack.count;

                    needles_upper : [16] u8 = ---;
                    memset(needles_upper.data, needle, 16);
                    needles_upper_data := needles_upper.data;

                    needles_lower : [16] u8 = ---;
                    memset(needles_lower.data, to_lower(needle), 16);
                    needles_lower_data := needles_lower.data;

                    // @TODO Update to use two asm blocks - setup + loop - when compiler supports it

                    result : u16 = ---;
                    result_data := *result;

                    loop_until := end - 15;

                    while data < loop_until {
                        #asm {
                            /* load data */
                            movdqu.x   needles_upper_vec:, [needles_upper_data];
                            movdqu.x   needles_lower_vec:, [needles_lower_data];
                            movdqu.x   results_lower_vec:, [data];

                            /* check for equality */
                            movdqu.x   results_upper_vec:, results_lower_vec;
                            pcmpeqb.x  results_upper_vec, needles_upper_vec;

                            pcmpeqb.x  results_lower_vec, needles_lower_vec;
                            por.x results_lower_vec, results_lower_vec, results_upper_vec;

                            /* coalesce and count bits */
                            pmovmskb.x found_gpr:, results_lower_vec;
                            popcnt.w   total_gpr:, found_gpr;

                            /* export */
                            mov.w      [result_data], total_gpr;
                        }

                        total += result;
                        data += 16;
                    }

                    for data .. min(data + 15, end - 1)
                        if no_case_compare(<<cast(*u8)it, needle)
                            total += 1;

                    return total;


                case .AVX2;
                    data := cast(u64)haystack.data;
                    end := cast(u64)haystack.data + cast(u64)haystack.count;

                    needles_upper : [32] u8 = ---;
                    memset(needles_upper.data, needle, 32);
                    needles_upper_data := needles_upper.data;

                    needles_lower : [32] u8 = ---;
                    memset(needles_lower.data, to_lower(needle), 32);
                    needles_lower_data := needles_lower.data;

                    // @TODO Update to use two asm blocks - setup + loop - when compiler supports it

                    result : u32 = ---;
                    result_data := *result;

                    loop_until := end - 31;

                    while data < loop_until {
                        #asm {
                            /* load data */
                            movdqu.y   needles_upper_vec:, [needles_upper_data];
                            movdqu.y   needles_lower_vec:, [needles_lower_data];
                            movdqu.y   haystack_vec:, [data];

                            /* check for equality */
                            pcmpeqb.y  results_upper_vec:, haystack_vec, needles_upper_vec;
                            pcmpeqb.y  results_lower_vec:, haystack_vec, needles_lower_vec;
                            por.y      results_lower_vec, results_lower_vec, results_upper_vec;

                            /* coalesce and count bits */
                            pmovmskb.y found_gpr:, results_lower_vec;
                            popcnt.d   total_gpr:, found_gpr;

                            /* export */
                            mov.d      [result_data], total_gpr;
                        }

                        total += result;
                        data += 32;
                    }

                    for data .. min(data + 31, end - 1)
                        if no_case_compare(<<cast(*u8)it, needle)
                            total += 1;

                    return total;
            }
    }

    for 0 .. haystack.count - 1 {
        if compare.compare(haystack[it], needle) {
            total += 1;
        }
    }

    return total;
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

no_case_compare :: inline (a: u8, b: u8) -> bool {
    return (ifx a >= #char "A" && a <= #char "Z" then a | 32 else a)
        == (ifx b >= #char "A" && b <= #char "Z" then b | 32 else b);
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
                case .SSE2;
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
                            /* check for equality */
                            movdqu.x   needle_vec:, [needle_data];
                            movdqu.x   results_vec:, [data];
                            pcmpeqb.x  results_vec, needle_vec;

                            /* calculate index of first equal character */
                            pmovmskb.x found_gpr:, results_vec;
                            tzcnt.w    index_gpr:, found_gpr;

                            /* pack found:index and export */
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

                            /* calculate index of first equal character */
                            pmovmskb.y found_gpr:,     results_vec;
                            xor.q      index_gpr:,     index_gpr;
                            tzcnt.d    index_gpr,      found_gpr;

                            /* pack found:index and export */
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
                case .SSE2;
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

                            /* check for case-sensitive equality */
                            movdqu.x result_cased_vec:, haystack_vec;
                            pcmpeqb.x result_cased_vec, needle_vec, haystack_vec;

                            /* check for ignore-case equality */
                            por.x haystack_vec, case_vec;
                            por.x needle_vec, case_vec;
                            movdqu.x result_nocase_vec:, haystack_vec;
                            pcmpeqb.x result_nocase_vec, needle_vec;

                            /* generate mask for which bits should be case-sensitive */
                            movdqa.x mask_vec:, haystack_vec;
                            pcmpgtb.x mask_vec, z_vec;

                            movdqa.x bounds_vec:, a_vec;
                            pcmpgtb.x bounds_vec, haystack_vec;
                            por.x mask_vec, bounds_vec;

                            /* apply mask to keep case-sensitive bits */
                            pand.x result_cased_vec, mask_vec;

                            /* invert mask then apply it to keep ignore-case bits */
                            pcmpeqb.x bounds_vec, bounds_vec;
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
                case .SSE2;
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
                                /* check for equality */
                                movdqu.x needle_vec:, [needle_data];
                                movdqu.x results_vec:, [data];
                                pcmpeqb.x results_vec, needle_vec;

                                /* calculate index of last equal character */
                                pmovmskb.x found_gpr:, results_vec;
                                lzcnt.w index_gpr:, found_gpr;

                                /* pack found:index and export */
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

                                /* calculate index of last equal character */
                                pmovmskb.y found_gpr:, results_vec;
                                xor.q index_gpr:, index_gpr;
                                lzcnt.d index_gpr, found_gpr;

                                /* pack found:index and export */
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
                case .SSE2;
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

                                /* check for case-sensitive equality */
                                movdqu.x result_cased_vec:, haystack_vec;
                                pcmpeqb.x result_cased_vec, needle_vec;

                                /* check for ignore-case equality */
                                por.x haystack_vec, case_vec;
                                por.x needle_vec, case_vec;
                                movdqu.x result_nocase_vec:, haystack_vec;
                                pcmpeqb.x result_nocase_vec, needle_vec;

                                /* generate mask for which bits should be case-sensitive */
                                movdqa.x mask_vec:, haystack_vec;
                                pcmpgtb.x mask_vec, z_vec;

                                movdqa.x bounds_vec:, a_vec;
                                pcmpgtb.x bounds_vec, haystack_vec;
                                por.x mask_vec, bounds_vec;

                                /* apply mask to keep case-sensitive bits */
                                pand.x result_cased_vec, mask_vec;

                                /* invert mask then apply it to keep ignore-case bits */
                                pcmpeqb.x bounds_vec, bounds_vec;
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
    text           : string;
    max_results    : int;
    skip_empty     : bool;
    keep_separator : Keep_Separator;
    compare        : Character_Compare;
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
}


Split_By_Proc :: struct {
    using base: Split_By;
    separator : string;
    index_proc : Index_Proc;
}


#scope_file

fill_split_struct :: () #expand {
    `split_struct.text           = `text;
    `split_struct.max_results    = `max_results;
    `split_struct.skip_empty     = `skip_empty;
    `split_struct.keep_separator = `keep_separator;
}

#scope_export



make_split :: (text: string, separator: string, compare: Character_Compare, first_index_proc: String_Index_Proc, last_index_proc: String_Index_Proc, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> Split_By_String {
    split_struct : Split_By_String = ---;
    fill_split_struct();
    split_struct.separator = separator;
    split_struct.compare = compare;
    split_struct.first_index = first_index_proc;
    split_struct.last_index = last_index_proc;
    return split_struct;
}


make_split :: (text: string, separator: [] u8, compare: Character_Compare, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> Split_By_Chars {
    split_struct : Split_By_Chars = ---;
    fill_split_struct();
    split_struct.compare = compare;
    split_struct.separator = separator;
    return split_struct;
}


make_split :: (text: string, separator: u8, compare: Character_Compare, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> Split_By_Char {
    split_struct : Split_By_Char = ---;
    fill_split_struct();
    split_struct.compare = compare;
    split_struct.separator = separator;
    return split_struct;
}


make_split :: (text: string, indexes: [] int, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> Split_By_Index {
    split_struct : Split_By_Index = ---;
    fill_split_struct();
    split_struct.indexes = indexes;
    return split_struct;
}


make_split :: (text: string, separator: string, index_proc: Index_Proc, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> Split_By_Proc {
    split_struct : Split_By_Proc = ---;
    fill_split_struct();
    split_struct.separator = separator;
    split_struct.index_proc = index_proc;
    return split_struct;
}


make_line_split :: (text: string, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> Split_By_Line {
    split_struct : Split_By_Line = ---;
    fill_split_struct();
    split_struct.compare = case_sensitive;
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
        separator_offset_to_start, separator_offset_to_end, empty_count : int = ---;

        if reverse {
            end_index := splitter.text.count;
            index, found := last_index(splitter.text, splitter.separator, splitter.compare, splitter.last_index);
            if splitter.keep_separator == {
                case .NO;
                empty_count = 0;
                separator_offset_to_start = splitter.separator.count;
                separator_offset_to_end = 0;

                case .AS_PREFIX;
                empty_count = splitter.separator.count;
                separator_offset_to_start = 0;
                separator_offset_to_end = 0;

                case .AS_POSTFIX;
                empty_count = splitter.separator.count;
                separator_offset_to_start = splitter.separator.count;
                separator_offset_to_end = splitter.separator.count;
            }

            while found {
                it = unsafe_slice(splitter.text, index + separator_offset_to_start, end_index);
                end_index = index + separator_offset_to_end;

                if !splitter.skip_empty || it.count != empty_count {
                    it_index += 1;
                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;
                }

                index, found = last_index(splitter.text, splitter.separator, index, splitter.compare, splitter.last_index);
            }

            it = unsafe_slice(splitter.text, 0, end_index);
        }
        else {
            start_index := 0;
            index, found := first_index(splitter.text, splitter.separator, splitter.compare, splitter.first_index);
            if splitter.keep_separator == {
                case .NO;
                empty_count = 0;
                separator_offset_to_start = splitter.separator.count;
                separator_offset_to_end = 0;

                case .AS_PREFIX;
                empty_count = splitter.separator.count;
                separator_offset_to_start = 0;
                separator_offset_to_end = 0;

                case .AS_POSTFIX;
                empty_count = splitter.separator.count;
                separator_offset_to_start = splitter.separator.count;
                separator_offset_to_end = splitter.separator.count;
            }

            while found {
                it = unsafe_slice(splitter.text, start_index, index + separator_offset_to_end);
                start_index = index + separator_offset_to_start;

                if !splitter.skip_empty || it.count != empty_count {
                    it_index += 1;
                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;
                }

                index, found = first_index(splitter.text, splitter.separator, index + splitter.separator.count, splitter.compare, splitter.first_index);
            }

            it = unsafe_slice(splitter.text, start_index);
        }

        if !splitter.skip_empty || it.count != empty_count {
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
                if #complete splitter.keep_separator == {
                    case .AS_PREFIX;
                    it = unsafe_slice(splitter.text, from_index, end_index);
                    end_index = from_index;

                    case .AS_POSTFIX;
                    it = unsafe_slice(splitter.text, to_index, end_index);
                    end_index = to_index;

                    case .NO;
                    it = unsafe_slice(splitter.text, to_index, end_index);
                    end_index = from_index;
                }

                if !splitter.skip_empty || it != "" {
                    it_index += 1;
                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;
                }

                from_index, to_index, found = splitter.index_proc(splitter.text, splitter.separator, from_index, true);
            }

            it = unsafe_slice(splitter.text, 0, end_index);
        }
        else {
            start_index := 0;
            from_index, to_index, found := splitter.index_proc(splitter.text, splitter.separator, 0, false);
            while found {
                if #complete splitter.keep_separator == {
                    case .AS_PREFIX;
                    it = unsafe_slice(splitter.text, start_index, from_index);
                    start_index = from_index;

                    case .AS_POSTFIX;
                    it = unsafe_slice(splitter.text, start_index, to_index);
                    start_index = to_index;

                    case .NO;
                    it = unsafe_slice(splitter.text, start_index, from_index);
                    start_index = to_index;
                }

                if !splitter.skip_empty || it != "" {
                    it_index += 1;
                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;
                }

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
        separator_offset_to_start, separator_offset_to_end, empty_count : int = ---;

        if reverse {
            end_index := splitter.text.count;
            index, found := last_index(splitter.text, splitter.separator, splitter.compare);
            if splitter.keep_separator == {
                case .NO;
                empty_count = 0;
                separator_offset_to_start = 1;
                separator_offset_to_end = 0;

                case .AS_PREFIX;
                empty_count = 1;
                separator_offset_to_start = 0;
                separator_offset_to_end = 0;

                case .AS_POSTFIX;
                empty_count = 1;
                separator_offset_to_start = 1;
                separator_offset_to_end = 1;
            }

            while found {
                it = unsafe_slice(splitter.text, index + separator_offset_to_start, end_index);
                end_index = index + separator_offset_to_end;

                if !splitter.skip_empty || it.count != empty_count {
                    it_index += 1;
                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;
                }

                index, found = last_index(splitter.text, splitter.separator, index, splitter.compare);
            }

            it = unsafe_slice(splitter.text, 0, end_index);
        }
        else {
            start_index := 0;
            index, found := first_index(splitter.text, splitter.separator, splitter.compare);
            if splitter.keep_separator == {
                case .NO;
                empty_count = 0;
                separator_offset_to_start = 1;
                separator_offset_to_end = 0;

                case .AS_PREFIX;
                empty_count = 1;
                separator_offset_to_start = 0;
                separator_offset_to_end = 0;

                case .AS_POSTFIX;
                empty_count = 1;
                separator_offset_to_start = 1;
                separator_offset_to_end = 1;
            }

            while found {
                it = unsafe_slice(splitter.text, start_index, index + separator_offset_to_end);
                start_index = index + separator_offset_to_start;

                if !splitter.skip_empty || it.count != empty_count {
                    it_index += 1;
                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;
                }

                index, found = first_index(splitter.text, splitter.separator, index + 1, splitter.compare);
            }

            it = unsafe_slice(splitter.text, start_index);
        }

        if !splitter.skip_empty || it.count != empty_count {
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
        separator_offset_to_start, separator_offset_to_end, empty_count : int = ---;

        if reverse {
            end_index := splitter.text.count;
            index, found := last_index(splitter.text, splitter.separator, splitter.compare);
            if splitter.keep_separator == {
                case .NO;
                empty_count = 0;
                separator_offset_to_start = 1;
                separator_offset_to_end = 0;

                case .AS_PREFIX;
                empty_count = 1;
                separator_offset_to_start = 0;
                separator_offset_to_end = 0;

                case .AS_POSTFIX;
                empty_count = 1;
                separator_offset_to_start = 1;
                separator_offset_to_end = 1;
            }

            while found {
                it = unsafe_slice(splitter.text, index + separator_offset_to_start, end_index);
                end_index = index + separator_offset_to_end;

                if !splitter.skip_empty || it.count != empty_count {
                    it_index += 1;
                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;
                }

                index, found = last_index(splitter.text, splitter.separator, index, splitter.compare);
            }

            it = unsafe_slice(splitter.text, 0, end_index);
        }
        else {
            start_index := 0;
            index, found := first_index(splitter.text, splitter.separator, splitter.compare);
            if splitter.keep_separator == {
                case .NO;
                empty_count = 0;
                separator_offset_to_start = 1;
                separator_offset_to_end = 0;

                case .AS_PREFIX;
                empty_count = 1;
                separator_offset_to_start = 0;
                separator_offset_to_end = 0;

                case .AS_POSTFIX;
                empty_count = 1;
                separator_offset_to_start = 1;
                separator_offset_to_end = 1;
            }

            while found {
                it = unsafe_slice(splitter.text, start_index, index + separator_offset_to_end);
                start_index = index + separator_offset_to_start;

                if !splitter.skip_empty || it.count != empty_count {
                    it_index += 1;
                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;
                }

                index, found = first_index(splitter.text, splitter.separator, index + 1, splitter.compare);
            }

            it = unsafe_slice(splitter.text, start_index);
        }

        if !splitter.skip_empty || it.count != empty_count {
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

        if reverse {
            index := splitter.text.count;
            end_index : int = ---;
            found := false;

            if #complete splitter.keep_separator == {
                case .AS_PREFIX;
                end_index = index;

                case .AS_POSTFIX;
                end_index = index;
                if splitter.text[index - 1] == Chars.LF  index -= 1;

                case .NO;
                if splitter.text[index - 1] == Chars.LF  index -= 1;
                if index > 0 && splitter.text[index - 1] == Chars.CR  index -= 1;
                end_index = index;
            }

            index, found = last_index(splitter.text, Chars.LF, index, splitter.compare);

            while found {
                if #complete splitter.keep_separator == {
                    case .AS_PREFIX;
                    if index > 0 && splitter.text[index - 1] == Chars.CR
                        index -= 1;
                    it = unsafe_slice(splitter.text, index, end_index);
                    end_index = index;

                    case .AS_POSTFIX;
                    it = unsafe_slice(splitter.text, index + 1, end_index);
                    end_index = index + 1;

                    case .NO;
                    it = unsafe_slice(splitter.text, index + 1, end_index);
                    if index > 0 && splitter.text[index - 1] == Chars.CR
                        end_index = index - 1;
                    else
                        end_index = index;
                }

                if !splitter.skip_empty || !it_is_empty() {
                    it_index += 1;
                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;
                }

                index, found = last_index(splitter.text, Chars.LF, index, splitter.compare);
            }

            if end_index > 0 {
                it = unsafe_slice(splitter.text, 0, end_index);

                if !splitter.skip_empty || !it_is_empty() {
                    it_index += 1;
                    #insert body;
                }
            }
        }
        else {
            start_index := 0;
            index, found := first_index(splitter.text, Chars.LF, splitter.compare);

            while found {
                if #complete splitter.keep_separator == {
                    case .AS_PREFIX;
                    end_index := index;
                    if end_index > 0 && splitter.text[end_index - 1] == Chars.CR
                        end_index -= 1;
                    it = unsafe_slice(splitter.text, start_index, end_index);
                    start_index = end_index;

                    case .AS_POSTFIX;
                    it = unsafe_slice(splitter.text, start_index, index + 1);
                    start_index = index + 1;

                    case .NO;
                    end_index := index;
                    if end_index > 0 && splitter.text[end_index - 1] == Chars.CR
                        end_index -= 1;
                    it = unsafe_slice(splitter.text, start_index, end_index);
                    start_index = index + 1;
                }

                if !splitter.skip_empty || !it_is_empty() {
                    it_index += 1;
                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;
                }

                index, found = first_index(splitter.text, Chars.LF, index + 1, splitter.compare);
            }

            if start_index < splitter.text.count {
                it = unsafe_slice(splitter.text, start_index, splitter.text.count);

                if !splitter.skip_empty || !it_is_empty() {
                    it_index += 1;
                    #insert body;
                }
            }
        }
    }

    it_is_empty :: () -> bool #expand {
        if `splitter.keep_separator != .NO
            return `it == "" || `it.count == 1 || `it.count == 2 && `it[0] == Chars.CR;
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
