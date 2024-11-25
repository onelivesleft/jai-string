// @TODO
// [ ] get `apply_backslash` and `escape` to handle `\u` and `\U`


#import "Basic";
#import "Unicode";
using shared :: #import "Strings_Shared";


#scope_file

current_compare := default_compare;
current_first_index := default_first_index;
current_last_index := default_last_index;

#scope_export


set_default_compare :: (character_compare := default_compare) {
    current_compare = character_compare;
}


set_index_algorithm :: (first_index_proc := default_first_index, last_index_proc := default_last_index) {
    current_first_index = first_index_proc;
    current_last_index = last_index_proc;
}


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

    for make_split(haystack, needle, compare, current_first_index, current_last_index, ifx max_replacements <= 0 then 0 else max_replacements + 1) {
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



split :: (text: string, separator: string, compare: Character_Compare, reversed := false, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> [] string #must {
    result : [..] string;

    if reversed
        for < make_split(text, separator, compare, current_first_index, current_last_index, max_results, skip_empty, keep_separator)
            array_add(*result, it);
    else
        for make_split(text, separator, compare, current_first_index, current_last_index, max_results, skip_empty, keep_separator)
            array_add(*result, it);

    return result;
}


split :: inline (text: string, separator: string, reversed := false, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> [] string #must {
    return split(text, separator, current_compare, reversed, max_results, skip_empty, keep_separator);
}


split :: (text: string, separator: string, index: Index_Proc, reversed := false, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> [] string #must {
    result : [..] string;

    if reversed
        for < make_split(text, separator, index, max_results, skip_empty, keep_separator)
            array_add(*result, it);
    else
        for make_split(text, separator, index, max_results, skip_empty, keep_separator)
            array_add(*result, it);

    return result;
}


split :: (text: string, separator: [] u8, reversed := false, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> [] string #must {
    result : [..] string;

    if reversed
        for < make_split(text, separator, current_compare, max_results, skip_empty, keep_separator)
            array_add(*result, it);
    else
        for make_split(text, separator, current_compare, max_results, skip_empty, keep_separator)
            array_add(*result, it);

    return result;
}


split :: (text: string, separator: u8, reversed := false, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> [] string #must {
    result : [..] string;

    if reversed
        for < make_split(text, separator, current_compare, max_results, skip_empty, keep_separator)
            array_add(*result, it);
    else
        for make_split(text, separator, current_compare, max_results, skip_empty, keep_separator)
            array_add(*result, it);

    return result;
}


count_split :: (text: string, count: int, reversed := false, max_results := 0) -> [] string #must {
    result : [..] string;

    if reversed
        for < make_split(text, count, max_results)
            array_add(*result, it);
    else
        for make_split(text, count, max_results)
            array_add(*result, it);

    return result;
}



index_split :: (text: string, indexes: .. int, reversed := false, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> [] string #must {
    result : [..] string;

    if reversed
        for < make_split(text, indexes, max_results, skip_empty, keep_separator)
            array_add(*result, it);
    else
        for make_split(text, indexes, max_results, skip_empty, keep_separator)
            array_add(*result, it);

    return result;
}


line_split :: (text: string, reversed := false, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> [] string #must {
    result : [..] string;

    if reversed
        for < make_line_split(text, max_results, skip_empty, keep_separator)
            array_add(*result, it);
    else
        for make_line_split(text, max_results, skip_empty, keep_separator)
            array_add(*result, it);

    return result;
}


split :: (separator: $T/Split_By, reversed := false) -> [] string #must {
    result : [..] string;

    if reversed
        for < separator  array_add(*result, it);
    else
        for separator  array_add(*result, it);

    return result;
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

