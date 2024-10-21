



kernel32 :: #system_library "kernel32";
user32   :: #system_library "user32";
shcore   :: #system_library "shcore";
gdi32    :: #system_library "gdi32";
avrt     :: #system_library "avrt";
dwmapi   :: #system_library "dwmapi";

ENUM_CURRENT_SETTINGS : DWORD : xx,no_check -1;
MONITORINFOF_PRIMARY : DWORD : 0x00000001;

HTBORDER       :: 18;
HTBOTTOM       :: 15;
HTBOTTOMLEFT   :: 16;
HTBOTTOMRIGHT  :: 17;
HTCAPTION      :: 2;
HTCLIENT       :: 1;
HTCLOSE        :: 20;
HTERROR        :: -2;
HTGROWBOX      :: 4;
HTHELP         :: 21;
HTHSCROLL      :: 6;
HTLEFT         :: 10;
HTMENU         :: 5;
HTMAXBUTTON    :: 9;
HTMINBUTTON    :: 8;
HTNOWHERE      :: 0;
HTREDUCE       :: 8;
HTRIGHT        :: 11;
HTSIZE         :: 4;
HTSYSMENU      :: 3;
HTTOP          :: 12;
HTTOPLEFT      :: 13;
HTTOPRIGHT     :: 14;
HTTRANSPARENT  :: -1;
HTVSCROLL      :: 7;
HTZOOM         :: 9;

MONITORINFOEXW :: struct {
	using base: MONITORINFO;
  	szDevice: [32]u16;
}

POINTL :: struct {
  x: s32;
  y: s32;
}

DEVMODEW :: struct {
  dmDeviceName: [32]u16;
  dmSpecVersion: WORD;
  dmDriverVersion: WORD;
  dmSize: WORD;
  dmDriverExtra: WORD;
  dmFields: DWORD;
  DUMMYUNIONNAME: union {
    DUMMYSTRUCTNAME: struct {
      dmOrientation: s16;
      dmPaperSize: s16;
      dmPaperLength: s16;
      dmPaperWidth: s16;
      dmScale: s16;
      dmCopies: s16;
      dmDefaultSource: s16;
      dmPrintQuality: s16;
    };
    dmPosition: POINTL;
    DUMMYSTRUCTNAME2: struct {
      dmPosition: POINTL;
      dmDisplayOrientation: DWORD;
      dmDisplayFixedOutput: DWORD;
    };
  };
  dmColor: s16;
  dmDuplex: s16;
  dmYResolution: s16;
  dmTTOption: s16;
  dmCollate: s16;
  dmFormName: [32]u16;
  dmLogPixels: WORD;
  dmBitsPerPel: DWORD;
  dmPelsWidth: DWORD;
  dmPelsHeight: DWORD;
  DUMMYUNIONNAME2: union {
    dmDisplayFlags: DWORD;
    dmNup: DWORD;
  };
  dmDisplayFrequency: DWORD;
  dmICMMethod: DWORD;
  dmICMIntent: DWORD;
  dmMediaType: DWORD;
  dmDitherType: DWORD;
  dmReserved1: DWORD;
  dmReserved2: DWORD;
  dmPanningWidth: DWORD;
  dmPanningHeight: DWORD;
}

DISPLAY_DEVICEW :: struct {
  cb:           DWORD;
  DeviceName:   [32]u16;
  DeviceString: [128]u16;
  StateFlags:   DWORD;
  DeviceID:     [128]u16;
  DeviceKey:    [128]u16;
}

MINMAXINFO :: struct {
  ptReserved:     POINT;
  ptMaxSize:      POINT;
  ptMaxPosition:  POINT;
  ptMinTrackSize: POINT;
  ptMaxTrackSize: POINT;
}

HRESULT_FROM_WIN32 :: (x: u32) -> HRESULT { 

	xhr: HRESULT = cast(HRESULT)x;
	
	return xx,no_check ifx xhr <= 0 then x else (x & 0x0000FFFF) | (7 << 16) | 0x80000000;
}

SetLastError :: (err: DWORD) #foreign kernel32;

EnumDisplaySettingsW :: (lpszDeviceName: *u16, iModeNum: DWORD, lpDevMode: *DEVMODEW) -> BOOL #foreign user32;
EnumDisplayDevicesW :: (lpDevice: *u16, iDevNum: DWORD, lpDisplayDevice: *DISPLAY_DEVICEW, dwFlags: DWORD) -> BOOL #foreign user32;
SetProcessDpiAwarenessContext :: (value: DPI_AWARENESS_CONTEXT) -> BOOL #foreign user32; // #Portability
SetProcessDpiAwareness :: (awareness: s32) -> HRESULT #foreign shcore; // #Portability

GetDpiForMonitor :: (hmonitor: HMONITOR, dpiType: MONITOR_DPI_TYPE, dpiX: *u32, dpiY: *u32) -> HRESULT #foreign shcore;

CreateDIBSection :: (hdc: HDC, pbmi: *BITMAPINFO, usage: u32, ppvBits: **void, hSection: HANDLE, offset: DWORD) -> HBITMAP #foreign gdi32;
CreateIconIndirect :: (piconinfo: *ICONINFO) -> HICON #foreign user32;


ResetEvent :: (hEvent: HANDLE) -> BOOL #foreign kernel32;
SetEvent   :: (hEvent: HANDLE) -> BOOL #foreign kernel32;

SwitchToThread :: () -> BOOL #foreign kernel32;

SetPriorityClass :: (hProcess: HANDLE, dwPriorityClass: DWORD) -> BOOL #foreign kernel32;

AvSetMmThreadCharacteristicsA :: (TaskName: *u8, TaskIndex: *u32) -> HANDLE #foreign avrt;

SetDIBitsToDevice :: (hdc: HDC, xDest: s32, yDest: s32, w: DWORD, h: u32, xSrc: u32, ySrc: u32, startScane: u32, cLines: u32, lpvBits: *void, lpbmi: *BITMAPINFO, ColorUse: u32) -> s32 #foreign gdi32;

DwmFlush :: () -> HRESULT #foreign dwmapi;