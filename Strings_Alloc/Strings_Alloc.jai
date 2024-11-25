// All functions return allocated data, and take an `allocator` optional parameters,
// (defaulting to using the allocator specified in the module parameters).


// @TODO
// [ ] get `apply_backslash` and `escape` to handle `\u` and `\U`


#import "Basic";
#import "Unicode";
using shared :: #import "Strings_Shared";



#scope_file

make_thread_proc_array :: (proc_name: string) -> string {
    builder : String_Builder;
    init_string_builder(*builder);
    append(*builder, ".[");
    append(*builder, proc_name);
    for 2 .. strings_shared_max_thread_count {
        append(*builder, ",");
        append(*builder, proc_name);
    }
    append(*builder, "];");
    return builder_to_string(*builder);
}

current_compare : [strings_shared_max_thread_count] type_of(default_compare)
    = #insert #run make_thread_proc_array("default_compare");

current_first_index : [strings_shared_max_thread_count] type_of(default_first_index)
    = #insert #run make_thread_proc_array("default_first_index");

current_last_index : [strings_shared_max_thread_count] type_of(default_last_index)
    = #insert #run make_thread_proc_array("default_last_index");

string_builder_allocator :: temp;

#scope_export



set_default_compare :: (character_compare := default_compare) {
    current_compare[context.thread_index] = character_compare;
}


set_index_algorithm :: (first_index_proc := default_first_index, last_index_proc := default_last_index) {
    current_first_index[context.thread_index] = first_index_proc;
    current_last_index[context.thread_index] = last_index_proc;
}


copy_string :: (str: string, allocator := Allocator.{}, $$null_terminate := false) -> string #must {
    if !str  return empty();

    result : string = ---;
    a := get_allocator(allocator);

    if null_terminate && str[str.count - 1] != #char "\0" {
        result = alloc_string(str.count + 1,, a);
        memcpy(result.data, str.data, str.count);
        result[result.count - 1] = #char "\0";
    }
    else {
        result = alloc_string(str.count,, a);
        memcpy(result.data, str.data, str.count);
    }

    return result;
}


reverse :: (str: string, allocator := Allocator.{}, $$null_terminate := false) -> string #must {
    if !str  return empty();

    result := copy_string(str, allocator, null_terminate);
    if null_terminate  result.count -= 1;
    _reverse(result);
    if null_terminate  result.count += 1;

    return result;
}



replace :: inline (haystack: string, needle: string, replacement: string, max_replacements := 0, allocator := Allocator.{}, $$null_terminate := false) -> string #must {
    return replace(haystack, needle, replacement, max_replacements, current_compare[context.thread_index], allocator, null_terminate);
}

replace :: (haystack: string, needle: string, replacement: string, max_replacements := 0, compare : Character_Compare, allocator := Allocator.{}, $$null_terminate := false) -> string #must {
    #if strict {
        assert(needle != "", "You cannot replace an empty string");
        assert(max_replacements >= 0, "max_replacements cannot be negative");
    }
    else {
        if needle == "" {
            result : Allocator = ---;
            set_result_allocator();
            return copy_string(haystack, result, null_terminate);
        }
    }

    if haystack == ""  return empty();

    result : String_Builder;
    set_result_allocator();

    first_loop := true;
    last_string := "";
    for make_split(haystack, needle, compare, current_first_index[context.thread_index], current_last_index[context.thread_index], ifx max_replacements <= 0 then 0 else max_replacements + 1) {
        if first_loop  first_loop = false;
        else           append(*result, replacement);
        append(*result, it);
    }

    if null_terminate {
        buffer := get_current_buffer(*result);
        if buffer.count == 0 || <<(get_buffer_data(buffer) + buffer.count - 1) != #char "\0"
            append(*result, #char "\0");
    }

    a := get_allocator(allocator);
    output := builder_to_string(*result,, a);
    if a != temp
        set_temporary_storage_mark(result_temporary_storage_mark);
    return output;
}


