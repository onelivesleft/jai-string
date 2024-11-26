Split_By :: struct {
    text           : string;
    max_results    : int;
    skip_empty     : bool;
    keep_separator : Keep_Separator;
    compare        : Character_Compare;
}


Split_By_String :: struct {
    #as using base: Split_By;
    separator : string;
    first_index : String_Index_Proc;
    last_index  : String_Index_Proc;
}


Split_By_Chars :: struct {
    #as using base: Split_By;
    separator : [] u8;
}


Split_By_Char :: struct {
    #as using base: Split_By;
    separator : u8;
}


Split_By_Index :: struct {
    #as using base: Split_By;
    indexes : [] int;
}


Split_By_Count :: struct {
    #as using base: Split_By;
    count : int;
}


Split_By_Line :: struct {
    #as using base: Split_By;
}


Split_By_Proc :: struct {
    #as using base: Split_By;
    separator : string;
    index_proc : Index_Proc;
}


#scope_file

fill_split_struct :: () #expand {
    assert(`max_results >= 0, "max_results cannot be negative : %", `max_results);
    `split_struct.text           = `text;
    `split_struct.max_results    = `max_results;
    `split_struct.skip_empty     = `skip_empty;
    `split_struct.keep_separator = `keep_separator;
}

#scope_export


to_array :: (splitter: $T/Split_By, reversed := false) -> [..] string {
    result : [..] string;
    if reversed  for < splitter  array_add(*result, it);
    else         for splitter    array_add(*result, it);
    return result;
}


split_at_index :: (text: string, index: int) -> string, string {
    return slice(text, 0, index), slice(text, index);
}

split_into_two :: (text: string, separator: u8) -> string, string {
    index, found := first_index(text, separator);
    if !found  return text, "";
    return raw_slice(text, 0, index), raw_slice(text, index + 1);
}

split_into_two :: (text: string, separator: [] u8) -> string, string {
    index, found := first_index(text, separator);
    if !found  return text, "";
    return raw_slice(text, 0, index), raw_slice(text, index + 1);
}

split_into_two :: (text: string, separator: string) -> string, string {
    index, found := first_index(text, separator);
    if !found  return text, "";
    return raw_slice(text, 0, index), raw_slice(text, index + separator.count);
}

split_into_two :: (text: string, separator: string, $$separator_proc: Index_Proc) -> string, string {
    from_index, found, to_index := first_index(text, separator, separator_proc);
    if !found  return text, "";
    return raw_slice(text, 0, from_index), raw_slice(text, to_index);
}

split_into_two :: (text: string, separator: $T, keep_separator: Keep_Separator) -> string, string {
    first, second := split_into_two(text, separator, keep_separator, current_compare);
    return first, second;
}

split_into_two :: (text: string, separator: $T, compare: Character_Compare) -> string, string {
    first, second := split_into_two(text, separator, .NO, compare);
    return first, second;
}

split_into_two :: (text: string, separator: $T, keep_separator: Keep_Separator, compare: Character_Compare) -> string, string {
    parts : [2] string = ---;
    split(*parts, text, separator, keep_separator = keep_separator, compare = compare);
    return parts[0], parts[1];
}


split_into :: (array: *[$N] string, text: string, separator: $T, reversed := false, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO, compare: Character_Compare) -> count: int
#modify {
    if T == int  T = u8; // Feels like a kludge; sometimes when we get to here with a #char param it'll register as int and not match inside the split call below.
    return T == u8 || T == [] u8 || T == string || T == Index_Proc;
} {
    count := -1;
    _max_results := ifx max_results <= 0 || max_results > N then N else max_results;
    if reversed {
        for < split(text, separator, max_results = _max_results, skip_empty = skip_empty, keep_separator = keep_separator, compare = compare) {
            array.*[it_index] = it;
            count = it_index;
        }
    }
    else {
        for split(text, separator, max_results = _max_results, skip_empty = skip_empty, keep_separator = keep_separator, compare = compare) {
            array.*[it_index] = it;
            count = it_index;
        }
    }
    count += 1;
    remainder := (N - 1) - count;
    if remainder > 0
        memset(array.data + count, 0, remainder * size_of(string));
    return count;
}

split_into :: (array: *[$N] string, text: string, separator: $T, reversed := false, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> count: int
#modify {
    if T == int  T = u8;
    return T == u8 || T == [] u8 || T == string || T == Index_Proc;
} {
    return split_into(array, text, separator, reversed, max_results, skip_empty, keep_separator, current_compare);
}


split :: inline (text: string, separator: string, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO, compare: Character_Compare) -> Split_By_String {
    return make_split(text, separator, compare, current_first_index, current_last_index, max_results, skip_empty, keep_separator);
    //return Split_By_String.{.{text, max_results, skip_empty, keep_separator, compare}, separator, current_first_index, current_last_index};
}

