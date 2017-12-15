unit Rx.Implementations;

interface
uses Rx, Generics.Collections, Classes, SyncObjs;

type

  IAutoRefObject = interface
    ['{AE37B031-074C-4F46-B475-1E392E4775CB}']
    function GetValue: TObject;
  end;

  TAutoRefObjectImpl = class(TInterfacedObject, IAutoRefObject)
  strict private
    FValue: TObject;
  public
    constructor Create(Value: TObject);
    destructor Destroy; override;
    function GetValue: TObject;
  end;

  TSubscriptionImpl = class(TInterfacedObject, ISubscription)
  strict private
    FIsUnsubscribed: Boolean;
  protected
    FLock: TCriticalSection;
    procedure UnsubscribeInterceptor; dynamic;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Unsubscribe;
    function IsUnsubscribed: Boolean;
    procedure SetProducer(P: IProducer);
  end;

  IContract<T> = interface(ISubscription)
    procedure Lock;
    procedure Unlock;
    function GetSubscriber: IObserver<T>;
  end;

  TContractImpl<T> = class(TSubscriptionImpl, IContract<T>)
  strict private
    [Weak] FSubscriber: IObserver<T>;
    FHardRef: IInterface;
  protected
    procedure UnsubscribeInterceptor; override;
  public
    destructor Destroy; override;
    procedure Lock;
    procedure Unlock;
    function GetSubscriber: IObserver<T>;
    procedure SetSubscriber(Value: IObserver<T>; const WeakRef: Boolean=True);
  end;

  TSubscriberImpl<T> = class(TInterfacedObject, ISubscriber<T>, IObserver<T>, ISubscription)
  type
    TOnNext = TOnNext<T>;
  strict private
    FContract: IContract<T>;
    FOnNext: TOnNext;
    FOnError: TOnError;
    FOnCompleted: TOnCompleted;
  public
    constructor Create(Contract: IContract<T>; const OnNext: TOnNext=nil;
      const OnError: TOnError = nil; const OnCompleted: TOnCompleted=nil);
    destructor Destroy; override;
    procedure OnNext(const A: T);
    procedure OnError(E: IThrowable);
    procedure OnCompleted;
    procedure Unsubscribe;
    function IsUnsubscribed: Boolean;
    procedure SetProducer(P: IProducer);
  end;

  IFromSubscription<T> = interface(ISubscriber<T>)
    procedure Lock;
    procedure Unlock;
    function GetObservable: IObservable<T>;
  end;

  TFromSbscriptionImpl<T> = class(TSubscriptionImpl, IFromSubscription<T>, ISubscription)
  type
    TOnNext = TOnNext<T>;
  strict private
    [Weak] FObservable: IObservable<T>;
    FOnNext: TOnNext;
    FOnError: TOnError;
    FOnCompleted: TOnCompleted;
  protected
    procedure UnsubscribeInterceptor; override;
  public
    constructor Create(Observable: IObservable<T>; const OnNext: TOnNext=nil;
      const OnError: TOnError = nil; const OnCompleted: TOnCompleted=nil);
    procedure Lock;
    procedure Unlock;
    procedure OnNext(const A: T); dynamic;
    procedure OnError(E: IThrowable);
    procedure OnCompleted;
    function GetObservable: IObservable<T>;
  end;


  TSubscriberDecorator<T> = class(TInterfacedObject, ISubscriber<T>, IObserver<T>)
  strict private
    FSubscriber: ISubscriber<T>;
    FScheduler: IScheduler;
  public
    constructor Create(S: ISubscriber<T>; Scheduler: IScheduler);
    destructor Destroy; override;
    procedure OnNext(const A: T);
    procedure OnError(E: IThrowable);
    procedure OnCompleted;
    procedure Unsubscribe;
    function IsUnsubscribed: Boolean;
    procedure SetProducer(P: IProducer);
  end;

  TOnNextAction<T> = class(TInterfacedObject, IAction)
  strict private
    FData: TSmartVariable<T>;
    FContract: IContract<T>;
  public
    constructor Create(const Data: T; Contract: IContract<T>);
    procedure Emit;
  end;

  TOnErrorAction<T> = class(TInterfacedObject, IAction)
  strict private
    FThrowable: IThrowable;
    FContract: IContract<T>;
  public
    constructor Create(const Throwable: IThrowable; Contract: IContract<T>);
    procedure Emit;
  end;

  TOnCompletedAction<T> = class(TInterfacedObject, IAction)
  strict private
    FContract: IContract<T>;
  public
    constructor Create(Contract: IContract<T>);
    procedure Emit;
  end;

  TOnSubscribeAction<T> = class(TInterfacedObject, IAction)
  strict private
    FContract: IContract<T>;
    FRoutine: TOnSubscribe<T>;
  public
    constructor Create(Contract: IContract<T>; const Routine: TOnSubscribe<T>);
    procedure Emit;
  end;

  TObservableImpl<T> = class(TInterfacedObject, IObservable<T>, IObserver<T>)
  type
    IContract = IContract<T>;
    tContractCollection = array of IContract;
    IFromSubscription = IFromSubscription<T>;
  strict private
    FLock: TCriticalSection;
    FContracts: TList<IContract>;
    FInputs: TList<IFromSubscription>;
    FScheduler: IScheduler;
    FSubscribeOnScheduler: IScheduler;
    FDoOnNext: TOnNext<T>;
    FOnSubscribe: TOnSubscribe<T>;
    FOnSubscribe2: TOnSubscribe2<T>;
    FName: string;
    function SubscribeInternal(OnNext: TOnNext<T>; const OnError: TOnError; const OnCompleted: TOnCompleted): ISubscription;
  protected
    procedure Lock; inline;
    procedure Unlock; inline;
    class threadvar OffOnSubscribe: Boolean;
    property Inputs: TList<IFromSubscription> read FInputs;
    function Freeze: tContractCollection;
    property Scheduler: IScheduler read FScheduler;
    procedure OnSubscribe(Subscriber: ISubscriber<T>); dynamic;
  public
    constructor Create; overload;
    constructor Create(const OnSubscribe: TOnSubscribe<T>); overload;
    constructor Create(const OnSubscribe: TOnSubscribe2<T>); overload;
    destructor Destroy; override;
    // debug-only purposes
    procedure SetName(const Value: string);
    property Name: string read FName write SetName;

    function Subscribe(const OnNext: TOnNext<T>): ISubscription; overload;
    function Subscribe(const OnNext: TOnNext<T>; const OnError: TOnError): ISubscription; overload;
    function Subscribe(const OnNext: TOnNext<T>; const OnError: TOnError; const OnCompleted: TOnCompleted): ISubscription; overload;
    function Subscribe(const OnNext: TOnNext<T>; const OnCompleted: TOnCompleted): ISubscription; overload;
    function Subscribe(const OnError: TOnError): ISubscription; overload;
    function Subscribe(const OnCompleted: TOnCompleted): ISubscription; overload;
    function Subscribe(A: ISubscriber<T>): ISubscription; overload;
    function Merge(O: IObservable<T>): ISubscription;
    procedure OnNext(const Data: T); dynamic;
    procedure OnError(E: IThrowable); dynamic;
    procedure OnCompleted; dynamic;
    procedure ScheduleOn(Scheduler: IScheduler);
    procedure SubscribeOn(Scheduler: IScheduler);
    procedure DoOnNext(const Cb: TOnNext<T>);
  end;

  TIntervalThread = class(TThread)
  strict private
    FSubscription: ISubscriber<LongWord>;
    FDelay: LongWord;
    FInitialDelay: LongWord;
    FOnTerminate: TEvent;
  protected
    procedure Execute; override;
  public
    constructor Create(Subscription: ISubscriber<LongWord>; Delay: LongWord;
      InitialDelay: LongWord);
    destructor Destroy; override;
    procedure Terminate; reintroduce;
  end;

  TIntervalObserver = class(TObservableImpl<LongWord>)
  strict private
    FThreads: TList<TIntervalThread>;
  protected
    procedure OnSubscribe(Subscriber: ISubscriber<LongWord>); override;
    class threadvar CurDelay: LongWord;
    class threadvar InitialDelay: LongWord;
  public
    constructor Create;
    destructor Destroy; override;
  end;

