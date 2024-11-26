// @TODO for v2
// [ ] Remove all allocator stuff
// [ ] Merge Strings, Strings_Alloc, & Strings_Shared into one modul
// [ ] Fix threading by putting data on context
// [ ] Remove __default_allocator
// [ ] Remove make_..._split
// [ ] Fix or remove strict
// [ ] split only returns iterators and include to_array, to_fixed_array?

// @Todo
// [ ] add pointer versions of for_expansions
// [ ] split asm blocks into setup and loop
// [x] update readme for allocator change
// [ ] investigate boyer-moore avx/sse first_index speed - why is last_index so much faster?
// [ ] in-place replace string->string
// [x] Bug in `index_profile` when needle is one char!
// [ ] `count` simd - is #asm working?
// [ ] first_index simd - has the stashing of xmm registers been relaxed, granting performance?
// [x] error in index_profile when needle is `" "`
// [ ] schpeeeed https://web.archive.org/web/20201107074620/http://effbot.org/zone/stringlib.htm

// [ ] Metaprogram option to run equivalent of index_profile on program data and select algorithm accordingly
// [ ] Add SIMD_mode to Comparator?
// [x] SIMD first_index/last_index chars
// [ ] SIMD replace char   // wait until we can split asm blocks
// [ ] SIMD replace chars  // wait until we can split asm blocks
// [ ] SIMD is_any?
// [ ] Refactor docs: put into sections and add ToC
// [x] make threadsafe (use context.thread_index into global arrays)

#import "Basic";
#import "Machine_X64";

Index_Proc :: #type (haystack: string, needle: string, boundary_index: int, reverse: bool) -> from_index: int, to_index: int, found: bool;
String_Index_Proc :: #type (haystack: string, needle: string, from_index: int, compare: Character_Compare) -> index: int, found: bool;

Character_Compare :: struct {
    kind : enum u8 { CASE_SENSITIVE; IGNORE_CASE; CUSTOM; };
    compare : #type (a: u8, b: u8) -> bool;
}

operator== :: (a: Character_Compare, b: Character_Compare) -> bool {
    return a.kind == b.kind && a.compare == b.compare;
}

Keep_Separator :: enum {
    NO; AS_PREFIX; AS_POSTFIX;
}

#scope_module

current_compare := default_compare;
current_first_index := default_first_index;
current_last_index := default_last_index;

Strings_Thread_Data :: struct {
    simd_mode: enum { SSE2; OFF; AUTO; AVX2; };
}

#add_context strings_thread_data: Strings_Thread_Data;

#scope_export


set_default_compare :: (character_compare := default_compare) {
    current_compare = character_compare;
}


set_index_algorithm :: (first_index_proc := default_first_index, last_index_proc := default_last_index) {
    current_first_index = first_index_proc;
    current_last_index = last_index_proc;
}


equal :: inline (a: string, b: string) -> bool {
    return equal(a, b, current_compare);
}


set_simd_mode :: (mode: type_of(Strings_Thread_Data.simd_mode)) {
    using context.strings_thread_data;

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


char_as_string :: inline (char: *u8) -> string { // @TODO rename? support utf8?
    result : string = ---;
    result.data = char;
    result.count = 1;
    return result;
}


raw_slice :: inline (str: string, from_index: int, to_index: int) -> string {
    // @Note Handles positive indexes only!
    assert(from_index >= 0 && from_index <= str.count, "Cannot slice; from_index falls outwith range of string.");
    assert(to_index >= from_index, "Cannot slice; to_index is not higher than from_index.");
    assert(to_index <= str.count, "Cannot slice; to_index falls outwith range of string.");

    result : string = ---;
    result.data = str.data + from_index;
    result.count = to_index - from_index;
    return result;
}


raw_slice :: inline (str: string, from_index: int) -> string {
    // @Note Handles positive index only!
    assert(from_index >= 0 && from_index <= str.count, "Cannot slice; from_index falls outwith range of string.");

    result : string = ---;
    result.data = str.data + from_index;
    result.count = str.count - from_index;
    return result;
}


raw_substring :: inline (str: string, from_index: int, count: int) -> string {
    // @Note Handles positive indexes only!
    assert(from_index >= 0, "Cannot slice; from_index falls outwith range of string.");
    assert(count > 0, "Cannot slice; count is not >= 0.");
    assert(from_index + count <= str.count, "Cannot slice; count falls outwith range of string.");

    result : string = ---;
    result.data = str.data + from_index;
    result.count = count;
    return result;
}


slice_index :: inline (str: string, index: int) -> normalized_index: int, valid_when_strict: bool {
    if index < 0  index += str.count;

    if index > str.count  return str.count, false;
    else if index < 0     return 0, false;
    else                  return index, true;
}


to_lower :: (str_ptr: *string) {
    if str_ptr.* == ""  return;

    data : u64 = cast(u64)str_ptr.data;
    end  : u64 = data + cast(u64)str_ptr.count - 1;

    if context.strings_thread_data.simd_mode == {
        case .SSE2;
            case_bit : u8 : 32;
            case_bytes := #insert #run make_16(case_bit);
            a_bytes := #insert #run make_16(#char "A");
            z_bytes := #insert #run make_16(#char "Z");
            case_ptr := *case_bytes;
            a_ptr := *a_bytes;
            z_ptr := *z_bytes;

            loop_until := end - 15;
            while data < loop_until {
                #asm {
                    /* load data */
                    movdqu.x case_vec:, [case_ptr];
                    movdqu.x a_vec:, [a_ptr];
                    movdqu.x z_vec:, [z_ptr];
                    movdqu.x string_vec:, [data];

                    /* generate mask for which bits are uppercase letters */
                    movdqa.x mask_vec:, string_vec;
                    pcmpgtb.x mask_vec, z_vec;

                    pcmpgtb.x a_vec, string_vec;
                    por.x mask_vec, a_vec;

                    /* apply mask to keep non-upper chars */
                    movdqu.x non_upper_vec:, string_vec;
                    pand.x non_upper_vec, mask_vec;

                    /* convert uppercase to lowercase, and rest to garbage */
                    por.x string_vec, case_vec;

                    /* invert mask then apply it to add lowered chars */
                    pcmpeqb.x a_vec, a_vec;
                    pxor.x mask_vec, a_vec;
                    pand.x string_vec, mask_vec;

                    /* combine results and output */
                    por.x string_vec, non_upper_vec;
                    movdqu.x [data], string_vec;
                }

                data += 16;
            }

        case .AVX2;
            case_bit : u8 : 32;
            case_bytes := #insert #run make_32(case_bit);
            a_bytes := #insert #run make_32(#char "A");
            z_bytes := #insert #run make_32(#char "Z");
            case_ptr := *case_bytes;
            a_ptr := *a_bytes;
            z_ptr := *z_bytes;

            loop_until := end - 31;
            while data < loop_until {
                #asm AVX,AVX2 {
                    /* load data */
                    movdqu.y case_vec:, [case_ptr];
                    movdqu.y a_vec:, [a_ptr];
                    movdqu.y z_vec:, [z_ptr];
                    movdqu.y string_vec:, [data];

                    /* generate mask for which bits are uppercase letters */
                    pcmpgtb.y mask_vec:, string_vec, z_vec;
                    pcmpgtb.y a_vec, a_vec, string_vec;
                    por.y mask_vec, mask_vec, a_vec;

                    /* apply mask to keep non-upper chars */
                    pand.y non_upper_vec:, string_vec, mask_vec;

                    /* convert uppercase to lowercase, and rest to garbage */
                    por.y string_vec, string_vec, case_vec;

                    /* invert mask then apply it to add lowered chars */
                    pcmpeqb.y a_vec, a_vec, a_vec;
                    pxor.y mask_vec, mask_vec, a_vec;
                    pand.y string_vec, string_vec, mask_vec;

                    /* combine results and output */
                    por.y string_vec, string_vec, non_upper_vec;
                    movdqu.y [data], string_vec;
                }

                data += 32;
            }
    }

    for data .. end {
        if <<cast(*u8)it >= #char "A" && <<cast(*u8)it <= #char "Z" {
            <<cast(*u8)it += 32;
        }
    }
}



