/*

*/
/*#add_context chungus_arena: Arena;

times: [..]float64;

render_threads: []Thread;
current_render_batch: *Rect_Batch;
current_render_frame_buffer: []u8;
render_done_sems:  []Semaphore;
render_start_sems: []Semaphore;

main :: () {
	context.logger = logger_proc;
	platform_init();
	
	defer dump_google_trace_result();
	
	//platform.number_of_logical_processors = 8;
	
	array_resize(*render_threads, platform.number_of_logical_processors,,chungus);
	array_resize(*render_done_sems, platform.number_of_logical_processors,,chungus);
	array_resize(*render_start_sems, platform.number_of_logical_processors,,chungus);
	
	indices: []int;
	array_resize(*indices, platform.number_of_logical_processors,,chungus);
	for *indices { <<it = it_index; }
	
	for * render_threads {
		thread_init(it, render_thread);
		thread_start(it);
		
		it.data = *indices[it_index];
		
		init(*render_done_sems[it_index]);
		init(*render_start_sems[it_index]);
		
		//signal(*render_done_sems[it_index]);
	}
	
	batch: Rect_Batch;
	batch_init(*batch, window.width, window.height,,arena_allocator(*context.chungus_arena));
	
	Rect :: struct {
		aabb: Vector4;
		speed_factor: float;
		color: u32;
	}
	
	NUM_RECTS :: 250000;
	
	rects: []Rect;
	array_resize(*rects, NUM_RECTS);
	
	for * it: rects {
		xoffset := cast(int)random_get_within_range(cast(float)0.0, cast(float)window.width);
		yoffset := cast(int)random_get_within_range(cast(float)0.0, cast(float)window.height);
		w := cast(int)random_get_within_range(cast(float)16, 32);
		h := cast(int)random_get_within_range(cast(float)16, 32);
		
		color: Vector4;
		color.xyz = get_random_vec3_in_range(.{0.0, 0.0, 0.0}, .{1.0, 1.0, 1.0});
		color.w = 1.0;
		
		<<it = Rect.{.{xx xoffset, xx yoffset, xx w, xx h}, random_get_within_range(0.9, 1.1)*30, rgba_to_u32(color)};
	}
	
	last := cast(float)seconds_since_init();
	while !window.should_close {
	
		profile_scope("Step");
	
		reset_temporary_storage();
		
		now := cast(float)seconds_since_init();
		delta := now-last;
		last=now;
		
		platform_poll_events();
		
		
		memset_u32(window.back_buffer.data, 0, window.back_buffer.count);
		
		
		push_random_seed(69);
		for * rects {
			it.aabb.x += delta*it.speed_factor;
			it.aabb.y += delta*it.speed_factor;
			
			if it.aabb.x > xx window.width   it.aabb.x = 0;
			if it.aabb.y > xx window.height  it.aabb.y = 0;
		}
		for rects {
			batch_push_rect(*batch, it.aabb, it.color);
		}
		
		
		while times.count > 500 {
			array_unordered_remove_by_index(*times, 0);
		}
		t0 := seconds_since_init();
		batch_flush(*batch, window.back_buffer);
		t1 := seconds_since_init();
		array_add(*times, t1-t0);
		log("avg %ms (%ms)", (array_sum(times)/xx times.count)*1000.0, (t1-t0)*1000.0);
		
		
		platform_update();
	}
}



Rect_Batch :: struct {
	Node :: struct {
		rects: [..] struct { color: u32; aabb: Vector4; };
		
		last_hash: u64;
	}

	width: int;
	height: int;
	active: bool;
	
	nodes: []Node;
	xnodes: int;
	ynodes: int;
	
	allocator: Allocator;
}

batch_init :: (using b: *Rect_Batch, w: int, h: int, hint_count := 250000/12) {
	assert(!active);
	width = w;
	height = h;
	active = true;
	
	//xnodes, ynodes = get_most_even_factors_for_product(platform.number_of_logical_processors);
	xnodes = 1;
	ynodes = platform.number_of_logical_processors;
	
	num_nodes := xnodes*ynodes;
	
	array_resize(*nodes, num_nodes);
	for * nodes  {
		array_reserve(*it.rects, hint_count);
		it.rects.allocator = context.allocator;
	}
	
	allocator = context.allocator;
	
	assert(xnodes*ynodes == num_nodes);
}
batch_push_rect :: (using b: *Rect_Batch, aabb: Vector4, color: u32) {
	profile_scope();

	xstart := cast(int)max(((aabb.x) / xx window.width)*xx xnodes, 0);
	ystart := cast(int)max(((aabb.y)/ xx window.height)*xx ynodes, 0);
	
	xend := cast(int)min(((aabb.x+aabb.z) / xx window.width)*xx xnodes, cast(float)xnodes-1);
	yend := cast(int)min(((aabb.y+aabb.w)/ xx window.height)*xx ynodes, cast(float)ynodes-1);
	
	node_width  := (cast(float)width/cast(float)xnodes);
	node_height := (cast(float)height/cast(float)ynodes);
	
	
	for xnode: xstart .. xend {
		for ynode: ystart .. yend {
			node := *nodes[ynode*xnodes+xnode];
			
			
			x0 := cast(float)xnode * node_width;
			y0 := cast(float)ynode * node_height;
			x1 := x0+node_width;
			y1 := y0+node_height;
			array_add(*node.rects, .{color=color, aabb=Vector4.{
				max(aabb.x, x0),
				max(aabb.y, y0),
				min(aabb.z, x1),
				min(aabb.w, y1),
			}});
		}
	}
}
batch_flush :: (using b: *Rect_Batch, frame_buffer: []u8) {
	//assert(active);
	active = false;
	
	current_render_batch = b;
	current_render_frame_buffer = frame_buffer;
	
	push_allocator(allocator);
	
	
	for * array_view(render_start_sems, 0, nodes.count) signal(it);
	
	for * array_view(render_done_sems, 0, nodes.count) wait_for(it);
	
	for nodes  array_reset_keeping_memory(*it.rects);
}

render_thread :: (t: *Thread) -> s64 {
	
	timeBeginPeriod(1);
	SetPriorityClass(GetCurrentProcess(), 0x00000080 /*REALTIME_PRIORITY_CLASS*/);
	SetThreadPriority(GetCurrentThread(), 15 /*THREAD_PRIORITY_TIME_CRITICAL*/);
	task_index: u32;
	AvSetMmThreadCharacteristicsA("Games", *task_index);
	
	render_index := <<cast(*int)t.data;
	
	while !window.should_close {
	
		sdbm_hash_64 :: (data: *void, size: int, h := 5381) -> u64 {
		    for 0..size-1 #no_abc #no_aoc {
		        h = (h << 33) + (h << 11) - h + (cast(*u8)data)[it];
		    }
		
		    return cast,no_check(u64) h;
		}
	
		wait_for(*render_start_sems[render_index]);
		defer signal(*render_done_sems[render_index]);
	
		using current_render_batch;
		
		node := *nodes[render_index];
		//hash := combine_hashes(node.last_hash, sdbm_hash_64(node.rects.data, node.rects.count*size_of(Rect_Batch.Rect)));
		//if node.last_hash == hash  continue;
		//node.last_hash = hash;
		
		frame_buffer := current_render_frame_buffer;
	
		node_width  := (cast(float)width/cast(float)xnodes);
		node_height := (cast(float)height/cast(float)ynodes);
		
		node_index_x := render_index % xnodes;
		node_index_y := render_index / xnodes;
		
		
		x0 := cast(int)(cast(float)node_index_x * node_width);
		y0 := cast(int)(cast(float)node_index_y * node_height);
		x1 := cast(int)(x0+node_width)-1;
		y1 := cast(int)(y0+node_height)-1;
		
		for rect: node.rects {
			w: int = xx rect.aabb.z;
			h: int = xx rect.aabb.w;
			#if DEBUG { // Simd memset is way slower than just setting like this in debug for some reason
				for px: max(cast(int)rect.aabb.x, 0)..min(cast(int)rect.aabb.x+w-1, window.width-1) {
					for py: max(cast(int)rect.aabb.y, 0)..min(cast(int)rect.aabb.y+h-1, window.height-1) {
						
						pixel := cast(*u32)*frame_buffer[(py*window.width+px)*4];
						<<pixel = rect.color;
					}
				}
			} else {
				for row_index: max(cast(int)rect.aabb.y, 0)..min(cast(int)rect.aabb.y+h-1, window.height-1) {
					row_pixels := cast(*u32)*frame_buffer[(row_index*window.width+cast(int)rect.aabb.x)*4];
					
					if w >= 32 {
						alignment := 16;
						if w >= 64 && check_feature(cpu_info.feature_leaves, x86_Feature_Flag.AVX2)
							alignment = 32;
						
						row_pixels_aligned := align_next(row_pixels, alignment);
						error := cast(int)(row_pixels_aligned-row_pixels);
						memset_u32(row_pixels, rect.color, error*size_of(u32));
						memset_u32(row_pixels_aligned, rect.color, (w-error)*size_of(u32));
					} else {
						memset_u32(row_pixels, rect.color, (w)*size_of(u32));
					}
				}
			}
		}
	}
	
	return 0;
}