replace :: (haystack: string, needle: string, index: Index_Proc, replacement: string, max_replacements := 0, allocator := Allocator.{}, $$null_terminate := false) -> string #must {
    if haystack == ""  return empty();

    result : String_Builder;
    set_result_allocator();

    first_loop := true;
    last_string := "";
    for make_split(haystack, needle, index, ifx max_replacements <= 0 then 0 else max_replacements + 1) {
        if first_loop  first_loop = false;
        else           append(*result, replacement);
        append(*result, it);
    }

    if null_terminate {
        buffer := get_current_buffer(*result);
        if buffer.count == 0 || <<(get_buffer_data(buffer) + buffer.count - 1) != #char "\0"
            append(*result, #char "\0");
    }

    a := get_allocator(allocator);
    output := builder_to_string(*result,, a);
    if a != temp
        set_temporary_storage_mark(result_temporary_storage_mark);
    return output;
}



join :: (strings: .. string, allocator := Allocator.{}, $$null_terminate := false) -> string #must {
    if strings.count == 0  return empty();

    if strings.count == 1 {
        result : Allocator = ---;
        set_result_allocator();
        return copy_string(strings[0], result, null_terminate);
    }

    terminating := null_terminate && !ends_with(strings[strings.count - 1], #char "\0", case_sensitive);
    extra_byte := ifx terminating then 1 else 0;

    count := 0;
    for strings  count += it.count;

    result : Allocator = ---;
    set_result_allocator();

    joined := alloc_string(count + extra_byte,, result);
    memcpy(joined.data, strings[0].data, strings[0].count);
    position := joined.data + strings[0].count;
    for 1 .. strings.count - 1 {
        memcpy(position, strings[it].data, strings[it].count);
        position += strings[it].count;
    }

    if terminating  joined[count] = #char "\0";

    return joined;
}


join :: (strings: [] string, separator: string, allocator := Allocator.{}, $$null_terminate := false) -> string #must {
    if strings.count == 0  return empty();

    if strings.count == 1 {
        result : Allocator = ---;
        set_result_allocator();
        return copy_string(strings[0], result, null_terminate);
    }

    terminating := null_terminate && !ends_with(strings[strings.count - 1], #char "\0", case_sensitive);
    extra_byte := ifx terminating then 1 else 0;

    count := separator.count * (strings.count - 1);
    for strings  count += it.count;

    result : Allocator = ---;
    set_result_allocator();

    joined := alloc_string(count + extra_byte,, result);
    memcpy(joined.data, strings[0].data, strings[0].count);
    position := joined.data + strings[0].count;
    for 1 .. strings.count - 1 {
        if separator {
            memcpy(position, separator.data, separator.count);
            position += separator.count;
        }
        memcpy(position, strings[it].data, strings[it].count);
        position += strings[it].count;
    }

    if terminating  joined[count] = #char "\0";

    return joined;
}


join :: inline (strings: [] string, allocator := Allocator.{}, $$null_terminate := false) -> string #must {
    return join(strings, "", allocator, null_terminate);
}


join :: (strings: [] string, separator: u8, allocator := Allocator.{}, $$null_terminate := false) -> string #must {
    return join(strings, char_as_string(*separator), allocator);
}



split :: (text: string, separator: string, compare: Character_Compare, reversed := false, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO, allocator := Allocator.{}) -> [] string #must {
    result : [..] string;
    set_result_allocator();

    if reversed
        for < make_split(text, separator, compare, current_first_index[context.thread_index], current_last_index[context.thread_index], max_results, skip_empty, keep_separator)
            array_add(*result, it);
    else
        for make_split(text, separator, compare, current_first_index[context.thread_index], current_last_index[context.thread_index], max_results, skip_empty, keep_separator)
            array_add(*result, it);

    return result;
}


split :: inline (text: string, separator: string, reversed := false, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO, allocator := Allocator.{}) -> [] string #must {
    return split(text, separator, current_compare[context.thread_index], reversed, max_results, skip_empty, keep_separator, allocator);
}


