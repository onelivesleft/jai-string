#import "Basic";
#import "File";
#import "File_Utilities";
#import "Sort";
#import "Time";
#import "Strings";
heap :: #import "Strings_Alloc";
jai_string :: #import "String";


main :: () {
    args := get_command_line_arguments();
    haystack_file := "";
    needle := "";
    no_case := false;
    times : s64 = 100;
    i := 1;
    test_only := false;
    valid_args := true;
    while i < args.count {
        arg := args[i];
        if arg == "-i" {
            no_case = true;
        }
        else if arg == "-t" {
            test_only = true;
        }
        else if arg == "-c" {
            i += 1;
            if i >= args.count {
                valid_args = false;
                break;
            }
            n, ok := jai_string.parse_int(*args[i]);
            if !ok || n < 1 {
                valid_args = false;
                break;
            }
            times = n;
        }
        else if haystack_file == "" {
            haystack_file = arg;
        }
        else if needle == "" {
            needle = heap.apply_backslash(arg);
        }
        else {
            valid_args = false;
            break;
        }

        i += 1;
    }

    if !(haystack_file && needle && valid_args) {
        print("\nUSAGE: index_profile.exe [-i] [-c <N>] <haystackfile> <needle>\n\n");
        print(" <haystackfile> = path of file containing haystack text\n");
        print(" <needle>       = text to search for\n");
        print(" -i             = ignore case\n");
        print(" -c <N>         = perform N iterations, default is 100\n");
        exit(1);
    }

    if !file_exists(haystack_file) {
        print("\nFile not found: %\n", haystack_file);
        exit(2);
    }

    if test_only  times = 1;

    haystack := read_entire_file(haystack_file);

    simple            :: true;
    jai               :: true;
    simple_sse2       :: true;
    simple_avx2       :: true;
    kmp               :: true;
    boyer_moore       :: true;
    boyer_moore_sse2  :: true;
    boyer_moore_avx2  :: true;

    //#if kmp {
    //    #load "../Strings_Shared/knuth_morris_pratt.jai";
    //}

    format_float := *context.print_style.default_format_float;
    format_float.zero_removal = .NO;
    format_float.width = 6;
    format_float.trailing_width = 3;


    find_index_from_left := jai_find_index_from_left;
    find_index_from_right := jai_find_index_from_right;

    if no_case {
        find_index_from_left = jai_find_index_from_left_nocase;
        find_index_from_right = jai_find_index_from_right_nocase;
        set_default_compare(ignore_case);
    }
    else {
        set_default_compare(case_sensitive);
    }

    expected_first_checksum : u64;
    expected_last_checksum : u64;
    expected_total := 0;

    {
        s := haystack;
        offset := 0;
        index := find_index_from_left(s, needle);
        while index >= 0 {
            index += offset;
            expected_first_checksum = xor(expected_first_checksum, xx index);
            expected_total += 1;
            offset = index + 1;
            s.data = haystack.data + offset;
            s.count = haystack.count - offset;
            index = find_index_from_left(s, needle);
        }

        s = haystack;
        index = find_index_from_right(haystack, needle);
        while index >= 0 {
            expected_last_checksum = xor(expected_last_checksum, xx index);
            s.count = index;
            index = find_index_from_right(s, needle);
        }

        expected_first_checksum *= cast(u64)times;
        expected_last_checksum  *= cast(u64)times;
        expected_total *= times;
    }


    Entry :: struct {
        name : string;
        id : string;
        prefix : string;
        first_time : float64 = 0;
        last_time  : float64 = 0;
        first_total := 0;
        first_checksum : u64 = 0;
        last_checksum  : u64 = 0;
        last_total := 0;
    }

    entry :: (id: string, name: string, prefix: string) -> Entry {
        result : Entry;
        result.id = id;
        result.name = name;
        result.prefix = prefix;
        return result;
    }

    #if jai               jai_entry              := entry("?", "Jai", "jai");
    #if boyer_moore       boyer_moore_entry      := entry("BOYER_MOORE", "Boyer-Moore", "boyer_moore");
    #if boyer_moore_sse2   boyer_moore_sse2_entry  := entry("BOYER_MOORE_SSE2", "Boyer-Moore SSE2", "boyer_moore_sse2");
    #if boyer_moore_avx2  boyer_moore_avx2_entry := entry("BOYER_MOORE_AVX2", "Boyer-Moore AVX2", "boyer_moore_avx2");
    #if kmp               kmp_entry              := entry("KNUTH_MORRIS_PRATT", "Knuth-Morris-Pratt", "knuth_morris_pratt");
    #if simple            simple_entry           := entry("SIMPLE", "Simple", "simple");
    #if simple_sse2        simple_sse2_entry       := entry("SIMPLE_SSE2", "Simple SSE2", "simple_sse2");
    #if simple_avx2       simple_avx2_entry      := entry("SIMPLE_AVX2", "Simple AVX2", "simple_avx2");

    prev_marker := -1;

    for 1 .. times {
        if times >= 10 {
            marker : s64 = it / (times / 10);
            if marker != prev_marker {
                prev_marker = marker;
                if marker < 10
                    print("%", marker);
            }
        }

        #if jai {{
            t := get_time();
            s := haystack;
            offset := 0;
            index := find_index_from_left(haystack, needle);
            checksum : u64 = 0;
            total := 0;
            while index >= 0 {
                index += offset;
                checksum = xor(checksum, xx index);
                total += 1;
                offset = index + 1;
                s.data = haystack.data + offset;
                s.count = haystack.count - offset;
                index = find_index_from_left(s, needle);
            }
            jai_entry.first_checksum += checksum;
            jai_entry.first_total += total;
            jai_entry.first_time += get_time() - t;

            t = get_time();
            s = haystack;
            index = find_index_from_right(haystack, needle);
            checksum = 0;
            total = 0;
            while index >= 0 {
                checksum = xor(checksum, xx index);
                total += 1;
                s.count  = index;
                index = find_index_from_right(s, needle);
            }
            jai_entry.last_checksum += checksum;
            jai_entry.last_total += total;
            jai_entry.last_time += get_time() - t;
        }}

        test :: (first_index_proc: type_of(simple_first_index), last_index_proc: type_of(simple_last_index), entry: *Entry) #expand {
            set_index_algorithm(first_index_proc, last_index_proc);

            t := get_time();
            index, found := first_index(`haystack, `needle);
            checksum : u64 = 0;
            total := 0;
            while found {
                checksum = xor(checksum, xx index);
                total += 1;
                index, found = first_index(`haystack, `needle, index + 1);
            }
            entry.first_checksum += checksum;
            entry.first_total += total;
            entry.first_time += get_time() - t;

            t = get_time();
            index, found = last_index(`haystack, `needle);
            checksum = 0;
            total = 0;
            while found {
                checksum = xor(checksum, xx index);
                total += 1;
                index, found = last_index(`haystack, `needle, index);
            }
            entry.last_checksum += checksum;
            entry.last_total += total;
            entry.last_time += get_time() - t;
        }

        #if boyer_moore       test(boyer_moore_first_index, boyer_moore_last_index, *boyer_moore_entry);
        #if boyer_moore_sse2   test(boyer_moore_sse2_first_index, boyer_moore_sse2_last_index, *boyer_moore_sse2_entry);
        #if boyer_moore_avx2  test(boyer_moore_avx2_first_index, boyer_moore_avx2_last_index, *boyer_moore_avx2_entry);
        #if kmp               test(knuth_morris_pratt_first_index, knuth_morris_pratt_last_index, *kmp_entry);
        #if simple            test(simple_first_index, simple_last_index, *simple_entry);
        #if simple_sse2        test(simple_sse2_first_index, simple_sse2_last_index, *simple_sse2_entry);
        #if simple_avx2       test(simple_avx2_first_index, simple_avx2_last_index, *simple_avx2_entry);
    }

    entries : [..] Entry;

    #if jai               array_add(*entries, jai_entry);
    #if kmp               array_add(*entries, kmp_entry);
    #if boyer_moore       array_add(*entries, boyer_moore_entry);
    #if boyer_moore_sse2   array_add(*entries, boyer_moore_sse2_entry);
    #if boyer_moore_avx2  array_add(*entries, boyer_moore_avx2_entry);
    #if simple            array_add(*entries, simple_entry);
    #if simple_sse2        array_add(*entries, simple_sse2_entry);
    #if simple_avx2       array_add(*entries, simple_avx2_entry);

    quick_sort(entries, (a: Entry) -> float64 { return a.first_time; });

    fastest_last_time := entries[0].last_time;
    for entries  if it.last_time < fastest_last_time  fastest_last_time = it.last_time;

    if test_only {
        all_ok := true;
        print("Testing: %\nNeedle:  %\nFound:   %\n", haystack_file, needle, expected_total);
        for entries {
            print("%", heap.pad_end(it.name, 20));

            valid := true;
            if it.first_checksum != expected_first_checksum {
                print("BAD FIRST CHECKSUM: Expected [%] Got [%]\n", expected_first_checksum, it.first_checksum);
                valid = false;
            }
            if it.last_checksum != expected_last_checksum {
                if !valid  print("                    ");
                print("BAD LAST CHECKSUM:  Expected [%] Got [%]\n", expected_last_checksum, it.last_checksum);
                valid = false;
            }
            if it.first_total != expected_total {
                if !valid  print("                    ");
                print("BAD FIRST TOTAL:  Expected [%] Got [%]\n", expected_total, it.first_total);
                valid = false;
            }
            if it.last_checksum != expected_last_checksum {
                if !valid  print("                    ");
                print("BAD LAST TOTAL:  Expected [%] Got [%]\n", expected_total, it.last_total);
                valid = false;
            }

            if valid  print("OK\n");
        }
        print("\n");
        if !all_ok  exit(1);
    }
    else {
        print("\n\n");

        for entries {
            if !it_index  print("\e[0;32m");
            print("%", heap.pad_end(it.name, 20));
            first_color := "";
            if !it_index {
                print("\e[m");
                first_color = "\e[0;33m";
            }
            last_color := "";
            if it.last_time == fastest_last_time
                last_color = "\e[0;33m";
            time := sprint("%4%1%3 / %5%2%3", it.first_time, it.last_time, "\e[m", first_color, last_color);

            valid := true;
            if it.first_checksum != expected_first_checksum {
                print("BAD FIRST CHECKSUM: Expected [%] Got [%]\n", expected_first_checksum, it.first_checksum);
                valid = false;
            }
            if it.last_checksum != expected_last_checksum {
                if !valid  print("                    ");
                print("BAD LAST CHECKSUM:  Expected [%] Got [%]\n", expected_last_checksum, it.last_checksum);
                valid = false;
            }
            if it.first_total != expected_total {
                if !valid  print("                    ");
                print("BAD FIRST TOTAL:  Expected [%] Got [%]\n", expected_total, it.first_total);
                valid = false;
            }
            if it.last_checksum != expected_last_checksum {
                if !valid  print("                    ");
                print("BAD LAST TOTAL:  Expected [%] Got [%]\n", expected_total, it.last_total);
                valid = false;
            }

            if !valid {
                print("\n                    Bad checksums/totals only happen if there's a bug in the\n                    Strings library, please report it!\n\n");
                continue;
            }

            #if jai {
                format_float.width = 5;
                first_factor := sprint("%", jai_entry.first_time / it.first_time);
                last_factor :=  sprint("%", jai_entry.last_time / it.last_time);
                format_float.width = 6;
                print("%1   = %4%2x\e[m / %5%3x\e[m\n", heap.pad_start(time, 7), heap.pad_start(first_factor, 7), heap.pad_start(last_factor, 7), first_color, last_color);
            }
            else {
                print("%\n", heap.pad_end(time, 7));
            }
            if !it_index  print("\n");
        }

        print(#string __info

Results are listed for first_index / last_index, and sorted by first_index (as
first_index is used internally so is more important).  If you want to use a
different algorithm for last_index than for first_index you can use the bottom
call below with different arguments.

The winning algorithm for this dataset is: %5%1%4

To use it import with module parameters:

    %6#import "Strings"(index_algorithm = .%2);%4

or call set_index_algorithm:

    %6set_index_algorithm(%3_first_index, %3_last_index);%4
    __info, entries[0].name, entries[0].id, entries[0].prefix, "\e[m", "\e[0;32m", "\e[0;33m");
    }
}


