#module_parameters ()(max_thread_count := 16);

strings_shared_max_thread_count :: max_thread_count;

#load "Strings_Shared.jai";
#load "indexing.jai";
#load "boyer_moore.jai";
#load "knuth_morris_pratt.jai";


// @TODO cleanup this
__default_allocator :: Allocator.{__default_allocator_proc, null};
