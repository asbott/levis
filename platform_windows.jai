Window_Handle :: HWND;
Custom_Mouse_Pointer :: HCURSOR;


win_key_states: [#run enum_highest_value(Input_Key_Code)+1]Input_State_Flags;
win_key_down_timestamps: [#run enum_highest_value(Input_Key_Code)+1]float32;

win_send_key_event :: (code: Input_Key_Code, state: Input_State_Flags, gamepad_index: int) {
	e: Input_Event;
	e.kind = .KEY;
	e.key_code = code;
	e.key_state = state;
	e.gamepad_index = xx,no_check gamepad_index;
	input.events[input.number_of_events] = e;
	input.number_of_events += 1;
}

win_handle_key_up :: (code: Input_Key_Code, gamepad_index: s64) {
	if (code == .UNKNOWN) return;
	last_state: Input_State_Flags = win_key_states[code];
	state: Input_State_Flags = 0;
	if (last_state & .DOWN)  state |= .JUST_RELEASED;
	
	win_key_states[code] = state;
	
	win_send_key_event(code, state, gamepad_index);
}
win_handle_key_down :: (code: Input_Key_Code, gamepad_index: s64) {
	if (code == .UNKNOWN) return;
	
	last_state: Input_State_Flags = win_key_states[code];
	state: Input_State_Flags = .DOWN;
	
	if (!(last_state & .DOWN))  state |= .JUST_PRESSED;
	
	win_key_states[code] = state;
	if (!(last_state & .DOWN)) win_key_down_timestamps[code] = xx seconds_since_init();
	
	win_send_key_event(code, state, gamepad_index);
}

window_proc :: (event_window: HWND, message: u32, wparam: WPARAM, lparam: LPARAM) -> LRESULT #c_call {
    
    do_default_thing := true;
    
    c: Context;
    push_context(c) {
	    if message == {
	    	case WM_CREATE;
	            
	            
	    	case WM_CLOSE; 
	    		window.should_close = true;
            	DestroyWindow(window.handle);
	    		PostQuitMessage(0);
	    		
	    	case WM_DESTROY;
	            PostQuitMessage(0);
			case WM_SYSKEYDOWN; #through;
	        case WM_KEYDOWN;
	        	is_repeat := (lparam & 0x40000000) != 0;
		        if (!is_repeat) win_handle_key_down(win_key_to_input_key(xx wparam), -1);
	        case WM_SYSKEYUP; #through;
		    case WM_KEYUP;
		        win_handle_key_up(win_key_to_input_key(xx wparam), -1);
		    case WM_LBUTTONDOWN;
		        win_handle_key_down(.MOUSE_BUTTON_LEFT, -1);
		    case WM_RBUTTONDOWN;
		        win_handle_key_down(.MOUSE_BUTTON_RIGHT, -1);
		    case WM_MBUTTONDOWN;
		        win_handle_key_down(.MOUSE_BUTTON_MIDDLE, -1);
		    case WM_LBUTTONUP;
		        win_handle_key_up(.MOUSE_BUTTON_LEFT, -1);
		    case WM_RBUTTONUP;
		        win_handle_key_up(.MOUSE_BUTTON_RIGHT, -1);
		    case WM_MBUTTONUP;
				win_handle_key_up(.MOUSE_BUTTON_MIDDLE, -1);
		    case WM_MOUSEWHEEL; {
		        delta: s16 = xx,no_check(wparam >> 16) & 0xFFFF;
		        e: Input_Event;
		        e.kind = .SCROLL;
		        e.yscroll = cast(float32)delta/cast(float32)120;
		        input.scroll_delta_y += xx e.yscroll;
		        e.xscroll = 0;
		        input.events[input.number_of_events] = e;
				input.number_of_events += 1;
		    }
		    case WM_MOUSEHWHEEL; {
		        delta: s16 = xx,no_check(wparam >> 16) & 0xFFFF;
		        e: Input_Event;
		        e.kind = .SCROLL;
		        e.yscroll = 0;
		        e.xscroll = cast(float32)delta/cast(float32)120;
		        input.scroll_delta_x += xx e.xscroll;
		        input.events[input.number_of_events] = e;
				input.number_of_events += 1;
		    }
		    case WM_CHAR; {
		        utf16 : [2]u16 = .[cast(u16)wparam, 0];
		    	if utf16[0] >= 32 {
			        utf8 := wide_to_utf8_new(utf16.data,,temp);
			        
			        e: Input_Event;
			        e.kind = .TEXT;
			        e.utf32 = character_utf8_to_utf32(utf8.data, 1);
			        
			        input.events[input.number_of_events] = e;
					input.number_of_events += 1;
		    	}
		    }	            
            case WM_SETCURSOR;
	    
            hit_test      := lparam & 0xFFFF;
            
            if (hit_test == HTLEFT || hit_test == HTRIGHT || hit_test == HTTOP ||
                hit_test == HTBOTTOM || hit_test == HTTOPLEFT || hit_test == HTTOPRIGHT ||
                hit_test == HTBOTTOMLEFT || hit_test == HTBOTTOMRIGHT) {
                
                // We are hovering the borders, let windows decide the pointer
                win.want_override_mouse_pointer = true;
            } else {
                do_default_thing = false;
                if (win.want_override_mouse_pointer) {
                    win.want_override_mouse_pointer = false;
                    if (win.did_override_user_mouse_pointer) {
                        win.did_override_user_mouse_pointer = false;
                        SetCursor(win.shadowed_mouse_pointer);
                    } else {
                    	do_default_thing = true;
                    }
                }
            }
	    		
	    	case WM_DISPLAYCHANGE;
		    	win_query_monitors();
		    case WM_GETMINMAXINFO; {
		    	/*if (window.handle != null) {
		    		do_default_thing = false;
			    	mmi := cast(*MINMAXINFO)lparam;
		            
		            mmi.ptMaxSize.x      = xx  window.monitor.resolution_x;
		            mmi.ptMaxSize.y      = xx  window.monitor.resolution_y;
		            mmi.ptMaxTrackSize.x = xx  window.monitor.resolution_x;
		            mmi.ptMaxTrackSize.y = xx  window.monitor.resolution_y;
		            mmi.ptMinTrackSize.x = xx -window.monitor.resolution_x;
		            mmi.ptMinTrackSize.y = xx -window.monitor.resolution_y;
		    	}*/
		    }
	    }
		
		if do_default_thing  return DefWindowProcW(event_window, message, wparam, lparam);
		else return 0;
    }
    
}



platform_update :: () {

	if window.should_close  return;

	// When in fullscreen, undo whatever the game says about x, y, w, h
	if (window.fullscreen && win.last_window.fullscreen) {
		window.width  = window.monitor.resolution_x;
		window.height = window.monitor.resolution_y;
		window.x = 0;
		window.y = 0;
	}
	
	ok: BOOL;
	style    := cast(DWORD)GetWindowLongW(window.handle, GWL_STYLE);
	style_ex := cast(DWORD)GetWindowLongW(window.handle, GWL_EXSTYLE);
	screen_height := window.monitor.resolution_y;
	
	///
	// Listen to window x, y, w, h changes from game
	if win.last_window.x      != window.x 
	|| win.last_window.y      != window.y 
	|| win.last_window.width  != window.width 
	|| win.last_window.height != window.height {
	
	    update_rect: RECT;
	    update_rect.left   = xx,no_check (window.x);
	    update_rect.right  = xx,no_check (window.x + window.width);
	    update_rect.top    = xx,no_check (screen_height - (window.y+window.height));
	    update_rect.bottom = xx,no_check (screen_height - window.y);
	
	    AdjustWindowRectEx(*update_rect, xx,no_check style, 0, xx,no_check style_ex);
	
	    actual_width  := update_rect.right - update_rect.left;
	    actual_height := update_rect.bottom - update_rect.top;
	    actual_x      := update_rect.left;
	    actual_y      := update_rect.top;
	    
	    SetWindowPos(window.handle, null, actual_x, actual_y, actual_width, actual_height, SWP_NOACTIVATE);
	}
	
	///
	// Report the current state of the window
	client_rect: RECT;
	ok = xx GetClientRect(window.handle, *client_rect);
	assert(ok != 0, "GetClientRect failed with error code %lu", GetLastError());
	
	adjusted_rect: RECT = client_rect;
	ok = xx AdjustWindowRectEx(*adjusted_rect, xx,no_check style, 0, xx,no_check style_ex);
    assert(ok != 0, "AdjustWindowRectEx failed with error code %lu", GetLastError());
    
    window_rect: RECT;
	ok = xx GetWindowRect(window.handle, *window_rect);
	assert(ok != 0, "GetWindowRect failed with error code %lu", GetLastError());

	window_rect.left   -= xx,no_check(adjusted_rect.left);
	window_rect.right  -= xx,no_check(adjusted_rect.right-client_rect.right);
	window_rect.top    -= xx,no_check(adjusted_rect.top);
	window_rect.bottom -= xx,no_check(adjusted_rect.bottom-client_rect.bottom);
	
	top_left: POINT;
	top_left.x = xx,no_check client_rect.left;
	top_left.y = xx,no_check client_rect.top;
	ok = xx,no_check ClientToScreen(window.handle, *top_left);
	assert(ok != 0, "ClientToScreen failed with error code %lu", GetLastError());
	
	bottom_right: POINT;
	bottom_right.x = xx,no_check client_rect.right;
	bottom_right.y = xx,no_check client_rect.bottom;
	ok = xx,no_check ClientToScreen(window.handle, *bottom_right);
	assert(ok != 0, "ClientToScreen failed with error code %lu", GetLastError());
	
	window.width = (bottom_right.x - top_left.x);
	window.height = (bottom_right.y - top_left.y);
	window.x = window_rect.left;
	window.y = screen_height-window_rect.bottom;
    
    last_fullscreen := win.last_window.fullscreen;
    win.last_window = window;
    
    ///
    // Handle fullscreen change
    if (last_fullscreen != window.fullscreen) {
		
		if (window.fullscreen) {
		
			// Save windowed state
			win.windowed_style    = style;
		    win.windowed_style_ex = style_ex;
		    win.windowed_x        = window.x;
		    win.windowed_y        = window.y;
		    win.windowed_width    = window.width;
		    win.windowed_height   = window.height;
		    
		    SetWindowLongW(window.handle, GWL_STYLE, xx,no_check (style & ~(WS_CAPTION | WS_THICKFRAME)));
			SetWindowLongW(window.handle, GWL_EXSTYLE, 
				xx,no_check (style_ex & ~(WS_EX_DLGMODALFRAME | WS_EX_WINDOWEDGE | WS_EX_CLIENTEDGE | WS_EX_STATICEDGE))
			);
		    
		} else {
			
			// Restore windowed_state
			style         = win.windowed_style;
			style_ex      = win.windowed_style_ex;
			window.x      = win.windowed_x;
			window.y      = win.windowed_y;
			window.width  = win.windowed_width;
			window.height = win.windowed_height;
			
			SetWindowLongW(window.handle, GWL_STYLE,   xx,no_check win.windowed_style);
			SetWindowLongW(window.handle, GWL_EXSTYLE, xx,no_check win.windowed_style_ex);
		}
	}
    
    if window.front_buffer.count != window.width*window.height*4 {
    	window.front_buffer.data = alloc(window.width*window.height*4*2 + 64);
    	window.front_buffer.count = window.width*window.height*4;
    	window.back_buffer.data = window.front_buffer.data + window.width*window.height*4;
    	window.back_buffer.count = window.width*window.height*4;
    	
    	// For simd
    	front_buffer_aligned := align_next(window.front_buffer.data, 32);
    	back_buffer_aligned  := align_next(window.front_buffer.data, 32);
    	window.front_buffer.count -= front_buffer_aligned-window.front_buffer.data;
    	window.back_buffer.count -= back_buffer_aligned-window.back_buffer.data;
    	window.front_buffer.data = front_buffer_aligned;
    	window.back_buffer.data = back_buffer_aligned;
    	
    	log("hh");
	}
	
	hdc := GetDC(window.handle);

    // Set up BITMAPINFO structure
    bmi: BITMAPINFO;
    bmi.bmiHeader.biSize = size_of(BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth = xx window.width;
    bmi.bmiHeader.biHeight = xx window.height;
    bmi.bmiHeader.biPlanes = 1;
    bmi.bmiHeader.biBitCount = 32;
    bmi.bmiHeader.biCompression = BI_RGB;

	{
		scope_lock(*window.swap_mutex);
		Swap(*window.back_buffer.data, *window.front_buffer.data);
	}



	now := seconds_since_init();
	passed := now - win.last_blt_time;
	target := 1.0/cast(float64)window.monitor.refresh_rate;
	if passed < target {
		platform_high_precision_sleep((target-passed)*1000.0);
	} else {
		log("Missed frame target %ms by %ms (%ms)", target*1000.0, (passed-target)*1000.0, (passed)*1000.0);
	}
	win.last_blt_time = seconds_since_init();
    SetDIBitsToDevice(
        hdc,
        0, 0, xx window.width, xx window.height,
        0, 0,
        0, xx window.height,
        window.front_buffer.data,
        *bmi,
        DIB_RGB_COLORS);

    ReleaseDC(window.handle, hdc);
}

platform_poll_events :: () {
	
	last_input = input;
	
	input = .{};

	input.number_of_events = 0;
	
	// A windows api that just does what you want it to.
	// This can't be right...
	
	win_lazy_init_xinput();
	if (win.xinput != null) {
		if (!XInputGetState) XInputGetState = cast((DWORD, *XINPUT_STATE)->DWORD #c_call)GetProcAddress(win.xinput, "XInputGetState");
		assert(XInputGetState != null, "xinput dll corrupt");
		
		any_gamepad_processed := false;
		
		// Poll gamepad
		for i: 0 .. XUSER_MAX_COUNT-1 {
		    state: XINPUT_STATE;
		
		    r := XInputGetState(xx i, *state);
		    if(r == 0) {
		    	if (state.Gamepad.wButtons & XINPUT_GAMEPAD_DPAD_UP) { if !(win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_DPAD_UP) win_handle_key_down(.DPAD_UP, i); }
		    	else if (win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_DPAD_UP) win_handle_key_up(.DPAD_UP, i);
		    	if (state.Gamepad.wButtons & XINPUT_GAMEPAD_DPAD_RIGHT) { if !(win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_DPAD_RIGHT) win_handle_key_down(.DPAD_RIGHT, i); }
		    	else if (win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_DPAD_RIGHT) win_handle_key_up(.DPAD_RIGHT, i);
		    	if (state.Gamepad.wButtons & XINPUT_GAMEPAD_DPAD_DOWN) { if !(win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_DPAD_DOWN) win_handle_key_down(.DPAD_DOWN, i); }
		    	else if (win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_DPAD_DOWN) win_handle_key_up(.DPAD_DOWN, i);
		    	if (state.Gamepad.wButtons & XINPUT_GAMEPAD_DPAD_LEFT) { if !(win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_DPAD_LEFT) win_handle_key_down(.DPAD_LEFT, i); }
		    	else if (win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_DPAD_LEFT) win_handle_key_up(.DPAD_LEFT, i);
		    	if (state.Gamepad.wButtons & XINPUT_GAMEPAD_START) { if !(win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_START) win_handle_key_down(.GAMEPAD_START, i); }
		    	else if (win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_START) win_handle_key_up(.GAMEPAD_START, i);
		    	if (state.Gamepad.wButtons & XINPUT_GAMEPAD_BACK) { if !(win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_BACK) win_handle_key_down(.GAMEPAD_BACK, i); }
		    	else if (win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_BACK) win_handle_key_up(.GAMEPAD_BACK, i);
		    	if (state.Gamepad.wButtons & XINPUT_GAMEPAD_LEFT_THUMB) { if !(win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_LEFT_THUMB) win_handle_key_down(.GAMEPAD_LEFT_STICK, i); }
		    	else if (win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_LEFT_THUMB) win_handle_key_up(.GAMEPAD_LEFT_STICK, i);
		    	if (state.Gamepad.wButtons & XINPUT_GAMEPAD_RIGHT_THUMB) { if !(win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_RIGHT_THUMB) win_handle_key_down(.GAMEPAD_RIGHT_STICK, i); }
		    	else if (win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_RIGHT_THUMB) win_handle_key_up(.GAMEPAD_RIGHT_STICK, i);
		    	if (state.Gamepad.wButtons & XINPUT_GAMEPAD_LEFT_SHOULDER) { if !(win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_LEFT_SHOULDER) win_handle_key_down(.GAMEPAD_LEFT_BUMPER, i); }
		    	else if (win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_LEFT_SHOULDER) win_handle_key_up(.GAMEPAD_LEFT_BUMPER, i);
		    	if (state.Gamepad.wButtons & XINPUT_GAMEPAD_RIGHT_SHOULDER) { if !(win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_RIGHT_SHOULDER) win_handle_key_down(.GAMEPAD_RIGHT_BUMPER, i); }
		    	else if (win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_RIGHT_SHOULDER) win_handle_key_up(.GAMEPAD_RIGHT_BUMPER, i);
		    	if (state.Gamepad.wButtons & XINPUT_GAMEPAD_A) { if !(win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_A) win_handle_key_down(.GAMEPAD_A, i); }
		    	else if (win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_A) win_handle_key_up(.GAMEPAD_A, i);
		    	if (state.Gamepad.wButtons & XINPUT_GAMEPAD_B) { if !(win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_B) win_handle_key_down(.GAMEPAD_B, i); }
		    	else if (win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_B) win_handle_key_up(.GAMEPAD_B, i);
		    	if (state.Gamepad.wButtons & XINPUT_GAMEPAD_X) { if !(win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_X) win_handle_key_down(.GAMEPAD_X, i); }
		    	else if (win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_X) win_handle_key_up(.GAMEPAD_X, i);
		    	if (state.Gamepad.wButtons & XINPUT_GAMEPAD_Y) { if !(win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_Y) win_handle_key_down(.GAMEPAD_Y, i); }
		    	else if (win.last_xinput_states[i].Gamepad.wButtons & XINPUT_GAMEPAD_Y) win_handle_key_up(.GAMEPAD_Y, i);
		    	
		    	left_stick_x  := state.Gamepad.sThumbLX;
		    	left_stick_y  := state.Gamepad.sThumbLY;
		    	right_stick_x := state.Gamepad.sThumbRX;
		    	right_stick_y := state.Gamepad.sThumbRY;
		    	
		    	if (!any_gamepad_processed) {
		    		input.left_stick = Vector2.{
			    		cast(float32)left_stick_x / (ifx left_stick_x >= 0 then 32767.0 else 32768.0),
			    		cast(float32)left_stick_y / (ifx left_stick_y >= 0 then 32767.0 else 32768.0),
		    		};
		    		input.right_stick = Vector2.{
			    		cast(float32)right_stick_x / (ifx right_stick_x >= 0 then 32767.0 else 32768.0),
			    		cast(float32)right_stick_y / (ifx right_stick_y >= 0 then 32767.0 else 32768.0),
		    		};
		    		input.left_trigger  = cast(float32)state.Gamepad.bLeftTrigger / 255.0;
		    		input.right_trigger = cast(float32)state.Gamepad.bRightTrigger / 255.0;
		    		
		    	}
		    	
		    	if (state.Gamepad.bLeftTrigger >= 230) win_handle_key_down(.GAMEPAD_LEFT_TRIGGER, i);
		    	else if (win.last_xinput_states[i].Gamepad.bLeftTrigger >= 230) win_handle_key_up(.GAMEPAD_LEFT_TRIGGER, i);
		    	if (state.Gamepad.bRightTrigger >= 230) win_handle_key_down(.GAMEPAD_RIGHT_TRIGGER, i);
		    	else if (win.last_xinput_states[i].Gamepad.bRightTrigger >= 230) win_handle_key_up(.GAMEPAD_RIGHT_TRIGGER, i);
		    	
		    	if (abs(input.left_stick.x)  < deadzone_left_stick.x)  input.left_stick.x  = 0.0;
		    	if (abs(input.left_stick.y)  < deadzone_left_stick.y)  input.left_stick.y  = 0.0;
		    	if (abs(input.right_stick.x) < deadzone_right_stick.x) input.right_stick.x = 0.0;
		    	if (abs(input.right_stick.y) < deadzone_right_stick.y) input.right_stick.y = 0.0;
		    	if (abs(input.left_trigger)  < deadzone_left_trigger)  input.left_trigger  = 0.0;
		    	if (abs(input.right_trigger) < deadzone_right_trigger) input.right_trigger = 0.0;
		    	
		    	// Update state to account for deadzone
		    	state.Gamepad.sThumbLX = xx (input.left_stick.x*32768.0-1);
		    	state.Gamepad.sThumbLY = xx (input.left_stick.y*32768.0-1);
		    	state.Gamepad.sThumbRX = xx (input.right_stick.x*32768.0-1);
		    	state.Gamepad.sThumbRY = xx (input.right_stick.y*32768.0-1);
		    	state.Gamepad.bLeftTrigger  = xx (input.left_trigger*255);
		    	state.Gamepad.bRightTrigger = xx (input.right_trigger*255);
		    	left_stick_x  = xx state.Gamepad.sThumbLX;
		    	left_stick_y  = xx state.Gamepad.sThumbLY;
		    	right_stick_x = xx state.Gamepad.sThumbRX;
		    	right_stick_y = xx state.Gamepad.sThumbRY;
		    	
		    	e: Input_Event;
		    	e.kind = .GAMEPAD_AXIS;
				e.gamepad_index = xx,no_check i;
		    	
		    	if (left_stick_x != win.last_xinput_states[i].Gamepad.sThumbLX || left_stick_y != win.last_xinput_states[i].Gamepad.sThumbLY) {
		    		e.axes_changed |= .LEFT_STICK;
		    		e.left_stick = input.left_stick;
		    	}
		    	if (right_stick_x != win.last_xinput_states[i].Gamepad.sThumbRX || right_stick_y != win.last_xinput_states[i].Gamepad.sThumbRY) {
		    		e.axes_changed |= .RIGHT_STICK;
		    		e.right_stick = input.right_stick;
		    	}
		    	if (state.Gamepad.bLeftTrigger != win.last_xinput_states[i].Gamepad.bLeftTrigger) {
		    		e.axes_changed |= .LEFT_TRIGGER;
		    		e.left_trigger = input.left_trigger;
		    	}
		    	if (state.Gamepad.bRightTrigger != win.last_xinput_states[i].Gamepad.bRightTrigger) {
		    		e.axes_changed |= .RIGHT_TRIGGER;
		    		e.right_trigger = input.right_trigger;
		    	}
		    	
		    	if (e.axes_changed != 0) {
					input.events[input.number_of_events] = e;
					input.number_of_events += 1;
		    	}
		    	
		    	win.last_xinput_states[i] = state;
		    	any_gamepad_processed = true;
		    }
		}
	}
	
	if GetFocus() != window.handle {
		// Reset states when window loses focus
		for * state, key: win_key_states {
			if << state & .DOWN {
				<< state = 0;
			}
		}
	} else {
		for i: 1..#run enum_highest_value(Input_Key_Code) {
			win_key_states[i] &= ~(.REPEAT);
			win_key_states[i] &= ~(.JUST_PRESSED);
			win_key_states[i] &= ~(.JUST_RELEASED);
			
			delay_seconds := cast(float32)platform.keyboard_delay_seconds;
			time_since_down := seconds_since_init() - win_key_down_timestamps[i];
			if (win_key_states[i] & .DOWN) {
				if time_since_down >= delay_seconds
					win_key_states[i] |= (.REPEAT);
				win_send_key_event(xx i, win_key_states[i], -1);
			}
		}
	}

	if window.should_close  return;
	msg: MSG;
	while PeekMessageW(*msg, null, 0, 0, PM_REMOVE) {
        TranslateMessage(*msg);
        DispatchMessageW(*msg);
    }
    
    memcpy(input.key_states.data, win_key_states.data, size_of(type_of(input.key_states)));
	p: POINT;
	GetCursorPos(*p);
	ScreenToClient(window.handle, *p);
	p.y = xx (window.height - p.y);
	input.mouse.x = xx p.x;
	input.mouse.y = xx p.y;
	
	if (window.should_close) {
		window_proc(window.handle, WM_CLOSE, 0, 0);
	}
}

win_lazy_init_xinput :: () {
	if (!win.xinput) {
		win.xinput = LoadLibraryW(utf8_to_wide_new("xinput1_4.dll",,temp));
		if (!win.xinput) win.xinput = LoadLibraryW(utf8_to_wide_new("xinput1_3.dll",,temp));
		if (!win.xinput) win.xinput = LoadLibraryW(utf8_to_wide_new("xinput9_1_0.dll",,temp));
		if (!win.xinput) {
			log_warning("xinput is missing, gamepads not supported.");
		}
	}
}

set_gamepad_vibration :: (left: float32, right: float32) {
	win_lazy_init_xinput();
	
	if (!XInputGetState) XInputGetState = cast(#type(DWORD, *XINPUT_STATE)->DWORD#c_call)GetProcAddress(win.xinput, "XInputGetState");
	assert(XInputGetState != null, "xinput dll corrupt");
	
	for i: 0..XUSER_MAX_COUNT-1 {
	    state: XINPUT_STATE;
	    // #Lag #Speed
	    r := XInputGetState(xx i, *state);
	
	    if (r == 0) {
	    	set_gamepad_vibration(xx i, left, right);
	    }
    }
}
set_gamepad_vibration :: (gamepad_index: u64, left: float32, right: float32) {
	win_lazy_init_xinput();
	if (!XInputSetState) XInputSetState = cast(#type(DWORD, *XINPUT_VIBRATION)->DWORD#c_call)GetProcAddress(win.xinput, "XInputSetState");
	assert(XInputSetState != null, "xinput dll corrupt");
	
	vibration: XINPUT_VIBRATION;
	vibration.wLeftMotorSpeed  = xx (65535.0*clamp(left, 0, 1));
	vibration.wRightMotorSpeed = xx (65535.0*clamp(right, 0, 1));
	r := XInputSetState(xx gamepad_index, *vibration);
	if (r != 0) { log_warning("Could not set gamepad vibration on gamepad %d", gamepad_index); }
}

mouse_pointer_kind_to_win :: (k: Mouse_Pointer_Kind) -> LPCSTR {
    if #complete k == {
        case .DEFAULT;           return IDC_ARROW;
        case .TEXT_SELECT;       return IDC_IBEAM;
        case .BUSY;              return IDC_WAIT;
        case .BUSY_BACKGROUND;   return IDC_APPSTARTING;
        case .CROSS;             return IDC_CROSS;
        case .ARROW_N;           return IDC_UPARROW;
        case .ARROWS_NW_SE;      return IDC_SIZENWSE;
        case .ARROWS_NE_SW;      return IDC_SIZENESW;
        case .ARROWS_HORIZONTAL; return IDC_SIZEWE;
        case .ARROWS_VERTICAL;   return IDC_SIZENS;
        case .ARROWS_ALL;        return IDC_SIZEALL;
        case .NO;                return IDC_NO;
        case .POINT;             return IDC_HAND;
    }
    panic("Unhandled Mouse_Pointer_Kind");
}

platform_set_mouse_pointer :: (kind: Mouse_Pointer_Kind) {
    
    if (win.loaded_pointers[kind] == null) {
        win.loaded_pointers[kind] = LoadCursorA(null, mouse_pointer_kind_to_win(kind));
    }
    
    if (win.want_override_mouse_pointer) {
        win.shadowed_mouse_pointer = win.loaded_pointers[kind];
        win.did_override_user_mouse_pointer = true;
    } else {
        SetCursor(win.loaded_pointers[kind]);
    }
}
platform_set_mouse_pointer :: (p: Custom_Mouse_Pointer) {
    if (win.want_override_mouse_pointer) {
        win.shadowed_mouse_pointer = cast(HCURSOR)p;
        win.did_override_user_mouse_pointer = true;
    } else {
        SetCursor(cast(HCURSOR)p);
    }
}

// Expects 32-bit rgba
platform_make_mouse_pointer :: (image: *u8, width: int, height: int, hotspot_x: int, hotspot_y: int) -> Custom_Mouse_Pointer {
    icon: HICON;
    bitmap: HBITMAP;
    icon_info: ICONINFO;
    
    bmi: BITMAPINFO;
    bmi.bmiHeader.biSize        = size_of(BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth       = xx,no_check width;
    bmi.bmiHeader.biHeight      = xx,no_check height;
    bmi.bmiHeader.biPlanes      = 1;
    bmi.bmiHeader.biBitCount    = 32;
    bmi.bmiHeader.biCompression = BI_RGB;
    
    bits: *u8;
    hdc := GetDC(null);
    bitmap = CreateDIBSection(hdc, *bmi, DIB_RGB_COLORS, xx *bits, null, 0);
    ReleaseDC(null, hdc);
    if (!bitmap) {
        panic("Failed to create DIB section");
        return null;
    }

    memcpy(bits, image, width * height * 4);

    icon_info.fIcon    = 0; // Cursor, not icon
    icon_info.xHotspot = xx,no_check (hotspot_x);
    icon_info.yHotspot = xx,no_check (height-hotspot_y);
    icon_info.hbmMask  = bitmap;
    icon_info.hbmColor = bitmap;

    icon = CreateIconIndirect(*icon_info);
    if (!icon) {
        assert(false, "Failed to create icon from bitmap");
        DeleteObject(bitmap);
        return null;
    }

    DeleteObject(bitmap);
    
    return icon;
}

platform_make_mouse_pointer_from_file :: (path: string, hotspot_x: int, hotspot_y: int) -> Custom_Mouse_Pointer {
    width, height, channels: int;
    
    png, ok := read_entire_file(path);
    defer if ok free(png);
    
    if (!ok) return null;
    
    stbi_set_flip_vertically_on_load(1);
    stb_data := stbi_load_from_memory(
        png.data, 
        xx,no_check png.count,
        xx *width, 
        xx *height, 
        xx *channels, 
        xx,no_check STBI.rgb_alpha
    );
    defer if stb_data  stbi_image_free(stb_data);
    
    if (!stb_data) {
        return null;
    }
    
    p := platform_make_mouse_pointer(stb_data, width, height, hotspot_x, hotspot_y);
    
    
    return p;    
}

win_key_to_input_key :: (key: u32) -> Input_Key_Code {

	if (key >= #char "A" && key <= #char "Z") {
        return cast(Input_Key_Code)key;
    }
    if (key >= #char "0" && key <= #char "9") {
        return cast(Input_Key_Code)key;
    }

    if key ==  {
        case VK_BACK;         return .BACKSPACE;
        case VK_TAB;          return .TAB;
        case VK_RETURN;       return .ENTER;
        case VK_ESCAPE;       return .ESCAPE;
        case VK_SPACE;        return .SPACEBAR;
        case VK_DELETE;       return .DELETE;
        case VK_UP;           return .ARROW_UP;
        case VK_DOWN;         return .ARROW_DOWN;
        case VK_LEFT;         return .ARROW_LEFT;
        case VK_RIGHT;        return .ARROW_RIGHT;
        case VK_PRIOR;        return .PAGE_UP;
        case VK_NEXT;         return .PAGE_DOWN;
        case VK_HOME;         return .HOME;
        case VK_END;          return .END;
        case VK_INSERT;       return .INSERT;
        case VK_PAUSE;        return .PAUSE;
        case VK_SCROLL;       return .SCROLL_LOCK;
        case VK_MENU;         return .ALT;
        case VK_CONTROL;      return .CTRL;
        case VK_SHIFT;        return .SHIFT;
        case VK_LWIN;         return .CMD;
        case VK_RWIN;         return .CMD;
        case VK_F1;           return .F1;
        case VK_F2;           return .F2;
        case VK_F3;           return .F3;
        case VK_F4;           return .F4;
        case VK_F5;           return .F5;
        case VK_F6;           return .F6;
        case VK_F7;           return .F7;
        case VK_F8;           return .F8;
        case VK_F9;           return .F9;
        case VK_F10;          return .F10;
        case VK_F11;          return .F11;
        case VK_F12;          return .F12;
        case VK_SNAPSHOT;     return .PRINT_SCREEN;
        case VK_LBUTTON;      return .MOUSE_BUTTON_LEFT;
        case VK_MBUTTON;      return .MOUSE_BUTTON_MIDDLE;
        case VK_RBUTTON;      return .MOUSE_BUTTON_RIGHT;
        case;                 return .UNKNOWN;
    }
}

input_key_to_win_key :: (key: Input_Key_Code) -> u32 {

    if (key >= #char "A" && key <= #char "Z") {
        return cast(u32)key;
    }
    if (key >= #char "0" && key <= #char "9") {
        return cast(u32)key;
    }

    if key == {
        case .BACKSPACE;          return VK_BACK;
        case .TAB;                return VK_TAB;
        case .ENTER;              return VK_RETURN;
        case .ESCAPE;             return VK_ESCAPE;
        case .SPACEBAR;           return VK_SPACE;
        case .DELETE;             return VK_DELETE;
        case .ARROW_UP;           return VK_UP;
        case .ARROW_DOWN;         return VK_DOWN;
        case .ARROW_LEFT;         return VK_LEFT;
        case .ARROW_RIGHT;        return VK_RIGHT;
        case .PAGE_UP;            return VK_PRIOR;
        case .PAGE_DOWN;          return VK_NEXT;
        case .HOME;               return VK_HOME;
        case .END;                return VK_END;
        case .INSERT;             return VK_INSERT;
        case .PAUSE;              return VK_PAUSE;
        case .SCROLL_LOCK;        return VK_SCROLL;
        case .ALT;                return VK_MENU;
        case .CTRL;               return VK_CONTROL;
        case .SHIFT;              return VK_SHIFT;
        case .CMD;                return VK_LWIN; // Alternatively, VK_RWIN
        case .F1;                 return VK_F1;
        case .F2;                 return VK_F2;
        case .F3;                 return VK_F3;
        case .F4;                 return VK_F4;
        case .F5;                 return VK_F5;
        case .F6;                 return VK_F6;
        case .F7;                 return VK_F7;
        case .F8;                 return VK_F8;
        case .F9;                 return VK_F9;
        case .F10;                return VK_F10;
        case .F11;                return VK_F11;
        case .F12;                return VK_F12;
        case .PRINT_SCREEN;       return VK_SNAPSHOT;
        case .MOUSE_BUTTON_LEFT;  return VK_LBUTTON;
        case .MOUSE_BUTTON_MIDDLE;return VK_MBUTTON;
        case .MOUSE_BUTTON_RIGHT; return VK_RBUTTON;
        case;                     return 0; // Or another default value for unknown keys
    }
}

platform_init :: () {

	cpu_info = get_cpu_info();

	ok: int;

	GetSystemInfo(*win.system_info);
	platform.granularity = win.system_info.dwAllocationGranularity;
	platform.page_size   = win.system_info.dwPageSize;
	platform.number_of_logical_processors = xx win.system_info.dwNumberOfProcessors;
	win32_really_is_goofy: int;
	SystemParametersInfoW(0x0016, 0, *win32_really_is_goofy, 0);
	platform.keyboard_delay_seconds = xx win32_really_is_goofy * 0.25;
	
	context.chungus_arena = platform_get_arena(gb(69), 0, xx align_next(gb(69000), platform.granularity), name="chungus");

	///
	// Window init
	window.width = 1280;
	window.height = 720;
	window.should_close = false;
	init(*window.swap_mutex);

	timeBeginPeriod(1);
	SetPriorityClass(GetCurrentProcess(), 0x00000080 /*REALTIME_PRIORITY_CLASS*/);
	SetThreadPriority(GetCurrentThread(), 15 /*THREAD_PRIORITY_TIME_CRITICAL*/);
	
	task_index: u32;
	AvSetMmThreadCharacteristicsA("Games", *task_index);

    instance := GetModuleHandleW(null);
    
    assert(instance != INVALID_HANDLE_VALUE, "Failed getting current HINSTANCE");

	wc: WNDCLASSEXW;
    wc.cbSize = size_of(WNDCLASSEXW);
    wc.style = CS_OWNDC;
    wc.lpfnWndProc = xx window_proc;
    wc.hInstance = instance;
    wc.lpszClassName = utf8_to_wide_new("sigma balls",,temp);
    wc.hIcon = LoadIconW(null, cast(*u16)32512);
    wc.hCursor = LoadCursorW(null, IDC_ARROW);
    wc.hIconSm = LoadIconW(null, cast(*u16)32512);

	ok = RegisterClassExW(*wc);
	assert(ok != 0, "Failed registering window class (error code %)", GetLastError());
	
	rect := RECT.{0, 0, xx,no_check window.width, xx,no_check window.height};
	
	style    : s32 = WS_OVERLAPPEDWINDOW;
	style_ex : s32 = WS_EX_CLIENTEDGE;
	
	ok = xx AdjustWindowRectEx(*rect, xx style, 0, xx style_ex);
	assert(ok != 0, "AdjustWindowRectEx failed with error code %", GetLastError());
	
    // Create the window
    window.handle = CreateWindowExW(
        style_ex,
        utf8_to_wide_new("sigma balls",,temp),
        utf8_to_wide_new("gem",,temp),
        xx style,
        CW_USEDEFAULT, CW_USEDEFAULT, xx window.width, xx window.height,
        null, null, instance, null
    );
    assert(window.handle != null, "Window creation failed, error: %", GetLastError());
    
    window.front_buffer.data = alloc(window.width*window.height*4*2);
	window.front_buffer.count = window.width*window.height*4;
	window.back_buffer.data = window.front_buffer.data + window.width*window.height*4;
	window.back_buffer.count = window.width*window.height*4;
    
    UpdateWindow(window.handle);
    ShowWindow(window.handle, SW_SHOW);
    
	ok = xx SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
	if (!ok) {
		hr := SetProcessDpiAwareness(xx,no_check PROCESS_PER_MONITOR_DPI_AWARE);
		win_check_hr(hr);
	}
    
    
    platform_set_mouse_pointer(.DEFAULT);

    win_query_monitors();
    
    window.x = window.monitor.resolution_x/2 - window.width/2;
    window.y = window.monitor.resolution_y - window.height-100;
    
    log("Windows platform initialized");
    
    // Windows starts with the loading pointer
    
    log_verbose("Primary_monitor: %", << platform.primary_monitor);
}

win_query_monitors_callback :: (monitor_handle: HMONITOR, dc: HDC, rect: *RECT, param: LPARAM) -> BOOL #c_call {
	c: Context;
    push_context(c) {
		info: MONITORINFOEXW;
	    info.cbSize = size_of(MONITORINFOEXW);
	    ok: BOOL = GetMonitorInfoW(monitor_handle, cast(*MONITORINFO)*info);
	    assert(xx ok, "GetMonitorInfoW failed");
	    
	    monitor_id_wide := xx,no_check info.szDevice.data;
	    
	    more_info: DEVMODEW;
	    name_wide := monitor_id_wide;
	    ok = EnumDisplaySettingsW(name_wide, ENUM_CURRENT_SETTINGS, *more_info);
	    assert(xx ok, "EnumDisplaySettingsW failed");
	    
	    even_more_info: DISPLAY_DEVICEW;
		even_more_info.cb = size_of(DISPLAY_DEVICEW);
	    display_device_found := false;
	    
	    i := 0;
	    while EnumDisplayDevicesW(null, xx,no_check i, *even_more_info, 0) {
	        if (wcscmp(even_more_info.DeviceName.data, monitor_id_wide) == 0) {
	            display_device_found = true;
	            break;
	        }
	        i += 1;
	    }
	    assert(display_device_found, "DISPLAY_DEVICE not found");
	    
	    monitor := array_add(*platform.monitors);
	    
	    if info.dwFlags & xx,no_check MONITORINFOF_PRIMARY  platform.primary_monitor = monitor;
	    
	    monitor.name         = wide_to_utf8_new(even_more_info.DeviceString.data,,temp);
	    monitor.refresh_rate = more_info.dmDisplayFrequency;
	    monitor.resolution_x = xx,no_check (info.rcMonitor.right  - info.rcMonitor.left);
	    monitor.resolution_y = xx,no_check (info.rcMonitor.bottom - info.rcMonitor.top);
	    
	    GetDpiForMonitor(monitor_handle, MDT_EFFECTIVE_DPI, xx,no_check *monitor.dpi, xx,no_check *monitor.dpi_y);
	    
	    if monitor_handle == MonitorFromWindow(window.handle, MONITOR_DEFAULTTONEAREST) {
	    	window.monitor = monitor;
	    }
    }
    return 1;
}
win_query_monitors :: () {
	window.monitor = null;

	array_reset_keeping_memory(*platform.monitors);
	
	EnumDisplayMonitors(null, null, win_query_monitors_callback, 0);
	
	if (!window.monitor) {
		window.monitor = platform.primary_monitor;
	}
}

platform_sleep :: (ms: int) {
	Sleep(xx ms);
}

platform_high_precision_sleep :: (ms: float64) {
	
	start := seconds_since_init();
	
	s := ms/1000.0;
	
	end := cast(float64)start + cast(float64)s;
	sleep_time := cast(s32)(((end-start))*1000.0-1.0);
	do_sleep := sleep_time >= 1;
	
	timeBeginPeriod(1);
	
	if do_sleep  platform_sleep(sleep_time);
	
	while seconds_since_init() < end {
		//SwitchToThread();
	}
	
}

platform_get_arena :: (reserved_size: int, amount_to_commit := 0, base_address := null, name := "unnamed") -> Arena {
	arena: Arena;
	arena.name = name;
	
	base_address_aligned := align_next(base_address, platform.granularity);
	
	assert(base_address_aligned == base_address, "base_address must be 0 or aligned to platform.granularity. Do align_next(x, platform.granularity)");
	
	reserved_size = align_next(reserved_size, platform.page_size);
	if amount_to_commit  amount_to_commit = align_next(amount_to_commit, platform.granularity);
	
	MAX_ATTEMPTS :: 100;
	attempts := 0;
	while (!arena.head && attempts < MAX_ATTEMPTS) {
		SetLastError(0);
		arena.head = VirtualAlloc(xx base_address, xx reserved_size, MEM_RESERVE, PAGE_NOACCESS);
		attempts += 1;
	}
	arena.next = arena.head;
	arena.reserved_size = reserved_size;
	win_check_last_error();
	
	if amount_to_commit {
		attempts = 0;
		commit_ptr := null;
		while (!commit_ptr && attempts < MAX_ATTEMPTS) {
			SetLastError(0);
			commit_ptr = VirtualAlloc(xx arena.head, xx amount_to_commit, MEM_COMMIT, PAGE_READWRITE);
			attempts += 1;
		}
		assert(commit_ptr != null, "VirtualAlloc for MEM_COMMIT failed, error code: %", GetLastError());
		arena.number_of_committed_bytes = amount_to_commit;
		memset(arena.head, 0, amount_to_commit);
	}
	win_check_last_error();
	
	return arena;
}

arena_make :: (ptr: *void, size_in_bytes: int, name := "unnamed") -> Arena {
	arena: Arena;
	arena.head = ptr;
	arena.next = ptr;
	arena.reserved_size = size_in_bytes;
	arena.number_of_committed_bytes = size_in_bytes;
	arena.name = name;
	
	return arena;
}
arena_make_child :: (parent: *Arena, size_in_bytes: int, name := "unnamed") -> Arena {
	
	ptr := arena_push(parent, size_in_bytes);

	arena: Arena;
	arena.head = ptr;
	arena.next = ptr;
	arena.reserved_size = size_in_bytes;
	arena.number_of_committed_bytes = size_in_bytes;
	arena.name = name;
	
	return arena;
}

arena_push :: (using arena: *Arena, number_of_bytes: int, $uninit := false, $debug_is_cycling := false) -> *void {

	if cast(*u8)arena.next+number_of_bytes > cast(*u8)arena.head+arena.reserved_size {
		#if !debug_is_cycling {
			log_error("Tried to push % bytes to arena '%', but it was full (%/%)", number_of_bytes, arena.name, format_bytes(xx (arena.next-arena.head)), format_bytes(arena.reserved_size));
			print_stack_trace(context.stack_trace);
		}
		return null;
	}
	if cast(*u8)arena.next+number_of_bytes > cast(*u8)arena.head+arena.number_of_committed_bytes {
		
		commit_start := cast(*u8)arena.head+arena.number_of_committed_bytes;
		
		new_number_of_committed_bytes := min(get_next_power_of_two(arena.number_of_committed_bytes+number_of_bytes), arena.reserved_size);
		assert(new_number_of_committed_bytes > arena.number_of_committed_bytes);
		
		commit_end := head + new_number_of_committed_bytes;
		
		committed_ptr := null;
		
		bytes_to_commit := (new_number_of_committed_bytes-arena.number_of_committed_bytes);
		
		MAX_ATTEMPTS :: 100;
		attempts := 0;
		while (!committed_ptr && attempts < MAX_ATTEMPTS) {
			SetLastError(0);
			committed_ptr = VirtualAlloc(commit_start, xx,no_check bytes_to_commit, MEM_COMMIT, PAGE_READWRITE);
			attempts += 1;
		}
		win_check_last_error();
		
		arena.number_of_committed_bytes = new_number_of_committed_bytes;
		
		memset(commit_start, 0, bytes_to_commit);
		
		log("Arena '%' committed % (total: % %% // %/%)", name, format_bytes(bytes_to_commit), 100.0*(cast(float64)arena.number_of_committed_bytes/cast(float64)arena.reserved_size), format_bytes(arena.number_of_committed_bytes), format_bytes(arena.reserved_size));
	}

	p := next;
	next = cast(*u8)next + number_of_bytes;
	#if !uninit {
		memset(p, 0, number_of_bytes);
	}
	
	
	
	return p;
}
arena_push :: (using arena: *Arena, $T: Type, count := 1, $uninit := false) -> *T {
	p: *T = xx arena_push(arena, size_of(T)*count, uninit);
	#if !uninit then default_initialize(p);
	return p;
}
arena_push_scoped :: (using arena: *Arena, number_of_bytes: int, $uninit := false) -> *void #expand {
	`defer arena_pop(arena, number_of_bytes);
	return arena_push(arena, number_of_bytes, uninit);
}
arena_push_scoped :: (using arena: *Arena, $T: Type, count := 1, $uninit := false) -> *T #expand {
	`defer arena_pop(arena, size_of(T)*count);
	return arena_push(arena, T, count, uninit);
}
arena_push_cycling :: (using arena: *Arena, size: int) -> *void {
	if cast(*u8)arena.next+size > cast(*u8)arena.head + arena.reserved_size {
		arena_reset(arena);
	}
	return arena_push(arena, size, debug_is_cycling=true);
}
arena_push_cycling :: (using arena: *Arena, $T: Type, n := 1) -> *void {
	if cast(*u8)arena.next+size_of(T)*n > cast(*u8)arena.head + arena.reserved_size {
		arena_reset(arena);
	}
	return arena_push(arena, size_of(T)*n, debug_is_cycling=true);
}
arena_push_copy :: (using arena: *Arena, p: *void, size: int) -> *void {
	cp := arena_push(arena, size);
	memcpy(cp, p, size);
	return cp;
}
arena_push_copy_cycling :: (using arena: *Arena, p: *void, size: int) -> *void {
	cp := arena_push_cycling(arena, size);
	memcpy(cp, p, size);
	return cp;
}
arena_push_copy :: (using arena: *Arena, p: $T) -> *void {
	cp := arena_push(arena, size_of(T));
	memcpy(cp, *p, size_of(T));
	return cp;
}
arena_push_copy_cycling :: (using arena: *Arena, p: $T) -> *void {
	cp := arena_push_cycling(arena, size_of(T));
	memcpy(cp, *p, size_of(T));
	return cp;
}