split :: (text: string, separator: string, index: Index_Proc, reversed := false, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO, allocator := Allocator.{}) -> [] string #must {
    result : [..] string;
    set_result_allocator();

    if reversed
        for < make_split(text, separator, index, max_results, skip_empty, keep_separator)
            array_add(*result, it);
    else
        for make_split(text, separator, index, max_results, skip_empty, keep_separator)
            array_add(*result, it);

    return result;
}


split :: (text: string, separator: [] u8, reversed := false, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO, allocator := Allocator.{}) -> [] string #must {
    result : [..] string;
    set_result_allocator();

    if reversed
        for < make_split(text, separator, current_compare[context.thread_index], max_results, skip_empty, keep_separator)
            array_add(*result, it);
    else
        for make_split(text, separator, current_compare[context.thread_index], max_results, skip_empty, keep_separator)
            array_add(*result, it);

    return result;
}


split :: (text: string, separator: u8, reversed := false, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO, allocator := Allocator.{}) -> [] string #must {
    result : [..] string;
    set_result_allocator();

    if reversed
        for < make_split(text, separator, current_compare[context.thread_index], max_results, skip_empty, keep_separator)
            array_add(*result, it);
    else
        for make_split(text, separator, current_compare[context.thread_index], max_results, skip_empty, keep_separator)
            array_add(*result, it);

    return result;
}


count_split :: (text: string, count: int, reversed := false, max_results := 0, allocator := Allocator.{}) -> [] string #must {
    result : [..] string;
    set_result_allocator();

    if reversed
        for < make_split(text, count, max_results)
            array_add(*result, it);
    else
        for make_split(text, count, max_results)
            array_add(*result, it);

    return result;
}



index_split :: (text: string, indexes: .. int, reversed := false, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO, allocator := Allocator.{}) -> [] string #must {
    #if strict {
        prev_index := 0;
        for index: indexes {
            _, valid := slice_index(text, prev_index, index);
            assert(valid, "Invalid indexes passed to split: %, %", prev_index, index);
            prev_index = index;
        }
    }

    result : [..] string;
    set_result_allocator();

    if reversed
        for < make_split(text, indexes, max_results, skip_empty, keep_separator)
            array_add(*result, it);
    else
        for make_split(text, indexes, max_results, skip_empty, keep_separator)
            array_add(*result, it);

    return result;
}


line_split :: (text: string, reversed := false, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO, allocator := Allocator.{}) -> [] string #must {
    result : [..] string;
    set_result_allocator();

    if reversed
        for < make_line_split(text, max_results, skip_empty, keep_separator)
            array_add(*result, it);
    else
        for make_line_split(text, max_results, skip_empty, keep_separator)
            array_add(*result, it);

    return result;
}


split :: (separator: $T/Split_By, reversed := false, allocator := Allocator.{}) -> [] string #must {
    result : [..] string;
    set_result_allocator();

    if reversed
        for < separator  array_add(*result, it);
    else
        for separator  array_add(*result, it);

    return result;
}


#scope_file
default_pad_with :: "                                                                ";
#scope_export


pad_start :: (str: string, desired_count: int, pad_with := default_pad_with, allocator := Allocator.{}, $$null_terminate := false) -> string #must {
    #if strict {
        assert(str.count <= desired_count, "Cannot pad string as it is longer than desired count");
    }

    assert(pad_with.count > 0, "pad_with cannot be empty");

    if str.count >= desired_count {
        result : Allocator = ---;
        set_result_allocator();
        return copy_string(str, result, null_terminate);
    }

    terminating := null_terminate && !ends_with(str, #char "\0", case_sensitive);
    extra_byte := ifx terminating then 1 else 0;

    count := desired_count;

    result : Allocator = ---;
    set_result_allocator();

    padded := alloc_string(count + extra_byte,, result);
    padded_index := 0;
    padding_chars_required := desired_count - str.count;
    while padded_index <= padding_chars_required - pad_with.count {
        memcpy(padded.data + padded_index, pad_with.data, pad_with.count);
        padded_index += pad_with.count;
    }
    if padded_index < padding_chars_required
        memcpy(padded.data + padded_index, pad_with.data, padding_chars_required - padded_index);

    memcpy(padded.data + padding_chars_required, str.data, str.count);

    if terminating  padded[count] = #char "\0";

    return padded;
}


