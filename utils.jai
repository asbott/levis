

align_next :: inline (x: $T, a: $A) -> T #expand {
	return cast(T)((cast(int)x + cast(int)a - 1) & ~(cast(int)a - 1));
}

kb :: inline (n: int) -> int #expand {
	return 1024*n;
}
mb :: inline (n: int) -> int #expand {
	return 1024*kb(n);
}
gb :: inline (n: int) -> int #expand {
	return 1024*mb(n);
}

panic :: inline (message: string, args: .. Any) #expand {
	assert(false, message, ..args);
}

get_next_power_of_two :: (x: int) -> int {
	if x == 0 {
		return 1;
	}
	
	x -= 1;
	x |= x >> 1;
	x |= x >> 2;
	x |= x >> 4;
	x |= x >> 8;
	x |= x >> 16;
	x |= x >> 32;
	
	return x + 1;
}

wcscmp :: (a: *u16, b: *u16) -> int {
	while (<< a != 0 && << b != 0) {
		if (<< a != << b) {
			return << a - << b;
		}
		a += 1;
		b += 1;
	}
	
	return << a - << b;
}

offset_of :: ($T: Type, member: string) -> int {
	for type_info(T).members {
		if it.name == member return it.offset_in_bytes;
	}
	
	assert(false, "Type '%' does not have member '%'", T, member);
	return -1;
}

from_c_string :: (s: *u8) -> string {
	utf8: string;
	utf8.data = s;
	utf8.count = c_style_strlen(s);
	return utf8;
}

format_bytes :: (n: int) -> string {
	if n > gb(2)  return tprint("% gb", n/(1024*1024*1024));
	if n > mb(10) return tprint("% mb", n/(1024*1024));
	if n > kb(10) return tprint("% kb", n/(1024));
	return tprint("% bytes", n);
}



chungus_allocator :: (mode: Allocator_Mode, size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void {
	if #complete mode == {
		case .STARTUP;      #through;
		case .SHUTDOWN;     #through;
		case .THREAD_START; #through;
		case .THREAD_STOP;
		return null;
		
		case .ALLOCATE; #through;
		case .RESIZE;
		result := arena_push(*context.chungus_arena, size);
		if mode == .RESIZE {
			size_to_copy := min(old_size, size);
			if result && size_to_copy memcpy(result, old_memory, size_to_copy);
		}
		return result;
		
		case .FREE;
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
		if old_memory { <<cast(*string)old_memory = "boogabooga"; }
		return cast(*void) 0;
		
		case;
		context.handling_assertion_failure = true;
		context.assertion_failed(#location(), "Invalid or corrupt mode passed to Walloc.allocator_proc().\n");
		context.handling_assertion_failure = false;
		return null;
	}
}

chungus :: #run Allocator.{chungus_allocator, null};

arena_reset_to_here_after_scope :: (arena: *Arena) #expand {
	current := arena.next;
	`defer arena.next = current;
}

chungus_push :: (size: int) -> *void {
	return arena_push(*context.chungus_arena, size);
}
chungus_push :: ($T: Type, n := 1) -> *T {
	return chungus_push(size_of(T)*n);
}

// To use on arrays, where the arena is simply reset on each free (resize)
arena_allocator_array_proc :: (mode: Allocator_Mode, size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void {
	arena := cast(*Arena)allocator_data;
	if #complete mode == {
		case .STARTUP;      #through;
		case .SHUTDOWN;     #through;
		case .THREAD_START; #through;
		case .THREAD_STOP;
		return null;
		
		case .ALLOCATE; #through;
		case .RESIZE;
		result := arena_push(arena, size);
		assert(result != null, "Arena '%' is out of size (max is %, requested is %)", format_bytes(arena.reserved_size), format_bytes(size));
		if mode == .RESIZE {
			size_to_copy := min(old_size, size);
			if result && size_to_copy memcpy(result, old_memory, size_to_copy);
		}
		return result;
		
		case .FREE;
		arena_reset(arena);
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
		if old_memory { <<cast(*string)old_memory = "boogabooga"; }
		return cast(*void) 0;
		
		case;
		context.handling_assertion_failure = true;
		context.assertion_failed(#location(), "Invalid or corrupt mode passed to Walloc.allocator_proc().\n");
		context.handling_assertion_failure = false;
		return null;
	}
}

arena_allocator_proc :: (mode: Allocator_Mode, size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void {
	arena := cast(*Arena)allocator_data;
	if #complete mode == {
		case .STARTUP;      #through;
		case .SHUTDOWN;     #through;
		case .THREAD_START; #through;
		case .THREAD_STOP;
		return null;
		
		case .ALLOCATE; #through;
		case .RESIZE;
		result := arena_push(arena, size);
		assert(result != null, "Arena '%' is out of size (max is %, requested is %)", arena.name, format_bytes(arena.reserved_size), format_bytes(size));
		if mode == .RESIZE {
			size_to_copy := min(old_size, size);
			if result && size_to_copy memcpy(result, old_memory, size_to_copy);
		}
		return result;
		
		case .FREE;
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
		if old_memory { <<cast(*string)old_memory = "boogabooga"; }
		return cast(*void) 0;
		
		case;
		context.handling_assertion_failure = true;
		context.assertion_failed(#location(), "Invalid or corrupt mode passed to Walloc.allocator_proc().\n");
		context.handling_assertion_failure = false;
		return null;
	}
}

arena_allocator :: (arena: *Arena) -> Allocator {
	a: Allocator;
	a.proc = arena_allocator_proc;
	a.data = arena;
	return a;
}

array_resize_arena :: (array: *[]$T, count: int, arena: *Arena) {
	a: Allocator;
	a.proc = arena_allocator_array_proc;
	a.data = arena;
	
	array_resize(array, count,,a);
}

arenafy :: (array: *$T, arena: *Arena) {
	allocator: Allocator;
	allocator.proc = arena_allocator_array_proc;
	allocator.data = arena;
	
	array.allocator = allocator;
}

crash_on_allocation_proc :: (mode: Allocator_Mode, size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void {
	panic("This allocator was not supposed to be used");
	return null;
}

get_crash_allocator :: () -> Allocator {
	a: Allocator;
	a.proc = crash_on_allocation_proc;
	return a;
}

crash_allocator :: #run get_crash_allocator();


utf8_slice :: (str: string, index: int, count: int) -> string {
	byte_index := utf8_index_to_byte_index(str, index);
	byte_end_index := utf8_index_to_byte_index(str, index+count);
	byte_count := byte_end_index - byte_index;
	
	return slice(str, byte_index, byte_count);
}
utf8_index_to_byte_index :: (str: string, index: int) -> int {
	byte_index := 0;
	utf8_index := 0;
	while utf8_index < index && str.count != 0 {
		last_str := str;
		codepoint, result := utf8_next_character(*str);
		if result != .CONVERSION_OK then break;
		
		byte_diff := (cast(*u8)str.data)-(cast(*u8)last_str.data);
		assert(byte_diff != 0);
		byte_index += byte_diff;
		utf8_index += 1;
	}
	return byte_index;
}
get_utf32_at_index :: (str: string, index: int) -> u32 {
	if str.data == null then return 0;
	i := 0;
	while str.count > 0 {
		defer i += 1;
		codepoint, result := utf8_next_character(*str);
		if result != .CONVERSION_OK then break;
		
		if i == index then return codepoint;
	}
	
	assert(false, "index out of range");
	return 0;
}
utf8_count :: (str: string) -> int {
	if str.data == null || str.count <= 0 then return 0;
	i := 0;
	while str.count > 0 {
		codepoint, result := utf8_next_character(*str);
		if result != .CONVERSION_OK then break;
		i += 1;
	}
	return i;
}

round :: (x: $T) -> T {
	return floor(x+0.5);
}

smerp :: (from: $T, to: T, t: float) -> T {
	smooth := t * t * (3.0 - 2.0 * t);
	return lerp(from, to, smooth);
}
smerpsmerp :: smerp;

ease_out_quad :: (t: float) -> float {
	return 1.0 - (1.0 - t) * (1.0 - t);
}
ease_in_cubic :: (t: float) -> float {
	return t * t * t;
}

smerp2 :: (from: $T, to: T, t: float) -> T {
	smooth := ease_in_cubic(t);
	return lerp(from, to, smooth);
}

push_random_seed :: (new_seed: u64) #expand
{
	prev_state := context.random_state;
	random_seed(new_seed);
	`defer context.random_state = prev_state;
}

