// All functions return a string view and/or mutate a string view in-place


// @Release v1.0 checklist:
// [ ] Wait for compiler to allow .AVX2
// [x] Check eveything which could be using `first_index` is doing so
// [x] Update readme
// [x] `keep_separator` on all `split`
// [x] `trim_to`, `trim_past`
// [x] trim_start_to, trim_start_past, trim_end_from, trim_end_after
// [x] first_index lambda needle
// [x] split at
// [x] trim string characters?
// [x] default_compare

// @Todo
// Extras
// [ ] get_index(split(foo, bar), i) -> string - return string view on foo as if it had been split and then indexed by i
//     - is this useful?  example which prompted it was better done using trim_start_past anyway...
//       maybe useful if you can set a start and end index? hmmm
// [ ] split_into_two, split_into_three ?
// [ ] Add SIMD_mode to Comparator?
// [ ] SIMD first_index/last_index chars
// [ ] SIMD replace char   // wait until we can split asm blocks
// [ ] SIMD replace chars  // wait until we can split asm blocks
// [ ] SIMD is_any?
// [.] double-up in `repeat`
// [x] SIMD reverse
// [x] SIMD count chars
// [x] SIMD to_lower / to_upper
// [x] SIMD count char


#import "Basic";
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


equal :: inline (a: string, b: string) -> bool {
    return equal(a, b, current_compare);
}


slice :: inline (str: string, from_index: int, to_index: int) -> string, normalized_from_index: int, normalized_to_index: int {
    #if strict {
        if from_index < 0  from_index = str.count + from_index;

        assert(from_index >= 0 && from_index <= str.count, "Cannot slice; from_index falls outwith range of string.");

        if to_index < 0  to_index = str.count + to_index;

        assert(to_index >= from_index, "Cannot slice; to_index is ahead of to_index.");
        assert(to_index <= str.count, "Cannot slice; to_index falls outwith range of string.");
    }
    else {
        if from_index >= 0  from_index = min(from_index, str.count);
        else                from_index = clamp(str.count + from_index, 0, str.count);

        if to_index >= 0  to_index = min(to_index, str.count);
        else              to_index = clamp(str.count + to_index, 0, str.count);
    }

    if from_index >= to_index  return "", from_index, to_index;

    result : string = ---;
    result.data = str.data + from_index;
    result.count = to_index - from_index;
    return result, from_index, to_index;
}


slice :: inline (str: string, from_index: int) -> string, normalized_from_index: int, normalized_to_index: int {
    result, normalized_from_index, normalized_to_index := slice(str, from_index, str.count);
    return result, normalized_from_index, normalized_to_index;
}


substring :: inline (str: string, from_index: int) -> string, normalized_from_index: int, normalized_to_index: int {
    result, normalized_from_index, normalized_to_index := slice(str, from_index, str.count);
    return result, normalized_from_index, normalized_to_index;
}


substring :: (str: string, from_index: int, count: int) -> string, normalized_from_index: int, normalized_to_index: int {
    #if strict {
        assert(count >= 0, "substring count must not be negative.");
    }
    else {
        if count <= 0  return "", from_index, from_index;
    }

    result, normalized_from_index, normalized_to_index := slice(str, from_index, from_index + count);
    return result, normalized_from_index, normalized_to_index;
}


reverse :: _reverse;


// @Note `needle` is guaranteed to be at least 2 characters long, as the call site is internal to the module and checks.
reverse_index_proc :: (index_proc: Index_Proc, haystack: string, needle: string, boundary_index: int) -> from_index: int, to_index: int, found: bool {
    for < haystack_index: haystack.count - 1 .. 0 {
        s := unsafe_slice(haystack, haystack_index);
        from_index, to_index, found := index_proc(s, needle, 0, false);
        if found && haystack_index + to_index <= boundary_index
            return haystack_index + from_index, haystack_index + to_index, true;
    }

    return -1, -1, false;
}



first_index :: inline (haystack: string, needle: u8, from_index := 0) -> index: int, found: bool {
    index, found := first_index(haystack, needle, from_index, current_compare);
    return index, found;
}