implementation
uses SysUtils, Rx.Schedulers;

type

  TLockBasket = class
  strict private
    FLock: TCriticalSection;
    FRefs: TDictionary<Pointer, Integer>;
    procedure Lock; inline;
    procedure Unlock; inline;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddRef(A: TObject);
    procedure Release(A: TObject);
  end;

  TRefRegistry = class
  const
    HASH_SIZE = 1024;
  strict private
    // reduce probability of race conditions by Lock basket
    FBaskets: array[0..HASH_SIZE-1] of TLockBasket;
    function HashFunc(A: TObject): LongWord;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddRef(A: TObject);
    procedure Release(A: TObject);
  end;

var
  RefRegistry: TRefRegistry;

{ TRefRegistry }

procedure TRefRegistry.AddRef(A: TObject);
begin
  FBaskets[HashFunc(A)].AddRef(A);
end;

constructor TRefRegistry.Create;
var
  I: Integer;
begin
  for I := 0 to HASH_SIZE-1 do
    FBaskets[I] := TLockBasket.Create;
end;

destructor TRefRegistry.Destroy;
var
  I: Integer;
begin
  for I := 0 to HASH_SIZE-1 do
    FBaskets[I].Free;
  inherited;
end;

function TRefRegistry.HashFunc(A: TObject): LongWord;
var
  H: UInt64;
