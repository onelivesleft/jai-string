#import "Basic";
#import "Time";
#import "Scratch";
#import "Strings";
scratch :: #import "Strings_Alloc"(scratch_allocator);

#load "data/shakespeare.jai";


main :: () {
    foo := scratch.copy(shakespeare);

    for count: 1 .. 1000 {
        foo = scratch.replace(foo, "z", "#");
        for < #char "y" .. #char "a" {
            from : u8 = cast(u8)it;
            next : u8 = cast(u8)it + 1;
            foo = scratch.replace(foo, string_from_char(*from), string_from_char(*next));
        }
        foo = scratch.replace(foo, "#", "a");
    }

    print(foo);
}
