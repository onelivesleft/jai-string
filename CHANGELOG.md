# Change Log

## [2.0.0] - 2024-11-
* Rework!

## [1.0.9] - 2022-12-23
* Removed copy_string in Shared (Basic copy_string is now identical)
* Updated for latest compiler version

## [1.0.8] - 2021-12-24
* Renamed `char_split` to `split`
* Updated references to `String_Builder.occupied` to `String_Builder.count`
* Updated references to `String_Builder.data.data` to `get_buffer_data(String_Builder)`
* Added `modules.lst`

## [1.0.7] - 2021-12-09
* Updated all built-in index algorithms so that they use a character index when the needle has length 1.
* Renamed `copy` to `copy_string`
* Added `char_split`

## [1.0.6] - 2021-11-27
* Updated to work with new `Allocator` style.
* Added some thread-unsafe indexing procs.

## [1.0.5] - 2021-10-24
* Fixed array-write version of `split` when used on empty strings.
* Fixed boyer-moore first index returning false for equal haystack/needle.

## [1.0.4] - 2021-10-12
* Fixed indexing algorithms erroneously allocating with context.allocator
* Fixed `null_terminate` in `join`.

## [1.0.3] - 2021-10-12
* Renamed `trim_to`, `trim_past` -> `trim_into`, `trim_through`.
* Fixed `trim_through` behaviour when only one needle present.
* Updated to work with compiler v86.

## [1.0.2] - 2021-09-22
* Fixed SIMD `last_index` procs.

## [1.0.1] - 2021-09-21
* `Strings_Alloc.add_convenience_functions` now defaults to `true` (as module should be namespaced anyway).
* Fixed `first_index`, `last_index` not handling empty haystacks correctly.
* Now checks for valid `max_results` in splitters.

## [1.0.0] - 2021-09-19
* First release.
