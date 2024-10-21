#scope_file

MAX_BUILDERS :: 1024;
builders: [MAX_BUILDERS]String_Builder;

#scope_module

#if TRACE {

dump_google_trace_result :: () {
	write_entire_file("google_trace.json", " ");
	file := file_open("google_trace.json", for_writing=true);
	defer file_close(*file);
	
	file_write(*file, "[");
	for builder: builders {
		if !builder.initialized  continue;
		file_write(*file, *builder);
	}
	file_write(*file, "{}]");
}

profile_scope :: ($name: string = "") #expand {

	location := #location(#this);
	#if name {
		ZONE_NAME :: name;
	} else {
        PROC_NAME :: #procedure_name(#this);
        #if PROC_NAME {
            ZONE_NAME :: PROC_NAME;
        } else {
            ZONE_NAME :: "<anonymous_procedure>";
        }
	}
	
	start := seconds_since_init();
	
	
	
	`defer {
		now := seconds_since_init();
		
		elapsed := now - start;
		
		micro_elapsed := elapsed * 1000000;
		micro_start := start * 1000000;
		
		fmt :: "{\"cat\":\"function\",\"dur\":%,\"name\":\"%\",\"ph\":\"X\",\"pid\":0,\"tid\":%,\"ts\":%},";
		
		builder := *builders[context.thread_index];
		append(builder, tprint(fmt, micro_elapsed, ZONE_NAME, context.thread_index, micro_start));	
	}
}

} else {
	profile_scope :: ($name: string = "") #expand #no_debug{}
	dump_google_trace_result :: () #expand #no_debug {}
}