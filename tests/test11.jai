#import "Basic";
#import "Strings";
#import "Scratch";
jai_string :: #import "String";

#load "data/shakespeare.jai";
//#load "data/dna.jai";

main :: () {
    data := shakespeare;
    //data := "abcdefghijklm0123456789nopqrstuvwxyzABCDEFGHIJKLM0123456789NOPQRSTUVWXYZ";
    times :: 10;//1000;

    print_output :: false;

    t : float64;

    format_float := *context.print_style.default_format_float;
    format_float.zero_removal = .NO;
    format_float.width = 6;
    format_float.trailing_width = 3;

    valid := copy_string(data);
    low_index := 0;
    high_index := valid.count - 1;
    while low_index < high_index {
        c := valid[low_index];
        valid[low_index] = valid[high_index];
        valid[high_index] = c;
        low_index += 1;
        high_index -= 1;
    }
    #if print_output  print("valid:  %\n", valid);


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
                s := copy_string(data,, scratch);
                warm(s);
                t = seconds_since_init();
                reverse(*s);
                sse2_delta += seconds_since_init() - t;
                #if print_output  print("sse2:   %\n", s);
                if it == 1 && s != valid  sse2_valid = false;
                reset_temporary_storage();
            }
        }


        set_simd_mode(.AVX2);
        avx2_delta : float64;
        avx2_valid := true;
        {
            for 1..times {
                s := copy_string(data,, scratch);
                warm(s);
                t = seconds_since_init();
                reverse(*s);
                avx2_delta += seconds_since_init() - t;
                #if print_output  print("avx2:   %\n", s);
                if it == 1 &&  s != valid  avx2_valid = false;
                reset_temporary_storage();
            }
        }


        set_simd_mode(.OFF);
        scalar_delta : float64;
        scalar_valid := true;
        {
            for 1..times {
                s := copy_string(data,, scratch);
                warm(s);
                t = seconds_since_init();
                reverse(*s);
                scalar_delta += seconds_since_init() - t;
                #if print_output  print("scalar: %\n", s);
                if it == 1 && s != valid  scalar_valid = false;
                reset_temporary_storage();
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
