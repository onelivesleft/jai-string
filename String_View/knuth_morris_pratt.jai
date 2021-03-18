#import "String_View";


knuth_morris_pratt_first_index_of :: (haystack: string, needle: string, from_index: int, cmp: type_of(case_sensitive)) -> index: int #must, found: bool {
    if needle == ""  return from_index, true;
    if from_index >= haystack.count - needle.count  return -1, false;

    if needle != last_used_needle || cmp != last_used_cmp || last_search_was_reversed {
        last_search_was_reversed = false;
        last_used_cmp = cmp;
        if last_used_needle  free(last_used_needle);
        last_used_needle = copy_string(needle);
        make_needle_table(*needle_table, needle, cmp, false);
    }

    j := 0;
    needle_end := needle.count - 1;
    for i: from_index .. haystack.count - 1 {
        while j >= 0 && !cmp(haystack[i], needle[j])
            j = needle_table[j];
        if j == needle_end  return i - j, true;
        j += 1;
    }

//    end := cast(u64)haystack.data + cast(u64)(haystack.count - needle.count);
//
//    for start_of_word: cast(u64)haystack.data + cast(u64)from_index .. end {
//        while j >= 0 && !cmp(<<cast(*u8)(start_of_word), needle[j])
//            j = needle_table[j];
//
//        j += 1;
//        if j == needle.count
//            return cast(int)(start_of_word - cast(u64)haystack.data), true;
//    }

    return -1, false;
}


knuth_morris_pratt_last_index_of :: (haystack: string, needle: string, from_index: int, $$cmp: type_of(case_sensitive)) -> index: int #must, found: bool {
    if needle == ""  return from_index - 1, true;
    if from_index < needle.count  return -1, false;
    from_index = haystack.count - from_index;

    if needle != last_used_needle || !last_search_was_reversed || cmp != last_used_cmp {
        last_search_was_reversed = true;
        last_used_cmp = cmp;
        if last_used_needle  free(last_used_needle);
        last_used_needle = copy_string(needle);
        make_needle_table(*needle_table, needle, cmp, true);
    }

    j := from_index;
    k := 0;

    while j < haystack.count {
        if cmp(get(needle, k, true), get(haystack, j, true)) {
            if k == needle.count - 1  return haystack.count - (needle.count + j - k), true;
            j += 1; k += 1;
        }
        else {
            k = needle_table[k];
            if k < 0 {
                j += 1; k += 1;
            }
        }
    }

    return -1, false;
}


#scope_file


last_used_needle : string;
last_used_cmp : type_of(case_sensitive);
last_search_was_reversed := false;
needle_table : [..] int;


get :: inline (str: string, index: int, $$reversed: bool) -> u8 {
    if reversed  return str[str.count - 1 - index];
    else         return str[index];
}


make_needle_table :: (needle_table: *[] int, needle: string, cmp: type_of(case_sensitive), $$reversed: bool) {
    if needle_table.count <= needle.count
        array_resize(needle_table, needle.count + 1, false);

    needle_table.data[0] = -1;

    for i: 0 .. needle.count - 1 {
        j := i + 1;
        needle_table.data[j] = needle_table.data[i] + 1;
        while needle_table.data[j] > 0 && !cmp(needle[i], needle[needle_table.data[j] - 1])
            needle_table.data[j] = needle_table.data[needle_table.data[j] - 1] + 1;
    }

//    for i: 1..needle.count  print("% ", needle_table.data[i]);
//    print("\n");
}
