unit Rx.Observable.FlatMap;

interface
uses Rx, SyncObjs, Rx.Subjects, Rx.Implementations, Generics.Collections;

type

  TConcurrencyCondVar = class
  strict private
    FCriSection: TCriticalSection;
    FCondVar: TConditionVariableCS;
    FLimit: Integer;
    FCurrent: Integer;
  public
    constructor Create(Limit: Integer);
    destructor Destroy; override;
    procedure Enter;
    procedure Leave;
    procedure SetLimit(Value: Integer);
  end;

  TFromConcurrentSbscriptionImpl<T> = class(TFromSbscriptionImpl<T>)
  type
    TOnNext = TOnNext<T>;
  strict private
    FConcurrency: TConcurrencyCondVar;
  public
    constructor Create(Observable: IObservable<T>; Concurrency: TConcurrencyCondVar;
      const OnNext: TOnNext=nil; const OnError: TOnError = nil;
      const OnCompleted: TOnCompleted=nil);
    procedure OnNext(const A: T); override;
  end;

  TInputSubscription<T> = class(TSubscriptionImpl, IFromSubscription<T>)
  type
    TOnNext = TOnNext<T>;
  strict private
    [Weak] FObservable: IObservable<T>;
    FOnNext: TOnNext;
    FOnError: TOnError;
    FConcurrency: TConcurrencyCondVar;
  protected
    procedure UnsubscribeInterceptor; override;
  public
    constructor Create(Observable: IObservable<T>; Concurrency: TConcurrencyCondVar;
      const OnNext: TOnNext=nil; const OnError: TOnError = nil);
    procedure Lock;
    procedure Unlock;
    procedure OnNext(const A: T);
    procedure OnError(E: IThrowable);
    procedure OnCompleted;
    function GetObservable: IObservable<T>;
  end;

  TFlatMap<X, Y> = class(TObservableImpl<X>, IObservable<Y>, IFlatMapObservable<X, Y>)
  type
    TFlatMap = Rx.TFlatMap<X,Y>;
    TFlatMapStatic = Rx.TFlatMapStatic<X,Y>;
    IFromYSubscription = IFromSubscription<Y>;
  strict private
    FStreams: TList<IObservable<Y>>;
    FSpawns: TList<TFlatMap>;
    FSpawnsStatic: TList<TFlatMapStatic>;
    FLock: TCriticalSection;
    FDest: TPublishSubject<Y>;
    FInputs: TList<IFromYSubscription>;
    FConcurrency: TConcurrencyCondVar;
    procedure OnDestSubscribe(Subscriber: IObserver<Y>);
    procedure OnInputError(E: IThrowable);
  public
    constructor Create(Source: IObservable<X>; const MaxConcurrent: Integer=0);
    destructor Destroy; override;
    procedure Spawn(const Routine: TFlatMap); overload;
    procedure Spawn(const Routine: TFlatMapStatic); overload;
    procedure SetMaxConcurrency(Value: Integer);
    function Subscribe(const OnNext: TOnNext<Y>): ISubscription; overload;
    function Subscribe(const OnNext: TOnNext<Y>; const OnError: TOnError): ISubscription; overload;
    function Subscribe(const OnNext: TOnNext<Y>; const OnError: TOnError; const OnCompleted: TOnCompleted): ISubscription; overload;
    function Subscribe(const OnNext: TOnNext<Y>; const OnCompleted: TOnCompleted): ISubscription; overload;
    function Subscribe(const OnError: TOnError): ISubscription; overload;
    function Subscribe(const OnCompleted: TOnCompleted): ISubscription; overload;
    function Subscribe(A: ISubscriber<Y>): ISubscription; overload;
    procedure OnNext(const Data: Y); reintroduce; overload;
    procedure OnNext(const Data: X); overload; override;
    procedure OnError(E: IThrowable); override;
    procedure OnCompleted; override;
  end;

  TFlatMapIterableImpl<T> = class(TFlatMap<T, T>, IFlatMapIterableObservable<T>)
  strict private
  class threadvar CurRoutine: TFlatMapIterable<T>;
  class threadvar CurRoutineStatic: TFlatMapIterableStatic<T>;
    function RoutineDecorator(const Data: T): IObservable<T>;
  public
    procedure Spawn(const Routine: TFlatMapIterable<T>); overload;
    procedure Spawn(const Routine: TFlatMapIterableStatic<T>); overload;
  end;

  TOnceSubscriber<X, Y> = class(TInterfacedObject, ISubscriber<X>)
  strict private
    FRoutine: Rx.TFlatMap<X, Y>;
    FStream: IObserver<Y>;
    FOnError: TOnError;
    FConcurrency: TConcurrencyCondVar;
    procedure OnYNext(const Data: Y);
  public
    constructor Create(Stream: IObserver<Y>; Concurrency: TConcurrencyCondVar;
      const Routine: Rx.TFlatMap<X, Y>);
    destructor Destroy; override;
    procedure OnNext(const A: X);
    procedure OnError(E: IThrowable);
    procedure OnCompleted;
    procedure Unsubscribe;
    function IsUnsubscribed: Boolean;
    procedure SetProducer(P: IProducer);
  end;