get_string_hash :: (s: string) -> u64 {
	return fnv1a_hash(s.data, s.count, 53815381);
}

animate_to_target :: (value: *float, target: float, delta_t: float, rate:= 15.0, good_enough:= 0.001) -> bool
{
	<<value += (target - <<value) * (1.0 - pow(2.0, -rate * delta_t));
	if almost_equals(<<value, target, good_enough)
	{
		<<value = target;
		return true; // reached
	}
	return false;
}

animate_to_target :: (value: *Vector2, target: Vector2, delta_t: float, rate := 15.0)
{
	value.x += (target.x - value.x) * (1.0 - pow(2.0, -rate * delta_t));
	value.y += (target.y - value.y) * (1.0 - pow(2.0, -rate * delta_t));
}

animate_to_target :: (value: *Vector4, target: Vector4, delta_t: float, rate := 15.0)
{
	value.x += (target.x - value.x) * (1.0 - pow(2.0, -rate * delta_t));
	value.y += (target.y - value.y) * (1.0 - pow(2.0, -rate * delta_t));
	value.z += (target.z - value.z) * (1.0 - pow(2.0, -rate * delta_t));
	value.w += (target.w - value.w) * (1.0 - pow(2.0, -rate * delta_t));
}

almost_equals :: (a: float, b: float, epsilon: float = 0.001) -> bool
{
	return abs(a - b) <= epsilon;
}

almost_equals :: (a: Vector2, b: Vector2, epsilon: float = 0.001) -> bool
{
	return almost_equals(a.x, b.x, epsilon) && almost_equals(a.y, b.y, epsilon);
}


