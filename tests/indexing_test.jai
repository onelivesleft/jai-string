#import "Basic";
#import "Hash_Table";
#import "Sort";

jai_string :: #import "String";


#load "data/shakespeare.jai";
#load "data/degenerate.jai";

no_case :: false;
#if no_case {
    #import "Strings"(CHARACTER_COMPARE=.IGNORE_CASE);
}
else {
    #import "Strings"(CHARACTER_COMPARE=.CASE_SENSITIVE);
}

main :: () {
    haystack :: shakespeare;// degenerate;
    needle :: " and ";
    //needle :: "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffN";
    //needle :: "nffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
    //"THE end\n";//" and "; //"ffffffffffffffffffffffffffffffffffffffffn"; "zealous";
    times :: 10;
    debug :: false;

    x :: true;
    _ :: false;
    simple           :: x;
    jai              :: x;
    simple_sse2      :: x;
    simple_avx2      :: x;
    kmp              :: x;
    boyer_moore      :: x;
    boyer_moore_sse2 :: x;
    boyer_moore_avx2 :: x;


    format_float := *context.print_style.default_format_float;
    format_float.zero_removal = .NO;
    format_float.trailing_width = 3;

    #if no_case {
        find_index_from_left :: find_index_from_left_nocase;
        find_index_from_right :: find_index_from_right_nocase;
    }
    else {
        find_index_from_left :: jai_string.find_index_from_left;
        find_index_from_right :: jai_string.find_index_from_right;
    }

    first_checksum : u64;
    last_checksum : u64;

    {
        s := haystack;
        offset := 0;
        total := 0;
        index := find_index_from_left(s, needle);
        while index >= 0 {
            index += offset;
            total += 1;
            #if debug  print("%\n", index);
            first_checksum = xor(first_checksum, xx index);
            offset = index + 1;
            s.data = haystack.data + offset;
            s.count = haystack.count - offset;
            index = find_index_from_left(s, needle);
        }
        #if debug  print("\n\n");
        //print("INDEX: %\n", total);

        s = haystack;
        index = find_index_from_right(haystack, needle);
        while index >= 0 {
            last_checksum = xor(last_checksum, xx index);
            s.count = index;
            index = find_index_from_right(s, needle);
        }

        first_checksum *= times;
        last_checksum *= times;
    }


    t : float64;

    Entry :: struct {
        name : string;
        first_time : float64 = 0;
        last_time  : float64 = 0;
        first_checksum : u64 = 0;
        last_checksum  : u64 = 0;
    }

    entry :: (name: string) -> Entry {
        result : Entry;
        result.name = name;
        return result;
    }

    #if jai               jai_entry              := entry("Jai");
    #if boyer_moore       boyer_moore_entry      := entry("Boyer-Moore");
    #if boyer_moore_sse2  boyer_moore_sse2_entry := entry("Boyer-Moore SSE2");
    #if boyer_moore_avx2  boyer_moore_avx2_entry := entry("Boyer-Moore AVX2");
    #if kmp               kmp_entry              := entry("Knuth-Morris-Pratt");
    #if simple            simple_entry           := entry("Simple");
    #if simple_sse2       simple_sse2_entry      := entry("Simple SSE2");
    #if simple_avx2       simple_avx2_entry      := entry("Simple AVX2");

    prev_marker := -1;

    for 1 .. times {
        #if times >= 10 {
            marker := it / (times / 10);
            if marker != prev_marker {
                prev_marker = marker;
                if marker < 10
                    print("%", marker);
            }
        }

        #if jai {{
            t = seconds_since_init();
            s := haystack;
            offset := 0;
            index := find_index_from_left(haystack, needle);
            checksum : u64 = 0;
            while index >= 0 {
                index += offset;
                checksum = xor(checksum, xx index);
                offset = index + 1;
                s.data = haystack.data + offset;
                s.count = haystack.count - offset;
                index = find_index_from_left(s, needle);
            }
            jai_entry.first_checksum += checksum;
            jai_entry.first_time += seconds_since_init() - t;

            t = seconds_since_init();
            s = haystack;
            index = find_index_from_right(haystack, needle);
            checksum = 0;
            while index >= 0 {
                checksum = xor(checksum, xx index);
                s.count  = index;
                index = find_index_from_right(s, needle);
            }
            jai_entry.last_checksum += checksum;
            jai_entry.last_time += seconds_since_init() - t;
        }}

        #if boyer_moore {{
            set_index_algorithm(boyer_moore_first_index,boyer_moore_last_index);

            t = seconds_since_init();
            index, found := first_index(haystack, needle);
            checksum : u64 = 0;
            while found {
                checksum = xor(checksum, xx index);
                index, found = first_index(haystack, needle, index + 1);
            }
            boyer_moore_entry.first_checksum += checksum;
            boyer_moore_entry.first_time += seconds_since_init() - t;

            t = seconds_since_init();
            index, found = last_index(haystack, needle);
            checksum = 0;
            while found {
                checksum = xor(checksum, xx index);
                index, found = last_index(haystack, needle, index);
            }
            boyer_moore_entry.last_checksum += checksum;
            boyer_moore_entry.last_time += seconds_since_init() - t;
        }}

        #if boyer_moore_sse2 {{
            set_index_algorithm(boyer_moore_sse2_first_index,boyer_moore_sse2_last_index);

            t = seconds_since_init();
            index, found := first_index(haystack, needle);
            checksum : u64 = 0;
            total := 0;
            while found {
                #if debug  print("%\n", index);
                total += 1;
                checksum = xor(checksum, xx index);
                index, found = first_index(haystack, needle, index + 1);
            }
            //print("BM: %\n", total);
            boyer_moore_sse2_entry.first_checksum += checksum;
            boyer_moore_sse2_entry.first_time += seconds_since_init() - t;

            t = seconds_since_init();
            index, found = last_index(haystack, needle);
            checksum = 0;
            while found {
                checksum = xor(checksum, xx index);
                index, found = last_index(haystack, needle, index);
            }
            boyer_moore_sse2_entry.last_checksum += checksum;
            boyer_moore_sse2_entry.last_time += seconds_since_init() - t;
        }}

        #if boyer_moore_avx2 {{
            set_index_algorithm(boyer_moore_avx2_first_index,boyer_moore_avx2_last_index);

            t = seconds_since_init();
            index, found := first_index(haystack, needle);
            checksum : u64 = 0;
            total := 0;
            while found {
                #if debug  print("%\n", index);
                total += 1;
                checksum = xor(checksum, xx index);
                index, found = first_index(haystack, needle, index + 1);
            }
            //print("BM: %\n", total);
            boyer_moore_avx2_entry.first_checksum += checksum;
            boyer_moore_avx2_entry.first_time += seconds_since_init() - t;

            t = seconds_since_init();
            index, found = last_index(haystack, needle);
            checksum = 0;
            while found {
                checksum = xor(checksum, xx index);
                index, found = last_index(haystack, needle, index);
            }
            boyer_moore_avx2_entry.last_checksum += checksum;
            boyer_moore_avx2_entry.last_time += seconds_since_init() - t;
        }}

        #if kmp {{
            set_index_algorithm(knuth_morris_pratt_first_index,knuth_morris_pratt_last_index);

            t = seconds_since_init();
            index, found := first_index(haystack, needle);
            checksum : u64 = 0;
            while found {
                checksum = xor(checksum, xx index);
                index, found = first_index(haystack, needle, index + 1);
            }
            kmp_entry.first_checksum += checksum;
            kmp_entry.first_time += seconds_since_init() - t;

            t = seconds_since_init();
            index, found = last_index(haystack, needle);
            checksum = 0;
            while found {
                checksum = xor(checksum, xx index);
                index, found = last_index(haystack, needle, index);
            }
            kmp_entry.last_checksum += checksum;
            kmp_entry.last_time += seconds_since_init() - t;
        }}

        #if simple {{
            set_index_algorithm(simple_first_index, simple_last_index);

            t = seconds_since_init();
            index, found := first_index(haystack, needle);
            checksum : u64 = 0;
            while found {
                checksum = xor(checksum, xx index);
                index, found = first_index(haystack, needle, index + 1);
            }
            simple_entry.first_checksum += checksum;
            simple_entry.first_time += seconds_since_init() - t;

            t = seconds_since_init();
            index, found = last_index(haystack, needle);
            checksum = 0;
            while found {
                checksum = xor(checksum, xx index);
                index, found = last_index(haystack, needle, index);
            }
            simple_entry.last_checksum += checksum;
            simple_entry.last_time += seconds_since_init() - t;
        }}

        #if simple_sse2 {{
            set_index_algorithm(simple_sse2_first_index, simple_sse2_last_index);

            t = seconds_since_init();
            index, found := first_index(haystack, needle);
            checksum : u64 = 0;
            while found {
                checksum = xor(checksum, xx index);
                index, found = first_index(haystack, needle, index + 1);
            }
            simple_sse2_entry.first_checksum += checksum;
            simple_sse2_entry.first_time += seconds_since_init() - t;

            t = seconds_since_init();
            index, found = last_index(haystack, needle);
            checksum = 0;
            while found {
                checksum = xor(checksum, xx index);
                index, found = last_index(haystack, needle, index);
            }
            simple_sse2_entry.last_checksum += checksum;
            simple_sse2_entry.last_time += seconds_since_init() - t;
        }}

        #if simple_avx2 {{
            set_index_algorithm(simple_avx2_first_index, simple_avx2_last_index);

            t = seconds_since_init();
            index, found := first_index(haystack, needle);
            checksum : u64 = 0;
            while found {
                checksum = xor(checksum, xx index);
                index, found = first_index(haystack, needle, index + 1);
            }
            simple_avx2_entry.first_checksum += checksum;
            simple_avx2_entry.first_time += seconds_since_init() - t;

            t = seconds_since_init();
            index, found = last_index(haystack, needle);
            checksum = 0;
            while found {
                checksum = xor(checksum, xx index);
                index, found = last_index(haystack, needle, index);
            }
            simple_avx2_entry.last_checksum += checksum;
            simple_avx2_entry.last_time += seconds_since_init() - t;
        }}
    }



    entries : [..] Entry;

    #if jai               array_add(*entries, jai_entry);
    #if kmp               array_add(*entries, kmp_entry);
    #if boyer_moore       array_add(*entries, boyer_moore_entry);
    #if boyer_moore_sse2  array_add(*entries, boyer_moore_sse2_entry);
    #if boyer_moore_avx2  array_add(*entries, boyer_moore_avx2_entry);
    #if simple            array_add(*entries, simple_entry);
    #if simple_sse2       array_add(*entries, simple_sse2_entry);
    #if simple_avx2       array_add(*entries, simple_avx2_entry);

    quick_sort(entries, (a: Entry) -> float64 { return a.first_time; });

    print("\n\n");

    for entries {
        print("%", pad_end(it.name, 20));
        time := sprint("% / %", it.first_time, it.last_time);
        if it.first_checksum != first_checksum {
            print("BAD FIRST CHECKSUM: % != %\n", it.first_checksum, first_checksum);
            if it.last_checksum != last_checksum
                print("                    BAD LAST CHECKSUM: % != %\n", it.last_checksum, last_checksum);
            continue;
        }
        else if it.last_checksum != last_checksum {
            print("BAD LAST CHECKSUM: % != %\n", it.last_checksum, last_checksum);
            continue;
        }

        #if jai {
            first_factor := sprint("%", jai_entry.first_time / it.first_time);
            last_factor :=  sprint("%", jai_entry.last_time / it.last_time);
            print("%   = %x / %x\n", pad_start(time, 7), pad_start(first_factor, 7), pad_start(last_factor, 7));
        }
        else {
            print("% %\n", it.first_checksum, pad_end(time, 7));
        }
        if !it_index  print("\n");
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


find_index_from_left_nocase :: (haystack: string, needle: string) -> int {
    if haystack.count < needle.count  return -1;

    for 0 .. haystack.count - needle.count {
        t := jai_string.slice(haystack, it, needle.count);
        if jai_string.equal_nocase(t, needle) return it;
    }

    return -1;
}


find_index_from_right_nocase :: (haystack: string, needle: string) -> int {
    if haystack.count < needle.count  return -1;

    for < haystack.count - needle.count .. 0 {
        t := jai_string.slice(haystack, it, needle.count);
        if jai_string.equal_nocase(t, needle) return it;
    }

    return -1;
}
