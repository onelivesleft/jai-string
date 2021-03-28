// All functions return a string view and/or mutate a string view in-place


// TODO
// [ ] bake cmp?
// [ ] ask about autobaking problem on first_index (when cmp is autobaked you cannot switch proc using set_index_algorithm)
// [ ] unicode support
// [x] first_index lambda needle
// [x] split at
// [x] trim string characters?
// [x] default_compare


#import "Basic";

current_first_index := default_first_index;
current_last_index := default_last_index;

set_index_algorithm :: (first_index_proc := default_first_index, last_index_proc := def) {
    current_first_index = first_index_proc;
    current_last_index = last_index_proc;
}


slice_index :: inline (str: string, index: int) -> normalized_index: int #must, valid_when_strict: bool {
    if index < 0  index += str.count;

    if index < 0               return 0, false;
    else if index > str.count  return str.count, false;
    else                       return index, true;
}


slice :: inline (str: string, from_index: int, to_index: int) -> string #must, normalized_from_index: int, normalized_to_index: int {
    #if strict {
        if from_index < 0  from_index = str.count + from_index;

        assert(from_index >= 0 && from_index <= str.count, "Cannot slice; from_index falls outwith range of string.");

        if to_index < 0  to_index = str.count + to_index;

        assert(to_index >= from_index, "Cannot slice; to_index is ahead of to_index.");
        assert(to_index <= str.count, "Cannot slice; to_index falls outwith range of string.");
    }
    else {
        if from_index >= 0  from_index = min(from_index, str.count);
        else                from_index = clamp(str.count + from_index, 0, str.count);

        if to_index >= 0  to_index = min(to_index, str.count);
        else              to_index = clamp(str.count + to_index, 0, str.count);
    }

    if from_index >= to_index  return "", from_index, to_index;

    result : string = ---;
    result.data = str.data + from_index;
    result.count = to_index - from_index;
    return result, from_index, to_index;
}


slice :: inline (str: string, from_index: int) -> string #must, normalized_from_index: int, normalized_to_index: int {
    result, normalized_from_index, normalized_to_index := slice(str, from_index, str.count);
    return result, normalized_from_index, normalized_to_index;
}


unsafe_slice :: inline (str: string, from_index: int, to_index: int) -> string #must {
    // @Note Handles positive indexes only!
    assert(from_index >= 0 && from_index <= str.count, "Cannot slice; from_index falls outwith range of string.");
    assert(to_index >= from_index, "Cannot slice; to_index is ahead of from_index.");
    assert(to_index <= str.count, "Cannot slice; to_index falls outwith range of string.");

    result : string = ---;
    result.data = str.data + from_index;
    result.count = to_index - from_index;
    return result;
}


unsafe_slice :: inline (str: string, from_index: int) -> string #must {
    // @Note Handles positive index only!
    assert(from_index >= 0 && from_index <= str.count, "Cannot slice; from_index falls outwith range of string.");

    result : string = ---;
    result.data = str.data + from_index;
    result.count = str.count - from_index;
    return result;
}



substring :: (str: string, from_index: int) -> string #must {
    return slice(str, from_index, str.count);
}


substring :: (str: string, from_index: int, count: int) -> string #must {
    #if strict {
        assert(count >= 0, "substring count must not be negative.");
    }
    else {
        if count <= 0  return "";
    }

    return slice(str, from_index, from_index + count);
}


case_sensitive :: inline (a: u8, b: u8) -> bool #must {
    return a == b;
}


ignore_case :: inline (a: u8, b: u8) -> bool #must {
    lower_a : int = ifx a >= #char "A" && a <= #char "Z" then a + #char "a" - #char "A" else a;
    lower_b : int = ifx b >= #char "A" && b <= #char "Z" then b + #char "a" - #char "A" else b;
    return lower_a == lower_b;
}


is_any :: inline (needle: u8, characters: [] u8, $$cmp := default_compare) -> bool #must {
    for character: characters
        if cmp(needle, character)  return true;

    return false;
}


string_from_char :: (char: *u8) -> string #must {
    result : string = ---;
    result.data = char;
    result.count = 1;
    return result;
}


starts_with :: (haystack: string, needle: string, $$cmp := default_compare) -> bool #must {
    if haystack.count < needle.count  return false;

    for 0 .. needle.count - 1
        if !cmp(haystack[it], needle[it])
            return false;

    return true;
}


starts_with :: inline (haystack: string, needle: u8) -> bool #must {
    return haystack.count > 0 && haystack[0] == needle;
}


starts_with :: inline (haystack: string, needle: [] u8) -> bool #must {
    return haystack.count > 0 && is_any(haystack[0], needle);
}


starts_with :: inline (haystack: string, needle: string, $$index: Index_Proc) -> bool #must {
    return index(haystack, needle, 0, false) == 0;
}


