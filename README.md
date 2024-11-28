# jai-string

Modules present:

* `Strings` Fairly performant and well reasoned api for working with strings.
* `Scratch` A simple allocator for doing multiple operations in a row without grabbing more memory on each one. [Info](Scratch/module.jai)

To use clone the repo then copy the `Strings` folder into your `jai/modules` folder, or symlink them: `mklink /d c:\jai\modules\Strings c:\repos\jai-string\Strings`
Optionally do the same for the `Scratch` folder if you want to have access to the scratch allocator.


## Mechanics

### Mutating in-place vs returning result

Any proc in this module which writes to the string's data will have a pointer to the string as its parameter instead of just a string.  This gives a clear indicator of intent, and also delineates between different versions of a proc.  For example:
```jai
bar := to_upper(foo); // returns a copy of foo converted to uppercase (allocates!)
to_upper(*foo);       // mutates foo in-place, converting it to uppercase.
```

### Generating strings

Any proc which generates (allocates) a string will take an optional `null_terminate` parameter; setting this to true ensures the resulting string ends in `\0`.


### Character Comparison

By default characters being compared between two strings are compared using the `case_sensitive` function (unless you override it with the module parameter).  In this library any procedure which involves comparing strings will take a `character_compare` parameter in which you can specify a different procedure from the default.  For example:

```jai
    assert( contains("Hello", "h")              == false );
    assert( contains("Hello", "h", ignore_case) == true  );
```

The comparator is a struct; you can make your own like this:

```jai
are_numbers :: Character_Compare.{
    .CUSTOM,
    (a: u8, b: u8) -> bool {
        return (a >= #char "0" && a <= #char "9")
            == (b >= #char "0" && b <= #char "9");
    }
};

share_case :: Character_Compare.{
    .CUSTOM,
    (a: u8, b: u8) -> bool {
        a_is_alpha := is_alpha(a);
        if a_is_alpha != is_alpha(b)  return false;
        if !a_is_alpha  return true;
        return is_upper(a) == is_upper(b);
    }
};
```

The two comparators built-in to the module are `case_sensitive`, `ignore_case`.

