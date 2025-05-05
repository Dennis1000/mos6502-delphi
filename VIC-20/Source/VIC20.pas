unit VIC20;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

uses
{$IFnDEF FPC}
  WinApi.Messages, System.Classes,
{$ELSE}
  Windows, Classes,
{$ENDIF}
  MOS6502;

// USE_THREADEDTIMERSIMULATION compiler switch
// If activated the program uses the 6502 CPU Cycles as the time base and
//  inserts every 18470 cycles (=16.66359 ms = (nearly) 1/60s  the timer interrupt.
//  It also support other IRQ timing, since the registers of the VIA2 $9124, $9125 are used.
// If deactivated, a System-Timer is used and triggers
//  every 17ms (almost 1/59s) the timer interrupt.
{$DEFINE USE_THREADEDTIMERSIMULATION}

const
  WM_SCREEN_WRITE = WM_USER + 0;

  CIA1 = $9120;   // $DC00;

  // VIC-20 keyboard matrix
{
  Found at: https://www.lemon64.com/forum/viewtopic.php?t=68210

  VIC20 Keyboard Matrix

  Write to Port B($9120)column
  Read from Port A($9121)row

       7   6   5   4   3   2   1   0
      --------------------------------
    7| F7  F5  F3  F1  CDN CRT RET DEL    CRT=Cursor-Right, CDN=Cursor-Down
     |
    6| HOM UA  =   RSH /   ;   *   BP     BP=British Pound, RSH=Should be Right-SHIFT,
     |                                    UA=Up Arrow
    5| -   @   :   .   ,   L   P   +
     |
    4| 0   O   K   M   N   J   I   9
     |
    3| 8   U   H   B   V   G   Y   7
     |
    2| 6   T   F   C   X   D   R   5
     |
    1| 4   E   S   Z   LSH A   W   3      LSH=Should be Left-SHIFT
     |
    0| 2   Q   CBM SPC STP CTL LA  1      LA=Left Arrow, CTL=Should be CTRL, STP=RUN/STOP
     |                                    CBM=Commodore key

  C64/VIC20 Keyboard Layout

    LA  1  2  3  4  5  6  7  8  9  0  +  -  BP HOM DEL    F1
    CTRL Q  W  E  R  T  Y  U  I  O  P  @  *  UA RESTORE   F3
  STOP SL A  S  D  F  G  H  J  K  L  :  ;  =  RETURN      F5
  C= SHIFT Z  X  C  V  B  N  M  ,  .  /  SHIFT  CDN CRT   F7
           [        SPACE BAR       ]

  Keyboard Connector
  Pin  Desc.
  1    Ground
  2    [key]
  3    RESTORE key
  4    +5 volts
  5    Column 7, Joy 3
  6    Column 6
  7    Column 5
  8    Column 4
  9    Column 3, Tape Write(E5)
  10   Column 2
  11   Column 1
  12   Column 0
  13   Row 7
  14   Row 6
  15   Row 5
  16   Row 4
  17   Row 3
  18   Row 2
  19   Row 1
  20   Row 0
}
  KEY_TRANSLATION = '2'+'q'+#00+' '+#27+#00+#00+'1'+  // $00..$07  0
                    '4'+'e'+'s'+'z'+#00+'a'+'w'+'3'+  // $08..$0f
                    '6'+'t'+'f'+'c'+'x'+'d'+'r'+'5'+  // $10..$17
                    '8'+'u'+'h'+'b'+'v'+'g'+'y'+'7'+  // $18..$1f
                    '0'+'o'+'k'+'m'+'n'+'j'+'i'+'9'+  // $20..$27
                    '-'+'@'+':'+'.'+','+'l'+'p'+'+'+  // $28..$2f

                    #00+#00+'='+#00+'/'+';'+'*'+#00+  // $30..$37 // '£' is not working
                    #00+#00+#00+#00+#00+#00+#13+#08+  // $38..$3f  63

                    '"'+#00+#00+#00+#00+#00+#00+'!'+  // $40..$47  64
                    '$'+#00+#00+#00+#00+#00+#00+'#'+  // $48..$4f
                    '&'+#00+#00+#00+#00+#00+#00+'%'+  // $50..$57
                    '('+#00+#00+#00+#00+#00+#00+''''+ // $58..$5f
                    '0'+#00+#00+#00+#00+#00+#00+')'+  // $60..$67
                    '_'+#00+'['+'>'+'<'+'l'+#00+#00+  // $68..$6f
                    #00+#00+'='+#00+'?'+']'+#00+#00+  // $70..$77
                    #00+#00+#00+#00+#00+#00+#13+#08;  // $78..$7f  127

  // Some consts for the timer
  // PAL
  SYS_FREQ_PAL = 4.433618e6 / 4.0; // PAL Frequency 4.433618 MHz => 1.108405 MHz => Clk Period 0.902197e-6 s
  // VIA Timer Register Addr $9125, $9124, see memory $FE3E... LDA #$26 and $FE43 LDA #$48 => $4826 = 18470 => 16,6635 ms => 1/60.01s
  // NTSC
  SYS_FREQ_NTSC = 14.318180e6 / 14.0; // NTSC Frequency 14.318180 MHz => 1.022727 MHz => Clk Period 0.9777779e-6 s
  // VIA Timer register Addr $9125, $9124, see memory $FE3E... LDA #$89 and $FE43 LDA #$42 => $4289 = 17033 => 16.6545 ms => 1/60.04s

