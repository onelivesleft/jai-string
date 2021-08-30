#import "Basic";
#import "Strings";
heap :: #import "Strings_Alloc";
#import "Time";

//#load "data/common_words.jai";
//#load "data/shakespeare.jai";
//#load "data/dna.jai";
#load "data/degenerate.jai";


main :: () {
    t : float64;

    serial_haystack := heap.copy(degenerate);
    simd_haystack := heap.copy(degenerate);
    table : [] Character_Translation = .[Character_Translation.{#char "f", #char "F"}];

    format_float := *context.print_style.default_format_float;
    format_float.zero_removal = .NO;


    serial_delta : float64;
    serial_changes : int;
    {
        t = get_time();
        serial_changes = replace(serial_haystack, table);
        serial_delta = get_time() - t;
        print("Serial: (%) %\n", serial_changes, serial_delta);
    }

    simd_delta : float64;
    simd_changes : int;
    {
        t = get_time();
        simd_changes = simd_replace(simd_haystack, table);
        simd_delta = get_time() - t;
        print("SIMD: (%) %\n", simd_changes, simd_delta);
    }

    print("\nSpeedup: %x\n", serial_delta / simd_delta);
}
