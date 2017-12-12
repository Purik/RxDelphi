unit BaseTests;

interface
uses SysUtils, Classes, Generics.Collections;


type

  ETestError = class(EAbort)
  end;

  TLoggingObj = class(TObject)
  strict private
    FOnBeforeDestroy: TThreadProcedure;
  public
    constructor Create(const OnBeforeDestroy: TThreadProcedure);
    destructor Destroy; override;
  end;

  TLoggingObjDescendant = class(TLoggingObj)
  end;

  // Use class instance wrapper for detectong memory leaks
  TInteger = class
  private
    FValue: Integer;
  public
    constructor Create(Value: Integer);
    property Value: Integer read FValue write FValue;
  end;

function IsEqual(L: TList<string>; const Collection: array of string): Boolean;

implementation

{ TLoggingObj }

constructor TLoggingObj.Create(const OnBeforeDestroy: TThreadProcedure);
begin
  FOnBeforeDestroy := OnBeforeDestroy
end;

destructor TLoggingObj.Destroy;
begin
  FOnBeforeDestroy();
  inherited;
end;

{ TInteger }

constructor TInteger.Create(Value: Integer);
begin
  FValue := Value
end;

function IsEqual(L: TList<string>; const Collection: array of string): Boolean;
var
  I: Integer;
begin
  Result := L.Count = Length(Collection);
  if Result then
    for I := 0 to L.Count-1 do
      if L[I] <> Collection[I] then
        Exit(False)
end;

end.