to_upper :: (str_ptr: *string) {
    if str_ptr.* == ""  return;

    data : u64 = cast(u64)str_ptr.data;
    end  : u64 = data + cast(u64)str_ptr.count - 1;

    if context.strings_thread_data.simd_mode == {
        case .SSE2;
            case_bit : u8 : 32;
            case_bytes := #insert #run make_16(case_bit);
            a_bytes := #insert #run make_16(#char "a");
            z_bytes := #insert #run make_16(#char "z");
            case_ptr := *case_bytes;
            a_ptr := *a_bytes;
            z_ptr := *z_bytes;

            loop_until := end - 15;
            while data < loop_until {
                #asm {
                    /* load data */
                    movdqu.x case_vec:, [case_ptr];
                    movdqu.x a_vec:, [a_ptr];
                    movdqu.x z_vec:, [z_ptr];
                    movdqu.x string_vec:, [data];

                    /* generate mask for which bits are uppercase letters */
                    movdqa.x mask_vec:, string_vec;
                    pcmpgtb.x mask_vec, z_vec;

                    pcmpgtb.x a_vec, string_vec;
                    por.x mask_vec, a_vec;

                    /* apply mask to keep non-upper chars */
                    movdqu.x non_lower_vec:, string_vec;
                    pand.x non_lower_vec, mask_vec;

                    /* convert lowercase to uppercase, and rest to garbage */
                    pxor.x string_vec, case_vec;

                    /* invert mask then apply it to add uppered chars */
                    pcmpeqb.x a_vec, a_vec;
                    pxor.x mask_vec, a_vec;
                    pand.x string_vec, mask_vec;

                    /* combine results and output */
                    por.x string_vec, non_lower_vec;
                    movdqu.x [data], string_vec;
                }

                data += 16;
            }

        case .AVX2;
            case_bit : u8 : 32;
            case_bytes := #insert #run make_32(case_bit);
            a_bytes := #insert #run make_32(#char "a");
            z_bytes := #insert #run make_32(#char "z");
            case_ptr := *case_bytes;
            a_ptr := *a_bytes;
            z_ptr := *z_bytes;

            loop_until := end - 31;
            while data < loop_until {
                #asm AVX,AVX2 {
                    /* load data */
                    movdqu.y case_vec:, [case_ptr];
                    movdqu.y a_vec:, [a_ptr];
                    movdqu.y z_vec:, [z_ptr];
                    movdqu.y string_vec:, [data];

                    /* generate mask for which bits are uppercase letters */
                    pcmpgtb.y mask_vec:, string_vec, z_vec;
                    pcmpgtb.y a_vec, a_vec, string_vec;
                    por.y mask_vec, mask_vec, a_vec;

                    /* apply mask to keep non-upper chars */
                    pand.y non_lower_vec:, string_vec, mask_vec;

                    /* convert lowercase to uppercase, and rest to garbage */
                    pxor.y string_vec, string_vec, case_vec;

                    /* invert mask then apply it to add uppered chars */
                    pcmpeqb.y a_vec, a_vec, a_vec;
                    pxor.y mask_vec, mask_vec, a_vec;
                    pand.y string_vec, string_vec, mask_vec;

                    /* combine results and output */
                    por.y string_vec, string_vec, non_lower_vec;
                    movdqu.y [data], string_vec;
                }

                data += 32;
            }
    }

    for data .. end {
        if <<cast(*u8)it >= #char "a" && <<cast(*u8)it <= #char "z" {
            <<cast(*u8)it -= 32;
        }
    }
}


to_capitalized :: (str_ptr: *string, preserve_caps := true) {
    str := str_ptr.*;
    if !str  return;

    str[0] = to_upper(str[0]);
    if !preserve_caps
        to_lower(*raw_slice(str, 1));
}


is_lower :: inline (char: u8) -> bool { // Not utf
    return char >= #char "a" && char <= #char "z";
}


is_upper :: inline (char: u8) -> bool { // Not utf
    return char >= #char "A" && char <= #char "Z";
}


//bit_masks_16 := u8.[0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
//                    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
//                    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF];
//
//bit_mask_16_zero : *u8 = (cast(*u8)*bit_masks_16) + 16;

// @TODO asm can't handle globals yet: when it does put them out here

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



starts_with :: (haystack: string, needle: string, compare : Character_Compare) -> bool {
    if haystack.count < needle.count  return false;

    return equal(raw_slice(haystack, 0, needle.count), needle, compare);
}


starts_with :: (haystack: string, needle: u8, compare : Character_Compare) -> bool {
    return haystack.count > 0 && compare.compare(haystack[0], needle);
}


starts_with :: (haystack: string, needle: [] u8, compare : Character_Compare) -> bool {
    return haystack.count > 0 && is_any(haystack[0], needle, compare);
}


starts_with :: (haystack: string, needle: string, $$index: Index_Proc) -> bool {
    return index(haystack, needle, 0, false) == 0;
}


ends_with :: (haystack: string, needle: string, compare: Character_Compare) -> bool {
    if haystack.count < needle.count  return false;

    return equal(raw_slice(haystack, haystack.count - needle.count), needle, compare);
}


ends_with :: (haystack: string, needle: u8, compare: Character_Compare) -> bool {
    return haystack.count > 0 && compare.compare(haystack[haystack.count - 1], needle);
}


ends_with :: (haystack: string, needle: [] u8, compare: Character_Compare) -> bool {
    return haystack.count > 0 && is_any(haystack[haystack.count - 1], needle, compare);
}


ends_with :: (haystack: string, needle: string, $$index: Index_Proc) -> bool {
    from_index, to_index, found := index(haystack, needle, haystack.count, true);
    return to_index == haystack.count;
}


advance_to :: (haystack_ptr: *string, needle: u8, compare: Character_Compare) -> characters_skipped: int {
    index, found := first_index(haystack_ptr.*, needle, compare);

    if !found  index = haystack_ptr.count;
    haystack_ptr.data += index;
    haystack_ptr.count -= index;

    return index;
}

advance_to :: (haystack_ptr: *string, needle: [] u8, compare: Character_Compare) -> characters_skipped: int {
    if !needle  return 0;

    index, found := first_index(haystack_ptr.*, needle, compare);

    if !found  index = haystack_ptr.count;
    haystack_ptr.data += index;
    haystack_ptr.count -= index;

    return index;
}

advance_to :: (haystack_ptr: *string, needle: string, compare: Character_Compare, string_index_proc: String_Index_Proc) -> characters_skipped: int {
    if !needle  return 0;

    index, found := first_index(haystack_ptr.*, needle, compare, string_index_proc);

    if !found  index = haystack_ptr.count;
    haystack_ptr.data += index;
    haystack_ptr.count -= index;

    return index;
}

advance_to :: (haystack_ptr: *string, needle: string, $$index_proc: Index_Proc) -> characters_skipped: int {
    index, found := first_index(haystack_ptr.*, needle, index_proc);

    if !found  index = haystack_ptr.count;
    haystack_ptr.data += index;
    haystack_ptr.count -= index;

    return index;
}


advance_through :: (haystack_ptr: *string, needle: u8, compare: Character_Compare) -> characters_skipped: int {
    index, found := first_index(haystack_ptr.*, needle, compare);

    if found  index += 1;
    else      index = haystack_ptr.count;

    haystack_ptr.data += index;
    haystack_ptr.count -= index;

    return index;
}

