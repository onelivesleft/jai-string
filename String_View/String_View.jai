// All functions return a string view and/or mutate a string view in-place

// TODO
// [ ] bake cmp?
// [ ] trim string characters?
// [ ] ask about autobaking problem
// [x] default_compare


#module_parameters (
    default_first_index_of := naive_first_index_of,  // default proc to find first index of substring in string
    default_last_index_of := naive_last_index_of,    // default proc to find last index of substring in string
    default_compare := case_sensitive,               // default character comparison check
    strict := false                                  // Asserts when indices fall outside the range of the string
);


#import "Basic";


current_first_index_of := default_first_index_of;
current_last_index_of := default_last_index_of;

set_index_of_algorithm :: (first_index_of_proc := default_first_index_of, last_index_of_proc := default_last_index_of) {
    current_first_index_of = first_index_of_proc;
    current_last_index_of = last_index_of_proc;
}


slice :: inline (str: string, from_index: int, to_index: int) -> string #must {
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

    if from_index >= to_index  return "";

    result : string = ---;
    result.data = str.data + from_index;
    result.count = to_index - from_index;
    return result;
}


slice :: inline (str: string, from_index: int) -> string #must {
    return slice(str, from_index, str.count);
}


unsafe_slice :: inline (str: string, from_index: int, to_index: int) -> string #must {
    // @Note Handles positive indexes only!
    #if strict {
        assert(from_index >= 0 && from_index <= str.count, "Cannot slice; from_index falls outwith range of string.");
        assert(to_index >= from_index, "Cannot slice; to_index is ahead of to_index.");
        assert(to_index <= str.count, "Cannot slice; to_index falls outwith range of string.");
    }

    result : string = ---;
    result.data = str.data + from_index;
    result.count = to_index - from_index;
    return result;
}


unsafe_slice :: inline (str: string, from_index: int) -> string #must {
    // @Note Handles positive index only!
    #if strict {
        assert(from_index >= 0 && from_index <= str.count, "Cannot slice; from_index falls outwith range of string.");
    }

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
    //print("% == %: %\n", a, b, a == b);
    return a == b;
}


ignore_case :: inline (a: u8, b: u8) -> bool #must {
    lower_a : int = ifx a >= #char "A" && a <= #char "Z" then a + #char "a" - #char "A" else a;
    lower_b : int = ifx b >= #char "A" && b <= #char "Z" then b + #char "a" - #char "A" else b;
    return lower_a == lower_b;
}



is_any :: inline (needle: u8, characters: [] u8, $$cmp := default_compare) -> bool #must {
    //#if is_constant(characters) && characters.count == 1 {
    //    return needle == characters[0];
    //}
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


ends_with :: (haystack: string, needle: string, $$cmp := default_compare) -> bool #must {
    if haystack.count < needle.count  return false;

    needle_index := 0;

    for haystack.count - needle.count .. haystack.count - 1 {
        if !cmp(haystack[it], needle[needle_index])
            return false;

        needle_index += 1;
    }

    return false;
}


ends_with :: inline (haystack: string, needle: u8) -> bool #must {
    return haystack.count > 0 && haystack[haystack.count - 1] == needle;
}


ends_with :: inline (haystack: string, needle: [] u8) -> bool #must {
    return haystack.count > 0 && is_any(haystack[haystack.count - 1], needle);
}


#scope_file


validate_from_index :: (str: string) #expand {
    #if strict {
        if `from_index < 0  `from_index = str.count + `from_index;
        assert(`from_index >= 0 && `from_index <= str.count, "from_index falls outwith range of string.");
    }
    else {
        if `from_index < 0  `from_index = clamp(str.count + `from_index, 0, str.count);
        else                `from_index = clamp(`from_index, 0, str.count);
    }
}


#scope_export


first_index_of :: (haystack: string, needle: u8, from_index := 0) -> index: int #must, found: bool {
    validate_from_index(haystack);

    for cast(u64)haystack.data + cast(u64)from_index .. cast(u64)haystack.data + cast(u64)haystack.count - 1
        if <<cast(*u8)it == needle
            return cast(int)(it - cast(u64)haystack.data), true;

    return -1, false;
}


first_index_of :: (haystack: string, needle: [] u8, from_index := 0) -> index: int #must, found: bool {
    validate_from_index(haystack);

    for cast(u64)haystack.data + cast(u64)from_index .. cast(u64)haystack.data + cast(u64)haystack.count - 1
        if is_any(<<cast(*u8)it, needle)
            return cast(int)(it - cast(u64)haystack.data), true;

    return -1, false;
}