log_file: File;
has_opened_log_file := false;
logger_proc :: (initial_message: string, data: *void, info: Log_Info) {
    if !initial_message then return;

	message := tprint("[%:%] %", info.location.fully_pathed_filename, info.location.line_number, initial_message);

    if !has_opened_log_file {
    	log_file, has_opened_log_file = file_open("log.txt", for_writing=true);
    	if !has_opened_log_file  print("Could not open log file\n");
    }
    
    if message[message.count-1] != #char "\n" {
        write_strings(message, "\n");
        file_write(*log_file, tprint("%\n", message));
    } else {
        write_strings(message);
        file_write(*log_file, message);
    }
}

#import "Basic";
#import "String";
#import "Math";
#import "Unicode";
#import "Random";
#import "File_Utilities";
#import "File";
#import "Thread";
#import "Hash";
#import "Hash_Table";
#import "stb_image";
#import "Machine_X64";

#load "platform.jai";
#load "utils.jai";
#load "input.jai";
#load "log.jai";
#load "google_trace.jai";
*/



/*

*/
#add_context chungus_arena: Arena;

times: [..]float64;

render_threads: []Thread;
current_render_batch: *Rect_Batch;
current_render_frame_buffer: []u8;
render_done_sems:  []Semaphore;
render_start_sems: []Semaphore;

