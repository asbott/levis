
Input_Event_Kind :: enum u8 {
	HANDLED; // Can set to this to mark as handled/invalidate
	KEY;
	SCROLL;
	TEXT;
	GAMEPAD_AXIS;
};

Input_Key_Code :: enum u8 {
	UNKNOWN :: 0;

    // Non-textual keys that have placements in the ASCII table
    // (and thus in Unicode):

    BACKSPACE   :: 8;
    TAB         :: 9;
    ENTER       :: 13;
    ESCAPE      :: 27;
    SPACEBAR    :: 32;

    // The letters A-Z live in here as well and may be returned
    // by keyboard events.

    DELETE      :: 127;
    ARROW_UP    :: 128;
    ARROW_DOWN  :: 129;
    ARROW_LEFT  :: 130;
    ARROW_RIGHT :: 131;
    PAGE_UP     :: 132;
    PAGE_DOWN   :: 133;
    HOME        :: 134;
    END         :: 135;
    INSERT      :: 136;
    PAUSE       :: 137;
    SCROLL_LOCK :: 138;

    ALT;
    CTRL;
    SHIFT;
    CMD;
    META :: CMD;

    F1;
    F2;
    F3;
    F4;
    F5;
    F6;
    F7;
    F8;
    F9;
    F10;
    F11;
    F12;

    PRINT_SCREEN;

	DPAD_UP;
	DPAD_RIGHT;
	DPAD_DOWN;
	DPAD_LEFT;
	
	GAMEPAD_A;
	GAMEPAD_X;
	GAMEPAD_Y;
	GAMEPAD_B;
	
	GAMEPAD_START;
	GAMEPAD_BACK;
	
	GAMEPAD_LEFT_STICK;
	GAMEPAD_RIGHT_STICK;
	
	GAMEPAD_LEFT_BUMPER;
	GAMEPAD_RIGHT_BUMPER;
	GAMEPAD_LEFT_TRIGGER;
	GAMEPAD_RIGHT_TRIGGER;

    MOUSE_BUTTON_LEFT;
    MOUSE_BUTTON_MIDDLE;
    MOUSE_BUTTON_RIGHT;
    
    GAMEPAD_FIRST :: GAMEPAD_START;
    GAMEPAD_LAST  :: GAMEPAD_RIGHT_TRIGGER;
    
    MOUSE_FIRST :: MOUSE_BUTTON_LEFT;
    MOUSE_LAST  :: MOUSE_BUTTON_RIGHT;
}


Input_State_Flags :: enum_flags u8 {
	DOWN;
	JUST_PRESSED;
	JUST_RELEASED;
	REPEAT;
};

Input_Axis_Flags :: enum_flags u8 {
	LEFT_STICK;
	RIGHT_STICK;
	LEFT_TRIGGER;
	RIGHT_TRIGGER;
}

Input_Event :: struct {
	kind: Input_Event_Kind;

	// For KEY
	key_code: Input_Key_Code;
	key_state: Input_State_Flags;
	
	// For GAMEPAD_AXIS
	// Only the changed axes have valid values
	axes_changed:  Input_Axis_Flags;
	left_stick:    Vector2;
	right_stick:   Vector2;
	left_trigger:  float32;
	right_trigger: float32;

	// For SCROLL
	xscroll: float32;
	yscroll: float32;
	
	// For TEXT_INPUT
	union { utf32: u32; ascii: u8; };

	// For KEY
	// For GAMEPAD_AXIS
	gamepad_index: s8 = -1; // -1 if key is not from a gamepad
	
	
	
}  #no_padding

COMPRESS_BITS_PER_GAMEPAD_STICK_AXIS :: 8;
COMPRESS_BITS_PER_GAMEPAD_TRIGGER_AXIS :: 6;
COMPRESS_BITS_PER_SCROLL_AXIS :: 6;