scope_lock :: (m: *Mutex) #expand {
	lock(m);
	`defer unlock(m);
}

is_valid_enum_value :: (value: int, $Enum: Type) -> bool {

	for enum_values_as_enum(Enum)  if it == xx value  return true;

	return false;
}
is_valid_enum_value :: (value: $Enum) -> bool {

	for enum_values_as_enum(Enum)  if it == xx value  return true;

	return false;
}

get_random_float32_in_range :: (lo: float32, hi: float32) -> float32 {
	return random_get_within_range(lo, hi);
}
get_random_vec2_in_range :: (lo: Vector2, hi: Vector2) -> Vector2 {
	return .{
		get_random_float32_in_range(lo.x, hi.x),
		get_random_float32_in_range(lo.y, hi.y),
	};
}
get_random_vec3_in_range :: (lo: Vector3, hi: Vector3) -> Vector3 {
	return .{
		get_random_float32_in_range(lo.x, hi.x),
		get_random_float32_in_range(lo.y, hi.y),
		get_random_float32_in_range(lo.z, hi.z),
	};
}
get_random_vec4_in_range :: (lo: Vector4, hi: Vector4) -> Vector4 {
	return .{
		get_random_float32_in_range(lo.x, hi.x),
		get_random_float32_in_range(lo.y, hi.y),
		get_random_float32_in_range(lo.z, hi.z),
		get_random_float32_in_range(lo.w, hi.w),
	};
}

snap :: (x: $T, interval: T) -> T {
	return round(x/interval)*interval;
}

array_shift_left :: (array: *[]$T, $NO_ZERO := false) {
	memcpy(array.data, array.data+1, size_of(T)*(array.count-1));
	#if !NO_ZERO default_initialize(*(<< array)[array.count-1]);
}
array_shift_left_cycling :: (array: *[]$T) {
	t := (<< array)[0];
	memcpy(array.data, array.data+1, size_of(T)*(array.count-1));
	(<< array)[array.count-1] = t;
}
array_shift_left :: (array: *[$N]$T, $NO_ZERO := false) {
	memcpy(array.data, array.data+1, size_of(T)*(array.count-1));
		#if !NO_ZERO default_initialize(*(<< array)[array.count-1]);
}
array_shift_left_cycling :: (array: *[$N]$T) {
	t := (<< array)[0];
	memcpy(array.data, array.data+1, size_of(T)*(array.count-1));
	(<< array)[array.count-1] = t;
}

default_initialize :: (p: *$T) {
	ini :: initializer_of(T);
	
	#if ini  ini(p);
	else {
		memset(p, 0, size_of(T));
	}
}

combine_hashes :: inline (a: u64, b: u64) -> u64 {
    return a ^ (b + 0x9e3779b97f4A7C15 + (a << 12) + (a >> 4));
}

hash_struct_layout :: (s: *Type_Info_Struct) -> int {
	hash: int = 69420;
	
	for s.members {
		
		h := combine_hashes(xx,no_check get_hash(it.name), xx,no_check get_hash(it.type.runtime_size));
		h = combine_hashes(xx,no_check h, xx,no_check get_hash(it.offset_in_bytes));
		hash = xx,no_check combine_hashes(xx,no_check hash, xx,no_check h);
	}
	
	return hash;
}
hash_struct_layout :: ($T: Type) -> int {
	hash_struct_layout(type_info(T));
}

is_type_trivial :: (type: *Type_Info) -> bool {
	if type.type == {
		case .BOOL; #through;
		case .INTEGER; #through;
		case .FLOAT; #through;
		case .ENUM; 
			return true;
		case .STRUCT; 
		
			struct_info := cast(*Type_Info_Struct)type;
			
			for struct_info.members {
				if !is_type_trivial(it.type)  return false;
			}
			
			return true;
			
		case .ARRAY;
			array_info := cast(*Type_Info_Array)type;
			// Static arrays are trivial
			return array_info.array_count > 0 && is_type_trivial(array_info.element_type);
		
		case;
			return false;
	}
}

Pointer_Mapping :: struct {
	src_start: *void;
	src_end: *void;
	dst_start: *void;
}
serialize_non_trivial_parts_of_member :: (src: *void, dst: *void, type: *Type_Info, arena: *Arena, member_stack: *[..]Type_Info_Struct_Member, pointer_map: *[..]Pointer_Mapping, parent_start: *void, array_like_count := -1, array_like_type: *Type_Info = null) -> int {

	start := arena.next;

	// Return dst pointer which src pointer is mapped to, else null
	try_map_src_pointer :: (pointer_map: *[..]Pointer_Mapping, pointer: *void, size: int) -> *void {
		for <<pointer_map {
			if pointer >= it.src_start && pointer+size <= it.src_end  return it.dst_start + (pointer-it.src_start);
		}
		return null;
	}
	
	assert(!is_type_trivial(type));

	if type.type == .ARRAY {
		array_type := cast(*Type_Info_Array)type;
		
		if array_type.array_type == .FIXED {
			for 0..array_type.array_count-1 {
				serialize_non_trivial_parts_of_member(src+array_type.element_type.runtime_size*it, dst+array_type.element_type.runtime_size*it, array_type.element_type, arena, member_stack, pointer_map, parent_start);
			}
		} else if array_type.array_type == .VIEW {
			arr := cast(*Array_View_64)src;
			return serialize_non_trivial_parts_of_member(src, dst, type_info(Array_View_64), arena, member_stack, pointer_map, parent_start, array_like_count=arr.count, array_like_type=array_type.element_type);
		} else if array_type.array_type == .RESIZABLE {
			arr := cast(*Array_View_64)src;
			return serialize_non_trivial_parts_of_member(src, dst, type_info(Resizable_Array), arena, member_stack, pointer_map, parent_start, array_like_count=arr.count, array_like_type=array_type.element_type);
		}
		
	} else if type.type == .STRING {
		arr := cast(*Array_View_64)src;
		return serialize_non_trivial_parts_of_member(src, dst, type_info(Newstring), arena, member_stack, pointer_map, parent_start, array_like_count=arr.count, array_like_type=type_info(u8));
	} else if type.type == .STRUCT {
	
		struct_type := cast(*Type_Info_Struct)type;
		
		if array_find(struct_type.notes, "TaggedUnion") {
			
			kind_member: Type_Info_Struct_Member;
			value_member: Type_Info_Struct_Member;
			
			kind_found := false;
			value_found := false;
			
			for struct_type.members {
				if it.name == "kind" {
					assert(it.type.type == .ENUM, "Type tagged with TaggedUnion has a 'kind' member but it is not of type Enum");
					kind_found = true;
					kind_member = it;
				}
				if it.name == "union_value" {
					assert(it.type.type == .STRUCT && (cast(*Type_Info_Struct)it.type).textual_flags & .UNION, "Type tagged with TaggedUnion has a 'union_value' member but it is not a union");
					value_found = true;
					value_member = it;
				}
			}
			
			assert(kind_found, "Type tagged with TaggedUnion is missing a 'kind' member");
			assert(value_found, "Type tagged with TaggedUnion is missing a 'union_value' member");
			
			kind_enum := cast(*Type_Info_Enum)kind_member.type;
			value_union_type := cast(*Type_Info_Struct)value_member.type;
			
			kind_int: int;
			memcpy(*kind_int, src+kind_member.offset_in_bytes, kind_enum.runtime_size);
			
			member_index: int = -1;
				
			for m, mi: value_union_type.members {
				for e: kind_enum.values {
					if m.name == kind_enum.names[it_index] {
						member_index = mi;
						break;
					}
				}
			}
			assert(member_index != -1);
			
			// #Volatile 
			// Assumes Type_Info_Struct.members to be in the same order as they were when the Tag enum was generated.
			// I don't see a reason why it wouldn't, but if it isn't our program will shit its pants.
			member_to_serialize := value_union_type.members[member_index];
			
			type_to_serialize := member_to_serialize.type;
			
			array_add(member_stack, member_to_serialize);
			serialize_non_trivial_parts_of_member(src + value_member.offset_in_bytes, dst + value_member.offset_in_bytes, type_to_serialize, arena, member_stack, pointer_map, parent_start);
			pop(member_stack);
			
			
			
		} else {
			
			is_array_like := array_like_count != -1 && array_like_type != null;
			
			members: []Type_Info_Struct_Member;
			
			if struct_type.textual_flags & .UNION {
				array_resize(*members, 1,,temp);
				
				for struct_type.members {
					if !members[0].type || it.type.runtime_size > members[0].type.runtime_size  members[0] = it;
				}
				
			} else {
				members = struct_type.members;
			}
			
			for members  if !is_type_trivial(it.type) && !array_find(it.notes, "NoSerialize") && it.name != "allocator" {
				array_add(member_stack, it,,temp);
				if is_array_like && it.name == "data" {
					
					arr_struct_data := src;
					arr := cast(*Array_View_64)arr_struct_data;
					arr_data := arr.data;
					
					dst_arr := cast(*Array_View_64)dst;
					
					if arr.count > 0 && arr.data != null {
						mapped := try_map_src_pointer(pointer_map, arr_data, array_like_count*array_like_type.runtime_size);
						if mapped {
							dst_arr.data = xx(mapped-parent_start);
							assert(cast(u64)dst_arr.data < xx gb(69));
							return 0; // Pointer already mapped
						}
					
						mapping := array_add(pointer_map,,temp);
						mapping.src_start = arr_data;
						mapping.src_end = arr_data + array_like_count*array_like_type.runtime_size;
						mapping.dst_start = arena.next;
						
						array_data_dst := arena_push_copy(arena, arr_data, array_like_count*array_like_type.runtime_size);
						
						if !is_type_trivial(array_like_type) {
							for 0..array_like_count-1 {
								offset := array_like_type.runtime_size*it;
								serialize_non_trivial_parts_of_member(arr_data+offset, array_data_dst + offset, array_like_type, arena, member_stack, pointer_map, parent_start);
							}
						}
						
						dst_arr.data = xx (array_data_dst-parent_start);
						assert(cast(u64)dst_arr.data < xx gb(69));
					}
						
				} else {
					serialize_non_trivial_parts_of_member(src + it.offset_in_bytes, dst + it.offset_in_bytes, it.type, arena, member_stack, pointer_map, parent_start);
				}
				pop(member_stack);
			} else if it.name == "allocator" {
				memset(dst + it.offset_in_bytes, 0, size_of(Allocator));
			}
		}	
		
	} else if type.type == .POINTER { 
		// Stuff being non-trivial always boils down to a pointer where it eventually needs to come down to a trivial copy
		
		pointer_type := cast(*Type_Info_Pointer)type;
		
		src_pointer_pointer := cast(**void)src;
		pointer_to_src_data := <<src_pointer_pointer;
	
		if !pointer_to_src_data return 0;
	
		mapped := try_map_src_pointer(pointer_map, pointer_to_src_data, pointer_type.pointer_to.runtime_size);
		if mapped {
			<<cast(**void)dst = xx mapped-parent_start;
			assert(cast(u64)<<cast(**void)dst < xx gb(69));
			return 0; // Pointer already mapped
		}
	
		mapping := array_add(pointer_map,,temp);
		mapping.src_start = pointer_to_src_data;
		mapping.src_end = pointer_to_src_data + pointer_type.pointer_to.runtime_size;
		mapping.dst_start = arena.next;
		
		<<cast(**void)dst = xx mapping.dst_start-parent_start;
		assert(cast(u64)<<cast(**void)dst < xx gb(69));

		pointer_to_dst_data := arena_push_copy(arena, pointer_to_src_data, pointer_type.pointer_to.runtime_size);
		
		if !is_type_trivial(pointer_type.pointer_to) {
			serialize_non_trivial_parts_of_member(pointer_to_src_data, pointer_to_dst_data, pointer_type.pointer_to, arena, member_stack, pointer_map, parent_start);
		}
	} else {
		builder: String_Builder;
		append(*builder, "Unsupported type for serialization:\n",,temp);
		append(*builder, tprint("\t%\n", <<type),,temp);
		for < <<member_stack {
			append(*builder, tprint("in\t%: %\n", it.name, <<it.type));
		}
		panic(builder_to_string(*builder));
	}
	
	return xx (arena.next-start);
}

serialize :: (src: *void, struct_type: *Type_Info_Struct, arena: *Arena) -> *void, int {
	start := arena.next;
	
	pointer_map := New([..]Pointer_Mapping,,temp);
	member_stack := New([..]Type_Info_Struct_Member,,temp);
	
	pointer_map.allocator = temp;
	member_stack.allocator = temp;
	
	dst_struct := arena_push_copy(arena, src, struct_type.runtime_size);
	if !is_type_trivial(struct_type) {
		
		members: []Type_Info_Struct_Member;
		
		if struct_type.textual_flags & .UNION {
			array_resize(*members, 1,,temp);
			
			for struct_type.members {
				if !members[0].type || it.type.runtime_size > members[0].type.runtime_size  members[0] = it;
			}
			
		} else {
			members = struct_type.members;
		}
		
		for members  if !is_type_trivial(it.type) && !array_find(it.notes, "NoSerialize") && it.name != "allocator" {
			array_add(member_stack, it);
			serialize_non_trivial_parts_of_member(src + it.offset_in_bytes, dst_struct + it.offset_in_bytes, it.type, arena, member_stack, pointer_map, dst_struct);
			pop(member_stack);
		} else if it.name == "allocator" {
			memset(dst_struct+it.offset_in_bytes, 0, size_of(Allocator));
		}
	}
	
	return start, xx(cast(u64)arena.next-cast(u64)start);
}
serialize :: (item: $T, arena: *Arena) -> *void, int {

	t :: #run type_info(T);
	
	data,size := serialize(*item, t, arena);
	return data,size;
}

// NOTE: All non-trivial data will be "re-instated" (allocated & copied) using context.allocator
deserialize :: (data: *void, dst: *void, struct_type: *Type_Info_Struct, _base_pointer := null, big_allocator := context.allocator, big_threshold := 1024) {

	set_pointers :: (data: *void, dst: *void, type: *Type_Info, base_pointer: *void, pointer_map: *[..]Pointer_Mapping, big_allocator: Allocator, big_threshold: int) {
		
		try_map_src_pointer :: (pointer_map: *[..]Pointer_Mapping, pointer: *void, size: int) -> *void {
			for <<pointer_map {
				if pointer >= it.src_start && pointer+size <= it.src_end  return it.dst_start + (pointer-it.src_start);
			}
			return null;
		}
		
		special_alloc :: (sz: int, big_allocator: Allocator, big_threshold: int) -> *void {
			return alloc(sz,,ifx sz >= big_threshold  big_allocator else context.allocator);
		}
		
		if type.type == .ARRAY {
			array_type := cast(*Type_Info_Array)type;
			
			if array_type.array_type == .FIXED {
				assert(!is_type_trivial(array_type.element_type));
				
				for 0..array_type.array_count-1 {
					set_pointers(data+it*array_type.element_type.runtime_size, dst+it*array_type.element_type.runtime_size, array_type.element_type, base_pointer, pointer_map, big_allocator, big_threshold);
				}
			} else if array_type.array_type == .VIEW || array_type.array_type == .RESIZABLE {
				src_arr := cast(*Array_View_64)data;
				dst_arr := cast(*Array_View_64)dst;
				<<dst_arr = <<src_arr;
				dst_arr.data = null;
				
				if src_arr.count != 0 {
				
					mapped := try_map_src_pointer(pointer_map, src_arr.data, src_arr.count*array_type.element_type.runtime_size);
					if !mapped {
						// relative pointer correction
						assert(cast(u64)src_arr.data < xx gb(69)); // Relative pointer should be small
						src_arr.data = xx (src_arr.data + cast(u64)base_pointer);
						dst_arr.data = special_alloc(src_arr.count*array_type.element_type.runtime_size, big_allocator, big_threshold);
						
						memcpy(dst_arr.data, src_arr.data, src_arr.count*array_type.element_type.runtime_size);
						
						if array_type.array_type == .RESIZABLE {
							r := cast(*Resizable_Array)dst_arr;
							r.allocator = context.allocator;
							r.allocated = r.count;
						}
						
						if !is_type_trivial(array_type.element_type) {
							next_src := src_arr.data;
							next_dst := dst_arr.data;
							while next_src < src_arr.data + src_arr.count*array_type.element_type.runtime_size {
								set_pointers(next_src, next_dst, array_type.element_type, base_pointer, pointer_map, big_allocator, big_threshold);
								next_src += array_type.element_type.runtime_size;
								next_dst += array_type.element_type.runtime_size;
							}
						}
						
						mapping: Pointer_Mapping;
						
						mapping.src_start = src_arr.data;
						mapping.src_end   = src_arr.data+src_arr.count*array_type.element_type.runtime_size;
						mapping.dst_start = dst_arr.data;
						array_add(pointer_map, mapping,,temp);
					} else {
						dst_arr.data = mapped;
						dst_arr.count = src_arr.count;
						if array_type.array_type == .RESIZABLE {
							r := cast(*Resizable_Array)dst_arr;
							r.allocator = context.allocator;
							r.allocated = r.count;
						}
					}
				} else {
					dst_arr.count = 0;
					dst_arr.data = null;
					if array_type.array_type == .RESIZABLE {
						r := cast(*Resizable_Array)dst_arr;
						r.allocator = .{};
						r.allocated = 0;
					}
				}
				
				
			}
			
		} else if type.type == .STRING {
			src_arr := cast(*Newstring)data;
			dst_arr := cast(*Newstring)dst;
			
			if src_arr.count != 0 {
				mapped := try_map_src_pointer(pointer_map, src_arr.data, src_arr.count);
				if !mapped {
					// relative pointer correction
					assert(cast(u64)src_arr.data < xx gb(69)); // Relative pointer should be small
					src_arr.data = xx (src_arr.data + cast(u64)base_pointer);
					
					<<dst_arr = <<src_arr;
					dst_arr.data = special_alloc(src_arr.count, big_allocator, big_threshold);
					memcpy(dst_arr.data, src_arr.data, src_arr.count);
					
					mapping: Pointer_Mapping;
					mapping.src_start = src_arr.data;
					mapping.src_end = src_arr.data + src_arr.count;
					mapping.dst_start = dst_arr.data;
					
					array_add(pointer_map, mapping,,temp);
				} else {
					dst_arr.data = mapped;
					dst_arr.count = src_arr.count;
				}
			}
		} else if type.type == .STRUCT {
			struct_type := cast(*Type_Info_Struct)type;
			
			// We need to maintain whatever the dst memory is for NoSerializer members.
			no_serialize_copies: [..]struct { src: *void; dst: *void; size: int; };
			for struct_type.members if array_find(it.notes, "NoSerialize") {
				backup := talloc(it.type.runtime_size);
				memcpy(backup, dst + it.offset_in_bytes, it.type.runtime_size);
				array_add(*no_serialize_copies, .{backup, dst + it.offset_in_bytes, it.type.runtime_size},,temp );
			}
			
			memcpy(dst, data, struct_type.runtime_size);
			
			for no_serialize_copies {
				memcpy(it.dst, it.src, it.size);
			}
			
			if array_find(struct_type.notes, "TaggedUnion") {
			
				kind_member: Type_Info_Struct_Member;
				value_member: Type_Info_Struct_Member;
				
				kind_found := false;
				value_found := false;
				
				for struct_type.members {
					if it.name == "kind" {
						assert(it.type.type == .ENUM, "Type tagged with TaggedUnion has a 'kind' member but it is not of type Enum");
						kind_found = true;
						kind_member = it;
					}
					if it.name == "union_value" {
						assert(it.type.type == .STRUCT && (cast(*Type_Info_Struct)it.type).textual_flags & .UNION, "Type tagged with TaggedUnion has a 'union_value' member but it is not a union");
						value_found = true;
						value_member = it;
					}
				}
				
				assert(kind_found, "Type tagged with TaggedUnion is missing a 'kind' member");
				assert(value_found, "Type tagged with TaggedUnion is missing a 'union_value' member");
				
				kind_enum := cast(*Type_Info_Enum)kind_member.type;
				value_union_type := cast(*Type_Info_Struct)value_member.type;
				
				kind_int: int;
				memcpy(*kind_int, data+kind_member.offset_in_bytes, kind_enum.runtime_size);
				
				member_index: int = -1;
				
				for m, mi: value_union_type.members {
					for e: kind_enum.values {
						if m.name == kind_enum.names[it_index] {
							member_index = mi;
							break;
						}
					}
				}
				assert(member_index != -1);
				
				// #Volatile 
				// Assumes Type_Info_Struct.members to be in the same order as they were when the Tag enum was generated.
				// I don't see a reason why it wouldn't, but if it isn't our program will shit its pants.
				member_to_deserialize := value_union_type.members[member_index];
				
				type_to_deserialize := member_to_deserialize.type;
				
				set_pointers(data + value_member.offset_in_bytes, dst + value_member.offset_in_bytes, type_to_deserialize, base_pointer, pointer_map, big_allocator, big_threshold);
				
			} else {
				members: []Type_Info_Struct_Member;
			
				if struct_type.textual_flags & .UNION {
					array_resize(*members, 1,,temp);
					
					for struct_type.members {
						if !members[0].type || it.type.runtime_size > members[0].type.runtime_size  members[0] = it;
					}
					
				} else {
					members = struct_type.members;
				}
				
				for members {
					if !is_type_trivial(it.type) && !array_find(it.notes, "NoSerialize") && it.name != "allocator" {
						set_pointers(data + it.offset_in_bytes, dst + it.offset_in_bytes, it.type, base_pointer, pointer_map, big_allocator, big_threshold);
					} 
				} 
			}
			
			
		
		} else if type.type == .POINTER {
			pointer_type := cast(*Type_Info_Pointer)type;
			src_pointer_pointer := cast(**void)data;
			src_pointer := <<src_pointer_pointer;
			
			
			if src_pointer != null {
				
				mapped := try_map_src_pointer(pointer_map, src_pointer, pointer_type.pointer_to.runtime_size);
				
				if !mapped {
				
					dst_pointer := special_alloc(pointer_type.pointer_to.runtime_size, big_allocator, big_threshold);
					if pointer_type.pointer_to.type == .STRUCT {
						s := cast(*Type_Info_Struct)pointer_type.pointer_to;
						if s.initializer  s.initializer(dst_pointer);
					}
					// relative pointer correction
					assert(cast(u64)src_pointer < xx gb(69)); // Relative pointer should be small
					<<src_pointer_pointer += cast(u64) base_pointer;
					src_pointer = <<src_pointer_pointer;
					memcpy(dst_pointer, src_pointer, pointer_type.pointer_to.runtime_size);
					if !is_type_trivial(pointer_type.pointer_to) {
						set_pointers(src_pointer, dst_pointer, pointer_type.pointer_to, base_pointer, pointer_map, big_allocator, big_threshold);
					}
					
					mapping: Pointer_Mapping;
					mapping.src_start = src_pointer;
					mapping.src_end = src_pointer + pointer_type.pointer_to.runtime_size;
					mapping.dst_start = dst_pointer;
					
					array_add(pointer_map, mapping,,temp);
					
					<<cast(**void)dst = dst_pointer;
				} else {
					<<cast(**void)dst = mapped;
					
				}
				
			} else {
				<<cast(**void)dst = null;
			}
		}
		
	}
		
		
	base_pointer := _base_pointer;
	if !base_pointer  base_pointer = data;

	// We need to maintain whatever the dst memory is for NoSerializer members.
	no_serialize_copies: [..]struct { src: *void; dst: *void; size: int; };
	for struct_type.members if array_find(it.notes, "NoSerialize") {
		backup := talloc(it.type.runtime_size);
		memcpy(backup, dst + it.offset_in_bytes, it.type.runtime_size);
		array_add(*no_serialize_copies, .{backup, dst + it.offset_in_bytes, it.type.runtime_size},,temp );
	}
	
	memcpy(dst, data, struct_type.runtime_size);
	
	for no_serialize_copies  memcpy(it.dst, it.src, it.size);

	if !is_type_trivial(struct_type) {
	
		pointer_map: [..]Pointer_Mapping;
		pointer_map.allocator = temp;
		
		members: []Type_Info_Struct_Member;
		
		if struct_type.textual_flags & .UNION {
			array_resize(*members, 1,,temp);
			
			for struct_type.members {
				if !members[0].type || it.type.runtime_size > members[0].type.runtime_size  members[0] = it;
			}
			
		} else {
			members = struct_type.members;
		}
		
		for members  if !is_type_trivial(it.type) && !array_find(it.notes, "NoSerialize") && it.name != "allocator" {
			set_pointers(data + it.offset_in_bytes, dst + it.offset_in_bytes, it.type, base_pointer, *pointer_map, big_allocator, big_threshold);
		}
		
	}
}
deserialize :: (data: *void, p: *$T, big_allocator := context.allocator, big_threshold := 1024) {
	deserialize(data, p, type_info(T), big_allocator=big_allocator, big_threshold=big_threshold);
}

// in-place
deep_copy :: (dst: *$T, src: T, dst_size := -1) -> int {	
	if dst_size == -1  dst_size = size_of(T);
	
	t := talloc(dst_size);
	memset(t, 0, dst_size);
	arena := arena_make(t, dst_size);
	
	p, size := serialize(src, *arena);
	
	result := deserialize(p, dst);
	
	return size;
}

array_sum :: (array: []$T) -> T {
	acc: T;
	
	for array  acc += it;
	
	return acc;
}

array_pop_front :: (array: *[]$T) {
	array_ordered_remove_by_index(array, 0);
}

// Function to get the fractional part of a float
fract :: (x: float) -> float {
    return x - floor(x);
}

// RGB to HSV conversion
rgb_to_hsv :: (c: Vector3) -> Vector3 {
    c_max := max(c.x, max(c.y, c.z));
    c_min := min(c.x, min(c.y, c.z));
    delta := c_max - c_min;

    h: float = 0.0;

    if delta > 0.0 {
        if c_max == c.x {
            h = fmod_cycling(((c.y - c.z) / delta), 6.0);
            if h < 0.0 { h += 6.0; } // Ensure h is positive
        } else if c_max == c.y {
            h = ((c.z - c.x) / delta) + 2.0;
        } else {
            h = ((c.x - c.y) / delta) + 4.0;
        }
        h /= 6.0; // Normalize to [0,1]
    }

    s: float;
    if c_max == 0.0 {
        s = 0.0;
    } else {
        s = delta / c_max;
    }

    v := c_max;

    return Vector3.{h, s, v};
}

// HSV to RGB conversion
hsv_to_rgb :: (c: Vector3) -> Vector3 {
    h := c.x * 6.0; // Scale hue to [0,6)
    s := c.y;
    v := c.z;

    i := cast(int)floor(h) % 6; // Ensure i is within [0,5]
    f := h - floor(h);

    p := v * (1.0 - s);
    q := v * (1.0 - s * f);
    t := v * (1.0 - s * (1.0 - f));

    rgb: Vector3;

    if i == 0 {
        rgb = Vector3.{v, t, p};
    } else if i == 1 {
        rgb = Vector3.{q, v, p};
    } else if i == 2 {
        rgb = Vector3.{p, v, t};
    } else if i == 3 {
        rgb = Vector3.{p, q, v};
    } else if i == 4 {
        rgb = Vector3.{t, p, v};
    } else { // i == 5
        rgb = Vector3.{v, p, q};
    }

    return rgb;
}

// Interpolates between two RGBA colors in HSV space
transition_color_linear :: (color1: Vector4, color2: Vector4, t: float) -> Vector4 {
    hsv1 := rgb_to_hsv(color1.xyz);
    hsv2 := rgb_to_hsv(color2.xyz);

    // Handle hue wrapping
    if abs(hsv1.x - hsv2.x) > 0.5 {
        if hsv1.x > hsv2.x {
            hsv2.x += 1.0;
        } else {
            hsv1.x += 1.0;
        }
    }

    // Interpolate HSV components
    hsv_result := hsv1 * (1.0 - t) + hsv2 * t;
    hsv_result.x = fract(hsv_result.x); // Ensure hue is within [0,1)

    rgb_result := hsv_to_rgb(hsv_result);
    alpha := color1.w * (1.0 - t) + color2.w * t;

    return Vector4.{rgb_result.x, rgb_result.y, rgb_result.z, alpha};
}


// max EXCLUSIVE
random_get_within_range :: inline (min: int, max: int) -> int {
	assert(max >= min);
	if min == max return min;
	
	return min + cast,no_check(int)(random_get() % cast(u64)(max-min));
}


Tagged_Union :: struct($Union: Type, $Tag_Enum: Type = void) {
	
	using union_value: Union;
	
	#insert #run -> string {
		builder: String_Builder;
		
		#assert type_of(<<type_info(Union)) == Type_Info_Struct;
		
		enum_name := "Tag";
		
		underlying_int_type: string;
		
		if type_info(Union).members.count < 128  underlying_int_type = "s8";
		else                                     underlying_int_type = "s16";
		
		#if Tag_Enum == void {
			
			append(*builder, tprint("% :: enum % {\n", enum_name, underlying_int_type));
			
			for type_info(Union).members {
				append(*builder, tprint("%;\n", it.name));
				
			}
			
			append(*builder, tprint("\n} @NoSerialize\ntag: %;\n", enum_name));
		} else {
			append(*builder, tprint("% :: %; @NoSerialize\n", enum_name, tprint("%", Tag_Enum)));
			append(*builder, tprint("\ntag: %;\n", enum_name));
		}
		
		return builder_to_string(*builder);
	};
	
} @TaggedUnion

union_get :: (u: *Tagged_Union($T, $Tag), $Get_Type: Type) -> *Get_Type {
	get_tag :: #run -> Tag {
		type_name := tprint("%", Get_Type);
		to_lower_in_place(type_name);
		for enum_names(Tag) {
			if type_name == it  return enum_values_as_enum(Tag)[it_index];
			
		}
		return xx -1;
	};
	
	assert_fail_msg :: #run tprint("Invalid type % passed to union_get", Get_Type);
	#run assert(get_tag != xx -1, assert_fail_msg);
	
	assert(u.tag == get_tag, "Tried to get union value as type % (%), but it was tagged as %", Get_Type, get_tag, u.tag);
	
	return xx *u.union_value;
}

memset_u32 :: (dst: *void, $$ _v: u32, $$ amount_in_bytes: int) {

	can_avx2 := check_feature(cpu_info.feature_leaves, x86_Feature_Flag.AVX2);

	p0 := dst;
	
	p := p0;
	
	// Intrinsic memset is faster if the 4 bytes are all the same
	#if is_constant(_v) {
		   #if (_v & 0x000000ff) == ((_v & 0x0000ff00)>>8)
		    && (_v & 0x0000ff00) == ((_v & 0x00ff0000)>>8)
		    && (_v & 0x00ff0000) == ((_v & 0xff000000)>>8) {
		    	memset(dst, xx,no_check _v, amount_in_bytes);
				return;
		    }
		    
	} else {
		if (_v & 0x000000ff) == ((_v & 0x0000ff00)>>8)
		&& (_v & 0x0000ff00) == ((_v & 0x00ff0000)>>8)
		&& (_v & 0x00ff0000) == ((_v & 0xff000000)>>8) {
			memset(dst, xx,no_check _v, amount_in_bytes);
			return;
		}
	}
	v := _v;
	
	
	if can_avx2 && amount_in_bytes >= 64 { // Probably not worth it under 64 because manually setting trailing bytes
		stride :: size_of(u32)*8;
		#if is_constant(amount_in_bytes) {
			simdable :: #run amount_in_bytes - amount_in_bytes%stride;
			trailing_bytes :: #run amount_in_bytes - simdable;
			has_trailing_bytes :: #run trailing_bytes > 0;
		} else {
			simdable := amount_in_bytes - amount_in_bytes%stride;
			trailing_bytes := amount_in_bytes - simdable;
			has_trailing_bytes := trailing_bytes > 0;
		}
		
		p1 := p0 + simdable;
		if cast(u64)dst % 32 == 0 {
			
			while p < p1 {
				defer p += stride;
				
				#asm AVX, AVX2 {
					broadcastss.y c256:, [*v];
					movdqa.y [p], c256;
				}
				
			}
			
		} else {
		
			while p < p1 {
				defer p += stride;
				
				#asm AVX, AVX2 {
					broadcastss.y c256:, [*v];
					movdqu.y [p], c256;
				}
				
			}
			
		}
		if has_trailing_bytes {
			p = p1;
			p1 = p1 + trailing_bytes;
			while p+size_of(u32) < p1 {
				defer p += size_of(u32);
				<<cast(*u32)p = v;
			}
			i := 0;
			while p < p1 {
				defer p += 1;
				defer i += 1;
				<<cast(*u8)p = (cast(*u8)*v)[i];
			}
		}
	} else {
		stride :: size_of(u32)*4;
		#if is_constant(amount_in_bytes) {
			simdable :: #run amount_in_bytes - amount_in_bytes%stride;
			trailing_bytes :: #run amount_in_bytes - simdable;
			has_trailing_bytes :: #run trailing_bytes > 0;
		} else {
			simdable := amount_in_bytes - amount_in_bytes%stride;
			trailing_bytes := amount_in_bytes - simdable;
			has_trailing_bytes := trailing_bytes > 0;
		}
		
		p1 := p0 + simdable;
		if cast(u64)dst % 16 == 0 {
			while p < p1 {
				defer p += stride;
				
				#asm {
					movd c128:, [*v];
					pshufd c128, c128, 0;
					movdqu [p], c128;
				}
				
			}
		} else {
			while p < p1 {
				defer p += stride;
				
				#asm {
					movd c128:, [*v];
					pshufd c128, c128, 0;
					movdqu [p], c128;
				}
				
			}
		}
		if has_trailing_bytes {
			p = p1;
			p1 = p1 + trailing_bytes;
			while p+size_of(u32) < p1 {
				defer p += size_of(u32);
				<<cast(*u32)p = v;
			}
			i := 0;
			while p < p1 {
				defer p += 1;
				defer i += 1;
				<<cast(*u8)p = (cast(*u8)*v)[i];
			}
		}
	}
	

	
} 

test_memset_simd :: () {
	cpu_info = get_cpu_info();
	
	_mem: [256]u32;
	mem: []u32;
	
	mem.count = 64;
	mem.data = align_next(_mem.data, 32);
	
	memset_u32(mem.data, 0xff0000ff, 256);
	
	for 0..63 {
		if it % 16 == 0  print("\n");
		print("0x% ", formatInt(mem[it], base=16));
	}
}




rgba_to_u32 :: (v: Vector4) -> u32 {
	return rgba_to_u32(v.x, v.y, v.z, v.w);
}
rgba_to_u32 :: (r: f32, g: f32, b: f32, a: f32) -> u32 {
	v: u32;
	
	v = ((cast(u32) round(clamp(r, 0, 1)*255))      & 0x000000ff)
	  | (((cast(u32)round(clamp(g, 0, 1)*255))<<8)  & 0x0000ff00)
	  | (((cast(u32)round(clamp(b, 0, 1)*255))<<16) & 0x00ff0000)
	  | (((cast(u32)round(clamp(a, 0, 1)*255))<<24) & 0xff000000);
	
	return v;
}

u32_to_rgba :: (v: u32) -> Vector4 {
	return .{
		cast(f32) (v & 0x000000ff)     /255.0,
		cast(f32)((v & 0x0000ff00)>>8) /255.0,
		cast(f32)((v & 0x00ff0000)>>16)/255.0,
		cast(f32)((v & 0xff000000)>>24)/255.0,
	};
}

f32 :: float32;
f64 :: float64;

get_most_even_factors_for_product :: (p: int) -> int, int {
	a := cast(int) sqrt(cast(float)p);
	b := cast(int) sqrt(cast(float)p);

	adone := false;
	bdone := false;
	
	index := 0;
	while a*b < p {
		defer index += 1;
		
		if index % 2 == 0 {
			a += 1;
			if a*b > p {
				a -= 1;
				if bdone {
					break;
				}
				adone = true;
			}
		} else {
			b += 1;
			if b*b > p {
				b -= 1;
				if adone {
					break;
				}
				bdone = true;
			}
		}
	}
	
	return a, b;
}