*(The other two options to `.CUSTOM` are `.CASE_SENSITIVE` and `.IGNORE_CASE`: you may roll your own versions of those comparators if you wish, and by choosing the relevant identifier the correct SIMD optimisations will be invoked - however, there's not a lot of point in doing so...)*


### Tool types: u8 / [] u8 / string / Index_Proc

In a string library it is often the case that you have a string which you are applying an operation to using a *tool* parameter.  In this library there will generally be four version of such procedures, the first three of which are the single parameters: `u8`, `[] u8`, `string`.  As tools these types behave consistently across the library:

* `u8`<br>
The single character specified will be used.

* `[] u8`<br>
A match to any of the characters in the array will be used.

* `string`<br>
The exact string will be used: i.e. the characters specified in the sequence specified.


For example:
```jai
    assert( trim( " apple  ",    #char " "        )  == "apple"  );
    assert( trim( "banana pear", cast([]u8) "ban" )  == " pear" );
    assert( trim( "banana pear", "ban"            )  == "ana pear" );
```

Additionally, any time the tool is a `string` you may specify an `Index_Proc`.  An `Index_Proc` is a procedure with the signature:

`(haystack: string, needle: string, initial_index: int, reversed: bool) -> from_index: int, to_index: int, found: bool`

This allows you to feed an arbitrarily complex pattern match into the procedure you are using.  When using an `Index_Proc`, a character comparator is not used (as your own code is instead).

For example:
```jai
    question_mark_index :: (haystack: string, needle: string, initial_index: int, $$reversed: bool) -> from_index: int, to_index: int, found: bool {
        if reversed {
            from_index, to_index, found := reverse_index_proc(question_mark_index, haystack, needle, initial_index);
            return from_index, to_index, found;
        }
        else {
            index := slice_index(haystack, initial_index);
            if index >= haystack.count  return -1, -1, false;

            for haystack_index: index .. haystack.count - needle.count {
                for needle_index: 0 .. needle.count - 1 {
                    c := needle[needle_index];
                    if c != #char "?" && c != haystack[haystack_index + needle_index]
                        continue haystack_index;
                }

                return haystack_index, haystack_index + needle.count, true;
            }

            return -1, -1, false;
        }
    }

    assert( starts_with("Hello World", "He??o")                      == false );
    assert( starts_with("Hello World", "He??o", question_mark_index) == true );
```

Notice the use of `reverse_index_proc` to handle when the `reversed` parameter is set.  This is a library procedure that you can use if you don't want to write out the reverse algorithm yourself, but note that it is extremely inefficient!

In the docs below, any time a parameter of type `%Tool` is specified, it means there are four versions of the procedure, each corresponding to the behaviour described above (the fourth being that the %Tool is two parameters: `string`+`Index_Proc`).

<hr>

### `#module_parameters`

* `CHARACTER_COMPARE`<br>Default comparator used to check if two string characters are equal.  One of:
    * `.CASE_SENSITIVE`
    * `.IGNORE_CASE`

* `INDEX_ALGORITHM`<br>Determines the default string search algorithm to use (they can be changed later using `set_index_algorithm`).  One of:
    * `.SIMPLE`, `.SIMPLE_SSE2`, `.SIMPLE_AVX2`, `.SIMPLE_UNSAFE`<br>Simplest algorithm, no memory overhead.
    * `.BOYER_MOORE`, `.BOYER_MOORE_SSE2`, `.BOYER_MOORE_AVX2`<br>[Boyer-Moore algorithm](https://en.wikipedia.org/wiki/Boyer%E2%80%93Moore_string-search_algorithm).  Fastest tested scalar algorithm overall, has a small memory footprint that increases with needle size.
    * `.KNUTH_MORRIS_PRATT`<br>[Knuth-Morris-Pratt algorithm](https://en.wikipedia.org/wiki/Knuth%E2%80%93Morris%E2%80%93Pratt_algorithm). Another fast algorithm, with a similar memory footprint.

#### A note on indexing algorithms

The indexing algorithm set by `set_index_algorithm` is used internally in the module for most operations: any time you call things like `first_index`, `replace`, `split` it will be employed.
Whereas other functions in the library will utilize SIMD features (SSE2 & AVX2) when told to with the `set_simd_mode` command, you must explicitly set an index algorithm to use them if that is what you wish<sup>*</sup>:  the default indexing algorithm is scalar `Boyer-Moore`, because it is good on practically any dataset; a safe choice.  Choosing a different indexing algorithm can provide impressive performance improvements, but this depends on the dataset you are working on (the specific strings and substrings you are searching with).  SIMD algorithms can be orders of magnitude faster, but they can also be catastrophically slow when facing degenerate datasets.  If you want to get the most performance out of the library then you should choose an appropriate indexing algorithm for your dataset.

To help with this there is the `index_profile` tool (in the `tools/` folder): provide it with a file and a typical search string from your data and it will show you how each available algorithm performs with the data you are manipulating.

<sup>*</sup> *(Though all the built-in indexing algorithms will detect if the needle is a single character long, and if so will use the relevant built-in character index algorithm, which will obey `set_simd_mode`)*


### Procedures


#### Configuration


* `set_index_algorithm (first_index_proc := default_first_index, last_index_proc := default_last_index)`<br>
Sets the index procedures used internally when searching through strings with strings (for `replace`, `split`, etc.)


* `set_simd_mode (mode)`<br>Sets whether to use SIMD optimisations.  One of:
    * `.OFF`<br>Disables all SIMD optimisations, utilizing scalar code only.
    * `.AUTO`<br>Uses the fastest SIMD instruction set available on the CPU.
    * `.SSE2`<br>Uses SSE2 (128bit) optimisations.  This is the default.
    * `.AVX2`<br>Uses AVX2 (256bit) optimisations.


#### Substrings


* `slice (str: string, from_index: int, [to_index: int]) -> string, normalized_from_index: int, normalized_to_index: int`<br>
Returns the string inside `str`, between the specified indices.  You may use a negative index to specify backwards from the end of the string.  If you do not specify a `to_index` then it will include all characters up to the end of the string.  The last two return parameters are the positive indexes the slice ends up using, after validation.


* `substring (str: string, from_index: int, [count: int]) -> string, normalized_from_index: int, normalized_to_index: int`<br>
Same as `slice`, except instead of a `to_index` you specify a character count.  If you do not specify a `count` then it will include all characters up to the end of the string.


* `slice_index (str: string, index: int) -> normalized_index: int, well_formed: bool`<br>
Returns the validated and normalized index which would be used with the provided string, as well as whether the index was within the bounds of the string.


* `raw_slice (str: string, from_index: int, to_index: int) -> string`<br>
As `slice`, but without any checking on the indices, and without being able to use negative indices (and thus faster).  If you do not specify a `to_index` then it will include all characters up to the end of the string.  Generally speaking, just use `slice` instead.


* `raw_substring (str: string, from_index: int, count: int) -> string`<br>
As `substring`, but without any checking on the indices, and without being able to use negative indices (and thus faster).  If you do not specify a `count` then it will include all characters up to the end of the string.  Generally speaking, just use `substring` instead.


* `trim (str: string) -> string`<br>
Returns the substring of `str` with all characters from the start and end which are <= `#char " "` removed (i.e. all whitespace and control codes).


* `trim (str: string, tool: %Tool, character_compare := default_compare) -> string`<br>
Returns the substring of `str` with all characters matching tool removed from the start and end.


* `trim_start (str: string, tool: %Tool, character_compare := default_compare) -> string`<br>
Returns the substring of `str` with all characters matching tool removed from the start.


* `trim_end (str: string, tool: %Tool, character_compare := default_compare) -> string, found: bool`<br>
Returns the substring of `str` with all characters matching tool removed from the end.


* `trim_to (str: string, tool: %Tool, character_compare := default_compare) -> string, found: bool`<br>
Returns the substring of `str` with all characters before the first instance and after the last instance of tool removed.  If tool is not found then the entire string is returned.


* `trim_start_to (str: string, tool: %Tool, character_compare := default_compare) -> string, found: bool`<br>
Returns the substring of `str` with all characters before the first instance of tool removed from the start.  If tool is not found then the entire string is returned.


* `trim_end_to (str: string, tool: %Tool, character_compare := default_compare) -> string, found: bool`<br>
Returns the substring of `str` with all characters after the last instance of tool removed from the end.  If tool is not found then the entire string is returned.


* `trim_through (str: string, tool: %Tool, character_compare := default_compare) -> string, found: bool`<br>
Returns the substring of `str` with all characters before the first instance and after the last instance of tool, as well as the tool itself, removed.  If tool is not found then the entire string is returned.


* `trim_start_through (str: string, tool: %Tool, character_compare := default_compare) -> string, found: bool`<br>
Returns the substring of `str` with all characters before the first instance of tool, and the tool, removed from the start.  If tool is not found then the entire string is returned.


* `trim_end_through (str: string, tool: %Tool, character_compare := default_compare) -> string, found: bool`<br>
Returns the substring of `str` with all characters after the last instance of tool, and the tool, removed from the end.  If tool is not found then the entire string is returned.


#### Consuming


* `advance_to (haystack: *string, needle: %Tool) -> characters_skipped: int, found: bool`<br>
Modifies `haystack` in-place, moving its start point forward until it hits `%Tool` (or empties).


* `advance_through (haystack: *string, needle: %Tool) -> characters_skipped: int, found: bool`<br>
Modifies `haystack` in-place, moving its start point forward until it hits and reaches the end of `%Tool` (or empties).


#### Splitting


All split procedures return an iterator (a for-expansion).  If you want the substrings to be in an array you can feed this iterator into `to_array` or `into_array`.


* `split (text: string, separator: %Tool, skip_empty := false, max_results := 0, keep_separator := .NO, character_compare := default_compare)`<br>
Used to iterate over `text` in a `for` loop, splitting the string by the chosen tool.
If `skip_empty` is set then your code will not be called with the empty string (i.e. when there are two consecutive `seperator`s).
If `max_results` is non-zero then `text` will only be split into at most that
many pieces.
If `keep_separator` is set to `.AS_PREFIX` or `.AS_POSTFIX` then the separator will be included in the strings, at the specified position.

For example:
```jai
    for word, index: split(" aa  bb  cc dd  ", #char " ", skip_empty = true, max_results = 3) {
        if index == {
            case  0; assert(word == "aa");
            case  1; assert(word == "bb");
            case  2; assert(word == "cc");
            case  3; assert(false);
        }
    }

    for word, index: split("Hello, World.", ", ", keep_separator = .AS_POSTFIX) {
        if index == {
            case  0; assert(word == "Hello, ");
            case  1; assert(word == "World.");
            case  2; assert(false);
        }
    }
```


* `split_into_two (text: string, separator: %Tool, keep_separator := .NO, character_compare := default_compare) -> string, string`<br>
As split with max_results set to 2, but returns the two strings directly rather than an iterator.


* `to_array (splitter: $T/Splitter, reversed := false) -> [..] string`<br>
Executes the splitter, generating an array.
```jai
splitter := split("How about a nice game of chess?", #char " ");
words := to_array(splitter,, temp);
assert(words.count == 7);
```


* `into_array (array: *[] string, splitter: $T/Splitter, reversed := false, clear_unused := true) -> [] string`<br>
Executes the splitter and places its results into the array.  Returns an array_view over the array with the used count.
If `clear_unused` is set then any trailing slots in the array after the resulting count will be cleared.
```jai
parts : [20] string;
view := split(*parts, "How about a nice game of chess?", #char " ");
assert(view.count == 7);
```


* `count_split (text: string, count: int, max_results := 0)`<br>
As `split`, except the string is split into sections with the specified `count`.


* `index_split (text: string, indexes: .. int, skip_empty := false, max_results := 0)`<br>
As `split`, except the string is split at the specified indices.


* `line_split (text: string, keep_end := false, skip_empty := false, max_results := 0, keep_separator := .NO)`<br>
As `split` using `#char "\n"` as the tool, but will automatically handle windows vs unix file formats (i.e. will take care of `"\r\n"`).


#### Querying


* `first_index (haystack: string, needle: %Tool, start_index := 0, character_compare := default_compare) -> index: int, found: bool, [to_index: int]`<br>
Returns the first index in `haystack` at which `needle` occurs, or `-1` if it does not occur.  `found` will be true if `needle` was found.  In the case when `%Tool` is an `Index_Proc`, `to_index` will be set to the index the pattern terminates at.


* `last_index (haystack: string, needle: %Tool, start_index := 0, character_compare := default_compare) -> index: int, found: bool, [to_index: int]`<br>
As per `first_index`, but working backwards from the end of the `haystack`.


* `contains (haystack: string, needle: %Tool, character_compare := default_compare) -> bool`<br>
Whether `needle` occurs within `haystack`.


* `count (haystack: string, needle: %Tool, character_compare := default_compare) -> int`<br>
How many times `needle` occurs within `haystack` (non-overlapping).


* `equal (a: string, b: string, character_compare := default_compare) -> bool`<br>
Returns whether the two strings are equal, using current or specified comparator.


* `is_any (needle: u8, characters: [] u8, character_compare := default_compare) -> bool`<br>
Returns whether `needle` is equal to any of `characters`.


* `is_lower (char: u8) -> bool`<br>
Whether `char` falls in the range `#char "a" - #char "z"`.


* `is_upper (char: u8) -> bool`<br>
Whether `char` falls in the range `#char "A" - #char "Z"`.


* `starts_with (haystack: string, needle: %Tool, character_compare := default_compare) -> bool`<br>
Returns whether `haystack` begins with `needle`.


* `ends_with (haystack: string, needle: %Tool, character_compare := default_compare) -> bool`<br>
Returns whether `haystack` ends with `needle`.


#### Mutating


* `pad_start (str: string, desired_count: int, pad_with := " ", null_terminate := false) -> string`<br>
Returns a copy of `str` with `pad_with` repeated at the beginning such that the string length reaches the `desired_count`.
Note that `pad_with` can be multiple characters long (and in fact the default value is actually multiple spaces, for performance).


* `pad_start (str: string, desired_count: int, pad_with: u8, null_terminate := false) -> string`<br>
Returns a copy of `str` with `pad_with` repeated at the beginning such that the string length reaches the `desired_count`.


* `pad_end (str: string, desired_count: int, pad_with := " ", null_terminate := false) -> string`<br>
Returns a copy of `str` with `pad_with` repeated from the end such that the string length reaches the `desired_count`.
Note that `pad_with` can be multiple characters long (and in fact the default value is actually multiple spaces, for performance).


* `pad_end (str: string, desired_count: int, pad_with: u8, null_terminate := false) -> string`<br>
Returns a copy of `str` with `pad_with` repeated from the end such that the string length reaches the `desired_count`.


* `pad (str: string, desired_count: int, pad_with := " ", null_terminate := false) -> string`<br>
Returns a copy of `str` with `pad_with` repeated from the begining *and* from the end such that the string length reaches the `desired_count`.
Note that `pad_with` can be multiple characters long (and in fact the default value is actually multiple spaces, for performance).


* `pad (str: string, desired_count: int, pad_with: u8, null_terminate := false) -> string`<br>
Returns a copy of `str` with `pad_with` repeated from the begining *and* from the end such that the string length reaches the `desired_count`.


* `repeat (str: string, times: int, null_terminate := false) -> string`<br>
Returns a string consisting of `str` repeated `times` times.


* `replace (haystack: *string, needle: %Tool, replacement: u8, max_replacements := 0, null_terminate := false) -> change_count: int`<br>
Mutates the haystack in-place, replacing `needle` with the `replacement` character specified.


* `replace (haystack: string, needle: %Tool, replacement: string,  max_replacements := 0, character_compare := default_compare, null_terminate := false) -> string`<br>
Returns a copy of `str` with all (non-overlapping) instances of `needle` replaced with `replacement`.
If `max_replacements` is non-zero then at most that many replacements will be made (starting at the beginning of the string).


* `reverse (str: *string)`<br>
Reverses the characters in `str` in-place.


* `reverse (str: string, null_terminate := false) -> string`<br>
Returns a copy of `str` with the characters in the reverse order.


* `to_upper (str: *string)`<br>
Mutates `str` in-place, overwritting any lower-case characters with their upper-case equivalent.


* `to_upper (str: string, null_terminate := false)`<br>
Returns a copy of `str` with all lower-case characters converted to their upper-case equivalent.


* `to_lower (str: *string)`<br>
Mutates `str` in-place, overwritting any upper-case characters with their lower-case equivalent.


* `to_lower (str: string, null_terminate := false) -> string`<br>
Returns a copy of `str` with all upper-case characters converted to their lower-case equivalent.


* `to_capitalized (str: *string, preserve_caps := true)`<br>
Sets the first letter of `str` to upper-case.  If `preserve_caps` is set to false, will set all following letters to lower-case.


* `to_capitalized (str: string, preserve_caps := true, null_terminate := false) -> string`<br>
Returns a copy of `str` with the first letter converted to upper-case.  If `preserve_caps` is disabled then all subsequent letters will be converted to lower-case.


* `camel_from_snake (str: string, preserve_caps := false, null_terminate := false) -> string`<br>
Returns a copy of underscore-separated `str`, changed into programmer CamelCase; i.e. with the leading letter, and every letter after an underscore, converted to upper-case, and with underscores removed.  If `preserve_caps` is enabled then the the underscore removal still happens, but the case is kept.

For example:
```jai
    assert( camel_from_snake("play_RTS")       == "playRts" );
    assert( camel_from_snake("play_RTS", true) == "playRTS" );
```


* `snake_from_camel (str: string, preserve_caps := false, null_terminate := false) -> string`<br>
Returns a copy of CamelCased `str`, changed into programmer snake case; i.e. converted to lower-case, but split by `_` at each formerly upper-case letter edge.  If `preserve_caps` is enabled then the the split still happens, but the case is kept.

For example:
```jai
    assert( snake_from_camel("PlayRTS")       == "play_rts" );
    assert( snake_from_camel("PlayRTS", true) == "play_RTS" );
```


#### Utilities


* `char_as_string (char: *u8) -> string`<br>
Returns a string representation of the single character provided.


* `copy_string (str: string, null_terminate: bool) -> string`<br>
Returns of a copy of `str`.


* `join (strings: .. string, null_terminate := false) -> string`<br>
Returns a single string created by concatenating all the provided strings together.


* `join (strings: [] string, null_terminate := false) -> string`<br>
Returns a single string, the result of joining all the strings in the `strings` array together.


* `join (strings: [] string, separator: string|u8, null_terminate := false) -> string`<br>
Returns a single string, the result of joining all the strings in the `strings` array together with `separator` between them.


* `join (strings: $T/Splitter, null_terminate := false) -> string`<br>
Returns a single string, the result of joining all the strings in the `strings` iterator together.


* `join (strings: $T/Splitter, separator: string|u8, null_terminate := false) -> string`<br>
Returns a single string, the result of joining all the strings in the `strings` iterator together with `separator` between them.


* `apply_backslash (str: string, null_terminate := false) -> string, well_formed: bool`<br>
Converts legal jai backslash escape sequences (i.e. `\n`, `\t`, etc) into their specified character. i.e. a two character string `"\n"` will yield a single character string with byte value `10`;
`well_formed` will be true if all backslash characters in `str` are followed by an appropriate escape sequence.


* `escape (str: string, null_terminate := false) -> string`<br>
Replaces the special characters which jai uses backslash escapes to represent with said backslash escape sequence. i.e. the single character string with byte value `10` will yield the two character string `"\n"`


* `reverse_index_proc (index_proc: Index_Proc, haystack: string, needle: string, boundary_index: int) -> from_index: int, to_index: int, found: bool`<br>
Can be used to automatically make a reversed version of an `Index_Proc` (see `question_mark_index` example above).  It does so in an extremely inefficient way; if you care about the performance of the reverse search then you should code it directly.
