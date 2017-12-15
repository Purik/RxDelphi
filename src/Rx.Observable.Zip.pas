unit Rx.Observable.Zip;

interface
uses SyncObjs, Rx, Rx.Subjects, Generics.Collections, Rx.Implementations,
  Rx.Fibers;

type

  TInterceptor<T> = class(TObservableImpl<T>)
  private
    FOnNextIntercept: TOnNext<T>;
    FOnErrorIntercept: TOnError;
    FOnCompletedIntercept: TOnCompleted;
  public
    procedure OnNext(const Data: T); override;
    procedure OnError(E: IThrowable); override;
    procedure OnCompleted; override;
  end;

  IJoinStrategy<X, Y> = interface
    function OnNext(const Left: X): TZip<X, Y>; overload;
    function OnNext(const Right: Y): TZip<X, Y>; overload;
    function OnCompletedLeft: Boolean;
    function OnCompletedRight: Boolean;
    function OnErrorLeft(Error: IThrowable): Boolean;
    function OnErrorRight(Error: IThrowable): Boolean;
  end;

  TJoinStrategy<X, Y> = class(TInterfacedObject, IJoinStrategy<X, Y>)
  strict private
    FCompletedLeft: Boolean;
    FCompletedRight: Boolean;
    FError: IThrowable;
  protected
    property CompletedLeft: Boolean read FCompletedLeft write FCompletedLeft;
    property CompletedRight: Boolean read FCompletedLeft write FCompletedLeft;
    property Error: IThrowable read FError write FError;
  public
    function OnNext(const Left: X): TZip<X, Y>; overload; dynamic; abstract;
    function OnNext(const Right: Y): TZip<X, Y>; overload; dynamic; abstract;
    function OnCompletedLeft: Boolean; dynamic;
    function OnCompletedRight: Boolean; dynamic;
    function OnErrorLeft(Error: IThrowable): Boolean; dynamic;
    function OnErrorRight(Error: IThrowable): Boolean; dynamic;
  end;

  TSyncStrategy<X, Y> = class(TJoinStrategy<X, Y>)
  strict private
    FLeftBuffer: TList<TSmartVariable<X>>;
    FRightBuffer: TList<TSmartVariable<Y>>;
  public
    constructor Create;
    destructor Destroy; override;
    function OnNext(const Left: X): TZip<X, Y>; overload; override;
    function OnNext(const Right: Y): TZip<X, Y>; overload; override;
    function OnCompletedLeft: Boolean; override;
    function OnCompletedRight: Boolean; override;
    function OnErrorLeft(Error: IThrowable): Boolean; override;
    function OnErrorRight(Error: IThrowable): Boolean; override;
  end;

  TCombineLatestStrategy<X, Y> = class(TJoinStrategy<X, Y>)
  strict private
    FLeft: TSmartVariable<X>;
    FRight: TSmartVariable<Y>;
    FLeftExists: Boolean;
    FRightExists: Boolean;
  public
    function OnNext(const Left: X): TZip<X, Y>; overload; override;
    function OnNext(const Right: Y): TZip<X, Y>; overload; override;
  end;

  TFastStream = (fsA, fsB);

  TWithLatestFromStrategy<X, Y> = class(TJoinStrategy<X, Y>)
  strict private
    FFastStream: TFastStream;
    FLeft: TSmartVariable<X>;
    FRight: TSmartVariable<Y>;
    FLeftExists: Boolean;
    FRightExists: Boolean;
    procedure AfterOnNext;
  public
    constructor Create(FastStream: TFastStream);
    function OnNext(const Left: X): TZip<X, Y>; overload; override;
    function OnNext(const Right: Y): TZip<X, Y>; overload; override;
  end;

  TAMBStrategy<X, Y> = class(TJoinStrategy<X, Y>)
  strict private
    FLeft: TSmartVariable<X>;
    FRight: TSmartVariable<Y>;
    FLeftExists: Boolean;
    FRightExists: Boolean;
  public
    function OnNext(const Left: X): TZip<X, Y>; overload; override;
    function OnNext(const Right: Y): TZip<X, Y>; overload; override;
  end;

  TAMBWithStrategy<X, Y> = class(TJoinStrategy<X, Y>)
  strict private
    FFastStream: TFastStream;
    FLeft: TSmartVariable<X>;
    FRight: TSmartVariable<Y>;
    FLeftExists: Boolean;
    FRightExists: Boolean;
    procedure AfterOnNext;
  public
    constructor Create(FastStream: TFastStream);
    function OnNext(const Left: X): TZip<X, Y>; overload; override;
    function OnNext(const Right: Y): TZip<X, Y>; overload; override;
  end;

  IJoiner = interface
    procedure OnSubscribe(Subscriber: IInterface);
  end;

  TJoiner<X, Y> = class(TInterfacedObject, IObserver<X>, IObserver<Y>, IJoiner)
  type
    TZip = TZip<X, Y>;
    TXValue = TSmartVariable<X>;
    TYValue = TSmartVariable<Y>;
    TOnNextRoutine = procedure(Data: TObject) of object;
    TOnErrorRoutine = procedure(E: IThrowable) of object;
    TOnCompletedRoutine = procedure of object;
  strict private
    class threadvar Route: Boolean;
    class threadvar RouteLeft: ISubscriber<X>;
    class threadvar RouteRight: ISubscriber<Y>;
  var
    FLeftIcp: TInterceptor<X>;
    FRightIcp: TInterceptor<Y>;
    FRoutine: TOnNextRoutine;
    FOnError: TOnErrorRoutine;
    FOnCompleted: TOnCompletedRoutine;
    FLock: TCriticalSection;
    FStrategy: IJoinStrategy<X, Y>;
    function GetStrategy: IJoinStrategy<X, Y>;
    procedure Lock; inline;
    procedure UnLock; inline;
    procedure OnNextRight(const Right: Y);
    procedure SetStrategy(Value: IJoinStrategy<X, Y>);
    procedure RouteLeftFiberExecute(Fiber: TCustomFiber);
    procedure RouteRightFiberExecute(Fiber: TCustomFiber);
    procedure OnErrorLeft(E: IThrowable);
    procedure OnErrorRight(E: IThrowable);
    procedure OnCompletedLeft;
    procedure OnCompletedRight;
  public
    constructor Create(Left: IObservable<X>; Right: IObservable<Y>;
      const Routine: TOnNextRoutine; const OnError: TOnErrorRoutine;
      const OnCompleted: TOnCompletedRoutine);
    destructor Destroy; override;
    property Strategy: IJoinStrategy<X, Y> read FStrategy write SetStrategy;
    procedure OnNext(const Left: X); overload;
    procedure OnNext(const Right: Y); overload;
    procedure OnError(E: IThrowable);
    procedure OnCompleted;
    procedure OnSubscribe(Subscriber: IInterface);
  end;

  TOnceSubscriber<Z: class; X, Y> = class(TInterfacedObject, ISubscriber<Z>, ISubscriber<X>, ISubscriber<Y>)
  strict private
    FLeftBuffer: TList<TJoiner<X, Y>.TXValue>;
    FRightBuffer: TList<TJoiner<X, Y>.TYValue>;
    FDest: ISubscriber<Z>;
    FFiberLeft: TCustomFiber;
    FFiberRight: TCustomFiber;
    FStrategy: IJoinStrategy<X, Y>;
  protected
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
  public
    constructor Create(Dest: ISubscriber<Z>; Strategy: IJoinStrategy<X, Y>); overload;
    constructor Create(Dest: ISubscriber<Z>; Strategy: IJoinStrategy<X, Y>;
      FiberLeft, FiberRight: TCustomFiber); overload;
    destructor Destroy; override;
    procedure OnNext(const Left: X); overload;
    procedure OnNext(const Right: Y); overload;
    procedure OnNext(const A: Z); overload;
    procedure OnError(E: IThrowable);
    procedure OnCompleted;
    procedure Unsubscribe;
    function IsUnsubscribed: Boolean;
    procedure SetProducer(P: IProducer);
  end;

  TZipObserver<T: class> = class(TPublishSubject<T>)
  strict private
    FJoiner: IJoiner;
  protected
    procedure OnSubscribe(Subscriber: ISubscriber<T>); override;
  public
    destructor Destroy; override;
    procedure Setup(Joiner: IJoiner);
    procedure OnNextIcp(Data: TObject);
  end;