arena_pop :: (using arena: *Arena, number_of_bytes: int) {
	last := next;
	next = max(cast(*u8)next - number_of_bytes, arena.head);
	#if DEBUG {
		popped_page_start := align_next(next, platform.page_size);
		num := cast(int)(last-next);
		memset(next, 0xBA, num);
		
		// #Incomplete lock pages
	}
}
arena_reset :: (using arena: *Arena) {
	next = head;
}

arena_can_fit :: (using arena: Arena, size: int) -> bool {
	return arena.next + size <= arena.head+arena.reserved_size;
}

binary_semaphore_init :: (sem: *Platform_Binary_Semaphore, signalled := false) {
	sem.os_event = CreateEventW(null, 1, xx (ifx signalled  1 else 0), null);
	sem.initted = true;
}

binary_semaphore_destroy :: (sem: *Platform_Binary_Semaphore) {
	if !sem.initted  binary_semaphore_init(sem);
	CloseHandle(sem.os_event);
}

binary_semaphore_wait :: (sem: *Platform_Binary_Semaphore) {
	if !sem.initted  binary_semaphore_init(sem);
	WaitForSingleObject(sem.os_event, INFINITE);
	ResetEvent(sem.os_event);
}

binary_semaphore_unsignal :: (sem: *Platform_Binary_Semaphore) {
	if !sem.initted  binary_semaphore_init(sem);
	ResetEvent(sem.os_event);
}

