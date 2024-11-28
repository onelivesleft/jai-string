#import "Basic";
#import "Strings";

#load "data/shakespeare.jai";
//#load "data/dna.jai";

/* Timings as one asm block
CASE SENSITIVE:
scalar: (24427000)  0.705
sse2:   (24427000)  0.044
avx2:   (24427000)  0.032

SSE2 > Scalar: 15.983x
AVX2 > Scalar: 22.271x
AVX2 > SSE2:    1.393x


IGNORE CASE:
scalar: (28859400)  2.564
sse2:   (28859400)  0.057
avx2:   (28859400)  0.033

SSE2 > Scalar: 45.147x
AVX2 > Scalar: 78.874x
AVX2 > SSE2:    1.747x


After 2xASM

CASE SENSITIVE:
scalar: (24427000)  0.706
sse2:   (24427000)  0.059
avx2:   (24427000)  0.023

SSE2 > Scalar: 12.044x
AVX2 > Scalar: 30.381x
AVX2 > SSE2:    2.522x


IGNORE CASE:
scalar: (28859400)  2.565
sse2:   (28859400)  0.053
avx2:   (28859400)  0.029

SSE2 > Scalar: 48.216x
AVX2 > Scalar: 87.188x
AVX2 > SSE2:    1.808x

*/

main :: () {
    haystack := shakespeare;
    needle : u8 = #char "a";
    times :: 1;

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
        set_simd_mode(.SSE2);
        sse_delta : float64;
        sse_total : int;
        {
            t = seconds_since_init();
            for 1..times  sse_total += count(haystack, needle);
            sse_delta = seconds_since_init() - t;
        }


        set_simd_mode(.AVX2);
        avx2_delta : float64;
        avx2_total : int;
        {
            t = seconds_since_init();
            for 1..times  avx2_total += count(haystack, needle);
            avx2_delta = seconds_since_init() - t;
        }


        set_simd_mode(.OFF);
        scalar_delta : float64;
        scalar_total : int;
        {
            t = seconds_since_init();
            for 1..times  scalar_total += count(haystack, needle);
            scalar_delta = seconds_since_init() - t;
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
        set_simd_mode(.SSE2);
        sse_delta : float64;
        sse_total : int;
        {
            t = seconds_since_init();
            for 1..times  sse_total += count(haystack, needle, ignore_case);
            sse_delta = seconds_since_init() - t;
        }


        set_simd_mode(.AVX2);
        avx2_delta : float64;
        avx2_total : int;
        {
            t = seconds_since_init();
            for 1..times  avx2_total += count(haystack, needle, ignore_case);
            avx2_delta = seconds_since_init() - t;
        }


        set_simd_mode(.OFF);
        scalar_delta : float64;
        scalar_total : int;
        {
            t = seconds_since_init();
            for 1..times  scalar_total += count(haystack, needle, ignore_case);
            scalar_delta = seconds_since_init() - t;
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
