scratch_allocator :: (mode: Allocator_Mode, requested_size: s64, old_size: s64, old_memory_pointer: *void, allocator_data: *void) -> *void {
    if #complete mode == {
        case .FREE;
        return null;

        case .RESIZE;
        assert(false, "Cannot resize scratch buffer: just allocate instead.");
        return null;


        case .ALLOCATE;
        current_buffer_index += 1;
        current_buffer_index %= buffer_count;

        if sizes[current_buffer_index] < requested_size {
            if buffers[current_buffer_index]  free(buffers[current_buffer_index]);
            sizes[current_buffer_index] = cast(s64)(requested_size * buffer_size_factor + 1);
            buffers[current_buffer_index] = alloc(sizes[current_buffer_index]);
        }

        return buffers[current_buffer_index];
    }
}


free_scratch_allocator_buffers :: () {
    // If you are done using the scratch allocator and want to release the buffer
    // memory.
    for i: 0 .. buffer_count - 1 {
        if buffers[i]  free(buffers[i]);
        sizes[i] = 0;
    }
}



#scope_file



current_buffer_index := 0;
buffers : [buffer_count] *void;
sizes   : [buffer_count] int;

#import "Basic"