implementation

{ TInterceptor<T> }

procedure TInterceptor<T>.OnCompleted;
begin
  FOnCompletedIntercept
end;

procedure TInterceptor<T>.OnError(E: IThrowable);
begin
  FOnErrorIntercept(E)
end;

procedure TInterceptor<T>.OnNext(const Data: T);
begin
  FOnNextIntercept(Data)
end;

{ TJoiner<X, Y> }

constructor TJoiner<X, Y>.Create(Left: IObservable<X>; Right: IObservable<Y>;
  const Routine: TOnNextRoutine;
  const OnError: TOnErrorRoutine;
  const OnCompleted: TOnCompletedRoutine);
begin
  FLock := TCriticalSection.Create;
  FLeftIcp := TInterceptor<X>.Create;
  with FLeftIcp do begin
    FOnNextIntercept := Self.OnNext;
    FOnErrorIntercept := Self.OnErrorLeft;
    FOnCompletedIntercept := Self.OnCompletedLeft;
  end;
  FRightIcp := TInterceptor<Y>.Create;
  with FRightIcp do begin
    FOnNextIntercept := Self.OnNextRight;
    FOnErrorIntercept := Self.OnErrorRight;
    FOnCompletedIntercept := Self.OnCompletedRight;
  end;
  //
  FRoutine := Routine;
  FOnError := OnError;
  FOnCompleted := OnCompleted;
  FLeftIcp.Merge(Left);
  FRightIcp.Merge(Right);