xor :: (a: u64, b: u64) -> u64 {
    result := a;
    #asm {
        x : gpr;
        mov.q x, result;
        xor.q x, b;
        mov.q result, x;
    }
    return result;
}


jai_find_index_from_left_nocase :: (haystack: string, needle: string) -> int {
    if haystack.count < needle.count  return -1;

    for 0 .. haystack.count - needle.count {
        t := jai_string.slice(haystack, it, needle.count);
        if jai_string.equal_nocase(t, needle) return it;
    }

    return -1;
}


jai_find_index_from_right_nocase :: (haystack: string, needle: string) -> int {
    if haystack.count < needle.count  return -1;

    for < haystack.count - needle.count .. 0 {
        t := jai_string.slice(haystack, it, needle.count);
        if jai_string.equal_nocase(t, needle) return it;
    }

    return -1;
}


jai_find_index_from_left :: (s: string, substring: string) -> int {
    if !substring return -1;

    // This is SO SLOW! @Cleanup.
    for i: 0..s.count-substring.count {
        t := jai_string.slice(s, i, substring.count);
        if t == substring return i;
    }

    return -1;
}

jai_find_index_from_right :: (s: string, substring: string) -> int {
    if !substring return -1;

    // This is SO SLOW! @Cleanup.
    for < i: s.count-substring.count..0 {
        t := jai_string.slice(s, i, substring.count);
        if t == substring return i;
    }

    return -1;
}