begin
  // hash calculation example: TThreadLocalCounter.HashIndex
  H := Uint64(A);
  Result := Int64Rec(H).Words[0] xor Int64Rec(H).Words[1] or
    Int64Rec(H).Words[2] xor Int64Rec(H).Words[3];
  Result := Result mod HASH_SIZE;
end;

procedure TRefRegistry.Release(A: TObject);
begin
  FBaskets[HashFunc(A)].Release(A);
end;

{ TLockBasket }

procedure TLockBasket.AddRef(A: TObject);
begin
  Lock;
  try
    if not FRefs.ContainsKey(A) then
      FRefs.Add(A, 1)
    else
      FRefs[A] := FRefs[A] + 1
  finally
    Unlock;
  end;
end;

constructor TLockBasket.Create;
begin
  FLock := TCriticalSection.Create;
  FRefs := TDictionary<Pointer, Integer>.Create;
end;

destructor TLockBasket.Destroy;
begin
  FRefs.Free;
  FLock.Free;
  inherited;
end;

procedure TLockBasket.Lock;
begin
  FLock.Acquire;
end;

procedure TLockBasket.Release(A: TObject);
var
  RefCount: Integer;
begin
  Lock;
  try
    RefCount := FRefs[A];
    Dec(RefCount);
    if RefCount > 0 then
      FRefs[A] := RefCount
    else begin
      FRefs.Remove(A);
      A.Free;
    end;
  finally
    Unlock;
  end;
end;

procedure TLockBasket.Unlock;
begin
  FLock.Release;
end;

{ TAutoRefObjectImpl }

constructor TAutoRefObjectImpl.Create(Value: TObject);
begin
  FValue := Value;
  RefRegistry.AddRef(Value);
end;

destructor TAutoRefObjectImpl.Destroy;
begin
  RefRegistry.Release(FValue);
  inherited;
end;

function TAutoRefObjectImpl.GetValue: TObject;
begin
  Result := FValue;
end;

{ TOnNextAction }

constructor TOnNextAction<T>.Create(const Data: T; Contract: IContract<T>);
begin
  FData := Data;
  FContract := Contract;
end;

procedure TOnNextAction<T>.Emit;
begin
  FContract.Lock;
  try
    if Assigned(FContract.GetSubscriber) then
      FContract.GetSubscriber.OnNext(FData)
    else
      FContract.Unsubscribe;
  finally
    FContract.Unlock
  end;
end;

{ TOnErrorAction<T> }

constructor TOnErrorAction<T>.Create(const Throwable: IThrowable;
  Contract: IContract<T>);
begin
  FThrowable := Throwable;
  FContract := Contract;
end;

procedure TOnErrorAction<T>.Emit;
begin
  FContract.Lock;
  try
    if Assigned(FContract.GetSubscriber) then begin
      FContract.GetSubscriber.OnError(FThrowable);
      FContract.Unsubscribe;
    end
    else
      FContract.Unsubscribe;
  finally
    FContract.Unlock
  end;
end;

{ TOnCompletedAction<T> }

constructor TOnCompletedAction<T>.Create(Contract: IContract<T>);
begin
  FContract := Contract;
end;

procedure TOnCompletedAction<T>.Emit;
begin
  FContract.Lock;
  try
    if Assigned(FContract.GetSubscriber) then begin
      FContract.GetSubscriber.OnCompleted;
      FContract.Unsubscribe;
    end
    else
      FContract.Unsubscribe;
  finally
    FContract.Unlock
  end;