pad_start :: inline (str: string, desired_count: int, pad_with: u8, allocator := Allocator.{}, $$null_terminate := false) -> string #must {
    return pad_start(str, desired_count, char_as_string(*pad_with), allocator, null_terminate);
}


pad_end :: (str: string, desired_count: int, pad_with := default_pad_with, allocator := Allocator.{}, $$null_terminate := false) -> string #must {
    #if strict {
        assert(str.count <= desired_count, "Cannot pad string as it is longer than desired count");
    }

    assert(pad_with.count > 0, "pad_with cannot be empty");

    if str.count >= desired_count {
        result : Allocator = ---;
        set_result_allocator();
        return copy_string(str, result, null_terminate);
    }

    terminating := null_terminate && !ends_with(str, #char "\0", case_sensitive);
    extra_byte := ifx terminating then 1 else 0;

    count := desired_count;

    result : Allocator = ---;
    set_result_allocator();

    padded := alloc_string(count + extra_byte,, result);
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

    if terminating  padded[count] = #char "\0";

    return padded;
}


pad_end :: inline (str: string, desired_count: int, pad_with: u8, allocator := Allocator.{}, $$null_terminate := false) -> string #must {
    return pad_end(str, desired_count, char_as_string(*pad_with), allocator, null_terminate);
}


pad_center :: (str: string, desired_count: int, pad_with := default_pad_with, allocator := Allocator.{}, $$null_terminate := false) -> string #must {
    #if strict {
        assert(str.count <= desired_count, "Cannot pad string as it is longer than desired count");
    }

    assert(pad_with.count > 0, "pad_with cannot be empty");

    if str.count >= desired_count {
        result : Allocator = ---;
        set_result_allocator();
        return copy_string(str, result, null_terminate);
    }

    terminating := null_terminate && !ends_with(str, #char "\0", case_sensitive);
    extra_byte := ifx terminating then 1 else 0;

    count := desired_count;

    result : Allocator = ---;
    set_result_allocator();

    padded := alloc_string(count + extra_byte,, result);
    center_index := (desired_count - str.count) / 2;

    // left
    padded_index := 0;
    padding_chars_required := center_index;
    while padded_index <= padding_chars_required - pad_with.count {
        memcpy(padded.data + padded_index, pad_with.data, pad_with.count);
        padded_index += pad_with.count;
    }
    if padded_index < padding_chars_required
        memcpy(padded.data + padded_index, pad_with.data, padding_chars_required - padded_index);

    // right
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

    if terminating  padded[count] = #char "\0";

    return padded;
}


pad_center :: inline (str: string, desired_count: int, pad_with: u8, allocator := Allocator.{}, $$null_terminate := false) -> string #must {
    return pad_center(str, desired_count, char_as_string(*pad_with), allocator, null_terminate);
}



repeat :: (str: string, times: int, allocator := Allocator.{}, $$null_terminate := false) -> string #must {
    #if strict {
        assert(str != "", "str cannot be empty");
        assert(times > 0, "count must be a positive number");
    }
    else {
        if str == "" || times <= 0  return empty();
    }

    if times == 1 {
        result : Allocator = ---;
        set_result_allocator();
        return copy_string(str, result, null_terminate);
    }

    terminating := null_terminate && !ends_with(str, #char "\0", case_sensitive);
    extra_byte := ifx terminating then 1 else 0;

    count := str.count * times;

    result : Allocator = ---;
    set_result_allocator();

    repeated := alloc_string(count + extra_byte,, result);
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


lower :: (str: string, allocator := Allocator.{}, $$null_terminate := false) -> string #must {
    a := get_allocator(allocator);
    result := copy_string(str, a, null_terminate);
    to_lower(result);
    return result;
}