type
  TVC20 = class;

  TVC20Thread = class(TThread)
  private
    VC20: TVC20;
    FAvgIRQPeriod : Single;
    FAvgSysTime6502EmulationRatio : Single;
  protected
    // Average time in Microseconds between two timer interrups
    property AvgIRQPeriod : Single read FAvgIRQPeriod;
    // Average ratio between the consumed time by the system and the emulation.
    // E.g. a value of 0.3 means that the system uses 30% of the time to emulate the VIC and 70% to wait.
    property AvgSysTime6502EmulationRatio : Single read FAvgSysTime6502EmulationRatio;
  public
    procedure Execute; override;
    constructor Create(VC20Instance: TVC20);
  end;

  TVC20MemKind = (mkUnimplemented,mkRAM,mkRegister,mkROM);
  TV20MemRange = record
    MemKind : TVC20MemKind;
    MemStartAddr : Word;
    MemStopAddr : Word;
    MemDescr : String;
  end;
  TV20MemRangeArr = array of TV20MemRange;

  TVC20SystemFreqKind = (fkNTSC, fkPAL);

  { TVC20 }

  TVC20 = class(TMOS6502)
  private
    Thread: TVC20Thread;
    {$IFDEF USE_THREADEDTIMERSIMULATION}
    IRQCycleLowByte : Byte; // The low byte written to the VIA
    IRQCycleCnt : Word; // The actual value used by the VIA
    {$ELSE}
    TimerHandle: Integer;
    {$ENDIF}
    LastKey: Char;
    FMemoryMap : TV20MemRangeArr;
    FCPU6502Freq : Double;
    FCPU6502CyclePeriodUs : Double;
    procedure OnBusWrite(Adr: Word; Value: Byte);
    function OnBusRead(Adr: Word): Byte;
    function KeyRead: Byte;
    function GetMemKind(AMemAddr : Word) : TVC20MemKind;
  protected
    KeyMatrix: Array[0 .. 7, 0 .. 7] of Byte;
    Memory: array of Byte;
    InterruptRequest: Boolean;
    procedure SetupMemoryMap;virtual;
    function GetMemoryMapItemCount : Integer;
    function GetMemoryMapItems(Index : Integer) : TV20MemRange;
    function GetMemoryMapKinds(Index : Integer) : TVC20MemKind;
    procedure SetMemoryMapKinds(Index : Integer; Value : TVC20MemKind);
  public
    WndHandle: THandle;
    property MemKind[AMemAddr : Word] : TVC20MemKind read GetMemKind;
    property MemoryMapItemCount : Integer read GetMemoryMapItemCount;
    property MemoryMapItems[Index : Integer] : TV20MemRange read GetMemoryMapItems;
    property MemoryMapKinds[Index : Integer] : TVC20MemKind read GetMemoryMapKinds write SetMemoryMapKinds;
    constructor Create(const ASysFreqKind : TVC20SystemFreqKind = fkNTSC);
    destructor Destroy; override;
    procedure LoadROM(Filename: String; Addr: Word);
    procedure SetSysFreq(const ASysFreqKind : TVC20SystemFreqKind);
    procedure Add3KRAMExt;
    procedure Exec;
    procedure SetKey(Key: Char; Value: Byte);
  end;

implementation

uses
{$IFnDEF FPC}
  Winapi.Windows, System.SysUtils {$IFnDEF USE_THREADEDTIMERSIMULATION}, WinApi.MMSystem{$ENDIF};
{$ELSE}
  SysUtils {$IFnDEF USE_THREADEDTIMERSIMULATION},MMSystem{$ENDIF};
{$ENDIF}