end;

{ TOnSubscribeAction<T> }

constructor TOnSubscribeAction<T>.Create(Contract: IContract<T>; const Routine: TOnSubscribe<T>);
begin

end;

procedure TOnSubscribeAction<T>.Emit;
begin
  FContract.Lock;
  try
    if Assigned(FContract.GetSubscriber) then
      FRoutine(FContract.GetSubscriber)
    else
      FContract.Unsubscribe;
  finally
    FContract.Unlock
  end;
end;



{ TObservableImpl<T> }

constructor TObservableImpl<T>.Create;
begin
  FLock := TCriticalSection.Create;
  FScheduler := TCurrentThreadScheduler.Create;
  FContracts := TList<IContract>.Create;
  FInputs := TList<IFromSubscription>.Create;
end;

constructor TObservableImpl<T>.Create(const OnSubscribe: TOnSubscribe<T>);
begin
  Create;
  FOnSubscribe := OnSubscribe;
end;

constructor TObservableImpl<T>.Create(const OnSubscribe: TOnSubscribe2<T>);
begin
  Create;
  FOnSubscribe2 := OnSubscribe;
end;

destructor TObservableImpl<T>.Destroy;
var
  S: IFromSubscription;
  C: IContract;
begin
  Lock;
  try
    for S in FInputs do begin
      S.Unsubscribe;
    end;
    for C in FContracts do
      C.Unsubscribe;
  finally
    Unlock;
  end;
  FContracts.Free;
  FInputs.Free;
  FScheduler := nil;
  FLock.Free;
  inherited;
end;

procedure TObservableImpl<T>.DoOnNext(const Cb: TOnNext<T>);
begin
  FDoOnNext := Cb;
end;

function TObservableImpl<T>.Freeze: tContractCollection;
var
  I: Integer;
  Contract: IContract;
begin
  Lock;
  try
    for I := FContracts.Count-1 downto 0 do begin
      Contract := FContracts[I];
      if Contract.IsUnsubscribed then
        FContracts.Delete(I);
    end;
    SetLength(Result, FContracts.Count);
    for I := 0 to FContracts.Count-1 do
      Result[I] := FContracts[I];
  finally
    Unlock;
  end;
end;

procedure TObservableImpl<T>.Lock;
begin
  FLock.Acquire
end;

function TObservableImpl<T>.Merge(O: IObservable<T>): ISubscription;
var
  S: IFromSubscription;
  SImpl: TFromSbscriptionImpl<T>;
  Found: Boolean;
begin
  Lock;
  OffOnSubscribe := True;
  try
    Found := False;
    for S in FInputs do
      if S.GetObservable = O then begin
        Found := True;
        Break
      end;
    if not Found then begin
      SImpl := TFromSbscriptionImpl<T>.Create(O, Self.OnNext, Self.OnError, Self.OnCompleted);
      S := SImpl;
      FInputs.Add(SImpl);
      O.Subscribe(S);
      Result := SImpl;
    end;
  finally
    OffOnSubscribe := False;
    Unlock;
  end;
end;

procedure TObservableImpl<T>.OnCompleted;
var
  Contract: IContract;
begin
  for Contract in Freeze do begin
    FScheduler.Invoke(TOnCompletedAction<T>.Create(Contract));
  end;
end;

procedure TObservableImpl<T>.OnError(E: IThrowable);
var
  Contract: IContract;
begin
  for Contract in Freeze do begin
    FScheduler.Invoke(TOnErrorAction<T>.Create(E, Contract));
  end;
end;

procedure TObservableImpl<T>.OnNext(const Data: T);
begin
  if Assigned(FDoOnNext) then
    FDoOnNext(Data);
  // Descendant can override
end;

procedure TObservableImpl<T>.OnSubscribe(Subscriber: ISubscriber<T>);
var
  S: IFromSubscription;
  Once: ISubscription;
  Succ: Boolean;
  SubscribeOnScheduler: IScheduler;
  SubscriberDecorator: ISubscriber<T>;
