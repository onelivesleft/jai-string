// @Note this file must be saved as LF only! (Hmmm this probably isn't true any more)

#import "Basic";

#import "Strings"(index_algorithm=.BOYER_MOORE);
heap :: #import "Strings_Alloc";
temp_strings :: #import "Strings_Alloc"(temp);

jai_string :: #import "String";

errors_only :: true;


errors : [..] int;

test :: (test_id: int, value: string, expected: string) {
    if value != expected {
        print("(%)\nWanted: [%]\nResult: [%]\n\n", test_id, expected, value);
        array_add(*errors, test_id);
    }
    else if !errors_only {
        print("(%) OK\n", test_id);
    }
}

test :: (test_id: int, value: u8, expected: u8) {
    if value != expected {
        print("(%)\nWanted: [%]\nResult: [%]\n\n", test_id, expected, value);
        array_add(*errors, test_id);
    }
    else if !errors_only {
        print("(%) OK\n", test_id);
    }
}

test :: (test_id: int, value: int, expected: int) {
    if value != expected {
        print("(%)\nWanted: [%]\nResult: [%]\n\n", test_id, expected, value);
        array_add(*errors, test_id);
    }
    else if !errors_only {
        print("(%) OK\n", test_id);
    }
}

test :: (test_id: int, value: bool, expected: bool) {
    if value != expected {
        print("(%)\nWanted: [%]\nResult: [%]\n\n", test_id, expected, value);
        array_add(*errors, test_id);
    }
    else if !errors_only {
        print("(%) OK\n", test_id);
    }
}


test :: (test_id: int, value: [] $T, expected: [] T) {
    if !array_equal(value, expected) {
        print("(%)\nWanted: [%]\nResult: [%]\n\n", test_id, expected, value);
        array_add(*errors, test_id);
    }
    else if !errors_only {
        print("(%) OK\n", test_id);
    }
}

array_equal :: (a: [] $T, b: [] T) -> bool {
    if a.count != b.count  return false;
    for i: 0 .. a.count - 1  if a[i] != b[i]  return false;
    return true;
}

split_into_three :: (text: string, separator: u8) -> string, string, string {
    first, tail := split_into_two(text, separator);
    second, third := split_into_two(tail, separator);
    return first, second, third;
}

split_into_three :: (text: string, separator: $T) -> string, string, string {
    first, tail := split_into_two(text, separator);
    second, third := split_into_two(tail, separator);
    return first, second, third;
}

test_string :: #string ___
One reason we have endless bloat is that we teach that all code should expand
until it meets all needs. This is wrong, empirically, and we should stop teaching it.
___;


really_long_string_no_cr :: #string ___
How long have I studied?  How many times have I read the same books, over and over?  Were I to free us, I would be the most knowledgeable man in England, at least about the contents of my own library, but it is a farce.  I have found nothing!

Every practice and ritual, every sacrament and offering I have read about, seen in illustrations, inferred from context… I have tried, and none of them have worked.  Nothing works to placate whichever god (or demon) the idol represents…  Nothing, that is, except that which I have already given, except the offering I know it accepts.

Our immortal souls are trapped here in this purgatory, and I know what I must do.
___;

rls_0 :: "How long have I studied?  How many times have I read the same books, over and over?  Were I to free us, I would be the most knowledgeable man in England, at least about the contents of my own library, but it is a farce.  I have found nothing!";
rls_1 :: "";
rls_2 :: "Every practice and ritual, every sacrament and offering I have read about, seen in illustrations, inferred from context… I have tried, and none of them have worked.  Nothing works to placate whichever god (or demon) the idol represents…  Nothing, that is, except that which I have already given, except the offering I know it accepts.";
rls_3 :: "";
rls_4 :: "Our immortal souls are trapped here in this purgatory, and I know what I must do.";


main :: () {
    print("SIMD OFF\n");
    set_simd_mode(.OFF);
    run_tests();

    if errors.count == 0 {
        print("\nSIMD SSE2\n");
        set_simd_mode(.SSE2);
        run_tests();
    }

    if errors.count == 0 {
        print("\nSIMD AVX2\n");
        set_simd_mode(.AVX2);
        run_tests();
    }
}