implementation
uses Rx.Observable.Map;

{ TFlatMap<X, Y> }

constructor TFlatMap<X, Y>.Create(Source: IObservable<X>; const MaxConcurrent: Integer);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FStreams := TList<IObservable<Y>>.Create;
  FSpawns := TList<TFlatMap>.Create;
  FSpawnsStatic := TList<TFlatMapStatic>.Create;
  FDest := TPublishSubject<Y>.Create(OnDestSubscribe);
  FInputs := TList<IFromYSubscription>.Create;
  FConcurrency := TConcurrencyCondVar.Create(MaxConcurrent);
  inherited Merge(Source);
end;

destructor TFlatMap<X, Y>.Destroy;
begin
  FStreams.Free;
  FSpawns.Free;
  FSpawnsStatic.Free;
  FInputs.Free;
  FDest.Free;
  FConcurrency.Free;
  FLock.Free;
  inherited;
end;

procedure TFlatMap<X, Y>.OnNext(const Data: Y);
begin
  // nothing
end;

procedure TFlatMap<X, Y>.OnCompleted;
begin
  FDest.OnCompleted
end;

procedure TFlatMap<X, Y>.OnDestSubscribe(Subscriber: IObserver<Y>);
var
  Decorator: ISubscriber<X>;
  Routine: Rx.TFlatMap<X,Y>;
begin
  for Routine in FSpawns do begin
    Decorator := TOnceSubscriber<X, Y>.Create(Subscriber, FConcurrency, Routine);
    try
      Inputs[0].GetObservable.Subscribe(Decorator)
    finally
      Decorator.Unsubscribe
    end;
  end;
end;

procedure TFlatMap<X, Y>.OnError(E: IThrowable);
begin
  FDest.OnError(E);
end;

procedure TFlatMap<X, Y>.OnInputError(E: IThrowable);
var
  Contract: TObservableImpl<Y>.IContract;
begin
  for Contract in FDest.Freeze do
    FDest.Scheduler.Invoke(TOnErrorAction<Y>.Create(E, Contract))
end;

procedure TFlatMap<X, Y>.OnNext(const Data: X);
var
  O: IObservable<Y>;
  Routine: TFlatMap;
  RoutineStatic: TFlatMapStatic;
  S: IFromYSubscription;
  I: Integer;
  List: TList<IObservable<Y>>;
begin
  List := TList<IObservable<Y>>.Create;
  try
    for Routine in FSpawns do begin
      O := Routine(Data);
      List.Add(O)
    end;
    for RoutineStatic in FSpawnsStatic do begin
      O := RoutineStatic(Data);
      List.Add(O)
    end;

    FLock.Acquire;
    try
      for O in List do begin
        if not FStreams.Contains(O) then begin
          S := TInputSubscription<Y>.Create(O, FConcurrency, FDest.OnNext, Self.OnInputError);
          FInputs.Add(S);
          O.Subscribe(S);
        end;
      end;
      for I := FInputs.Count-1 downto 0 do
        if FInputs[I].IsUnsubscribed then
          FInputs.Delete(I);
    finally
      FLock.Release;
    end;
  finally
    List.Free;
  end;