split :: inline (text: string, separator: string, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> Split_By_String {
    return make_split(text, separator, current_compare, current_first_index, current_last_index, max_results, skip_empty, keep_separator);
    //return Split_By_String.{.{text, max_results, skip_empty, keep_separator, current_compare}, separator, current_first_index, current_last_index};
}


split :: inline (text: string, separator: [] u8, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO, compare: Character_Compare) -> Split_By_Chars {
    return make_split(text, separator, compare, max_results, skip_empty, keep_separator);
}

split :: inline (text: string, separator: [] u8, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> Split_By_Chars {
    return make_split(text, separator, current_compare, max_results, skip_empty, keep_separator);
}


split :: inline (text: string, separator: u8, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO, compare: Character_Compare) -> Split_By_Char {
    return make_split(text, separator, compare, max_results, skip_empty, keep_separator);
}

split :: inline (text: string, separator: u8, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> Split_By_Char {
    return make_split(text, separator, current_compare, max_results, skip_empty, keep_separator);
}


count_split :: inline (text: string, count: int, max_results := 0) -> Split_By_Count {
    return make_split(text, count, max_results);
}


index_split :: inline (text: string, indexes: .. int, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> Split_By_Index {
    return make_split(text, indexes, max_results, skip_empty);
}


split :: inline (text: string, separator: string, $$index: Index_Proc, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> Split_By_Proc {
    return make_split(text, separator, index, max_results, skip_empty, keep_separator);
}


line_split :: inline (text: string, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> Split_By_Line {
    return make_line_split(text,max_results, skip_empty, keep_separator);
}


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


make_split :: (text: string, count: int, max_results := 0) -> Split_By_Count {
    split_struct : Split_By_Count = ---;
    split_struct.text = text;
    assert(max_results >= 0, "max_results cannot be negative : %", max_results);
    split_struct.max_results = max_results;
    assert(count > 0, "Count must be greater than 0 : %", count);
    split_struct.count = count;
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

    for escape: 1..1 { // so break avoids the cleanup #insert
        if splitter.max_results == 1 {
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
                    defer index, found = last_index(splitter.text, splitter.separator, index, splitter.compare, splitter.last_index);

                    it = raw_slice(splitter.text, index + separator_offset_to_start, end_index);
                    end_index = index + separator_offset_to_end;

                    if !splitter.skip_empty || it.count != empty_count {
                        it_index += 1;
                        defer if splitter.max_results != 0 && it_index >= max_it_index  break;

                        #insert(break = break escape) body;
                    }

                }

                it = raw_slice(splitter.text, 0, end_index);
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
                    defer index, found = first_index(splitter.text, splitter.separator, index + splitter.separator.count, splitter.compare, splitter.first_index);

                    it = raw_slice(splitter.text, start_index, index + separator_offset_to_end);
                    start_index = index + separator_offset_to_start;

                    if !splitter.skip_empty || it.count > empty_count {
                        it_index += 1;
                        defer if splitter.max_results != 0 && it_index >= max_it_index  break;

                        #insert(break = break escape) body;
                    }
                }

                it = raw_slice(splitter.text, start_index);
            }

            if !splitter.skip_empty || it.count != empty_count {
                it_index += 1;
                #insert body;
            }
        }
    }
}


for_expansion :: (splitter: *Split_By_Proc, body: Code, flags: For_Flags) #expand {
	#assert(!(flags & .POINTER));
    reverse := flags & .REVERSE;

    `it : string = ---;
    `it_index : int = -1;

    for escape: 1..1 { // so break avoids the cleanup #insert
        if splitter.max_results == 1 {
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
                    defer from_index, to_index, found = splitter.index_proc(splitter.text, splitter.separator, from_index, true);

                    if #complete splitter.keep_separator == {
                        case .AS_PREFIX;
                        it = raw_slice(splitter.text, from_index, end_index);
                        end_index = from_index;

                        case .AS_POSTFIX;
                        it = raw_slice(splitter.text, to_index, end_index);
                        end_index = to_index;

                        case .NO;
                        it = raw_slice(splitter.text, to_index, end_index);
                        end_index = from_index;
                    }

                    if !splitter.skip_empty || it != "" {
                        it_index += 1;
                        defer if splitter.max_results != 0 && it_index >= max_it_index  break;

                        #insert(break = break escape) body;
                    }
                }

                it = raw_slice(splitter.text, 0, end_index);
            }
            else {
                start_index := 0;
                from_index, to_index, found := splitter.index_proc(splitter.text, splitter.separator, 0, false);
                while found {
                    defer from_index, to_index, found = splitter.index_proc(splitter.text, splitter.separator, to_index, false);

                    if #complete splitter.keep_separator == {
                        case .AS_PREFIX;
                        it = raw_slice(splitter.text, start_index, from_index);
                        start_index = from_index;

                        case .AS_POSTFIX;
                        it = raw_slice(splitter.text, start_index, to_index);
                        start_index = to_index;

                        case .NO;
                        it = raw_slice(splitter.text, start_index, from_index);
                        start_index = to_index;
                    }

                    if !splitter.skip_empty || it != "" {
                        it_index += 1;
                        defer if splitter.max_results != 0 && it_index >= max_it_index  break;

                        #insert(break = break escape) body;
                    }
                }

                it = raw_slice(splitter.text, start_index);
            }

            if !splitter.skip_empty || it != "" {
                it_index += 1;

                #insert body;
            }
        }
    }
}


