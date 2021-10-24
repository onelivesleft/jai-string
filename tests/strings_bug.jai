main :: () {
  files := #string __
README.txt - C:\\Users\\farzher\\Downloads\\4coder\\README.txt
changes.txt - C:\\Users\\farzher\\Downloads\\4coder\\changes.txt
__

  context.allocator = __temporary_allocator;


  for i: 1 .. 3 {
    reset_temporary_storage();
    print("loop: %\n", i);
    filesstr: string;
    for line: line_split(files) {
      //filename, path := split_into_two(line, " - ");
      //print("%\n%\n", filename, path);
      //filesstr = strings_alloc.join(filesstr, path, "\0");
      filesstr = strings_alloc.join(filesstr, substring(line, first_index(line, " - ")+" - ".count), "\0");
      //filesstr = strings_alloc.join(filesstr, substring(line, String.find_index_from_left(line, " - ")+" - ".count), "\0");
    }
    print("%\n", filesstr);
    print("%\n", get_temporary_storage_mark());
  }
}

String :: #import "String";
#import "Strings";
strings_alloc :: #import "Strings_Alloc";
#import "Basic";
