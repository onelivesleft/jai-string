// All functions return allocated data, and take `allocator` + `allocator_data` optional parameters,
// (defaulting to using the allocator specified in the module parameters).


// TODO
// [ ] create a Scratch allocator
// [ ] rename concatenate to join
// [x] allow user to set allocator used by string builder
// [x] return "\0" for empty string when null_terminate is true
// [x] snake_from_camel / camel_from_snake
// [x] capitalize (maybe not ^)
// [x] repeat
// [x] justify / pad
// [x] maybe split_lines?
// [x] fast string compare
// [x] null_terminate parameter?
// [x] maybe conflate separators in split?


#import "Basic";
using shared :: #import "Strings_Shared";


#scope_file

current_compare := default_compare;
current_first_index := default_first_index;
current_last_index := default_last_index;
#if string_builder_allocator == .TEMP {
    current_string_builder_allocator := __temporary_allocator;
    current_string_builder_allocator_data : *void = null;
}
else {
    current_string_builder_allocator := default_allocator;
    current_string_builder_allocator_data := default_allocator_data;
}

#scope_export


set_default_compare :: (character_compare := default_compare) {
    current_compare = character_compare;
}


set_index_algorithm :: (first_index_proc := default_first_index, last_index_proc := default_last_index) {
    current_first_index = first_index_proc;
    current_last_index = last_index_proc;
}


set_string_builder_allocator :: (allocator: Allocator, allocator_data : *void = null) {
    current_string_builder_allocator = allocator;
    current_string_builder_allocator_data = allocator_data;
}


copy :: (str: string, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
    if !str  return empty();

    result : string = ---;
    a, ad := get_allocator(allocator, allocator_data);

    if null_terminate && str[str.count - 1] != #char "\0" {
        result = alloc_string(str.count + 1, allocator = a, allocator_data = ad);
        memcpy(result.data, str.data, str.count);
        result[result.count - 1] = #char "\0";
    }
    else {
        result = alloc_string(str.count, allocator = allocator, allocator_data = allocator_data);
        memcpy(result.data, str.data, str.count);
    }

    return result;
}


reverse :: (str: string, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
    if !str  return empty();

    a, ad := get_allocator(allocator, allocator_data);
    result : string = ---;
    terminating := null_terminate && str[0] != #char "\0";
    if terminating
        result = alloc_string(str.count + 1, allocator = a, allocator_data = ad);
    else
        result = alloc_string(str.count, allocator = a, allocator_data = ad);

    end := str.count - 1;
    for i: 0 .. end
        result[i] = str[end - i];

    if terminating  result[str.count] = #char "\0";

    return result;
}


capitalized :: (str: string, preserve_caps: = true, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
    if !str  return empty();

    result := copy(str, allocator, allocator_data, null_terminate);
    to_capitalized(result, preserve_caps);

    return result;
}


replace :: inline (haystack: string, needle: string, replacement: string, max_replacements := 0, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
    return replace(haystack, needle, replacement, max_replacements, current_compare, allocator, allocator_data);
}

replace :: (haystack: string, needle: string, replacement: string, max_replacements := 0, compare : Character_Compare, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
    #if strict {
        assert(needle != "", "You cannot replace an empty string");
        assert(max_replacements >= 0, "max_replacements cannot be negative");
    }
    else {
        if needle == "" {
            result : Allocator_Wrapper;
            set_result_allocator();
            return copy(haystack, result.allocator, result.allocator_data, null_terminate);
        }
    }

    if haystack == ""  return empty();

    print("Temporary Storage\nPre:  %\n", <<context.temporary_storage);

    result : String_Builder;
    set_result_allocator();

    first_loop := true;
    last_string := "";
    for make_split(haystack, needle, compare, current_first_index, current_last_index, ifx max_replacements <= 0 then 0 else max_replacements + 1) {
        if first_loop  first_loop = false;
        else           append(*result, replacement);
        append(*result, it);
    }

    if null_terminate {
        buffer := get_current_buffer(*result);
        if buffer.occupied == 0 || <<(buffer.data.data + buffer.occupied - 1) != #char "\0"
            append(*result, #char "\0");
    }

    a, ad := get_allocator(allocator, allocator_data);
    print("Post: %\n", <<context.temporary_storage);
    return builder_to_string(*result, allocator = a, allocator_data = ad);
}