advance_through :: (haystack_ptr: *string, needle: [] u8, compare: Character_Compare) -> characters_skipped: int {
    if !needle  return 0;

    index, found := first_index(haystack_ptr.*, needle, compare);

    if found {
        while index < haystack_ptr.count && is_any(haystack_ptr.*[index], needle, compare)
            index += 1;
        index += 1;
    }
    else {
        index = haystack_ptr.count;
    }

    haystack_ptr.data += index;
    haystack_ptr.count -= index;

    return index;
}

advance_through :: (haystack_ptr: *string, needle: string, compare: Character_Compare, string_index_proc: String_Index_Proc) -> characters_skipped: int {
    if !needle  return 0;

    index, found := first_index(haystack_ptr.*, needle, compare, string_index_proc);

    if found  index += needle.count;
    else      index = haystack_ptr.count;

    haystack_ptr.data += index;
    haystack_ptr.count -= index;

    return index;
}

advance_through :: (haystack_ptr: *string, needle: string, $$index_proc: Index_Proc) -> characters_skipped: int {
    index, found, to_index := first_index(haystack_ptr.*, needle, index_proc);

    if found  index = to_index;
    else      index = haystack_ptr.count;

    haystack_ptr.data += index;
    haystack_ptr.count -= index;

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

    return raw_slice(str, low_index, high_index + 1);
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

    return raw_slice(str, low_index, high_index + 1);
}

trim :: (str: string, string_to_remove: string, compare : Character_Compare) -> string {
    s := str;
    while starts_with(s, string_to_remove, compare)
        s = raw_slice(s, string_to_remove.count);

    if !s  return "";

    while ends_with(s, string_to_remove, compare)
        s = raw_slice(s, 0, s.count - string_to_remove.count);

    return s;
}

