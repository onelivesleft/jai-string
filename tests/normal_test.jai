#import "Basic";
#import "String_View"; // @TODO investigate: (default_first_index_of = boyer_moore_first_index_of);
new :: #import "String_New"(null, debug = false)  #unshared;
temp :: #import "String_New"(__temporary_allocator, debug = false) #unshared;
String :: #import "String";


#load "../String_View/boyer_moore.jai";
#load "../String_View/knuth_morris_pratt.jai";

// TODO
// [ ] reversed / reverse
// [ ] replace translate
// [ ] count
// [ ] null_terminate



main :: () {
    defer {
        if errors.count != 0
            print("\nErrors:\n%\n", errors);
        else
            print("\nAll OK!\n");
    }

    print("new: %\n", new.default_allocator);
    print("temp: %\n", temp.default_allocator);

    exit(0);

    //set_index_of_algorithm(boyer_moore_first_index_of, boyer_moore_last_index_of);
    set_index_of_algorithm(knuth_morris_pratt_first_index_of, knuth_morris_pratt_last_index_of);

    test(1, slice(test_string, 0, 999), test_string);
    test(2, slice(test_string, -999, -888), "");
    test(3, slice(test_string, 0, 3), "One");
    test(4, slice(test_string, 4, 10), "reason");
    test(5, slice(test_string, -4, -1),  "it.");

    short_string := slice(test_string, -61);
    This := substring(short_string, 1, 4);
    end_it := substring(short_string, -4);

    test( 6, first_index_of("Hello", #char "l"), 2);
    test( 7, first_index_of("Hello", #char "l", 2), 2);
    test( 8, first_index_of("Hello", #char "l", 3), 3);
    test( 9, first_index_of("Hello", #char "l", 4), -1);
    test(10, first_index_of("Hello", #char "l", -3), 2);
    test(11, first_index_of("Hello", #char "l", -2), 3);
    test(12, first_index_of("Hello", #char "l", -1), -1);
    test(13, first_index_of("Hello", .[#char "l"]), 2);
    test(14, first_index_of("Hello", .[#char "l"], 2), 2);
    test(15, first_index_of("Hello", .[#char "l"], 3), 3);
    test(16, first_index_of("Hello", .[#char "l"], 4), -1);
    test(17, first_index_of("Hello", .[#char "l"], -3), 2);
    test(18, first_index_of("Hello", .[#char "l"], -2), 3);
    test(19, first_index_of("Hello", .[#char "l"], -1), -1);
    test(20, first_index_of("Hello", "el"), 1);
    test(21, first_index_of("Hello", "el", 0), 1);
    test(22, first_index_of("Hello", "el", 1), 1);
    test(23, first_index_of("Hello", "el", 2), -1);
    test(24, first_index_of("Hello", "el", -5), 1);
    test(25, first_index_of("Hello", "el", -4), 1);
    test(26, first_index_of("Hello", "el", -3), -1);
    test(27, last_index_of("Hello", #char "l"), 3);
    test(28, last_index_of("Hello", #char "l", 4), 3);
    test(29, last_index_of("Hello", #char "l", 3), 2);
    test(30, last_index_of("Hello", #char "l", 2), -1);
    test(31, last_index_of("Hello", #char "l", -3), -1);
    test(32, last_index_of("Hello", #char "l", -2), 2);
    test(33, last_index_of("Hello", #char "l", -1), 3);
    test(34, last_index_of("Hello", .[#char "l"]), 3);
    test(35, last_index_of("Hello", .[#char "l"], 2), -1);
    test(36, last_index_of("Hello", .[#char "l"], 3), 2);
    test(37, last_index_of("Hello", .[#char "l"], 4), 3);
    test(38, last_index_of("Hello", .[#char "l"], -3), -1);
    test(39, last_index_of("Hello", .[#char "l"], -2), 2);
    test(40, last_index_of("Hello", .[#char "l"], -1), 3);

    test(41, last_index_of("Hello", "el"), 1);
    test(42, last_index_of("Hello", "el", 0), -1);
    test(43, last_index_of("Hello", "el", 1), -1);
    test(44, last_index_of("Hello", "el", 2), -1);
    test(45, last_index_of("Hello", "el", 3), 1);
    test(46, last_index_of("Hello", "el", -3), -1);
    test(47, last_index_of("Hello", "el", -2), 1);
    test(477, last_index_of("Hello", "ell", -1), 1);

    test(48, trim(short_string), "This is wrong, empirically, and we should stop teaching it.");
    test(49, trim_left(short_string), "This is wrong, empirically, and we should stop teaching it.\n");
    test(50, trim_right(short_string), " This is wrong, empirically, and we should stop teaching it.");
    test(51, trim(short_string, "\n"), " This is wrong, empirically, and we should stop teaching it.");
    test(52, trim(short_string, " "), "This is wrong, empirically, and we should stop teaching it.\n");

    trimmed := copy_string(trim(short_string));

    to_upper(trimmed);
    test(53, trimmed, "THIS IS WRONG, EMPIRICALLY, AND WE SHOULD STOP TEACHING IT.");
    to_lower(trimmed);
    test(54, trimmed, "this is wrong, empirically, and we should stop teaching it.");

    simple := copy_string("foo bar bar qux quux");
    replace(simple, #char "a", #char "u");
    test(55, simple, "foo bur bur qux quux");

    simple = copy_string("foo bar bar qux quux");
    replace(simple, cast([]u8) "aeiou", #char "y");
    test(555, simple, "fyy byr byr qyx qyyx");

    passwords := copy_string("type in the password to enter the password then push enter");
    changes := replace(passwords, "password", #char "*");
    test(56, changes, 16);
    test(57, passwords, "type in the ******** to enter the ******** then push enter");


    index := 0;
    for forward_split(" aa bb cc ", " ") {
        if index == {
            case 0; test(58, it, "");
            case 1; test(59, it, "aa");
            case 2; test(60, it, "bb");
            case 3; test(61, it, "cc");
            case 4; test(62, it, "");
        }
        index += 1;
    }

    index = 0;
    for forward_split(" aa\tbb cc ", .[#char " ", #char "\t"]) {
        if index == {
            case 0; test(63, it, "");
            case 1; test(64, it, "aa");
            case 2; test(65, it, "bb");
            case 3; test(66, it, "cc");
            case 4; test(67, it, "");
        }
        index += 1;
    }

    index = 0;
    for forward_split(" aa bb cc ", #char " ") {
        if index == {
            case 0; test(68, it, "");
            case 1; test(69, it, "aa");
            case 2; test(70, it, "bb");
            case 3; test(71, it, "cc");
            case 4; test(72, it, "");
        }
        index += 1;
    }

    index = 0;
    for reverse_split(" aa bb cc ", " ") {
        if index == {
            case 0; test(73, it, "");
            case 1; test(74, it, "cc");
            case 2; test(75, it, "bb");
            case 3; test(76, it, "aa");
            case 4; test(77, it, "");
        }
        index += 1;
    }

    index = 0;
    for reverse_split(" aa\tbb cc ", .[#char " ", #char "\t"]) {
        if index == {
            case 0; test(78, it, "");
            case 1; test(79, it, "cc");
            case 2; test(80, it, "bb");
            case 3; test(81, it, "aa");
            case 4; test(82, it, "");
        }
        index += 1;
    }

    index = 0;
    for reverse_split(" aa bb cc ", #char " ") {
        if index == {
            case 0; test(83, it, "");
            case 1; test(84, it, "cc");
            case 2; test(85, it, "bb");
            case 3; test(86, it, "aa");
            case 4; test(87, it, "");
        }
        index += 1;
    }

    parts := new.split(" aa bb cc ", " ");
    test(88, parts, string.["", "aa", "bb", "cc", ""]);

    backwards := new.split(" aa bb cc ", " ", reversed = true, allocator = __temporary_allocator);
    test(89, backwards, string.["", "cc", "bb", "aa", ""]);

    some_text := "some text\there";

    temp_parts := temp.split(some_text, .[#char " ", #char "\t"]);
    test(90, temp_parts, string.["some", "text", "here"]);

    temp_parts = temp.split(some_text, cast([] u8)" \t");
    test(91, temp_parts, string.["some", "text", "here"]);

    joined := temp.join(temp_parts, " ");
    i := last_index_of(joined, " ");
    joined[i] = #char "\t";
    test(92, joined, some_text);

    joined = temp.join(temp_parts, #char "\t");
    replace(joined, #char "\t", #char " ", 1);
    test(93, joined, some_text);

    test(94, temp.split(some_text, cast([] u8) " \t", max_results = 1), .["some text\there"]);
    test(95, temp.split(some_text, cast([] u8) " \t", max_results = 2), .["some", "text\there"]);

    test( 96, temp.replace(some_text, "e",  "ae"),   "somae taext\thaerae");
    test( 97, temp.replace(some_text, "ae", "e"),    "some text\there");
    test( 98, temp.replace(some_text, "s",  "e"),    "eome text\there");
    test( 99, temp.replace(some_text, "e",  "a", 2), "soma taxt\there");
    test(100, temp.replace(some_text, "e",  "a", 1), "soma text\there");
    test(101, temp.replace(some_text, "e",  "a", 0), "soma taxt\thara");

    test(102, temp.replace(some_text, "E",  "ae",   ignore_case), "somae taext\thaerae");
    test(103, temp.replace(some_text, "AE", "e",    ignore_case), "some text\there");
    test(104, temp.replace(some_text, "S",  "e",    ignore_case), "eome text\there");
    test(105, temp.replace(some_text, "E",  "a", 2, ignore_case), "soma taxt\there");
    test(106, temp.replace(some_text, "E",  "a", 1, ignore_case), "soma text\there");
    test(107, temp.replace(some_text, "E",  "a", 0, ignore_case), "soma taxt\thara");

    index = 0;
    for forward_split("  aa    bb \t cc ", cast([]u8) " \t", skip_empty = true) {
        if index == {
            case 0; test(108, it, "aa");
                    test(109, it_index, 0);
            case 1; test(110, it, "bb");
                    test(111, it_index, 1);
            case 2; test(111, it, "cc");
                    test(112, it_index, 2);
            case 3; test(999, it, "This shouldn't happen!");
        }
        index += 1;
    }

    index = 0;
    for reverse_split("  aa    bb \t cc ", cast([]u8) " \t", skip_empty = true) {
        if index == {
            case 0; test(113, it, "cc");
                    test(114, it_index, 0);
            case 1; test(115, it, "bb");
                    test(116, it_index, 1);
            case 2; test(117, it, "aa");
                    test(118, it_index, 2);
            case 3; test(999, it, "This shouldn't happen!");
        }
        index += 1;
    }

    temp_parts = temp.split("  aa    bb \t cc ", cast([]u8) " \t", skip_empty = true);
    test(119, temp_parts, string.["aa", "bb", "cc"]);

    test(120, contains(some_text, "some"), true);
    test(121, contains(some_text, "soma"), false);
    test(122, contains(some_text, "text"), true);
    test(123, contains(some_text, "here"), true);
    test(124, contains(some_text, "her"), true);

    rls_parts := temp.split(really_long_string, "\n");
    test(125, trim_right(rls_parts[0], #char "\r"), rls_0);
    test(126, trim_right(rls_parts[1], #char "\r"), rls_1);
    test(127, trim_right(rls_parts[2], #char "\r"), rls_2);
    test(128, trim_right(rls_parts[3], #char "\r"), rls_3);
    test(129, trim_right(rls_parts[4], #char "\r"), rls_4);

    index = 0;
    for line_split(really_long_string) {
        if index == {
            case 0; test(130, it, rls_0);
            case 1; test(131, it, rls_1);
            case 2; test(132, it, rls_2);
            case 3; test(133, it, rls_3);
            case 4; test(134, it, rls_4);
        }
        index += 1;
    }

    index = 0;
    for line_split(really_long_string, skip_empty = true) {
        if index == {
            case 0; test(135, it, rls_0);
                    test(136, it_index, 0);
            case 1; test(137, it, rls_2);
                    test(138, it_index, 1);
            case 2; test(139, it, rls_4);
                    test(140, it_index, 2);
        }
        index += 1;
    }

    c : u8 = xx #char "H";
    test(141, string_from_char(*c), "H");
}


errors : [..] int;

test :: (test_id: int, value: $T, expected: T) {
    if value != expected {
        print("(%)\nWanted: [%]\nGot: [%]\n\n", test_id, expected, value);
        array_add(*errors, test_id);
    }
    else {
        print("(%) OK\n", test_id);
    }
}

test :: (test_id: int, value: [] string, expected: [] string) {
    if !array_equals(value, expected) {
        print("(%)\nWanted: [%]\nGot: [%]\n\n", test_id, expected, value);
        array_add(*errors, test_id);
    }
    else {
        print("(%) OK\n", test_id);
    }
}

array_equals :: (a: [] $T, b: [] T) -> bool #must {
    if a.count != b.count  return false;
    for i: 0..a.count-1  if a[i] != b[i]  return false;
    return true;
}


test_string :: #string ___
One reason we have endless bloat is that we teach that all code should expand
until it meets all needs. This is wrong, empirically, and we should stop teaching it.
___;


really_long_string :: #string ___
How long have I studied?  How many times have I read the same books, over and over?  Were I to free us, I would be the most knowledgeable man in England, at least about the contents of my own library, but it is a farce.  I have found nothing!

Every practice and ritual, every sacrament and offering I have read about, seen in illustrations, inferred from context… I have tried, and none of them have worked.  Nothing works to placate whichever god (or demon) the idol represents…  Nothing, that is, except that which I have already given, except the offering I know it accepts.

Our immortal souls are trapped here in this purgatory, and I know what I must do.
___;

rls_0 :: "How long have I studied?  How many times have I read the same books, over and over?  Were I to free us, I would be the most knowledgeable man in England, at least about the contents of my own library, but it is a farce.  I have found nothing!";
rls_1 :: "";
rls_2 :: "Every practice and ritual, every sacrament and offering I have read about, seen in illustrations, inferred from context… I have tried, and none of them have worked.  Nothing works to placate whichever god (or demon) the idol represents…  Nothing, that is, except that which I have already given, except the offering I know it accepts.";
rls_3 :: "";
rls_4 :: "Our immortal souls are trapped here in this purgatory, and I know what I must do.";
