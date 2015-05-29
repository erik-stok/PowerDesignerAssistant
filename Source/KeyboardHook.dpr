library KeyboardHook;

uses
  Windows,
  Messages,
  uShared in 'uShared.pas';

type
  PHookData   = ^THookData;
  THookData   = record
    Hook   : THandle;
    Notify : THandle;
  end;

var
  // Note: these variables are per-process! GMap is used to install/uninstall
  // the hook, therefore the same process which installed the hook MUST
  // uninstall it. GShared references the same file mapping, but exists to
  // prevent conflicts with GMap in the "mother process". GData is initialized
  // in the DLL's initialization and can be used to access the shared data.
  GMap    : THandle;

  GShared : THandle;
  GData   : PHookData;

const
  MapName = '{2E20AB6E-0C90-461F-A0B3-955EF55793BB}';

function KeyboardProc(Code: Integer; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  Hook : THandle;
  Msg  : Cardinal;

begin
  if Assigned(GData) then
    Hook := GData^.Hook
  else
    Hook := 0;

  Result := CallNextHookEx(Hook, Code, wParam, lParam);

  if (Code < 0) or (Hook = 0) then
    Exit;

  // lParam contains the key state, according to the SDK the interesting
  // bits are:
  //
  // 30 - Previous state; if set to 1, the key was down, otherwise it was up.
  // 31 - Transition state; if set to 1, the key is being released, otherwise
  //      it is being pressed.
  if ((lParam shr 31) and 1) = 1 then
  begin
    // Key is being released
    Msg := KM_KEYUP
  end
  else
  begin
    if ((lParam shr 30) and 1) = 1 then
      // Key was already down, it's a repeat
      Msg := KM_KEYREPEAT
    else
      // Key is being pressed
      Msg := KM_KEYDOWN;
  end;

  // Notify the application. Instead of SendMessage I'm using PostMessage.
  // The advantage is that the hook doesn't have to wait for the application
  // to process the message, thus not slowing down the system (at least to
  // a minimum). The downside is that you can't let the application
  // modify any of the messages, only monitor it.
  PostMessage(GData^.Notify, Msg, wParam, lParam);
end;

procedure HookInstall(const ANotify: THandle);
var
  View: PHookData;
begin
  // Create shared data
  GMap := CreateFileMapping($FFFFFFFF, nil, PAGE_READWRITE, 0,
                             SizeOf(THookData), MapName);
  View := MapViewOfFile(GMap, FILE_MAP_WRITE, 0, 0, 0);

  if Assigned(View) then
  begin
    // Install hook
    View^.Notify := ANotify;
    View^.Hook   := SetWindowsHookEx(WH_KEYBOARD, @KeyboardProc, hInstance, 0);
    UnmapViewOfFile(View);
  end;
end;

procedure HookUninstall;
var
  View: PHookData;
begin
  View := MapViewOfFile(GMap, FILE_MAP_READ, 0, 0, 0);

  if Assigned(View) then
  begin
    // Uninstall hook
    UnhookWindowsHookEx(View^.Hook);
    UnmapViewOfFile(View);
  end;

  CloseHandle(GMap);
end;


procedure LibraryProc(Reason: Integer);
begin
  case Reason of
    DLL_PROCESS_ATTACH:
      begin
        DisableThreadLibraryCalls(hInstance);
        GShared := OpenFileMapping(FILE_MAP_READ, False, MapName);
        GData   := MapViewOfFile(GShared, FILE_MAP_READ, 0, 0, 0);
      end;
    DLL_PROCESS_DETACH:
      begin
        UnmapViewOfFile(GData);
        CloseHandle(GShared);
      end;
  end;
end;

exports
  HookInstall,
  HookUninstall;

begin
  DllProc := LibraryProc;
  DllProc(DLL_PROCESS_ATTACH);
end.

