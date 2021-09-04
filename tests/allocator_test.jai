#import "Basic";
#import "Time";
#import "Strings";
scratch :: #import "Strings_Alloc"(default_allocator=scratch_allocator);

#load "../Strings_Shared/scratch.jai";

#load "data/shakespeare.jai";


main :: () {
    foo := scratch.copy(shakespeare);

    for count: 1 .. 1000 {
        for < #char "z" .. #char "a" {
            from : u8 = cast(u8)it;
            next : u8 = cast(u8)it + 1;
            foo = scratch.replace(foo, string_from_char(*from), string_from_char(*next));
        }
        foo = scratch.replace(foo, "}", "a");
    }

    //print(foo);
}