first_index :: inline (haystack: string, needle: [] u8, from_index := 0) -> index: int, found: bool {
    index, found := first_index(haystack, needle, from_index, current_compare);
    return index, found;
}

first_index :: inline (haystack: string, needle: string, from_index := 0) -> index: int, found: bool {
    index, found := first_index(haystack, needle, from_index, current_compare, current_first_index);
    return index, found;
}

first_index :: inline (haystack: string, needle: string, from_index := 0, compare: Character_Compare) -> index: int, found: bool {
    index, found := first_index(haystack, needle, from_index, compare, current_first_index);
    return index, found;
}


last_index :: inline (haystack: string, needle: u8) -> index: int, found: bool {
    index, found := last_index(haystack, needle, haystack.count, current_compare);
    return index, found;
}

last_index :: inline (haystack: string, needle: [] u8) -> index: int, found: bool {
    index, found := last_index(haystack, needle, haystack.count, current_compare);
    return index, found;
}

last_index :: inline (haystack: string, needle: string) -> index: int, found: bool {
    index, found := last_index(haystack, needle, haystack.count, current_compare, current_last_index);
    return index, found;
}

last_index :: inline (haystack: string, needle: string, compare: Character_Compare) -> index: int, found: bool {
    index, found := last_index(haystack, needle, haystack.count, compare, current_last_index);
    return index, found;
}


last_index :: inline (haystack: string, needle: u8, from_index: int) -> index: int, found: bool {
    index, found := last_index(haystack, needle, from_index, current_compare);
    return index, found;
}

last_index :: inline (haystack: string, needle: [] u8, from_index: int) -> index: int, found: bool {
    index, found := last_index(haystack, needle, from_index, current_compare);
    return index, found;
}

last_index :: inline (haystack: string, needle: string, from_index: int) -> index: int, found: bool {
    index, found := last_index(haystack, needle, from_index, current_compare, current_last_index);
    return index, found;
}

last_index :: inline (haystack: string, needle: string, from_index: int, compare: Character_Compare) -> index: int, found: bool {
    index, found := last_index(haystack, needle, from_index, compare, current_last_index);
    return index, found;
}



is_any :: inline (needle: u8, haystack: [] u8) -> bool {
    return is_any(needle, haystack, current_compare);
}


contains :: inline (haystack: string, needle: u8) -> bool {
    _, found := first_index(haystack, needle);
    return found;
}

contains :: inline (haystack: string, needle: [] u8) -> bool {
    _, found := first_index(haystack, needle);
    return found;
}

contains :: inline (haystack: string, needle: string) -> bool {
    _, found := first_index(haystack, needle);
    return found;
}

contains :: inline (haystack: string, needle: string, compare: Character_Compare) -> bool {
    _, found := first_index(haystack, needle, compare, current_first_index);
    return found;
}

contains :: inline (haystack: string, needle: string, $$index: Index_Proc) -> bool {
    _, __, found := index(haystack, needle, 0, false);
    return found;
}


starts_with :: inline (haystack: string, needle: string) -> bool {
    return starts_with(haystack, needle, current_compare);
}

starts_with :: inline (haystack: string, needle: u8) -> bool {
    return starts_with(haystack, needle, current_compare);
}

starts_with :: inline (haystack: string, needle: [] u8) -> bool {
    return starts_with(haystack, needle, current_compare);
}


ends_with :: inline (haystack: string, needle: string) -> bool {
    return ends_with(haystack, needle, current_compare);
}

ends_with :: inline (haystack: string, needle: u8) -> bool {
    return ends_with(haystack, needle, current_compare);
}

ends_with :: inline (haystack: string, needle: [] u8) -> bool {
    return ends_with(haystack, needle, current_compare);
}


advance_to :: inline (haystack: *string, needle: u8) -> characters_skipped: int {
    return advance_to(haystack, needle, current_compare);
}

advance_to :: inline (haystack: *string, needle: [] u8) -> characters_skipped: int {
    return advance_to(haystack, needle, current_compare);
}

