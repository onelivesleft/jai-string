#import "Basic";
#import "Sort";
#import "String_View";

#load "common_words.jai";
#load "shakespeare.jai";
#load "dna.jai";

#load "../String_View/boyer_moore.jai";
#load "../String_View/knuth_morris_pratt.jai";


times :: 9;


main :: () {
    //test("foo", () -> int {
    //    return count("foo foo foo foo foo", "foo");
    //});
    //exit(0);
    test("#char a", () -> int {
        return count(shakespeare, #char "a");
    });

    test("a", () -> int {
        return count(shakespeare, "a");
    });

    test("of", () -> int {
        return count(shakespeare, "of");
    });

    test("the", () -> int {
        return count(shakespeare, "the");
    });

    test("that", () -> int {
        return count(shakespeare, "that");
    });

    needle :: #string ___
Lear. O, reason not the need! Our basest beggars
     Are in the poorest thing superfluous.
     Allow not nature more than nature needs,
     Man's life is cheap as beast's. Thou art a lady:
     If only to go warm were gorgeous,
     Why, nature needs not what thou gorgeous wear'st
     Which scarcely keeps thee warm. But, for true need-
     You heavens, give me that patience, patience I need!
     You see me here, you gods, a poor old man,
     As full of grief as age; wretched in both.
     If it be you that stirs these daughters' hearts
     Against their father, fool me not so much
     To bear it tamely; touch me with noble anger,
     And let not women's weapons, water drops,
     Stain my man's cheeks! No, you unnatural hags!
     I will have such revenges on you both
     That all the world shall- I will do such things-
     What they are yet, I know not; but they shall be
     The terrors of the earth! You think I'll weep.
     No, I'll not weep.
___
    test("lear...", () -> int {
        return count(shakespeare, needle);
    });

    test("cc", () -> int {
        return count(dna, "cc");
    });

    test("ag", () -> int {
        return count(dna, "ag");
    });

    test("ccccatat...", () -> int {
        return count(dna, "ccccatatctataagtactacgccgaagatatggaccgtgtcagagccggctccttggactcacggttctgggcaaaaagtggctctactcggggacc");
    });
}


test :: (label: string, call: () -> int) {
    set_index_of_algorithm(naive_first_index_of, naive_last_index_of);
    naive, naive_min, naive_med, naive_max := time_it(call, times);

    set_index_of_algorithm(boyer_moore_first_index_of, boyer_moore_last_index_of);
    boyer_moore, boyer_moore_min, boyer_moore_med, boyer_moore_max := time_it(call, times);

    set_index_of_algorithm(knuth_morris_pratt_first_index_of, knuth_morris_pratt_last_index_of);
    knuth_morris_pratt, knuth_morris_pratt_min, knuth_morris_pratt_med, knuth_morris_pratt_max := time_it(call, times);

    print("%\n", label);
    print("% / % / % : %\n", naive, boyer_moore, knuth_morris_pratt,
        ifx naive == boyer_moore && naive == knuth_morris_pratt then "OK" else "UH-OH!");
    print("Naive:              % : % : %\n", naive_min, naive_med, naive_max);
    print("Boyer-Moore:        % : % : %\n", boyer_moore_min, boyer_moore_med, boyer_moore_max);
    print("Knuth-Morris-Pratt: % : % : %\n", knuth_morris_pratt_min, knuth_morris_pratt_med, knuth_morris_pratt_max);
    print("\n");
}


time_it :: (call: () -> int, times: int) -> result: int, minimum: float64, median: float64, maximum: float64 {
    result : int;
    dt := NewArray(times, float64);
    for i: 0 .. times - 1 {
        start_time := get_time();
        result = call();
        dt[i] = get_time() - start_time;
    }

    quick_sort(dt, (x: float64) -> float64 { return x; });
    return result, dt[0], dt[times / 2], dt[times - 1];
}