first_index_of :: inline (haystack: string, needle: string, from_index := 0, cmp := default_compare) -> index: int #must, found: bool {
    validate_from_index(haystack);
    if needle.count == 0 {
        return from_index, true;
    }
    else if needle.count == 1 {
        for cast(u64)haystack.data + cast(u64)from_index .. cast(u64)haystack.data + cast(u64)haystack.count - 1
            if cmp(<<cast(*u8)it, <<needle.data)
                return cast(int)(it - cast(u64)haystack.data), true;
        return -1, false;
    }
    else {
        index, found := current_first_index_of(haystack, needle, from_index, cmp);
        return index, found;
    }
}


first_index_of :: inline (haystack: string, needle: string, compare: Character_Compare) -> index: int #must, found: bool {
    index, found := first_index_of(haystack, needle, 0, compare);
    return index, found;
}


// @Note `needle` is guaranteed to be at least 2 characters long

naive_first_index_of :: (haystack: string, needle: string, from_index: int, cmp: Character_Compare) -> index: int #must, found: bool {
    if from_index > haystack.count - needle.count  return -1, false;

    end := cast(u64)haystack.data + cast(u64)(haystack.count - needle.count);
    needle_end := cast(u64)needle.count - 1;
    for start_of_word: cast(u64)haystack.data + cast(u64)from_index .. end {
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


last_index_of :: (haystack: string, needle: u8) -> index: int #must, found: bool {
    for < cast(u64)haystack.data + cast(u64)haystack.count - 1 .. cast(u64)haystack.data
        if <<cast(*u8)it == needle
            return cast(int)(it - cast(u64)haystack.data), true;


    return -1, false;
}


last_index_of :: (haystack: string, needle: [] u8) -> index: int #must, found: bool {
    for < cast(u64)haystack.data + cast(u64)haystack.count - 1 .. cast(u64)haystack.data
        if is_any(<<cast(*u8)it, needle)
            return cast(int)(it - cast(u64)haystack.data), true;

    return -1, false;
}


last_index_of :: (haystack: string, needle: u8, from_index : int) -> index: int #must, found: bool {
    if from_index == 0  return -1, false;

    from_index -= 1;
    validate_from_index(haystack);

    for < cast(u64)haystack.data + cast(u64)from_index .. cast(u64)haystack.data
        if <<cast(*u8)it == needle
            return cast(int)(it - cast(u64)haystack.data), true;

    return -1, false;
}


last_index_of :: (haystack: string, needle: [] u8, from_index : int) -> index: int #must, found: bool {
    if from_index == 0  return -1, false;

    from_index -= 1;
    validate_from_index(haystack);

    for < cast(u64)haystack.data + cast(u64)from_index .. cast(u64)haystack.data
        if is_any(<<cast(*u8)it, needle)
            return cast(int)(it - cast(u64)haystack.data), true;

    return -1, false;
}


// @Note `needle` is guaranteed to be at least 2 characters long

naive_last_index_of :: (haystack: string, needle: string, from_index: int, cmp: Character_Compare) -> index: int #must, found: bool {
    if from_index < needle.count  return -1, false;

    start := cast(u64)haystack.data + cast(u64)(from_index - needle.count);
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


last_index_of :: inline (haystack: string, needle: string, from_index: int, cmp: Character_Compare) -> index: int #must, found: bool {
    validate_from_index(haystack);
    if needle.count == 0 {
        return from_index, true;
    }
    else if needle.count == 1 {
        for < cast(u64)haystack.data + cast(u64)from_index - 1.. cast(u64)haystack.data
            if cmp(<<cast(*u8)it, needle[0])
                return cast(int)(it - cast(u64)haystack.data), true;
        return -1, false;
    }
    else {
        index, found := current_last_index_of(haystack, needle, from_index, cmp);
        return index, found;
    }
}


last_index_of :: inline (haystack: string, needle: string, cmp: Character_Compare) -> index: int #must, found: bool {
    index, found := last_index_of(haystack, needle, haystack.count, cmp);
    return index, found;
}


last_index_of :: inline (haystack: string, needle: string, from_index: int) -> index: int #must, found: bool {
    index, found := last_index_of(haystack, needle, from_index, default_compare);
    return index, found;
}


last_index_of :: inline (haystack: string, needle: string) -> index: int #must, found: bool {
    index, found := last_index_of(haystack, needle, haystack.count, default_compare);
    return index, found;
}



contains :: (haystack: string, needle: u8) -> bool #must {
    _, found := first_index_of(haystack, needle);
    return found;
}


