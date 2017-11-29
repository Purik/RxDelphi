unit Rx.Observable.AdvancedOps;

interface
uses Rx, Rx.Implementations, Rx.Subjects, Rx.Observable.Map,
  Generics.Collections, Generics.Defaults, SyncObjs;


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

  TGroupByObservable<X, Y> = class(TObservableImpl<X>, IObservable<IObservable<Y>>)
  type
    TDict = TDictionary<TSmartVariable<Y>, IObservable<Y>>;
  strict private
    FHashMap: TDict;
    FMapper: Rx.TMap<X, Y>;
    FMapperStatic: Rx.TMapStatic<X, Y>;
    FDest: TPublishSubject<IObservable<Y>>;
    FLock: TCriticalSection;
    procedure OnDestSubscribe(Subscriber: IObserver<IObservable<Y>>);
    procedure OnDestSubscribe2(Subscriber: IObserver<Y>);
  protected
    property HashMap: TDict read FHashMap;
    procedure Lock;
    procedure Unlock;
    function RoutineDecorator(const Data: X): IObservable<Y>; dynamic;
  public
    constructor Create(Source: IObservable<X>; const Mapper: Rx.TMap<X, Y>);
    constructor CreateStatic(Source: IObservable<X>; const Mapper: Rx.TMapStatic<X, Y>);
    destructor Destroy; override;
    function Subscribe(const OnNext: TOnNext<IObservable<Y>>): ISubscription; overload;
    function Subscribe(const OnNext: TOnNext<IObservable<Y>>; const OnError: TOnError): ISubscription; overload;
    function Subscribe(const OnNext: TOnNext<IObservable<Y>>; const OnError: TOnError; const OnCompleted: TOnCompleted): ISubscription; overload;
    function Subscribe(const OnNext: TOnNext<IObservable<Y>>; const OnCompleted: TOnCompleted): ISubscription; overload;
    function Subscribe(const OnError: TOnError): ISubscription; overload;
    function Subscribe(const OnCompleted: TOnCompleted): ISubscription; overload;
    function Subscribe(A: ISubscriber<IObservable<Y>>): ISubscription; overload;
    procedure OnNext(const Data: IObservable<Y>); reintroduce; overload;
    procedure OnNext(const Data: X); overload; override;
    procedure OnError(E: IThrowable); override;
    procedure OnCompleted; override;
  end;

  TOnceGroupSubscriber<X, Y> = class(TOnceSubscriber<X, Y>)
  public
    procedure OnNext(const A: X); override;
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

{ TGroupByObservable<X, Y> }

constructor TGroupByObservable<X, Y>.Create(Source: IObservable<X>;
  const Mapper: Rx.TMap<X, Y>);
begin
  inherited Create;
  FHashMap := TDict.Create;
  FDest := TPublishSubject<IObservable<Y>>.Create(OnDestSubscribe);
  inherited Merge(Source);
  FMapper := Mapper;
  FLock := TCriticalSection.Create;
end;

constructor TGroupByObservable<X, Y>.CreateStatic(Source: IObservable<X>;
  const Mapper: Rx.TMapStatic<X, Y>);
begin
  inherited Create;
  FHashMap := TDict.Create;
  FDest := TPublishSubject<IObservable<Y>>.Create(OnDestSubscribe);
  inherited Merge(Source);
  FMapperStatic := Mapper;
  FLock := TCriticalSection.Create;
end;

destructor TGroupByObservable<X, Y>.Destroy;
begin
  FHashMap.Free;
  FDest.Free;
  FLock.Free;
  inherited;
end;

procedure TGroupByObservable<X, Y>.Lock;
begin
  FLock.Acquire
end;

procedure TGroupByObservable<X, Y>.OnCompleted;
begin
  FDest.OnCompleted;
end;

procedure TGroupByObservable<X, Y>.OnDestSubscribe2(Subscriber: IObserver<Y>);
var
  Decorator: ISubscriber<X>;