trim :: (str: string, string_to_remove: string, $$index: Index_Proc) -> string {
    s := str;
    from_index, to_index, found := index(s, string_to_remove, 0, false);
    while s && from_index == 0 {
        s = raw_slice(s, to_index);
        from_index, to_index, found = index(s, string_to_remove, 0, false);
    }

    if !s  return "";

    from_index, to_index, found = index(s, string_to_remove, s.count, true);
    while s && to_index == s.count {
        s = raw_slice(s, 0, from_index);
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

    return raw_slice(str, low_index, high_index + 1), true;
}

trim_to :: (str: string, needle : [] u8, compare: Character_Compare) -> string, found: bool {
    low_index, high_index : int = ---;
    found : bool = ---;

    low_index, found = first_index(str, needle, compare);
    if !found  return str, false;

    high_index = last_index(str, needle, compare);

    return raw_slice(str, low_index, high_index + 1), true;
}

trim_to :: (str: string, needle: string, compare : Character_Compare, first_index_proc: String_Index_Proc, last_index_proc: String_Index_Proc) -> string, found: bool {
    low_index, high_index : int = ---;
    found : bool = ---;

    low_index, found = first_index(str, needle, compare, first_index_proc);
    if !found  return str, false;

    high_index = last_index(str, needle, compare, last_index_proc);

    return raw_slice(str, low_index, high_index + needle.count), true;
}

trim_to :: (str: string, needle: string, $$index: Index_Proc) -> string, found: bool {
    low_index, high_index, _ : int = ---;
    found : bool = ---;

    low_index, _, found = index(str, needle, 0, false);
    if !found  return str, false;

    _, high_index, found = index(str, needle, str.count, true);
    if !found  return str, false;

    return raw_slice(str, low_index, high_index), true;
}


trim_through :: (str: string, needle: u8, compare: Character_Compare) -> string, found: bool {
    low_index, high_index : int = ---;
    found : bool = ---;

    low_index, found = first_index(str, needle, compare);
    if !found  return str, false;

    high_index = last_index(str, needle, compare);

    if low_index == high_index
        return "", true;
    else
        return raw_slice(str, low_index + 1, high_index), true;
}

trim_through :: (str: string, needle : [] u8, compare: Character_Compare) -> string, found: bool {
    low_index, high_index : int = ---;
    found : bool = ---;

    low_index, found = first_index(str, needle, compare);
    if !found  return str, false;

    high_index = last_index(str, needle, compare);

    if low_index == high_index
        return "", true;
    else
        return raw_slice(str, low_index + 1, high_index), true;
}

trim_through :: (str: string, needle: string, compare : Character_Compare, first_index_proc: String_Index_Proc, last_index_proc: String_Index_Proc) -> string, found: bool {
    low_index, high_index : int = ---;
    found : bool = ---;

    low_index, found = first_index(str, needle, compare, first_index_proc);
    if !found  return str, false;

    high_index = last_index(str, needle, compare, last_index_proc);

    if low_index == high_index
        return "", true;
    else
        return raw_slice(str, low_index + needle.count, high_index), true;
}

trim_through :: (str: string, needle: string, $$index: Index_Proc) -> string, found: bool {
    low_index, high_index, _ : int = ---;
    found : bool = ---;

    _, low_index, found = index(str, needle, 0, false);
    if !found  return str, false;

    high_index, _, found = index(str, needle, str.count, true);
    if !found  return str, false;

    if low_index == high_index
        return "", true;
    else
        return raw_slice(str, low_index, high_index), true;
}


trim_start :: (str: string, char: u8, compare: Character_Compare) -> string {
    index := 0;

    while index < str.count && compare.compare(str[index], char)
        index += 1;

    if index >= str.count  return "";

    return raw_slice(str, index);
}

trim_start :: (str: string, chars: [] u8, compare: Character_Compare) -> string {
    if chars.count == 0  return str;

    index := 0;

    while index < str.count && is_any(str[index], chars, compare)
        index += 1;

    if index >= str.count  return "";

    return raw_slice(str, index);
}

trim_start :: (str: string, string_to_remove: string, compare : Character_Compare) -> string {
    if string_to_remove == ""  return str;

    s := str;
    while starts_with(s, string_to_remove, compare)
        s = raw_slice(s, string_to_remove.count);

    return s;
}

trim_start :: (str: string, string_to_remove: string, $$index: Index_Proc) -> string {
    s := str;
    from_index, to_index, found := index(s, string_to_remove, 0, false);
    while s && from_index == 0 {
        s = raw_slice(s, to_index);
        from_index, to_index, found = index(s, string_to_remove, 0, false);
    }

    return s;
}


trim_start_to :: (str: string, needle: u8, compare: Character_Compare) -> string, found: bool {
    index, found := first_index(str, needle, 0, compare);
    if !found  return str, false;
    return raw_slice(str, index), true;
}

trim_start_to :: (str: string, needle: [] u8, compare: Character_Compare) -> string, found: bool {
    index, found := first_index(str, needle, 0, compare);
    if !found  return str, false;
    return raw_slice(str, index), true;
}

trim_start_to :: (str: string, needle: string, compare: Character_Compare, string_index_proc: String_Index_Proc) -> string, found: bool {
    if needle == ""  return str, true;
    index, found := first_index(str, needle, 0, compare, string_index_proc);
    if !found  return str, false;
    return raw_slice(str, index), true;
}

trim_start_to :: (str: string, needle: string, $$index: Index_Proc) -> string, found: bool {
    index, found := first_index(str, needle, 0, index);
    if !found  return str, false;
    return raw_slice(str, index), true;
}


trim_start_through :: (str: string, needle: u8, compare: Character_Compare) -> string, found: bool {
    index, found := first_index(str, needle, 0, compare);
    if !found  return str, false;
    return raw_slice(str, index + 1), true;
}

trim_start_through :: (str: string, needle: [] u8, compare: Character_Compare) -> string, found: bool {
    index, found := first_index(str, needle, 0, compare);
    if !found  return str, false;
    return raw_slice(str, index + 1), true;
}

trim_start_through :: (str: string, needle: string, compare: Character_Compare, string_index_proc: String_Index_Proc) -> string, found: bool {
    if needle == ""  return str, true;
    index, found := first_index(str, needle, 0, compare, string_index_proc);
    if !found  return str, false;
    return raw_slice(str, index + needle.count), true;
}

trim_start_through :: (str: string, needle: string, $$index: Index_Proc) -> string, found: bool {
    from_index, found, to_index := first_index(str, needle, 0, index);
    if !found  return str, false;
    return raw_slice(str, to_index), true;
}


trim_end :: inline (str: string, char: u8, compare: Character_Compare) -> string {
    index := str.count - 1;

    while index >= 0 && compare.compare(str[index], char)
        index -= 1;

    if index < 0  return "";

    return raw_slice(str, 0, index + 1);
}

trim_end :: inline (str: string, chars : [] u8, compare: Character_Compare) -> string {
    if chars.count == 0  return str;

    index := str.count - 1;

    while index >= 0 && is_any(str[index], chars, compare)
        index -= 1;

    if index < 0  return "";

    return raw_slice(str, 0, index + 1);
}

trim_end :: (str: string, string_to_remove: string, compare : Character_Compare) -> string {
    if string_to_remove == ""  return str;

    s := str;
    while ends_with(s, string_to_remove, compare)
        s = raw_slice(s, 0, s.count - string_to_remove.count);

    return s;
}

trim_end :: (str: string, string_to_remove: string, $$index: Index_Proc) -> string {
    s := str;
    from_index, to_index, found := index(s, string_to_remove, s.count, true);
    while s && to_index == s.count {
        s = raw_slice(s, 0, from_index);
        from_index, to_index, found = index(s, string_to_remove, s.count, true);
    }

    return s;
}


trim_end_to :: (str: string, needle: u8, compare: Character_Compare) -> string, found: bool {
    index, found := last_index(str, needle, str.count, compare);
    if !found  return str, false;
    return raw_slice(str, 0, index + 1), true;
}

trim_end_to :: (str: string, needle: [] u8, compare: Character_Compare) -> string, found: bool {
    index, found := last_index(str, needle, str.count, compare);
    if !found  return str, false;
    return raw_slice(str, 0, index + 1), true;
}

trim_end_to :: (str: string, needle: string, compare: Character_Compare, string_index_proc: String_Index_Proc) -> string, found: bool {
    if needle == ""  return str, true;
    index, found := last_index(str, needle, str.count, compare, string_index_proc);
    if !found  return str, false;
    return raw_slice(str, 0, index + needle.count), true;
}

trim_end_to :: (str: string, needle: string, $$index: Index_Proc) -> string, found: bool {
    from_index, found, to_index := last_index(str, needle, str.count, index);
    if !found  return str, false;
    return raw_slice(str, 0, to_index), true;
}



trim_end_through :: (str: string, needle: u8, compare: Character_Compare) -> string, found: bool {
    index, found := last_index(str, needle, str.count, compare);
    if !found  return str, false;
    return raw_slice(str, 0, index), true;
}

trim_end_through :: (str: string, needle: [] u8, compare: Character_Compare) -> string, found: bool {
    index, found := last_index(str, needle, str.count, compare);
    if !found  return str, false;
    return raw_slice(str, 0, index), true;
}

trim_end_through :: (str: string, needle: string, compare: Character_Compare, string_index_proc: String_Index_Proc) -> string, found: bool {
    if needle == ""  return str, true;
    index, found := last_index(str, needle, str.count, compare, string_index_proc);
    if !found  return str, false;
    return raw_slice(str, 0, index), true;
}

trim_end_through :: (str: string, needle: string, $$index: Index_Proc) -> string, found: bool {
    from_index, found, to_index := last_index(str, needle, str.count, index);
    if !found  return str, false;
    return raw_slice(str, 0, from_index), true;
}


reverse :: (str_ptr: *string) {
    if str_ptr.* == ""  return;

    low_data  : u64 = cast(u64)str_ptr.data;
    high_data : u64 = low_data + cast(u64)str_ptr.count;

    if context.strings_thread_data.simd_mode == {
        case .AVX2;
            if low_data + 64 < high_data {
                shuffle_bytes := u8.[15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
                                     15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0];
                shuffle_data := shuffle_bytes.data;

                while low_data + 64 <= high_data {
                    //high_data -= 32;

                    #asm AVX,AVX2 {
                        sub.q high_data, 32;
                        /* load data */
                        movdqu.y low_vec:, [low_data];
                        movdqu.y high_vec:, [high_data];
                        movdqu.y shuffle_vec:, [shuffle_data];

                        /* shuffle both 128-bit sections */
                        pshufb.y low_vec, low_vec, shuffle_vec;
                        pshufb.y high_vec, high_vec, shuffle_vec;

                        /* swap 128-bit sections */
                        perm2i128 low_vec, low_vec, low_vec, 1;
                        perm2i128 high_vec, high_vec, high_vec, 1;

                        /* export out to reversed positions */
                        movdqu.y [high_data], low_vec;
                        movdqu.y [low_data], high_vec;
                        add.q low_data, 32;
                    }

                    //low_data += 32;
                }
            }
            #through; // we might still have 32 <= bytes <= 64 to swap

        case .SSE2;
            if low_data + 32 < high_data {
                shuffle_bytes := u8.[15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0];
                shuffle_data := shuffle_bytes.data;

                while low_data + 32 <= high_data {
                    high_data -= 16;
                    #asm {
                        /* load data */
                        movdqu.x low_vec:, [low_data];
                        movdqu.x high_vec:, [high_data];
                        movdqu.x shuffle_vec:, [shuffle_data];

                        /* shuffle */
                        pshufb.x low_vec, shuffle_vec;
                        pshufb.x high_vec, shuffle_vec;

                        /* export out to reversed positions */
                        movdqu.x [high_data], low_vec;
                        movdqu.x [low_data], high_vec;
                    }

                    low_data += 16;
                }
            }

    }

    high_data -= 1;

    while low_data < high_data {
        #asm {
            mov.b low_gpr:, [low_data];
            mov.b high_gpr:, [high_data];
            mov.b [high_data], low_gpr;
            mov.b [low_data], high_gpr;
        }
        low_data += 1;
        high_data -= 1;
    }
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
/*
    if compare.kind == {
        case .CASE_SENSITIVE;
            if context.strings_thread_data.simd_mode == {
                case .SSE2;
                    data := cast(u64)haystack.data;
                    end := cast(u64)haystack.data + cast(u64)haystack.count;

                    needles : [16] u8 = ---;
                    memset(needles.data, needle, 16);
                    needle_ptr := needles.data;

                    loop_until := end - 15;

                    #asm {
                        movdqu.x   needle_vec:, [needle_ptr];
                        int3;
                        xor.q      total_gpr:, total_gpr;
                    }

                    while data < loop_until {
                        #asm {
                            /* check for equality */
                            movdqu.x   results_vec:, [data];
                            pcmpeqb.x  results_vec, needle_vec:;

                            /* coalesce and count bits */
                            pmovmskb.x found_gpr:, results_vec;
                            popcnt.w   found_gpr, found_gpr;

                            /* add */
                            add.w      total_gpr:, found_gpr;
                        }

                        data += 16;
                    }

                    #asm {
                        mov.q total, total_gpr;
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
                    needle_ptr := needles.data;

                    result : u32 = ---;
                    result_data := *result;

                    loop_until := end - 31;

                    #asm AVX,AVX2 {
                        movdqu.y   needle_vec:, [needle_ptr];
                    }

                    while data < loop_until {
                        #asm AVX,AVX2 {
                            /* check for equality */
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
                        if compare.compare(<<cast(*u8)it, needle)
                            total += 1;

                    return total;

            }

        case .IGNORE_CASE;
            if context.strings_thread_data.simd_mode == {
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

                    #asm {
                        movdqu.x   needles_upper_vec:, [needles_upper_data];
                        movdqu.x   needles_lower_vec:, [needles_lower_data];
                    }

                    while data < loop_until {
                        #asm {
                            /* load data */
                            movdqu.x   results_lower_vec:, [data];

                            /* check for equality */
                            movdqu.x   results_upper_vec:, results_lower_vec;
                            pcmpeqb.x  results_upper_vec, needles_upper_vec;

                            pcmpeqb.x  results_lower_vec, needles_lower_vec;
                            por.x results_lower_vec, results_upper_vec;

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
                        if compare.compare(<<cast(*u8)it, needle)
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

                    result : u32 = ---;
                    result_data := *result;

                    loop_until := end - 31;

                    #asm AVX,AVX2 {
                        movdqu.y   needles_upper_vec:, [needles_upper_data];
                        movdqu.y   needles_lower_vec:, [needles_lower_data];
                    }

                    while data < loop_until {
                        #asm AVX,AVX2 {
                            /* load data */
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
                        if compare.compare(<<cast(*u8)it, needle)
                            total += 1;

                    return total;
            }
    }