{ TVC20 }
{$IFnDEF USE_THREADEDTIMERSIMULATION}
procedure TimerProcedure(TimerID, Msg: Uint; dwUser, dw1, dw2: DWORD_PTR);pascal;
var
  VC20: TVC20;
begin
  VC20 := TVC20(dwUser);

  if VC20.Status and INTERRUPT_FLAG = 0 then // if IRQ allowed then set irq
    VC20.InterruptRequest := True;
end;
{$ENDIF}

function TVC20.OnBusRead(Adr: Word): Byte;
var
  memk : TVC20MemKind;
begin
  Result := Memory[Adr];
  memk := MemKind[Adr];
  if memk = mkUnimplemented then
    Result := $FF;
end;
procedure TVC20.OnBusWrite(Adr: Word; Value: Byte);
var
  memk : TVC20MemKind;
begin
  memk := MemKind[Adr];

  // test for I/O requests
  case Adr of
    CIA1:
      begin
        memk := MemKind[Adr];

        // Handle keyboard reading
        Memory[Adr] := Value;
        Memory[CIA1 + 1] := KeyRead;
      end;

    {$IFDEF USE_THREADEDTIMERSIMULATION}
    CIA1 + 4: // Timer1 latch lowbyte
      IRQCycleLowByte := Value;
    {$ENDIF}
    CIA1 + 5: // Timer1 latch highbyte
      {$IFDEF USE_THREADEDTIMERSIMULATION}
      IRQCycleCnt := (Value shl 8) or IRQCycleLowByte;
      {$ELSE}
      if TimerHandle = 0 then
        TimerHandle := TimeSetEvent(IRQ_CLK_MS_ROUND, 1, @TimerProcedure, DWORD_PTR(Self), TIME_PERIODIC);
      {$ENDIF}
  end;

  if (memk = mkROM) or
     (memk = mkUnimplemented) then
    Exit;

  Memory[Adr] := Value;

  // video RAM
  if (Adr >= $1E00) and (Adr <= $1FF9) then   // $400 - $07E7
    PostMessage(WndHandle, WM_SCREEN_WRITE, Adr - $1E00, Value);  // $400
end;

constructor TVC20.Create(const ASysFreqKind: TVC20SystemFreqKind);
begin
  inherited Create(OnBusRead, OnBusWrite);
  SetSysFreq(ASysFreqKind);
  // create 64kB memory table
  SetLength(Memory, 65536);

  SetupMemoryMap;

  Thread := TVC20Thread.Create(Self);
end;

destructor TVC20.Destroy;
begin
  {$IFnDEF USE_THREADEDTIMERSIMULATION}
  if TimerHandle <> 0 then
     Timekillevent(TimerHandle);
  {$ENDIF}

  Thread.Terminate;
  Thread.Suspended := False;
  Thread.WaitFor;
  Thread.Free;
  SetLength(Memory,0);
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
  begin
    if Cols and (1 shl Col) = 0 then  // a 0 indicates a column read
    begin
      for Row := 0 to 7 do
      begin
        if KeyMatrix[7 - Col, Row] = 1 then
          Result := Result + (1 shl Row);
      end;
    end;
  end;
  Result := not Result;
end;

function TVC20.GetMemKind(AMemAddr: Word): TVC20MemKind;
var
  i : Integer;
begin
  Result := mkUnimplemented;
  for i := 0 to High(FMemoryMap) do
  begin
    if (AMemAddr >= FMemoryMap[i].MemStartAddr) and (AMemAddr <= FMemoryMap[i].MemStopAddr) then
    begin
      Result := FMemoryMap[i].MemKind;
      Exit;
    end;
  end;
end;

