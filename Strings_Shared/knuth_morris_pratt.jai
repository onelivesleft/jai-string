// @TODO last_index variants reverse indexing so they can use the mechanics of first_index variants
//       (using `get` etc.) - this makes logic simple but is slower than if it was coded directly,
//       so... code it directly!



knuth_morris_pratt_first_index :: (haystack: string, needle: string, start_index: int, compare: Character_Compare) -> index: int, found: bool {
    #insert,scope() first_index_header;

    if needle != thread_data[context.thread_index].last_used_needle || compare != thread_data[context.thread_index].last_used_compare || thread_data[context.thread_index].last_search_was_reversed {
        thread_data[context.thread_index].last_search_was_reversed = false;
        thread_data[context.thread_index].last_used_compare = compare;
        if thread_data[context.thread_index].last_used_needle  free(thread_data[context.thread_index].last_used_needle);
        thread_data[context.thread_index].last_used_needle = copy_string(needle,, __default_allocator);
        make_needle_table(needle, compare, false);
    }

    j := 0;
    needle_end := needle.count - 1;
    end := cast(u64)haystack.data + cast(u64)haystack.count - 1;
    for i: cast(u64)haystack.data + cast(u64)start_index .. end {
        while j >= 0 && !compare.compare(<<cast(*u8)i, needle[j])
            j = thread_data[context.thread_index].needle_table[j];
        if j == needle_end  return cast(s64)((i - cast(u64)j) - cast(u64)haystack.data), true;
        j += 1;
    }

    return -1, false;
}


knuth_morris_pratt_last_index :: (haystack: string, needle: string, start_index: int, compare: Character_Compare) -> index: int, found: bool {
    #insert,scope() last_index_header;

    start_index = haystack.count - start_index;

    if needle != thread_data[context.thread_index].last_used_needle || !thread_data[context.thread_index].last_search_was_reversed || compare != thread_data[context.thread_index].last_used_compare {
        thread_data[context.thread_index].last_search_was_reversed = true;
        thread_data[context.thread_index].last_used_compare = compare;
        if thread_data[context.thread_index].last_used_needle  free(thread_data[context.thread_index].last_used_needle);
        thread_data[context.thread_index].last_used_needle = copy_string(needle,, __default_allocator);
        make_needle_table(needle, compare, true);
    }

    j := 0;
    needle_end := needle.count - 1;
    for i: start_index .. haystack.count - 1 {
        while j >= 0 && !compare.compare(get(haystack, i, true), get(needle, j, true))
            j = thread_data[context.thread_index].needle_table[j];
        if j == needle_end  return haystack.count - needle.count - (i - j), true;
        j += 1;
    }

    return -1, false;
}


#scope_file


#import "Strings_Shared";

max_thread_count :: strings_shared_max_thread_count;

thread_data : [max_thread_count] struct {
    last_used_needle : string;
    last_used_compare : Character_Compare;
    last_search_was_reversed : bool;
    needle_table : [..] int;
};


get :: inline (str: string, index: int, $reversed: bool) -> u8 {
    #if reversed  return str[str.count - 1 - index];
    else          return str[index];
}


make_needle_table :: (needle: string, compare: Character_Compare, $reversed: bool) {
    push_allocator(__default_allocator);

    if thread_data[context.thread_index].needle_table.count <= needle.count
        array_resize(*thread_data[context.thread_index].needle_table, needle.count + 1, false);

    thread_data[context.thread_index].needle_table.data[0] = -1;

    for i: 0 .. needle.count - 1 {
        j := i + 1;
        thread_data[context.thread_index].needle_table[j] = thread_data[context.thread_index].needle_table[i] + 1;
        while thread_data[context.thread_index].needle_table[j] > 0 && !compare.compare(get(needle, i, reversed), get(needle, thread_data[context.thread_index].needle_table[j] - 1, reversed))
            thread_data[context.thread_index].needle_table[j] = thread_data[context.thread_index].needle_table[thread_data[context.thread_index].needle_table[j] - 1] + 1;
    }

//    for i: 1..needle.count  print("% ", needle_table.data[i]);
//    print("\n");
}