ends_with :: (haystack: string, needle: string, $$cmp := default_compare) -> bool #must {
    if haystack.count < needle.count  return false;

    needle_index := 0;

    for haystack.count - needle.count .. haystack.count - 1 {
        if !cmp(haystack[it], needle[needle_index])
            return false;

        needle_index += 1;
    }

    return true;
}


ends_with :: inline (haystack: string, needle: u8) -> bool #must {
    return haystack.count > 0 && haystack[haystack.count - 1] == needle;
}


ends_with :: inline (haystack: string, needle: [] u8) -> bool #must {
    return haystack.count > 0 && is_any(haystack[haystack.count - 1], needle);
}


ends_with :: inline (haystack: string, needle: string, $$index: Index_Proc) -> bool #must {
    from_index, to_index, found := index(haystack, needle, haystack.count, true);
    return to_index == haystack.count;
}



// @Note `needle` is guaranteed to be at least 2 characters long.
// @TODO check back here after compiler can optimize code, to see if nicely written
//       version is just as fast.

naive_first_index :: (haystack: string, needle: string, start_index: int, cmp: Character_Compare) -> index: int #must, found: bool {
    if start_index > haystack.count - needle.count  return -1, false;

    end := cast(u64)haystack.data + cast(u64)(haystack.count - needle.count);
    needle_end := cast(u64)needle.count - 1;
    for start_of_word: cast(u64)haystack.data + cast(u64)start_index .. end {
        needle_index := needle.data;
        for character: start_of_word .. start_of_word + needle_end {
            if !cmp(<<cast(*u8)character, <<needle_index)
                continue start_of_word;
            needle_index += 1;
        }
        return cast(int)(start_of_word - cast(u64)haystack.data), true;
    }

    return -1, false;
}


naive_last_index :: (haystack: string, needle: string, start_index: int, cmp: Character_Compare) -> index: int #must, found: bool {
    if start_index < needle.count  return -1, false;

    start := cast(u64)haystack.data + cast(u64)(start_index - needle.count);
    needle_end := cast(u64)needle.count - 1;
    for < start_of_word: start .. cast(u64)haystack.data {
        needle_index := needle.data;
        for character: start_of_word .. start_of_word + needle_end {
            if !cmp(<<cast(*u8)character, <<needle_index)
                continue start_of_word;
            needle_index += 1;
        }
        return cast(int)(start_of_word - cast(u64)haystack.data), true;
    }

    return -1, false;
}


#scope_file


validate_start_index :: (str: string) #expand {
    #if strict {
        if `start_index < 0  `start_index = str.count + `start_index;
        assert(`start_index >= 0 && `start_index <= str.count, "start_index falls outwith range of string.");
    }
    else {
        if `start_index < 0  `start_index = clamp(str.count + `start_index, 0, str.count);
        else                `start_index = clamp(`start_index, 0, str.count);
    }
}


#scope_export


first_index :: (haystack: string, needle: u8, start_index := 0) -> index: int #must, found: bool {
    validate_start_index(haystack);

    for cast(u64)haystack.data + cast(u64)start_index .. cast(u64)haystack.data + cast(u64)haystack.count - 1
        if <<cast(*u8)it == needle
            return cast(int)(it - cast(u64)haystack.data), true;

    return -1, false;
}


first_index :: (haystack: string, needle: [] u8, start_index := 0) -> index: int #must, found: bool {
    validate_start_index(haystack);

    for cast(u64)haystack.data + cast(u64)start_index .. cast(u64)haystack.data + cast(u64)haystack.count - 1
        if is_any(<<cast(*u8)it, needle)
            return cast(int)(it - cast(u64)haystack.data), true;

    return -1, false;
}


first_index :: inline (haystack: string, needle: string, start_index := 0, $$cmp := default_compare) -> index: int #must, found: bool {
    validate_start_index(haystack);
    if needle.count == 0 {
        return start_index, true;
    }
    else if needle.count == 1 {
        for cast(u64)haystack.data + cast(u64)start_index .. cast(u64)haystack.data + cast(u64)haystack.count - 1
            if cmp(<<cast(*u8)it, <<needle.data)
                return cast(int)(it - cast(u64)haystack.data), true;
        return -1, false;
    }
    else {
        index, found := current_first_index(haystack, needle, start_index, cmp);
        return index, found;
    }
}


first_index :: inline (haystack: string, needle: string, $$cmp: Character_Compare) -> index: int #must, found: bool {
    index, found := first_index(haystack, needle, 0, cmp);
    return index, found;
}


first_index :: (haystack: string, needle: string, $$index: Index_Proc, start_index := 0) -> from_index: int #must, found: bool, to_index: int {
    from_index, to_index, found := index(haystack, needle, start_index, false);
    return from_index, found, to_index;
}


