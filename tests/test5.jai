#import "Basic";

#load "data/shakespeare.jai";

main :: () {
    t : float64;

    cased := copy_string(shakespeare);
    uncased := copy_string(shakespeare);
    to_lower(uncased);


    format_float := *context.print_style.default_format_float;
    format_float.zero_removal = .NO;

    total := 0;
    for 0 .. cased.count - 1 {
        if <<cast(*u8)(cased.data + it) == <<cast(*u8)(uncased.data + it)
            total += 1;
    }

    asm_delta : float64;
    {
        t = seconds_since_init();
        total = 0;
        for 0 .. cased.count - 1{
            if asm(<<cast(*u8)(cased.data + it), <<cast(*u8)(uncased.data + it))
                total += 1;
        }
        asm_delta = seconds_since_init() - t;
        print("asm: (%) %\n", total, asm_delta);
    }

    jai_delta : float64;
    {
        t = seconds_since_init();
        total = 0;
        for 0 .. cased.count - 1{
            if jai(<<cast(*u8)(cased.data + it), <<cast(*u8)(uncased.data + it))
                total += 1;
        }
        jai_delta = seconds_since_init() - t;
        print("jai: (%) %\n", total, jai_delta);
    }

    print("\nSpeedup: %x\n", jai_delta / asm_delta);
}


asm :: (_a: u8, _b: u8) -> bool {
    ptr_a := *_a;
    ptr_b := *_b;
    result : u8 = 0; // true
    ptr_result := *result;
    #asm {
        a : gpr;
        b : gpr;
        low : gpr;
        high : gpr;
        mov.b   a, [ptr_a];
        mov.b   b, [ptr_b];
        or.b    a, 32;
        or.b    b, 32;
        xor.b   a, b;
        cmp.b   b, 97;  // a
        setl    low;
        cmp.b   b, 122; // z
        setg    high;
        or.b    a, low;
        or.b    a, high;
        mov.b   [ptr_result], a;
    }
    return result == 0;
}


jai :: (a: u8, b: u8) -> bool {
    lower_a : int = ifx a >= #char "A" && a <= #char "Z" then a + #char "a" - #char "A" else a;
    lower_b : int = ifx b >= #char "A" && b <= #char "Z" then b + #char "a" - #char "A" else b;
    return lower_a == lower_b;
}

to_lower :: (str: string) {
    for 0 .. str.count - 1 {
        if str[it] >= #char "A" && str[it] <= #char "Z" {
            c : int = str[it] + #char "a" - #char "A";
            str[it] = cast(u8) c;
        }
    }
}