replace :: (haystack: string, needle: string, index: Index_Proc, replacement: string, max_replacements := 0, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
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
        if buffer.occupied == 0 || <<(buffer.data.data + buffer.occupied - 1) != #char "\0"
            append(*result, #char "\0");
    }

    a, ad := get_allocator(allocator, allocator_data);
    return builder_to_string(*result, allocator = a, allocator_data = ad);
}



// @TODO rename to join
concatenate :: (strings: .. string, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
    if strings.count == 0  return empty();

    if strings.count == 1 {
        result : Allocator_Wrapper;
        set_result_allocator();
        return copy(strings[0], result.allocator, result.allocator_data, null_terminate);
    }

    terminating := null_terminate && !ends_with(strings[strings.count - 1], #char "\0", case_sensitive);

    count := 0;
    for strings  count += it.count;
    if terminating  count += 1;

    result : Allocator_Wrapper;
    set_result_allocator();

    joined := alloc_string(count, result.allocator, result.allocator_data);
    memcpy(joined.data, strings[0].data, strings[0].count);
    position := joined.data + strings[0].count;
    for 1 .. strings.count - 1 {
        memcpy(position, strings[it].data, strings[it].count);
        position += strings[it].count;
    }

    if terminating  joined[count] = #char "\0";

    return joined;
}


join :: (strings: [] string, separator: string, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
    if strings.count == 0  return empty();

    if strings.count == 1 {
        result : Allocator_Wrapper;
        set_result_allocator();
        return copy(strings[0], result.allocator, result.allocator_data, null_terminate);
    }

    terminating := null_terminate && !ends_with(strings[strings.count - 1], #char "\0", case_sensitive);

    count := separator.count * (strings.count - 1);
    for strings  count += it.count;
    if terminating  count += 1;

    result : Allocator_Wrapper;
    set_result_allocator();

    joined := alloc_string(count, result.allocator, result.allocator_data);
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


join :: inline (strings: [] string, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
    return join(strings, "", allocator, allocator_data, null_terminate);
}


join :: (strings: [] string, separator: u8, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
    return join(strings, string_from_char(*separator), allocator, allocator_data);
}



split :: (text: string, separator: string, compare: Character_Compare, reversed := false, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO, allocator: Allocator = null, allocator_data: *void = null) -> [] string #must {
    result : [..] string;
    set_result_allocator();

    if reversed
        for < make_split(text, separator, compare, current_first_index, current_last_index, max_results, skip_empty, keep_separator)
            array_add(*result, it);
    else
        for make_split(text, separator, compare, current_first_index, current_last_index, max_results, skip_empty, keep_separator)
            array_add(*result, it);

    return result;
}


split :: inline (text: string, separator: string, reversed := false, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO, allocator: Allocator = null, allocator_data: *void = null) -> [] string #must {
    return split(text, separator, current_compare, reversed, max_results, skip_empty, keep_separator, allocator, allocator_data);
}


split :: (text: string, separator: string, index: Index_Proc, reversed := false, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO, allocator: Allocator = null, allocator_data: *void = null) -> [] string #must {
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


split :: (text: string, separator: [] u8, reversed := false, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO, allocator: Allocator = null, allocator_data: *void = null) -> [] string #must {
    result : [..] string;
    set_result_allocator();

    if reversed
        for < make_split(text, separator, current_compare, max_results, skip_empty, keep_separator)
            array_add(*result, it);
    else
        for make_split(text, separator, current_compare, max_results, skip_empty, keep_separator)
            array_add(*result, it);

    return result;
}


split :: (text: string, separator: u8, reversed := false, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO, allocator: Allocator = null, allocator_data: *void = null) -> [] string #must {
    result : [..] string;
    set_result_allocator();

    if reversed
        for < make_split(text, separator, current_compare, max_results, skip_empty, keep_separator)
            array_add(*result, it);
    else
        for make_split(text, separator, current_compare, max_results, skip_empty, keep_separator)
            array_add(*result, it);

    return result;
}


