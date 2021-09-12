#import "Basic";
#import "Time";
#import "Strings";

#load "data/shakespeare.jai";
//#load "data/dna.jai";

main :: () {
    haystack := shakespeare;
    needle : u8 = #char "a";
    times :: 1000;

    t : float64;

    format_float := *context.print_style.default_format_float;
    format_float.zero_removal = .NO;
    format_float.width = 6;
    format_float.trailing_width = 3;

    total := 0;
    for 0 .. haystack.count - 1 {
        total += <<cast(*u8)(haystack.data + it);
    }

    {
        set_default_compare(case_sensitive);

        set_simd_mode(.SSE2);
        sse_delta : float64;
        sse_total : int;
        {
            t = get_time();
            for 1..times  sse_total += count(haystack, needle);
            sse_delta = get_time() - t;
        }


        set_simd_mode(.AVX2);
        avx2_delta : float64;
        avx2_total : int;
        {
            t = get_time();
            for 1..times  avx2_total += count(haystack, needle);
            avx2_delta = get_time() - t;
        }


        set_simd_mode(.OFF);
        scalar_delta : float64;
        scalar_total : int;
        {
            t = get_time();
            for 1..times  scalar_total += count(haystack, needle);
            scalar_delta = get_time() - t;
        }

        print("CASE SENSITIVE:\n");
        print("scalar: (%) %\n", scalar_total, scalar_delta);
        print("sse2:   (%) %\n", sse_total, sse_delta);
        print("avx2:   (%) %\n", avx2_total, avx2_delta);
        print("\n");
        print("SSE2 > Scalar: %x\n", scalar_delta / sse_delta);
        print("AVX2 > Scalar: %x\n", scalar_delta / avx2_delta);
        print("AVX2 > SSE2:   %x\n", sse_delta / avx2_delta);
    }

    {
        set_default_compare(ignore_case);

        set_simd_mode(.SSE2);
        sse_delta : float64;
        sse_total : int;
        {
            t = get_time();
            for 1..times  sse_total += count(haystack, needle);
            sse_delta = get_time() - t;
        }


        set_simd_mode(.AVX2);
        avx2_delta : float64;
        avx2_total : int;
        {
            t = get_time();
            for 1..times  avx2_total += count(haystack, needle);
            avx2_delta = get_time() - t;
        }


        set_simd_mode(.OFF);
        scalar_delta : float64;
        scalar_total : int;
        {
            t = get_time();
            for 1..times  scalar_total += count(haystack, needle);
            scalar_delta = get_time() - t;
        }

        print("\n\nIGNORE CASE:\n");
        print("scalar: (%) %\n", scalar_total, scalar_delta);
        print("sse2:   (%) %\n", sse_total, sse_delta);
        print("avx2:   (%) %\n", avx2_total, avx2_delta);
        print("\n");
        print("SSE2 > Scalar: %x\n", scalar_delta / sse_delta);
        print("AVX2 > Scalar: %x\n", scalar_delta / avx2_delta);
        print("AVX2 > SSE2:   %x\n", sse_delta / avx2_delta);
    }
}