run_tests :: () {
    defer {
        if !errors_only
            for word: split("How about a nice game of chess?", #char " ")
                print("%\n", word);

        if errors.count != 0
            print("Errors:\n%\n", errors);
        else
            print("All OK!\n");
    }

    //set_index_algorithm(boyer_moore_first_index, boyer_moore_last_index);
    //set_index_algorithm(knuth_morris_pratt_first_index, knuth_morris_pratt_last_index);

    really_long_string := heap.replace(really_long_string_no_cr, "\n", "\r\n");

    test(1, slice(test_string, 0, 999), test_string);
    test(2, slice(test_string, -999, -888), "");
    test(3, slice(test_string, 0, 3), "One");
    test(4, slice(test_string, 4, 10), "reason");
    test(5, slice(test_string, -4, -1),  "it.");

    short_string := slice(test_string, -61);
    This := substring(short_string, 1, 4);
    end_it := substring(short_string, -4);
    test( 6, first_index("Hello", #char "l"), 2);
    test( 7, first_index("Hello", #char "l", 2), 2);
    test( 8, first_index("Hello", #char "l", 3), 3);
    test( 9, first_index("Hello", #char "l", 4), -1);
    test(10, first_index("Hello", #char "l", -3), 2);
    test(11, first_index("Hello", #char "l", -2), 3);
    test(12, first_index("Hello", #char "l", -1), -1);
    test(13, first_index("Hello", .[#char "l"]), 2);
    test(14, first_index("Hello", .[#char "l"], 2), 2);
    test(15, first_index("Hello", .[#char "l"], 3), 3);
    test(16, first_index("Hello", .[#char "l"], 4), -1);
    test(17, first_index("Hello", .[#char "l"], -3), 2);
    test(18, first_index("Hello", .[#char "l"], -2), 3);
    test(19, first_index("Hello", .[#char "l"], -1), -1);
    test(20, first_index("Hello", "el"), 1);
    test(21, first_index("Hello", "el", 0), 1);
    test(22, first_index("Hello", "el", 1), 1);
    test(23, first_index("Hello", "el", 2), -1);
    test(24, first_index("Hello", "el", -5), 1);
    test(25, first_index("Hello", "el", -4), 1);
    test(26, first_index("Hello", "el", -3), -1);
    test(27, last_index("Hello", #char "l"), 3);
    test(28, last_index("Hello", #char "l", 4), 3);
    test(29, last_index("Hello", #char "l", 3), 2);
    test(30, last_index("Hello", #char "l", 2), -1);
    test(31, last_index("Hello", #char "l", -3), -1);
    test(32, last_index("Hello", #char "l", -2), 2);
    test(33, last_index("Hello", #char "l", -1), 3);
    test(34, last_index("Hello", .[#char "l"]), 3);
    test(35, last_index("Hello", .[#char "l"], 2), -1);
    test(36, last_index("Hello", .[#char "l"], 3), 2);
    test(37, last_index("Hello", .[#char "l"], 4), 3);
    test(38, last_index("Hello", .[#char "l"], -3), -1);
    test(39, last_index("Hello", .[#char "l"], -2), 2);
    test(40, last_index("Hello", .[#char "l"], -1), 3);

    test(41, last_index("Hello", "el"), 1);
    test(42, last_index("Hello", "el", 0), -1);
    test(43, last_index("Hello", "el", 1), -1);
    test(44, last_index("Hello", "el", 2), -1);
    test(45, last_index("Hello", "el", 3), 1);
    test(46, last_index("Hello", "el", -3), -1);
    test(47, last_index("Hello", "el", -2), 1);
    test(477, last_index("Hello", "ell", -1), 1);

    test(48, trim(short_string), "This is wrong, empirically, and we should stop teaching it.");
    test(488, trim(short_string, cast([]u8)" \n"), "This is wrong, empirically, and we should stop teaching it.");
    test(49, trim_start(short_string), "This is wrong, empirically, and we should stop teaching it.\n");
    test(50, trim_end(short_string), " This is wrong, empirically, and we should stop teaching it.");
    test(51, trim(short_string, "\n"), " This is wrong, empirically, and we should stop teaching it.");
    test(52, trim(short_string, " "), "This is wrong, empirically, and we should stop teaching it.\n");
    test(522, trim(short_string, " This "), "is wrong, empirically, and we should stop teaching it.\n");
    test(523, trim(short_string, " it.\n"), " This is wrong, empirically, and we should stop teaching");

    trimmed := heap.copy_string(trim(short_string));

    to_upper(trimmed);
    test(53, trimmed, "THIS IS WRONG, EMPIRICALLY, AND WE SHOULD STOP TEACHING IT.");
    to_lower(trimmed);
    test(54, trimmed, "this is wrong, empirically, and we should stop teaching it.");

    simple := heap.copy_string("foo bar bar qux quux");
    replace(simple, #char "a", #char "u");
    test(55, simple, "foo bur bur qux quux");

    simple = heap.copy_string("foo bar bar qux quux");
    replace(simple, cast([]u8) "aeiou", #char "y");
    test(555, simple, "fyy byr byr qyx qyyx");

    passwords := heap.copy_string("type in the password to enter the password then push enter");
    changes := replace(passwords, "password", #char "*");
    test(56, changes, 16);
    test(57, passwords, "type in the ******** to enter the ******** then push enter");


    index := 0;
    for split(" aa bb cc ", " ") {
        if index == {
            case 0; test(58, it, "");
            case 1; test(59, it, "aa");
            case 2; test(60, it, "bb");
            case 3; test(61, it, "cc");
            case 4; test(62, it, "");
        }
        index += 1;
    }
    test(621, index, 5);

    index = 0;
    for split(" aa\tbb cc ", .[#char " ", #char "\t"]) {
        if index == {
            case 0; test(63, it, "");
            case 1; test(64, it, "aa");
            case 2; test(65, it, "bb");
            case 3; test(66, it, "cc");
            case 4; test(67, it, "");
        }
        index += 1;
    }
    test(671, index, 5);

    index = 0;
    for split(" aa bb cc ", #char " ") {
        if index == {
            case 0; test(68, it, "");
            case 1; test(69, it, "aa");
            case 2; test(70, it, "bb");
            case 3; test(71, it, "cc");
            case 4; test(72, it, "");
        }
        index += 1;
    }
    test(721, index, 5);

    index = 0;
    for < split(" aa bb cc ", " ") {
        if index == {
            case 0; test(73, it, "");
            case 1; test(74, it, "cc");
            case 2; test(75, it, "bb");
            case 3; test(76, it, "aa");
            case 4; test(77, it, "");
        }
        index += 1;
    }
    test(771, index, 5);

    index = 0;
    for < split(" aa\tbb cc ", .[#char " ", #char "\t"]) {
        if index == {
            case 0; test(78, it, "");
            case 1; test(79, it, "cc");
            case 2; test(80, it, "bb");
            case 3; test(81, it, "aa");
            case 4; test(82, it, "");
        }
        index += 1;
    }
    test(821, index, 5);

    index = 0;
    for < split(" aa bb cc ", #char " ") {
        if index == {
            case 0; test(83, it, "");
            case 1; test(84, it, "cc");
            case 2; test(85, it, "bb");
            case 3; test(86, it, "aa");
            case 4; test(87, it, "");
        }
        index += 1;
    }
    test(871, index, 5);


    jai_string.find_index_from_left("Foo", "f");
    jai_string.find_index_from_left("FoO", #char "f");

    // For potential overload error
    //Fooble :: struct {}
    //splitter : Fooble;
    //blahblah := heap.split(splitter);

    parts := heap.split(" aa bb cc ", " ");
    test(88, parts, string.["", "aa", "bb", "cc", ""]);

    backwards := heap.split(" aa bb cc ", " ", reversed = true, allocator = temp);
    test(89, backwards, string.["", "cc", "bb", "aa", ""]);

    some_text := "some text\there";

    temp_parts := temp_strings.split(some_text, .[#char " ", #char "\t"]);
    test(90, temp_parts, string.["some", "text", "here"]);

    temp_parts = temp_strings.split(some_text, cast([] u8)" \t");
    test(91, temp_parts, string.["some", "text", "here"]);

    joined := temp_strings.join(temp_parts, " ");
    i := last_index(joined, " ");
    joined[i] = #char "\t";
    test(92, joined, some_text);

    joined = temp_strings.join(temp_parts, #char "\t");
    replace(joined, #char "\t", #char " ", 1);
    test(93, joined, some_text);

    test(94, temp_strings.split(some_text, cast([] u8) " \t", false, 1), string.["some text\there"]);
    test(95, temp_strings.split(some_text, cast([] u8) " \t", false, 2), string.["some", "text\there"]);

    test( 97, temp_strings.replace(some_text, "ae", "e"),    "some text\there");
    test( 98, temp_strings.replace(some_text, "s",  "e"),    "eome text\there");
    test( 96, temp_strings.replace(some_text, "e",  "ae"),   "somae taext\thaerae");
    test( 99, temp_strings.replace(some_text, "e",  "a", 2), "soma taxt\there");
    test(100, temp_strings.replace(some_text, "e",  "a", 1), "soma text\there");
    test(101, temp_strings.replace(some_text, "e",  "a", 0), "soma taxt\thara");

    temp0 := temp_strings.replace(some_text, "E",  "ae",   compare=ignore_case);
    temp1 := temp_strings.replace(some_text, "AE", "e",    compare=ignore_case);
    temp2 := temp_strings.replace(some_text, "S",  "e",    compare=ignore_case);
    temp3 := temp_strings.replace(some_text, "E",  "a", 2, ignore_case);
    temp4 := temp_strings.replace(some_text, "E",  "a", 1, ignore_case);
    temp5 := temp_strings.replace(some_text, "E",  "a", 0, ignore_case);
    test(102, temp0, "somae taext\thaerae");
    test(103, temp1, "some text\there");
    test(104, temp2, "eome text\there");
    test(105, temp3, "soma taxt\there");
    test(106, temp4, "soma text\there");
    test(107, temp5, "soma taxt\thara");

    index = 0;
    for split("  aa    bb  cc ", " ", skip_empty = true) {
        if index == {
            case 0; test(9108, it, "aa");
                    test(9109, it_index, 0);
            case 1; test(9110, it, "bb");
                    test(9111, it_index, 1);
            case 2; test(9112, it, "cc");
                    test(9113, it_index, 2);
        }
        index += 1;
    }
    test(9114, index, 3);


    index = 0;
    for split("  aa    bb \t cc ", cast([]u8) " \t", skip_empty = true) {
        if index == {
            case 0; test(108, it, "aa");
                    test(109, it_index, 0);
            case 1; test(110, it, "bb");
                    test(111, it_index, 1);
            case 2; test(111, it, "cc");
                    test(112, it_index, 2);
        }
        index += 1;
    }
    test(1121, index, 3);

    index = 0;
    for < split("  aa    bb \t cc ", cast([]u8) " \t", skip_empty = true) {
        if index == {
            case 0; test(113, it, "cc");
                    test(114, it_index, 0);
            case 1; test(115, it, "bb");
                    test(116, it_index, 1);
            case 2; test(117, it, "aa");
                    test(118, it_index, 2);
        }
        index += 1;
    }
    test(1181, index, 3);

    temp_parts = temp_strings.split("  aa    bb \t cc ", cast([]u8) " \t", skip_empty = true);
    test(119, temp_parts, string.["aa", "bb", "cc"]);

    test(120, contains(some_text, "some"), true);
    test(121, contains(some_text, "soma"), false);
    test(122, contains(some_text, "text"), true);
    test(123, contains(some_text, "here"), true);
    test(124, contains(some_text, "her"),  true);

    rls_parts := temp_strings.split(really_long_string, "\n");
    test(125, trim_end(rls_parts[0], #char "\r"), rls_0);
    test(126, trim_end(rls_parts[1], "\r"), rls_1);
    test(127, trim_end(rls_parts[2], cast([]u8)"\r"), rls_2);
    test(128, trim_end(rls_parts[3], #char "\r"), rls_3);
    test(129, trim_end(rls_parts[4], #char "\r"), rls_4);

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
    test(1341, index, 5);

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
    test(1401, index, 3);

    c : u8 = xx #char "H";
    test(141, char_as_string(*c), "H");

    test(142, starts_with("Hello world", "Hello"), true);
    test(143, starts_with("Hello world", "hello"), false);
    test(144, starts_with("Hello world", "hello", ignore_case), true);
    test(145, ends_with("Hello world", "world"), true);
    test(146, ends_with("Hello world", "World"), false);
    test(147, ends_with("Hello world", "World", ignore_case), true);

    test(148, trim_start("Hello world", "Hello"), " world");
    test(149, trim_start("Hello world", "hello", ignore_case), " world");
    test(150, trim_start("Hello world", "hello"), "Hello world");
    test(151, trim_end("Hello world", "world"), "Hello ");
    test(152, trim_end("Hello world", "World"), "Hello world");
    test(153, trim_end("Hello world", "World", ignore_case), "Hello ");

    test(154, trim("xxxxxHelloxxxxx", "xx"), "xHellox");
    test(155, trim("xxxxxxHelloxxxxxx", "xx"), "Hello");

    parts = heap.split(" aa bb cc ", " ");
    test(156, parts, string.["", "aa", "bb", "cc", ""]);

    parts = temp_strings.line_split(" aa\nbb\r\ncc ");
    test(157, parts, string.[" aa", "bb", "cc "]);

    test(158, heap.join("Hello ", "to ", "the ", "world."), "Hello to the world.");

    test(159, heap.pad_start("Hello", 8), "   Hello");
    test(160, heap.pad_start("Hello", 8, "Hello"), "HelHello");
    test(161, heap.pad_start("Hello", 8, #char "x"), "xxxHello");
    test(162, heap.pad_start("Hello", 12, "xyz"), "xyzxyzxHello");

    test(163, heap.pad_end("Hello", 8), "Hello   ");
    test(164, heap.pad_end("Hello", 8, "Hello"), "Hellollo");
    test(165, heap.pad_end("Hello", 8, #char "x"), "Helloxxx");
    test(166, heap.pad_end("Hello", 12, "xyz"), "Hellozxyzxyz");

    test(167, heap.pad_center("Hello", 8), " Hello  ");
    test(168, heap.pad_center("Hello", 9), "  Hello  ");
    test(169, heap.pad_center("Hola", 8), "  Hola  ");
    test(170, heap.pad_center("Hola", 9), "  Hola   ");
    test(171, heap.pad_center("Hello", 8, "Hello"), "HHellolo");
    test(172, heap.pad_center("Hello", 8, #char "x"), "xHelloxx");
    test(173, heap.pad_center("Hello", 12, "xyz"), "xyzHellozxyz");

    test(174, heap.repeat("Hello", 5), "HelloHelloHelloHelloHello");

    test(175, heap.snake_from_camel("HelloHelloHelloHelloHello"), "hello_hello_hello_hello_hello");
    test(176, heap.snake_from_camel("HelloHelloHelloHelloHello", true), "Hello_Hello_Hello_Hello_Hello");

    test(177, heap.snake_from_camel("HELLOHelloHello"), "hello_hello_hello");
    test(178, heap.snake_from_camel("HELLOHelloHello", true), "Hello_Hello_Hello");

    blah := heap.copy_string("blAh");
    to_capitalized(blah);
    test(179, blah, "BlAh");
    to_capitalized(blah, false);
    test(180, blah, "Blah");

    test(181, heap.camel_from_snake("hello_hello_hello_hello_hello"), "HelloHelloHelloHelloHello");
    test(182, heap.camel_from_snake("heLlo_helLo_hEllo_Hello_hellO", true), "HeLloHelLoHElloHelloHellO");
    test(183, heap.camel_from_snake("HELLO_hello_hello", true), "HELLOHelloHello");
    test(184, heap.camel_from_snake("Hello_Hello_Hello"), "HelloHelloHello");

    test(185, temp_strings.capitalized("blAh"), "BlAh");
    test(186, temp_strings.capitalized("blAh", false), "Blah");

    rev := temp_strings.reverse("gnat");
    test(187, rev, "tang");
    reverse(rev);
    test(188, rev, "gnat");

    rev = temp_strings.reverse("ognat");
    test(189, rev, "tango");
    reverse(rev);
    test(190, rev, "ognat");

    test(191, count(really_long_string, "I"), 11);
    test(192, count(really_long_string, "I", ignore_case), 38);


    index = 0;
    for index_split(" aa bb cc ", -15, -13, 1, 3, 1, 4, 6, 7, 9, 15, 21) {
        if index == {
            case  0; test(193, it, "");
            case  1; test(194, it, "");
            case  2; test(195, it, " ");
            case  3; test(196, it, "aa");
            case  4; test(197, it, "");
            case  5; test(198, it, " ");
            case  6; test(199, it, "bb");
            case  7; test(200, it, " ");
            case  8; test(201, it, "cc");
            case  9; test(202, it, " ");
            case 10; test(203, it, "");
            case 11; test(204, it, "");
        }
        index += 1;
    }
    test(2041, index, 12);

    index = 0;
    for < index_split(" aa bb cc ", -15, -13, 1, 4, 3, 4, 6, 7, 9, 15, 21) {
        if index == {
            case  0; test(205, it, "");
            case  1; test(206, it, "");
            case  2; test(207, it, " ");
            case  3; test(208, it, "cc");
            case  4; test(209, it, " ");
            case  5; test(210, it, "bb");
            case  6; test(211, it, " ");
            case  7; test(212, it, "");
            case  8; test(213, it, "aa");
            case  9; test(214, it, " ");
            case 10; test(215, it, "");
            case 11; test(216, it, "");
        }
        index += 1;
    }
    test(2161, index, 12);

    temp_parts = temp_strings.index_split("  aa    bb \t cc ", 2, 4, 8, 10, 13, 15);
    test(217, temp_parts, string.["  ", "aa", "    ", "bb", " \t ", "cc", " "]);

    valid : bool;
    index, valid = slice_index("Hello", -6);
    test(218, valid, false);
    index, valid = slice_index("Hello", 0);
    test(219, valid, true);
    index, valid = slice_index("Hello", 5);
    test(220, valid, true);
    index, valid = slice_index("Hello", 6);
    test(221, valid, false);
    index, valid = slice_index("Hello", -3);
    test(222, valid, true);


    index = 0;
    for index_split(" aa bb cc ", -15, -13, 1, 3, 1, 4, 6, 7, 9, 15, 21, skip_empty = true) {
        if index == {
            case  0; test(223, it, " ");
            case  1; test(224, it, "aa");
            case  2; test(225, it, " ");
            case  3; test(226, it, "bb");
            case  4; test(227, it, " ");
            case  5; test(228, it, "cc");
            case  6; test(229, it, " ");
        }
        index += 1;
    }
    test(2291, index, 7);

    index = 0;
    for < index_split(" aa bb cc ", -15, -13, 1, 4, 3, 4, 6, 7, 9, 15, 21, skip_empty = true) {
        if index == {
            case  0; test(230, it, " ");
            case  1; test(231, it, "cc");
            case  2; test(232, it, " ");
            case  3; test(233, it, "bb");
            case  4; test(234, it, " ");
            case  5; test(235, it, "aa");
            case  6; test(236, it, " ");
        }
        index += 1;
    }
    test(2361, index, 7);

    index = 0;
    for line_split(really_long_string, keep_separator = .AS_POSTFIX) {
        if index == {
            case 0; test(2370, starts_with(it, rls_0), true);
                    test(2380, ends_with(it, "\n"), true);
            case 1; test(2371, starts_with(it, rls_1), true);
                    test(2381, ends_with(it, "\n"), true);
            case 2; test(2372, starts_with(it, rls_2), true);
                    test(2382, ends_with(it, "\n"), true);
            case 3; test(2373, starts_with(it, rls_3), true);
                    test(2383, ends_with(it, "\n"), true);
            case 4; test(2374, starts_with(it, rls_4), true);
                    test(2384, ends_with(it, "\n"), true);
        }
        index += 1;
    }
    test(2385, index, 5);

    map := heap.copy_string("How about a nice game of chess?");
    replace(map, #char " ", #char "-");
    replace(map, #char "a", #char "A");
    test(239, map, "How-About-A-nice-gAme-of-chess?");


    question_mark_index :: (haystack: string, needle: string, boundary_index: int, $$reverse: bool) -> from_index: int, to_index: int, found: bool {
        if reverse {
            from_index, to_index, found := reverse_index_proc(question_mark_index, haystack, needle, boundary_index);
            return from_index, to_index, found;
        }
        else {
            index := slice_index(haystack, boundary_index);
            if index >= haystack.count  return -1, -1, false;

            for haystack_index: index .. haystack.count - needle.count {
                for needle_index: 0 .. needle.count - 1 {
                    c := needle[needle_index];
                    if c != #char "?" && c != haystack[haystack_index + needle_index]
                        continue haystack_index;
                }

                return haystack_index, haystack_index + needle.count, true;
            }

            return -1, -1, false;
        }
    }

    test(240, starts_with(map, "Ho?", question_mark_index), true);
    test(241, starts_with(map, "ho?", question_mark_index), false);
    test(242, ends_with(map, "c?e?s?", question_mark_index), true);
    test(243, ends_with(map, "ho?", question_mark_index), false);

    test(244, contains(map, "?ni?e?", question_mark_index), true);
    test(245, contains(map, "?Ni?e?", question_mark_index), false);

    test(246, trim(map, "???-", question_mark_index), slice(map, 4));
    test(247, trim(map, "-??????", question_mark_index), slice(map, 0, -7));
    test(248, trim("aaaBBBaa", "a?", question_mark_index), "BB");

    test(249, trim_start(map, "???-", question_mark_index), slice(map, 4));
    test(250, trim_start(map, "-??????", question_mark_index), map);
    test(251, trim_start("aaaBBBaa", "a?", question_mark_index), "BBaa");

    test(252, trim_end(map, "???-", question_mark_index), map);
    test(253, trim_end(map, "-??????", question_mark_index), slice(map, 0, -7));
    test(254, trim_end("aaaBBBaa", "a?", question_mark_index), "aaaBBB");

    replace(map, "?-?", question_mark_index, #char "*", 2);
    test(255, map, "Ho**About-A-nice-gAme-of-chess?");
    replace(map, "?-?", question_mark_index, #char "*");
    test(256, map, "Ho**Abou***-nic***Am******hess?");

    test(257, count(map, "*?", question_mark_index), 8);

    index = 0;
    for split(map, "*?", question_mark_index) {
        if index == {
            case  0; test(258, it, "Ho");
            case  1; test(259, it, "Abou");
            case  2; test(260, it, "");
            case  3; test(261, it, "nic");
            case  4; test(262, it, "");
            case  5; test(263, it, "m");
            case  6; test(264, it, "");
            case  7; test(265, it, "");
            case  8; test(266, it, "hess?");
        }
        index += 1;
    }
    test(261, index, 9);

    index = 0;
    for < split(map, "*?", question_mark_index) {
        if index == {
            case  0; test(267, it, "ess?");
            case  1; test(268, it, "");
            case  2; test(269, it, "");
            case  3; test(270, it, "m*");
            case  4; test(271, it, "");
            case  5; test(272, it, "nic");
            case  6; test(273, it, "");
            case  7; test(274, it, "bou");
            case  8; test(275, it, "Ho*");
        }
        index += 1;
    }
    test(2751, index, 9);

    test(276, temp_strings.replace(map, "*?", question_mark_index, "-"),   "Ho-Abou--nic--m---hess?");
    test(277, temp_strings.replace(map, "?o?", question_mark_index, "---"),   "---*A---***-nic***Am******hess?");

    bah := temp_strings.copy_string(some_text);
    replace(bah, #char "\t", #char " ");
    temp_parts = temp_strings.split(bah, "? ?", question_mark_index);
    test(278, temp_parts, string.["som", "ex", "ere"]);

    temp_parts = temp_strings.split(bah, "? ?", question_mark_index, true);
    test(279, temp_parts, string.["ere", "ex", "som"]);

    test(280, temp_strings.lower("What Goes On Here"), "what goes on here");
    test(281, temp_strings.upper("What Goes On Here"), "WHAT GOES ON HERE");

    test(282, equal("What Goes On Here", "what goes on here"), false);
    test(283, equal("What Goes On Here", "what goes on here", ignore_case), true);

    bah2 := heap.copy_string(bah);
    advance_to(*bah, #char "s");
    test(284, bah, "some text here");
    advance_to(*bah, "ex");
    test(285, bah, "ext here");
    advance_to(*bah, cast([]u8) "hr");
    test(286, bah, "here");
    advance_to(*bah, #char "e");
    test(287, bah, "ere");
    advance_to(*bah, #char "e");
    test(288, bah, "ere");
    advance_to(*bah, #char "e");
    test(289, bah, "ere");
    advance_to(*bah, "?e", question_mark_index);
    test(290, bah, "re");
    advance_to(*bah, #char  "x");
    test(291, bah, "");

    advance_past(*bah2, #char "s");
    test(292, bah2, "ome text here");
    advance_past(*bah2, "ex");
    test(293, bah2, "t here");
    advance_past(*bah2, cast([]u8) " h");
    test(294, bah2, "re");
    advance_past(*bah2, #char "e");
    test(295, bah2, "");
    advance_past(*bah2, #char "e");
    test(296, bah2, "");

    more_than_16_one   := temp_strings.repeat("What Goes On Here", 11);
    more_than_16_two   := temp_strings.repeat("What Goes On Here", 11);
    more_than_16_three := temp_strings.repeat("what goes on here", 11);
    test(297, equal(more_than_16_one, more_than_16_two), true);
    test(298, equal(more_than_16_one, more_than_16_two, ignore_case), true);
    test(299, equal(more_than_16_one, more_than_16_three), false);
    test(300, equal(more_than_16_one, more_than_16_three, ignore_case), true);

    index = 0;
    for < line_split(really_long_string, skip_empty = true) {
        if index == {
            case 0; test(301, it, rls_4);
                    test(302, it_index, 0);
            case 1; test(303, it, rls_2);
                    test(304, it_index, 1);
            case 2; test(305, it, rls_0);
                    test(306, it_index, 2);
        }
        index += 1;
    }
    test(307, index, 3);

    index = 0;
    for < line_split(really_long_string, keep_separator = .AS_POSTFIX) {
        if index == {
            case 0; test(308, starts_with(it, rls_4), true);
                    test(309, ends_with(it, "\r\n"), true);
            case 1; test(310, starts_with(it, rls_3), true);
                    test(311, ends_with(it, "\r\n"), true);
            case 2; test(312, starts_with(it, rls_2), true);
                    test(313, ends_with(it, "\r\n"), true);
            case 3; test(314, starts_with(it, rls_1), true);
                    test(315, ends_with(it, "\r\n"), true);
            case 4; test(316, starts_with(it, rls_0), true);
                    test(317, ends_with(it, "\r\n"), true);
        }
        //print("%:\n[%]\n\n", it_index, it);
        index += 1;
    }
    test(318, index, 5);

    // string

    index = 0;
    for split(" aa bb cc ", " ", keep_separator = .AS_PREFIX) {
        if index == {
            case 0; test(319, it, "");
            case 1; test(320, it, " aa");
            case 2; test(321, it, " bb");
            case 3; test(322, it, " cc");
            case 4; test(323, it, " ");
        }
        index += 1;
    }
    test(324, index, 5);

    index = 0;
    for split(" aa bb cc ", " ", keep_separator = .AS_POSTFIX) {
        if index == {
            case 0; test(325, it, " ");
            case 1; test(326, it, "aa ");
            case 2; test(327, it, "bb ");
            case 3; test(328, it, "cc ");
            case 4; test(329, it, "");
        }
        index += 1;
    }
    test(330, index, 5);

    index = 0;
    for < split(" aa bb cc ", " ", keep_separator = .AS_PREFIX) {
        if index == {
            case 0; test(331, it, " ");
            case 1; test(332, it, " cc");
            case 2; test(333, it, " bb");
            case 3; test(334, it, " aa");
            case 4; test(335, it, "");
        }
        index += 1;
    }
    test(336, index, 5);

    index = 0;
    for < split(" aa bb cc ", " ", keep_separator = .AS_POSTFIX) {
        if index == {
            case 0; test(337, it, "");
            case 1; test(338, it, "cc ");
            case 2; test(339, it, "bb ");
            case 3; test(340, it, "aa ");
            case 4; test(341, it, " ");
        }
        index += 1;
    }

    test(342, index, 5);


    // char

    index = 0;
    for split(" aa bb cc ", #char " ", keep_separator = .AS_PREFIX) {
        if index == {
            case 0; test(343, it, "");
            case 1; test(344, it, " aa");
            case 2; test(345, it, " bb");
            case 3; test(346, it, " cc");
            case 4; test(347, it, " ");
        }
        index += 1;
    }
    test(348, index, 5);

    index = 0;
    for split(" aa bb cc ", #char " ", keep_separator = .AS_POSTFIX) {
        if index == {
            case 0; test(349, it, " ");
            case 1; test(350, it, "aa ");
            case 2; test(351, it, "bb ");
            case 3; test(352, it, "cc ");
            case 4; test(353, it, "");
        }
        index += 1;
    }
    test(354, index, 5);

    index = 0;
    for < split(" aa bb cc ", #char " ", keep_separator = .AS_PREFIX) {
        if index == {
            case 0; test(355, it, " ");
            case 1; test(356, it, " cc");
            case 2; test(357, it, " bb");
            case 3; test(358, it, " aa");
            case 4; test(359, it, "");
        }
        index += 1;
    }
    test(360, index, 5);

    index = 0;
    for < split(" aa bb cc ", #char " ", keep_separator = .AS_POSTFIX) {
        if index == {
            case 0; test(361, it, "");
            case 1; test(362, it, "cc ");
            case 2; test(363, it, "bb ");
            case 3; test(364, it, "aa ");
            case 4; test(365, it, " ");
        }
        index += 1;
    }

    test(366, index, 5);



    // chars

    index = 0;
    for split(" aa bb cc ", cast([]u8)" b", keep_separator = .AS_PREFIX) {
        if index == {
            case 0; test(343, it, "");
            case 1; test(344, it, " aa");
            case 2; test(345, it, " ");
            case 3; test(346, it, "b");
            case 4; test(347, it, "b");
            case 5; test(348, it, " cc");
            case 6; test(349, it, " ");
        }
        index += 1;
    }
    test(350, index, 7);

    index = 0;
    for split(" aa bb cc ", cast([]u8)" b", keep_separator = .AS_POSTFIX) {
        if index == {
            case 0; test(351, it, " ");
            case 1; test(352, it, "aa ");
            case 2; test(353, it, "b");
            case 3; test(354, it, "b");
            case 4; test(355, it, " ");
            case 5; test(356, it, "cc ");
            case 6; test(357, it, "");
        }
        index += 1;
    }
    test(358, index, 7);

    index = 0;
    for < split(" aa bb cc ", cast([]u8)" b", keep_separator = .AS_PREFIX) {
        if index == {
            case 0; test(359, it, " ");
            case 1; test(360, it, " cc");
            case 2; test(361, it, "b");
            case 3; test(362, it, "b");
            case 4; test(363, it, " ");
            case 5; test(364, it, " aa");
            case 6; test(365, it, "");
        }
        index += 1;
    }
    test(366, index, 7);

    index = 0;
    for < split(" aa bb cc ", cast([]u8)" b", keep_separator = .AS_POSTFIX) {
        if index == {
            case 0; test(367, it, "");
            case 1; test(368, it, "cc ");
            case 2; test(369, it, " ");
            case 3; test(370, it, "b");
            case 4; test(371, it, "b");
            case 5; test(372, it, "aa ");
            case 6; test(373, it, " ");
        }
        index += 1;
    }
    test(374, index, 7);
/*
    escaped := #string __
\e\\\n\r\t\"\0\xAB\d123\uABCD\UABCDEF12
__;
    test(343, temp_strings.apply_backslash(escaped), "\e\\\n\r\t\"\0\xAB\d123\uABCD\UABCDEF12\n");
*/

    escaped := #string __
\\\n\r\t\"\0\x08\d123\eX
__;
    test(343, cast([]u8)temp_strings.apply_backslash(slice(escaped, 0, -1)), cast([]u8)"\\\n\r\t\"\0\x08\d123\eX");

    unescaped := #string __
\e\\\n\r\t\"\0\x08
__;
    test(344, cast([]u8)temp_strings.escape("\e\\\n\r\t\"\0\x08"), cast([]u8)slice(unescaped, 0, -1));


    banana_sandwiches := "banana sandwiches are nice but banana & pear sandwiches are nicer";
    test(375, trim_start_to(banana_sandwiches, #char "a"), "anana sandwiches are nice but banana & pear sandwiches are nicer");
    test(376, trim_start_past(banana_sandwiches, #char "a"), "nana sandwiches are nice but banana & pear sandwiches are nicer");
    test(377, trim_start_to(banana_sandwiches, "nan"), "nana sandwiches are nice but banana & pear sandwiches are nicer");
    test(378, trim_start_past(banana_sandwiches, "nan"), "a sandwiches are nice but banana & pear sandwiches are nicer");

    test(379, trim_end_after(banana_sandwiches, #char "p"), "banana sandwiches are nice but banana & p");
    test(380, trim_end_from(banana_sandwiches, #char "p"), "banana sandwiches are nice but banana & ");
    test(381, trim_end_after(banana_sandwiches, "sandwiches"), "banana sandwiches are nice but banana & pear sandwiches");
    test(382, trim_end_from(banana_sandwiches, " banana"), "banana sandwiches are nice but");

    test(383, trim_into(banana_sandwiches, #char "a"), "anana sandwiches are nice but banana & pear sandwiches a");
    test(384, trim_into(banana_sandwiches, "sandwiches"), "sandwiches are nice but banana & pear sandwiches");
    test(385, trim_through(banana_sandwiches, #char "a"), "nana sandwiches are nice but banana & pear sandwiches ");
    test(386, trim_through(banana_sandwiches, "sandwiches"), " are nice but banana & pear ");


    // Ho**Abou***-nic***Am******hess?

    index = 0;
    for split(map, "*?", question_mark_index, keep_separator = .AS_PREFIX) {
        if index == {
            case  0; test(387, it, "Ho");
            case  1; test(388, it, "**Abou");
            case  2; test(389, it, "**");
            case  3; test(390, it, "*-nic");
            case  4; test(391, it, "**");
            case  5; test(392, it, "*Am");
            case  6; test(393, it, "**");
            case  7; test(394, it, "**");
            case  8; test(395, it, "**hess?");
        }
        index += 1;
    }
    test(396, index, 9);

    index = 0;
    for < split(map, "*?", question_mark_index, keep_separator = .AS_PREFIX) {
        if index == {
            case  0; test(397, it, "*hess?");
            case  1; test(398, it, "**");
            case  2; test(399, it, "**");
            case  3; test(400, it, "*Am*");
            case  4; test(401, it, "**");
            case  5; test(402, it, "*-nic");
            case  6; test(403, it, "**");
            case  7; test(404, it, "*Abou");
            case  8; test(405, it, "Ho*");
        }
        index += 1;
    }
    test(406, index, 9);


    // Ho**Abou***-nic***Am******hess?
    // 9999988888776666655444433221111

    index = 0;
    for split(map, "*?", question_mark_index, keep_separator = .AS_POSTFIX) {
        if index == {
            case  0; test(406, it, "Ho**");
            case  1; test(407, it, "Abou**");
            case  2; test(408, it, "*-");
            case  3; test(409, it, "nic**");
            case  4; test(410, it, "*A");
            case  5; test(411, it, "m**");
            case  6; test(412, it, "**");
            case  7; test(413, it, "**");
            case  8; test(414, it, "hess?");
        }
        index += 1;
    }
    test(415, index, 9);

    index = 0;
    for < split(map, "*?", question_mark_index, keep_separator = .AS_POSTFIX) {
        if index == {
            case  0; test(416, it, "ess?");
            case  1; test(417, it, "*h");
            case  2; test(418, it, "**");
            case  3; test(419, it, "m***");
            case  4; test(420, it, "*A");
            case  5; test(421, it, "nic**");
            case  6; test(422, it, "*-");
            case  7; test(423, it, "bou**");
            case  8; test(424, it, "Ho**A");
        }
        index += 1;
    }
    test(425, index, 9);


    index = 0;
    for < line_split(really_long_string, keep_separator = .AS_PREFIX) {
        if index == {
            case 0; test(426, it, "\r\n");
            case 1; test(427, ends_with(it, rls_4), true);
                    test(428, starts_with(it, "\r\n"), true);
            case 2; test(429, ends_with(it, rls_3), true);
                    test(430, starts_with(it, "\r\n"), true);
            case 3; test(431, ends_with(it, rls_2), true);
                    test(432, starts_with(it, "\r\n"), true);
            case 4; test(433, ends_with(it, rls_1), true);
                    test(434, starts_with(it, "\r\n"), true);
            case 5; test(435, it, rls_0);
        }
        //print("%:\n[%]\n\n", it_index, it);
        index += 1;
    }
    test(436, index, 6);

    test(437, count(really_long_string, cast([]u8)"ae"), count(really_long_string, #char "a") + count(really_long_string, #char "e"));

    first, second, third : string = ---;
    first, second = split_into_two(" aa bb cc ", #char " ");
    test(438, first, "");
    test(439, second, "aa bb cc ");

    first, second = split_into_two(" aa bb cc ", "bb");
    test(440, first, " aa ");
    test(441, second, " cc ");

    first, second = split_into_two(" aa bb cc ", cast([]u8)" a");
    test(442, first, "");
    test(443, second, "aa bb cc ");

    first, second, third = split_into_three(" aa bb cc ", #char " ");
    test(444, first, "");
    test(445, second, "aa");
    test(446, third, "bb cc ");

    first, second, third = split_into_three(" aa bb cc ", "b");
    test(447, first, " aa ");
    test(448, second, "");
    test(449, third, " cc ");

    first, second, third = split_into_three(" aa bb cc ", cast([]u8)" a");
    test(450, first, "");
    test(451, second, "");
    test(452, third, "a bb cc ");

    split_into_parts : [5] string = ---;
    split(*split_into_parts, " aa bb cc ", #char " ");
    test(453, split_into_parts, string.["", "aa", "bb", "cc", ""]);

    result_count := split(*split_into_parts, " aa bb cc ", "bb");
    test(454, split_into_parts, string.[" aa ", " cc ", "", "", ""]);
    test(455, result_count, 2);

    result_count = split(*split_into_parts, " aa bb cc ", "bb", keep_separator = .AS_PREFIX);
    test(456, split_into_parts, string.[" aa ", "bb cc ", "", "", ""]);
    test(457, result_count, 2);

    result_count = split(*split_into_parts, " aa bb cc ", "BB", keep_separator = .AS_PREFIX, compare = ignore_case);
    test(458, split_into_parts, string.[" aa ", "bb cc ", "", "", ""]);
    test(459, result_count, 2);

    index = 0;
    for count_split(" aa bb cc ", 3) {
        if index == {
            case 0; test(460, it, " aa");
            case 1; test(461, it, " bb");
            case 2; test(462, it, " cc");
            case 3; test(463, it, " ");
        }
        index += 1;
    }
    test(464, index, 4);

    index = 0;
    for < count_split(" aa bb cc ", 3) {
        if index == {
            case 0; test(465, it, "cc ");
            case 1; test(466, it, "bb ");
            case 2; test(467, it, "aa ");
            case 3; test(468, it, " ");
        }
        index += 1;
    }
    test(469, index, 4);

    index = 0;
    for count_split(" aa bb cc ", 2, 4) {
        if index == {
            case 0; test(470, it, " a");
            case 1; test(471, it, "a ");
            case 2; test(472, it, "bb");
            case 3; test(473, it, " cc ");
        }
        index += 1;
    }
    test(474, index, 4);

    index = 0;
    for < count_split(" aa bb cc ", 2, 4) {
        if index == {
            case 0; test(475, it, "c ");
            case 1; test(476, it, " c");
            case 2; test(477, it, "bb");
            case 3; test(478, it, " aa ");
        }
        index += 1;
    }
    test(479, index, 4);

    temp_parts = temp_strings.count_split(some_text, 2);
    test(480, temp_parts, string.["so", "me", " t", "ex", "t\t", "he", "re"]);

    temp_parts = temp_strings.count_split(some_text, 3, true);
    test(481, temp_parts, string.["ere", "t\th", "tex", "me ", "so"]);

    test(482, trim_into("blah blah blah .. blah blah blah", #char "."), "..");
    test(483, trim_into("blah blah blah . blah blah blah", #char "."), ".");
    test(484, trim_into("blah blah blah blah blah blah", #char "."), "blah blah blah blah blah blah");

    test(485, trim_through("blah blah blah .. blah blah blah", #char "."), "");
    test(486, trim_through("blah blah blah . blah blah blah", #char "."), "");
    test(487, trim_through("blah blah blah blah blah blah", #char "."), "blah blah blah blah blah blah");

    test(488, boyer_moore_first_index("<<", "<<", 0, case_sensitive), 0);


    last_index_test :: "ooma loompa dooopidee doo hell yeah hell yeweeeeeeeeah";
    last_index_of_a := jai_string.find_index_from_right(last_index_test, "a");
    test(489, last_index(last_index_test, "a"), last_index_of_a);
    test(490, last_index(last_index_test, "A", ignore_case), last_index_of_a);
}
