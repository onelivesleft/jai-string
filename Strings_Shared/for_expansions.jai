

for_expansion :: (splitter: *Split_By_String, body: Code, flags: For_Flags) #expand {
	#assert(!(flags & .POINTER));
    reverse := flags & .REVERSE;

    `it : string = ---;
    `it_index : int = -1;

    if splitter.max_results != 0 && splitter.max_results < 2 {
        it = splitter.text;
        it_index = 0;

        #insert body;
    }
    else {
        max_it_index := ifx splitter.max_results == 0 then 0 else splitter.max_results - 2;
        process_remainder := true;

        if reverse {
            end_index := splitter.text.count;
            index, found := _last_index(splitter.text, splitter.separator, splitter.compare, splitter.last_index);
            while found {
                it = _unsafe_slice(splitter.text, index + splitter.separator.count, end_index);
                end_index = index;

                if splitter.skip_empty && it == ""  continue;

                it_index += 1;

                #insert body;

                if splitter.max_results != 0 && it_index >= max_it_index
                    break;

                index, found = _last_index(splitter.text, splitter.separator, index, splitter.compare, splitter.last_index);
            }

            if process_remainder  it = _unsafe_slice(splitter.text, 0, end_index);
        }
        else {
            start_index := 0;
            index, found := _first_index(splitter.text, splitter.separator, splitter.compare, splitter.first_index);
            while found {
                it = _unsafe_slice(splitter.text, start_index, index);
                start_index = index + splitter.separator.count;

                if splitter.skip_empty && it == ""  continue;

                it_index += 1;

                #insert body;

                if splitter.max_results != 0 && it_index >= max_it_index
                    break;

                index, found = _first_index(splitter.text, splitter.separator, start_index, splitter.compare, splitter.first_index);
            }

            if process_remainder  it = _unsafe_slice(splitter.text, start_index);
        }

        if process_remainder && (!splitter.skip_empty || it != "") {
            it_index += 1;

            #insert body;
        }
    }
}


for_expansion :: (splitter: *Split_By_Proc, body: Code, flags: For_Flags) #expand {
	#assert(!(flags & .POINTER));
    reverse := flags & .REVERSE;

    `it : string = ---;
    `it_index : int = -1;

    if splitter.max_results != 0 && splitter.max_results < 2 {
        it = splitter.text;
        it_index = 0;

        #insert body;
    }
    else {
        max_it_index := ifx splitter.max_results == 0 then 0 else splitter.max_results - 2;
        process_remainder := true;

        if reverse {
            end_index := splitter.text.count;
            from_index, to_index, found := splitter.index_proc(splitter.text, splitter.separator, splitter.text.count, true);
            while found {
                it = _unsafe_slice(splitter.text, to_index, end_index);
                end_index = from_index;

                if splitter.skip_empty && it == ""  continue;

                it_index += 1;

                #insert body;

                if splitter.max_results != 0 && it_index >= max_it_index
                    break;

                from_index, to_index, found = splitter.index_proc(splitter.text, splitter.separator, from_index, true);
            }

            if process_remainder  it = _unsafe_slice(splitter.text, 0, end_index);
        }
        else {
            start_index := 0;
            from_index, to_index, found := splitter.index_proc(splitter.text, splitter.separator, 0, false);
            while found {
                it = _unsafe_slice(splitter.text, start_index, from_index);
                start_index = to_index;

                if splitter.skip_empty && it == ""  continue;

                it_index += 1;

                #insert body;

                if splitter.max_results != 0 && it_index >= max_it_index
                    break;

                from_index, to_index, found = splitter.index_proc(splitter.text, splitter.separator, to_index, false);
            }

            if process_remainder  it = _unsafe_slice(splitter.text, start_index);
        }

        if process_remainder && (!splitter.skip_empty || it != "") {
            it_index += 1;

            #insert body;
        }
    }
}


for_expansion :: (splitter: *Split_By_Chars, body: Code, flags: For_Flags) #expand {
    #assert(!(flags & .POINTER));
    reverse := flags & .REVERSE;

    `it : string = ---;
    `it_index : int = -1;

    if splitter.max_results != 0 && splitter.max_results < 2 {
        it = splitter.text;
        it_index = 0;

        #insert body;
    }
    else {
        max_it_index := ifx splitter.max_results == 0 then 0 else splitter.max_results - 2;
        process_remainder := true;

        if reverse {
            end_index := splitter.text.count;
            for < index: splitter.text.count - 1 .. 0 {
                if _is_any(splitter.text[index], splitter.separator, splitter.compare) {
                    it = _unsafe_slice(splitter.text, index + 1, end_index);
                    end_index = index;

                    if splitter.skip_empty && it == ""  continue;

                    it_index += 1;

                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;
                }
            }

            if process_remainder  it = _unsafe_slice(splitter.text, 0, end_index);
        }
        else {
            start_index := 0;
            for index: 0 .. splitter.text.count - 1 {
                if _is_any(splitter.text[index], splitter.separator, splitter.compare) {
                    it = _unsafe_slice(splitter.text, start_index, index);
                    start_index = index + 1;

                    if splitter.skip_empty && it == ""  continue;

                    it_index += 1;

                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;
                }
            }

            if process_remainder  it = _unsafe_slice(splitter.text, start_index);
        }

        if process_remainder && (!splitter.skip_empty || it != "") {
            it_index += 1;

            #insert body;
        }
    }
}