begin
  // In case when Source is initialized by generator-base function manner
  // let it to run once
  Decorator := TOnceGroupSubscriber<X, Y>.Create(Subscriber, FMapper, FMapperStatic);
  try
    Inputs[0].GetObservable.Subscribe(Decorator)
  finally
    Decorator.Unsubscribe
  end;
end;

procedure TGroupByObservable<X, Y>.OnDestSubscribe(
  Subscriber: IObserver<IObservable<Y>>);
var
  Decorator: ISubscriber<X>;
begin
  // In case when Source is initialized by generator-base function manner
  // let it to run once
  Decorator := TOnceGroupSubscriber<X, IObservable<Y>>.Create(Subscriber, RoutineDecorator, nil);
  try
    Inputs[0].GetObservable.Subscribe(Decorator)
  finally
    Decorator.Unsubscribe
  end;
end;

procedure TGroupByObservable<X, Y>.OnError(E: IThrowable);
begin
  FDest.OnError(E);
end;

procedure TGroupByObservable<X, Y>.OnNext(const Data: X);
begin
  FDest.OnNext(RoutineDecorator(Data))
end;

function TGroupByObservable<X, Y>.RoutineDecorator(
  const Data: X): IObservable<Y>;
var
  Key: TSmartVariable<Y>;
begin

  if Assigned(FMapper) then
    Key := FMapper(Data)
  else
    Key := FMapperStatic(Data);

  Lock;
  try
    if FHashMap.ContainsKey(Key) then
      Result := nil
    else begin
      Result := TPublishSubject<Y>.Create(OnDestSubscribe2);
      FHashMap.Add(Key, Result);
    end
  finally
    Unlock
  end;
end;

procedure TGroupByObservable<X, Y>.OnNext(const Data: IObservable<Y>);
begin
  FDest.OnNext(Data)
end;

function TGroupByObservable<X, Y>.Subscribe(
  const OnNext: TOnNext<IObservable<Y>>;
  const OnError: TOnError): ISubscription;
begin
  Result := FDest.Subscribe(OnNext, OnError);
end;

function TGroupByObservable<X, Y>.Subscribe(
  const OnNext: TOnNext<IObservable<Y>>): ISubscription;
begin
  Result := FDest.Subscribe(OnNext);
end;

function TGroupByObservable<X, Y>.Subscribe(
  const OnCompleted: TOnCompleted): ISubscription;
begin
  Result := FDest.Subscribe(OnCompleted);
end;

function TGroupByObservable<X, Y>.Subscribe(
  A: ISubscriber<IObservable<Y>>): ISubscription;
begin
  Result := FDest.Subscribe(A);
end;

procedure TGroupByObservable<X, Y>.Unlock;
begin
  FLock.Release
end;

function TGroupByObservable<X, Y>.Subscribe(
  const OnError: TOnError): ISubscription;
begin
  Result := FDest.Subscribe(OnError);
end;

function TGroupByObservable<X, Y>.Subscribe(
  const OnNext: TOnNext<IObservable<Y>>; const OnError: TOnError;
  const OnCompleted: TOnCompleted): ISubscription;
begin
  Result := FDest.Subscribe(OnNext, OnError, OnCompleted);
end;

function TGroupByObservable<X, Y>.Subscribe(
  const OnNext: TOnNext<IObservable<Y>>;
  const OnCompleted: TOnCompleted): ISubscription;
begin
  Result := FDest.Subscribe(OnNext, OnCompleted);
end;

{ TOnceGroupSubscriber<X, Y> }

procedure TOnceGroupSubscriber<X, Y>.OnNext(const A: X);
var
  Ret: Y;
  O: IUnknown absolute Ret;
begin
  if not IsUnsubscribed then
    if Assigned(FRoutine) then
      Ret := FRoutine(A)
    else
      Ret := FRoutineStatic(A);
  if Assigned(O) then
    FSource.OnNext(Ret)
end;

end.
