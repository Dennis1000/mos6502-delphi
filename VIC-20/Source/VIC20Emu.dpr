program VIC20Emu;

uses
  Vcl.Forms,
  FormV20 in 'FormV20.pas' {FrmVC20},
  VIC20 in 'VIC20.pas',
  MOS6502 in '..\..\Source\MOS6502.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFrmVC20, FrmVC20);
  Application.Run;
end.