reverse_index_proc :: (index_proc: Index_Proc, haystack: string, needle: string, boundary_index: int) -> from_index: int, to_index: int, found: bool {
    for < haystack_index: haystack.count - 1 .. 0 {
        s := unsafe_slice(haystack, haystack_index);
        from_index, to_index, found := index_proc(s, needle, 0, false);
        if found && haystack_index + to_index <= boundary_index
            return haystack_index + from_index, haystack_index + to_index, true;
    }

    return -1, -1, false;
}


Index_Proc :: #type(haystack: string, needle: string, boundary_index: int, reverse: bool) -> from_index: int, to_index: int, found: bool;


last_index :: (haystack: string, needle: u8) -> index: int #must, found: bool {
    for < cast(u64)haystack.data + cast(u64)haystack.count - 1 .. cast(u64)haystack.data
        if <<cast(*u8)it == needle
            return cast(int)(it - cast(u64)haystack.data), true;


    return -1, false;
}


last_index :: (haystack: string, needle: [] u8) -> index: int #must, found: bool {
    for < cast(u64)haystack.data + cast(u64)haystack.count - 1 .. cast(u64)haystack.data
        if is_any(<<cast(*u8)it, needle)
            return cast(int)(it - cast(u64)haystack.data), true;

    return -1, false;
}


last_index :: (haystack: string, needle: u8, start_index : int) -> index: int #must, found: bool {
    if start_index == 0  return -1, false;

    start_index -= 1;
    validate_start_index(haystack);

    for < cast(u64)haystack.data + cast(u64)start_index .. cast(u64)haystack.data
        if <<cast(*u8)it == needle
            return cast(int)(it - cast(u64)haystack.data), true;

    return -1, false;
}


last_index :: (haystack: string, needle: [] u8, start_index : int) -> index: int #must, found: bool {
    if start_index == 0  return -1, false;

    start_index -= 1;
    validate_start_index(haystack);

    for < cast(u64)haystack.data + cast(u64)start_index .. cast(u64)haystack.data
        if is_any(<<cast(*u8)it, needle)
            return cast(int)(it - cast(u64)haystack.data), true;

    return -1, false;
}


last_index :: inline (haystack: string, needle: string, start_index: int, $$cmp: Character_Compare) -> index: int #must, found: bool {
    validate_start_index(haystack);
    if needle.count == 0 {
        return start_index, true;
    }
    else if needle.count == 1 {
        for < cast(u64)haystack.data + cast(u64)start_index - 1.. cast(u64)haystack.data
            if cmp(<<cast(*u8)it, needle[0])
                return cast(int)(it - cast(u64)haystack.data), true;
        return -1, false;
    }
    else {
        index, found := current_last_index(haystack, needle, start_index, cmp);
        return index, found;
    }
}


last_index :: inline (haystack: string, needle: string, $$cmp: Character_Compare) -> index: int #must, found: bool {
    index, found := last_index(haystack, needle, haystack.count, cmp);
    return index, found;
}


last_index :: inline (haystack: string, needle: string, start_index: int) -> index: int #must, found: bool {
    index, found := last_index(haystack, needle, start_index, default_compare);
    return index, found;
}


last_index :: inline (haystack: string, needle: string) -> index: int #must, found: bool {
    index, found := last_index(haystack, needle, haystack.count, default_compare);
    return index, found;
}


last_index :: (haystack: string, needle: string, $$index: Index_Proc) -> from_index: int #must, found: bool, to_index: int {
    from_index, to_index, found := index(haystack, needle, haystack.count, true);
    return from_index, found, to_index;
}


last_index :: (haystack: string, needle: string, $$index: Index_Proc, start_index: int) -> from_index: int #must, found: bool, to_index: int {
    from_index, to_index, found := index(haystack, needle, start_index, true);
    return from_index, found, to_index;
}


contains :: (haystack: string, needle: u8) -> bool #must {
    _, found := first_index(haystack, needle);
    return found;
}


contains :: (haystack: string, needle: [] u8) -> bool #must {
    _, found := first_index(haystack, needle);
    return found;
}


contains :: (haystack: string, needle: string, $$cmp := default_compare) -> bool #must {
    _, found := first_index(haystack, needle, cmp);
    return found;
}


contains :: (haystack: string, needle: string, $$index: Index_Proc) -> bool #must {
    _, __, found := index(haystack, needle, 0, false);
    return found;
}



trim :: inline (str: string, char: u8) -> string #must {
    chars : [1] u8 = ---;
    chars[0] = char;
    return trim(str, chars);
}


trim :: (str: string) -> string #must {
    low_index := 0;
    high_index := str.count - 1;

    while low_index < str.count && str[low_index] <= SPACE
        low_index += 1;

    if low_index >= str.count  return "";

    while high_index > low_index && str[high_index] <= SPACE
        high_index -= 1;

    return unsafe_slice(str, low_index, high_index + 1);
}


