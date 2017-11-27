unit Rx.Observable.AdvancedOps;

interface
uses Rx, Rx.Implementations, Rx.Subjects, Rx.Observable.Map,
  Generics.Collections, Generics.Defaults;


type

  TScanObservable<CTX, T> = class(TMap<T, CTX>)
  strict private
    FContext: CTX;
    FContextHolder: TSmartVariable<CTX>;
    FScanRoutine: TScanRoutine<CTX, T>;
  protected
    function RoutineDecorator(const Data: T): CTX; override;
  public
    constructor Create(Source: IObservable<T>;
      const Initial: TSmartVariable<CTX>; const ScanRoutine: TScanRoutine<CTX, T>);
  end;

  TReduceObservable<ACCUM, T> = class(TMap<T, ACCUM>)
  strict private
    FAccum: TSmartVariable<ACCUM>;
    FReduceRoutine: TReduceRoutine<ACCUM, T>;
    FAccumIsEmpty: Boolean;
  protected
    function RoutineDecorator(const Data: T): ACCUM; override;
  public
    constructor Create(Source: IObservable<T>; const ReduceRoutine: TReduceRoutine<ACCUM, T>);
     procedure OnNext(const Data: T); override;
  end;

  TCollect1Observable<ITEM, VALUE> = class(TMap<VALUE, TList<ITEM>>)
  type
    TList = TList<ITEM>;
    TSmartList = TList<TSmartVariable<ITEM>>;
  strict private
    FList: TSmartList;
    FListHolder: TSmartVariable<TSmartList>;
    FAction: TCollectAction1<ITEM, VALUE>;
  protected
    function RoutineDecorator(const Data: VALUE): TList; override;
  public
    constructor Create(Source: IObservable<VALUE>;
      const Initial: TSmartList; const Action: TCollectAction1<ITEM, VALUE>);
  end;

implementation

{ TScanObservable<CTX, T> }

constructor TScanObservable<CTX, T>.Create(Source: IObservable<T>;
  const Initial: TSmartVariable<CTX>; const ScanRoutine: TScanRoutine<CTX, T>);
begin
  inherited Create(Source, nil);
  FScanRoutine := ScanRoutine;
  FContext := Initial;
  FContextHolder := FContext;
end;

function TScanObservable<CTX, T>.RoutineDecorator(const Data: T): CTX;
begin
  FScanRoutine(FContext, Data);
  Result := FContext;
end;


{ TReduceObservable<CTX, T> }

constructor TReduceObservable<ACCUM, T>.Create(Source: IObservable<T>;
  const ReduceRoutine: TReduceRoutine<ACCUM, T>);
begin
  inherited Create(Source, nil);
  FReduceRoutine := ReduceRoutine;
  FAccumIsEmpty := True;
end;

procedure TReduceObservable<ACCUM, T>.OnNext(const Data: T);
begin
 // inherited;

end;

function TReduceObservable<ACCUM, T>.RoutineDecorator(const Data: T): ACCUM;
begin
  FAccum := FReduceRoutine(FAccum, Data);
  Result := FAccum;
end;

{ TCollect1Observable<ITEM, VALUE> }

constructor TCollect1Observable<ITEM, VALUE>.Create(Source: IObservable<VALUE>;
  const Initial: TSmartList; const Action: TCollectAction1<ITEM, VALUE>);
begin
  inherited Create(Source, nil);
  FAction := Action;
  if Assigned(Initial) then
    FList := Initial
  else
    FList := TSmartList.Create;
  FListHolder := FList;
end;

function TCollect1Observable<ITEM, VALUE>.RoutineDecorator(
  const Data: VALUE): TList;
var
  I: Integer;
  NewList: TSmartList;
begin
  Result := TList.Create;
  for I := 0 to FList.Count-1 do
    Result.Add(FList[I]);
  FAction(Result, Data);
  NewList := TSmartList.Create;
  for I := 0 to Result.Count-1 do
    NewList.Add(Result[I]);
  FList := NewList;
end;

end.