contains :: (haystack: string, needle: [] u8) -> bool #must {
    _, found := first_index_of(haystack, needle);
    return found;
}


contains :: (haystack: string, needle: string, $$cmp := default_compare) -> bool #must {
    _, found := first_index_of(haystack, needle, cmp);
    return found;
}



trim :: inline (str: string, chars: [] u8 = WHITESPACE) -> string #must {
    return trim(str, cast(string) chars);
}


trim :: (str: string, chars_to_trim: string, $$cmp := default_compare) -> string #must {
    #if strict {
        assert(chars_to_trim != "", "You cannot trim nothing!");
    }
    else {
        if chars_to_trim == ""  return str;
    }

    low_index := 0;
    high_index := str.count - 1;

    while low_index < str.count && is_any(str[low_index], cast([] u8) chars_to_trim, cmp = cmp)
        low_index += 1;

    if low_index >= str.count  return "";

    while high_index > low_index && is_any(str[high_index], cast([] u8) chars_to_trim, cmp = cmp)
        high_index -= 1;

    return unsafe_slice(str, low_index, high_index + 1);
}


trim_left :: inline (str: string, char: u8) -> string #must {
    return trim_left(str, string_from_char(*char));
}


trim_left :: inline (str: string, chars: [] u8 = WHITESPACE) -> string #must {
    return trim_left(str, cast(string) chars);
}


trim_left :: (str: string, chars_to_trim: string, $$cmp := default_compare) -> string #must {
    #if strict {
        assert(chars_to_trim != "", "You cannot trim nothing!");
    }
    else {
        if chars_to_trim == ""  return str;
    }

    index := 0;

    while index < str.count && is_any(str[index], cast([] u8) chars_to_trim, cmp = cmp)
        index += 1;

    if index >= str.count  return "";

    return unsafe_slice(str, index);
}


trim_right :: inline (str: string, char: u8) -> string #must {
    return trim_right(str, string_from_char(*char));
}


trim_right :: inline (str: string, chars: [] u8 = WHITESPACE) -> string #must {
    return trim_right(str, cast(string) chars);
}


trim_right :: (str: string, chars_to_trim: string, $$cmp := default_compare) -> string #must {
    #if strict {
        assert(chars_to_trim != "", "You cannot trim nothing!");
    }
    else {
        if chars_to_trim == ""  return str;
    }

    index := str.count - 1;

    while index >= 0 && is_any(str[index], cast([] u8) chars_to_trim, cmp = cmp)
        index -= 1;

    if index < 0  return "";

    return unsafe_slice(str, 0, index + 1);
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