compress_input_event :: (e: Input_Event, arena: *Arena) -> *void, total_bytes: int, pad_bits: int {
	//start := arena.head;
	
	bit_stack: [..]u8;
	n := 0;
	
	push_bits :: (stack: *[..]u8, p: *$Int, start: int, nbits: int) -> int {
	
		required_ints := (start + nbits+7)/8;
		if stack.count < required_ints  array_resize(stack, required_ints,,temp);
	
		dst_int := *(<<stack)[start/8];
		src_int := p;
		
		dst_bit := start % 8;
		src_bit := 0;
		
		for 0..nbits-1 {
			
			//<<dst_int = (<<dst_int) | (((cast(u64)<<src_int) << src_bit) & (0x1 << (size_of(Int)*8-1)) >> dst_bit);
			
			src_bit_value := cast,no_check(u8)(((<<src_int) >> src_bit) & 1);
			<<dst_int = (<<dst_int) | (src_bit_value << dst_bit);
			
			dst_bit += 1;
			src_bit += 1;
			
			if dst_bit == 8 {
				dst_bit = 0;
				dst_int += 1;
			}
			if src_bit == size_of(Int)*8 {
				src_bit = 0;
				src_int += 1;
			}
		}
		
		return start + nbits;
	}
	
	push_enum :: (stack: *[..]u8, v: $Enum, start: int) -> int #must {
		highest_value := enum_highest_value(Enum);
		kind_bits := cast(u8)ceil( log(cast(float64)highest_value + 1) / log(2.0) );
		return push_bits(stack, *v, start, kind_bits);
	}
	push_int :: (stack: *[..]u8, v: $Int, start: int, max_bits := 0) -> int #must {
		if !max_bits  max_bits = size_of(Int)*8;
		return push_bits(stack, *v, start, max_bits);
	}
	
	push_float32_compressed :: (stack: *[..]u8, v: float32, start: int, min: float32, max: float32, $bits: int) -> int #must {
		scale := (pow(2.0, xx bits) - 1) / (max - min);
		
	    compressed := cast(int)round(((v - min) * scale));
	    
	    return push_int(stack, compressed, start, max_bits = bits);
	}
	
	n = push_enum(*bit_stack, e.kind, n);
	
	if #complete e.kind == {
		case .HANDLED;
			// Event is handled, no data needed
		case .KEY;
			n = push_enum(*bit_stack, e.key_code, n);
			n = push_enum(*bit_stack, e.key_state, n);
			n = push_int(*bit_stack, <<cast(*u8)*e.gamepad_index, n, 8);
		case .SCROLL;
			n = push_float32_compressed(*bit_stack, e.xscroll, n, -5.0, 5.0, COMPRESS_BITS_PER_SCROLL_AXIS);
			n = push_float32_compressed(*bit_stack, e.yscroll, n, -5.0, 5.0, COMPRESS_BITS_PER_SCROLL_AXIS);
		case .TEXT;
			n = push_int(*bit_stack, e.utf32, n);
		case .GAMEPAD_AXIS;			
			n = push_enum(*bit_stack, e.axes_changed, n);
			n = push_float32_compressed(*bit_stack, e.left_stick.x,  n, -1.0, 1.0, COMPRESS_BITS_PER_GAMEPAD_STICK_AXIS);
			n = push_float32_compressed(*bit_stack, e.left_stick.y,  n, -1.0, 1.0, COMPRESS_BITS_PER_GAMEPAD_STICK_AXIS);
			n = push_float32_compressed(*bit_stack, e.right_stick.x, n, -1.0, 1.0, COMPRESS_BITS_PER_GAMEPAD_STICK_AXIS);
			n = push_float32_compressed(*bit_stack, e.right_stick.y, n, -1.0, 1.0, COMPRESS_BITS_PER_GAMEPAD_STICK_AXIS);
			n = push_float32_compressed(*bit_stack, e.left_trigger,  n, 0, 1.0, COMPRESS_BITS_PER_GAMEPAD_TRIGGER_AXIS);
			n = push_float32_compressed(*bit_stack, e.right_trigger, n, 0, 1.0, COMPRESS_BITS_PER_GAMEPAD_TRIGGER_AXIS);
			n = push_int(*bit_stack, <<cast(*u8)*e.gamepad_index, n, 8);
			
	}
	
	start := arena.next;
	arena_push_copy(arena, bit_stack.data, bit_stack.count);
	return start, bit_stack.count, 8-(n % 8);
	//return start;
}

