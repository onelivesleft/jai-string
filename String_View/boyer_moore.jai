// Based on copypasta from wikipedia


#import "String_View";


boyer_moore_first_index_of :: (haystack: string, needle: string, from_index: int, cmp: type_of(case_sensitive)) -> index: int #must, found: bool {
    if needle == ""  return from_index, true;
    if from_index >= haystack.count - needle.count  return -1, false;

    if needle != last_used_needle || last_search_was_reversed {
        last_search_was_reversed = false;
        if last_used_needle  free(last_used_needle);
        last_used_needle = copy_string(needle);
        make_bad_character_delta(needle, false);
        make_good_suffix_delta(*good_suffix_delta, needle, cmp, false);
    }

    haystack_index := needle.count - 1 + from_index;
    while haystack_index < haystack.count {
        needle_index := needle.count - 1;
        while needle_index >= 0 && cmp(haystack[haystack_index], needle[needle_index]) {
            haystack_index -= 1;
            needle_index -= 1;
        }
        if needle_index < 0  return haystack_index + 1, true;

        haystack_index += max(bad_character_delta[haystack[haystack_index]], good_suffix_delta[needle_index]);
    }

    return -1, false;
}


boyer_moore_last_index_of :: (haystack: string, needle: string, from_index: int, cmp: type_of(case_sensitive)) -> index: int #must, found: bool {
    if needle == ""  return from_index - 1, true;
    if from_index < needle.count  return -1, false;
    from_index = haystack.count - from_index;

    if needle != last_used_needle || !last_search_was_reversed {
        last_search_was_reversed = true;
        if last_used_needle  free(last_used_needle);
        last_used_needle = copy_string(needle);
        make_bad_character_delta(needle, true);
        make_good_suffix_delta(*good_suffix_delta, needle, cmp, true);
    }

    haystack_index := needle.count - 1 + from_index;
    needle_end := needle.count - 1;
    while haystack_index < haystack.count {
        needle_index := needle_end;

        while needle_index >= 0 && cmp(get(haystack, haystack_index, true), get(needle, needle_index, true)) {
            haystack_index -= 1;
            needle_index -= 1;
        }
        if needle_index < 0  return haystack.count - needle.count - (haystack_index + 1), true;

        haystack_index += max(bad_character_delta[get(haystack, haystack_index, true)], good_suffix_delta[needle_index]);
    }

    return -1, false;
}


#scope_file


alphabet_count :: 256;

bad_character_delta : [alphabet_count] int;
good_suffix_delta : [..] int;
last_used_needle : string;
last_search_was_reversed := false;


get :: inline (str: string, index: int, $$reversed: bool) -> u8 {
    if reversed  return str[str.count - 1 - index];
    else         return str[index];
}


make_bad_character_delta :: (needle: string, $$reversed: bool) {
    for i: 0 .. alphabet_count - 1
        bad_character_delta[i] = needle.count;
    for i: 0 .. needle.count - 1
        bad_character_delta[get(needle, i, reversed)] = max(1, needle.count - 1 - i);
}


is_prefix :: (word: string, index: int, cmp: type_of(case_sensitive), $$reversed: bool) -> bool {
    for word_index: 0 .. word.count - index - 1
        if !cmp(get(word, word_index, reversed), get(word, index + word_index, reversed))
            return false;

    return true;
}


get_suffix_count :: (word: string, index: int, cmp: type_of(case_sensitive), $$reversed: bool) -> int {
    word_index := 0;
    while cmp(get(word, index - word_index, reversed), get(word, word.count - 1 - word_index, reversed)) && word_index < index
        word_index += 1;

    return word_index;
}


make_good_suffix_delta :: (good_suffix_delta: *[] int, needle: string, cmp: type_of(case_sensitive), $$reversed: bool) {
    if good_suffix_delta.count < needle.count
        array_resize(good_suffix_delta, needle.count, false);

    last_prefix_index := needle.count - 1;

    for < index: needle.count - 1 .. 0 {
        if is_prefix(needle, index + 1, cmp, reversed)
            last_prefix_index = index + 1;
        good_suffix_delta.data[index] = last_prefix_index + needle.count - 1 - index;
    }

    for index: 0 .. needle.count - 2 {
        suffix_count := get_suffix_count(needle, index, cmp, reversed);
        if !cmp(get(needle, index - suffix_count, reversed), get(needle, needle.count - 1 - suffix_count, reversed))
            good_suffix_delta.data[needle.count - 1 - suffix_count] = needle.count - 1 - index + suffix_count;
    }
}
