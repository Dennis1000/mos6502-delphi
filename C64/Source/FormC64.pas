unit FormC64;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, C64;

const
  ScreenZoom = 2;
  ScreenWidth = 320 * ScreenZoom;
  ScreenHeight = 200 * ScreenZoom;

  ColorTable: array [0 .. 2] of Cardinal = ($801010, $D0A0A0, $D0A0A0);

type
  TFrmC64 = class(TForm)
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
    C64: TC64;
  end;

var
  FrmC64: TFrmC64;

implementation

{$R *.dfm}

procedure TFrmC64.FormCreate(Sender: TObject);
begin
  ClientWidth := ScreenWidth;
  ClientHeight := ScreenHeight;

  Canvas.Font.Name := 'cbm';
  Canvas.Font.Height := 8 * ScreenZoom;
  Canvas.Brush.Style := bsSolid;

  C64 := TC64.Create;
  C64.WndHandle := Handle;
  C64.LoadROM('..\ROMs\basic.901226-01.bin', $A000);
  C64.LoadROM('..\ROMs\kernal.901227-03.bin', $E000);
  C64.Exec;
end;

procedure TFrmC64.FormDestroy(Sender: TObject);
begin
  C64.Free;
end;

procedure TFrmC64.FormKeyPress(Sender: TObject; var Key: Char);
begin
  C64.SetKey(Key, 1);
  LastKey := Key;
end;

procedure TFrmC64.FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if LastKey <> #0 then
    C64.SetKey(LastKey, 0);
  LastKey := #0;
end;

procedure TFrmC64.OnScreenWrite(var Msg: TMessage);
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

  Y := (Addr div 40);
  X := (Addr - Y*40);

  Flag := (Value shr 7) and $FF;
  Q1 := Value and $7F;
  Sc := Char((Q1 + 32 * (ord(Q1 < 32) * 2 + ord(Q1 > 63) + ord(Q1 > 95))));

  Canvas.Font.Color := ColorTable[1 - Flag];
  Canvas.Brush.Color := ColorTable[Flag];
  Canvas.TextOut(X * (8*ScreenZoom), Y * (8*ScreenZoom), Sc);
end;

end.
