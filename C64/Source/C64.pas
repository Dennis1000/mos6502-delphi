unit C64;

interface

uses
  System.Classes, WinApi.Messages, MOS6502;

const
  WM_SCREEN_WRITE = WM_USER + 0;

  CIA1 = $DC00;
  KEY_TRANSLATION = '1£+9753'#8+#8'*piyrw'#13+#0';ljgda'#0+'2'#0'-0864'#0+' '#0'.mbcz'#0+#0'=:khfs'#0+'q'#0'@oute'#0+
    #0'/,nvx'#0#0+'!'#0#0')'#39'%#'+#0+#0#0#0#0#0#0#0#13+#0']'#0#0#0#0#0#0+'"'#0#0#0'(&$'#0+' '#0'>'#0#0#0#0#0+
    #0#0'['#0#0#0#0#0+#0#0#0#0#0#0#0#0+#0'?<';

type
  TC64 = class;

  TC64Thread = class(TThread)
  private
    C64: TC64;
  protected
  public
    procedure Execute; override;
    constructor Create(C64Instance: TC64);
  end;

  TC64 = class(TMOS6502)
  private
    Thread: TC64Thread;
    TimerHandle: Integer;
    LastKey: Char;
    procedure BusWrite(Adr: Word; Value: Byte);
    function BusRead(Adr: Word): Byte;
    function KeyRead: Byte;
  protected
    KeyMatrix: Array[0 .. 7, 0 .. 7] of Byte;
    Memory: PByte;
    InterruptRequest: Boolean;
  public
    WndHandle: THandle;
    constructor Create;
    destructor Destroy; override;
    procedure LoadROM(Filename: String; Addr: Word);
    procedure Exec;
    procedure SetKey(Key: Char; Value: Byte);
  end;

implementation

uses
  System.SysUtils, Winapi.Windows, WinApi.MMSystem;

{ TC64 }

procedure TimerProcedure(TimerID, Msg: Uint; dwUser, dw1, dw2: DWORD); pascal;
var
  C64: TC64;
begin
  C64 := TC64(dwUser);

  if C64.Status and $04 = 0 then // if IRQ allowed then set irq
    C64.InterruptRequest := True;
end;


function TC64.BusRead(Adr: Word): Byte;
begin
  Result := Memory[Adr];
end;

procedure TC64.BusWrite(Adr: Word; Value: Byte);
begin
  // test for I/O requests
  case Adr of
    CIA1:
      begin
        // Handle keyboard reading
        Memory[Adr] := Value;
        Memory[CIA1 + 1] := KeyRead;
      end;

    CIA1 + 5: // Timer
     if TimerHandle = 0 then
       TimerHandle := TimeSetEvent(34, 2, @TimerProcedure, DWORD(Self), TIME_PERIODIC);
  end;

  if (Adr >= $A000) then  // treat anything above as ROM
    Exit;

  Memory[Adr] := Value;

  // video RAM
  if (Adr >= $400) and (Adr <= $07E7) then
    PostMessage(WndHandle, WM_SCREEN_WRITE, Adr - $400, Value);
end;

constructor TC64.Create;
begin
  inherited Create(BusRead, BusWrite);

  // create 64kB memory table
  GetMem(Memory, 65536);

  Thread := TC64Thread.Create(Self);
end;

destructor TC64.Destroy;
begin
  if TimerHandle <> 0 then
    Timekillevent(TimerHandle);
  Thread.Terminate;
  Thread.WaitFor;
  FreeMem(Memory);
  inherited;
end;

procedure TC64.Exec;
begin
  Reset;
  Thread.Start;
end;

function TC64.KeyRead: Byte;
var
  Row, Col, Cols: Byte;
begin
  Result := 0;
  Cols := Memory[CIA1];
  for Col := 0 to 7 do
    if Cols and (1 shl Col) = 0 then  // a 0 indicates a column read
      for Row := 0 to 7 do
        if KeyMatrix[7 - Col, Row] = 1 then
          Result := Result + (1 shl Row);
  Result := not Result;
end;

procedure TC64.LoadROM(Filename: String; Addr: Word);
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(Filename, fmOpenRead);
  try
    Stream.Read(Memory[Addr], Stream.Size);
  finally
    Stream.Free;
  end;
end;

procedure TC64.SetKey(Key: Char; Value: Byte);
var
  KeyPos: Integer;
begin
  KeyPos := Pos(Key, KEY_TRANSLATION) - 1;
  if KeyPos >= 0 then
  begin
    // always release last key on keypress
    if Value = 1 then
    begin
      SetKey(LastKey, 0);
      LastKey := Key;
    end;

    if KeyPos > 63 then  // set right shift on/off
    begin
      KeyMatrix[1, 4] := Value;
      Dec(KeyPos, 64);
    end;

    KeyMatrix[KeyPos mod 8, KeyPos div 8] := Value;
  end;
end;

{ TC64Thread }

constructor TC64Thread.Create(C64Instance: TC64);
begin
  inherited Create(True);
  C64 := C64Instance;
end;

procedure TC64Thread.Execute;
begin
  while (not Terminated) do
  begin
    if C64.InterruptRequest then
    begin
      C64.InterruptRequest := False;
      C64.IRQ;
    end;
    C64.Step;
    Sleep(0);
  end;
end;

end.