*/
    for 0 .. haystack.count - 1 {
        if compare.compare(haystack[it], needle) {
            total += 1;
        }
    }

    return total;
}



Chars :: struct {
    SPACE :: #char " ";
    TAB   :: #char "\t";
    CR    :: #char "\r";
    LF    :: #char "\n";
    NBSP  :: #char " "; // careful!
    WHITESPACE :: u8.[SPACE, TAB, CR, LF];
}


/// Strings


slice :: inline (str: string, from_index: int, to_index: int) -> string, normalized_from_index: int, normalized_to_index: int {
    if from_index >= 0  from_index = min(from_index, str.count);
    else                from_index = clamp(str.count + from_index, 0, str.count);

    if to_index >= 0  to_index = min(to_index, str.count);
    else              to_index = clamp(str.count + to_index, 0, str.count);

    if from_index >= to_index  return "", from_index, to_index;

    result : string = ---;
    result.data = str.data + from_index;
    result.count = to_index - from_index;
    return result, from_index, to_index;
}


slice :: inline (str: string, from_index: int) -> string, normalized_from_index: int, normalized_to_index: int {
    result, normalized_from_index, normalized_to_index := slice(str, from_index, str.count);
    return result, normalized_from_index, normalized_to_index;
}


substring :: inline (str: string, from_index: int) -> string, normalized_from_index: int, normalized_to_index: int {
    result, normalized_from_index, normalized_to_index := slice(str, from_index, str.count);
    return result, normalized_from_index, normalized_to_index;
}


substring :: (str: string, from_index: int, count: int) -> string, normalized_from_index: int, normalized_to_index: int {
    if count <= 0  return "", from_index, from_index;

    result, normalized_from_index, normalized_to_index := slice(str, from_index, from_index + count);
    return result, normalized_from_index, normalized_to_index;
}


// @Note `needle` is guaranteed to be at least 2 characters long, as the call site is internal to the module and checks.
// This won't work with multibyte chars!
reverse_index_proc :: (index_proc: Index_Proc, haystack: string, needle: string, boundary_index: int) -> from_index: int, to_index: int, found: bool {
    for < haystack_index: haystack.count - 1 .. 0 {
        s := raw_slice(haystack, haystack_index);
        from_index, to_index, found := index_proc(s, needle, 0, false);
        if found && haystack_index + to_index <= boundary_index
            return haystack_index + from_index, haystack_index + to_index, true;
    }

    return -1, -1, false;
}





is_any :: inline (needle: u8, haystack: [] u8) -> bool {
    return is_any(needle, haystack, current_compare);
}


contains :: inline (haystack: string, needle: u8) -> bool {
    _, found := first_index(haystack, needle);
    return found;
}

contains :: inline (haystack: string, needle: [] u8) -> bool {
    _, found := first_index(haystack, needle);
    return found;
}

contains :: inline (haystack: string, needle: string) -> bool {
    _, found := first_index(haystack, needle);
    return found;
}

contains :: inline (haystack: string, needle: string, compare: Character_Compare) -> bool {
    _, found := first_index(haystack, needle, compare, current_first_index);
    return found;
}

contains :: inline (haystack: string, needle: string, $$index: Index_Proc) -> bool {
    _, __, found := index(haystack, needle, 0, false);
    return found;
}


starts_with :: inline (haystack: string, needle: string) -> bool {
    return starts_with(haystack, needle, current_compare);
}

starts_with :: inline (haystack: string, needle: u8) -> bool {
    return starts_with(haystack, needle, current_compare);
}

starts_with :: inline (haystack: string, needle: [] u8) -> bool {
    return starts_with(haystack, needle, current_compare);
}


ends_with :: inline (haystack: string, needle: string) -> bool {
    return ends_with(haystack, needle, current_compare);
}

ends_with :: inline (haystack: string, needle: u8) -> bool {
    return ends_with(haystack, needle, current_compare);
}

ends_with :: inline (haystack: string, needle: [] u8) -> bool {
    return ends_with(haystack, needle, current_compare);
}


advance_to :: inline (haystack_ptr: *string, needle: u8) -> characters_skipped: int {
    return advance_to(haystack_ptr, needle, current_compare);
}

advance_to :: inline (haystack_ptr: *string, needle: [] u8) -> characters_skipped: int {
    return advance_to(haystack_ptr, needle, current_compare);
}

advance_to :: inline (haystack_ptr: *string, needle: string) -> characters_skipped: int {
    return advance_to(haystack_ptr, needle, current_compare, current_first_index);
}


advance_through :: inline (haystack_ptr: *string, needle: u8) -> characters_skipped: int {
    return advance_through(haystack_ptr, needle, current_compare);
}

advance_through :: inline (haystack_ptr: *string, needle: [] u8) -> characters_skipped: int {
    return advance_through(haystack_ptr, needle, current_compare);
}

advance_through :: inline (haystack_ptr: *string, needle: string) -> characters_skipped: int {
    return advance_through(haystack_ptr, needle, current_compare, current_first_index);
}



trim :: (str: string) -> string {
    low_index := 0;
    high_index := str.count - 1;

    while low_index < str.count && str[low_index] <= Chars.SPACE
        low_index += 1;

    if low_index >= str.count  return "";

    while high_index > low_index && str[high_index] <= Chars.SPACE
        high_index -= 1;

    return raw_slice(str, low_index, high_index + 1);
}

trim :: inline (str: string, char : u8) -> string {
    return trim(str, char, current_compare);
}

trim :: inline (str: string, chars : [] u8) -> string {
    return trim(str, chars, current_compare);
}

trim :: inline (str: string, string_to_remove: string) -> string {
    return trim(str, string_to_remove, current_compare);
}


trim_to :: inline (str: string, needle: u8) -> string, found: bool {
    result, found := trim_to(str, needle, current_compare);
    return result, found;
}

trim_to :: inline (str: string, needle: [] u8) -> string, found: bool {
    result, found := trim_to(str, needle, current_compare);
    return result, found;
}

trim_to :: inline (str: string, needle: string) -> string, found: bool  {
    result, found := trim_to(str, needle, current_compare, current_first_index, current_last_index);
    return result, found;
}


trim_through :: inline (str: string, needle: u8) -> string, found: bool {
    result, found := trim_through(str, needle, current_compare);
    return result, found;
}

trim_through :: inline (str: string, needle: [] u8) -> string, found: bool {
    result, found := trim_through(str, needle, current_compare);
    return result, found;
}

trim_through :: inline (str: string, needle: string) -> string, found: bool  {
    result, found := trim_through(str, needle, current_compare, current_first_index, current_last_index);
    return result, found;
}


trim_start :: (str: string) -> string {
    index := 0;

    while index < str.count && str[index] <= Chars.SPACE
        index += 1;

    if index >= str.count  return "";

    return raw_slice(str, index);
}


trim_start :: inline (str: string, char : u8) -> string {
    return trim_start(str, char, current_compare);
}


trim_start :: inline (str: string, chars : [] u8) -> string {
    return trim_start(str, chars, current_compare);
}