Aabb :: struct {
	x: s16;
	y: s16;
	z: s16;
	w: s16;
}

main :: () {
	context.logger = logger_proc;
	platform_init();
	
	timeBeginPeriod(1);
	SetPriorityClass(GetCurrentProcess(), 0x00000080 /*REALTIME_PRIORITY_CLASS*/);
	SetThreadPriority(GetCurrentThread(), 15 /*THREAD_PRIORITY_TIME_CRITICAL*/);
	task_index: u32;
	AvSetMmThreadCharacteristicsA("Games", *task_index);
	
	defer dump_google_trace_result();
	
	//platform.number_of_logical_processors = 1;
	
	array_resize(*render_threads, platform.number_of_logical_processors,,chungus);
	array_resize(*render_done_sems, platform.number_of_logical_processors,,chungus);
	array_resize(*render_start_sems, platform.number_of_logical_processors,,chungus);
	
	indices: []int;
	array_resize(*indices, platform.number_of_logical_processors,,chungus);
	for *indices { <<it = it_index; }
	
	for * render_threads {
		thread_init(it, render_thread);
		thread_start(it);
		
		it.data = *indices[it_index];
		
		init(*render_done_sems[it_index]);
		init(*render_start_sems[it_index]);
		
		signal(*render_done_sems[it_index]);
	}
	
	back_batch: Rect_Batch;
	front_batch: Rect_Batch;
	batch_init(*back_batch, window.width, window.height,,arena_allocator(*context.chungus_arena));
	batch_init(*front_batch, window.width, window.height,,arena_allocator(*context.chungus_arena));
	
	Rect :: struct {
		aabb: Vector4;
		speed_factor: float;
		color: u32;
	}
	speed_factors: []float;
	
	NUM_RECTS :: 1000000;
	
	rects: []Rect;
	array_resize(*rects, NUM_RECTS);
	array_resize(*speed_factors, NUM_RECTS);
	
	for * it: rects {
		xoffset := cast(int)random_get_within_range(cast(float)0.0, cast(float)window.width);
		yoffset := cast(int)random_get_within_range(cast(float)0.0, cast(float)window.height);
		w := cast(int)random_get_within_range(cast(float)16, 32);
		h := cast(int)random_get_within_range(cast(float)16, 32);
		
		color: Vector4;
		color.xyz = get_random_vec3_in_range(.{0.0, 0.0, 0.0}, .{1.0, 1.0, 1.0});
		color.w = 1.0;
		
		<<it = Rect.{.{xx xoffset, xx yoffset, xx w, xx h}, random_get_within_range(0.9, 1.1)*30, rgba_to_u32(color)};
	}
	
	last := cast(float)seconds_since_init();
	while !window.should_close {
	
		profile_scope("Step");
	
		reset_temporary_storage();
		
		now := cast(float)seconds_since_init();
		delta := (now-last);
		last = now;
		
		platform_poll_events();
		
		
		
		
		push_random_seed(69);
		/*for 0..80000 {
		
			xoffset := cast(int)random_get_within_range(cast(float)0.0, cast(float)window.width);
			yoffset := cast(int)random_get_within_range(cast(float)0.0, cast(float)window.height);
			w := cast(int)random_get_within_range(cast(float)16, 32);
			h := cast(int)random_get_within_range(cast(float)16, 32);
			speed_factor :=random_get_within_range(0.9, 1.1);
		
			x: float = xx ((cast(int)(seconds_since_init() * 300*speed_factor)+xoffset) % (window.width));
			y: float = xx ((cast(int)(seconds_since_init() * 300*speed_factor)+yoffset) % (window.height));
			
			color: Vector4;
			color.xyz = get_random_vec3_in_range(.{0.0, 0.0, 0.0}, .{1.0, 1.0, 1.0});
			color.w = 1.0;
			batch_push_rect(*back_batch, .{x, y, (x+w), (y+h)}, rgba_to_u32(color));
		}*/
		t0 := seconds_since_init();
		for * rects {
			it.aabb.x += delta*it.speed_factor;
			it.aabb.y += delta*it.speed_factor;
			
			if it.aabb.x > xx window.width   it.aabb.x = 0;
			if it.aabb.y > xx window.height  it.aabb.y = 0;
		}
		for rects {
			batch_push_rect(*back_batch, .{it.aabb.x, it.aabb.y, it.aabb.z, it.aabb.w}, it.color);
		}
		t1 := seconds_since_init();
		array_add(*times, t1-t0);
		log("avg %ms (%ms)", (array_sum(times)/xx times.count)*1000.0, (t1-t0)*1000.0);
		
		
		
		while times.count > 500 {
			array_unordered_remove_by_index(*times, 0);
		}
		
		
		for * render_done_sems  wait_for(it);
		Swap(*front_batch, *back_batch);
		platform_update(); // Window swap
		memset_u32(window.back_buffer.data, 0, window.back_buffer.count);
		
		
		node_height := cast(s16)(window.height/render_threads.count);
	
		current_render_batch = *front_batch;
		current_render_frame_buffer = window.back_buffer;
		
		for t: 0..render_threads.count-1 {
		
			for 0..front_batch.rect_counts_per_thread[t]-1 {
				rect_float := (front_batch.rects+t*front_batch.max_quads_per_node)[it];
				rect_int :=  *(front_batch.rects_int+t*front_batch.max_quads_per_node)[it];
				
				rect_int.aabb.x = cast(s16)rect_float.aabb.x;
				rect_int.aabb.y = cast(s16)rect_float.aabb.y;
				rect_int.aabb.z = cast(s16)rect_float.aabb.z;
				rect_int.aabb.w = cast(s16)rect_float.aabb.w;
				rect_int.color = rect_float.color;
			}
		
			
		}
		
		for * render_start_sems  signal(it);
		
		for * back_batch.rect_counts_per_thread  { <<it = 0; }
		arena_reset(*back_batch.arena_rects);
		
		
		//batch_flush(*front_batch, window.back_buffer);
		
		
		
		
	}
}


