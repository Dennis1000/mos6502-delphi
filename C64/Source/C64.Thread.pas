unit C64.Thread;

interface

uses
  System.Classes, C64;

type
  TC64Thread = class(TThread)
  private
    C64: TC64;
  protected
  public
    procedure Execute; override;
    constructor Create(C64Instance: TC64);
    destructor Destroy; override;
  end;

implementation

{ TC64Thread }

constructor TC64Thread.Create(C64Instance: TC64);
begin
  inherited Create(True);
  C64 := C64Instance;
end;

destructor TC64Thread.Destroy;
begin

  inherited;
end;

procedure TC64Thread.Execute;
begin
  inherited;

end;

end.
