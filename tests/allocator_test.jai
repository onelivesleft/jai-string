#import "Basic";
#import "Scratch";
#import "Strings";

#load "data/shakespeare.jai";


main :: () {
    foo := copy_string(shakespeare,, scratch);

    for count: 1 .. 1000 {
        foo = replace(foo, "z", "#",, scratch);
        for < #char "y" .. #char "a" {
            from : u8 = cast(u8)it;
            next : u8 = cast(u8)it + 1;
            foo = replace(foo, char_as_string(*from), char_as_string(*next),, scratch);
        }
        foo = replace(foo, "#", "a",, scratch);
    }

    print(foo);
}
