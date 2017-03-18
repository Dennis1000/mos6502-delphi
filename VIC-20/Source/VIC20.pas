unit VIC20;

interface

uses
  System.Classes, WinApi.Messages, MOS6502;

const
  WM_SCREEN_WRITE = WM_USER + 0;

  CIA1 = $9120;   // $DC00;

  // VIC-20 keyboard matrix
  KEY_TRANSLATION = '2q'#0' '#27#0#0'1'+
                    '4esz'#0'aw3'+
                    '6tfcxdr5'+
                    '8uhbvgy7'+
                    '0okmnji9'+
                    '-@:.,lp+'+
                    #0#0'='#0'/;*£'+
                    #0#0#0#0#0#0#13#8+

                    '"'#0#0#0#0#0#0'!'+
                    '$'#0#0#0#0#0#0'#'+
                    '&'#0#0#0#0#0#0'%'+
                    '('#0#0#0#0#0#0''''+
                    '0'#0#0#0#0#0#0')'+
                    '_'#0'[><l'#0#0+
                    #0#0'='#0'?]'#0#0+
                    #0#0#0#0#0#0#13#8;

type
  TVC20 = class;

  TVC20Thread = class(TThread)
  private
    VC20: TVC20;
  protected
  public
    procedure Execute; override;
    constructor Create(VC20Instance: TVC20);
  end;

  TVC20 = class(TMOS6502)
  private
    Thread: TVC20Thread;
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

{ TVC20 }

procedure TimerProcedure(TimerID, Msg: Uint; dwUser, dw1, dw2: DWORD); pascal;
var
  VC20: TVC20;
begin
  VC20 := TVC20(dwUser);

  if VC20.Status and VC20.INTERRUPT = 0 then // if IRQ allowed then set irq
    VC20.InterruptRequest := True;
end;


function TVC20.BusRead(Adr: Word): Byte;
begin
  Result := Memory[Adr];
end;

procedure TVC20.BusWrite(Adr: Word; Value: Byte);
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

  if (Adr >= $2000) then // $A000  // treat anything above as ROM
    Exit;

  Memory[Adr] := Value;

  // video RAM
  if (Adr >= $1E00) and (Adr <= $1FF9) then   // $400 - $07E7
    PostMessage(WndHandle, WM_SCREEN_WRITE, Adr - $1E00, Value);  // $400
end;

constructor TVC20.Create;
begin
  inherited Create(BusRead, BusWrite);

  // create 64kB memory table
  GetMem(Memory, 65536);

  Thread := TVC20Thread.Create(Self);
end;

destructor TVC20.Destroy;
begin
  if TimerHandle <> 0 then
    Timekillevent(TimerHandle);
  Thread.Terminate;
  Thread.WaitFor;
  FreeMem(Memory);
  inherited;
end;

procedure TVC20.Exec;
begin
  Reset;
  Thread.Start;
end;

function TVC20.KeyRead: Byte;
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

procedure TVC20.LoadROM(Filename: String; Addr: Word);
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

procedure TVC20.SetKey(Key: Char; Value: Byte);
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
      KeyMatrix[3, 6] := Value;   // 1, 4
      Dec(KeyPos, 64);
    end;

    KeyMatrix[KeyPos mod 8, KeyPos div 8] := Value;
  end;
end;

{ TVC20Thread }

constructor TVC20Thread.Create(VC20Instance: TVC20);
begin
  inherited Create(True);
  VC20 := VC20Instance;
end;

procedure TVC20Thread.Execute;
begin
  while (not Terminated) do
  begin
    if VC20.InterruptRequest then
    begin
      VC20.InterruptRequest := False;
      VC20.IRQ;
    end;
    VC20.Step;
    Sleep(0);
  end;
end;

end.
