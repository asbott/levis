
Compile_Flags :: enum_flags {
	release; llvm; x64; very; trace;
}
flags: Compile_Flags;

do_build :: () {
	Compiler.set_build_options_dc(.{do_output=false, write_added_strings=false});
	
	args := Compiler.get_build_options().compile_time_command_line;
	
	for args {
		found := false;
		for n, e: enum_names(Compile_Flags) {
			if it == n {
				flags |= enum_values_as_enum(Compile_Flags)[e];
				found = true;
				break;
			}
		}
		
		if !found  Compiler.compiler_report(tprint("Invalid compiler argument '%'", it));
	}
	
	if flags != 0 {
		print("Compile flags: ");
		vals := enum_values_as_enum(Compile_Flags);
		for vals if flags & it {
			print("%", it);
			if it_index < vals.count-1 print(" | ");
		}
		print("\n");
	}
	
	w := Compiler.compiler_create_workspace("levis");
	
	options := Compiler.get_build_options(w);
	
	
	options.text_output_flags = .OUTPUT_TIMING_INFO;
	
	build_dir: string;
	
	if flags & .release {
		build_dir = "release";
		options.backend = .LLVM;
		
		if flags & .very {
			log("Compiling VERY release");
			Compiler.set_optimization(*options, .VERY_OPTIMIZED, preserve_debug_info=false);
			options.array_bounds_check = .OFF;
			options.cast_bounds_check = .OFF;
			options.null_pointer_check = .OFF;
			options.arithmetic_overflow_check = .OFF;
		} else {
			log("Compiling release");
			Compiler.set_optimization(*options, .OPTIMIZED, preserve_debug_info=true);
	        options.array_bounds_check = .ON;
	        options.cast_bounds_check  = .FATAL;
	        options.null_pointer_check = .ON;
		}
	} else {
		build_dir = "build";
		options.backend = .X64;
		options.use_natvis_compatible_types = true;
		
		if flags & .very {
			log("Compiling VERY debug");
			Compiler.set_optimization(*options, .VERY_DEBUG, preserve_debug_info=true);
		} else {
			log("Compiling debug");
			Compiler.set_optimization(*options, .DEBUG, preserve_debug_info=true);
		}
	}
	
	options.output_executable_name = "levis";

	make_directory_if_it_does_not_exist(build_dir);
	options.output_path = build_dir;
	
	if flags & .llvm  options.backend = .LLVM;
	if flags & .x64   options.backend = .X64;
	
	Compiler.set_build_options(options, w);
	
	intercept_flags: Compiler.Intercept_Flags;
	Compiler.compiler_begin_intercept(w, intercept_flags);
	
	Compiler.add_build_file("levis.jai", w);
	Compiler.add_build_string(tprint("DEBUG :: %;", !(flags & .release)), w);
	Compiler.add_build_string(tprint("TRACE :: %;", (flags & .trace)), w);
	Compiler.add_build_string(tprint("VERY_DEBUG :: %;", !(flags & .release) && flags & .very), w);
	
	Compiler.compiler_end_intercept(w);
}
#run do_build();

#import "Basic";
#import "File";
#import "Hash_Table";
#import "String";
#import "File_Utilities";
Compiler :: #import "Compiler";