end;

destructor TJoiner<X, Y>.Destroy;
begin
  FStrategy := nil;
  FLeftIcp.Free;
  FRightIcp.Free;
  FLock.Free;
  inherited;
end;

function TJoiner<X, Y>.GetStrategy: IJoinStrategy<X, Y>;
begin
  if not Assigned(FStrategy) then
    FStrategy := TSyncStrategy<X, Y>.Create;
  Result := FStrategy;
end;

procedure TJoiner<X, Y>.Lock;
begin
  FLock.Acquire;
end;

procedure TJoiner<X, Y>.OnCompleted;
begin
  if Route then begin
    RouteLeft.OnCompleted;
    RouteRight.OnCompleted;
  end
  else begin
    Lock;
    try
      FOnCompleted()
    finally
      Unlock;
    end;
  end;
end;

procedure TJoiner<X, Y>.OnError(E: IThrowable);
begin
  if Route then begin
    RouteLeft.OnError(E);
    RouteRight.OnError(E);
  end
  else begin
    Lock;
    try
      FOnError(E)
    finally
      Unlock;
    end;
  end;
end;

procedure TJoiner<X, Y>.OnNext(const Right: Y);
var
  Left: X;
  Zip: TZip;
begin
  if Route then
    RouteRight.OnNext(Right)
  else begin
    Lock;
    try
      Zip := GetStrategy.OnNext(Right);
      if Assigned(Zip) then
        FRoutine(Zip);
    finally
      Unlock;
    end;
  end;
end;

procedure TJoiner<X, Y>.OnNextRight(const Right: Y);
begin
  OnNext(Right)
end;

procedure TJoiner<X, Y>.OnSubscribe(Subscriber: IInterface);
var
  LeftFiber, RightFiber: TFiber;
  Once: TOnceSubscriber<TZip<X,Y>, X, Y>;
  Sbscr: ISubscriber<TZip<X,Y>>;
begin

  LeftFiber := TFiber.Create(RouteLeftFiberExecute);
  RightFiber := TFiber.Create(RouteRightFiberExecute);

  Sbscr := ISubscriber<TZip<X,Y>>(Subscriber);
  Once := TOnceSubscriber<TZip<X,Y>, X, Y>.Create(Sbscr, FStrategy, LeftFiber, RightFiber);
  Route := True;
  RouteLeft := Once;
  RouteRight := Once;
  try
     while not (LeftFiber.IsTerminated or RightFiber.IsTerminated) do begin
       LeftFiber.Invoke;
       RightFiber.Invoke;
     end
  finally
    Route := False;
    TJoiner<X, Y>.RouteLeft := nil;
    TJoiner<X, Y>.RouteRight := nil;
    Sbscr := nil;
    LeftFiber.Free;
    RightFiber.Free;
  end;
