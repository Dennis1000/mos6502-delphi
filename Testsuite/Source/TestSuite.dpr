program TestSuite;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.Classes, System.SysUtils,
  MOS6502 in '..\..\Source\MOS6502.pas';

type
  TMOS6502TestSuite = class(TMOS6502)
  protected
    procedure BusWrite(Adr: Word; Value: Byte);
    function BusRead(Adr: Word): Byte;
  public
    Memory: PByte;
    constructor Create;
    destructor Destroy; override;
    procedure RunTest(EndAddress: Word);
    procedure Load(Filename: String);
  end;

{ TMOS6502TestSuite }

function TMOS6502TestSuite.BusRead(Adr: Word): Byte;
begin
  Result := Memory[Adr];
end;

procedure TMOS6502TestSuite.BusWrite(Adr: Word; Value: Byte);
begin
  Memory[Adr] := Value;
end;

constructor TMOS6502TestSuite.Create;
begin
  inherited Create(BusRead, BusWrite);

  // create memory
  GetMem(Memory, 65536);
end;

destructor TMOS6502TestSuite.Destroy;
begin
  FreeMem(Memory);
  inherited;
end;


procedure TMOS6502TestSuite.Load(Filename: String);
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(Filename, fmOpenRead);
  Stream.Read(Memory[0], Stream.Size);
  Stream.Free;
end;

procedure TMOS6502TestSuite.RunTest(EndAddress: Word);
var
  LastPc: Word;
  LastTest: Byte;
begin
  // reset (jump to $0400)
  Reset;

  LastTest := $FF;
  repeat
    LastPc := Pc;
    if Memory[$200] <> LastTest then
    begin
      LastTest := Memory[$200];
      Writeln('test case ' + LastTest.ToString + ' at $' +IntToHex(Pc, 4));
    end;

    // Run 1 instruction
    Step;
  until (IllegalOpcode) or (Pc = LastPC) or (Pc = EndAddress);

  if Pc = EndAddress then
    writeln('test successful')
  else
    writeln('failed at ' + IntToHex(Pc, 4));
end;

var
  MOS6502: TMOS6502TestSuite;

begin
  try
    MOS6502 := TMOS6502TestSuite.Create;
    try
      // load test bin
      MOS6502.Load('..\Test-Files\6502_functional_test.bin');

      // set reset vectors to $0400
      MOS6502.Memory[$FFFC] := 0;
      MOS6502.Memory[$FFFD] := 4;


      // and run test suite, if PC reaches $3399 then test is successful
      MOS6502.RunTest($3399);

      Readln;

    finally
      MOS6502.Free;
    end;

  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.

