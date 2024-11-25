# jai-string

String modules for Jai

* `Strings` provides procs which mutate strings in place or return information or string-views.
* `Strings_Alloc` provides procs which return allocated data.
* `Scratch` provides a simple allocator for doing multiple operations in a row without grabbing more memory on each one. [Info](Scratch/module.jai)

For example, you could import and use them like this:

```jai
#import "Strings";
heap_strings :: #import "Strings_Alloc";
scratch_strings :: #import "Strings_Alloc"(scratch_allocator);
temp_strings :: #import "Strings_Alloc"(temp);
#import "Scratch";

main :: () {
    trimmed := trim("  Some test string  ");  // in Strings, does not allocate

    words := temp_strings.split(trimmed, #char " "); // allocated in temporary storage

    banner := heap_strings.join(words, #char "\n"); // allocated with default allocator
}
```

To use clone the repo then copy the `Strings`, `Strings_Alloc` and `Strings_Shared` folders into your `jai/modules` folder, or symlink them: `mklink /d c:\jai\modules\Strings c:\repos\jai-string\Strings`
Optionally do the same for the `Scratch` folder if you want to have access to the scratch allocator.


## Mechanics


### Character Comparison

By default characters being compared between two strings are compared using the `case_sensitive` function (unless you override it with the module parameter).  In this library, any procedure which involves comparing strings will take a `compare` parameter in which you can specify a different procedure from the default.  For example:

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
        if is_alpha(a)
            return is_alpha(b) && is_upper(a) == is_upper(b);
        else
            return !is_alpha(b);
    }
};
```

The two comparators built-in to the module are `case_sensitive`, `ignore_case`.

*(The other two options to `.CUSTOM` are `.CASE_SENSITIVE` and `.IGNORE_CASE`: you may roll your own versions of those comparators if you wish, and by choosing the relevant identifier the correct SIMD optimisations will be invoked - however, there's not a lot of point in doing so...)*


### Tool types: u8 / [] u8 / string / Index_Proc

In a string library it is often the case that you have a string which you are applying an operation to using a *tool* parameter.  In this library there will generally be four version of such procedures, a version each for when the tool is: `u8`, `[] u8`, `string`.  As tools these types behave consistently across the library.  The first three are simple, built-in types, and work like this:

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

`(haystack: string, needle: string, boundary_index: int, reverse: bool) -> from_index: int, to_index: int, found: bool`

This allows you to feed an arbitrarily complex pattern match into the procedure you are using.  When using an `Index_Proc`, a character comparator is not used (as your own code is instead).

For example:
```jai
    question_mark_index :: (haystack: string, needle: string, boundary_index: int, $$reverse: bool) -> from_index: int, to_index: int, found: bool {
        if reverse {
            from_index, to_index, found := reverse_index_proc(question_mark_index, haystack, needle, boundary_index);
            return from_index, to_index, found;
        }
        else {
            index := slice_index(haystack, boundary_index);
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

    assert( starts_with("Hello World", "He??o", question_mark_index) == true );
```

Notice the use of `reverse_index_proc` to handle when the `reverse` parameter is set.  This is a library procedure that you can use if you don't want to write out the reverse algorithm yourself, but note that it is extremely inefficient!

In the docs below, any time a type of `%Tool` is specified, it means there are four versions of the procedure, each corresponding to the behaviour described above (the fourth being `string`+`Index_Proc`).


### Threading

By default the library will support up to 16 threads.  If you want more then you need to set the `Strings_Shared` program parameter `max_thread_count`.

i.e. before importing any other of these modules, do:

```jai
strings_shared :: #import "Strings_Shared"()(max_thread_count=32);
```

<hr>

## Strings

This module provides procedures which predominantly interact with string views; i.e. the jai `string` type.  None of the procedures in this module allocate: to generate new strings from old ones see the `Strings_Alloc` module below.


### `#module_parameters`

* `compare`<br>Default comparator used to check if two string characters are equal.  You may change it using `set_default_compare`.  One of:
    * `.CASE_SENSITIVE`
    * `.IGNORE_CASE`

* `index_algorithm`<br>Determines the default string search algorithm to use, can be changed later using `set_index_algorithm`.  One of:
    * `.SIMPLE`, `.SIMPLE_SSE2`, `.SIMPLE_AVX2`, `.SIMPLE_UNSAFE`<br>Simplest algorithm, no memory overhead.
    * `.BOYER_MOORE`, `.BOYER_MOORE_SSE2`, `.BOYER_MOORE_AVX2`<br>[Boyer-Moore algorithm](https://en.wikipedia.org/wiki/Boyer%E2%80%93Moore_string-search_algorithm).  Fastest tested scalar algorithm overall, has a small memory footprint that increases with needle size.
    * `.KNUTH_MORRIS_PRATT`<br>[Knuth-Morris-Pratt algorithm](https://en.wikipedia.org/wiki/Knuth%E2%80%93Morris%E2%80%93Pratt_algorithm). Another fast algorithm, with a similar memory footprint.

* `strict`<br>By default the module will be fairly permissive of inputs, doing the Right Thing without error for odd values (indices outwith the string for instance).  Setting `strict` to true will make the module behave more stringently, erroring on such inputs.


#### A note on indexing algorithms

Whereas other functions in the library will utilize SIMD features (SSE2 & AVX2) when told to with the `set_simd_mode` command, you must explicitly set an index algorithm to use them if that is what you wish`*`:  the default indexing algorithm is scalar `Boyer-Moore`, because it is good on practically any dataset; a safe choice.  Choosing a different indexing algorithm can provide impressive performance improvements, but this depends on the dataset you are working on (the specific strings and substrings you are searching with).  SIMD algorithms can be orders of magnitude faster, but they can also be catastrophically slow when facing degenerate datasets.  If you want to get the most performance out of the library then you should choose an appropriate indexing algorithm for your dataset.

To help with this there is the `index_profile.exe` tool (in the `tools/` folder): provide it with a file and a typical search string from your data and it will show you how each available algorithm performs with the data you are manipulating.

`*` *(Though all the built-in indexing algorithms will detect if the needle is a single character long, and if so will use the relevant built-in character index algorithm, which will obey `set_simd_mode`)*


### Procedures

* `set_default_compare (character_compare := default_compare)`<br>
Sets the compartor used to check if two characters match.

* `set_index_algorithm (first_index_proc := default_first_index, last_index_proc := default_last_index)`<br>
Sets the index procedures used internally when searching through strings with strings (for `replace`, `split`, etc.)

* `set_simd_mode (mode)`<br>Sets whether to use SIMD optimisations.  One of:
    * `.OFF`<br>Disables all SIMD optimisations, utilizing scalar code only.
    * `.AUTO`<br>Uses the fastest SIMD instruction set available on the CPU.
    * `.SSE2`<br>Uses SSE2 (128bit) optimisations.  This is the default.
    * `.AVX2`<br>Uses AVX2 (256bit) optimisations.


* `char_as_string (char: *u8) -> string`<br>
Returns a string view on the single character specified.


* `reverse_index_proc (index_proc: Index_Proc, haystack: string, needle: string, boundary_index: int) -> from_index: int, to_index: int, found: bool`<br>
Can be used to automatically make a reversed version of an `Index_Proc` (see `question_mark_index` example above).  It does so in an extremely inefficient way; if you care about the performance of the reverse search then you should code it directly.


* `slice (str: string, from_index: int, to_index: int) -> string, normalized_from_index: int, normalized_to_index: int`<br>
Returns a string view inside `str`, between the specified indices.  You may use a negative index to specify backwards from the end of the string.  If you do not specify a `to_index` then it will include all characters up to the end of the string.  The last two return parameters are the positive indexes the slice ends up using, after validation.

* `slice_index (str: string, index: int) -> normalized_index: int, valid_when_strict: bool`<br>
Returns the validated and normalized index which would be used with the provided string, as well as whether such an input would be valid in `strict` mode.

* `raw_slice (str: string, from_index: int, to_index: int) -> string`<br>
Same thing as `slice`, but without any checking on the indices, and without being able to use negative indices (and thus faster).  If you do not specify a `to_index` then it will include all characters up to the end of the string.

* `substring (str: string, from_index: int, count: int) -> string`<br>
Same as `slice`, except instead of a `to_index` you specify a character count.  If you do not specify a `count` then it will include all characters up to the end of the string.


* `trim (str: string) -> string`<br>
Returns the string view of `str` with all characters from the start and end which are <= `#char " "` removed (i.e. all whitespace and control codes).

* `trim (str: string, tool: %Tool, compare := default_compare) -> string`<br>
Returns the string view of `str` with all characters matching tool removed from the start and end.

* `trim_to (str: string, tool: %Tool, compare := default_compare) -> string, found: bool`<br>
Returns the string view of `str` with all characters before the first instance and after the last instance of tool removed.  If tool is not found then the entire string is returned.

* `trim_past (str: string, tool: %Tool, compare := default_compare) -> string, found: bool`<br>
Returns the string view of `str` with all characters before the first instance and after the last instance of tool, as well as the tool itself, removed.  If tool is not found then the entire string is returned.


* `trim_start (str: string, tool: %Tool, compare := default_compare) -> string`<br>
Returns the string view of `str` with all characters matching tool removed from the start.

* `trim_start_to (str: string, tool: %Tool, compare := default_compare) -> string, found: bool`<br>
Returns the string view of `str` with all characters before the first instance of tool removed from the start.  If tool is not found then the entire string is returned.

* `trim_start_past (str: string, tool: %Tool, compare := default_compare) -> string, found: bool`<br>
Returns the string view of `str` with all characters before the first instance of tool, and the tool, removed from the start.  If tool is not found then the entire string is returned.

* `trim_end (str: string, tool: %Tool, compare := default_compare) -> string, found: bool`<br>
Returns the string view of `str` with all characters matching tool removed from the end.

* `trim_end_after (str: string, tool: %Tool, compare := default_compare) -> string, found: bool`<br>
Returns the string view of `str` with all characters after the last instance of tool removed from the end.  If tool is not found then the entire string is returned.

* `trim_end_from (str: string, tool: %Tool, compare := default_compare) -> string, found: bool`<br>
Returns the string view of `str` with all characters after the last instance of tool, and the tool, removed from the end.  If tool is not found then the entire string is returned.


* `advance_to (haystack: *string, needle: %Tool) -> characters_skipped: int`<br>
Modifies `haystack` in-place, moving its start point forward until it hits `%Tool` (or empties).

* `advance_past (haystack: *string, needle: %Tool) -> characters_skipped: int`<br>
Modifies `haystack` in-place, moving its start point forward until it hits and reaches the end of `%Tool` (or empties).


* `first_index (haystack: string, needle: %Tool, start_index := 0, compare := default_compare) -> index: int, found: bool, [to_index: int]`<br>
Returns the first index in `haystack` at which `needle` occurs, or `-1` if it does not occur.  `found` will be true if `needle` was found.  In the case when `%Tool` is an `Index_Proc`, `to_index` will be set to the index the pattern terminates at.

* `last_index (haystack: string, needle: %Tool, start_index := 0, compare := default_compare) -> index: int, found: bool, [to_index: int]`<br>
As per `first_index`, but working backwards from the end of the `haystack`.


* `equal (a: string, b: string, compare := default_compare) -> bool`<br>
Returns whether the two strings are equal, using current or specified comparator.


* `is_any (needle: u8, characters: [] u8, compare := default_compare) -> bool`<br>
Returns whether `needle` is equal to any of `characters`.


* `contains (haystack: string, needle: %Tool, compare := default_compare) -> bool`<br>
Whether `needle` occurs within `haystack`.


* `count (haystack: string, needle: %Tool, compare := default_compare) -> int`<br>
How many times `needle` occurs within `haystack` (non-overlapping).


* `starts_with (haystack: string, needle: %Tool, compare := default_compare) -> bool`<br>
Returns whether `haystack` begins with `needle`.


* `ends_with (haystack: string, needle: %Tool, compare := default_compare) -> bool`<br>
Returns whether `haystack` ends with `needle`.


* `is_lower (char: u8) -> bool`<br>
Whether `char` falls in the range `#char "a" - #char "z"`.

* `is_upper (char: u8) -> bool`<br>
Whether `char` falls in the range `#char "A" - #char "Z"`.


* `to_lower (str: string)`<br>
Mutates `str` in-place, overwritting any upper-case characters with their lower-case equivalent.

* `to_upper (str: string)`<br>
Mutates `str` in-place, overwritting any lower-case characters with their upper-case equivalent.

* `to_capitalized (str: string, preserve_caps := true)`<br>
Sets the first letter of `str` to upper-case.  If `preserve_caps` is set to false, will set all following letters to lower-case.


* `reverse (str: string)`<br>
Reverses the characters in `str` in-place.


* `replace (haystack: string, needle: %Tool, replacement: u8, max_replacements := 0) -> change_count: int`<br>
Replaces `needle` with the `replacement` character specified.


* `split (text: string, separator: %Tool, skip_empty := false, max_results := 0, keep_separator := .NO, compare := default_compare)`<br>
Used to iterate over `text` in a `for` loop, splitting the string by the chosen tool.
If `skip_empty` is set then your code will not be called with the empty string (i.e. when there are two consecutive `seperator`s).
If `max_results` is non-zero then `text` will only be split into at most that
many pieces.
If `keep_separator` is set to `.AS_PREFIX` or `.AS_POSTFIX` then the separator will be included in the strings, at the specified position.

For example:
```jai
    for word, index: split(" aa  bb  cc ", #char " ", skip_empty = true) {
        if index == {
            case  0; assert(word == "aa");
            case  1; assert(word == "bb");
            case  2; assert(word == "cc");
        }
    }

    for word, index: split("Hello, World.", #char " ", keep_separator = .AS_POSTFIX) {
        if index == {
            case  0; assert(word == "Hello, ");
            case  1; assert(word == "World.");
        }
    }
```

* `split (array: *[$N] string, text: string, separator: %Tool, skip_empty := false, max_results := 0, keep_separator := .NO, compare := default_compare) -> result_count: int`<br>
As `split`, but places the results into a predefined array instead of looping over them.  Returns the number of results.  You must set up the array beforehand, then pass in a pointer to it:
```jai
parts : [4] string;
split(*parts, text, separator)
```

* `line_split (text: string, keep_end := false, skip_empty := false, max_results := 0, keep_separator := .NO)`<br>
Works like `split` using `#char "\n"` as the tool, but will automatically handle windows vs unix file formats (i.e. will take care of `"\r\n"`).

* `count_split (text: string, count: int, max_results := 0)`<br>
Works like the above `split`, except the string is split into sections with the specified `count`.

* `index_split (text: string, indexes: .. int, skip_empty := false, max_results := 0)`<br>
Works like the above `split`, except the string is split at the specified indices.


* `split_into_two (text: string, separator: %Tool, keep_separator := .NO, compare := default_compare) -> string, string`<br>
Splits `text` into two parts, by `separator`.


<hr>


## Strings_Alloc

This module provides procedures which return new strings.  You can set the allocator used when you import the module, but can also override the allocator on each call.  Typically you should namespace the import, identifying the allocator used (you shouldn't globally import both this and the base `Strings` module, as they have identical procedure names which will collide).

For example:
```jai
#import "Strings";
heap :: #import "Strings_Alloc";
temp :: #import "Strings_Alloc"(temp);
```


### `#module_parameters`


* `default_allocator : Allocator`<br>
`Allocator` used to allocate all returned values.  If empty (the default) then the `context.allocator` will be used.  This may be overridden in each individual call.

* `add_convenience_functions`<br>
Set this to false to disable these procs (it defaults to true) - they provide version of these standard procedures whic behave as per every other proc in this module wrt allocators:
  * `print` - identical to `sprint`, set to use this module's allocator.
  * `builder_to_string` - identical to `builder_to_string`, set to use this module's allocator.

* `compare`<br>Default comparator used to check if two string characters are equal.  You may change it using `set_default_compare`.  One of:
    * `.CASE_SENSITIVE`
    * `.IGNORE_CASE`

* `index_algorithm`<br>Determines the default string search algorithm to use, can be changed later using `set_index_algorithm`.  One of:
    * `.SIMPLE`, `.SIMPLE_SSE2`, `.SIMPLE_AVX2`, `.SIMPLE_UNSAFE`<br>Simplest algorithm, no memory overhead.
    * `.BOYER_MOORE`, `.BOYER_MOORE_SSE2`, `.BOYER_MOORE_AVX2`<br>[Boyer-Moore algorithm](https://en.wikipedia.org/wiki/Boyer%E2%80%93Moore_string-search_algorithm).  Fastest tested scalar algorithm overall, has a small memory footprint that increases with needle size.
    * `.KNUTH_MORRIS_PRATT`<br>[Knuth-Morris-Pratt algorithm](https://en.wikipedia.org/wiki/Knuth%E2%80%93Morris%E2%80%93Pratt_algorithm). Another fast algorithm, with a similar memory footprint.

* `strict`<br>By default the module will be fairly permissive of inputs, doing the Right Thing without error for odd values (indices outwith the string for instance).  Setting `strict` to true will make the module behave more stringently, erroring on such inputs.


### Procedures

Every procedure unique to this module can take these two parameters (in addition to their listed parameters):

* `allocator: Allocator` - sets the `allocator` to use, overriding the default specified in the `module_parameters`.
* `null_terminate := false` - when enabled, the string returned will have a `#char "\0"` appended to it, if it does not already end with it.

<hr>


* `set_default_compare (character_compare := default_compare)`<br>
Sets the compartor used to check if two characters match.

* `set_index_algorithm (first_index_proc := default_first_index, last_index_proc := default_last_index)`<br>
Sets the index procedures used internally when searching through strings with strings (for `replace`, `split`, etc.)

* `set_simd_mode (mode)`<br>
Sets whether to use SIMD optimisations.  One of:
    * `.OFF`<br>Disables all SIMD optimisations, utilizing scalar code only.
    * `.AUTO`<br>Uses the fastest SIMD instruction set available on the CPU.
    * `.SSE2`<br>Uses SSE2 (128bit) optimisations.  This is the default.
    * `.AVX2`<br>Uses AVX2 (256bit) optimisations.
Note that this will *not* alter the string index algorithm you are using: if you wish to enable or disable SIMD functionalty with string indexing you must do so by choosing the appropriate algorithms using `set_index_algorithm`, or the `index_algorithm` module parameter.


* `copy_string (str: string) -> string`<br>
Returns of a copy of `str`.


* `reverse (str: string) -> string`<br>
Returns a copy of `str` with the characters in the reverse order.


* `lower (str: string) -> string`<br>
Returns a copy of `str` with all upper-case characters converted to their lower-case equivalent.

* `upper (str: string)`<br>
Returns a copy of `str` with all lower-case characters converted to their upper-case equivalent.

* `capitalized (str: string, preserve_caps := true) -> string`<br>
Returns a copy of `str` with the first letter converted to upper-case.  If `preserve_caps` is disabled then all subsequent letters will be converted to lower-case.


* `replace (haystack: string, needle: %Tool, replacement: string,  max_replacements := 0, compare := default_compare) -> string`<br>
Returns a copy of `str` with all (non-overlapping) instances of `needle` replaced with `replacement`.
If `max_replacements` is non-zero then at most that many replacements will be made (starting at the beginning of the string).

* `join  (strings: .. string) -> string`<br>
Returns a single string created by concatenating all the provided strings together.

* `join (strings: [] string) -> string`<br>
Returns a single string, the result of joining all the strings in the `strings` array together.

* `join (strings: [] string, separator: string) -> string`<br>
Returns a single string, the result of joining all the strings in the `strings` array together with `separator` between them.

* `join (strings: [] string, separator: u8) -> string`<br>
Returns a single string, the result of joining all the strings in the `strings` array together with `separator` between them.


* `split (text: string, separator: %Tool, reversed := false, skip_empty := false, max_results := 0, keep_separator := .NO, compare := default_compare) -> [] string`<br>
Creates an array of strings by splitting `text` at each instance of `separator`.
If `reversed` is set then the order in the array will be reversed.
If `skip_empty` is set then empty strings will not be added to the array (i.e. when there are two consecutive `seperator`s).
If `max_results` is non-zero then `text` will only be split into at most that
many pieces.
If `keep_separator` is set to `.AS_PREFIX` or `.AS_POSTFIX` then the separator will be included in the strings, at the specified position.

*NOTE* if you can accomplish your task by iterating with `split` from the `Strings` module then that may be the better, more performant solution.

* `line_split (text: string, reversed := false, skip_empty := false, max_results := 0, keep_separator := Keep_Separator.NO) -> [] string`<br>
As per `split` above, but splitting by lines as per `line_split` in the `Strings` module.

* `index_split (text: string, indexes: .. int, reversed := false, skip_empty := false, max_results := 0) -> [] string`<br>
As per `split` above, but splitting the string at the specified indices.

* `count_split (text: string, count: int, reversed := false, max_results := 0) -> [] string`<br>
As per `split` above, but splitting the string into sections with the specified `count`.


* `split (text: string, splitter: Split_By, reversed := false, skip_empty := false, max_results := 0) -> [] string`<br>
As per `split` above, but using the specified `Split_By` struct.  i.e. a struct returned by the `split` function in the `Strings` module.


* `pad_start (str: string, desired_count: int, pad_with := " ") -> string`<br>
Returns a copy of `str` with `pad_with` repeated at the beginning such that the string length reaches the `desired_count`.

* `pad_start (str: string, desired_count: int, pad_with: u8) -> string`<br>
Returns a copy of `str` with `pad_with` repeated at the beginning such that the string length reaches the `desired_count`.

* `pad_end (str: string, desired_count: int, pad_with := " ") -> string`<br>
Returns a copy of `str` with `pad_with` repeated from the end such that the string length reaches the `desired_count`.

* `pad_end (str: string, desired_count: int, pad_with: u8) -> string`<br>
Returns a copy of `str` with `pad_with` repeated from the end such that the string length reaches the `desired_count`.

* `pad_center (str: string, desired_count: int, pad_with := " ") -> string`<br>
Returns a copy of `str` with `pad_with` repeated from the begining *and* from the end such that the string length reaches the `desired_count`.

* `pad_center (str: string, desired_count: int, pad_with: u8) -> string`<br>
Returns a copy of `str` with `pad_with` repeated from the begining *and* from the end such that the string length reaches the `desired_count`.


* `repeat (str: string, times: int) -> string`<br>
Returns a string consisting of `str` repeated `times` times.


* `camel_from_snake (str: string, preserve_caps := false) -> string`<br>
Returns a copy of underscore-separated `str`, changed into programmer CamelCase; i.e. with the leading letter, and every letter after an underscore, converted to upper-case, and with underscores removed.  If `preserve_caps` is enabled then the the underscore removal still happens, but the case is kept.

For example:
```jai
    assert( camel_from_snake("play_RTS")       == "playRts" );
    assert( camel_from_snake("play_RTS", true) == "playRTS" );
```


* `snake_from_camel (str: string, preserve_caps := false) -> string`<br>
Returns a copy of CamelCased `str`, changed into programmer snake case; i.e. converted to lower-case, but split by `_` at each formerly upper-case letter edge.  If `preserve_caps` is enabled then the the split still happens, but the case is kept.

For example:
```jai
    assert( snake_from_camel("PlayRTS")       == "play_rts" );
    assert( snake_from_camel("PlayRTS", true) == "play_RTS" );
```


* `apply_backslash (str: string) -> string, well_formed: bool`<br>
Converts legal jai backslash escape sequences (i.e. `\n`, `\t`, etc) into their specified character. i.e. a two character string `"\n"` will yield a single character string with byte value `10`;
`well_formed` will be true if all backslash characters in `str` are followed by an appropriate escape sequence.


* `escape (str: string) -> string`<br>
Replaces the special characters which jai uses backslash escapes to represent with said backslash escape sequence. i.e. the single character string with byte value `10` will yield the two character string `"\n"`