advance_to :: inline (haystack: *string, needle: string) -> characters_skipped: int {
    return advance_to(haystack, needle, current_compare, current_first_index);
}


advance_past :: inline (haystack: *string, needle: u8) -> characters_skipped: int {
    return advance_past(haystack, needle, current_compare);
}

advance_past :: inline (haystack: *string, needle: [] u8) -> characters_skipped: int {
    return advance_past(haystack, needle, current_compare);
}

advance_past :: inline (haystack: *string, needle: string) -> characters_skipped: int {
    return advance_past(haystack, needle, current_compare, current_first_index);
}



trim :: (str: string) -> string {
    low_index := 0;
    high_index := str.count - 1;

    while low_index < str.count && str[low_index] <= Chars.SPACE
        low_index += 1;

    if low_index >= str.count  return "";

    while high_index > low_index && str[high_index] <= Chars.SPACE
        high_index -= 1;

    return unsafe_slice(str, low_index, high_index + 1);
}

trim :: inline (str: string, char : u8) -> string {
    return trim(str, char, current_compare);
}

trim :: inline (str: string, chars : [] u8) -> string {
    #if strict {
        assert(chars.count, "You cannot trim nothing!");
    }

    return trim(str, chars, current_compare);
}

trim :: inline (str: string, string_to_remove: string) -> string {
    #if strict {
        assert(string_to_remove != "", "You cannot trim nothing!");
    }

    return trim(str, string_to_remove, current_compare);
}


trim_to :: inline (str: string, needle: u8) -> string, found: bool {
    result, found := trim_to(str, needle, current_compare);
    return result, found;
}

trim_to :: inline (str: string, needle: [] u8) -> string, found: bool {
    #if strict {
        assert(needle.count, "You cannot trim nothing!");
    }
    result, found := trim_to(str, needle, current_compare);
    return result, found;
}

trim_to :: inline (str: string, needle: string) -> string, found: bool  {
    #if strict {
        assert(needle.count, "You cannot trim nothing!");
    }
    result, found := trim_to(str, needle, current_compare, current_first_index, current_last_index);
    return result, found;
}


trim_past :: inline (str: string, needle: u8) -> string, found: bool {
    result, found := trim_past(str, needle, current_compare);
    return result, found;
}

trim_past :: inline (str: string, needle: [] u8) -> string, found: bool {
    #if strict {
        assert(needle.count, "You cannot trim nothing!");
    }
    result, found := trim_past(str, needle, current_compare);
    return result, found;
}

trim_past :: inline (str: string, needle: string) -> string, found: bool  {
    #if strict {
        assert(needle.count, "You cannot trim nothing!");
    }
    result, found := trim_past(str, needle, current_compare, current_first_index, current_last_index);
    return result, found;
}


trim_start :: (str: string) -> string {
    index := 0;

    while index < str.count && str[index] <= Chars.SPACE
        index += 1;

    if index >= str.count  return "";

    return unsafe_slice(str, index);
}


trim_start :: inline (str: string, char : u8) -> string {
    return trim_start(str, char, current_compare);
}


trim_start :: inline (str: string, chars : [] u8) -> string {
    #if strict {
        assert(chars.count, "You cannot trim nothing!");
    }

    return trim_start(str, chars, current_compare);
}


trim_start :: inline (str: string, string_to_remove: string) -> string {
    #if strict {
        assert(string_to_remove.count, "You cannot trim nothing!");
    }

    return trim_start(str, string_to_remove, current_compare);
}



trim_start_to :: inline (str: string, needle: u8) -> string, found: bool {
    result, found := trim_start_to(str, needle, current_compare);
    return result, found;
}

trim_start_to :: inline (str: string, needle: [] u8) -> string, found: bool  {
    #if strict {
        assert(needle.count, "You cannot trim nothing!");
    }
    result, found := trim_start_to(str, needle, current_compare);
    return result, found;
}

trim_start_to :: inline (str: string, needle: string) -> string, found: bool  {
    #if strict {
        assert(needle.count, "You cannot trim nothing!");
    }
    result, found := trim_start_to(str, needle, current_compare, current_first_index);
    return result, found;
}


