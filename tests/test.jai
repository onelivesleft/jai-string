#import "Basic";
#import "Strings";
jai_string :: #import "String";

#load "data/shakespeare.jai";

only_problems :: false;

main :: () {
    defer {
        if errors.count != 0 {
            print("\nErrors:\n%\n", errors);
            exit(1);
        }
        else {
            print("\nAll OK!\n");
        }
    }

    haystack :: "hell yeah hell yeweeeeeeeeah";
    set_simd_mode(.SSE2);
    last_index_of_z := jai_string.find_index_from_right(haystack, "a");
    test(1, last_index(haystack, "a"), last_index_of_z);
}


errors : [..] int;

test :: (test_id: int, value: $T, expected: T) {
    if value != expected {
        print("[%]:\nWanted: [%]\nGot: [%]\n\n", test_id, expected, value);
        array_add(*errors, test_id);
    }
    else if !only_problems {
        print("[%] OK\n", test_id);
    }
}

test :: (test_id: int, value: [] string, expected: [] string) {
    if !array_equals(value, expected) {
        print("[%]:\nWanted: [%]\nGot: [%]\n\n", test_id, expected, value);
        array_add(*errors, test_id);
    }
    else if !only_problems {
        print("[%] OK\n", test_id);
    }
}

array_equals :: (a: [] $T, b: [] T) -> bool {
    if a.count != b.count  return false;
    for i: 0..a.count-1  if a[i] != b[i]  return false;
    return true;
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