binary_semaphore_signal :: (sem: *Platform_Binary_Semaphore) {
	if !sem.initted  binary_semaphore_init(sem);
	SetEvent(sem.os_event);
}




win_check_last_error :: inline (location := #caller_location) #expand {
	win_check_hr(HRESULT_FROM_WIN32(GetLastError()), location);
}

win_check_hr :: (hr: HRESULT, location := #caller_location) {
    if (hr != S_OK) {
    
    	msg: *void;
    	flags: DWORD = FORMAT_MESSAGE_ALLOCATE_BUFFER | 
	                    FORMAT_MESSAGE_FROM_SYSTEM | 
	                    FORMAT_MESSAGE_IGNORE_INSERTS;

        len := FormatMessageW(
            flags,
            null,
            xx,no_check hr,
            MAKELANGID(LANG_ENGLISH, SUBLANG_DEFAULT),
            xx *msg,
            0,
            null
        );

		wide_err: *u16;

        if (len > 0) {
        	wide_err = xx msg;
        } else {
        	wide_err = utf8_to_wide_new("Failed to retrieve error message.",,temp);
        }
    
    	utf8_err := wide_to_utf8_new(wide_err,,temp);
    	
    	Facility_Kind :: enum {
    		FACILITY_DISPATCH :: 2;
    		FACILITY_ITF      :: 4;
    		FACILITY_NULL     :: 0;
    		FACILITY_RPC      :: 1;
    		FACILITY_STORAGE  :: 3;
    		FACILITY_WIN32    :: 7;
    		FACILITY_WINDOWS  :: 8;
    	}
    	
    	facility := cast(Facility_Kind)((hr >> 16) & 0x000000FF);
    	code := hr & 0x0000FFFF;
    	
    	final_message_utf8 := tprint("%\nIn file % on line %\n\nhr: 0x%\nFacility: %\nCode: %", utf8_err, location.fully_pathed_filename, location.line_number, formatInt(hr, base=16), facility, code);
    	
    	final_message_wide := utf8_to_wide_new(final_message_utf8,,temp);
    
        MessageBoxW(null, final_message_wide, utf8_to_wide_new("Error",,temp), MB_OK | MB_ICONERROR);

        panic("win hr failed:\n%", final_message_utf8);
    }
}


