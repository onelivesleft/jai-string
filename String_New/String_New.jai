// Every proc in this module allocates, so every proc should take an `allocator` parameter!
// as well as an `allocator_data` parameter.


#module_parameters (
    default_allocator : Allocator = null,
    default_allocator_data : *void = null,
    default_compare := case_sensitive,
    strict := false,                         // Asserts when indices fall outside the range of the string
    debug := false
);

// TODO
// [ ] repeat
// [ ] snake_from_camel / camel_from_snake
// [ ] capitalize (maybe not ^)
// [ ] justify / pad
// [ ] maybe conflate separators in split?
// [ ] maybe split_lines?
// [ ] forward_til?
// [ ] fast string compare
// [ ] null_terminate parameter?


#import "Basic";
#import "String_View";


copy_string :: (s: string, allocator: Allocator, allocator_data: *void, $$null_terminate := false) -> string #must {
    if !s.count return "";

    copy : string = ---;

    if null_terminate && s[s.count - 1] != #char "\0" {
        copy = alloc_string(s.count + 1, allocator = allocator, allocator_data = allocator_data);
        memcpy(copy.data, s.data, s.count);
        copy[copy.count - 1] = #char "\0";
    }
    else {
        copy = alloc_string(s.count, allocator = allocator, allocator_data = allocator_data);
        memcpy(copy.data, s.data, s.count);
    }
    return copy;
}


reversed :: (s: string, allocator: Allocator, allocator_data: *void, $$null_terminate := false) -> string #must {
    if !s.count return "";
    a, ad := get_allocator(allocator, allocator_data);
    result : string = ---;
    terminating := null_terminate && s[0] != #char "\0";
    if terminating
        result = alloc_string(s.count + 1, allocator = a, allocator_data = ad);
    else
        result = alloc_string(s.count, allocator = a, allocator_data = ad);

    end := s.data + s.count - 1;
    for i: 0 .. s.count - 1
        result[i] = s[end - i];

    if terminating  result[s.count] = #char "\0";

    return result;
}


replace :: (haystack: string, needle: string, replacement: string, cmp: type_of(default_compare), allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
    return replace(haystack, needle, replacement, 0, cmp, allocator, allocator_data, null_terminate);
}


replace :: (haystack: string, needle: string, replacement: string, max_replacements := 0, $$cmp := default_compare, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
    #if strict {
        assert(needle != "", "You cannot replace an empty string");
        assert(max_replacements >= 0, "max_replacements cannot be negative");
    }
    else {
        if needle == "" {
            result : Allocator_Wrapper;
            set_result_allocator();
            return copy_string(haystack, result.allocator, result.allocator_data, null_terminate);
        }
    }

    result : String_Builder;
    init_string_builder(*result);
    set_result_allocator();

    first_loop := true;
    last_string := "";
    for forward_split(haystack, needle, max_results = ifx max_replacements <= 0 then 0 else max_replacements + 1, cmp = cmp) {
        if first_loop  first_loop = false;
        else           append(*result, replacement);
        append(*result, it);
    }

    if null_terminate {
        buffer := get_current_buffer(*result);
        if <<(buffer.data.data + buffer.occupied - 1) != #char "\0"
            append(*result, #char "\0");
    }

    return builder_to_string(*result);
}