procedure TVC20.SetupMemoryMap;
begin
  SetLength(FMemoryMap,15);
  // 0000-03FF 0-1023 ZERO_FLAG Page, 1K Ram
  FMemoryMap[0].MemDescr:= 'ZERO - System Variables';
  FMemoryMap[0].MemKind:= mkRAM;
  FMemoryMap[0].MemStartAddr:= $0000;
  FMemoryMap[0].MemStopAddr:=  $03FF;
  // 0400-0FFF 1024-4095 Optional 3K Extension, 3K
  FMemoryMap[1].MemDescr:= 'EXT2K - Expansion';
  FMemoryMap[1].MemKind:= mkUnimplemented;
  FMemoryMap[1].MemStartAddr:= $0400;
  FMemoryMap[1].MemStopAddr:=  $0FFF;
  // 1000-1DFF 4096-7679 Default User Basic memory, 3584 Bytes
  FMemoryMap[2].MemDescr:= 'BASICUSR - Default Basic Mem';
  FMemoryMap[2].MemKind:= mkRAM;
  FMemoryMap[2].MemStartAddr:= $1000;
  FMemoryMap[2].MemStopAddr:=  $1DFF;
  // 1E00-1FFF 7680-8191 Default Screen Memory, 512 Bytes (used 22*23 = 506)
  FMemoryMap[3].MemDescr:= 'SCREEN - Screen Mem';
  FMemoryMap[3].MemKind:= mkRAM;
  FMemoryMap[3].MemStartAddr:= $1E00;
  FMemoryMap[3].MemStopAddr:=  $1FFF;
  // 2000-3FFF 	8192-16383 BLK 1 – 8K expansion RAM/ROM block 1
  FMemoryMap[4].MemDescr:= 'BLK1 - 8K Optional RAM/ROM';
  FMemoryMap[4].MemKind:= mkUnimplemented;
  FMemoryMap[4].MemStartAddr:= $2000;
  FMemoryMap[4].MemStopAddr:=  $3FFF;
  // 4000-5FFF 	16384-24575 BLK 2 – 8K expansion RAM/ROM block 2
  FMemoryMap[5].MemDescr:= 'BLK2 - 8K Optional RAM/ROM';
  FMemoryMap[5].MemKind:= mkUnimplemented;
  FMemoryMap[5].MemStartAddr:= $4000;
  FMemoryMap[5].MemStopAddr:=  $5FFF;
  // 6000-7FFF 	24576-32767 BLK 3 – 8K expansion RAM/ROM block 3
  FMemoryMap[6].MemDescr:= 'BLK3 - 8K Optional RAM/ROM';
  FMemoryMap[6].MemKind:= mkUnimplemented;
  FMemoryMap[6].MemStartAddr:= $6000;
  FMemoryMap[6].MemStopAddr:=  $7FFF;
  // 8000-8FFF 	32768-36863 4K Character generator ROM
  FMemoryMap[7].MemDescr:= 'CHARACTER - 4K ROM';
  FMemoryMap[7].MemKind:= mkUnimplemented;
  FMemoryMap[7].MemStartAddr:= $8000;
  FMemoryMap[7].MemStopAddr:=  $8FFF;
  // 9000-93FF 	36864-37887 	I/O BLOCK 0 (VIC, VIA)
  FMemoryMap[8].MemDescr:= 'IOBLK0 - VIC, VIA';
  FMemoryMap[8].MemKind:= mkRegister;
  FMemoryMap[8].MemStartAddr:= $9000;
  FMemoryMap[8].MemStopAddr:=  $93FF;
  // 9400-97FF 	37888-38911 	I/O BLOCK 1 (COLOR Nibbles)
  FMemoryMap[9].MemDescr:= 'IOBLK1 - Color Nibbles';
  FMemoryMap[9].MemKind:= mkRAM;
  FMemoryMap[9].MemStartAddr:= $9400;
  FMemoryMap[9].MemStopAddr:=  $97FF;
  // 9800-9BFF 	38912-39935 	I/O BLOCK 2
  FMemoryMap[10].MemDescr:= 'IOBLK2';
  FMemoryMap[10].MemKind:= mkUnimplemented;
  FMemoryMap[10].MemStartAddr:= $9800;
  FMemoryMap[10].MemStopAddr:=  $9BFF;
  // 9C00-9FFF 	39936-40959 	I/O BLOCK 3
  FMemoryMap[11].MemDescr:= 'IOBLK3';
  FMemoryMap[11].MemKind:= mkUnimplemented;
  FMemoryMap[11].MemStartAddr:= $9C00;
  FMemoryMap[11].MemStopAddr:=  $9FFF;
  // A000-BFFF 	40960-49152 	BLK 4 – ROM expansion (cartridges)
  FMemoryMap[12].MemDescr:= 'BLK4 - 8K Optional ROM';
  FMemoryMap[12].MemKind:= mkUnimplemented;
  FMemoryMap[12].MemStartAddr:= $A000;
  FMemoryMap[12].MemStopAddr:=  $BFFF;
  // C000-DFFF 149152-57343 	BASIC – 8K ROM
  FMemoryMap[13].MemDescr:= 'BASICSYS – 8K ROM';
  FMemoryMap[13].MemKind:= mkUnimplemented; // Will be set to mkROM in the LoadROM method
  FMemoryMap[13].MemStartAddr:= $C000;
  FMemoryMap[13].MemStopAddr:=  $DFFF;
  // E000-FFFF 157344-65535 	KERNAL – 8K ROM
  FMemoryMap[14].MemDescr:= 'KERNAL – 8K ROM'; // Will be set to mkROM in the LoadROM method
  FMemoryMap[14].MemKind:= mkUnimplemented;
  FMemoryMap[14].MemStartAddr:= $E000;
  FMemoryMap[14].MemStopAddr:=  $FFFF;
