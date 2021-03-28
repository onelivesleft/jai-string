# jai-string

String modules for Jai

* `String_View` provides procs which mutate strings in place or return information or string-views.
* `String_New` provides procs which return allocated data.

For example, you could import and use them like this:

```jai
#import "String_View";
heap :: #import "String_New" #unshared;
temp :: #import "String_New"(__temporary_allocator) #unshared;

main :: () {
    trimmed := trim("  Some test string  ");  // in String_View, does not allocate

    words := temp.split(trimmed, #char " "); // allocated in temporary storage

    banner := heap.join(words, #char "\n"); // allocated with default allocator
}
```

To use clone the repo then copy the two `String_` folders into your `jai/modules` folder, or symlink them: `mklink /d c:\jai\modules\String_View c:\repos\jai-string\String_View`


## String_View

### `#module_parameters`

* `default_first_index`<br>
`first_index` procedure used to search through strings for substrings, and used internally (for `split`, `replace`, etc.).  By default this uses `boyer_moore_first_index`, which does allocate a small amount of data (increasing in size with the needle).  Swap to `naive_first_index` for a non-allocating albeit slower version (or roll your own).

* `default_last_index`<br>
As `default_first_index`, but searching backwards from the end of the string.

* `default_compare`<br>
Default comparison procedure used to check if two characters are equal.  Default is `case_sensitive`; you may change to `ignore_case`, or your own.

* `strict`<br>
By default the module will be fairly permissive of inputs, doing the Right Thing without error for odd values (indices outwith the string for instance).  Setting `strict` to true will make the module behave more stringently, erroring on such inputs.


### Character Comparison

By default characters being compared between two strings are compared using the `case_sensitive` function (unless you override it with the module parameter).  In this library, any procedure which involves comparing strings will take a `compare` parameter in which you can specify a different procedure from the default.  For example:

```jai
    assert( contains("Hello", "h")              == false );
    assert( contains("Hello", "h", ignore_case) == true  );
```


### Tool types: u8 / []u8 / string / Index_Proc

In a string library it is often the case that you have a string which you are applying an operation to using a *tool* parameter.  In this library there will generally be four version of such procedures, a version each for when the tool is: `u8`, `[] u8`, `string`, and `Index_Proc`.  As tools these types behave consistently across the libary.  The first three are simple, built-in types, and work like this:

* `u8`<br>
The single character specified will be used.

* `[] u8`<br>
A match to any of the characters in the array will be used.

* `string`<br>
The exact string will be used: i.e. the characters specified in the sequence specified.


For example:
```jai
    assert( trim(" Hello  ", #char " ")            == "Hello"  );
    assert( trim("prerep World", cast([]u8) "pre") == " World" );
    assert( trim("prerep World", "pre")            == "rep World" );
```

An `Index_Proc` is a procedure with the signature:

`(haystack: string, needle: string, boundary_index: int, reverse: bool) -> from_index: int, to_index: int, found: bool`

This allows you to feed an arbitrarily complex pattern match into the procedure you are using.

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


### Procedures

* `set_index_algorithm (first_index_proc := default_first_index, last_index_proc := default_last_index)`
Sets the index procedures used internally when searching through strings (for `replace`, `split`, etc.)

* `is_any (needle: u8, characters: [] u8, compare := default_compare) -> bool`<br>
Returns whether `needle` compares true to any of `characters`.  This is used internally with the `default_compare` any time a `[] u8` comparison is needed.

* `string_from_char (char: *u8) -> string`<br>
Returns a string view on the character specified.


* `slice (str: string, from_index: int, to_index: int) -> string, normalized_from_index: int, normalized_to_index: int`<br>
Returns a string view inside `str`, between the specified indices.  You may use a negative index to specify backwards from the end.  If you do not specify a `to_index` then it will go to the end of the string.

* `slice_index (str: string, index: int) -> normalized_index: int, valid_when_strict: bool`<br>
Returns the validated and normalized index which would be used with the provided string, as well as whether such an input would be valid in `strict` mode.