decompress_input_event :: (p: *void) -> Input_Event, int {

	extract_int64 :: (p: *void, start: int, nbits: int) -> u64, int #must {
		assert(nbits <= 64);
		byte_pointer: *u8 = xx (p + start/8);
		
		result: u64;
		
		src_bit := start % 8;
		dst_bit := 0;
		
		for 0..nbits-1 {

			src_bit_value := cast(u64)(((<<byte_pointer) >> src_bit) & 1);
			result = (result) | (src_bit_value << dst_bit);
			
			src_bit += 1;
			dst_bit += 1;
			if src_bit == 8 {
				src_bit = 0;
				byte_pointer += 1;
			}
		}
		
		return result, start+nbits;
	}
	
	extract_int :: (p: *void, start: int, $Int: Type, nbits: int) -> Int, int #must {
		value64, n := extract_int64(p, start, nbits);
		return xx value64, n;
	}
	
	extract_enum ::  (p: *void, start: int, $Enum: Type) -> Enum, int #must {
		highest_value := enum_highest_value(Enum);
		kind_bits := cast(u8)ceil( log(cast(float64)highest_value + 1) / log(2.0) );
		
		v, n := extract_int64(p, start, kind_bits);
		return xx v, n;
	}
	
	extract_float32 ::  (p: *void, start: int, min: float32, max: float32, compressed_bits: int) -> float32, int #must {
	
		compressed, n := extract_int64(p, start, compressed_bits);
	
		scale := (max - min) / (pow(2.0,xx compressed_bits) - 1);
    	return clamp(cast(float32)compressed * scale + min, min, max), n;
	}

	n := 0;
	
	e: Input_Event;
	e.kind, n = extract_enum(p, n, Input_Event_Kind);
	
	if #complete e.kind == {
		case .HANDLED;
			// Event is handled, no data needed
		case .KEY;
			e.key_code, n = extract_enum(p, n, type_of(e.key_code));
			e.key_state, n = extract_enum(p, n, type_of(e.key_state));
			g: u8;
			
			g, n = extract_int(p, n, u8, 8);
			e.gamepad_index = <<cast(*s8)*g;
		case .SCROLL;
			e.xscroll, n = extract_float32(p, n, -5, 5, COMPRESS_BITS_PER_SCROLL_AXIS);
			e.yscroll, n = extract_float32(p, n, -5, 5, COMPRESS_BITS_PER_SCROLL_AXIS);
		case .TEXT;
			e.utf32, n = extract_int(p, n, u32, 32);
		case .GAMEPAD_AXIS;
			e.axes_changed,  n = extract_enum(p, n, type_of(e.axes_changed));
			e.left_stick.x,  n = extract_float32(p, n, -1.0, 1.0, COMPRESS_BITS_PER_GAMEPAD_STICK_AXIS);
			e.left_stick.y,  n = extract_float32(p, n, -1.0, 1.0, COMPRESS_BITS_PER_GAMEPAD_STICK_AXIS);
			e.right_stick.x, n = extract_float32(p, n, -1.0, 1.0, COMPRESS_BITS_PER_GAMEPAD_STICK_AXIS);
			e.right_stick.y, n = extract_float32(p, n, -1.0, 1.0, COMPRESS_BITS_PER_GAMEPAD_STICK_AXIS);
			e.left_trigger,  n = extract_float32(p, n, 0, 1.0, COMPRESS_BITS_PER_GAMEPAD_TRIGGER_AXIS);
			e.right_trigger, n = extract_float32(p, n, 0, 1.0, COMPRESS_BITS_PER_GAMEPAD_TRIGGER_AXIS);
			g: u8;
			
			g, n = extract_int(p, n, u8, 8);
			e.gamepad_index = <<cast(*s8)*g;
	}

	
	return e, (n+7)/8;
}