end;


procedure TFlatMap<X, Y>.Spawn(const Routine: TFlatMap);
begin
  FLock.Acquire;
  try
    FSpawns.Add(Routine)
  finally
    FLock.Release;
  end;
end;

function TFlatMap<X, Y>.Subscribe(const OnNext: TOnNext<Y>;
  const OnError: TOnError; const OnCompleted: TOnCompleted): ISubscription;
begin
  Result := FDest.Subscribe(OnNext, OnError, OnCompleted);
end;

function TFlatMap<X, Y>.Subscribe(const OnNext: TOnNext<Y>;
  const OnError: TOnError): ISubscription;
begin
  Result := FDest.Subscribe(OnNext, OnError);
end;

function TFlatMap<X, Y>.Subscribe(const OnNext: TOnNext<Y>): ISubscription;
begin
  Result := FDest.Subscribe(OnNext);
end;

function TFlatMap<X, Y>.Subscribe(const OnNext: TOnNext<Y>;
  const OnCompleted: TOnCompleted): ISubscription;
begin
  Result := FDest.Subscribe(OnNext, OnCompleted);
end;

procedure TFlatMap<X, Y>.SetMaxConcurrency(Value: Integer);
begin
  FConcurrency.SetLimit(Value);
end;

procedure TFlatMap<X, Y>.Spawn(const Routine: TFlatMapStatic);
begin
  FLock.Acquire;
  try
    FSpawnsStatic.Add(Routine)
  finally
    FLock.Release;
  end;
end;

function TFlatMap<X, Y>.Subscribe(A: ISubscriber<Y>): ISubscription;
begin
  Result := FDest.Subscribe(A);
end;

function TFlatMap<X, Y>.Subscribe(
  const OnCompleted: TOnCompleted): ISubscription;
begin
  Result := FDest.Subscribe(OnCompleted);
end;

function TFlatMap<X, Y>.Subscribe(const OnError: TOnError): ISubscription;
begin
  Result := FDest.Subscribe(OnError);
end;

{ TInputSubscription<T> }

constructor TInputSubscription<T>.Create(Observable: IObservable<T>;
  Concurrency: TConcurrencyCondVar; const OnNext: TOnNext; const OnError: TOnError);
begin
  inherited Create;
  FObservable := Observable;
  FOnNext := OnNext;
  FOnError := OnError;
  FConcurrency := Concurrency;
end;

function TInputSubscription<T>.GetObservable: IObservable<T>;
begin
  Lock;
  Result := FObservable;
  Unlock;
end;

procedure TInputSubscription<T>.Lock;
begin
  FLock.Acquire;
end;

procedure TInputSubscription<T>.OnCompleted;
begin
  Unsubscribe
end;

procedure TInputSubscription<T>.OnError(E: IThrowable);
begin
  Lock;
  try
    if not IsUnsubscribed and Assigned(FOnError) then begin
      FOnError(E);
      Unsubscribe;
    end;
  finally
    Unlock;
  end;
end;

procedure TInputSubscription<T>.OnNext(const A: T);
begin
  Lock;
  try
    if not IsUnsubscribed and Assigned(FOnNext) then begin
      FConcurrency.Enter;
      try
        FOnNext(A)
      finally
        FConcurrency.Leave;
      end;
    end;
  finally
    Unlock;
  end;
end;

procedure TInputSubscription<T>.Unlock;
begin
  FLock.Release;
end;

procedure TInputSubscription<T>.UnsubscribeInterceptor;
begin
  FObservable := nil;
end;

{ TFlatMapIterableImpl<T> }

function TFlatMapIterableImpl<T>.RoutineDecorator(
  const Data: T): IObservable<T>;
begin
  if Assigned(CurRoutine) then
    Result := CurRoutine(Data)
  else
    Result := CurRoutineStatic(Data)
end;

procedure TFlatMapIterableImpl<T>.Spawn(const Routine: TFlatMapIterable<T>);
begin
  CurRoutine := Routine;
  CurRoutineStatic := nil;
  inherited Spawn(RoutineDecorator)
end;

