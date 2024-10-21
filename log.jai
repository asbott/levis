

log_verbose :: (format_string: string, args: .. Any, loc := #caller_location, user_flags : u32 = 0, section : *Log_Section = null) {
    builder: String_Builder;

    print_to_builder(*builder, format_string, ..args);

    s := builder_to_string(*builder,, allocator = __temporary_allocator);
    if !s.count return;

    info: Log_Info;
    info.source_identifier = context.log_source_identifier;
    info.location          = loc;
    info.common_flags      = .VERY_VERBOSE_ONLY;
    info.user_flags        = user_flags;
    info.section           = section;
    context.logger(s, context.logger_data, info);
} @PrintLike

log_warning :: (format_string: string, args: .. Any, loc := #caller_location, user_flags : u32 = 0, section : *Log_Section = null) {
    builder: String_Builder;

    print_to_builder(*builder, format_string, ..args);

    s := builder_to_string(*builder,, allocator = __temporary_allocator);
    if !s.count return;

    info: Log_Info;
    info.source_identifier = context.log_source_identifier;
    info.location          = loc;
    info.common_flags      = .WARNING;
    info.user_flags        = user_flags;
    info.section           = section;
    context.logger(s, context.logger_data, info);
} @PrintLike

log_info :: log;


// Sometimes persistent state might be odd and require a warning but we do not want to spam the console, so we just make it print out the first time this procedure is called. It can use any identifier, probably best to use like a pointer or something which is identified with the problematic state.
one_time_warning_mutex: Mutex;
one_time_warning_mutex_initted: bool;
one_time_warning_flags: Table(int, bool);
one_time_warning :: (message: string, identifier: $T) {

	if !one_time_warning_mutex_initted {
		// #Memory
		//push_allocator(persist_allocator);
		init(*one_time_warning_flags);
		init(*one_time_warning_mutex, "Single Time Warning");
		one_time_warning_mutex_initted = true;
	}
	lock(*one_time_warning_mutex);
	defer unlock(*one_time_warning_mutex);
	
	flag, found := table_find(*one_time_warning_flags, cast(int)identifier);
	
	if !flag || !found {
		log_warning(tprint("% [OTW 0x%]", message, formatInt(cast(int)identifier, base=16)));
		// #Memory
		// push_allocator(persist_allocator);
		table_set(*one_time_warning_flags, cast(int)identifier, true);
	}
}