#import "Basic";
#import "Time";
#import "Strings"(index_algorithm=.NAIVE);
jai_string :: #import "String";

#load "../Strings_Shared/boyer_moore.jai";
#load "../Strings_Shared/knuth_morris_pratt.jai";

#load "data/shakespeare.jai";

main :: () {
    t : float64;

    format_float := *context.print_style.default_format_float;
    format_float.zero_removal = .NO;

    total := 0;
    for 0 .. shakespeare.count - 1 {
        total += <<cast(*u8)(shakespeare.data + it);
    }


    needle :: " and ";
    times :: 1000;
    //needle :: "zealous";

    jai :: false;
    string_compare :: false;
    char_compare :: false;
    kmp :: false;
    simd_off :: false;
    sse :: true;
    avx2 :: false;
    boyer_moore :: false;


    jai_compare_delta : float64;
    jai_compare_total : u64;
    string_compare_delta : float64;
    string_compare_total : u64;
    kmp_delta : float64;
    kmp_total : u64;
    char_compare_delta : float64;
    char_compare_total : u64;
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
        {
            t = get_time();
            s := shakespeare;
            offset := 0;
            index := jai_string.find_index_from_left(shakespeare, needle);
            while index >= 0 {
                index += offset;
                jai_compare_total = xor(jai_compare_total, xx (index + it));
                offset = index + 1;
                s.data = shakespeare.data + offset;
                s.count = shakespeare.count - offset;
                index = jai_string.find_index_from_left(s, needle);
            }
            jai_compare_delta += get_time() - t;
        }

        #if string_compare
        {
            set_index_algorithm(naive_with_string_compare_first_index);
            t = get_time();
            index, found := first_index(shakespeare, needle);
            while found {
                string_compare_total = xor(string_compare_total, xx (index + it));
                index, found = first_index(shakespeare, needle, index + 1);
            }
            string_compare_delta += get_time() - t;
        }

        #if kmp
        {
            set_index_algorithm(knuth_morris_pratt_first_index);
            t = get_time();
            index, found := first_index(shakespeare, needle);
            while found {
                kmp_total = xor(kmp_total, xx (index + it));
                index, found = first_index(shakespeare, needle, index + 1);
            }
            kmp_delta += get_time() - t;
        }

        #if char_compare
        {
            set_index_algorithm(naive_with_char_compare_first_index);
            set_simd_mode(.OFF);
            t = get_time();
            index, found := first_index(shakespeare, needle);
            while found {
                char_compare_total = xor(char_compare_total, xx (index + it));
                index, found = first_index(shakespeare, needle, index + 1);
            }
            char_compare_delta += get_time() - t;
        }

        #if simd_off
        {
            set_index_algorithm(naive_with_simd_first_index);
            set_simd_mode(.OFF);
            t = get_time();
            index, found := first_index(shakespeare, needle);
            while found {
                simd_off_total = xor(simd_off_total, xx (index + it));
                index, found = first_index(shakespeare, needle, index + 1);
            }
            simd_off_delta += get_time() - t;
        }

        #if sse
        {
            set_index_algorithm(naive_with_simd_first_index);
            set_simd_mode(.SSE);
            t = get_time();
            index, found := first_index(shakespeare, needle);
            while found {
                sse_total = xor(sse_total, xx (index + it));
                index, found = first_index(shakespeare, needle, index + 1);
            }
            sse_delta += get_time() - t;
        }

        #if avx2
        {
            set_index_algorithm(naive_with_simd_first_index);
            set_simd_mode(.AVX2);
            t = get_time();
            index, found := first_index(shakespeare, needle);
            while found {
                avx2_total = xor(avx2_total, xx (index + it));
                index, found = first_index(shakespeare, needle, index + 1);
            }
            avx2_delta += get_time() - t;
        }

        #if boyer_moore
        {
            set_index_algorithm(boyer_moore_first_index);
            t = get_time();
            index, found := first_index(shakespeare, needle);
            while found {
                boyer_moore_total = xor(boyer_moore_total, xx (index + it));
                index, found = first_index(shakespeare, needle, index + 1);
            }
            boyer_moore_delta += get_time() - t;
        }
    }



    print("\n");
    #if jai             print("jai:            (%) %\n", jai_compare_total, jai_compare_delta);
    #if string_compare  print("string compare: (%) %\n", string_compare_total, string_compare_delta);
    #if kmp             print("KMP:            (%) %\n", kmp_total, kmp_delta);
    #if char_compare    print("char compare:   (%) %\n", char_compare_total, char_compare_delta);
    #if simd_off        print("simd off:       (%) %\n", simd_off_total, simd_off_delta);
    #if boyer_moore     print("boyer-moore:    (%) %\n", boyer_moore_total, boyer_moore_delta);
    #if sse             print("SSE:            (%) %\n", sse_total, sse_delta);
    #if avx2            print("AVX2:           (%) %\n", avx2_total, avx2_delta);
    #if jai {
        print("\n");
        print("Speedup Factor:\n");
        #if string_compare  print("string compare: %x\n", jai_compare_delta / string_compare_delta);
        #if kmp             print("KMP:            %x\n", jai_compare_delta / kmp_delta);
        #if char_compare    print("char compare:   %x\n", jai_compare_delta / char_compare_delta);
        #if simd_off        print("simd off:       %x\n", jai_compare_delta / simd_off_delta);
        #if boyer_moore     print("boyer-moore:    %x\n", jai_compare_delta / boyer_moore_delta);
        #if sse             print("SSE:            %x\n", jai_compare_delta / sse_delta);
        #if avx2            print("AVX2:           %x\n", jai_compare_delta / avx2_delta);
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