/*#run {

	es: [4]Input_Event;
	
	es[0].kind = .KEY;
	es[0].key_code = .ARROW_LEFT;
	es[0].key_state = .DOWN | .JUST_PRESSED | .REPEAT;
	es[0].gamepad_index = 7;
	
	es[1].kind = .SCROLL;
	es[1].xscroll = 2;
	es[1].yscroll = -3;
	
	es[2].kind = .TEXT;
	es[2].utf32 = 69;
	
	es[3].kind = .GAMEPAD_AXIS;
	es[3].axes_changed  = .LEFT_STICK | .RIGHT_STICK;
	es[3].left_stick.x  = 1;
	es[3].left_stick.y  = -0.00861;
	es[3].right_stick.x = 0.0100;
	es[3].right_stick.y = -0.7892638;
	es[3].left_trigger  = 0.2376109;
	es[3].right_trigger = 0.467123;
	es[3].gamepad_index = 3;
	
	p := talloc(kb(10));
	arena := arena_make(p, kb(10));
	
	for e: es {
		p, size, pad_bits := compress_input_event(e, *arena);
		
		ep := decompress_input_event(p);
		log("----\n%", ep.kind);
		log("Original size: %, compressed_size: %, pad bits: %", size_of(Input_Event), size, pad_bits);
		if #complete ep.kind == {
			case .HANDLED;
				// Event is handled, no data needed
			case .KEY;
				log("%: %", ep.key_code, ep.key_state);
				log("gamepad_index: %", ep.gamepad_index);
			case .SCROLL;
				log("x %, y %", ep.xscroll, ep.yscroll);
			case .TEXT;
				log("%", ep.utf32);
			case .GAMEPAD_AXIS;
				log("axes_changed: %", ep.axes_changed);
				log("left_stick.x: %", ep.left_stick.x);
				log("left_stick.y: %", ep.left_stick.y);
				log("right_stick.x: %", ep.right_stick.x);
				log("right_stick.y: %", ep.right_stick.y);
				log("left_trigger: %", ep.left_trigger);
				log("right_trigger: %", ep.right_trigger);
				log("gamepad_index: %", ep.gamepad_index);
		}
	}
	
}*/