begin
  if OffOnSubscribe then
    Exit;

  Lock;
  SubscribeOnScheduler := FSubscribeOnScheduler;
  Unlock;
  SubscriberDecorator := TSubscriberDecorator<T>.Create(Subscriber, FScheduler);

  if Assigned(FOnSubscribe) then
    if Assigned(SubscribeOnScheduler) then
      //SubscribeOnScheduler.Invoke(TOnSubscribeAction<T>.Create);
      raise Exception.Create('TODO')
    else begin
      try
        FOnSubscribe(SubscriberDecorator);
      except
        SubscriberDecorator.OnError(Observable.CatchException)
      end;
    end;
  if Assigned(FOnSubscribe2) then
    if Assigned(SubscribeOnScheduler) then
      raise Exception.Create('TODO')
    else begin
      try
        FOnSubscribe2(SubscriberDecorator);
      except
        SubscriberDecorator.OnError(Observable.CatchException)
      end;
    end;

  for S in FInputs do begin
    S.Lock;
    try
      Succ := not S.IsUnsubscribed and Assigned(S.GetObservable);
      if Succ then
        Once := nil;
        try
          Once := S.GetObservable.Subscribe(OnNext, OnError, OnCompleted)
        finally
          if Assigned(Once) then
            Once.Unsubscribe;
        end;
    finally
      S.Unlock;
    end;
  end;

end;

function TObservableImpl<T>.Subscribe(const OnError: TOnError): ISubscription;
begin
  Result := SubscribeInternal(nil, OnError, nil);
end;

function TObservableImpl<T>.Subscribe(const OnNext: TOnNext<T>;
  const OnCompleted: TOnCompleted): ISubscription;
begin
  Result := Subscribe(OnNext, nil, OnCompleted);
end;

procedure TObservableImpl<T>.ScheduleOn(Scheduler: IScheduler);
begin
  Lock;
  FScheduler := Scheduler;
  Unlock;
end;

procedure TObservableImpl<T>.SubscribeOn(Scheduler: IScheduler);
begin
  Lock;
  FSubscribeOnScheduler := Scheduler;
  Unlock;
end;

function TObservableImpl<T>.Subscribe(A: ISubscriber<T>): ISubscription;
var
  Contract: TContractImpl<T>;
begin
  Contract := TContractImpl<T>.Create;
  Contract.SetSubscriber(A);
  Lock;
  FContracts.Add(Contract);
  Unlock;
  OnSubscribe(A);
  Result := Contract;
end;

function TObservableImpl<T>.SubscribeInternal(OnNext: TOnNext<T>;
  const OnError: TOnError; const OnCompleted: TOnCompleted): ISubscription;
var
  Sub: TSubscriberImpl<T>;
  Contract: TContractImpl<T>;
begin
  Contract := TContractImpl<T>.Create;
  Sub := TSubscriberImpl<T>.Create(Contract, OnNext, OnError, OnCompleted);
  Contract.SetSubscriber(Sub);
  Lock;
  FContracts.Add(Contract);
  Unlock;
  OnSubscribe(Sub);
  Result := Contract;
end;

procedure TObservableImpl<T>.SetName(const Value: string);
begin
  FName := Value;
end;

function TObservableImpl<T>.Subscribe(
  const OnCompleted: TOnCompleted): ISubscription;
begin
  Result := SubscribeInternal(nil, nil, OnCompleted);
end;

function TObservableImpl<T>.Subscribe(const OnNext: TOnNext<T>;
  const OnError: TOnError): ISubscription;
begin
  Result := SubscribeInternal(OnNext, OnError, nil);
end;

function TObservableImpl<T>.Subscribe(const OnNext: TOnNext<T>;
  const OnError: TOnError; const OnCompleted: TOnCompleted): ISubscription;
begin
  Result := SubscribeInternal(OnNext, OnError, OnCompleted)
end;

function TObservableImpl<T>.Subscribe(const OnNext: TOnNext<T>): ISubscription;
begin
  Result := SubscribeInternal(OnNext, nil, nil);
end;

procedure TObservableImpl<T>.Unlock;
begin
  FLock.Release;
end;

{ TSubscriberImpl<T> }

constructor TSubscriberImpl<T>.Create(Contract: IContract<T>; const OnNext: TOnNext=nil;
      const OnError: TOnError = nil; const OnCompleted: TOnCompleted=nil);
begin
  FContract := Contract;
  FOnNext := OnNext;
  FOnError := OnError;
  FOnCompleted := OnCompleted;
end;

destructor TSubscriberImpl<T>.Destroy;
begin
  FContract.Unsubscribe;
  FContract := nil;
  inherited;
