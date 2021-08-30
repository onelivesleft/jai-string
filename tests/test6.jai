#import "Basic";
#import "Time";
#import "Strings";
jai_string :: #import "String";

#load "data/shakespeare.jai";

main :: () {
    t : float64;

    format_float := *context.print_style.default_format_float;
    format_float.zero_removal = .NO;

    total := 0;
    for 0 .. shakespeare.count - 1 {
        total += <<cast(*u8)(shakespeare.data + it);
    }

    jai_delta : float64;
    jai_total : u64;
    {
        t = get_time();
        s := shakespeare;
        offset := 0;
        index := jai_string.find_index_from_left(shakespeare, #char "z");
        while index >= 0 {
            index += offset;
            jai_total = xor(jai_total, xx index);
            offset = index + 1;
            s.data = shakespeare.data + offset;
            s.count = shakespeare.count - offset;
            index = jai_string.find_index_from_left(s, #char "z");
        }
        jai_delta = get_time() - t;
    }

    compare :: case_sensitive;

    set_simd_mode(.SSE);
    sse_delta : float64;
    sse_total : u64;
    {
        t = get_time();
        index, found := first_index(shakespeare, #char "z", compare);
        while found {
            sse_total = xor(sse_total, xx index);
            index, found = first_index(shakespeare, #char "z", index + 1, compare);
        }
        sse_delta = get_time() - t;
    }

    set_simd_mode(.AVX2);
    avx2_delta : float64;
    avx2_total : u64;
    {
        t = get_time();
        index, found := first_index(shakespeare, #char "z", compare);
        while found {
            avx2_total = xor(avx2_total, xx index);
            index, found = first_index(shakespeare, #char "z", index + 1, compare);
        }
        avx2_delta = get_time() - t;
    }


    set_simd_mode(.OFF);
    scalar_delta : float64;
    scalar_total : u64;
    {
        t = get_time();
        index, found := first_index(shakespeare, #char "z", compare);
        while found {
            scalar_total = xor(scalar_total, xx index);
            index, found = first_index(shakespeare, #char "z", index + 1, compare);
        }
        scalar_delta = get_time() - t;
    }

    print("scalar: (%) %\n", scalar_total, scalar_delta);
    print("jai:    (%) %\n", jai_total, jai_delta);
    print("sse:    (%) %\n", sse_total, sse_delta);
    print("avx2:   (%) %\n", avx2_total, avx2_delta);
    print("\n");
    print("SSE  > Scalar: %x\n", scalar_delta / sse_delta);
    print("SSE  > Jai:    %x\n", jai_delta / sse_delta);
    print("\n");
    print("AVX2 > Scalar: %x\n", scalar_delta / avx2_delta);
    print("AVX2 > Jai:    %x\n",  jai_delta / avx2_delta);
    print("AVX2 > SSE:    %x\n", sse_delta / avx2_delta);
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