end;

function TVC20.GetMemoryMapItemCount: Integer;
begin
  Result := Length(FMemoryMap);
end;

function TVC20.GetMemoryMapItems(Index: Integer): TV20MemRange;
begin
  Result := FMemoryMap[Index];
end;

function TVC20.GetMemoryMapKinds(Index: Integer): TVC20MemKind;
begin
  Result := FMemoryMap[Index].MemKind;
end;

procedure TVC20.SetMemoryMapKinds(Index: Integer; Value: TVC20MemKind);
begin
  FMemoryMap[Index].MemKind := Value;
end;

procedure TVC20.LoadROM(Filename: String; Addr: Word);
var
  Stream: TFileStream;
  i : Integer;
  addrstop : Word;
begin
  Stream := TFileStream.Create(Filename, fmOpenRead);
  try
    Stream.Read(Memory[Addr], Stream.Size);
    addrstop := Addr+Stream.Size-1;
    for i := 0 to High(FMemoryMap) do
    begin
      if (FMemoryMap[i].MemStartAddr = Addr) and
         (FMemoryMap[i].MemStopAddr = addrstop) then
      begin
        FMemoryMap[i].MemKind:= mkROM;
        Break;
      end;
    end;
  finally
    Stream.Free;
  end;
end;

procedure TVC20.SetSysFreq(const ASysFreqKind: TVC20SystemFreqKind);
var
  d : Double;
begin
  case ASysFreqKind of
    fkPAL : FCPU6502Freq := SYS_FREQ_PAL; // // PAL Frequency 4.433 MHz / 4
  else
    // fkNTSC
    FCPU6502Freq := SYS_FREQ_NTSC; // NTSC Frequency  14.318180 MHz / 14
  end;
  FCPU6502CyclePeriodUs := 1.0/FCPU6502Freq*1e6;
end;

procedure TVC20.Add3KRAMExt;
var
  i : Integer;
begin
  for i := 0 to High(FMemoryMap) do
  begin
    if (FMemoryMap[i].MemStartAddr = $0400)  then
    begin
      FMemoryMap[i].MemKind:= mkRAM;
      Break;
    end;
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
  function MicroSecondsFromTick(const ATick, AFreq : TLargeInteger) : Double;inline;
  begin
    Result := (ATick * 1000000) / AFreq; // convert the Tick into microsecs
  end;

var
  lastCycle, curCycle : Int64; // the 6502 CPU Cycle before and after execution
  {$IFDEF USE_THREADEDTIMERSIMULATION}
  lastIRQCycle : Int64;
  {$ENDIF}
  sysFreq : TLargeInteger; // the CPU frequency of the running system (assumed as static!)
  // The Ticks from the system
  lastSysTick, curSysTick: TLargeInteger;
  runTimeSysInUs, runTime6502InUs, deltaRunTimeInUs : Double;
  curIRQTick, lastIRQTick : TLargeInteger;
  d : Double;