procedure TFlatMapIterableImpl<T>.Spawn(
  const Routine: TFlatMapIterableStatic<T>);
begin
  CurRoutine := nil;
  CurRoutineStatic := Routine;
  inherited Spawn(RoutineDecorator)
end;

{ TOnceSubscriber<X, Y> }

constructor TOnceSubscriber<X, Y>.Create(Stream: IObserver<Y>;
  Concurrency: TConcurrencyCondVar; const Routine: Rx.TFlatMap<X, Y>);
begin
  FRoutine := Routine;
  FStream := Stream;
  FConcurrency := Concurrency;
end;

destructor TOnceSubscriber<X, Y>.Destroy;
begin
  FStream := nil;
  inherited;
end;

function TOnceSubscriber<X, Y>.IsUnsubscribed: Boolean;
begin
  Result := FStream = nil
end;

procedure TOnceSubscriber<X, Y>.OnCompleted;
begin
  //Unsubscribe
end;

procedure TOnceSubscriber<X, Y>.OnError(E: IThrowable);
begin
  if not IsUnsubscribed and Assigned(FOnError) then begin
    FOnError(E);
    //Unsubscribe;
  end;
end;

procedure TOnceSubscriber<X, Y>.OnNext(const A: X);
var
  O: IObservable<Y>;
  InternalSubscr: IFromSubscription<Y>;
begin
  if not IsUnsubscribed then begin
    O := FRoutine(A);
    InternalSubscr := TFromConcurrentSbscriptionImpl<Y>.Create(O, FConcurrency,
      OnYNext, OnError, OnCompleted);
    try
      O.Subscribe(InternalSubscr)
    finally
      InternalSubscr.Unsubscribe;
    end;
  end;
end;

procedure TOnceSubscriber<X, Y>.OnYNext(const Data: Y);
begin
  FStream.OnNext(Data)
end;

procedure TOnceSubscriber<X, Y>.SetProducer(P: IProducer);
begin
  // nothing
end;

procedure TOnceSubscriber<X, Y>.Unsubscribe;
begin
  FStream := nil;
end;

{ TConcurrencyCondVar }

constructor TConcurrencyCondVar.Create(Limit: Integer);
begin
  FCriSection := TCriticalSection.Create;
  FCondVar := TConditionVariableCS.Create;
  FLimit := Limit
end;

destructor TConcurrencyCondVar.Destroy;
begin
  FCriSection.Free;
  FCondVar.Free;
  inherited;
end;

procedure TConcurrencyCondVar.Enter;
begin
  FCriSection.Acquire;
  if FLimit <= 0 then begin
    FCriSection.Release;
    Exit;
  end;
  if FCurrent < FLimit then begin
    Inc(FCurrent);
    FCriSection.Release;
    Exit;
  end
  else begin
    repeat
      FCondVar.WaitFor(FCriSection);
      FCriSection.Acquire;
    until FCurrent < FLimit;
    FCriSection.Release;
  end;
end;

procedure TConcurrencyCondVar.Leave;
begin
  FCriSection.Acquire;
  Dec(FCurrent);
  FCriSection.Release;
  FCondVar.Release;
end;

procedure TConcurrencyCondVar.SetLimit(Value: Integer);
var
  Grow: Integer;
begin
  FCriSection.Acquire;
  if Value = 0 then
    Grow := MaxInt
  else
    Grow := Value - FLimit;
  FLimit := Value;
  FCriSection.Release;
  if Grow > 0 then
    FCondVar.ReleaseAll;
end;

{ TFromConcurrentSbscriptionImpl<T> }

constructor TFromConcurrentSbscriptionImpl<T>.Create(Observable: IObservable<T>;
  Concurrency: TConcurrencyCondVar; const OnNext: TOnNext;
  const OnError: TOnError; const OnCompleted: TOnCompleted);
begin
  inherited Create(Observable, OnNext, OnError, OnCompleted);
  FConcurrency := Concurrency;
end;

procedure TFromConcurrentSbscriptionImpl<T>.OnNext(const A: T);
begin
  FConcurrency.Enter;
  try
    inherited;
  finally
    FConcurrency.Leave;
  end;
end;

end.