trim :: (str: string, chars : [] u8) -> string #must {
    #if strict {
        assert(chars.count, "You cannot trim nothing!");
    }
    else {
        if chars.count == 0  return str;
    }

    low_index := 0;
    high_index := str.count - 1;

    while low_index < str.count && is_any(str[low_index], chars)
        low_index += 1;

    if low_index >= str.count  return "";

    while high_index > low_index && is_any(str[high_index], chars)
        high_index -= 1;

    return unsafe_slice(str, low_index, high_index + 1);
}


trim :: (str: string, string_to_remove: string, $$cmp := default_compare) -> string #must {
    #if strict {
        assert(string_to_remove != "", "You cannot trim nothing!");
    }
    else {
        if string_to_remove == ""  return str;
    }

    s := str;
    while s.count > string_to_remove.count && starts_with(s, string_to_remove, cmp = cmp)
        s = unsafe_slice(s, string_to_remove.count);

    if !s  return "";

    while s.count > string_to_remove.count && ends_with(s, string_to_remove, cmp = cmp)
        s = unsafe_slice(s, 0, s.count - string_to_remove.count);

    return s;
}


trim :: (str: string, string_to_remove: string, $$index: Index_Proc) -> string #must {
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


trim_start :: inline (str: string, char: u8) -> string #must {
    chars : [1] u8 = ---;
    chars[0] = char;
    return trim_start(str, chars);
}


trim_start :: inline (str: string) -> string #must {
    index := 0;

    while index < str.count && str[index] <= SPACE
        index += 1;

    if index >= str.count  return "";

    return unsafe_slice(str, index);
}


trim_start :: inline (str: string, chars : [] u8) -> string #must {
    #if strict {
        assert(chars.count, "You cannot trim nothing!");
    }
    else {
        if chars.count == 0  return str;
    }

    index := 0;

    while index < str.count && is_any(str[index], chars)
        index += 1;

    if index >= str.count  return "";

    return unsafe_slice(str, index);
}


trim_start :: (str: string, string_to_remove: string, $$cmp := default_compare) -> string #must {
    #if strict {
        assert(string_to_remove != "", "You cannot trim nothing!");
    }
    else {
        if string_to_remove == ""  return str;
    }

    s := str;
    while s.count > string_to_remove.count && starts_with(s, string_to_remove, cmp = cmp)
        s = unsafe_slice(s, string_to_remove.count);

    return s;
}


trim_start :: (str: string, string_to_remove: string, $$index: Index_Proc) -> string #must {
    s := str;
    from_index, to_index, found := index(s, string_to_remove, 0, false);
    while s && from_index == 0 {
        s = unsafe_slice(s, to_index);
        from_index, to_index, found = index(s, string_to_remove, 0, false);
    }

    return s;
}



trim_end :: inline (str: string, char: u8) -> string #must {
    chars : [1] u8 = ---;
    chars[0] = char;
    return trim_end(str, chars);
}


trim_end :: inline (str: string) -> string #must {
    index := str.count - 1;

    while index >= 0 && str[index] <= SPACE
        index -= 1;

    if index < 0  return "";

    return unsafe_slice(str, 0, index + 1);
}


trim_end :: inline (str: string, chars : [] u8) -> string #must {
    #if strict {
        assert(chars.count, "You cannot trim nothing!");
    }
    else {
        if chars.count == 0  return str;
    }

    index := str.count - 1;

    while index >= 0 && is_any(str[index], chars)
        index -= 1;

    if index < 0  return "";

    return unsafe_slice(str, 0, index + 1);
}


trim_end :: (str: string, string_to_remove: string, $$cmp := default_compare) -> string #must {
    #if strict {
        assert(string_to_remove != "", "You cannot trim nothing!");
    }
    else {
        if string_to_remove == ""  return str;
    }

    s := str;
    while s.count > string_to_remove.count && ends_with(s, string_to_remove, cmp = cmp)
        s = unsafe_slice(s, 0, s.count - string_to_remove.count);

    return s;
}


trim_end :: (str: string, string_to_remove: string, $$index: Index_Proc) -> string #must {
    s := str;
    from_index, to_index, found := index(s, string_to_remove, s.count, true);
    while s && to_index == s.count {
        s = unsafe_slice(s, 0, from_index);
        from_index, to_index, found = index(s, string_to_remove, s.count, true);
    }

    return s;
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


is_lower :: inline (char: u8) -> bool #must {
    return char >= #char "a" && char <= #char "z";
}


is_upper :: inline (char: u8) -> bool #must {
    return char >= #char "A" && char <= #char "Z";
}


reverse :: (str: string) {
    low_index := 0;
    high_index := str.count - 1;
    while low_index < high_index {
        c := str[low_index];
        str[low_index] = str[high_index];
        str[high_index] = c;
        low_index += 1;
        high_index -= 1;
    }
}


