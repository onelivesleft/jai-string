# Change Log

## [1.0.3] - 2021-10-24
* Renamed `trim_to`, `trim_past` -> `trim_into`, `trim_through`.
* Fixed `trim_through` behaviour when only one needle present.
* Fixed array-write version of `split` when used on empty strings.
* Fixed boyer-moore first index returning false for equal haystack/needle.

## [1.0.2] - 2021-09-22
* Fixed SIMD `last_index` procs.

## [1.0.1] - 2021-09-21
* `Strings_Alloc.add_convenience_functions` now defaults to `true` (as module should be namespaced anyway).
* Fixed `first_index`, `last_index` not handling empty haystacks correctly.
* Now checks for valid `max_results` in splitters.

## [1.0.0] - 2021-09-19
* First release.
