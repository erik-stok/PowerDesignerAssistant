unit fMain;

interface

uses
  Windows, Messages, Forms, Classes, Controls, StdCtrls, SysUtils, Dialogs,
  CoolTrayIcon, uShared, ImgList, Menus;

type
  THookInstall   = procedure(const ANotify: THandle);
  THookUninstall = procedure;

  TFrmMain = class(TForm)
    mmoLog: TMemo;
    imlTray: TImageList;
    pumTray: TPopupMenu;
    mniClose: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure mniCloseClick(Sender: TObject);
    procedure FormHide(Sender: TObject);
  private
    FHook          : THandle;
    FHookInstall   : THookInstall;
    FHookUninstall : THookUninstall;

    FShiftDown     : Boolean;
    FAltDown       : Boolean;

    FTrayIcon      : TCoolTrayIcon;

    function KeyToString(const AKey: Cardinal): String;

    procedure DoTrayIconDblClick(Sender: TObject);
    procedure ShowMainForm;
  protected
    procedure KMKeyDown(var Msg: TMessage); message KM_KEYDOWN;
    procedure KMKeyRepeat(var Msg: TMessage); message KM_KEYREPEAT;
    procedure KMKeyUp(var Msg: TMessage); message KM_KEYUP;
  end;

var
  FrmMain: TFrmMain;

implementation

{$R *.dfm}

procedure TFrmMain.FormCreate;
begin
  // Start hidden
  Application.ShowMainForm := False;

  // Create cool trayicon component. Runtime creation so the component
  // does not need to be installed
  FTrayIcon := TCoolTrayIcon.Create(Self);

  // Set up tray icon
  with FTrayIcon do
  begin
    // Set properties
    IconList       := imlTray;
    IconIndex      := 0;
    Hint           := Caption;
    IconVisible    := True;
    PopupMenu      := pumTray;
    MinimizeToTray := True;

    // Set events
    FTrayIcon.OnDblClick := DoTrayIconDblClick;
  end;

  FShiftDown := False;
  FAltDown   := False;

  FHook := LoadLibrary('KeyboardHook.dll');

  if FHook = 0 then
  begin

    MessageDlg('KeyboardHook.dll not found!', mtError, [mbOK], 0);

  end
  else
  begin

    @FHookInstall   := GetProcAddress(FHook, 'HookInstall');
    @FHookUninstall := GetProcAddress(FHook, 'HookUninstall');

    if (not Assigned(FHookInstall)) or (not Assigned(FHookUninstall)) then
    begin
      FreeLibrary(FHook);
      FHook          := 0;
      FHookInstall   := nil;
      FHookUninstall := nil;

      MessageDlg('KeyboardHook.dll is not correct!', mtError, [mbOK], 0);
    end
    else
    begin
      FHookInstall(Self.Handle);
    end;

  end;

end;

procedure TFrmMain.FormDestroy;
begin
  if FHook <> 0 then
  begin
    FHookUninstall;
    FreeLibrary(FHook);
  end;
end;


function TFrmMain.KeyToString;
var
  Text: array[0..255] of Char;
