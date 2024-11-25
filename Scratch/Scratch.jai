scratch :: Allocator.{scratch_allocator_proc, null};

scratch_allocator_proc :: (mode: Allocator_Mode, requested_size: s64, old_size: s64, old_memory_pointer: *void, allocator_data: *void) -> *void {
    scratch_allocator_data := cast(*Scratch_Allocator_Data) allocator_data;
    if !scratch_allocator_data {
        if !context.scratch_allocator_data
            context.scratch_allocator_data = context.default_allocator.proc(.ALLOCATE, size_of(Scratch_Allocator_Data), 0, null, null);
        scratch_allocator_data = context.scratch_allocator_data;
    }
    using scratch_allocator_data;

    if #complete mode == {
        case .RESIZE;
            assert(false, "Cannot resize scratch buffer: just allocate instead.");
            return null;


        case .ALLOCATE;
            current_buffer_index += 1;
            current_buffer_index %= buffer_count;

            if sizes[current_buffer_index] < requested_size {
                if buffers[current_buffer_index]  free(buffers[current_buffer_index]);
                sizes[current_buffer_index] = cast(s64)(requested_size * buffer_size_factor + 1);
                buffers[current_buffer_index] = context.default_allocator.proc(.ALLOCATE, sizes[current_buffer_index], 0, null, null);
            }

            return buffers[current_buffer_index];

        case .FREE;         #through;
        case .STARTUP;      #through;
        case .SHUTDOWN;     #through;
        case .THREAD_START; #through;
        case .THREAD_STOP;
            return null;

        case .CREATE_HEAP; #through;
        case .DESTROY_HEAP;
            context.handling_assertion_failure = true;
            context.assertion_failed(#location(), "This allocator does not support multiple heaps.\n");
            context.handling_assertion_failure = false;
            return null;


        case .IS_THIS_YOURS;
            context.handling_assertion_failure = true;
            context.assertion_failed(#location(), "This allocator does not support IS_THIS_YOURS.\n");
            context.handling_assertion_failure = false;
            return null;

        case .CAPS;
            if old_memory_pointer { <<cast(*string) old_memory_pointer = VERSION_STRING; }
            return cast(*void) (Allocator_Caps.HINT_I_AM_A_FAST_BUMP_ALLOCATOR|.MULTIPLE_THREADS);
    }
}

free_scratch_allocator_buffers :: () {
    // If you are done using the scratch allocator and want to release the buffer memory.
    using context.scratch_allocator;
    for i: 0 .. buffer_count - 1 {
        if buffers[i]  free(buffers[i]);
        sizes[i] = 0;
    }
}

Scratch_Allocator_Data :: struct {
    current_buffer_index := 0;
    buffers: [buffer_count] *void;
    sizes:   [buffer_count] int;
}


#scope_file

#add_context scratch_allocator_data: *Scratch_Allocator_Data;

#import "Basic";
