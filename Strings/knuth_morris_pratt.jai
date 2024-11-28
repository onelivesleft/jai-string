// @TODO last_index variants reverse indexing so they can use the mechanics of first_index variants
//       (using `get` etc.) - this makes logic simple but is slower than if it was coded directly,
//       so... code it directly!



knuth_morris_pratt_first_index :: (haystack: string, needle: string, start_index: int, character_compare: Character_Compare) -> index: int, found: bool {
    #insert,scope() first_index_header;
    using context.knuth_morris_pratt_thread_data;
    if !context.knuth_morris_pratt_thread_data  context.knuth_morris_pratt_thread_data = New(Knuth_Morris_Pratt_Thread_Data);

    if needle != last_used_needle || character_compare != last_used_compare || last_search_was_reversed {
        last_search_was_reversed = false;
        last_used_compare = character_compare;
        if last_used_needle  free(last_used_needle);
        last_used_needle = copy_string(needle,, context.default_allocator);
        make_needle_table(needle, character_compare, false);
    }

    j := 0;
    needle_end := needle.count - 1;
    end := cast(u64)haystack.data + cast(u64)haystack.count - 1;
    for i: cast(u64)haystack.data + cast(u64)start_index .. end {
        while j >= 0 && !character_compare.compare(<<cast(*u8)i, needle[j])
            j = needle_table[j];
        if j == needle_end  return cast(s64)((i - cast(u64)j) - cast(u64)haystack.data), true;
        j += 1;
    }

    return -1, false;
}


knuth_morris_pratt_last_index :: (haystack: string, needle: string, start_index: int, character_compare: Character_Compare) -> index: int, found: bool {
    #insert,scope() last_index_header;
    using context.knuth_morris_pratt_thread_data;
    if !context.knuth_morris_pratt_thread_data  context.knuth_morris_pratt_thread_data = New(Knuth_Morris_Pratt_Thread_Data);

    start_index = haystack.count - start_index;

    if needle != last_used_needle || !last_search_was_reversed || character_compare != last_used_compare {
        last_search_was_reversed = true;
        last_used_compare = character_compare;
        if last_used_needle  free(last_used_needle);
        last_used_needle = copy_string(needle,, context.default_allocator);
        make_needle_table(needle, character_compare, true);
    }

    j := 0;
    needle_end := needle.count - 1;
    for i: start_index .. haystack.count - 1 {
        while j >= 0 && !character_compare.compare(get(haystack, i, true), get(needle, j, true))
            j = needle_table[j];
        if j == needle_end  return haystack.count - needle.count - (i - j), true;
        j += 1;
    }

    return -1, false;
}


#scope_file


#add_context knuth_morris_pratt_thread_data: *Knuth_Morris_Pratt_Thread_Data;

Knuth_Morris_Pratt_Thread_Data :: struct {
    last_used_needle : string;
    last_used_compare : Character_Compare;
    last_search_was_reversed : bool;
    needle_table : [..] int;
};


get :: inline (str: string, index: int, $reversed: bool) -> u8 {
    #if reversed  return str[str.count - 1 - index];
    else          return str[index];
}


make_needle_table :: (needle: string, character_compare: Character_Compare, $reversed: bool) {
    using context.knuth_morris_pratt_thread_data;

    push_allocator(context.default_allocator);

    if needle_table.count <= needle.count
        array_resize(*needle_table, needle.count + 1, false);

    needle_table.data[0] = -1;

    for i: 0 .. needle.count - 1 {
        j := i + 1;
        needle_table[j] = needle_table[i] + 1;
        while needle_table[j] > 0 && !character_compare.compare(get(needle, i, reversed), get(needle, needle_table[j] - 1, reversed))
            needle_table[j] = needle_table[needle_table[j] - 1] + 1;
    }
}