for_expansion :: (splitter: *Split_By_Chars, body: Code, flags: For_Flags) #expand {
    #assert(!(flags & .POINTER));
    reverse := flags & .REVERSE;

    `it : string = ---;
    `it_index : int = -1;

    for escape: 1..1 { // so break avoids the cleanup #insert
        if splitter.max_results == 1 {
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
                    defer index, found = last_index(splitter.text, splitter.separator, index, splitter.compare);

                    it = raw_slice(splitter.text, index + separator_offset_to_start, end_index);
                    end_index = index + separator_offset_to_end;

                    if !splitter.skip_empty || it.count != empty_count {
                        it_index += 1;
                        defer if splitter.max_results != 0 && it_index >= max_it_index  break;

                        #insert(break = break escape) body;
                    }

                }

                it = raw_slice(splitter.text, 0, end_index);
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
                    defer index, found = first_index(splitter.text, splitter.separator, index + 1, splitter.compare);

                    it = raw_slice(splitter.text, start_index, index + separator_offset_to_end);
                    start_index = index + separator_offset_to_start;

                    if !splitter.skip_empty || it.count != empty_count {
                        it_index += 1;
                        defer if splitter.max_results != 0 && it_index >= max_it_index  break;

                        #insert(break = break escape) body;
                    }
                }

                it = raw_slice(splitter.text, start_index);
            }

            if !splitter.skip_empty || it.count != empty_count {
                it_index += 1;
                #insert body;
            }
        }
    }
}



for_expansion :: (splitter: *Split_By_Char, body: Code, flags: For_Flags) #expand {
	#assert(!(flags & .POINTER));
    reverse := flags & .REVERSE;

    `it : string = ---;
    `it_index : int = -1;

    for escape: 1..1 { // so break avoids the cleanup #insert
        if splitter.max_results == 1 {
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
                    defer index, found = last_index(splitter.text, splitter.separator, index, splitter.compare);

                    it = raw_slice(splitter.text, index + separator_offset_to_start, end_index);
                    end_index = index + separator_offset_to_end;

                    if !splitter.skip_empty || it.count != empty_count {
                        it_index += 1;
                        defer if splitter.max_results != 0 && it_index >= max_it_index  break;

                        #insert(break = break escape) body;
                    }
                }

                it = raw_slice(splitter.text, 0, end_index);
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
                    defer index, found = first_index(splitter.text, splitter.separator, index + 1, splitter.compare);

                    it = raw_slice(splitter.text, start_index, index + separator_offset_to_end);
                    start_index = index + separator_offset_to_start;

                    if !splitter.skip_empty || it.count != empty_count {
                        it_index += 1;
                        defer if splitter.max_results != 0 && it_index >= max_it_index  break;

                        #insert(break = break escape) body;
                    }
                }

                it = raw_slice(splitter.text, start_index);
            }

            if !splitter.skip_empty || it.count != empty_count {
                it_index += 1;
                #insert body;
            }
        }
    }
}


for_expansion :: (splitter: *Split_By_Index, body: Code, flags: For_Flags) #expand {
	#assert(!(flags & .POINTER));
    reverse := flags & .REVERSE;

    `it : string = ---;
    `it_index : int = -1;

    for escape: 1..1 { // so break avoids the cleanup #insert
        if splitter.max_results == 1 {
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
                    it = raw_slice(splitter.text, start_index, end_index);
                    end_index = start_index;

                    if splitter.skip_empty && it == ""  continue;

                    it_index += 1;
                    defer if splitter.max_results != 0 && it_index >= max_it_index  break;

                    #insert(break = break escape) body;
                }

                it = raw_slice(splitter.text, 0, end_index);
            }
            else {
                start_index := 0;
                for index, splitter_index: splitter.indexes {
                    start_index = slice_index(splitter.text, start_index);
                    end_index := slice_index(splitter.text, ifx index > start_index then index else start_index);
                    it = raw_slice(splitter.text, start_index, end_index);
                    start_index = end_index;

                    if splitter.skip_empty && it == ""  continue;

                    it_index += 1;
                    defer if splitter.max_results != 0 && it_index >= max_it_index  break;

                    #insert(break = break escape) body;
                }

                it = raw_slice(splitter.text, start_index);
            }

            if !splitter.skip_empty || it != "" {
                it_index += 1;

                #insert body;
            }
        }
    }
}