end;

procedure TJoiner<X, Y>.RouteLeftFiberExecute(Fiber: TCustomFiber);
begin
  FLeftIcp.Subscribe(RouteLeft)
end;

procedure TJoiner<X, Y>.RouteRightFiberExecute(Fiber: TCustomFiber);
begin
  FRightIcp.Subscribe(RouteRight)
end;

procedure TJoiner<X, Y>.SetStrategy(Value: IJoinStrategy<X, Y>);
begin
  FStrategy := Value;
end;

procedure TJoiner<X, Y>.OnErrorLeft(E: IThrowable);
begin
  if Route then
    RouteLeft.OnError(E)
  else begin
    Lock;
    try
      if GetStrategy.OnErrorLeft(E) then
        FOnError(E)
    finally
      Unlock;
    end;
  end;
end;

procedure TJoiner<X, Y>.OnErrorRight(E: IThrowable);
begin
  if Route then
    RouteRight.OnError(E)
  else begin
    Lock;
    try
      if GetStrategy.OnErrorRight(E) then
        FOnError(E)
    finally
      Unlock;
    end;
  end;
end;

procedure TJoiner<X, Y>.OnCompletedLeft;
begin
  if Route then
    RouteLeft.OnCompleted
  else begin
    Lock;
    try
      if GetStrategy.OnCompletedLeft then
        FOnCompleted
    finally
      Unlock;
    end;
  end;
end;

procedure TJoiner<X, Y>.OnCompletedRight;
begin
  if Route then
    RouteRight.OnCompleted
  else begin
    Lock;
    try
      if GetStrategy.OnCompletedRight then
        FOnCompleted
    finally
      Unlock;
    end;
  end;
end;

procedure TJoiner<X, Y>.UnLock;
begin
  FLock.Release;
end;

procedure TJoiner<X, Y>.OnNext(const Left: X);
var
  Right: Y;
  Zip: TZip;
begin
  if Route then
    RouteLeft.OnNext(Left)
  else begin
    Lock;
    try
      Zip := GetStrategy.OnNext(Left);
      if Assigned(Zip) then begin
        FRoutine(Zip);
      end;
    finally
      Unlock;
    end;
  end;
end;

{ TZip<T> }

destructor TZipObserver<T>.Destroy;
begin
  FJoiner := nil;
  inherited;
end;

procedure TZipObserver<T>.OnNextIcp(Data: TObject);
begin
  Self.OnNext(Data)
end;

procedure TZipObserver<T>.OnSubscribe(Subscriber: ISubscriber<T>);
begin
  if Assigned(FJoiner) then
    FJoiner.OnSubscribe(Subscriber);
end;

procedure TZipObserver<T>.Setup(Joiner: IJoiner);
begin
  FJoiner := Joiner;
end;

{ TOnceSubscriber<X, Y> }

constructor TOnceSubscriber<Z, X, Y>.Create(Dest: ISubscriber<Z>; Strategy: IJoinStrategy<X, Y>);
begin
  FLeftBuffer := TList<TJoiner<X, Y>.TXValue>.Create;
  FRightBuffer := TList<TJoiner<X, Y>.TYValue>.Create;
  FDest := Dest;
  FStrategy := Strategy;
end;

constructor TOnceSubscriber<Z, X, Y>.Create(Dest: ISubscriber<Z>; Strategy: IJoinStrategy<X, Y>;
  FiberLeft, FiberRight: TCustomFiber);
begin
  Create(Dest, Strategy);
  FFiberLeft := FiberLeft;
  FFiberRight := FiberRight;
end;

destructor TOnceSubscriber<Z, X, Y>.Destroy;
begin
  FDest := nil;
  FLeftBuffer.Free;
  FRightBuffer.Free;
  inherited;
end;

function TOnceSubscriber<Z, X, Y> ._AddRef: Integer;
begin
  Result := inherited _AddRef;
end;

function TOnceSubscriber<Z, X, Y> ._Release: Integer;
begin
  Result := inherited _Release;