Rect_Batch :: struct {
	rects: *struct{aabb: Vector4; color:u32; padding: u32; };
	rects_int: *struct{aabb: Aabb; color:u32; padding: u32; };
	//colors: *u32;
	arena_rects: Arena;
	//arena_colors: Arena;
	
	max_quads_per_node: int;
	
	rect_counts_per_thread: [1024]int;
}

batch_init :: (using b: *Rect_Batch, w: int, h: int, max_quads := 2500001) {
	arena_rects = arena_make_child(*context.chungus_arena, max_quads*size_of(type_of(<<rects)));
	//arena_colors = arena_make_child(*context.chungus_arena, max_quads*size_of(type_of(<<rects)));
	rects = xx arena_rects.head;
	rects_int = xx arena_rects.head;
	//colors = xx arena_colors.head;
	
	//for 0..render_threads.count-1 {
	//	lowest_rect_index_per_thread[it]=99999999;
	//}
	
	max_quads_per_node = max_quads/render_threads.count;
}
batch_push_rect :: (using b: *Rect_Batch, aabb: Vector4, color: u32) {
	profile_scope();

	//rect := cast(*type_of(<<rects))arena_push(*arena_rects, size_of(type_of(<<rects)));
	//pcolor := cast(*type_of(<<colors))arena_push(*arena_colors, size_of(type_of(<<colors)));
	
	//<<pcolor = color;
	//<<rect = .{
	//	aabb.x,
	//	aabb.y,
	//	aabb.z,
	//	aabb.w,
	//};
	
	node_height := cast(s16)(window.height/render_threads.count);
	
	for t: cast(int)aabb.y/node_height .. (cast(int)aabb.y+cast(int)aabb.w)/node_height {
		
		if rect_counts_per_thread[t] >= max_quads_per_node {
			log_error("A row node has too many quads in it !! it is ignored, something will look weird");
		}
	
		rect := *(rects+max_quads_per_node*t)[rect_counts_per_thread[t]];
	
		rect.aabb = .{
			aabb.x,
			aabb.y,
			aabb.z,
			aabb.w,
		};
		rect.color = color;
		
		rect_counts_per_thread[t] += 1;
	}
	
}
batch_flush :: (using b: *Rect_Batch, frame_buffer: []u8) {
	//assert(active);
	
	
	//arena_reset(*arena_colors);
}