begin
  try
    Priority := tpTimeCritical;
    FAvgSysTime6502EmulationRatio := 0.3; // Assuming that the system uses 30% to emulate and 70% to wait
    FAvgIRQPeriod := 16667.0;
    curSysTick := 0;
    sysFreq := 0;
    lastSysTick := 0;
    QueryPerformanceFrequency(sysFreq);
    QueryPerformanceCounter(lastSysTick);
    lastCycle := VC20.Cycles;
    {$IFDEF USE_THREADEDTIMERSIMULATION}lastIRQCycle := 0;{$ENDIF}

    curIRQTick := 0;
    lastIRQTick := 0;


    while (not Terminated) do
    begin
      // If the IRQ-Flag is set
      if VC20.InterruptRequest then
      begin
        // Measure the time between two IRQa
        curIRQTick := curSysTick;
        if lastIRQTick > 0 then
        begin
          d := MicroSecondsFromTick(curIRQTick-lastIRQTick,sysFreq);
          FAvgIRQPeriod := (FAvgIRQPeriod*0.99)+(d*(1.0-0.99));
        end;
        lastIRQTick := curIRQTick;
        // Reset the IRQ-Flag and proceed with the IRQ
        VC20.InterruptRequest := False;
        VC20.IRQ;
      end;
      VC20.Step; // Process one Command
      curCycle := VC20.Cycles; // save current Cycle counter
      Sleep(0); // Let other Tasks proceed
      QueryPerformanceCounter(curSysTick); // get the tick after the execution an the sleep(0)

      // Condiditional compiling, use internal stepper to simulate the VIA timer
      // This will give a better overall performance of the IRQ.
      // The IRQ is executed much closer to the real step as if fired from outside.
      // It allows the 6502 program to change the VIA Timer
      {$IFDEF USE_THREADEDTIMERSIMULATION}
      if ((VC20.Memory[CIA1 + $B] and $40) <> 0) and  // Timer enabled
         (VC20.IRQCycleCnt <> 0) then                 // Timer value set
      begin
        if (curCycle - lastIRQCycle) >= VC20.IRQCycleCnt then
        begin
          lastIRQCycle := curCycle;
          if ((VC20.Status and INTERRUPT_FLAG) = 0) then // if IRQ allowed then set irq
            VC20.InterruptRequest := True;
        end;
      end
      else // Timer disabled
      begin
        lastIRQCycle := curCycle;
      end;
      {$ENDIF}

      // Timing.
      // We assume that the emulation is faster than the original VIC-20.
      // (If not, we are lost anyway).
      // There are two options. One is to burn CPU time by adding some microseconds
      // after each step. This may double or more the CPU load.
      // The second option, which is implemented here, is to execute a number of
      // 6502-Cycles as fast as the emulation does until the emulation is
      // 10ms behind the running system (PC clock) and than burn the time with
      // System-sleep commands.

      runTimeSysInUs := MicroSecondsFromTick(curSysTick-lastSysTick,sysFreq); // consumed time in microsecs of the system
      runTime6502InUs := (curCycle - lastCycle) * VC20.FCPU6502CyclePeriodUs; // calculate the micro seconds in the 6502 CPU
      deltaRunTimeInUs := runTime6502InUs-runTimeSysInUs; // calculate the delta between the expected runTime6502InUs and the real runTimeSysInUs
      // If the system is running faster than the emulated 6502 than we have to wait.
      // If the system is running slower, than everything is lost here. But if we
      // stop in the debugger, this might be happen. You may than see a very fast blinking
      // cursor, until the system catch up with 6502 time.
      // The used timing is a bit experimental.
      // It would be nicer and smoother to have a shorter "ahead of time" difference. E.g. 1ms
      // But this would lead into the situation, that the actual wait call, which is
      // fairly unprecise, will jitter the whole system.
      // Thus we wait until we have 50ms ahead, but just to wait until we are somewhere between
      // 10ms and 0ms ahead.
      // The actual delay here will be than around 40ms.
      if (deltaRunTimeInUs > 50*1000) then
      begin // there is at least 50 Millisec to wait
        // track the ratio between the time from the system and the emulation
        FAvgSysTime6502EmulationRatio := (FAvgSysTime6502EmulationRatio * 0.99) + ((runTimeSysInUs / runTime6502InUs) * (1.0-0.99));
        repeat
          Sleep(5); // Sleep a while, let other threads do their job.
          // Now, calculate the consumed time and increase the Systems Runtime
          // until it reaches the 6502 Time
          QueryPerformanceCounter(curSysTick); // get the tick after the execution an the sleep(0)
          runTimeSysInUs := MicroSecondsFromTick(curSysTick-lastSysTick,sysFreq); // consumed time in microsecs
          deltaRunTimeInUs := runTime6502InUs-runTimeSysInUs; // calculate the delta between the expected runTimeSysInUs and the real runTimeSysInUs
        until (deltaRunTimeInUs <= (10*1000));
        lastSysTick := curSysTick; // Set the lasttick to the current tick, as base point for the next measurement
        lastCycle := Round(curCycle - (deltaRunTimeInUs * VC20.FCPU6502CyclePeriodUs)); // set the lastCycle to the assumed one
      end;
    end;
  finally
    // Make sure that the threads execute method is never left in non terminated state
    if not Terminated then
      Terminate;
  end;
end;

end.