join :: (parts: [] string, separator: string, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
    if parts.count == 0 {
        result : Allocator_Wrapper;
        set_result_allocator();
        return copy_string("", result.allocator, result.allocator_data, null_terminate);
    }

    if parts.count == 1 {
        result : Allocator_Wrapper;
        set_result_allocator();
        return copy_string(parts[0], result.allocator, result.allocator_data, null_terminate);
    }

    terminating := null_terminate && !ends_with(parts[parts.count - 1], #char "\0");

    count := separator.count * (parts.count - 1);
    for parts  count += it.count;
    if terminating  count += 1;

    result : Allocator_Wrapper;
    set_result_allocator();

    joined := alloc_string(count, result.allocator, result.allocator_data);
    memcpy(joined.data, parts[0].data, parts[0].count);
    position := joined.data + parts[0].count;
    for 1 .. parts.count - 1 {
        memcpy(position, separator.data, separator.count);
        position += separator.count;
        memcpy(position, parts[it].data, parts[it].count);
        position += parts[it].count;
    }

    if terminating  joined[count] = #char "\0";

    return joined;
}


join :: (parts: [] string, separator: u8, allocator: Allocator = null, allocator_data: *void = null, $$null_terminate := false) -> string #must {
    return join(parts, string_from_char(*separator), allocator, allocator_data);
}


split :: inline (text: string, separator: string, cmp: type_of(default_compare), skip_empty := false, allocator: Allocator = null, allocator_data: *void = null) -> [] string #must {
    return split_internal(text, separator, false, 0, cmp, skip_empty, allocator, allocator_data);
}


split :: inline (text: string, separator: string, reversed := false, max_results := 0, $$cmp := default_compare, skip_empty := false, allocator: Allocator = null, allocator_data: *void = null) -> [] string #must {
    return split_internal(text, separator, reversed, max_results, cmp, skip_empty, allocator, allocator_data);
}


split :: inline (text: string, separator: [] u8, reversed := false, max_results := 0, skip_empty := false, allocator: Allocator = null, allocator_data: *void = null) -> [] string #must {
    return split_internal(text, separator, reversed, max_results, default_compare, skip_empty, allocator, allocator_data);
}


split :: inline (text: string, separator: u8, reversed := false, max_results := 0, skip_empty := false, allocator: Allocator = null, allocator_data: *void = null) -> [] string #must {
    return split_internal(text, separator, reversed, max_results, default_compare, skip_empty, allocator, allocator_data);
}


#scope_file


Allocator_Wrapper :: struct {
    allocator : Allocator = null;
    allocator_data : *void = null;
}


split_internal :: (text: string, separator: $T, reversed := false, max_results := 0, $$cmp := default_compare, skip_empty := false, allocator: Allocator = null, allocator_data: *void = null) -> [] string #must {
    result : [..] string;
    set_result_allocator();

    #if T == string {
        if reversed {
            for reverse_split(text, separator, max_results, cmp, skip_empty)
                array_add(*result, it);
        }
        else {
            for forward_split(text, separator,  max_results, cmp, skip_empty)
                array_add(*result, it);
        }
    }
    else {
        if reversed {
            for reverse_split(text, separator, max_results, skip_empty)
                array_add(*result, it);
        }
        else {
            for forward_split(text, separator,  max_results, skip_empty)
                array_add(*result, it);
        }
    }

    return result;
}


set_result_allocator :: () #expand {
    if `allocator {
        `result.allocator = `allocator;
        if `allocator_data
            `result.allocator_data = `allocator_data;
    }
    else if `default_allocator {
        `result.allocator = `default_allocator;
        if `default_allocator_data
            `result.allocator_data = `default_allocator_data;
    }

    #if debug {
        print("Parameter allocator: %\n", `allocator);
        print("Default allocator:   %\n", `default_allocator);
        print("Used allocator:      %\n", `result.allocator);
    }
}


get_allocator :: (parameter_allocator: Allocator, parameter_allocator_data: *void) -> Allocator #must, *void #must {
    allocator : Allocator;
    allocator_data : *void;

    if parameter_allocator {
        allocator = parameter_allocator;
        if parameter_allocator_data
            allocator_data = parameter_allocator_data;
    }
    else if default_allocator {
        allocator = default_allocator;
        if default_allocator_data
            allocator_data = default_allocator_data;
    }

    #if debug {
        print("Parameter allocator: %\n", parameter_allocator);
        print("Default allocator:   %\n", default_allocator);
        print("Used allocator:      %\n", allocator);
    }

    return allocator, allocator_data;
}
