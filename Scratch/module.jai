#module_parameters (
    // Number of buffers the allocator will cycle through.
    // Usually you only need 2; one to read from and one to write to.
    // Must be >= 2
    buffer_count := 2,

    // Amount of space allocated when a buffer needs to increase in size
    // to accomadate an allocation request.  The amount requested times this
    // number will be allocated.  Overallocating one request means you do
    // not need to allocate again on a slightly-bigger following request.
    // Must be >= 1
    buffer_size_factor := 1.25
);


/** # Scratch Allocator
You will often want to perform a series of string operations, one after
another.
For example, replacing HTML character markers with the actual characters:

*Example 1*
```jai
    text = heap.replace(text, "&lt;", "<");
    text = heap.replace(text, "&gt;", ">");
    text = heap.replace(text, "&amp;", "&");
    text = heap.replace(text, "&nbsp;", Chars.NBSP);
```

The above code leaks because each call to replace allocates another copy of
the string.
To fix it with the heap allocator you would need to free after every call:

*Example 2*
```jai
    text1 := heap.replace(text0, "&lt;", "<");
    free(text0);
    text2 := heap.replace(text1, "&gt;", ">");
    free(text1);
    text3 := heap.replace(text2, "&amp;", "&");
    free(text2);
    text4 := heap.replace(text3, "&nbsp;", Chars.NBSP);
```

This is obviously cumbersome and error-prone.  Alternatively you could use
temporary storage:

*Example 3*
```jai
    text = temp.replace(text, "&lt;", "<");
    text = temp.replace(text, "&gt;", ">");
    text = temp.replace(text, "&amp;", "&");
    text = heap.replace(text, "&nbsp;", Chars.NBSP);
    reset_temporary_storage();
```

This is much nicer, but it still allocates more data on every call: if you are doing
a very long sequence of operations then you will allocate a very large amount of
memory.

However, notice in `Example 2` that we did not need to make all those variables: we
free `text0` before creating `text2`, so we could have written the code like this:

*Example 4*
```jai
    text1 := heap.replace(text0, "&lt;", "<");
    free(text0);
    text0 = heap.replace(text1, "&gt;", ">");
    free(text1);
    text1 = heap.replace(text0, "&amp;", "&");
    free(text0);
    text0 = heap.replace(text1, "&nbsp;", Chars.NBSP);
    free(text1);
```


This is because we are only ever dealing with two pieces of memory: the area we are
reading from and the area we are writing too.

The scratch allocator applies this reasoning to memory allocation: it will only ever allocate
two* pieces of memory: the buffer we are reading from and the buffer we are writing to.

Thus our code becomes:

*Example 5*
```jai
    text = scratch.replace(text, "&lt;", "<");       // writes to scratch buffer 0
    text = scratch.replace(text, "&gt;", ">");       // writes to scratch buffer 1
    text = scratch.replace(text, "&amp;", "&");      // writes to scratch buffer 0
    text = heap.replace(text, "&nbsp;", Chars.NBSP);
```

We never want to use the scratch allocator to hold data we wish to utilize elsewhere (as
it will be overwritten as soon as the scratch allocator is used anywhere else) so the final
call to replace uses the heap allocator instead.

* *Though see the `buffer_count` module parameter if you require more than two*
*/


#load "Scratch.jai";
