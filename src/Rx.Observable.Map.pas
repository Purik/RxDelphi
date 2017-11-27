unit Rx.Observable.Map;

interface
uses Rx, Rx.Subjects, Rx.Implementations, SyncObjs, Generics.Collections;

type

  TMap<X, Y> = class(TObservableImpl<X>, IObservable<Y>)
  strict private
    FRoutine: Rx.TMap<X, Y>;
    FRoutineStatic: Rx.TMapStatic<X, Y>;
    FDest: TPublishSubject<Y>;
    procedure OnDestSubscribe(Subscriber: IObserver<Y>);
  protected
    function RoutineDecorator(const Data: X): Y; dynamic;
  public
    constructor Create(Source: IObservable<X>; const Routine: Rx.TMap<X, Y>);
    constructor CreateStatic(Source: IObservable<X>; const Routine: Rx.TMapStatic<X, Y>);
    destructor Destroy; override;
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

  TOnceSubscriber<X, Y> = class(TInterfacedObject, ISubscriber<X>)
  strict private
    FRoutine: Rx.TMap<X, Y>;
    FRoutineStatic: Rx.TMapStatic<X, Y>;
    FSource: IObserver<Y>;
  public
    constructor Create(Source: IObserver<Y>;
      const Routine: Rx.TMap<X, Y>; const RoutineStatic: Rx.TMapStatic<X, Y>);
    destructor Destroy; override;
    procedure OnNext(const A: X);
    procedure OnError(E: IThrowable);
    procedure OnCompleted;
    procedure Unsubscribe;
    function IsUnsubscribed: Boolean;
    procedure SetProducer(P: IProducer);
  end;

implementation


{ TMap<X, Y> }

constructor TMap<X, Y>.Create(Source: IObservable<X>;
  const Routine: Rx.TMap<X, Y>);
begin
  inherited Create;
  FDest := TPublishSubject<Y>.Create(OnDestSubscribe);
  inherited Merge(Source);
  FRoutine := Routine;
end;

constructor TMap<X, Y>.CreateStatic(Source: IObservable<X>;
  const Routine: Rx.TMapStatic<X, Y>);
begin
  inherited Create;
  FDest := TPublishSubject<Y>.Create(OnDestSubscribe);
  inherited Merge(Source);
  FRoutineStatic := Routine;
end;

destructor TMap<X, Y>.Destroy;
begin
  FDest.Free;
  inherited;
end;

procedure TMap<X, Y>.OnCompleted;
begin
  FDest.OnCompleted;
end;

procedure TMap<X, Y>.OnDestSubscribe(Subscriber: IObserver<Y>);
var
  Decorator: ISubscriber<X>;
begin
  // Если Source иниализирован через генератор-функцию, дадим возможность
  // ей отработать единожды
  Decorator := TOnceSubscriber<X, Y>.Create(Subscriber, RoutineDecorator, nil);
  try
    Inputs[0].GetObservable.Subscribe(Decorator)
  finally
    Decorator.Unsubscribe
  end;
end;

procedure TMap<X, Y>.OnError(E: IThrowable);
begin
  FDest.OnError(E);
end;

procedure TMap<X, Y>.OnNext(const Data: X);
begin
  FDest.OnNext(RoutineDecorator(Data))
end;

function TMap<X, Y>.RoutineDecorator(const Data: X): Y;
begin
  if Assigned(FRoutine) then
    Result := FRoutine(Data)
  else
    Result := FRoutineStatic(Data)
end;

procedure TMap<X, Y>.OnNext(const Data: Y);
begin
  FDest.OnNext(Data)
end;

function TMap<X, Y>.Subscribe(const OnNext: TOnNext<Y>; const OnError: TOnError;
  const OnCompleted: TOnCompleted): ISubscription;
begin
  Result := FDest.Subscribe(OnNext, OnError, OnCompleted);
end;

function TMap<X, Y>.Subscribe(const OnNext: TOnNext<Y>;
  const OnError: TOnError): ISubscription;
begin
  Result := FDest.Subscribe(OnNext, OnError);
end;

function TMap<X, Y>.Subscribe(const OnNext: TOnNext<Y>): ISubscription;
begin
  Result := FDest.Subscribe(OnNext);
end;

function TMap<X, Y>.Subscribe(const OnCompleted: TOnCompleted): ISubscription;
begin
  Result := FDest.Subscribe(OnCompleted);
end;

function TMap<X, Y>.Subscribe(A: ISubscriber<Y>): ISubscription;
begin
  Result := FDest.Subscribe(A);
end;

function TMap<X, Y>.Subscribe(const OnNext: TOnNext<Y>;
  const OnCompleted: TOnCompleted): ISubscription;
begin
  Result := FDest.Subscribe(OnNext, OnCompleted);
end;

function TMap<X, Y>.Subscribe(const OnError: TOnError): ISubscription;
begin
  Result := FDest.Subscribe(OnError);
end;

{ TOnceSubscriber<X, Y> }

constructor TOnceSubscriber<X, Y>.Create(Source: IObserver<Y>;
  const Routine: Rx.TMap<X, Y>; const RoutineStatic: Rx.TMapStatic<X, Y>);
begin
  FSource := Source;
  FRoutine := Routine;
  FRoutineStatic := RoutineStatic;
end;

destructor TOnceSubscriber<X, Y>.Destroy;
begin
  FSource := nil;
  inherited;
end;

function TOnceSubscriber<X, Y>.IsUnsubscribed: Boolean;
begin
  Result := FSource = nil
end;

procedure TOnceSubscriber<X, Y>.OnCompleted;
begin
  if not IsUnsubscribed then begin
    FSource.OnCompleted;
    Unsubscribe;
  end;
end;

procedure TOnceSubscriber<X, Y>.OnError(E: IThrowable);
begin
  if not IsUnsubscribed then begin
    FSource.OnError(E);
    Unsubscribe;
  end;
end;

procedure TOnceSubscriber<X, Y>.OnNext(const A: X);
begin
  if not IsUnsubscribed then
    if Assigned(FRoutine) then
      FSource.OnNext(FRoutine(A))
    else
      FSource.OnNext(FRoutineStatic(A))
end;

procedure TOnceSubscriber<X, Y>.SetProducer(P: IProducer);
begin
  // nothing
end;

procedure TOnceSubscriber<X, Y>.Unsubscribe;
begin
  FSource := nil;
end;

end.
