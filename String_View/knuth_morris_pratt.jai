#import "String_View";


knuth_morris_pratt_first_index_of :: (haystack: string, needle: string, from_index: int, cmp: type_of(case_sensitive)) -> index: int #must, found: bool {
    if needle == ""  return from_index, true;
    if from_index >= haystack.count - needle.count  return -1, false;

    if needle != last_used_needle || last_search_was_reversed {
        last_search_was_reversed = false;
        if last_used_needle  free(last_used_needle);
        last_used_needle = copy_string(needle);
        make_needle_table(*needle_table, needle, cmp, false);
    }

    j := from_index;
    k := 0;

    while j < haystack.count {
        if cmp(needle[k], haystack[j]) {
            if k == needle.count - 1  return j - k, true;
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


knuth_morris_pratt_last_index_of :: (haystack: string, needle: string, from_index: int, $$cmp: type_of(case_sensitive)) -> index: int #must, found: bool {
    if needle == ""  return from_index - 1, true;
    if from_index < needle.count  return -1, false;
    from_index = haystack.count - from_index;

    if needle != last_used_needle || !last_search_was_reversed {
        last_search_was_reversed = true;
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

    cnd := 0;
    for pos: 1 .. needle.count - 1 {
        if cmp(get(needle, pos, reversed), get(needle, cnd, reversed))
            needle_table.data[pos] = needle_table.data[cnd];
        else {
            needle_table.data[pos] = cnd;
            while cnd > 0 && !cmp(get(needle, pos, reversed), get(needle, cnd, reversed))
                cnd = needle_table.data[cnd];
        }
    }

    needle_table.data[needle.count] = cnd;
}