split :: (text: string, indexes: .. int, reversed := false, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO, allocator: Allocator = null, allocator_data: *void = null) -> [] string #must {
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


line_split :: (text: string, reversed := false, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO, allocator: Allocator = null, allocator_data: *void = null) -> [] string #must {
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


split :: (separator: $T/Split_By, reversed := false, allocator: Allocator = null, allocator_data: *void = null) -> [] string #must {
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


pad_start :: (str: string, desired_count: int, pad_with := default_pad_with, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
    #if strict {
        assert(str.count <= desired_count, "Cannot pad string as it is longer than desired count");
    }

    assert(pad_with.count > 0, "pad_with cannot be empty");

    if str.count >= desired_count {
        result : Allocator_Wrapper;
        set_result_allocator();
        return copy(str, result.allocator, result.allocator_data, null_terminate);
    }

    terminating := null_terminate && !ends_with(str, #char "\0", case_sensitive);

    count := desired_count;
    if terminating  count += 1;

    result : Allocator_Wrapper;
    set_result_allocator();

    padded := alloc_string(count, result.allocator, result.allocator_data);
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


pad_start :: inline (str: string, desired_count: int, pad_with: u8, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
    return pad_start(str, desired_count, string_from_char(*pad_with), allocator, allocator_data, null_terminate);
}


pad_end :: (str: string, desired_count: int, pad_with := default_pad_with, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
    #if strict {
        assert(str.count <= desired_count, "Cannot pad string as it is longer than desired count");
    }

    assert(pad_with.count > 0, "pad_with cannot be empty");

    if str.count >= desired_count {
        result : Allocator_Wrapper;
        set_result_allocator();
        return copy(str, result.allocator, result.allocator_data, null_terminate);
    }

    terminating := null_terminate && !ends_with(str, #char "\0", case_sensitive);

    count := desired_count;
    if terminating  count += 1;

    result : Allocator_Wrapper;
    set_result_allocator();

    padded := alloc_string(count, result.allocator, result.allocator_data);
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


pad_end :: inline (str: string, desired_count: int, pad_with: u8, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
    return pad_end(str, desired_count, string_from_char(*pad_with), allocator, allocator_data, null_terminate);
}


pad_center :: (str: string, desired_count: int, pad_with := default_pad_with, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
    #if strict {
        assert(str.count <= desired_count, "Cannot pad string as it is longer than desired count");
    }

    assert(pad_with.count > 0, "pad_with cannot be empty");

    if str.count >= desired_count {
        result : Allocator_Wrapper;
        set_result_allocator();
        return copy(str, result.allocator, result.allocator_data, null_terminate);
    }

    terminating := null_terminate && !ends_with(str, #char "\0", case_sensitive);

    count := desired_count;
    if terminating  count += 1;

    result : Allocator_Wrapper;
    set_result_allocator();

    padded := alloc_string(count, result.allocator, result.allocator_data);
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


pad_center :: inline (str: string, desired_count: int, pad_with: u8, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
    return pad_center(str, desired_count, string_from_char(*pad_with), allocator, allocator_data, null_terminate);
}



repeat :: (str: string, times: int, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
    #if strict {
        assert(str != "", "str cannot be empty");
        assert(times > 0, "count must be a positive number");
    }
    else {
        if str == "" || times <= 0  return empty();
    }

    if times == 1 {
        result : Allocator_Wrapper;
        set_result_allocator();
        return copy(str, result.allocator, result.allocator_data, null_terminate);
    }

    terminating := null_terminate && !ends_with(str, #char "\0", case_sensitive);

    count := str.count * times;
    if terminating  count += 1;

    result : Allocator_Wrapper;
    set_result_allocator();

    repeated := alloc_string(count, result.allocator, result.allocator_data);
    for 0 .. times - 1
        memcpy(repeated.data + it * str.count, str.data, str.count);

    if terminating  repeated[count] = #char "\0";

    return repeated;
}


lower :: (str: string, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
    result := copy(str, allocator, allocator_data, null_terminate);
    to_lower(result);
    return result;
}


upper :: (str: string, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
    result := copy(str, allocator, allocator_data, null_terminate);
    to_upper(result);
    return result;
}


snake_from_camel :: (str: string, preserve_caps := false, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
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
        if buffer.occupied == 0 || <<(buffer.data.data + buffer.occupied - 1) != #char "\0"
            append(*result, #char "\0");
    }

    a, ad := get_allocator(allocator, allocator_data);
    return builder_to_string(*result, allocator = a, allocator_data = ad);
}


camel_from_snake :: (str: string, preserve_caps := false, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
    if str == ""  return empty();

    result : String_Builder;
    set_result_allocator();

    for word: make_split(str, #char "_", current_compare) {
        if word {
            append(*result, word);
            buffer := get_current_buffer(*result);
            in_place : string = ---;
            in_place.data = buffer.data.data + buffer.occupied - word.count;
            in_place.count = word.count;
            to_capitalized(in_place, preserve_caps);
        }
    }

    if null_terminate {
        buffer := get_current_buffer(*result);
        if buffer.occupied == 0 || <<(buffer.data.data + buffer.occupied - 1) != #char "\0"
            append(*result, #char "\0");
    }

    a, ad := get_allocator(allocator, allocator_data);
    return builder_to_string(*result, allocator = a, allocator_data = ad);
}


#if add_convenience_functions {
    print :: (format_string: string, args: .. Any, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
        builder: String_Builder;
        defer free_buffers(*builder);

        print_to_builder(*builder, format_string, ..args);

        return builder_to_string(*builder, allocator = allocator, allocator_data = allocator_data, null_terminate = null_terminate);
    } @PrintLike


    init_string_builder :: (using builder: *String_Builder, allocator: Allocator = null, allocator_data: *void = null) {
        allocator, allocator_data = get_allocator(allocator, allocator_data, String_Builder);
    }


    builder_to_string :: (builder: String_Builder, extra_bytes_to_prepend := 0, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
        a, ad := get_allocator(allocator, allocator_data);

        if null_terminate {
            buffer := get_current_buffer(*builder);
            if buffer.occupied == 0 || <<(buffer.data.data + buffer.occupied - 1) != #char "\0"
                append(*builder, #char "\0");
        }

        return builder_to_string(*builder, allocator = a, allocator_data = ad, extra_bytes_to_prepend);
    }
}



#scope_file



Allocator_Wrapper :: struct {
    allocator : Allocator = null;
    allocator_data : *void = null;
}


set_result_allocator :: () #expand {
    #if type_of(`result) == String_Builder {
        `defer reset(*`result);
        if current_string_builder_allocator {
            `result.allocator = current_string_builder_allocator;
            `result.allocator_data = current_string_builder_allocator_data;
            return;
        }
    }

    if `allocator {
        `result.allocator = `allocator;
        `result.allocator_data = `allocator_data;
    }
    else if `default_allocator {
        `result.allocator = `default_allocator;
        `result.allocator_data = `default_allocator_data;
    }
    else if context.allocator {
        `result.allocator = context.allocator;
        `result.allocator_data = context.allocator_data;
    }
}


get_allocator :: (parameter_allocator: Allocator = null, parameter_allocator_data: *void = null, $type: Type = void) -> Allocator, *void {
    allocator : Allocator;
    allocator_data : *void;

    #if type == String_Builder {
        if current_string_builder_allocator {
            allocator = current_string_builder_allocator;
            allocator_data = current_string_builder_allocator_data;
            return allocator, allocator_data;
        }
    }

    if parameter_allocator {
        allocator = parameter_allocator;
        allocator_data = parameter_allocator_data;
    }
    else if default_allocator {
        allocator = default_allocator;
        allocator_data = default_allocator_data;
    }
    else if context.allocator {
        allocator = context.allocator;
        allocator_data = context.allocator_data;
    }

    return allocator, allocator_data;
}


empty :: () -> string #expand {
    if `null_terminate {
        allocator := `allocator;
        allocator_data := `allocator_data;
        a, ad := get_allocator(allocator, allocator_data);
        empty := alloc_string(1, allocator = a, allocator_data = ad);
        empty[0] = #char "\0";
        return empty;
    }
    else
        return "";
}
