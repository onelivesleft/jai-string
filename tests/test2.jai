#import "Basic";
#import "Strings";
#import "Time";

//#load "data/common_words.jai";
#load "data/shakespeare.jai";
//#load "data/dna.jai";
//#load "data/degenerate.jai";


main :: () {
    count :: 1;
    t : float64;

    haystack := shakespeare;
    needle : u8 = #char "z";

    format_float := *context.print_style.default_format_float;
    format_float.zero_removal = .NO;


    {
        index := 0;
        for 1 .. count {
            index_a := basic_first_index(haystack, needle, index + 1);
            index_b := first_index(haystack, needle, index + 1);
            assert(haystack[index_a] == needle);
            assert(index_a == index_b);
            index = index_a;
        }
    }


    simd_delta : float64;
    {
        t = get_time();
        index := 0;
        for 1 .. count
            index = first_index(haystack, needle, index + 1);
        simd_delta = get_time() - t;
        print("SIMD: %\n", simd_delta);
    }

    serial_delta : float64;
    {
        t = get_time();
        index := 0;
        for 1 .. count
            index = basic_first_index(haystack, needle, index + 1);
        serial_delta = get_time() - t;
        print("Serial: %\n", serial_delta);
    }

    print("\nSpeedup: %x\n", serial_delta / simd_delta);
}
