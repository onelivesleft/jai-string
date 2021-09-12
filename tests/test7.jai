#import "Basic";
#import "Time";
#import "Strings";

#load "data/shakespeare.jai";

main :: () {
    t : float64;

    format_float := *context.print_style.default_format_float;
    format_float.zero_removal = .NO;

    total := 0;
    for 0 .. shakespeare.count - 1 {
        total += <<cast(*u8)(shakespeare.data + it);
    }

    compare :: case_sensitive;

    set_simd_mode(.SSE2);
    sse_delta : float64;
    sse_total : u64;
    {
        t = get_time();
        index, found := last_index(shakespeare, #char "z", compare);
        while found {
            sse_total = xor(sse_total, xx index);
            index, found = last_index(shakespeare, #char "z", index, compare);
        }
        sse_delta = get_time() - t;
    }

    set_simd_mode(.AVX2);
    avx2_delta : float64;
    avx2_total : u64;
    {
        t = get_time();
        index, found := last_index(shakespeare, #char "z", compare);
        while found {
            avx2_total = xor(avx2_total, xx index);
            index, found = last_index(shakespeare, #char "z", index, compare);
        }
        avx2_delta = get_time() - t;
    }


    set_simd_mode(.OFF);
    scalar_delta : float64;
    scalar_total : u64;
    {
        t = get_time();
        index, found := last_index(shakespeare, #char "z", compare);
        while found {
            scalar_total = xor(scalar_total, xx index);
            index, found = last_index(shakespeare, #char "z", index, compare);
        }
        scalar_delta = get_time() - t;
    }

    print("scalar: (%) %\n", scalar_total, scalar_delta);
    print("sse:    (%) %\n", sse_total, sse_delta);
    print("avx2:   (%) %\n", avx2_total, avx2_delta);
    print("\n");
    print("SSE2  > Scalar: %x\n", scalar_delta / sse_delta);
    print("AVX2 > Scalar: %x\n", scalar_delta / avx2_delta);
    print("AVX2 > SSE2:    %x\n", sse_delta / avx2_delta);
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