render_thread :: (t: *Thread) -> s64 {
	
	timeBeginPeriod(1);
	SetPriorityClass(GetCurrentProcess(), 0x00000080 /*REALTIME_PRIORITY_CLASS*/);
	SetThreadPriority(GetCurrentThread(), 15 /*THREAD_PRIORITY_TIME_CRITICAL*/);
	task_index: u32;
	AvSetMmThreadCharacteristicsA("Games", *task_index);
	
	render_index := <<cast(*int)t.data;
	
	while !window.should_close {
	
		sdbm_hash_64 :: (data: *void, size: int, h := 5381) -> u64 {
		    for 0..size-1 #no_abc #no_aoc {
		        h = (h << 33) + (h << 11) - h + (cast(*u8)data)[it];
		    }
		
		    return cast,no_check(u64) h;
		}
	
		wait_for(*render_start_sems[render_index]);
		defer signal(*render_done_sems[render_index]);
	
		using current_render_batch;
		frame_buffer := current_render_frame_buffer;
		
		node_height := window.height/render_threads.count;
		
		
		node_y0 := cast(s16)(render_index*node_height);
		node_y1 := cast(s16)(node_y0+node_height);
		
		if render_index == render_threads.count-1 {
			node_y1 += cast(s16)ceil((fract(cast(float)window.height/cast(float)render_threads.count)*render_threads.count));
		}
		
		start := render_index*max_quads_per_node;
		//if lowest_rect_index_per_thread[render_index] != 99999999 {
		//	start = lowest_rect_index_per_thread[render_index];
		//}
		
		
		for start..start+rect_counts_per_thread[render_index]-1 {
			
			rect := rects_int[it];
			//color := colors[it];
			color := rect.color;
			
			draw_x0 := rect.aabb.x;
			draw_x1 := draw_x0+rect.aabb.z;
			
			draw_y0 := rect.aabb.y;
			draw_y1 := rect.aabb.y+rect.aabb.w;
			
			if (draw_y1 < node_y0) || (draw_y0 > node_y1) || draw_y1 <= draw_y0 || draw_x1 < 0 || draw_x0 >= xx window.width
				continue;
			
			draw_y0 = clamp(draw_y0, node_y0, node_y1);
			draw_y1 = clamp(draw_y1, node_y0, node_y1);
			
 			
			w: s16 = (draw_x1-draw_x0);
			h: s16 = (draw_y1-draw_y0);
			
			#if DEBUG { // Simd memset is way slower than just setting like this in debug for some reason
				for px: cast(s16)max(draw_x0, 0)..min(draw_x0+w-1, cast(s16)window.width-1) {
					for py: cast(s16)max(draw_y0, 0)..min(draw_y0+h-1, cast(s16)window.height-1) {
						
						pixel := cast(*u32)*frame_buffer[(py*window.width+px)*4];
						<<pixel = color;
					}
				}
			} else {
				for row_index: max(draw_y0, 0)..min(draw_y0+h-1, cast(s16)window.height-1) {
					row_pixels := cast(*u32)*frame_buffer[(row_index*window.width+draw_x0)*4];
					
						memset_u32(row_pixels, color, (w)*size_of(u32));
					//if w >= 32 {
					//	alignment := 16;
					//	if w >= 64 && check_feature(cpu_info.feature_leaves, x86_Feature_Flag.AVX2)
					//		alignment = 32;
					//	
					//	row_pixels_aligned := align_next(row_pixels, alignment);
					//	error := cast(int)(row_pixels_aligned-row_pixels);
					//	memset_u32(row_pixels, rect.color, error*size_of(u32));
					//	memset_u32(row_pixels_aligned, rect.color, (w-error)*size_of(u32));
					//} else {
					//}
				}
			}
		}
	}
	
	return 0;
}

log_file: File;
has_opened_log_file := false;
logger_proc :: (initial_message: string, data: *void, info: Log_Info) {
    if !initial_message then return;

	message := tprint("[%:%] %", info.location.fully_pathed_filename, info.location.line_number, initial_message);

    if !has_opened_log_file {
    	log_file, has_opened_log_file = file_open("log.txt", for_writing=true);
    	if !has_opened_log_file  print("Could not open log file\n");
    }
    
    if message[message.count-1] != #char "\n" {
        write_strings(message, "\n");
        file_write(*log_file, tprint("%\n", message));
    } else {
        write_strings(message);
        file_write(*log_file, message);
    }
}


#import "Basic";
#import "String";
#import "Math";
#import "Unicode";
#import "Random";
#import "File_Utilities";
#import "File";
#import "Thread";
#import "Hash";
#import "Hash_Table";
#import "stb_image";
#import "Machine_X64";

#load "platform.jai";
#load "utils.jai";
#load "input.jai";
#load "log.jai";
#load "google_trace.jai";