* `unsafe_slice (str: string, from_index: int, to_index: int) -> string`<br>
Same thing as `slice`, but without any checking on the indices, and without being able to use negative indices (and thus faster).  If you do not specify a `to_index` then it will go to the end of the string.

* `substring (str: string, from_index: int, count: int) -> string`<br>
Same as `slice`, except instead of a `to_index` you specify a character count.

* `starts_with (haystack: string, needle: %Tool) -> bool`<br>
Returns whether `haystack` begins with `needle`.

* `ends_with (haystack: string, needle: %Tool) -> bool`<br>
Returns whether `haystack` ends with `needle`.

* `first_index (haystack: string, needle: %Tool, start_index := 0) -> index: int, found: bool, [to_index: int]`<br>
Returns the first index in `haystack` at which `needle` occurs, or `-1` if it does not occur.  `found` will be true if `needle` was found.  In the case when `%Tool` is an `Index_Proc`, `to_index` will be set to the index the pattern terminates at.

* `last_index (haystack: string, needle: %Tool, start_index := 0) -> index: int, found: bool, [to_index: int]`<br>
As per `first_index`, but working backwards from the end of the `haystack`.

* `contains (haystack: string, needle: %Tool) -> bool`<br>
Whether `needle` occurs within `haystack`.

* `count (haystack: string, needle: %Tool) -> int`<br>
How many times `needle` occurs within `haystack` (non-overlapping).

* `count (haystack: string, needle: [] Character_Translation) -> int`<br>
How many times `needle` occurs within `haystack` (non-overlapping).

* `trim (str: string) -> string`<br>
Returns the string view of `str` with all characters from the start and end which are <= `#char " "` removed (in effect all whitespace and control codes).

* `trim (str: string, tool: %Tool) -> string`<br>
Returns the string view of `str` with all characters from the start and end which are match `tool` removed.

* `trim_start`, `trim_end`<br>
As per `trim`, except only remove characters from the start and end of the string, respectively.

* `is_lower (char: u8) -> bool`<br>
Whether `char` falls in the range `#char "a" - #char "z"`.

* `is_upper (char: u8) -> bool`<br>
Whether `char` falls in the range `#char "A" - #char "Z"`.

* `to_lower (str: string)`<br>
Mutates `str` in-place, overwritting any upper-case characters with their lower-case equivalent.

* `to_upper (str: string)`<br>
Mutates `str` in-place, overwritting any lower-case characters with their upper-case equivalent.

* `reverse :: (str: string)`<br>
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

* `capitalize :: (str: string, preserve_caps := true)`<br>
Sets the first letter of `str` to upper-case.  If `preserve_caps` is set to false, will set all following letters to lower-case.


* `forward_split (text: string, separator: %Tool, skip_empty := false, max_results := 0)`<br>
Used to iterate over `text` in a `for` loop, splitting the string by the chosen tool.  If `skip_empty` is set then your code will not be called with the empty string (i.e. when there are two consecutive `seperator`s).  If `max_results` is non-zero then `text` will only be split into at most that many pieces.

For example:
```jai
    for word, index: forward_split(" aa bb cc ", #char " ", skip_empty = true) {
        if index == {
            case  0; assert(word == "aa");
            case  1; assert(word == "bb");
            case  2; assert(word == "cc");
        }
    }
```

* `reverse_split (text: string, separator: %Tool, skip_empty := false, max_results := 0)`<br>
As per `forward_split`, but working backwards from the end of `text`.

* `forward_split (text: string, indexes: .. int, skip_empty := false, max_results := 0)`<br>
Works like the above `forward_split`, except the string is split at the specified indices.

* `reverse_split (text: string, indexes: .. int, skip_empty := false, max_results := 0)`<br>
As per `forward_split`, but working backwards from the end of `text`.

* `line_split (text: string, skip_empty := false, max_results := 0, keep_eol := false)`<br>
Works like `forward_split` using `#char "\n"` as the tool, but will automatically handle windows vs unix file formats (i.e. will take care of `"\r\n"`).  By default the values returned will have the end-of-line characters removed, but you may elect to keep them by setting `keep_eol` to true.
