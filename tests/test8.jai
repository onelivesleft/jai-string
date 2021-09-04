#import "Basic";
#import "Sort";
#import "Time";
#import "Strings"(index_algorithm=.NAIVE);
heap :: #import "Strings_Alloc";
jai_string :: #import "String";

#load "../Strings_Shared/boyer_moore.jai";
#load "../Strings_Shared/knuth_morris_pratt.jai";

#load "data/shakespeare.jai";
#load "data/degenerate.jai";


main :: () {
    haystack :: shakespeare;// degenerate;
    needle :: " and "; //"ffffffffffffffffffffffffffffffffffffffffn";
    times :: 3000;
    //needle :: "zealous";

    jai         :: false;
    boyer_moore :: false;
    kmp         :: false;
    simd_off    :: false;
    sse         :: true;
    avx2        :: false;


    format_float := *context.print_style.default_format_float;
    format_float.zero_removal = .NO;
    format_float.trailing_width = 3;

    checksum : u64;
    {
        s := haystack;
        offset := 0;
        index := jai_string.find_index_from_left(s, needle);
        while index >= 0 {
            index += offset;
            checksum = xor(checksum, xx index);
            offset = index + 1;
            s.data = haystack.data + offset;
            s.count = haystack.count - offset;
            index = jai_string.find_index_from_left(s, needle);
        }
        checksum *= times;
    }

    t : float64;



    jai_delta : float64;
    jai_total : u64;
    kmp_delta : float64;
    kmp_total : u64;
    simd_off_delta : float64;
    simd_off_total : u64;
    sse_delta : float64;
    sse_total : u64;
    avx2_delta : float64;
    avx2_total : u64;
    boyer_moore_delta : float64;
    boyer_moore_total : u64;


    for 1 .. times {
        print("%", it % 10);
        #if jai
        {{
            t = get_time();
            s := haystack;
            offset := 0;
            index := jai_string.find_index_from_left(haystack, needle);
            total : u64 = 0;
            while index >= 0 {
                index += offset;
                total = xor(total, xx index);
                offset = index + 1;
                s.data = haystack.data + offset;
                s.count = haystack.count - offset;
                index = jai_string.find_index_from_left(s, needle);
            }
            jai_total += total;
            jai_delta += get_time() - t;
        }}

        #if boyer_moore
        {{
            set_index_algorithm(boyer_moore_first_index);
            t = get_time();
            index, found := first_index(haystack, needle);
            total : u64 = 0;
            while found {
                total = xor(total, xx index);
                index, found = first_index(haystack, needle, index + 1);
            }
            boyer_moore_total += total;
            boyer_moore_delta += get_time() - t;
        }}

        #if kmp
        {{
            set_index_algorithm(knuth_morris_pratt_first_index);
            t = get_time();
            index, found := first_index(haystack, needle);
            total : u64 = 0;
            while found {
                total = xor(total, xx index);
                index, found = first_index(haystack, needle, index + 1);
            }
            kmp_total += total;
            kmp_delta += get_time() - t;
        }}

        #if simd_off
        {{
            set_index_algorithm(naive_with_simd_first_index);
            set_simd_mode(.OFF);
            t = get_time();
            index, found := first_index(haystack, needle);
            total : u64 = 0;
            while found {
                total = xor(total, xx index);
                index, found = first_index(haystack, needle, index + 1);
            }
            simd_off_total += total;
            simd_off_delta += get_time() - t;
        }}

        #if sse
        {{
            set_index_algorithm(naive_with_simd_first_index);
            set_simd_mode(.SSE);
            t = get_time();
            index, found := first_index(haystack, needle);
            total : u64 = 0;
            while found {
                total = xor(total, xx index);
                index, found = first_index(haystack, needle, index + 1);
            }
            sse_total += total;
            sse_delta += get_time() - t;
        }}

        #if avx2
        {{
            set_index_algorithm(naive_with_simd_first_index);
            set_simd_mode(.AVX2);
            t = get_time();
            index, found := first_index(haystack, needle);
            total : u64 = 0;
            while found {
                total = xor(total, xx index);
                index, found = first_index(haystack, needle, index + 1);
            }
            avx2_total += total;
            avx2_delta += get_time() - t;
        }}
    }


    Entry :: struct {
        name : string;
        time : float64;
        checksum : u64;
    }

    entry :: (name: string, time: float64, checksum: u64) -> Entry {
        result : Entry = ---;
        result.name = name;
        result.time = time;
        result.checksum = checksum;
        return result;
    }

    entries : [..] Entry;

    #if jai          array_add(*entries, entry("Jai", jai_delta, jai_total));
    #if kmp          array_add(*entries, entry("Knuth-Morris-Pratt", kmp_delta, kmp_total));
    #if boyer_moore  array_add(*entries, entry("Boyer-Moore", boyer_moore_delta, boyer_moore_total));
    #if simd_off     array_add(*entries, entry("Naive", simd_off_delta, simd_off_total));
    #if sse          array_add(*entries, entry("Naive + SSE", sse_delta, sse_total));
    #if avx2         array_add(*entries, entry("Naive + AVX2", avx2_delta, avx2_total));

    quick_sort(entries, (a: Entry) -> float64 { return a.time; });

    print("\n\n");

    for entries {
        print("%", heap.pad_end(it.name, 20));
        time := sprint("%", it.time);
        if it.checksum != checksum {
            print("BAD CHECKSUM: % != %\n", it.checksum, checksum);
            continue;
        }

        #if jai {
            factor := sprint("%", jai_delta / it.time);
            print("%   = %x\n", heap.pad_start(time, 7), heap.pad_start(factor, 7));
        }
        else {
            print("%\n", heap.pad_end(time, 7));
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
