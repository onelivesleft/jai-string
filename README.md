# jai-string

String modules for Jai

* `Strings` provides procs which mutate strings in place or return information or string-views.
* `Strings_Alloc` provides procs which return allocated data.
* `Scratch` provides a simple allocator for doing multiple operations in a row without grabbing more memory on each one.

For example, you could import and use them like this:

```jai
#import "Strings";
heap :: #import "Strings_Alloc";
scratch :: #import "Strings_Alloc"(scratch_allocator);
temp :: #import "Strings_Alloc"(__temporary_allocator);
#import "Scratch";

main :: () {
    trimmed := trim("  Some test string  ");  // in Strings, does not allocate

    words := temp.split(trimmed, #char " "); // allocated in temporary storage

    banner := heap.join(words, #char "\n"); // allocated with default allocator
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
    inverted :: type_of(case_sensitive) {
        .CUSTOM,
        (a: u8, b: u8) -> bool {
            return a != b;
        }
    }
```

*(The other two options to `.CUSTOM` are `.CASE_SENSITIVE` and `.IGNORE_CASE`: you may roll your own versions of those comparators if you wish, and by choosing the relevant identifier the correct SIMD optimisations will be invoked)*


### Tool types: u8 / [] u8 / string / Index_Proc

In a string library it is often the case that you have a string which you are applying an operation to using a *tool* parameter.  In this library there will generally be four version of such procedures, a version each for when the tool is: `u8`, `[] u8`, `string`, and `Index_Proc`.  As tools these types behave consistently across the library.  The first three are simple, built-in types, and work like this:

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


An `Index_Proc` is a procedure with the signature:

`(haystack: string, needle: string, boundary_index: int, reverse: bool) -> from_index: int, to_index: int, found: bool`

This allows you to feed an arbitrarily complex pattern match into the procedure you are using.  When using an `Index_Proc` tool, a character comparator is not used (as your own code is instead).

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

In the docs below, any time a type of `%Tool` is specified, it means there are four versions of the procedure, each corresponding to the behaviour described above.

<hr>

## Strings

### `#module_parameters`

* `compare`<br>Default comparator used to check if two string characters are equal.  You may change it using `set_default_compare`.  One of:
    * `.CASE_SENSITIVE`
    * `.IGNORE_CASE`