upper :: (str: string, allocator := Allocator.{}, $$null_terminate := false) -> string #must {
    a := get_allocator(allocator);
    result := copy_string(str, a, null_terminate);
    to_upper(result);
    return result;
}


capitalized :: (str: string, preserve_caps: = true, allocator := Allocator.{}, $$null_terminate := false) -> string #must {
    if !str  return empty();

    a := get_allocator(allocator);
    result := copy_string(str, a, null_terminate);
    to_capitalized(result, preserve_caps);

    return result;
}


snake_from_camel :: (str: string, preserve_caps := false, allocator := Allocator.{}, $$null_terminate := false) -> string #must {
    if str == ""  return empty();

    result : String_Builder;
    set_result_allocator();

    inside_caps := false;

    for i: 0 .. str.count - 1 {
        c := str[i];
        if is_upper(c) {
            if !inside_caps || i < str.count - 1 && is_lower(str[i + 1]) {
                inside_caps = true;
                if i > 0  append(*result, "_");
                if preserve_caps
                    append(*result, c);
                else
                    append(*result, to_lower(c));
            }
            else
                append(*result, to_lower(c));
        }
        else {
            inside_caps = false;
            append(*result, c);
        }
    }

    if null_terminate {
        buffer := get_current_buffer(*result);
        if buffer.count == 0 || <<(get_buffer_data(buffer) + buffer.count - 1) != #char "\0"
            append(*result, #char "\0");
    }

    a := get_allocator(allocator);
    output := builder_to_string(*result,, a);
    if a != temp
        set_temporary_storage_mark(result_temporary_storage_mark);
    return output;
}


camel_from_snake :: (str: string, preserve_caps := false, allocator := Allocator.{}, $$null_terminate := false) -> string #must {
    if str == ""  return empty();

    result : String_Builder;
    set_result_allocator();

    for word: make_split(str, #char "_", current_compare[context.thread_index]) {
        if word {
            append(*result, word);
            buffer := get_current_buffer(*result);
            in_place : string = ---;
            in_place.data = get_buffer_data(buffer) + buffer.count - word.count;
            in_place.count = word.count;
            to_capitalized(in_place, preserve_caps);
        }
    }

    if null_terminate {
        buffer := get_current_buffer(*result);
        if buffer.count == 0 || <<(get_buffer_data(buffer) + buffer.count - 1) != #char "\0"
            append(*result, #char "\0");
    }

    a := get_allocator(allocator);
    output := builder_to_string(*result,, a);
    if a != temp
        set_temporary_storage_mark(result_temporary_storage_mark);
    return output;
}