begin
  FillChar(Text, SizeOf(Text), #0);
  GetKeyNameText(AKey, @Text, SizeOf(Text));
  Result := Text;
end;

procedure TFrmMain.KMKeyDown(var Msg: TMessage);
begin
  // Check if shift went down
  if SameText(KeyToString(Msg.LParam), 'Shift') then
    FShiftDown := True;

  // Check if ctrl went down
  if SameText(KeyToString(Msg.LParam), 'Alt') then
    FAltDown := True;
end;

procedure TFrmMain.KMKeyRepeat(var Msg: TMessage);
begin
  // Ingore repeats
end;

procedure TFrmMain.KMKeyUp(var Msg: TMessage);

  function GetActiveControlText: String;
  var
    Focuswin      : HWND;
    Otherwin      : HWND;
    OtherThreadID : DWord;
    Dummy         : DWord;
    Text          : PChar;
  begin
    OtherWin := GetForegroundWindow;

    OtherThreadID := GetWindowThreadProcessID(OtherWin, @Dummy);

    if AttachThreadInput(GetCurrentThreadID, OtherThreadID, True) then
    try
      FocusWin := GetFocus;
      if FocusWin <> 0 then
      begin
        GetMem(Text, 1023);
        SendMessage(FocusWin, WM_GETTEXT, 1023, LParam(Text));
        Result := Text;
        FreeMem(Text, 1023);
      end;
    finally
      AttachThreadInput(GetCurrentThreadID, OtherThreadID, False);
    end;
  end;

  procedure SetActiveControlText(NewText: String);
  var
    Focuswin      : HWND;
    Otherwin      : HWND;
    OtherThreadID : DWord;
    Dummy         : DWord;
    SelStart      : Integer;
    SelEnd        : Integer;
    Text          : PChar;
  begin
    OtherWin := GetForegroundWindow;

    OtherThreadID := GetWindowThreadProcessID(OtherWin, @Dummy);

    if AttachThreadInput(GetCurrentThreadID, OtherThreadID, True) then
    try
      FocusWin := GetFocus;
      if FocusWin <> 0 then
      begin
        GetMem(Text, 1023);
        StrPCopy(Text, NewText);
        SendMessage(FocusWin, EM_GETSEL, WParam(@SelStart), LParam(@SelEnd));
        SendMessage(FocusWin, WM_SETTEXT, 0, LParam(Text));
        SendMessage(FocusWin, EM_SETSEL, SelStart, SelEnd);
        FreeMem(Text, 1023);
      end;
    finally
      AttachThreadInput(GetCurrentThreadID, OtherThreadID, False);
    end;
  end;

  procedure SetActiveControlCursor(Position: Integer);
  var
    Focuswin      : HWND;
    Otherwin      : HWND;
    OtherThreadID : DWord;
    Dummy         : DWord;
  begin
    OtherWin := GetForegroundWindow;

    OtherThreadID := GetWindowThreadProcessID(OtherWin, @Dummy);

    if AttachThreadInput(GetCurrentThreadID, OtherThreadID, True) then
    try
      FocusWin := GetFocus;
      if FocusWin <> 0 then
        SendMessage(FocusWin, EM_SETSEL, Position, Position);

    finally
      AttachThreadInput(GetCurrentThreadID, OtherThreadID, False);
    end;
  end;

var
  Text : String;
begin
  // Check if shift went up
  if SameText(KeyToString(Msg.LParam), 'Shift') then
    FShiftDown := False;

  // Check if ctrl went up
  if SameText(KeyToString(Msg.LParam), 'Alt') then
    FAltDown := False;

  // Check if pause is went up. If so, get to work.
  if SameText(KeyToString(Msg.LParam), 'Pause') then
  begin
    Text := GetActiveControlText;

    if (not FShiftDown) and (not FAltDown) then
    begin
      if Length(Text) > 30 then
        SetActiveControlCursor(30);
    end;

    if FShiftDown and (not FAltDown) then
    begin
      SetActiveControlText(AnsiUpperCase(Text));

      mmoLog.Lines.Add(Format('Converted %s to %s', [Text, AnsiUpperCase(Text)]));
    end;

    if (not FShiftDown) and FAltDown then
    begin
      SetActiveControlText(AnsiLowerCase(Text));

      mmoLog.Lines.Add(Format('Converted %s to %s', [Text, AnsiLowerCase(Text)]));
    end;
  end;
end;

procedure TFrmMain.DoTrayIconDblClick(Sender: TObject);
begin
  // Execute show action on double click
  ShowMainForm;
end;

procedure TFrmMain.mniCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TFrmMain.ShowMainForm;
begin
  // Display form
  if not Application.ShowMainForm then
    Application.ShowMainForm := True;

  // Show main form
  FTrayIcon.ShowMainForm;

  // Hide icon
  FTrayIcon.IconVisible := False;
end;

procedure TFrmMain.FormHide(Sender: TObject);
begin
  // Display icon when hidden
  FTrayIcon.IconVisible := True;
end;

end.