end;

function TSubscriberImpl<T>.IsUnsubscribed: Boolean;
begin
  Result := FContract.IsUnsubscribed
end;

procedure TSubscriberImpl<T>.OnCompleted;
begin
  if Assigned(FOnCompleted) then
    FOnCompleted()
end;

procedure TSubscriberImpl<T>.OnError(E: IThrowable);
begin
  if Assigned(FOnError) then
    FOnError(E)
end;

procedure TSubscriberImpl<T>.OnNext(const A: T);
begin
  if Assigned(FOnNext) then
    FOnNext(A)
end;

procedure TSubscriberImpl<T>.SetProducer(P: IProducer);
begin
  FContract.SetProducer(P);
end;

procedure TSubscriberImpl<T>.Unsubscribe;
begin
  FContract.Unsubscribe;
end;

{ TSubscriptionImpl }

constructor TSubscriptionImpl.Create;
begin
  FLock := TCriticalSection.Create;
end;

destructor TSubscriptionImpl.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TSubscriptionImpl.IsUnsubscribed: Boolean;
begin
  FLock.Acquire;
  Result := FIsUnsubscribed;
  FLock.Release;
end;

procedure TSubscriptionImpl.SetProducer(P: IProducer);
begin

end;

procedure TSubscriptionImpl.Unsubscribe;
begin
  FLock.Acquire;
  if not FIsUnsubscribed then begin
    FIsUnsubscribed := True;
    UnsubscribeInterceptor;
  end;
  FLock.Release;
end;

procedure TSubscriptionImpl.UnsubscribeInterceptor;
begin

end;

{ TContractImpl<T> }

destructor TContractImpl<T>.Destroy;
begin
  SetSubscriber(nil, True);
  inherited;
end;

function TContractImpl<T>.GetSubscriber: IObserver<T>;
begin
  Lock;
  Result := FSubscriber;
  Unlock;
end;

procedure TContractImpl<T>.Lock;
begin
  FLock.Acquire
end;

procedure TContractImpl<T>.SetSubscriber(Value: IObserver<T>; const WeakRef: Boolean=True);
begin
  Lock;
  FSubscriber := Value;
  if not WeakRef then
    FHardRef := Value;
  Unlock;
end;

procedure TContractImpl<T>.Unlock;
begin
  FLock.Release;
end;

procedure TContractImpl<T>.UnsubscribeInterceptor;
begin
  FSubscriber := nil;
end;

{ TSubscriberDecorator<T> }

constructor TSubscriberDecorator<T>.Create(S: ISubscriber<T>; Scheduler: IScheduler);
begin
  FSubscriber := S;
  FScheduler := Scheduler;
end;

destructor TSubscriberDecorator<T>.Destroy;
begin
  if Assigned(FSubscriber) then begin
    FSubscriber := nil;
  end;
  inherited;
end;

procedure TSubscriberDecorator<T>.Unsubscribe;
begin
  if Assigned(FSubscriber) then
    FSubscriber.Unsubscribe;
end;

function TSubscriberDecorator<T>.IsUnsubscribed: Boolean;
begin
  if Assigned(FSubscriber) then
    Result := FSubscriber.IsUnsubscribed
  else
    Result := False;
end;

procedure TSubscriberDecorator<T>.SetProducer(P: IProducer);
begin
  if Assigned(FSubscriber) then
    FSubscriber.SetProducer(P);
end;

procedure TSubscriberDecorator<T>.OnCompleted;
var
  Contract: TContractImpl<T>;
begin
  if Assigned(FSubscriber) then begin
    if Supports(FScheduler, StdSchedulers.ICurrentThreadScheduler) then
      FSubscriber.OnCompleted
    else begin
      Contract := TContractImpl<T>.Create;
      Contract.SetSubscriber(FSubscriber);
      FScheduler.Invoke(TOnCompletedAction<T>.Create(Contract));
    end;
    FSubscriber.Unsubscribe;
    FSubscriber := nil;
  end;
end;

procedure TSubscriberDecorator<T>.OnError(E: IThrowable);
var
  Contract: TContractImpl<T>;
begin
  if Assigned(FSubscriber) then begin
    if Supports(FScheduler, StdSchedulers.ICurrentThreadScheduler) then
      FSubscriber.OnError(E)
    else begin
      Contract := TContractImpl<T>.Create;
      Contract.SetSubscriber(FSubscriber);
      FScheduler.Invoke(TOnErrorAction<T>.Create(E, Contract));
    end;
    FSubscriber.Unsubscribe;
    FSubscriber := nil;
  end;