end;

function TOnceSubscriber<Z, X, Y> .IsUnsubscribed: Boolean;
begin
  Result := FDest = nil;
end;

procedure TOnceSubscriber<Z, X, Y> .OnCompleted;
begin
  if not IsUnsubscribed then begin
    FDest.OnCompleted;
    Unsubscribe;
  end;
end;

procedure TOnceSubscriber<Z, X, Y> .OnError(E: IThrowable);
begin
  if not IsUnsubscribed then begin
    FDest.OnError(E);
    Unsubscribe;
  end;
end;

procedure TOnceSubscriber<Z, X, Y>.OnNext(const A: Z);
begin
  if not IsUnsubscribed then
    FDest.OnNext(A)
end;

procedure TOnceSubscriber<Z, X, Y> .OnNext(const Left: X);
var
  Zip: TZip<X, Y>;
begin
  try
    if IsUnsubscribed then
      Exit;
    Zip := FStrategy.OnNext(Left);
    if Assigned(Zip) then
      Self.OnNext(Zip)
  finally
    if Assigned(FFiberLeft) then
      FFiberLeft.Yield
  end;
end;

procedure TOnceSubscriber<Z, X, Y> .OnNext(const Right: Y);
var
  Zip: TZip<X, Y>;
  Ref: TSmartVariable<Z>;
begin
  try
    if IsUnsubscribed then
      Exit;
    Zip := FStrategy.OnNext(Right);
    if Assigned(Zip) then begin
      Ref := TObject(Zip);
      Self.OnNext(Zip);
    end;
  finally
    if Assigned(FFiberRight) then
      FFiberRight.Yield;
  end;
end;

procedure TOnceSubscriber<Z, X, Y> .SetProducer(P: IProducer);
begin
  // nothing
end;

procedure TOnceSubscriber<Z, X, Y> .Unsubscribe;
begin
  FDest := nil
end;

{ TSyncStrategy<X, Y> }

function TSyncStrategy<X, Y>.OnNext(const Left: X): TZip<X, Y>;
var
  Right: Y;
begin
  Result := nil;
  if FRightBuffer.Count > 0 then begin
    Right := FRightBuffer[0].Get;
    FRightBuffer.Delete(0);
    Result := TZip<X, Y>.Create(Left, Right);
  end
  else
    FLeftBuffer.Add(Left)
end;

constructor TSyncStrategy<X, Y>.Create;
begin
  FLeftBuffer := TList<TSmartVariable<X>>.Create;
  FRightBuffer := TList<TSmartVariable<Y>>.Create;
end;

destructor TSyncStrategy<X, Y>.Destroy;
begin
  FLeftBuffer.Free;
  FRightBuffer.Free;
  inherited;
end;

function TSyncStrategy<X, Y>.OnNext(const Right: Y): TZip<X, Y>;
var
  Left: X;
begin
  Result := nil;
  if FLeftBuffer.Count > 0 then begin
    Left := FLeftBuffer[0].Get;
    FLeftBuffer.Delete(0);
    Result := TZip<X, Y>.Create(Left, Right);
  end
  else
    FRightBuffer.Add(Right)
end;

function TSyncStrategy<X, Y>.OnCompletedLeft: Boolean;
begin
  Result := inherited OnCompletedLeft;
  if Result then begin
    if CompletedLeft then
      Result := FLeftBuffer.Count then


  end;
end;

function TSyncStrategy<X, Y>.OnCompletedRight: Boolean;
begin
  Result := inherited OnCompletedRight;
end;

function TSyncStrategy<X, Y>.OnErrorLeft(Error: IThrowable): Boolean;
begin
  Result := inherited OnErrorLeft(Error);
end;

function TSyncStrategy<X, Y>.OnErrorRight(Error: IThrowable): Boolean;
begin
  Result := inherited OnErrorRight(Error);
end;

{ TCombineLatestStrategy<X, Y> }

function TCombineLatestStrategy<X, Y>.OnNext(const Left: X): TZip<X, Y>;
begin
  FLeftExists := True;
  FLeft := Left;
  if FLeftExists and FRightExists then
    Result := TZip<X, Y>.Create(FLeft, FRight)
  else
    Result := nil;
