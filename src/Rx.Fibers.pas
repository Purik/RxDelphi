unit Rx.Fibers;

interface
uses Windows, SysUtils;

type

  TCustomFiber = class
  const
    STACK_SIZE = 1024;
  type
    AKill = class(EAbort);
  strict private
    FIsTerminated: Boolean;
    FIsRunned: Boolean;
    FContext: Pointer;
    FKill: Boolean;
    function GetRootContext: Pointer;
    class procedure FarCall(Param: Pointer); stdcall; static;
  protected
    procedure Execute; dynamic; abstract;
  public
    constructor Create;
    destructor Destroy; override;
    property IsTerminated: Boolean read FIsTerminated;
    procedure Invoke;
    procedure Yield;
    procedure Kill;
  end;

  TFiberRoutine = reference to procedure(Fiber: TCustomFiber);

  TFiber = class(TCustomFiber)
  strict private
    FRoutine: TFiberRoutine;
  protected
    procedure Execute; override;
  public
    constructor Create(const Routine: TFiberRoutine);
  end;

// used only for debugging!!!
procedure Yield;

implementation

threadvar
  CurThreadAsFiber: Pointer;

{ TCustomFiber }

constructor TCustomFiber.Create;
begin
  FContext := CreateFiber(STACK_SIZE, @FarCall, Self);
end;

destructor TCustomFiber.Destroy;
begin
  if not FIsTerminated and FIsRunned then
    Kill;
  if Assigned(FContext) then
    DeleteFiber(FContext);
  inherited;
end;

class procedure TCustomFiber.FarCall(Param: Pointer);
var
  Me: TCustomFiber;
begin
  Me := TCustomFiber(Param);
  try
    Me.FIsRunned := True;
    Me.Execute;
  finally
    Me.FIsTerminated := True;
    SwitchToFiber(CurThreadAsFiber);
  end;
end;

function TCustomFiber.GetRootContext: Pointer;
begin
  if CurThreadAsFiber = nil then
    CurThreadAsFiber := Pointer(ConvertThreadToFiber(nil));
  Result := CurThreadAsFiber;
end;

procedure TCustomFiber.Invoke;
begin
  GetRootContext;
  SwitchToFiber(FContext);
  if not FIsTerminated and FKill then
    raise AKill.Create('Killing');
end;

procedure TCustomFiber.Kill;
begin
  if not FIsTerminated then begin
    FKill := True;
    Invoke;
  end;
end;

procedure TCustomFiber.Yield;
begin
  SwitchToFiber(GetRootContext);
end;

{ TFiber }

constructor TFiber.Create(const Routine: TFiberRoutine);
begin
  inherited Create;
  FRoutine := Routine;
end;

procedure TFiber.Execute;
begin
  FRoutine(Self)
end;

procedure Yield;
begin
  SwitchToFiber(CurThreadAsFiber);
end;

end.