trim_start :: inline (str: string, string_to_remove: string) -> string {
    return trim_start(str, string_to_remove, current_compare);
}



trim_start_to :: inline (str: string, needle: u8) -> string, found: bool {
    result, found := trim_start_to(str, needle, current_compare);
    return result, found;
}

trim_start_to :: inline (str: string, needle: [] u8) -> string, found: bool  {
    result, found := trim_start_to(str, needle, current_compare);
    return result, found;
}

trim_start_to :: inline (str: string, needle: string) -> string, found: bool  {
    result, found := trim_start_to(str, needle, current_compare, current_first_index);
    return result, found;
}


trim_start_through :: inline (str: string, needle: u8) -> string, found: bool {
    result, found := trim_start_through(str, needle, current_compare);
    return result, found;
}

trim_start_through :: inline (str: string, needle: [] u8) -> string, found: bool  {
    result, found := trim_start_through(str, needle, current_compare);
    return result, found;
}

trim_start_through :: inline (str: string, needle: string) -> string, found: bool  {
    result, found := trim_start_through(str, needle, current_compare, current_first_index);
    return result, found;
}


trim_end :: (str: string) -> string {
    index := str.count - 1;

    while index >= 0 && str[index] <= Chars.SPACE
        index -= 1;

    if index < 0  return "";

    return raw_slice(str, 0, index + 1);
}


trim_end :: inline (str: string, char : u8) -> string {
    return trim_end(str, char, current_compare);
}


trim_end :: inline (str: string, chars : [] u8) -> string {
    return trim_end(str, chars, current_compare);
}


trim_end :: inline (str: string, string_to_remove: string) -> string {
    return trim_end(str, string_to_remove, current_compare);
}




trim_end_to :: inline (str: string, needle: u8) -> string, found: bool {
    result, found := trim_end_to(str, needle, current_compare);
    return result, found;
}

trim_end_to :: inline (str: string, needle: [] u8) -> string, found: bool  {
    result, found := trim_end_to(str, needle, current_compare);
    return result, found;
}

trim_end_to :: inline (str: string, needle: string) -> string, found: bool  {
    result, found := trim_end_to(str, needle, current_compare, current_last_index);
    return result, found;
}


trim_end_through :: inline (str: string, needle: u8) -> string, found: bool {
    result, found := trim_end_through(str, needle, current_compare);
    return result, found;
}

trim_end_through :: inline (str: string, needle: [] u8) -> string, found: bool  {
    result, found := trim_end_through(str, needle, current_compare);
    return result, found;
}

trim_end_through :: inline (str: string, needle: string) -> string, found: bool  {
    result, found := trim_end_through(str, needle, current_compare, current_last_index);
    return result, found;
}


replace :: (haystack_ptr: *string, needle: u8, replacement: u8, max_replacements := 0) -> change_count: int {
    haystack := haystack_ptr.*;
    change_count := 0;
    index, found := first_index(haystack, needle);

    while found {
        haystack[index] = replacement;
        change_count += 1;
        if max_replacements > 0 && change_count >= max_replacements  break;
        index, found = first_index(haystack, needle, index + 1);
    }

    return change_count;
}


replace :: (haystack_ptr: *string, needle: [] u8, replacement: u8, max_replacements := 0) -> change_count: int {
    haystack := haystack_ptr.*;
    change_count := 0;
    for 0 .. haystack.count - 1 {
        if is_any(haystack[it], needle) {
            haystack[it] = replacement;
            change_count += 1;
            if max_replacements > 0 && change_count >= max_replacements  break;
        }
    }

    return change_count;
}


replace :: inline (haystack_ptr: *string, needle: string, replacement: u8, max_replacements := 0) -> change_count: int {
    return replace(haystack_ptr, needle, replacement, max_replacements, current_compare);
}


replace :: (haystack_ptr: *string, needle: string, replacement: u8, max_replacements := 0, compare: Character_Compare) -> change_count: int {
    haystack := haystack_ptr.*;
    change_count := 0;
    over_limit := false;
    index, found := first_index(haystack, needle, compare, current_first_index);
    while found && !over_limit {
        for index .. index + needle.count - 1 {
            haystack[it] = replacement;
            change_count += 1;
            if max_replacements > 0 && change_count >= max_replacements {
                over_limit = true;
                break;
            }
        }
        index, found = first_index(haystack, needle, index + needle.count, compare, current_first_index);
    }

    return change_count;
}


replace :: (haystack_ptr: *string, needle: string, $$index: Index_Proc, replacement: u8, max_replacements := 0) -> change_count: int {
    haystack := haystack_ptr.*;
    change_count := 0;
    over_limit := false;
    from_index, to_index, found := index(haystack, needle, 0, false);
    while found && !over_limit {
        for from_index .. to_index - 1 {
            haystack[it] = replacement;
            change_count += 1;
            if max_replacements > 0 && change_count >= max_replacements {
                over_limit = true;
                break;
            }
        }
        from_index, to_index, found = index(haystack, needle, to_index, false);
    }

    return change_count;
}



count :: inline (haystack: string, needle: u8) -> total: int {
    return count(haystack, needle, current_compare);
}


count :: inline (haystack: string, needle: [] u8) -> total: int {
    return count(haystack, needle, current_compare);
}

count :: (haystack: string, needle: [] u8, compare: Character_Compare) -> total: int {
    if haystack == ""  return 0;

    total := 0;
    for needle  total += count(haystack, it, compare);
    return total;
}


count :: inline (haystack: string, needle: string) -> total: int {
    return count(haystack, needle, current_compare);
}

count :: (haystack: string, needle: string, compare: Character_Compare) -> total: int {
    if needle == ""  return 0;

    total := 0;
    index, found := first_index(haystack, needle, compare, current_first_index);
    while found {
        total += 1;
        index, found = first_index(haystack, needle, index + needle.count, compare, current_first_index);
    }

    return total;
}


count :: (haystack: string, needle: string, $$index: Index_Proc) -> total: int {
    total := 0;
    from_index, to_index, found := index(haystack, needle, 0, false);
    while found {
        total += 1;
        from_index, to_index, found = index(haystack, needle, to_index, false);
    }

    return total;
}



/// Alloc


// @TODO
// [ ] get `apply_backslash` and `escape` to handle `\u` and `\U`


copy_string :: (str: string, $$null_terminate: bool) -> string #must {
    if !str  return "";

    result : string = ---;
    if null_terminate && str[str.count - 1] != #char "\0" {
        result = alloc_string(str.count + 1);
        memcpy(result.data, str.data, str.count);
        result[result.count - 1] = #char "\0";
    }
    else {
        result = alloc_string(str.count);
        memcpy(result.data, str.data, str.count);
    }

    return result;
}


reverse :: (str: string, $$null_terminate := false) -> string #must {
    if !str  return "";

    result := copy_string(str, null_terminate);
    if null_terminate  result.count -= 1;
    reverse(*result);
    if null_terminate  result.count += 1;

    return result;
}



replace :: inline (haystack: string, needle: string, replacement: string, max_replacements := 0, $$null_terminate := false) -> string #must {
    return replace(haystack, needle, replacement, max_replacements, current_compare, null_terminate);
}

replace :: (haystack: string, needle: string, replacement: string, max_replacements := 0, compare: Character_Compare, $$null_terminate := false) -> string #must {
    assert(max_replacements >= 0, "max_replacements cannot be negative");

    if haystack == ""  return "";
    if needle == ""    return copy_string(haystack, null_terminate);

    builder: String_Builder;

    for split(haystack, needle, max_results = ifx max_replacements <= 0 then 0 else max_replacements + 1, compare = compare) {
        if it_index  append(*builder, replacement);
        append(*builder, it);
    }

    if null_terminate {
        buffer := get_current_buffer(*builder);
        if buffer.count == 0 || (get_buffer_data(buffer) + buffer.count - 1).* != #char "\0"
            append(*builder, #char "\0");
    }

    return builder_to_string(*builder);
}


