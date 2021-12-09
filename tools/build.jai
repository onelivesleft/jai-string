#import "Basic";
#import "Compiler";

filepath :: "index_profile.jai";

#run {
    build_options := get_build_options();
    set_build_options_dc(.{do_output = false});

    workspace := compiler_create_workspace();
    build_options.emit_debug_info = .NONE;
    set_optimization_level(*build_options, 3, 3);
    set_build_options(build_options, workspace);

    compiler_begin_intercept(workspace);

    add_build_file(filepath, workspace);

    while true {
        message := compiler_wait_for_message();
        if !message continue;
        if message.kind == .COMPLETE break;
    }

    compiler_end_intercept(workspace);
}