replace :: (haystack: string, needle: u8, replacement: u8, max_replacements := 0) -> change_count: int {
    change_count := 0;
    for 0 .. haystack.count - 1 {
        if haystack[it] == needle {
            haystack[it] = replacement;
            change_count += 1;
            if max_replacements > 0 && change_count >= max_replacements  break;
        }
    }

    return change_count;
}


replace :: (haystack: string, needle: [] u8, replacement: u8, max_replacements := 0) -> change_count: int {
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


replace :: inline (haystack: string, needle: string, replacement: u8, $$cmp: Character_Compare) -> change_count: int {
    return replace(haystack, needle, replacement, 0, cmp);
}


replace :: (haystack: string, needle: string, replacement: u8, max_replacements := 0, $$cmp := default_compare) -> change_count: int {
    change_count := 0;
    over_limit := false;
    index, found := first_index(haystack, needle, cmp);
    while found && !over_limit {
        for index .. index + needle.count - 1 {
            haystack[it] = replacement;
            change_count += 1;
            if max_replacements > 0 && change_count >= max_replacements {
                over_limit = true;
                break;
            }
        }
        index, found = first_index(haystack, needle, index + needle.count, cmp);
    }

    return change_count;
}


replace :: (haystack: string, needle: string, $$index: Index_Proc, replacement: u8, max_replacements := 0) -> change_count: int {
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


Character_Translation :: struct {
    needle: u8;
    replacement: u8;
}


replace :: (haystack: string, translation: [] Character_Translation, max_replacements := 0) -> change_count: int {
    change_count := 0;
    for index: 0 .. haystack.count - 1 {
        for entry: translation {
            if haystack[index] == entry.needle {
                haystack[index] = entry.replacement;
                change_count += 1;
                if max_replacements > 0 && change_count >= max_replacements
                    break index;
                break;
            }
        }
    }

    return change_count;
}



count :: (haystack: string, needle: u8) -> total: int #must {
    total := 0;
    for 0 .. haystack.count - 1 {
        if haystack[it] == needle {
            total += 1;
        }
    }

    return total;
}


count :: (haystack: string, needle: [] u8) -> total: int #must {
    if needle.count == 0  return 0;

    total := 0;
    for 0 .. haystack.count - 1 {
        if is_any(haystack[it], needle) {
            total += 1;
        }
    }

    return total;
}


count :: (haystack: string, needle: string, $$cmp := default_compare) -> total: int #must {
    if needle == ""  return 0;

    total := 0;
    index, found := first_index(haystack, needle, cmp);
    while found {
        total += 1;
        index, found = first_index(haystack, needle, index + needle.count, cmp);
    }

    return total;
}


count :: (haystack: string, needle: string, $$index: Index_Proc) -> total: int #must {
    total := 0;
    from_index, to_index, found := index(haystack, needle, 0, false);
    while found {
        total += 1;
        from_index, to_index, found = index(haystack, needle, to_index, false);
    }

    return total;
}


count :: (haystack: string, translation: [] Character_Translation) -> total: int {
    if translation.count == 0  return 0;

    total := 0;
    for 0 .. haystack.count - 1 {
        for entry: translation {
            if haystack[it] == entry.needle {
                total += 1;
                break;
            }
        }
    }

    return total;
}


capitalize :: (str: string, preserve_caps := true) {
    if !str  return;

    str[0] = to_upper(str[0]);
    if !preserve_caps
        for 1 .. str.count - 1
            str[it] = to_lower(str[it]);
}


Split_By :: struct {
    text        : string;
    reverse     : bool;
    max_results : int;
    skip_empty  : bool;
}