trim_start_past :: inline (str: string, needle: u8) -> string, found: bool {
    result, found := trim_start_past(str, needle, current_compare);
    return result, found;
}

trim_start_past :: inline (str: string, needle: [] u8) -> string, found: bool  {
    #if strict {
        assert(needle.count, "You cannot trim nothing!");
    }
    result, found := trim_start_past(str, needle, current_compare);
    return result, found;
}

trim_start_past :: inline (str: string, needle: string) -> string, found: bool  {
    #if strict {
        assert(needle.count, "You cannot trim nothing!");
    }
    result, found := trim_start_past(str, needle, current_compare, current_first_index);
    return result, found;
}


trim_end :: (str: string) -> string {
    index := str.count - 1;

    while index >= 0 && str[index] <= Chars.SPACE
        index -= 1;

    if index < 0  return "";

    return unsafe_slice(str, 0, index + 1);
}


trim_end :: inline (str: string, char : u8) -> string {
    return trim_end(str, char, current_compare);
}


trim_end :: inline (str: string, chars : [] u8) -> string {
    #if strict {
        assert(chars.count, "You cannot trim nothing!");
    }

    return trim_end(str, chars, current_compare);
}


trim_end :: inline (str: string, string_to_remove: string) -> string {
    #if strict {
        assert(string_to_remove.count, "You cannot trim nothing!");
    }

    return trim_end(str, string_to_remove, current_compare);
}




trim_end_after :: inline (str: string, needle: u8) -> string, found: bool {
    result, found := trim_end_after(str, needle, current_compare);
    return result, found;
}

trim_end_after :: inline (str: string, needle: [] u8) -> string, found: bool  {
    #if strict {
        assert(needle.count, "You cannot trim nothing!");
    }
    result, found := trim_end_after(str, needle, current_compare);
    return result, found;
}

trim_end_after :: inline (str: string, needle: string) -> string, found: bool  {
    #if strict {
        assert(needle.count, "You cannot trim nothing!");
    }
    result, found := trim_end_after(str, needle, current_compare, current_last_index);
    return result, found;
}


trim_end_from :: inline (str: string, needle: u8) -> string, found: bool {
    result, found := trim_end_from(str, needle, current_compare);
    return result, found;
}

trim_end_from :: inline (str: string, needle: [] u8) -> string, found: bool  {
    #if strict {
        assert(needle.count, "You cannot trim nothing!");
    }
    result, found := trim_end_from(str, needle, current_compare);
    return result, found;
}

trim_end_from :: inline (str: string, needle: string) -> string, found: bool  {
    #if strict {
        assert(needle.count, "You cannot trim nothing!");
    }
    result, found := trim_end_from(str, needle, current_compare, current_last_index);
    return result, found;
}




replace :: (haystack: string, needle: u8, replacement: u8, max_replacements := 0) -> change_count: int {
    change_count := 0;
    index, found := first_index(haystack, needle);

    while found {
        haystack[index] = replacement;
        change_count += 1;
        if max_replacements > 0 && change_count >= max_replacements  break;
        index, found = first_index(haystack, needle, index + 1);
    }

    return change_count;
}


replace :: (haystack: string, needle: [] u8, replacement: u8, max_replacements := 0) -> change_count: int {
    change_count := 0;
    for 0 .. haystack.count - 1 {
        if is_any(haystack[it], needle) {
            haystack[it] = replacement;
            change_count += 1;
            if max_replacements > 0 && change_count >= max_replacements  break;
        }
    }

    return change_count;
}


replace :: inline (haystack: string, needle: string, replacement: u8, max_replacements := 0) -> change_count: int {
    return replace(haystack, needle, replacement, max_replacements, current_compare);
}


replace :: (haystack: string, needle: string, replacement: u8, max_replacements := 0, compare: Character_Compare) -> change_count: int {
    change_count := 0;
    over_limit := false;
    index, found := first_index(haystack, needle, compare, current_first_index);
    while found && !over_limit {
        for index .. index + needle.count - 1 {
            haystack[it] = replacement;
            change_count += 1;
            if max_replacements > 0 && change_count >= max_replacements {
                over_limit = true;
                break;
            }
        }
        index, found = first_index(haystack, needle, index + needle.count, compare, current_first_index);
    }

    return change_count;
}