end;

procedure TSubscriberDecorator<T>.OnNext(const A: T);
var
  Contract: TContractImpl<T>;
begin
  if Assigned(FSubscriber) then begin
    // work through contract protect from memory leaks
    Contract := TContractImpl<T>.Create;
    Contract.SetSubscriber(FSubscriber);
    FScheduler.Invoke(TOnNextAction<T>.Create(A, Contract));
  end;
end;

{ TFromSbscriptionImpl<T> }

constructor TFromSbscriptionImpl<T>.Create(Observable: IObservable<T>;
  const OnNext: TOnNext; const OnError: TOnError;
  const OnCompleted: TOnCompleted);
begin
  inherited Create;
  FObservable := Observable;
  FOnNext := OnNext;
  FOnError := OnError;
  FOnCompleted := OnCompleted;
end;

function TFromSbscriptionImpl<T>.GetObservable: IObservable<T>;
begin
  Lock;
  Result := FObservable;
  Unlock;
end;

procedure TFromSbscriptionImpl<T>.Lock;
begin
  FLock.Acquire;
end;

procedure TFromSbscriptionImpl<T>.OnCompleted;
begin
  Lock;
  try
    if not IsUnsubscribed and Assigned(FOnCompleted) then begin
      FOnCompleted;
      Unsubscribe;
    end;
  finally
    Unlock;
  end;
end;

procedure TFromSbscriptionImpl<T>.OnError(E: IThrowable);
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

procedure TFromSbscriptionImpl<T>.OnNext(const A: T);
begin
  Lock;
  try
    if not IsUnsubscribed and Assigned(FOnNext) then
      FOnNext(A)
  finally
    Unlock;
  end;
end;

procedure TFromSbscriptionImpl<T>.Unlock;
begin
  FLock.Release;
end;

procedure TFromSbscriptionImpl<T>.UnsubscribeInterceptor;
begin
  FObservable := nil;
end;

{ TIntervalThread }

constructor TIntervalThread.Create(Subscription: ISubscriber<LongWord>;
  Delay: LongWord; InitialDelay: LongWord);
begin
  FOnTerminate := TEvent.Create(nil, True, False, '');
  inherited Create(False);
  FSubscription := Subscription;
  FDelay := Delay;
  FInitialDelay := InitialDelay;
end;

destructor TIntervalThread.Destroy;
begin
  FSubscription := nil;
  FOnTerminate.Free;
  inherited;
end;

procedure TIntervalThread.Terminate;
begin
  inherited Terminate;
  FOnTerminate.SetEvent;
end;

procedure TIntervalThread.Execute;
var
  Iter: LongWord;
begin
  Iter := 0;
  if FOnTerminate.WaitFor(FInitialDelay) = wrSignaled then begin
    Exit;
  end;
  while (not Terminated) and (not FSubscription.IsUnsubscribed) do begin
    if FOnTerminate.WaitFor(FDelay) = wrSignaled then begin
      Exit;
    end;
    FSubscription.OnNext(Iter);
    Inc(Iter);
  end
end;

{ TIntervalObserver }

constructor TIntervalObserver.Create;
begin
  inherited Create;
  FThreads := TList<TIntervalThread>.Create;
end;

destructor TIntervalObserver.Destroy;
var
  Th: TIntervalThread;
begin
  for Th in FThreads do begin
    Th.Terminate;
  end;
  for Th in FThreads do begin
    Th.WaitFor;
    Th.Free;
  end;
  FThreads.Free;
  inherited;
end;

procedure TIntervalObserver.OnSubscribe(Subscriber: ISubscriber<LongWord>);
var
  I: Integer;
  Th: TIntervalThread;
begin
  // reintroduce parent method
  // clear non-active thread pool
  for I := FThreads.Count-1 downto 0 do begin
    if FThreads[I].Terminated then begin
      FThreads[I].Free;
      FThreads.Delete(I);
    end;
  end;

  Th := TIntervalThread.Create(Subscriber, CurDelay, InitialDelay);
  FThreads.Add(Th);
end;

initialization
  RefRegistry := TRefRegistry.Create;

finalization
  RefRegistry.Free;

end.