Split_By_String :: struct {
    using base: Split_By;
    separator : string;
    cmp       : Character_Compare;
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


#scope_file


fill_split_struct :: (reversed: bool) #expand {
    `result.text = `text;
    `result.max_results = `max_results;
    `result.skip_empty = `skip_empty;
    `result.reverse = reversed;
}


#scope_export


forward_split :: (text: string, separator: string, $$cmp: Character_Compare, skip_empty := false, max_results := 0) -> Split_By_String #must {
    result : Split_By_String = ---;
    fill_split_struct(false);
    result.separator = separator;
    result.cmp = cmp;
    return result;
}

reverse_split :: (text: string, separator: string, $$cmp: Character_Compare, skip_empty := false, max_results := 0) -> Split_By_String #must {
    result : Split_By_String = ---;
    fill_split_struct(true);
    result.separator = separator;
    result.cmp = cmp;
    return result;
}


forward_split :: inline (text: string, separator: string, skip_empty := false, max_results := 0) -> Split_By_String #must {
    return forward_split(text, separator, default_compare, skip_empty, max_results);
}

reverse_split :: inline (text: string, separator: string, skip_empty := false, max_results := 0) -> Split_By_String #must {
    return reverse_split(text, separator, default_compare, skip_empty, max_results);
}


forward_split :: (text: string, separator: [] u8, skip_empty := false, max_results := 0) -> Split_By_Chars #must {
    result : Split_By_Chars = ---;
    fill_split_struct(false);
    result.separator = separator;
    return result;
}

reverse_split :: (text: string, separator: [] u8, skip_empty := false, max_results := 0) -> Split_By_Chars #must {
    result : Split_By_Chars = ---;
    fill_split_struct(true);
    result.separator = separator;
    return result;
}


forward_split :: (text: string, separator: u8, skip_empty := false, max_results := 0) -> Split_By_Char #must {
    result : Split_By_Char = ---;
    fill_split_struct(false);
    result.separator = separator;
    return result;
}

reverse_split :: (text: string, separator: u8, skip_empty := false, max_results := 0) -> Split_By_Char #must {
    result : Split_By_Char = ---;
    fill_split_struct(true);
    result.separator = separator;
    return result;
}


forward_split :: (text: string, indexes: .. int, skip_empty := false, max_results := 0) -> Split_By_Index #must {
    result : Split_By_Index = ---;
    fill_split_struct(false);
    result.indexes = indexes;
    return result;
}

reverse_split :: (text: string, indexes: .. int, skip_empty := false, max_results := 0) -> Split_By_Index #must {
    result : Split_By_Index = ---;
    fill_split_struct(true);
    result.indexes = indexes;
    return result;
}


forward_split :: (text: string, separator: string, $$index: Index_Proc, skip_empty := false, max_results := 0) -> Split_By_Proc #must {
    result : Split_By_Proc = ---;
    fill_split_struct(false);
    result.separator = separator;
    result.index_proc = index;
    return result;
}

reverse_split :: (text: string, separator: string, $$index: Index_Proc, skip_empty := false, max_results := 0) -> Split_By_Proc #must {
    result : Split_By_Proc = ---;
    fill_split_struct(true);
    result.separator = separator;
    result.index_proc = index;
    return result;
}


line_split :: (text: string, skip_empty := false, max_results := 0, keep_eol := false) -> Split_By_Line #must {
    result : Split_By_Line = ---;
    fill_split_struct(false);
    result.keep_eol = keep_eol;
    return result;
}



for_expansion :: (splitter: *Split_By_String, body: Code, flags: For_Flags) #expand {
	#assert(flags == 0);

    `it : string = ---;
    `it_index : int = -1;

    if splitter.max_results != 0 && splitter.max_results < 2 {
        #if strict {
            assert(splitter.max_results >= 0, "split.max_results cannot be negative.");
        }

        it = splitter.text;
        it_index = 0;

        #insert body;
    }
    else {
        max_it_index := ifx splitter.max_results == 0 then 0 else splitter.max_results - 2;
        process_remainder := true;

        if splitter.reverse {
            end_index := splitter.text.count;
            index, found := last_index(splitter.text, splitter.separator, splitter.cmp);
            while found {
                it = unsafe_slice(splitter.text, index + splitter.separator.count, end_index);
                end_index = index;

                if splitter.skip_empty && it == ""  continue;

                it_index += 1;

                #insert body;

                if splitter.max_results != 0 && it_index >= max_it_index
                    break;

                index, found = last_index(splitter.text, splitter.separator, index, splitter.cmp);
            }

            if process_remainder  it = unsafe_slice(splitter.text, 0, end_index);
        }
        else {
            start_index := 0;
            index, found := first_index(splitter.text, splitter.separator, splitter.cmp);
            while found {
                it = unsafe_slice(splitter.text, start_index, index);
                start_index = index + splitter.separator.count;

                if splitter.skip_empty && it == ""  continue;

                it_index += 1;

                #insert body;

                if splitter.max_results != 0 && it_index >= max_it_index
                    break;

                index, found = first_index(splitter.text, splitter.separator, start_index, splitter.cmp);
            }

            if process_remainder  it = unsafe_slice(splitter.text, start_index);
        }

        if process_remainder && (!splitter.skip_empty || it != "") {
            it_index += 1;

            #insert body;
        }
    }
}


for_expansion :: (splitter: *Split_By_Proc, body: Code, flags: For_Flags) #expand {
	#assert(flags == 0);

    `it : string = ---;
    `it_index : int = -1;

    if splitter.max_results != 0 && splitter.max_results < 2 {
        #if strict {
            assert(splitter.max_results >= 0, "split.max_results cannot be negative.");
        }

        it = splitter.text;
        it_index = 0;

        #insert body;
    }
    else {
        max_it_index := ifx splitter.max_results == 0 then 0 else splitter.max_results - 2;
        process_remainder := true;

        if splitter.reverse {
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
	#assert(flags == 0);

    `it : string = ---;
    `it_index : int = -1;

    if splitter.max_results != 0 && splitter.max_results < 2 {
        #if strict {
            assert(splitter.max_results >= 0, "split.max_results cannot be negative.");
        }

        it = splitter.text;
        it_index = 0;

        #insert body;
    }
    else {
        max_it_index := ifx splitter.max_results == 0 then 0 else splitter.max_results - 2;
        process_remainder := true;

        if splitter.reverse {
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
	#assert(flags == 0);

    `it : string = ---;
    `it_index : int = -1;

    if splitter.max_results != 0 && splitter.max_results < 2 {
        #if strict {
            assert(splitter.max_results >= 0, "split.max_results cannot be negative.");
        }

        it = splitter.text;
        it_index = 0;

        #insert body;
    }
    else {
        max_it_index := ifx splitter.max_results == 0 then 0 else splitter.max_results - 2;
        process_remainder := true;

        if splitter.reverse {
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
    #assert(flags == 0);

    `it : string = ---;
    `it_index : int = -1;

    if splitter.max_results != 0 && splitter.max_results < 2 {
        #if strict {
            assert(splitter.max_results >= 0, "split.max_results cannot be negative.");
        }

        it = splitter.text;
        it_index = 0;

        #insert body;
    }
    else {
        max_it_index := ifx splitter.max_results == 0 then 0 else splitter.max_results - 2;
        process_remainder := true;

        if splitter.reverse {
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
    #assert(flags == 0);

    `it : string = ---;
    `it_index : int = -1;

    if splitter.max_results != 0 && splitter.max_results < 2 {
        #if strict {
            assert(splitter.max_results >= 0, "split.max_results cannot be negative.");
        }

        it = splitter.text;
        it_index = 0;

        #insert body;
    }
    else {
        max_it_index := ifx splitter.max_results == 0 then 0 else splitter.max_results - 2;
        process_remainder := true;

        if splitter.reverse {
            assert(false, "Cannot (currently) iterate over lines in reverse"); // @TODO
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


#scope_module


SPACE :: #char " ";
TAB   :: #char "\t";
CR    :: #char "\r";
LF    :: #char "\n";

NBSP  :: #char " "; // careful!

WHITESPACE :: u8.[SPACE, TAB, CR, LF, NBSP];

Character_Compare :: #type(a: u8, b: u8) -> bool #must;


/*

for_expansion_internal :: (splitter: *Split_By, body: Code, flags: For_Flags, reverse_block: Code, forward_block: Code) #expand {
	#assert(flags == 0);

    if splitter.max_results != 0 && splitter.max_results < 2 {
        #if strict {
            assert(splitter.max_results >= 0, "split.max_results cannot be negative.");
        }

        `it = splitter.text;
        `it_index = 0;

        #insert body;
    }
    else {
        `max_it_index := ifx splitter.max_results == 0 then 0 else splitter.max_results - 2;
        `process_remainder := true;

        if splitter.reverse {
            `end_index := splitter.text.count;

            #insert reverse_block;

            if process_remainder  `it = unsafe_slice(splitter.text, 0, end_index);
        }
        else {
            `start_index := 0;

            #insert forward_block;
            if process_remainder  `it = unsafe_slice(splitter.text, start_index);
        }

        if process_remainder && (!splitter.skip_empty || `it != "") {
            `it_index += 1;

            #insert body;
        }
    }
}


for_expansion :: (splitter: *Split_By_String, body: Code, flags: For_Flags) #expand {
    `it : string = ---;
    `it_index : int = -1;

    for_expansion_internal(splitter, body, flags,
        reverse_block = #code {
            index, found := last_index(splitter.text, splitter.separator, splitter.cmp);
            while found {
                `it = unsafe_slice(splitter.text, index + splitter.separator.count, end_index);
                end_index = index;

                if splitter.skip_empty && `it == ""  continue;

                `it_index += 1;

                #insert body;

                if splitter.max_results != 0 && `it_index >= max_it_index
                    break;

                index, found = last_index(splitter.text, splitter.separator, index, splitter.cmp);
            }
        },
        forward_block = #code {
            index, found := first_index(splitter.text, splitter.separator, splitter.cmp);
            while found {
                `it = unsafe_slice(splitter.text, start_index, index);
                start_index = index + splitter.separator.count;

                if splitter.skip_empty && `it == ""  continue;

                `it_index += 1;

                #insert body;

                if splitter.max_results != 0 && `it_index >= max_it_index
                    break;

                index, found = first_index(splitter.text, splitter.separator, start_index, splitter.cmp);
            }
        }
    );
}


for_expansion :: (splitter: *Split_By_Proc, body: Code, flags: For_Flags) #expand {
    `it : string = ---;
    `it_index : int = -1;

    for_expansion_internal(splitter, body, flags,
        reverse_block = #code {
            from_index, to_index, found := splitter.index_proc(splitter.text, splitter.separator, splitter.text.count, true);
            while found {
                `it = unsafe_slice(splitter.text, to_index, end_index);
                end_index = from_index;

                if splitter.skip_empty && `it == ""  continue;

                `it_index += 1;

                #insert body;

                if splitter.max_results != 0 && `it_index >= max_it_index
                    break;

                from_index, to_index, found = splitter.index_proc(splitter.text, splitter.separator, from_index, true);
            }
        },
        forward_block = #code {
            from_index, to_index, found := splitter.index_proc(splitter.text, splitter.separator, 0, false);
            while found {
                `it = unsafe_slice(splitter.text, start_index, from_index);
                start_index = to_index;

                if splitter.skip_empty && `it == ""  continue;

                `it_index += 1;

                #insert body;

                if splitter.max_results != 0 && `it_index >= max_it_index
                    break;

                from_index, to_index, found = splitter.index_proc(splitter.text, splitter.separator, to_index, false);
            }
        }
    );
}


for_expansion :: (splitter: *Split_By_Chars, body: Code, flags: For_Flags) #expand {
    `it : string = ---;
    `it_index : int = -1;

    for_expansion_internal(splitter, body, flags,
        reverse_block = #code {
            for < index: splitter.text.count - 1 .. 0 {
                if is_any(splitter.text[index], splitter.separator) {
                    `it = unsafe_slice(splitter.text, index + 1, end_index);
                    end_index = index;

                    if splitter.skip_empty && `it == ""  continue;

                    `it_index += 1;

                    #insert body;

                    if splitter.max_results != 0 && `it_index >= max_it_index
                        break;
                }
            }
        },
        forward_block = #code {
            for index: 0 .. splitter.text.count - 1 {
                if is_any(splitter.text[index], splitter.separator) {
                    `it = unsafe_slice(splitter.text, start_index, index);
                    start_index = index + 1;

                    if splitter.skip_empty && `it == ""  continue;

                    `it_index += 1;

                    #insert body;

                    if splitter.max_results != 0 && `it_index >= max_it_index
                        break;
                }
            }
        }
    );
}



for_expansion :: (splitter: *Split_By_Char, body: Code, flags: For_Flags) #expand {
    `it : string = ---;
    `it_index : int = -1;

    for_expansion_internal(splitter, body, flags,
        reverse_block = #code {
            for < index: splitter.text.count - 1 .. 0 {
                if splitter.text[index] == splitter.separator {
                    `it = unsafe_slice(splitter.text, index + 1, end_index);
                    end_index = index;

                    if splitter.skip_empty && `it == ""  continue;

                    `it_index += 1;

                    #insert body;

                    if splitter.max_results != 0 && `it_index >= max_it_index
                        break;;
                }
            }
        },
        forward_block = #code {
            for index: 0 .. splitter.text.count - 1 {
                if splitter.text[index] == splitter.separator {
                    `it = unsafe_slice(splitter.text, start_index, index);
                    start_index = index + 1;

                    if splitter.skip_empty && `it == ""  continue;

                    `it_index += 1;

                    #insert body;

                    if splitter.max_results != 0 && `it_index >= max_it_index
                        break;
                }
            }
        }
    );
}


for_expansion :: (splitter: *Split_By_Index, body: Code, flags: For_Flags) #expand {
    `it : string = ---;
    `it_index : int = -1;

    for_expansion_internal(splitter, body, flags,
        reverse_block = #code {
            upper_bound := splitter.text.count;
            for < index: splitter.indexes {
                `it, end_index = slice(splitter.text, index, end_index);
                if end_index < upper_bound
                    upper_bound = end_index;
                else
                    end_index = upper_bound;

                if splitter.skip_empty && `it == ""  continue;

                `it_index += 1;

                #insert body;

                if splitter.max_results != 0 && `it_index >= max_it_index
                    break;
            }
        },
        forward_block = #code {
            lower_bound := 0;
            for index: splitter.indexes {
                _ : int;
                `it, _, start_index = slice(splitter.text, start_index, index);
                if start_index > lower_bound
                    lower_bound = start_index;
                else
                    start_index = lower_bound;

                if splitter.skip_empty && `it == ""  continue;

                `it_index += 1;

                #insert body;

                if splitter.max_results != 0 && `it_index >= max_it_index
                    break;
            }
        }
    );
}


for_expansion :: (splitter: *Split_By_Line, body: Code, flags: For_Flags) #expand {
    `it : string = ---;
    `it_index : int = -1;

    for_expansion_internal(splitter, body, flags, #code {},
        forward_block = #code {
            for index: 0 .. splitter.text.count - 1 {
                if splitter.text[index] == LF {
                    if splitter.keep_eol {
                        `it = unsafe_slice(splitter.text, start_index, index + 1);
                    }
                    else {
                        `it = unsafe_slice(splitter.text, start_index, index);
                        if ends_with(`it, CR)  `it = unsafe_slice(`it, 0, `it.count - 1);
                    }
                    start_index = index + 1;

                    if splitter.skip_empty && `it == ""  continue;

                    `it_index += 1;

                    #insert body;

                    if splitter.max_results != 0 && `it_index >= max_it_index
                        break;
                }
            }
        }
    );
}

*/
