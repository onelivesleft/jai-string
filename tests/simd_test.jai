#import "Basic";
#import "Strings";
jai_string :: #import "String";

#load "data/shakespeare.jai";

only_problems :: true;

main :: () {
    defer {
        if errors.count != 0
            print("\nErrors:\n%\n", errors);
        else
            print("\nAll OK!\n");
    }

    // calculate_checksums_from_jai_string();
    index_case_sensitive_checksum :: 5029604;
    index_ignore_case_checksum :: 2957927;

    haystack :: "   Hello world in string form can you give me a hell yeah hell yeah";

    for simd: 0 .. 3 {
        set_simd_mode(xx simd);

        x := (simd + 1) * 100;

        test( 1 + x, first_index(haystack, #char "H", case_sensitive),  3);
        test( 2 + x, first_index(haystack, #char "h", case_sensitive), 48);
        test( 3 + x, first_index(haystack, #char "E", case_sensitive), -1);
        test( 4 + x, first_index(haystack, #char "e", case_sensitive),  4);
        test( 5 + x, first_index(haystack, #char "L", case_sensitive), -1);
        test( 6 + x, first_index(haystack, #char "l", case_sensitive),  5);
        test( 7 + x, first_index(haystack, #char "O", case_sensitive), -1);
        test( 8 + x, first_index(haystack, #char "o", case_sensitive),  7);
        test( 9 + x, first_index(haystack, #char " ", case_sensitive),  0);
        test(10 + x, first_index(haystack, #char "W", case_sensitive), -1);
        test(11 + x, first_index(haystack, #char "w", case_sensitive),  9);
        test(12 + x, first_index(haystack, #char "R", case_sensitive), -1);
        test(13 + x, first_index(haystack, #char "r", case_sensitive), 11);
        test(14 + x, first_index(haystack, #char "D", case_sensitive), -1);
        test(15 + x, first_index(haystack, #char "d", case_sensitive), 13);
        test(16 + x, first_index(haystack, #char "m", case_sensitive), 28);
        test(17 + x, first_index(haystack, #char "A", case_sensitive), -1);
        test(18 + x, first_index(haystack, #char "a", case_sensitive), 31);
        test(19 + x, first_index(haystack, #char "Z", case_sensitive), -1);
        test(20 + x, first_index(haystack, #char "z", case_sensitive), -1);

        test(21 + x, first_index(haystack, #char "H", ignore_case),  3);
        test(22 + x, first_index(haystack, #char "h", ignore_case),  3);
        test(23 + x, first_index(haystack, #char "E", ignore_case),  4);
        test(24 + x, first_index(haystack, #char "e", ignore_case),  4);
        test(25 + x, first_index(haystack, #char "L", ignore_case),  5);
        test(26 + x, first_index(haystack, #char "l", ignore_case),  5);
        test(27 + x, first_index(haystack, #char "O", ignore_case),  7);
        test(28 + x, first_index(haystack, #char "o", ignore_case),  7);
        test(29 + x, first_index(haystack, #char " ", ignore_case),  0);
        test(30 + x, first_index(haystack, #char "W", ignore_case),  9);
        test(31 + x, first_index(haystack, #char "w", ignore_case),  9);
        test(32 + x, first_index(haystack, #char "R", ignore_case), 11);
        test(33 + x, first_index(haystack, #char "r", ignore_case), 11);
        test(34 + x, first_index(haystack, #char "D", ignore_case), 13);
        test(35 + x, first_index(haystack, #char "d", ignore_case), 13);
        test(36 + x, first_index(haystack, #char "m", ignore_case), 28);
        test(37 + x, first_index(haystack, #char "A", ignore_case), 31);
        test(38 + x, first_index(haystack, #char "a", ignore_case), 31);
        test(39 + x, first_index(haystack, #char "Z", ignore_case), -1);
        test(40 + x, first_index(haystack, #char "z", ignore_case), -1);

        test(41 + x, last_index(haystack, #char "H", case_sensitive),  3);
        test(42 + x, last_index(haystack, #char "h", case_sensitive), 66);
        test(43 + x, last_index(haystack, #char "E", case_sensitive), -1);
        test(44 + x, last_index(haystack, #char "e", case_sensitive), 64);
        test(45 + x, last_index(haystack, #char "L", case_sensitive), -1);
        test(46 + x, last_index(haystack, #char "l", case_sensitive), 61);
        test(47 + x, last_index(haystack, #char "O", case_sensitive), -1);
        test(48 + x, last_index(haystack, #char "o", case_sensitive), 35);
        test(49 + x, last_index(haystack, #char " ", case_sensitive), 62);
        test(50 + x, last_index(haystack, #char "W", case_sensitive), -1);
        test(51 + x, last_index(haystack, #char "w", case_sensitive),  9);
        test(52 + x, last_index(haystack, #char "R", case_sensitive), -1);
        test(53 + x, last_index(haystack, #char "r", case_sensitive), 27);
        test(54 + x, last_index(haystack, #char "D", case_sensitive), -1);
        test(55 + x, last_index(haystack, #char "d", case_sensitive), 13);
        test(56 + x, last_index(haystack, #char "m", case_sensitive), 43);
        test(57 + x, last_index(haystack, #char "A", case_sensitive), -1);
        test(58 + x, last_index(haystack, #char "a", case_sensitive), 65);
        test(59 + x, last_index(haystack, #char "Z", case_sensitive), -1);
        test(60 + x, last_index(haystack, #char "z", case_sensitive), -1);

        test(61 + x, last_index(haystack, #char "H", ignore_case), 66);
        test(62 + x, last_index(haystack, #char "h", ignore_case), 66);
        test(63 + x, last_index(haystack, #char "E", ignore_case), 64);
        test(64 + x, last_index(haystack, #char "e", ignore_case), 64);
        test(65 + x, last_index(haystack, #char "L", ignore_case), 61);
        test(66 + x, last_index(haystack, #char "l", ignore_case), 61);
        test(67 + x, last_index(haystack, #char "O", ignore_case), 35);
        test(68 + x, last_index(haystack, #char "o", ignore_case), 35);
        test(69 + x, last_index(haystack, #char " ", ignore_case), 62);
        test(70 + x, last_index(haystack, #char "W", ignore_case),  9);
        test(71 + x, last_index(haystack, #char "w", ignore_case),  9);
        test(72 + x, last_index(haystack, #char "R", ignore_case), 27);
        test(73 + x, last_index(haystack, #char "r", ignore_case), 27);
        test(74 + x, last_index(haystack, #char "D", ignore_case), 13);
        test(75 + x, last_index(haystack, #char "d", ignore_case), 13);
        test(76 + x, last_index(haystack, #char "m", ignore_case), 43);
        test(77 + x, last_index(haystack, #char "A", ignore_case), 65);
        test(78 + x, last_index(haystack, #char "a", ignore_case), 65);
        test(79 + x, last_index(haystack, #char "Z", ignore_case), -1);
        test(80 + x, last_index(haystack, #char "z", ignore_case), -1);

        checksum : u64;
        index, found := first_index(shakespeare, #char "z", case_sensitive);
        while found {
            checksum = xor(checksum, xx index);
            index, found = first_index(shakespeare, #char "z", index + 1, case_sensitive);
        }
        test(81 + x, checksum, index_case_sensitive_checksum);

        checksum = 0;
        index, found = last_index(shakespeare, #char "z", case_sensitive);
        while found {
            checksum = xor(checksum, xx index);
            index, found = last_index(shakespeare, #char "z", index, case_sensitive);
        }
        test(82 + x, checksum, index_case_sensitive_checksum);


        checksum = 0;
        index, found = first_index(shakespeare, #char "z", ignore_case);
        while found {
            checksum = xor(checksum, xx index);
            index, found = first_index(shakespeare, #char "z", index + 1, ignore_case);
        }
        test(83 + x, checksum, index_ignore_case_checksum);


        checksum = 0;
        index, found = last_index(shakespeare, #char "z", ignore_case);
        while found {
            checksum = xor(checksum, xx index);
            index, found = last_index(shakespeare, #char "z", index, ignore_case);
        }
        test(84 + x, checksum, index_ignore_case_checksum);
    }
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


calculate_checksums_from_jai_string :: () {
    s := shakespeare;
    offset := 0;
    first_index_case_sensitive_checksum : u64;
    index := jai_string.find_index_from_left(shakespeare, #char "z");
    while index >= 0 {
        index += offset;
        first_index_case_sensitive_checksum = xor(first_index_case_sensitive_checksum, xx index);
        offset = index + 1;
        s.data = shakespeare.data + offset;
        s.count = shakespeare.count - offset;
        index = jai_string.find_index_from_left(s, #char "z");
    }

    s = shakespeare;
    offset = 0;
    first_index_ignore_case_checksum : u64;
    index = jai_string.find_index_of_any_from_left(shakespeare, "zZ");
    while index >= 0 {
        index += offset;
        first_index_ignore_case_checksum = xor(first_index_ignore_case_checksum, xx index);
        offset = index + 1;
        s.data = shakespeare.data + offset;
        s.count = shakespeare.count - offset;
        index = jai_string.find_index_of_any_from_left(s, "zZ");
    }

    s = shakespeare;
    last_index_case_sensitive_checksum : u64;
    index = jai_string.find_index_from_right(shakespeare, #char "z");
    while index >= 0 {
        last_index_case_sensitive_checksum = xor(last_index_case_sensitive_checksum, xx index);
        s.count = index;
        index = jai_string.find_index_from_right(s, #char "z");
    }

    s = shakespeare;
    last_index_ignore_case_checksum : u64;
    index = jai_string.find_index_of_any_from_right(shakespeare, "zZ");
    while index >= 0 {
        last_index_ignore_case_checksum = xor(last_index_ignore_case_checksum, xx index);
        s.count = index;
        index = jai_string.find_index_of_any_from_right(s, "zZ");
    }

    print("first_index_case_sensitive_checksum: %\n", first_index_case_sensitive_checksum);
    print("first_index_ignore_case_checksum: %\n", first_index_ignore_case_checksum);
    print("last_index_case_sensitive_checksum: %\n", last_index_case_sensitive_checksum);
    print("last_index_ignore_case_checksum: %\n", last_index_ignore_case_checksum);
}