end;

function TCombineLatestStrategy<X, Y>.OnNext(const Right: Y): TZip<X, Y>;
begin
  FRightExists := True;
  FRight := Right;
  if FLeftExists and FRightExists then
    Result := TZip<X, Y>.Create(FLeft, FRight)
  else
    Result := nil;
end;

{ TWithLatestFromStrategy<X, Y> }

procedure TWithLatestFromStrategy<X, Y>.AfterOnNext;
begin
  if FFastStream = fsA then
    FLeftExists := False
  else
    FRightExists := False
end;

function TWithLatestFromStrategy<X, Y>.OnNext(const Left: X): TZip<X, Y>;
begin
  FLeftExists := True;
  FLeft := Left;
  if FLeftExists and FRightExists then begin
    Result := TZip<X, Y>.Create(FLeft, FRight);
    AfterOnNext;
  end
  else
    Result := nil;
end;

constructor TWithLatestFromStrategy<X, Y>.Create(FastStream: TFastStream);
begin
  FFastStream := FastStream;
end;

function TWithLatestFromStrategy<X, Y>.OnNext(const Right: Y): TZip<X, Y>;
begin
  FRightExists := True;
  FRight := Right;
  if FLeftExists and FRightExists then begin
    Result := TZip<X, Y>.Create(FLeft, FRight);
    AfterOnNext;
  end
  else
    Result := nil;
end;

{ TAMBWithStrategy<X, Y> }

procedure TAMBWithStrategy<X, Y>.AfterOnNext;
begin
  FLeftExists := False;
  FRightExists := False;
end;

function TAMBWithStrategy<X, Y>.OnNext(const Left: X): TZip<X, Y>;
begin
  if not FLeftExists then begin
    FLeftExists := True;
    FLeft := Left;
  end;
  if FLeftExists and FRightExists and (FFastStream = fsB) then begin
    Result := TZip<X, Y>.Create(FLeft, FRight);
    AfterOnNext;
  end
  else
    Result := nil;
end;

constructor TAMBWithStrategy<X, Y>.Create(FastStream: TFastStream);
begin
  FFastStream := FastStream;
end;

function TAMBWithStrategy<X, Y>.OnNext(const Right: Y): TZip<X, Y>;
begin
  if not FRightExists then begin
    FRightExists := True;
    FRight := Right;
  end;
  if FLeftExists and FRightExists and (FFastStream = fsA) then begin
    Result := TZip<X, Y>.Create(FLeft, FRight);
    AfterOnNext;
  end
  else
    Result := nil;
end;

  { TAMBStrategy<X, Y> }
function TAMBStrategy<X, Y>.OnNext(const Left: X): TZip<X, Y>;
begin
  if not FLeftExists then begin
    FLeftExists := True;
    FLeft := Left;
  end;
  if FLeftExists and FRightExists then begin
    Result := TZip<X, Y>.Create(FLeft, FRight);
    FLeftExists := False;
    FRightExists := False;
  end
  else
    Result := nil;
end;

function TAMBStrategy<X, Y>.OnNext(const Right: Y): TZip<X, Y>;
begin
  if not FRightExists then begin
    FRightExists := True;
    FRight := Right;
  end;
  if FLeftExists and FRightExists then begin
    Result := TZip<X, Y>.Create(FLeft, FRight);
    FLeftExists := False;
    FRightExists := False;
  end
  else
    Result := nil;
end;

{ TJoinStrategy<X, Y> }

function TJoinStrategy<X, Y>.OnCompletedLeft: Boolean;
begin
  FCompletedLeft := True;
  Result := True;
end;

function TJoinStrategy<X, Y>.OnCompletedRight: Boolean;
begin
  FCompletedRight := True;
  Result := False;
end;

function TJoinStrategy<X, Y>.OnErrorLeft(Error: IThrowable): Boolean;
begin
  FCompletedLeft := True;
  if not Assigned(FError) then
    FError := Error;
  Result := True;
end;

function TJoinStrategy<X, Y>.OnErrorRight(Error: IThrowable): Boolean;
begin
  FCompletedRight := True;
  if not Assigned(FError) then
    FError := Error;
  Result := True;
end;

end.