replace :: (haystack: string, needle: string, $$index: Index_Proc, replacement: u8, max_replacements := 0) -> change_count: int {
    change_count := 0;
    over_limit := false;
    from_index, to_index, found := index(haystack, needle, 0, false);
    while found && !over_limit {
        for from_index .. to_index - 1 {
            haystack[it] = replacement;
            change_count += 1;
            if max_replacements > 0 && change_count >= max_replacements {
                over_limit = true;
                break;
            }
        }
        from_index, to_index, found = index(haystack, needle, to_index, false);
    }

    return change_count;
}



count :: inline (haystack: string, needle: u8) -> total: int {
    return count(haystack, needle, current_compare);
}


count :: inline (haystack: string, needle: [] u8) -> total: int {
    return count(haystack, needle, current_compare);
}

count :: (haystack: string, needle: [] u8, compare: Character_Compare) -> total: int {
    if haystack == ""  return 0;

    total := 0;
    for needle  total += count(haystack, it, compare);
    return total;
}


count :: inline (haystack: string, needle: string) -> total: int {
    return count(haystack, needle, current_compare);
}

count :: (haystack: string, needle: string, compare: Character_Compare) -> total: int {
    if needle == ""  return 0;

    total := 0;
    index, found := first_index(haystack, needle, compare, current_first_index);
    while found {
        total += 1;
        index, found = first_index(haystack, needle, index + needle.count, compare, current_first_index);
    }

    return total;
}


count :: (haystack: string, needle: string, $$index: Index_Proc) -> total: int {
    total := 0;
    from_index, to_index, found := index(haystack, needle, 0, false);
    while found {
        total += 1;
        from_index, to_index, found = index(haystack, needle, to_index, false);
    }

    return total;
}


split_into_two :: inline (text: string, separator: u8) -> string, string {
    index, found := first_index(text, separator);
    if !found  return text, "";
    return unsafe_slice(text, 0, index), unsafe_slice(text, index + 1);
}

split_into_two :: inline (text: string, separator: [] u8) -> string, string {
    index, found := first_index(text, separator);
    if !found  return text, "";
    return unsafe_slice(text, 0, index), unsafe_slice(text, index + 1);
}

split_into_two :: inline (text: string, separator: string) -> string, string {
    index, found := first_index(text, separator);
    if !found  return text, "";
    return unsafe_slice(text, 0, index), unsafe_slice(text, index + separator.count);
}

split_into_two :: inline (text: string, $$separator: Index_Proc) -> string, string {
    from_index, found, to_index := first_index(text, separator);
    if !found  return text, "";
    return unsafe_slice(text, 0, from_index), unsafe_slice(text, to_index);
}


split_into_three :: inline (text: string, separator: u8) -> string, string, string {
    index, found := first_index(text, separator);
    if !found  return text, "", "";

    second, third := split_into_two(unsafe_slice(text, index + 1), separator);
    return unsafe_slice(text, 0, index), second, third;
}

split_into_three :: inline (text: string, separator: [] u8) -> string, string, string {
    index, found := first_index(text, separator);
    if !found  return text, "", "";

    second, third := split_into_two(unsafe_slice(text, index + 1), separator);
    return unsafe_slice(text, 0, index), second, third;
}

split_into_three :: inline (text: string, separator: string) -> string, string, string {
    index, found := first_index(text, separator);
    if !found  return text, "", "";

    second, third := split_into_two(unsafe_slice(text, index + separator.count), separator);
    return unsafe_slice(text, 0, index), second, third;
}

split_into_three :: inline (text: string, $$separator: Index_Proc) -> string, string, string {
    from_index, found, to_index := first_index(text, separator);
    if !found  return text, "", "";

    second, third := split_into_two(unsafe_slice(text, to_index), separator);
    return unsafe_slice(text, 0, from_index), second, third;
}