reverse :: (str: string) {
    end := str.count - 1;
    for i: 0 .. str.count / 2 {
        c := str[i];
        str[i] = str[end - i];
        str[end - i] = c;
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


replace :: inline (haystack: string, needle: string, replacement: u8, $$compare: Character_Compare) -> change_count: int {
    return replace(haystack, needle, replacement, 0, compare);
}


replace :: (haystack: string, needle: string, replacement: u8, max_replacements := 0, $$cmp := default_compare) -> change_count: int {
    change_count := 0;
    over_limit := false;
    index, found := first_index_of(haystack, needle, cmp);
    while found && !over_limit {
        for index .. index + needle.count - 1 {
            haystack[it] = replacement;
            change_count += 1;
            if max_replacements > 0 && change_count >= max_replacements {
                over_limit = true;
                break;
            }
        }
        index, found = first_index_of(haystack, needle, index + needle.count, cmp);
    }

    return change_count;
}


Character_Translation :: struct {
    needle: u8;
    replacement: u8;
}


replace :: (haystack: string, translation: [] Character_Translation) -> change_count: int {
    change_count := 0;
    for 0 .. haystack.count - 1 {
        for entry: translation {
            if haystack[it] == entry.needle {
                haystack[it] = entry.replacement;
                change_count += 1;
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
    index, found := first_index_of(haystack, needle, cmp);
    while found {
        total += 1;
        index, found = first_index_of(haystack, needle, index + needle.count, cmp);
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



Split_By :: struct {
    text: string;
    reverse : bool;
    max_results : int;
    skip_empty : bool;
}

Split_By_String :: struct {
    using base: Split_By;
    separator: string;
    cmp : Character_Compare;
}


Split_By_Chars :: struct {
    using base: Split_By;
    separator: [] u8;
}


Split_By_Char :: struct {
    using base: Split_By;
    separator: u8;
}


Split_By_Line :: struct {
    using base: Split_By;
}


#scope_file


fill_split_struct :: (reversed: bool) #expand {
    `result.text = `text;
    `result.separator = `separator;
    `result.max_results = `max_results;
    `result.skip_empty = `skip_empty;
    `result.reverse = reversed;
}


#scope_export


forward_split :: inline (text: string, separator: string, $$compare: Character_Compare, skip_empty := false) -> Split_By_String #must {
    return forward_split(text, separator, 0, compare, skip_empty);
}


forward_split :: (text: string, separator: string, max_results := 0, $$cmp := default_compare, skip_empty := false) -> Split_By_String #must {
    result : Split_By_String = ---;
    fill_split_struct(false);
    result.cmp = cmp;
    return result;
}


reverse_split :: inline (text: string, separator: string, $$compare: Character_Compare, skip_empty := false) -> Split_By_String #must {
    return reverse_split(text, separator, 0, compare, skip_empty);
}


reverse_split :: (text: string, separator: string, max_results := 0, $$cmp := default_compare, skip_empty := false) -> Split_By_String #must {
    result : Split_By_String = ---;
    fill_split_struct(true);
    result.cmp = cmp;
    return result;
}


forward_split :: (text: string, separator: [] u8, max_results := 0, skip_empty := false) -> Split_By_Chars #must {
    result : Split_By_Chars = ---;
    fill_split_struct(false);
    return result;
}


reverse_split :: (text: string, separator: [] u8, max_results := 0, skip_empty := false) -> Split_By_Chars #must {
    result : Split_By_Chars = ---;
    fill_split_struct(true);
    return result;
}


forward_split :: (text: string, separator: u8, max_results := 0, skip_empty := false) -> Split_By_Char #must {
    result : Split_By_Char = ---;
    fill_split_struct(false);
    return result;
}


reverse_split :: (text: string, separator: u8, max_results := 0, skip_empty := false) -> Split_By_Char #must {
    result : Split_By_Char = ---;
    fill_split_struct(true);
    return result;
}


line_split :: (text: string, max_results := 0, skip_empty := false) -> Split_By_Line #must {
    result : Split_By_Line = ---;
    result.text = text;
    result.max_results = max_results;
    result.skip_empty = skip_empty;
    result.reverse = false;
    return result;
}



for_expansion :: (splitter: *Split_By_String, body: Code, flags: For_Flags) #expand {
    `it : string = ---;
    `it_index : int = -1;

    for_expansion_internal(splitter, body, flags,
        reverse_block = #code {
            index, found := last_index_of(splitter.text, splitter.separator, splitter.cmp);
            while found {
                `it = unsafe_slice(splitter.text, index + splitter.separator.count, end_index);
                end_index = index;

                if splitter.skip_empty && `it == ""  continue;

                `it_index += 1;

                #insert body;

                if splitter.max_results != 0 && `it_index >= max_it_index
                    break;

                index, found = last_index_of(splitter.text, splitter.separator, index, splitter.cmp);
            }
        },
        forward_block = #code {
            index, found := first_index_of(splitter.text, splitter.separator, splitter.cmp);
            while found {
                `it = unsafe_slice(splitter.text, start_index, index);
                start_index = index + splitter.separator.count;

                if splitter.skip_empty && `it == ""  continue;

                `it_index += 1;

                #insert body;

                if splitter.max_results != 0 && `it_index >= max_it_index
                    break;

                index, found = first_index_of(splitter.text, splitter.separator, start_index, splitter.cmp);
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


for_expansion :: (splitter: *Split_By_Line, body: Code, flags: For_Flags) #expand {
    `it : string = ---;
    `it_index : int = -1;

    for_expansion_internal(splitter, body, flags, #code {},
        forward_block = #code {
            for index: 0 .. splitter.text.count - 1 {
                if splitter.text[index] == LF {
                    `it = unsafe_slice(splitter.text, start_index, index);
                    if ends_with(`it, CR)  `it = unsafe_slice(`it, 0, `it.count - 1);
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


#scope_module


SPACE :: #char " ";
TAB   :: #char "\t";
CR    :: #char "\r";
LF    :: #char "\n";
NBSP  :: #char " "; // careful!

WHITESPACE :: u8.[SPACE, TAB, CR, LF, NBSP];

Character_Compare :: #type(a: u8, b: u8) -> bool #must;


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

        if splitter.reverse {
            `end_index := splitter.text.count;

            #insert reverse_block;

            `it = unsafe_slice(splitter.text, 0, end_index);
        }
        else {
            `start_index := 0;

            #insert forward_block;

            `it = unsafe_slice(splitter.text, start_index);
        }

        if !splitter.skip_empty || `it != "" {
            `it_index += 1;

            #insert body;
        }
    }
}