for_expansion :: (splitter: *Split_By_Char, body: Code, flags: For_Flags) #expand {
	#assert(!(flags & .POINTER));
    reverse := flags & .REVERSE;

    `it : string = ---;
    `it_index : int = -1;

    if splitter.max_results != 0 && splitter.max_results < 2 {
        it = splitter.text;
        it_index = 0;

        #insert body;
    }
    else {
        max_it_index := ifx splitter.max_results == 0 then 0 else splitter.max_results - 2;
        process_remainder := true;

        if reverse {
            end_index := splitter.text.count;
            for < index: splitter.text.count - 1 .. 0 {
                if splitter.text[index] == splitter.separator {
                    it = _unsafe_slice(splitter.text, index + 1, end_index);
                    end_index = index;

                    if splitter.skip_empty && it == ""  continue;

                    it_index += 1;

                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;;
                }
            }

            if process_remainder  it = _unsafe_slice(splitter.text, 0, end_index);
        }
        else {
            start_index := 0;
            for index: 0 .. splitter.text.count - 1 {
                if splitter.text[index] == splitter.separator {
                    it = _unsafe_slice(splitter.text, start_index, index);
                    start_index = index + 1;

                    if splitter.skip_empty && it == ""  continue;

                    it_index += 1;

                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;
                }
            }

            if process_remainder  it = _unsafe_slice(splitter.text, start_index);
        }

        if process_remainder && (!splitter.skip_empty || it != "") {
            it_index += 1;

            #insert body;
        }
    }
}


for_expansion :: (splitter: *Split_By_Index, body: Code, flags: For_Flags) #expand {
	#assert(!(flags & .POINTER));
    reverse := flags & .REVERSE;

    `it : string = ---;
    `it_index : int = -1;

    if splitter.max_results != 0 && splitter.max_results < 2 {
        it = splitter.text;
        it_index = 0;

        #insert body;
    }
    else {
        max_it_index := ifx splitter.max_results == 0 then 0 else splitter.max_results - 2;
        process_remainder := true;

        if reverse {
            end_index := splitter.text.count;
            for < index, splitter_index: splitter.indexes {
                start_index := _slice_index(splitter.text, ifx index < end_index then index else end_index);
                it = _unsafe_slice(splitter.text, start_index, end_index);
                end_index = start_index;

                if splitter.skip_empty && it == ""  continue;

                it_index += 1;

                #insert body;

                if splitter.max_results != 0 && it_index >= max_it_index
                    break;
            }

            if process_remainder  it = _unsafe_slice(splitter.text, 0, end_index);
        }
        else {
            start_index := 0;
            for index, splitter_index: splitter.indexes {
                start_index = _slice_index(splitter.text, start_index);
                end_index := _slice_index(splitter.text, ifx index > start_index then index else start_index);
                it = _unsafe_slice(splitter.text, start_index, end_index);
                start_index = end_index;

                if splitter.skip_empty && it == ""  continue;

                it_index += 1;

                #insert body;

                if splitter.max_results != 0 && it_index >= max_it_index
                    break;
            }

            if process_remainder  it = _unsafe_slice(splitter.text, start_index);
        }

        if process_remainder && (!splitter.skip_empty || it != "") {
            it_index += 1;

            #insert body;
        }
    }
}


for_expansion :: (splitter: *Split_By_Line, body: Code, flags: For_Flags) #expand {
	#assert(!(flags & .POINTER));
    reverse := flags & .REVERSE;

    `it : string = ---;
    `it_index : int = -1;

    if splitter.max_results != 0 && splitter.max_results < 2 {
        it = splitter.text;
        it_index = 0;

        #insert body;
    }
    else {
        max_it_index := ifx splitter.max_results == 0 then 0 else splitter.max_results - 2;
        process_remainder := true;

        if reverse {
            end_index := splitter.text.count;

            for < index: splitter.text.count - 1 .. 0 {
                if splitter.text[index] == LF {
                    if splitter.keep_end {
                        it = _unsafe_slice(splitter.text, index + 1, end_index);
                    }
                    else {
                        it = _unsafe_slice(splitter.text, end_index, index);
                        if _ends_with(it, .[LF, CR], splitter.compare)  it = _unsafe_slice(it, 0, it.count - 1);
                    }
                    end_index = index + 1;

                    if splitter.skip_empty && it == ""  continue;

                    it_index += 1;

                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;
                }
            }
        }
        else {
            start_index := 0;

            for index: 0 .. splitter.text.count - 1 {
                if splitter.text[index] == LF {
                    if splitter.keep_end {
                        it = _unsafe_slice(splitter.text, start_index, index + 1);
                    }
                    else {
                        it = _unsafe_slice(splitter.text, start_index, index);
                        if _ends_with(it, CR, splitter.compare)  it = _unsafe_slice(it, 0, it.count - 1);
                    }
                    start_index = index + 1;

                    if splitter.skip_empty && it == ""  continue;

                    it_index += 1;

                    #insert body;

                    if splitter.max_results != 0 && it_index >= max_it_index
                        break;
                }
            }

            if process_remainder  it = _unsafe_slice(splitter.text, start_index);
        }

        if process_remainder && (!splitter.skip_empty || it != "") {
            it_index += 1;

            #insert body;
        }
    }
}