replace :: (haystack: string, needle: string, index: Index_Proc, replacement: string, max_replacements := 0, $$null_terminate := false) -> string #must {
    if haystack == ""  return "";

    builder: String_Builder;

    first_loop := true;
    last_string := "";
    for make_split(haystack, needle, index, ifx max_replacements <= 0 then 0 else max_replacements + 1) {
        if first_loop  first_loop = false;
        else           append(*builder, replacement);
        append(*builder, it);
    }

    if null_terminate {
        buffer := get_current_buffer(*builder);
        if buffer.count == 0 || <<(get_buffer_data(buffer) + buffer.count - 1) != #char "\0"
            append(*builder, #char "\0");
    }

    return builder_to_string(*builder);
}



join :: (strings: [] string, $$null_terminate := false) -> string #must {
    if strings.count == 0  return "";
    if strings.count == 1  return copy_string(strings[0], null_terminate);

    terminating := null_terminate && !ends_with(strings[strings.count - 1], #char "\0", case_sensitive);
    maybe_extra_byte := ifx terminating then 1 else 0;

    count := 0;
    for strings  count += it.count;

    joined := alloc_string(count + maybe_extra_byte);
    memcpy(joined.data, strings[0].data, strings[0].count);
    position := joined.data + strings[0].count;
    for 1 .. strings.count - 1 {
        memcpy(position, strings[it].data, strings[it].count);
        position += strings[it].count;
    }

    if terminating  joined[count] = #char "\0";

    return joined;
}


join :: (strings: [] string, separator: string, $$null_terminate := false) -> string #must {
    if strings.count == 0  return "";
    if strings.count == 1  return copy_string(strings[0], null_terminate);
    if !separator          return join(strings, null_terminate);

    terminating := null_terminate && !ends_with(strings[strings.count - 1], #char "\0", case_sensitive);
    maybe_extra_byte := ifx terminating then 1 else 0;

    count := separator.count * (strings.count - 1);
    for strings  count += it.count;

    joined := alloc_string(count + maybe_extra_byte);
    memcpy(joined.data, strings[0].data, strings[0].count);
    position := joined.data + strings[0].count;
    for 1 .. strings.count - 1 {
        memcpy(position, separator.data, separator.count);
        position += separator.count;
        memcpy(position, strings[it].data, strings[it].count);
        position += strings[it].count;
    }

    if terminating  joined[count] = #char "\0";

    return joined;
}


join :: inline (strings: .. string, $$null_terminate := false) -> string #must {
    return join(strings, null_terminate);
}


join :: (strings: [] string, separator: u8, $$null_terminate := false) -> string #must {
    return join(strings, char_as_string(*separator));
}



#scope_file
default_pad_with :: "                                                                ";
#scope_export


pad_start :: (str: string, desired_count: int, pad_with := default_pad_with, $$null_terminate := false) -> string #must {
    assert(pad_with.count > 0, "pad_with cannot be empty");

    if str.count >= desired_count
        return copy_string(str, null_terminate);

    terminating := null_terminate && !ends_with(str, #char "\0", case_sensitive);
    maybe_extra_byte := ifx terminating then 1 else 0;

    padded := alloc_string(desired_count + maybe_extra_byte);
    padded_index := 0;
    padding_chars_required := desired_count - str.count;
    while padded_index <= padding_chars_required - pad_with.count {
        memcpy(padded.data + padded_index, pad_with.data, pad_with.count);
        padded_index += pad_with.count;
    }
    if padded_index < padding_chars_required
        memcpy(padded.data + padded_index, pad_with.data, padding_chars_required - padded_index);

    memcpy(padded.data + padding_chars_required, str.data, str.count);

    if terminating  padded[padded.count] = #char "\0";

    return padded;
}


pad_start :: inline (str: string, desired_count: int, pad_with: u8, $$null_terminate := false) -> string #must {
    return pad_start(str, desired_count, char_as_string(*pad_with), null_terminate);
}


pad_end :: (str: string, desired_count: int, pad_with := default_pad_with, $$null_terminate := false) -> string #must {
    assert(pad_with.count > 0, "pad_with cannot be empty");

    if str.count >= desired_count
        return copy_string(str, null_terminate);

    terminating := null_terminate && !ends_with(str, #char "\0", case_sensitive);
    maybe_extra_byte := ifx terminating then 1 else 0;

    padded := alloc_string(desired_count + maybe_extra_byte);
    padded_index := desired_count - pad_with.count;
    while padded_index >= str.count {
        memcpy(padded.data + padded_index, pad_with.data, pad_with.count);
        padded_index -= pad_with.count;
    }
    remainder := padded_index - str.count;
    if remainder < 0 // only happens when the initial padding string already overshoots the desired padding amount
        memcpy(padded.data + str.count, pad_with.data - remainder, pad_with.count + remainder);
    else if remainder > 0
        memcpy(padded.data + str.count, pad_with.data + pad_with.count - remainder, remainder);

    memcpy(padded.data, str.data, str.count);

    if terminating  padded[padded.count] = #char "\0";

    return padded;
}


pad_end :: inline (str: string, desired_count: int, pad_with: u8, $$null_terminate := false) -> string #must {
    return pad_end(str, desired_count, char_as_string(*pad_with), null_terminate);
}


pad_start_and_end :: (str: string, desired_count: int, pad_with := default_pad_with, $$null_terminate := false) -> string #must {
    assert(pad_with.count > 0, "pad_with cannot be empty");

    if str.count >= desired_count
        return copy_string(str, null_terminate);

    terminating := null_terminate && !ends_with(str, #char "\0", case_sensitive);
    maybe_extra_byte := ifx terminating then 1 else 0;

    padded := alloc_string(desired_count + maybe_extra_byte);
    center_index := (desired_count - str.count) / 2;

    // start
    padded_index := 0;
    padding_chars_required := center_index;
    while padded_index <= padding_chars_required - pad_with.count {
        memcpy(padded.data + padded_index, pad_with.data, pad_with.count);
        padded_index += pad_with.count;
    }
    if padded_index < padding_chars_required
        memcpy(padded.data + padded_index, pad_with.data, padding_chars_required - padded_index);

    // end
    padded_index = desired_count - pad_with.count;
    end_index := center_index + str.count;
    while padded_index >= end_index {
        memcpy(padded.data + padded_index, pad_with.data, pad_with.count);
        padded_index -= pad_with.count;
    }
    remainder := padded_index - end_index;
    if remainder < 0 // only happens when the initial padding string already overshoots the desired padding amount
        memcpy(padded.data + end_index, pad_with.data - remainder, pad_with.count + remainder);
    else if remainder > 0
        memcpy(padded.data + end_index, pad_with.data + pad_with.count - remainder, remainder);

    memcpy(padded.data + center_index, str.data, str.count);

    if terminating  padded[padded.count] = #char "\0";

    return padded;
}


pad_start_and_end :: inline (str: string, desired_count: int, pad_with: u8, $$null_terminate := false) -> string #must {
    return pad_start_and_end(str, desired_count, char_as_string(*pad_with), null_terminate);
}



repeat :: (str: string, times: int, $$null_terminate := false) -> string #must {
    if str == "" || times <= 0  return "";

    terminating := null_terminate && !ends_with(str, #char "\0", case_sensitive);
    maybe_extra_byte := ifx terminating then 1 else 0;

    count := str.count * times;

    repeated := alloc_string(count + maybe_extra_byte);
    memcpy(repeated.data, str.data, str.count);

    copied_count := str.count;
    next_copied_count := copied_count * 2;
    while next_copied_count < count {
        memcpy(repeated.data + copied_count, repeated.data, copied_count);
        copied_count = next_copied_count;
        next_copied_count *= 2;
    }

    if copied_count < count
        memcpy(repeated.data + copied_count, repeated.data, count - copied_count);

    if terminating  repeated[count] = #char "\0";

    return repeated;
}