split_into_three :: inline (text: string, first_separator: u8, second_separator: $T) -> string, string, string {
    index, found := first_index(text, first_separator);
    if !found  return text, "", "";

    second, third := split_into_two(unsafe_slice(text, index + 1), second_separator);
    return unsafe_slice(text, 0, index), second, third;
}

split_into_three :: inline (text: string, first_separator: [] u8, second_separator: $T) -> string, string, string {
    index, found := first_index(text, first_separator);
    if !found  return text, "", "";

    second, third := split_into_two(unsafe_slice(text, index + 1), second_separator);
    return unsafe_slice(text, 0, index), second, third;
}

split_into_three :: inline (text: string, first_separator: string, second_separator: $T) -> string, string, string {
    index, found := first_index(text, first_separator);
    if !found  return text, "", "";

    second, third := split_into_two(unsafe_slice(text, index + separator.count), second_separator);
    return unsafe_slice(text, 0, index), second, third;
}

split_into_three :: inline (text: string, $$first_separator: Index_Proc, second_separator: $T) -> string, string, string {
    from_index, found, to_index := first_index(text, first_separator);
    if !found  return text, "", "";

    second, third := split_into_two(unsafe_slice(text, to_index), second_separator);
    return unsafe_slice(text, 0, from_index), second, third;
}


split_into :: (array: *[$N] string, text: string, separator: $T, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO, compare: Character_Compare) -> count: int #expand {
    count : int;
    mr := ifx max_results <= 0 || max_results > N then N else max_results;
    for split(text, separator, max_results = mr, skip_empty = skip_empty, keep_separator = keep_separator, compare = compare) {
        (<<array)[it_index] = it;
        count = it_index;
    }
    count += 1;
    for count .. N - 1 {
        (<<array)[it] = "";
    }
    return count;
}

split_into :: (array: *[$N] string, text: string, separator: $T, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> count: int #expand {
    return split_into(array, text, separator, max_results, skip_empty, keep_separator, current_compare);
}


split :: inline (text: string, separator: string, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO, compare: Character_Compare) -> Split_By_String {
    return make_split(text, separator, compare, current_first_index, current_last_index, max_results, skip_empty, keep_separator);
}

split :: inline (text: string, separator: string, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> Split_By_String {
    return make_split(text, separator, current_compare, current_first_index, current_last_index, max_results, skip_empty, keep_separator);
}


split :: inline (text: string, separator: [] u8, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO, compare: Character_Compare) -> Split_By_Chars {
    #if strict {
        assert(indexes.count > 0, "Cannot split with empty array!");
    }
    return make_split(text, separator, compare, max_results, skip_empty, keep_separator);
}

split :: inline (text: string, separator: [] u8, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> Split_By_Chars {
    #if strict {
        assert(indexes.count > 0, "Cannot split with empty array!");
    }
    return make_split(text, separator, current_compare, max_results, skip_empty, keep_separator);
}


split :: inline (text: string, separator: u8, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO, compare: Character_Compare) -> Split_By_Char {
    return make_split(text, separator, compare, max_results, skip_empty, keep_separator);
}

split :: inline (text: string, separator: u8, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> Split_By_Char {
    return make_split(text, separator, current_compare, max_results, skip_empty, keep_separator);
}


index_split :: inline (text: string, indexes: .. int, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> Split_By_Index {
    #if strict {
        assert(indexes.count > 0, "Cannot split with no indexes!");
        prev := indexes[0];
        for indexes {
            normalized, valid := slice_index(text, it);
            assert(valid, "Invalid split index: % = %", it, normalized);
            assert(normalized >= prev, "Cannot split with decreasing index! %->%", prev, it);
            prev = normalized;
        }
    }
    return make_split(text, indexes, max_results, skip_empty);
}


split :: inline (text: string, separator: string, $$index: Index_Proc, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> Split_By_Proc {
    return make_split(text, separator, index, max_results, skip_empty, keep_separator);
}


line_split :: inline (text: string, max_results := 0, skip_empty := false, keep_separator := Keep_Separator.NO) -> Split_By_Line {
    return make_line_split(text,max_results, skip_empty, keep_separator);
}
