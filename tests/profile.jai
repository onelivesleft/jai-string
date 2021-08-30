#import "Basic";
#import "Random";
#import "Sort";
#import "Strings";
#import "Time";

#load "data/common_words.jai";
#load "data/shakespeare.jai";
#load "data/dna.jai";
#load "data/degenerate.jai";

//#load "../Strings/boyer_moore.jai";
#load "../Strings/knuth_morris_pratt.jai";


times :: 23;


main :: () {
    char : u8 = #char "z";
    test(char, (char: u8) -> int {
        return first_index(shakespeare, char);
    });
    dynamic := get_command_line_arguments().count > 1;
    if dynamic   return;

    random_word : [3] u8;
    while dynamic {
        random_seed(cast,no_check(s32) get_current_file_time());
        dice := random_get() % 3;
        if dice == {
            case 1;
            word := common_words[random_get() % common_words.count];
            test(word, (word: string) -> int {
                return count(shakespeare, word, compare = cmp);
            });

            case 2;
            length := random_get() % 2 + 2;
            for i: 0 .. length - 1 {
                random_word[i] = cast,no_check(u8)(random_get() % 26 + #char "a");
            }
            //random_word_string := cast(string) random_word; //@TODO huh?
            random_word_string : string = ---;
            random_word_string.count = 3;
            random_word_string.data = *random_word[0];
            pattern := substring(random_word_string, 0, length);
            test(pattern, (pattern: string) -> int {
                return count(shakespeare, pattern, compare = cmp_ignore);
            });

            case 3;
            random_word_string := "wf";
            pattern := slice(random_word_string, 0, 2);
            test(pattern, (pattern: string) -> int {
                return count(shakespeare, pattern, compare = cmp_ignore);
            });

            case 4;
            random_word_string := "gas";
            pattern := slice(random_word_string, 0, 3);
            test(pattern, (pattern: string) -> int {
                return count(shakespeare, pattern, compare = cmp_ignore);
            });

            case 5;
            random_word_string := "vdb";
            pattern := slice(random_word_string, 0, 3);
            test(pattern, (pattern: string) -> int {
                return count(shakespeare, pattern, compare = cmp_ignore);
            });

            case;
            i := random_get() % (dna.count - 100);
            length := random_get() % 100;
            pattern := substring(dna, i, length);
            test(pattern, (pattern: string) -> int {
                return count(dna, pattern, compare = cmp);
            });
        }
    }
    //test("foo", () -> int {
    //    return count("foo foo foo foo foo", "foo");
    //});
    //exit(0);
    test("#char a", (needle: string) -> int {
        return count(shakespeare, #char "a");
    });

    test("a", (needle: string) -> int {
        return count(shakespeare, needle, compare = cmp);
    });

    test("of", (needle: string) -> int {
        return count(shakespeare, needle, compare = cmp);
    });

    test("the", (needle: string) -> int {
        return count(shakespeare, needle, compare = cmp);
    });

    test("that", (needle: string) -> int {
        return count(shakespeare, needle, compare = cmp);
    });

    lear :: #string ___
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
    test(lear, (needle: string) -> int {
        return count(shakespeare, needle, compare = cmp);
    });

    test("cc", (needle: string) -> int {
        return count(dna, needle, compare = cmp);
    });

    test("ag", (needle: string) -> int {
        return count(dna, needle, compare = cmp);
    });

    test("ccccatatctataagtactacgccgaagatatggaccgtgtcagagccggctccttggac", (needle: string) -> int {
        return count(dna, needle, compare = cmp);
    });

    test("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", (needle: string) -> int {
        return count(dna, needle, compare = cmp);
    });

    test("ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffnffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", (needle: string) -> int {
        return count(degenerate, needle, compare = cmp);
    });
}


test :: (needle: $T, call: (T) -> int) {
    set_index_algorithm(naive_first_index, naive_last_index);
    naive_cmps := cmp_count;
    naive, naive_min, naive_med, naive_max := time_it(call, needle, times);
    naive_cmps = cmp_count - naive_cmps;

    set_index_algorithm(boyer_moore_first_index, boyer_moore_last_index);
    boyer_moore_cmps := cmp_count;
    boyer_moore, boyer_moore_min, boyer_moore_med, boyer_moore_max := time_it(call, needle, times);
    boyer_moore_cmps = cmp_count - boyer_moore_cmps;

    set_index_algorithm(knuth_morris_pratt_first_index, knuth_morris_pratt_last_index);
    knuth_morris_pratt_cmps := cmp_count;
    knuth_morris_pratt, knuth_morris_pratt_min, knuth_morris_pratt_med, knuth_morris_pratt_max := time_it(call, needle, times);
    knuth_morris_pratt_cmps = cmp_count - knuth_morris_pratt_cmps;

    #if T == string {
        if needle.count > 100
            print("\"%(%)...\" ", substring(needle, 0, 10), needle.count);
        else
            print("\"%\" ", needle);
    }
    else #if T == u8 {
        print("'%' ", string_from_char(*needle));
    }
    else {
        print("% ", needle);
    }
    print("% / % / % : %\n", naive, boyer_moore, knuth_morris_pratt,
        ifx naive == boyer_moore && naive == knuth_morris_pratt then "OK" else "UH-OH! UH-OH! UH-OH! UH-OH! UH-OH! UH-OH!");
    new_context := context;

    quickest := min(naive_min, boyer_moore_min, knuth_morris_pratt_min);
    push_context new_context {
        format_float := *context.print_style.default_format_float;
        format_float.zero_removal = .NO;

        if quickest == naive_min
            print("Naive:              %1%2%3  % (%)\n", "\e[1;32m", naive_min, "\e[0m", "        ", naive_cmps);
        else
            print("Naive:              %1%2%3 +% (%)\n", "", naive_min, "", naive_min - quickest, naive_cmps);

        if quickest == boyer_moore_min
            print("Boyer-Moore:        %1%2%3  % (%)\n", "\e[1;32m", boyer_moore_min, "\e[0m", "        ", boyer_moore_cmps);
        else
            print("Boyer-Moore:        %1%2%3 +% (%)\n", "", boyer_moore_min, "", boyer_moore_min - quickest, boyer_moore_cmps);

        if quickest == knuth_morris_pratt_min
            print("Knuth-Morris-Pratt: %1%2%3  % (%)\n", "\e[1;32m", knuth_morris_pratt_min, "\e[0m", "        ", knuth_morris_pratt_cmps);
        else
            print("Knuth-Morris-Pratt: %1%2%3 +% (%)\n", "", knuth_morris_pratt_min, "", knuth_morris_pratt_min - quickest, knuth_morris_pratt_cmps);
    }
    print("\n");
}


time_it :: (call: (x: $T) -> int, needle: T, times: int) -> result: int, minimum: float64, median: float64, maximum: float64 {
    result : int;
    dt := NewArray(times, float64);
    for i: 0 .. times - 1 {
        start_time := get_time();
        result = call(needle);
        dt[i] = get_time() - start_time;
    }

    quick_sort(dt, (x: float64) -> float64 { return x; });
    return result, dt[0], dt[times / 2], dt[times - 1];
}


cmp_count := 0;

cmp :: inline (a: u8, b: u8) -> bool {
    cmp_count += 1;
    return a == b;
}

cmp_ignore :: inline (a: u8, b: u8) -> bool {
    cmp_count += 1;
    return ignore_case(a, b);
}
