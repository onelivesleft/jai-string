#import "Basic";
#import "Strings";
heap :: #import "Strings_Alloc";

#load "data/shakespeare.jai";

only_problems :: false;

main :: () {
    defer {
        if errors.count != 0
            print("\nErrors:\n%\n", errors);
        else
            print("\nAll OK!\n");
    }


    haystack :: "   Hello world in string form can you give me a hell yeah hell yeah";

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