apply_backslash :: (str: string, allocator := Allocator.{}, $$null_terminate := false) -> string #must, well_formed: bool {
    if str == ""  return empty(), true;

    result : String_Builder;
    set_result_allocator();

    i := 0;
    well_formed := true;

    while i < str.count {
        if str[i] == #char "\\" {
            i += 1;
            if i >= str.count { well_formed = false; break; }
            if str[i] == {
                case #char "\\";
                append(*result, #char "\\");

                case #char "e";
                append(*result, #char "\e");

                case #char "n";
                append(*result, #char "\n");

                case #char "r";
                append(*result, #char "\r");

                case #char "t";
                append(*result, #char "\t");

                case #char "\"";
                append(*result, #char "\"");

                case #char "0";
                append(*result, #char "\0");

                case #char "x";
                i += 2;
                if i >= str.count { well_formed = false; break; }
                value : u8 = hex_char_value(str[i - 1]) * 16 + hex_char_value(str[i]);
                append(*result, value);

                case #char "d";
                i += 3;
                if i >= str.count { well_formed = false; break; }
                value : u8 = hex_char_value(str[i - 2]) * 100 + hex_char_value(str[i - 1]) * 10 + hex_char_value(str[i]);
                append(*result, value);

                /* @TODO
                case #char "u";
                    i += 4;
                    if i >= str.count { well_formed = false; break; }
                    value : u16 = hex_char_value(str[i - 3]) * 16 * 16 * 16;
                    value += hex_char_value(str[i - 2]) * 16 * 16;
                    value += hex_char_value(str[i - 1]) * 16;
                    value += hex_char_value(str[i]);
                    append(*result, character_utf32_to_utf8(xx value));

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
                    append(*result, character_utf32_to_utf8(value));
                */

                case;
                i -= 1;
                well_formed = false;
            }
        }
        else {
            append(*result, str[i]);
        }
        i += 1;
    }

    if null_terminate {
        buffer := get_current_buffer(*result);
        if buffer.count == 0 || <<(get_buffer_data(buffer) + buffer.count - 1) != #char "\0"
            append(*result, #char "\0");
    }

    a := get_allocator(allocator);
    output := builder_to_string(*result,, a);
    if a != temp
        set_temporary_storage_mark(result_temporary_storage_mark);
    return output, well_formed;
}


escape :: (str: string, allocator := Allocator.{}, $$null_terminate := false) -> string #must {
    if str == ""  return empty();

    result : String_Builder;
    set_result_allocator();

    for i: 0 .. str.count - 1 {
        if str[i] == {
            case #char "\\";
            append(*result, "\\\\");

            case #char "\e";
            append(*result, "\\e");

            case #char "\n";
            append(*result, "\\n");

            case #char "\r";
            append(*result, "\\r");

            case #char "\t";
            append(*result, "\\t");

            case #char "\"";
            append(*result, "\\\"");

            case #char "\0";
            append(*result, "\\0");

            /* @TODO
            case #char "u";
            i += 4;
            if i >= str.count { well_formed = false; break; }
            value : u16 = hex_char_value(str[i - 3]) * 16 * 16 * 16;
            value += hex_char_value(str[i - 2]) * 16 * 16;
            value += hex_char_value(str[i - 1]) * 16;
            value += hex_char_value(str[i]);
            append(*result, character_utf32_to_utf8(xx value));

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
            append(*result, character_utf32_to_utf8(value));
            */
            case;
            if str[i] < 32
                print_to_builder(*result, "\\x%", formatInt(str[i], 16, 2));
            else
                append(*result, str[i]);
        }
    }

    if null_terminate {
        buffer := get_current_buffer(*result);
        if buffer.count == 0 || <<(get_buffer_data(buffer) + buffer.count - 1) != #char "\0"
            append(*result, #char "\0");
    }

    a := get_allocator(allocator);
    output := builder_to_string(*result,, a);
    if a != temp
        set_temporary_storage_mark(result_temporary_storage_mark);
    return output;
}



#scope_file



set_result_allocator :: () #expand {
    #if type_of(`result) == String_Builder {
        `result.allocator = temp;
        `result_temporary_storage_mark := get_temporary_storage_mark();
        // @Note we can't `defer set_temporary_storage_mark(result_temporary_storage_mark)`
        // here because we might be using the temp allocator to store the result, so we
        // need to check before we reset the mark (or we'd be clearing our work!).
    }
    else #if type_of(`result) == [..] string {
        `result.allocator = `allocator;
    }
    else {
        if `allocator.proc
            `result = `allocator;
        else if `default_allocator.proc
            `result = `default_allocator;
        else if context.allocator.proc
            `result = context.allocator;
        else
            assert(false, "Could not find an allocator!");
    }
}


get_allocator :: (parameter_allocator := Allocator.{}, $type: Type = void) -> Allocator {
    #if type == String_Builder
        return temp, null;

    if parameter_allocator.proc
        return parameter_allocator;
    else if default_allocator.proc
        return default_allocator;
    else if context.allocator.proc
        return context.allocator;

    assert(false, "Could not find an allocator!");
    return Allocator.{}; // never happens, to silence warning
}


empty :: () -> string #expand {
    if `null_terminate {
        allocator := `allocator;
        a := get_allocator(allocator);
        empty := alloc_string(1,, a);
        empty[0] = #char "\0";
        return empty;
    }
    else
        return "";
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


operator== :: (a: Allocator, b: Allocator) -> bool {
    return a.proc == b.proc;
}