MAX_EVENTS_PER_FRAME :: 128;
Input_Frame :: struct {
	
	mouse: Vector2;
	
	scroll_delta_x: float32;
	scroll_delta_y: float32;
	
	
	// Gamepad
	// If you need to deal with more than 1 gamepad, use INPUT_EVENT_GAMEPAD_AXIS
	left_stick:    Vector2;
	right_stick:   Vector2;
	left_trigger:  float32;
	right_trigger: float32;
	
	key_states: [#run enum_highest_value(Input_Key_Code)+1]Input_State_Flags;

	frame_index: int;
	tick_index: int;
	time_step: float64;
	
	events: [MAX_EVENTS_PER_FRAME]Input_Event;
	number_of_events: u8;
	
	is_mouse_pos_consumed: bool;
} #no_padding;

input: Input_Frame;
last_input: Input_Frame;
deadzone_left_stick: Vector2    = .{0.2, 0.2};
deadzone_right_stick: Vector2   = .{0.2, 0.2};
deadzone_left_trigger: float32  = 0.07;
deadzone_right_trigger: float32 = 0.07;



has_key_state :: (code: Input_Key_Code, flags: Input_State_Flags) -> bool {
	assert(code > 0 && code < #run enum_highest_value(Input_Key_Code)+1, "Invalid key code %d!", code);
	state := input.key_states[code];
	
#if DEBUG  {
		impossible : Input_State_Flags = (.JUST_RELEASED | .DOWN);
		assert((impossible & state) != impossible, "Key state for key '%d' is corrupt!", code);
		impossible = (.JUST_RELEASED | .JUST_PRESSED);
		assert((impossible & state) != impossible, "Key state for key '%d' is corrupt!", code);
	}
	return (state & flags) == flags;
}
is_key_down :: (code: Input_Key_Code, press_and_repeat := false) -> bool {
	if press_and_repeat return (has_key_state(code, .REPEAT)) || has_key_state(code, .JUST_PRESSED);
	return has_key_state(code, .DOWN);
}
is_key_up :: (code: Input_Key_Code) -> bool {
	return input.key_states[code] == 0 || has_key_state(code, .JUST_RELEASED);
}
is_key_just_pressed :: (code: Input_Key_Code) -> bool {
	return has_key_state(code, .JUST_PRESSED);
}
is_key_just_released :: (code: Input_Key_Code) -> bool {
	return has_key_state(code, .JUST_RELEASED);
}

consume_key_down :: (code: Input_Key_Code, press_and_repeat := false, consume_just_pressed := true) -> bool {
	result := is_key_down(code, press_and_repeat=press_and_repeat);
	input.key_states[code] &= ~(.DOWN);
	if press_and_repeat      input.key_states[code] &= ~(.REPEAT | .JUST_PRESSED);
	if consume_just_pressed  input.key_states[code] &= ~(.JUST_PRESSED);
	
	for * array_view(input.events, 0, input.number_of_events) {
		if it.kind == .KEY && it.key_code == code {
			it.key_state &= ~(.DOWN);
			if press_and_repeat      it.key_state &= ~(.REPEAT | .JUST_PRESSED);
			if consume_just_pressed  input.key_states[code] &= ~(.JUST_PRESSED);
		}
	}
	
	return result;
}
consume_key_repeat :: (code: Input_Key_Code) -> bool {
	result := has_key_state(code, .REPEAT);
	input.key_states[code] &= ~(.REPEAT);
	for * array_view(input.events, 0, input.number_of_events) {
		if it.kind == .KEY && it.key_code == code {
			it.key_state &= ~(.REPEAT);
		}
	}
	return result;
}
consume_key_just_pressed :: (code: Input_Key_Code) -> bool {
	result := is_key_just_pressed(code);
	input.key_states[code] &= ~(.JUST_PRESSED);
	for * array_view(input.events, 0, input.number_of_events) {
		if it.kind == .KEY && it.key_code == code {
			it.key_state &= ~(.JUST_PRESSED);
		}
	}
	return result;
}
consume_key_just_released :: (code: Input_Key_Code) -> bool {
	result := is_key_just_released(code);
	input.key_states[code] &= ~(.JUST_RELEASED);
	for * array_view(input.events, 0, input.number_of_events) {
		if it.kind == .KEY && it.key_code == code {
			it.key_state &= ~(.JUST_RELEASED);
		}
	}
	return result;
}

consume_key_entirely :: (code: Input_Key_Code) -> bool {
	result := is_key_down(code);
	consume_key_down(code);
	consume_key_down(code, press_and_repeat=true);
	consume_key_just_pressed(code);
	consume_key_just_released(code);
	
	for * array_view(input.events, 0, input.number_of_events) {
		if it.kind == .KEY && it.key_code == code {
			it.key_state = 0;
		}
	}
	
	return result;
}

is_input_code_gamepad :: (code: Input_Key_Code) -> bool {
	return code >= .DPAD_UP && code <= .GAMEPAD_RIGHT_TRIGGER;
}
is_input_code_mouse :: (code: Input_Key_Code) -> bool {
	return code >= .MOUSE_FIRST && code <= .MOUSE_LAST;
}
is_input_code_ui_navigation :: (code: Input_Key_Code) -> bool {
	return code == .ARROW_LEFT || code == .ARROW_RIGHT || code == .ARROW_UP || code == .ARROW_DOWN || code == .ENTER;
}


get_window_pos_projected :: (p: Vector2, projection: Matrix4, camera: Matrix4) ->Vector2 {
	ndcx := (p.x/cast(float)window.width) *2.0-1;
	ndcy := (p.y/cast(float)window.height)*2.0-1;
	
	projected := inverse(projection)*Vector4.{ndcx, ndcy, 0, 1};
	projected = camera * projected;
	
	return projected.xy;
}