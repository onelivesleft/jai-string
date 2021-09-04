scratch_allocator :: (mode: Allocator_Mode, requested_size: s64, old_size: s64, old_memory_pointer: *void, allocator_data: *void) -> *void {
    if #complete mode == {
        case .FREE;
        return null;

        case .RESIZE;
        assert(false, "Cannot resize scratch buffer: just allocate instead");
        return null;


        case .ALLOCATE;
        current_buffer_index += 1;
        current_buffer_index %= buffer_count;

        if sizes[current_buffer_index] < requested_size {
            if buffers[current_buffer_index]  free(buffers[current_buffer_index]);
            sizes[current_buffer_index] = cast(s64)(requested_size * buffer_increase_factor + 1);
            buffers[current_buffer_index] = alloc(sizes[current_buffer_index]);
        }

        return buffers[current_buffer_index];
    }
}


#scope_file


buffer_count :: 2;
buffer_increase_factor :: 1.5;

current_buffer_index := 0;
buffers : [buffer_count] *void;
sizes   : [buffer_count] int;