#scope_file

#load "windows_bindings.jai";
#import "Windows";
#import "Windows_Utf8";
#import "Gamepad";

XUSER_MAX_COUNT :: 4;
XINPUT_VIBRATION :: struct {
  wLeftMotorSpeed:  WORD;
  wRightMotorSpeed: WORD;
}
XINPUT_GAMEPAD :: struct {
	wButtons:      WORD;
	bLeftTrigger:  u8;
	bRightTrigger: u8;
	sThumbLX:      s16;
	sThumbLY:      s16;
	sThumbRX:      s16;
	sThumbRY:      s16;
}
XINPUT_STATE :: struct {
	dwPacketNumber: DWORD;
	Gamepad: XINPUT_GAMEPAD;
}
XInputGetState: (DWORD, *XINPUT_STATE)     -> DWORD #c_call;
XInputSetState: (DWORD, *XINPUT_VIBRATION) -> DWORD #c_call;

win: struct {
	system_info:                     SYSTEM_INFO;
	last_window:                     Platform_Window;
	windowed_style:                  DWORD;
	windowed_style_ex:               DWORD;
	windowed_x:                      int;
	windowed_y:                      int;
	windowed_width:                  int;
	windowed_height:                 int;
	want_override_mouse_pointer:     bool;
	did_override_user_mouse_pointer: bool;
	shadowed_mouse_pointer:          HCURSOR;
	loaded_pointers:                 [#run enum_highest_value(Mouse_Pointer_Kind)+1]HCURSOR;
	xinput:                          HANDLE;
	last_xinput_states:              [XUSER_MAX_COUNT]XINPUT_STATE;
	last_blt_time:                   float64;
};
