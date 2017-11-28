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
    FList: TSmartVariable<TSmartList>;
    FAction: TCollectAction1<ITEM, VALUE>;
  protected
    function RoutineDecorator(const Data: VALUE): TList; override;
  public
    constructor Create(Source: IObservable<VALUE>;
      const Initial: TSmartList; const Action: TCollectAction1<ITEM, VALUE>);
  end;

  TCollect2Observable<KEY, ITEM, VALUE> = class(TMap<VALUE, TDictionary<KEY, ITEM>>)
  type
    TDict = TDictionary<KEY, ITEM>;
    TSmartDict = TDictionary<KEY, TSmartVariable<ITEM>>;
  strict private
    FDict: TSmartVariable<TSmartDict>;
    FAction: TCollectAction2<KEY, ITEM, VALUE>;
  protected
    function RoutineDecorator(const Data: VALUE): TDict; override;
  public
    constructor Create(Source: IObservable<VALUE>;
      const Initial: TSmartDict; const Action: TCollectAction2<KEY, ITEM, VALUE>);
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
end;

function TCollect1Observable<ITEM, VALUE>.RoutineDecorator(
  const Data: VALUE): TList;
var
  I: Integer;
  NewList: TSmartList;
begin
  Result := TList.Create;
  for I := 0 to FList.Get.Count-1 do
    Result.Add(FList.Get[I]);
  FAction(Result, Data);
  NewList := TSmartList.Create;
  for I := 0 to Result.Count-1 do
    NewList.Add(Result[I]);
  FList := NewList;
end;

{ TCollect2Observable<KEY, ITEM, VALUE> }

constructor TCollect2Observable<KEY, ITEM, VALUE>.Create(
  Source: IObservable<VALUE>; const Initial: TSmartDict;
  const Action: TCollectAction2<KEY, ITEM, VALUE>);
begin
  inherited Create(Source, nil);
  FAction := Action;
  if Assigned(Initial) then
    FDict := Initial
  else
    FDict := TSmartDict.Create;
end;

function TCollect2Observable<KEY, ITEM, VALUE>.RoutineDecorator(
  const Data: VALUE): TDict;
var
  I: Integer;
  NewDict: TSmartDict;
  KV1: TPair<KEY, TSmartVariable<ITEM>>;
  KV2: TPair<KEY, ITEM>;
begin
  Result := TDict.Create;
  for KV1 in FDict.Get do begin
    Result.Add(KV1.Key, KV1.Value);
  end;
  FAction(Result, Data);
  NewDict := TSmartDict.Create;
  for KV2 in Result do begin
    NewDict.Add(KV2.Key, KV2.Value);
  end;
  FDict := NewDict;
end;

end.