* `index_algorithm`<br>Determines the default string search algorithm to use, can be changed later using `set_index_algorithm`.  One of:
    * `.NAIVE`<br>Simplest algorithm, no memory overhead.
    * `.BOYER_MOORE`<br>[Boyer-Moore algorithm](https://en.wikipedia.org/wiki/Boyer%E2%80%93Moore_string-search_algorithm).  Fastest tested algorithm, has a small memory footprint that increases with needle size.
    * `.KNUTH_MORRIS_PRATT`<br>[Knuth-Morris-Pratt algorithm](https://en.wikipedia.org/wiki/Knuth%E2%80%93Morris%E2%80%93Pratt_algorithm). Another fast algorithm, with a similar memory footprint.

* `strict`<br>By default the module will be fairly permissive of inputs, doing the Right Thing without error for odd values (indices outwith the string for instance).  Setting `strict` to true will make the module behave more stringently, erroring on such inputs.


### Procedures

* `set_default_compare (character_compare := default_compare)`<br>
Sets the compartor used to check if two characters match.

* `set_index_algorithm (first_index_proc := default_first_index, last_index_proc := default_last_index)`<br>
Sets the index procedures used internally when searching through strings with strings (for `replace`, `split`, etc.)

* `set_simd_mode (mode)`<br>Sets whether to use SIMD optimisations.  One of:
    * `.OFF`<br>Disables all SIMD optimisations, utilizing scalar code only.
    * `.AUTO`<br>Uses the fastest SIMD instruction set available on the CPU.
    * `.SSE`<br>Uses SSE (128bit) optimisations.  This is the default.
    * `.AVX2`<br>Uses AVX2 (256bit) optimisations.


* `is_any (needle: u8, characters: [] u8, compare := default_compare) -> bool`<br>
Returns whether `needle` is equal to any of `characters`.

* `equal (a: string, b: string, compare := default_compare) -> bool`<br>
Returns whether the two strings are equal, using current or specified comparator.


* `advance_to (haystack: string, needle: %Tool) -> characters_skipped: int`<br>
Modifies `haystack` in place, moving its start point forward until it hits `%Tool` (or empties).

* `advance_past (haystack: string, needle: %Tool) -> characters_skipped: int`<br>
Modifies `haystack` in place, moving its start point forward until it hits and reaches the end of `%Tool` (or empties).


* `slice (str: string, from_index: int, to_index: int) -> string, normalized_from_index: int, normalized_to_index: int`<br>
Returns a string view inside `str`, between the specified indices.  You may use a negative index to specify backwards from the end.  If you do not specify a `to_index` then it will go to the end of the string.  The last two return parameters are the positive indexes the slice ends up using, after validation.

* `slice_index (str: string, index: int) -> normalized_index: int, valid_when_strict: bool`<br>
Returns the validated and normalized index which would be used with the provided string, as well as whether such an input would be valid in `strict` mode.

* `unsafe_slice (str: string, from_index: int, to_index: int) -> string`<br>
Same thing as `slice`, but without any checking on the indices, and without being able to use negative indices (and thus faster).  If you do not specify a `to_index` then it will go to the end of the string.

* `substring (str: string, from_index: int, count: int) -> string`<br>
Same as `slice`, except instead of a `to_index` you specify a character count.

* `trim (str: string) -> string`<br>
Returns the string view of `str` with all characters from the start and end which are <= `#char " "` removed (in effect all whitespace and control codes).

* `trim (str: string, tool: %Tool, compare := default_compare) -> string`<br>
Returns the string view of `str` with all characters matching tool removed from the start and end.

* `trim_start (str: string, tool: %Tool, compare := default_compare) -> string`<br>
Returns the string view of `str` with all characters matching tool removed from the start.

* `trim_end (str: string, tool: %Tool, compare := default_compare) -> string`<br>
Returns the string view of `str` with all characters matching tool removed from the end.


* `first_index (haystack: string, needle: %Tool, start_index := 0, compare := default_compare) -> index: int, found: bool, [to_index: int]`<br>
Returns the first index in `haystack` at which `needle` occurs, or `-1` if it does not occur.  `found` will be true if `needle` was found.  In the case when `%Tool` is an `Index_Proc`, `to_index` will be set to the index the pattern terminates at.

* `last_index (haystack: string, needle: %Tool, start_index := 0, compare := default_compare) -> index: int, found: bool, [to_index: int]`<br>
As per `first_index`, but working backwards from the end of the `haystack`.

* `contains (haystack: string, needle: %Tool, compare := default_compare) -> bool`<br>
Whether `needle` occurs within `haystack`.

* `count (haystack: string, needle: %Tool, compare := default_compare) -> int`<br>
How many times `needle` occurs within `haystack` (non-overlapping).

* `count (haystack: string, needle: [] Character_Translation) -> int`<br>
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

* `replace (haystack: string, translation: [] Character_Translation, max_replacements := 0) -> change_count: int`<br>
Replaces characters specified within the translation table.  A `Character_Translation` is:

```jai
Character_Translation :: struct {
    needle: u8;
    replacement: u8;
}
```


* `split (text: string, separator: %Tool, skip_empty := false, max_results := 0)`<br>
Used to iterate over `text` in a `for` loop, splitting the string by the chosen tool.  If `skip_empty` is set then your code will not be called with the empty string (i.e. when there are two consecutive `seperator`s).  If `max_results` is non-zero then `text` will only be split into at most that many pieces.

For example:
```jai
    for word, index: split(" aa  bb  cc ", #char " ", skip_empty = true) {
        if index == {
            case  0; assert(word == "aa");
            case  1; assert(word == "bb");
            case  2; assert(word == "cc");
        }
    }
```

* `split (text: string, indexes: .. int, skip_empty := false, max_results := 0)`<br>
Works like the above `split`, except the string is split at the specified indices.

* `line_split (text: string, keep_end := false, skip_empty := false, max_results := 0)`<br>
Works like `split` using `#char "\n"` as the tool, but will automatically handle windows vs unix file formats (i.e. will take care of `"\r\n"`).  By default the values returned will have the end-of-line characters removed, but you may elect to keep them by setting `keep_end` to true.


* `string_from_char (char: *u8) -> string`<br>
Returns a string view on the character specified.

* `reverse_index_proc (index_proc: Index_Proc, haystack: string, needle: string, boundary_index: int) -> from_index: int, to_index: int, found: bool`<br>
Can be used to automatically make a reversed version of an `Index_Proc` (see `question_mark_index` example above).  Very inefficient!


<hr>


## Strings_Alloc


### `#module_parameters`


* `default_allocator : Allocator`<br>
`Allocator` used to allocate all returned values.  If `null` (the default) then the `context.allocator` will be used.  This may be overridden in each individual call.

* `default_allocator_data : *void`<br>
Allocator data used when allocating returned values.  This may be overridden in each individual call.

* `add_convenience_functions`<br>
When enabled (it defaults to false) the module will provide these additional procedures:
  * `print` - identical to `sprint`, set to use this module's allocator.
  * `builder_to_string` - identical to `builder_to_string`, set to use this module's allocator.

* `compare`<br>Default comparator used to check if two string characters are equal.  You may change it using `set_default_compare`.  One of:
    * `.CASE_SENSITIVE`
    * `.IGNORE_CASE`

* `index_algorithm`<br>Determines the default string search algorithm to use, can be changed later using `set_index_algorithm`.  One of:
    * `.NAIVE`<br>Simplest algorithm, no memory overhead.
    * `.BOYER_MOORE`<br>[Boyer-Moore algorithm](https://en.wikipedia.org/wiki/Boyer%E2%80%93Moore_string-search_algorithm).  Fastest tested algorithm, has a small memory footprint that increases with needle size.
    * `.KNUTH_MORRIS_PRATT`<br>[Knuth-Morris-Pratt algorithm](https://en.wikipedia.org/wiki/Knuth%E2%80%93Morris%E2%80%93Pratt_algorithm). Another fast algorithm, with a similar memory footprint.

* `strict`<br>By default the module will be fairly permissive of inputs, doing the Right Thing without error for odd values (indices outwith the string for instance).  Setting `strict` to true will make the module behave more stringently, erroring on such inputs.


### Procedures

Every procedure unique to this module can take these three parameters (in addition to their listed parameters):

* `allocator: Allocator` - sets the `allocator` to use, overriding the default specified in the `module_parameters`.
* `allocator_data: *void` - sets the `allocator_data` to use, overriding the default specified in the `module_parameters`.
* `null_terminate := false` - when enabled, the string returned will have a `#char "\0"` appended to it, if it does not already end with it.

<hr>


* `set_default_compare (character_compare := default_compare)`<br>
Sets the compartor used to check if two characters match.

* `set_index_algorithm (first_index_proc := default_first_index, last_index_proc := default_last_index)`<br>
Sets the index procedures used internally when searching through strings with strings (for `replace`, `split`, etc.)

* `set_simd_mode (mode)`<br>Sets whether to use SIMD optimisations.  One of:
    * `.OFF`<br>Disables all SIMD optimisations, utilizing scalar code only.
    * `.AUTO`<br>Uses the fastest SIMD instruction set available on the CPU.
    * `.SSE`<br>Uses SSE (128bit) optimisations.  This is the default.
    * `.AVX2`<br>Uses AVX2 (256bit) optimisations.

* `set_string_builder_allocator (allocator: Allocator, allocator_data : void = null)`<br>
Sets the allocator used by String_Builder as it operates. Can also be set with the `string_builder_allocator` module parameter.  It defaults to using temporary storage.


* `copy (str: string) -> string`<br>
Returns of a copy of `str`.

* `reverse (str: string) -> string`<br>
Returns a copy of `str` with the characters in the reverse order.

* `capitalized (str: string, preserve_caps := true) -> string`<br>
Returns a copy of `str` with the first letter converted to upper-case.  If `preserve_caps` is disabled then all subsequent letters will be converted to lower-case.

* `lower (str: string) -> string`<br>
Returns a copy of `str` with all upper-case characters converted to their lower-case equivalent.

* `upper (str: string)`<br>
Returns a copy of `str` with all lower-case characters converted to their upper-case equivalent.


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

* `split (text: string, separator: %Tool, reversed := false, skip_empty := false, max_results := 0, compare := default_compare) -> [] string`<br>
Creates an array of strings by splitting `text` at each instance of `separator`.  `reversed` will reverse the order of the array.  `skip_empty` will not include any empty strings in the array (i.e. when there are consecutive separators).  If `max_results` is non-zero then the array will contain at most that many entries.
*NOTE* if you can accomplish your task by iterating with `split` from the `Strings` module then that may be the better, more performant solution.

* `split (text: string, indexes: .. int, reversed := false, skip_empty := false, max_results := 0) -> [] string`<br>
As per `split`, but splitting the string at the specified indices.

* `split (text: string, splitter: Split_By, reversed := false, skip_empty := false, max_results := 0) -> [] string`<br>
As per `split`, but using the specified `Split_By` struct.  i.e. a struct returned by the `split` function in the `Strings` module.

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
