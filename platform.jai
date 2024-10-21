
#if OS == .WINDOWS {
	#load "platform_windows.jai";
}

MAX_WINDOW_DIMENSION :: 8192;

Platform_Window :: struct {
	width: int = 1280;
	height: int = 720;
	front_buffer: []u8;
	back_buffer: []u8;
	swap_mutex: Mutex;
	
	x: int;
	y: int;
	fullscreen: bool;
	vsync: bool;
	
	should_close: bool;
	
	handle: Window_Handle;
	dc: *void;
	
	monitor: *Platform_Monitor;
	
	has_focus: bool;
	
}

Arena :: struct {

	using #as allocator: Allocator;

	head: *void;
	next: *void;
	
	reserved_size:  int;
	number_of_committed_bytes:  int;
	
	name: string;
}

Platform_Info :: struct {
	granularity: int;
	page_size: int;
	
	number_of_logical_processors: int;
	
	primary_monitor: *Platform_Monitor;
	monitors: [..]Platform_Monitor;
	
	keyboard_delay_seconds: float32;
}

Platform_Monitor :: struct {
	refresh_rate: int;
	resolution_x: int;
	resolution_y: int;
	dpi:          int;
	dpi_y:        int;
	name:         string;
};

Mouse_Pointer_Kind :: enum {
    DEFAULT           :: 0;   // https://learn.microsoft.com/en-us/windows/win32/menurc/images/idc_arrow.png
    TEXT_SELECT       :: 10;  // https://learn.microsoft.com/en-us/windows/win32/menurc/images/idc_ibeam.png
    BUSY              :: 20;  // https://learn.microsoft.com/en-us/windows/win32/menurc/images/idc_wait.png
    BUSY_BACKGROUND   :: 30;  // https://learn.microsoft.com/en-us/windows/win32/menurc/images/idc_appstarting.png
    CROSS             :: 40;  // https://learn.microsoft.com/en-us/windows/win32/menurc/images/idc_cross.png
    ARROW_N           :: 50;  // https://learn.microsoft.com/en-us/windows/win32/menurc/images/idc_uparrow.png
    ARROWS_NW_SE      :: 60;  // https://learn.microsoft.com/en-us/windows/win32/menurc/images/idc_sizenwse.png
    ARROWS_NE_SW      :: 70;  // https://learn.microsoft.com/en-us/windows/win32/menurc/images/idc_sizenesw.png
    ARROWS_HORIZONTAL :: 80;  // https://learn.microsoft.com/en-us/windows/win32/menurc/images/idc_sizewe.png
    ARROWS_VERTICAL   :: 90;  // https://learn.microsoft.com/en-us/windows/win32/menurc/images/idc_sizens.png
    ARROWS_ALL        :: 100; // https://learn.microsoft.com/en-us/windows/win32/menurc/images/idc_sizeall.png
    NO                :: 110; // https://learn.microsoft.com/en-us/windows/win32/menurc/images/idc_no.png
    POINT             :: 120; // https://learn.microsoft.com/en-us/windows/win32/menurc/images/idc_hand.png
}

window: Platform_Window;
platform: Platform_Info;

Platform_Binary_Semaphore :: struct {
    os_event: *void;
    initted: bool;
}


cpu_info: Cpu_X86;