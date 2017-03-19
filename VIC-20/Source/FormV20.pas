unit FormV20;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, VIC20, Vcl.StdCtrls, Vcl.ExtCtrls;

const
  ScreenZoom = 2;
  ScreenWidth = 176 * ScreenZoom;   // 320
  ScreenHeight = 184 * ScreenZoom;  // 200

  ColorTable: array [0 .. 2] of Cardinal = ($801010, $D0A0A0, $D0A0A0);

type
  TFrmVC20 = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
    procedure OnScreenWrite(var Msg: TMessage); message WM_SCREEN_WRITE;
  public
    { Public declarations }
    LastKey: Char;
    VC20: TVC20;
  end;

var
  FrmVC20: TFrmVC20;

implementation

{$R *.dfm}

procedure TFrmVC20.FormCreate(Sender: TObject);
begin
  ClientWidth := ScreenWidth;
  ClientHeight := ScreenHeight;

  Canvas.Font.Name := 'cbm';
  Canvas.Font.Height := 8 * ScreenZoom;
  Canvas.Brush.Style := bsSolid;

  VC20 := TVC20.Create;
  VC20.WndHandle := Handle;
  VC20.LoadROM('..\ROMs\kernal.901486-06.bin', $E000); // E000-FFFF
  VC20.LoadROM('..\ROMs\basic.901486-01.bin', $C000); // C000-DFFF
  VC20.Exec;
end;

procedure TFrmVC20.FormDestroy(Sender: TObject);
begin
  VC20.Free;
end;

procedure TFrmVC20.FormKeyPress(Sender: TObject; var Key: Char);
begin
  VC20.SetKey(Key, 1);
  LastKey := Key;
end;

procedure TFrmVC20.FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if LastKey <> #0 then
    VC20.SetKey(LastKey, 0);
  LastKey := #0;
end;

procedure TFrmVC20.OnScreenWrite(var Msg: TMessage);
var
  Addr: Word;
  Value: Integer;
  X, Y: Integer;
  Flag: Cardinal;
  Q1: Byte;
  Sc: Char;
begin
  Addr := Msg.WParam;
  Value := Msg.LParam;

  Y := (Addr div 22); //40
  X := (Addr - Y*22); //40

  Flag := (Value shr 7) and $FF;
  Q1 := Value and $7F;
  Sc := Char((Q1 + 32 * (ord(Q1 < 32) * 2 + ord(Q1 > 63) + ord(Q1 > 95))));

  Canvas.Font.Color := ColorTable[1 - Flag];
  Canvas.Brush.Color := ColorTable[Flag];
  Canvas.TextOut(X * (8*ScreenZoom), Y * (8*ScreenZoom), Sc);
end;

end.