for_expansion :: (splitter: *Split_By_Count, body: Code, flags: For_Flags) #expand {
	#assert(!(flags & .POINTER));
    reverse := flags & .REVERSE;

    `it : string = ---;
    `it_index : int = -1;

    for escape: 1..1 { // so break avoids the cleanup #insert
        if splitter.max_results == 1 {
            it = splitter.text;
            it_index = 0;

            #insert body;
        }
        else {
            max_it_index := ifx splitter.max_results == 0 then 0 else splitter.max_results - 2;

            if reverse {
                end_index := splitter.text.count;
                start_index := end_index - splitter.count;
                while start_index > 0 {
                    it = raw_slice(splitter.text, start_index, end_index);
                    end_index = start_index;
                    start_index -= splitter.count;

                    it_index += 1;
                    defer if splitter.max_results != 0 && it_index >= max_it_index  break;

                    #insert(break = break escape) body;
                }

                it = raw_slice(splitter.text, 0, end_index);
            }
            else {
                start_index := 0;
                end_index := start_index + splitter.count;
                while end_index < splitter.text.count {
                    it = raw_slice(splitter.text, start_index, end_index);
                    start_index = end_index;
                    end_index += splitter.count;

                    it_index += 1;
                    defer if splitter.max_results != 0 && it_index >= max_it_index  break;

                    #insert(break = break escape) body;
                }

                it = raw_slice(splitter.text, start_index);
            }

            if it {
                it_index += 1;
                #insert body;
            }
        }
    }
}


for_expansion :: (splitter: *Split_By_Line, body: Code, flags: For_Flags) #expand {
	#assert(!(flags & .POINTER));
    reverse := flags & .REVERSE;

    it_is_empty :: () -> bool #expand {
        if `splitter.keep_separator != .NO
            return `it == "" || `it.count == 1 || `it.count == 2 && `it[0] == Chars.CR;
        else
            return `it == "";
    }

    `it : string = ---;
    `it_index : int = -1;

    for escape: 1..1 { // so break avoids the cleanup #insert
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
                    defer index, found = last_index(splitter.text, Chars.LF, index, splitter.compare);

                    if #complete splitter.keep_separator == {
                        case .AS_PREFIX;
                        if index > 0 && splitter.text[index - 1] == Chars.CR
                            index -= 1;
                        it = raw_slice(splitter.text, index, end_index);
                        end_index = index;

                        case .AS_POSTFIX;
                        it = raw_slice(splitter.text, index + 1, end_index);
                        end_index = index + 1;

                        case .NO;
                        it = raw_slice(splitter.text, index + 1, end_index);
                        if index > 0 && splitter.text[index - 1] == Chars.CR
                            end_index = index - 1;
                        else
                            end_index = index;
                    }

                    if !splitter.skip_empty || !it_is_empty() {
                        it_index += 1;
                        defer if splitter.max_results != 0 && it_index >= max_it_index  break;

                        #insert(break = break escape) body;
                    }
                }

                if end_index > 0 {
                    it = raw_slice(splitter.text, 0, end_index);

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
                    defer index, found = first_index(splitter.text, Chars.LF, index + 1, splitter.compare);

                    if #complete splitter.keep_separator == {
                        case .AS_PREFIX;
                        end_index := index;
                        if end_index > 0 && splitter.text[end_index - 1] == Chars.CR
                            end_index -= 1;
                        it = raw_slice(splitter.text, start_index, end_index);
                        start_index = end_index;

                        case .AS_POSTFIX;
                        it = raw_slice(splitter.text, start_index, index + 1);
                        start_index = index + 1;

                        case .NO;
                        end_index := index;
                        if end_index > 0 && splitter.text[end_index - 1] == Chars.CR
                            end_index -= 1;
                        it = raw_slice(splitter.text, start_index, end_index);
                        start_index = index + 1;
                    }

                    if !splitter.skip_empty || !it_is_empty() {
                        it_index += 1;
                        defer if splitter.max_results != 0 && it_index >= max_it_index  break;

                        #insert(break = break escape) body;
                    }
                }

                if start_index < splitter.text.count {
                    it = raw_slice(splitter.text, start_index, splitter.text.count);

                    if !splitter.skip_empty || !it_is_empty() {
                        it_index += 1;
                        #insert body;
                    }
                }
            }
        }
    }

}
