#import "Basic";
#import "Time";
#import "Strings";
heap :: #import "Strings_Alloc";
jai_string :: #import "String";

#load "data/shakespeare.jai";
//#load "data/dna.jai";

main :: () {
    data := shakespeare;
    times :: 1000;

    t : float64;

    format_float := *context.print_style.default_format_float;
    format_float.zero_removal = .NO;
    format_float.width = 6;
    format_float.trailing_width = 3;

    valid := copy_string(data);
    jai_string.to_upper(valid);

    warm :: (str: string) {
        total := 0;
        for 0 .. str.count - 1 {
            total += <<cast(*u8)(str.data + it);
        }
    }

    {
        set_simd_mode(.SSE2);
        sse2_delta : float64;
        sse2_valid := true;
        {
            for 1..times {
                s := heap.copy_string(data);
                warm(s);
                t = get_time();
                to_upper(s);
                sse2_delta += get_time() - t;
                if s != valid  sse2_valid = false;
            }
        }


        set_simd_mode(.AVX2);
        avx2_delta : float64;
        avx2_valid := true;
        {
            for 1..times {
                s := heap.copy_string(data);
                warm(s);
                t = get_time();
                to_upper(s);
                avx2_delta += get_time() - t;
                if s != valid  avx2_valid = false;
            }
        }


        set_simd_mode(.OFF);
        scalar_delta : float64;
        scalar_valid := true;
        {
            for 1..times {
                s := heap.copy_string(data);
                warm(s);
                t = get_time();
                to_upper(s);
                scalar_delta += get_time() - t;
                if s != valid  scalar_valid = false;
            }
        }

        print("scalar: (%) %\n", scalar_valid, scalar_delta);
        print("sse2:   (%) %\n", sse2_valid, sse2_delta);
        print("avx2:   (%) %\n", avx2_valid, avx2_delta);
        print("\n");
        print("SSE2 > Scalar: %x\n", scalar_delta / sse2_delta);
        print("AVX2 > Scalar: %x\n", scalar_delta / avx2_delta);
        print("AVX2 > SSE2:   %x\n", sse2_delta / avx2_delta);
    }
}