to_lower :: (str: string, $$null_terminate := false) -> string #must {
    result := copy_string(str, null_terminate);
    to_lower(*result);
    return result;
}


to_upper :: (str: string, $$null_terminate := false) -> string #must {
    result := copy_string(str, null_terminate);
    to_upper(*result);
    return result;
}


to_capitalized :: (str: string, preserve_caps: = true, $$null_terminate := false) -> string #must {
    if !str  return "";

    result := copy_string(str, null_terminate);
    to_capitalized(*result, preserve_caps);

    return result;
}


snake_from_camel :: (str: string, preserve_caps := false, $$null_terminate := false) -> string #must {
    if str == ""  return "";

    builder: String_Builder;
    inside_caps := false;

    for i: 0 .. str.count - 1 {
        c := str[i];
        if is_upper(c) {
            if !inside_caps || i < str.count - 1 && is_lower(str[i + 1]) {
                inside_caps = true;
                if i > 0  append(*builder, "_");
                if preserve_caps
                    append(*builder, c);
                else
                    append(*builder, to_lower(c));
            }
            else
                append(*builder, to_lower(c));
        }
        else {
            inside_caps = false;
            append(*builder, c);
        }
    }

    if null_terminate {
        buffer := get_current_buffer(*builder);
        if buffer.count == 0 || <<(get_buffer_data(buffer) + buffer.count - 1) != #char "\0"
            append(*builder, #char "\0");
    }

    return builder_to_string(*builder);
}


camel_from_snake :: (str: string, preserve_caps := false, $$null_terminate := false) -> string #must {
    if str == ""  return "";

    builder: String_Builder;

    for word: make_split(str, #char "_", current_compare) {
        if word {
            append(*builder, word);
            buffer := get_current_buffer(*builder);
            in_place : string = ---;
            in_place.data = get_buffer_data(buffer) + buffer.count - word.count;
            in_place.count = word.count;
            to_capitalized(*in_place, preserve_caps);
        }
    }

    if null_terminate {
        buffer := get_current_buffer(*builder);
        if buffer.count == 0 || <<(get_buffer_data(buffer) + buffer.count - 1) != #char "\0"
            append(*builder, #char "\0");
    }

    return builder_to_string(*builder);
}


apply_backslash :: (str: string, $$null_terminate := false) -> string #must, well_formed: bool {
    if str == ""  return "", true;

    builder: String_Builder;

    i := 0;
    well_formed := true;

    while i < str.count {
        if str[i] == #char "\\" {
            i += 1;
            if i >= str.count { well_formed = false; break; }
            if str[i] == {
                case #char "\\";
                append(*builder, #char "\\");

                case #char "e";
                append(*builder, #char "\e");

                case #char "n";
                append(*builder, #char "\n");

                case #char "r";
                append(*builder, #char "\r");

                case #char "t";
                append(*builder, #char "\t");

                case #char "\"";
                append(*builder, #char "\"");

                case #char "0";
                append(*builder, #char "\0");

                case #char "x";
                i += 2;
                if i >= str.count { well_formed = false; break; }
                value : u8 = hex_char_value(str[i - 1]) * 16 + hex_char_value(str[i]);
                append(*builder, value);

                case #char "d";
                i += 3;
                if i >= str.count { well_formed = false; break; }
                value : u8 = hex_char_value(str[i - 2]) * 100 + hex_char_value(str[i - 1]) * 10 + hex_char_value(str[i]);
                append(*builder, value);

                /* @TODO
                case #char "u";
                    i += 4;
                    if i >= str.count { well_formed = false; break; }
                    value : u16 = hex_char_value(str[i - 3]) * 16 * 16 * 16;
                    value += hex_char_value(str[i - 2]) * 16 * 16;
                    value += hex_char_value(str[i - 1]) * 16;
                    value += hex_char_value(str[i]);
                    append(*builder, character_utf32_to_utf8(xx value));

                case #char "U";
                    i += 8;
                    if i >= str.count { well_formed = false; break; }
                    value : u32 = hex_char_value(str[i - 7]) * 16 * 16 * 16 * 16 * 16 * 16 * 16;
                    value += hex_char_value(str[i - 6])      * 16 * 16 * 16 * 16 * 16 * 16;
                    value += hex_char_value(str[i - 5])      * 16 * 16 * 16 * 16 * 16;
                    value += hex_char_value(str[i - 4])      * 16 * 16 * 16 * 16;
                    value += hex_char_value(str[i - 3])      * 16 * 16 * 16;
                    value += hex_char_value(str[i - 2])      * 16 * 16;
                    value += hex_char_value(str[i - 1])      * 16;
                    value += hex_char_value(str[i]);
                    append(*builder, character_utf32_to_utf8(value));
                */

                case;
                i -= 1;
                well_formed = false;
            }
        }
        else {
            append(*builder, str[i]);
        }
        i += 1;
    }

    if null_terminate {
        buffer := get_current_buffer(*builder);
        if buffer.count == 0 || (get_buffer_data(buffer) + buffer.count - 1).* != #char "\0"
            append(*builder, #char "\0");
    }

    return builder_to_string(*builder), well_formed;
}


escape :: (str: string, $$null_terminate := false) -> string #must {
    if str == ""  return "";

    builder: String_Builder;

    for i: 0 .. str.count - 1 {
        if str[i] == {
            case #char "\\";
            append(*builder, "\\\\");

            case #char "\e";
            append(*builder, "\\e");

            case #char "\n";
            append(*builder, "\\n");

            case #char "\r";
            append(*builder, "\\r");

            case #char "\t";
            append(*builder, "\\t");

            case #char "\"";
            append(*builder, "\\\"");

            case #char "\0";
            append(*builder, "\\0");

            /* @TODO
            case #char "u";
            i += 4;
            if i >= str.count { well_formed = false; break; }
            value : u16 = hex_char_value(str[i - 3]) * 16 * 16 * 16;
            value += hex_char_value(str[i - 2]) * 16 * 16;
            value += hex_char_value(str[i - 1]) * 16;
            value += hex_char_value(str[i]);
            append(*builder, character_utf32_to_utf8(xx value));

            case #char "U";
            i += 8;
            if i >= str.count { well_formed = false; break; }
            value : u32 = hex_char_value(str[i - 7]) * 16 * 16 * 16 * 16 * 16 * 16 * 16;
            value += hex_char_value(str[i - 6])      * 16 * 16 * 16 * 16 * 16 * 16;
            value += hex_char_value(str[i - 5])      * 16 * 16 * 16 * 16 * 16;
            value += hex_char_value(str[i - 4])      * 16 * 16 * 16 * 16;
            value += hex_char_value(str[i - 3])      * 16 * 16 * 16;
            value += hex_char_value(str[i - 2])      * 16 * 16;
            value += hex_char_value(str[i - 1])      * 16;
            value += hex_char_value(str[i]);
            append(*builder, character_utf32_to_utf8(value));
            */
            case;
            if str[i] < 32
                print_to_builder(*builder, "\\x%", formatInt(str[i], 16, 2));
            else
                append(*builder, str[i]);
        }
    }

    if null_terminate {
        buffer := get_current_buffer(*builder);
        if buffer.count == 0 || <<(get_buffer_data(buffer) + buffer.count - 1) != #char "\0"
            append(*builder, #char "\0");
    }

    return builder_to_string(*builder);
}


#scope_file


hex_char_value :: inline (c: u8) -> u8 {
    hex_char_values :: u8.[0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                           0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                           0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                           0,  1,  2,  3,  4,  5,  6, 7, 8, 9, 0, 0, 0, 0, 0, 0,
                           0, 10, 11, 12, 13, 14, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                           0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                           0, 10, 11, 12, 13, 14, 15];

    if c >= hex_char_values.count  return 0;
    return hex_char_values[c];
}

