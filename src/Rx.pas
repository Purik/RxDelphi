unit Rx;

interface
uses SysUtils, Generics.Collections, Generics.Defaults;

type

  TimeUnit = record
  const
    MILLISECONDS = 0;
    SECONDS = 1;
    MINUTES = 2;
  end;

  IAction = interface
    procedure Emit;
  end;

  IScheduler = interface
    procedure Invoke(Action: IAction);
  end;


  StdSchedulers = record
  type

    ICurrentThreadScheduler = interface(IScheduler)
      ['{FAE0EAE9-8A6A-4675-9BCE-EC954396CABE}']
    end;

    IMainThreadScheduler = interface(IScheduler)
      ['{C35C921D-6D92-44F1-9040-02D57946EBD8}']
    end;

    ISeparateThreadScheduler = interface(IScheduler)
      ['{16C38E93-85C0-4E36-B115-81270BCD72FE}']
    end;

    INewThreadScheduler = interface(IScheduler)
      ['{BAA742F7-A5A4-44DF-81E7-7592FC9E454E}']
    end;

    IThreadPoolScheduler = interface(IScheduler)
      ['{6501AB55-3F4D-4185-B926-2BE3FB697F63}']
    end;

  const
    IMMEDIATE = 0;
  public
    class function CreateCurrentThreadScheduler: ICurrentThreadScheduler; static;
    class function CreateMainThreadScheduler: IMainThreadScheduler; static;
    class function CreateSeparateThreadScheduler: ISeparateThreadScheduler; static;
    class function CreateNewThreadScheduler: INewThreadScheduler; static;
    class function CreateThreadPoolScheduler(PoolSize: Integer): IThreadPoolScheduler; static;
  end;

  ///	<summary>
  ///   Error descriptor interface
  ///	</summary>
  IThrowable = interface
    function GetCode: Integer;
    function GetClass: TClass;
    function GetMessage: string;
    function GetStackTrace: string;
    function ToString: string;
  end;

  ///	<summary>
  ///	  Used for controlling back-pressure mechanism
  ///	  producer-consumer
  ///	</summary>
  IProducer = interface
    procedure Request(N: LongWord);
  end;

  ///	<summary>
  ///	  Base Observer interface
  ///	</summary>
  IObserver<T> = interface
    procedure OnNext(const A: T);
    procedure OnError(E: IThrowable);
    procedure OnCompleted;
  end;

  TSmartVariable<T> = record
  strict private
    FValue: T;
    FDefValue: T;
    FObjRef: IInterface;
    class function IsObject: Boolean; static;
  public
    constructor Create(const A: T);
    class operator Implicit(A: TSmartVariable<T>): T;
    class operator Implicit(A: T): TSmartVariable<T>;
    class operator Equal(A, B: TSmartVariable<T>): Boolean;
    function Get: T;
    procedure Clear;
  end;

  TZip<X, Y> = class
  strict private
    FAHolder: TSmartVariable<X>;
    FBHolder: TSmartVariable<Y>;
    function GetA: X;
    function GetB: Y;
  public
    constructor Create(const A: X; const B: Y);
    destructor Destroy; override;
    property A: X read GetA;
    property B: Y read GetB;
  end;


  ISubscription = interface
    procedure Unsubscribe;
    function IsUnsubscribed: Boolean;
    procedure SetProducer(P: IProducer);
  end;

  ISubscriber<T> = interface(IObserver<T>)
    procedure Unsubscribe;
    function IsUnsubscribed: Boolean;
    procedure SetProducer(P: IProducer);
  end;

  TOnNext<T> = reference to procedure(const A: T);
  TOnCompleted = reference to procedure;
  TOnError = reference to procedure(E: IThrowable);

  ///	<summary>
  ///	  Observable is associated to data stream,
  ///  developer may choice comfortable scheduler
  ///	</summary>
  IObservable<T> = interface
    function Subscribe(const OnNext: TOnNext<T>): ISubscription; overload;
    function Subscribe(const OnNext: TOnNext<T>; const OnError: TOnError): ISubscription; overload;
    function Subscribe(const OnNext: TOnNext<T>; const OnError: TOnError; const OnCompleted: TOnCompleted): ISubscription; overload;
    function Subscribe(const OnNext: TOnNext<T>; const OnCompleted: TOnCompleted): ISubscription; overload;
    function Subscribe(const OnError: TOnError): ISubscription; overload;
    function Subscribe(const OnCompleted: TOnCompleted): ISubscription; overload;
    function Subscribe(A: ISubscriber<T>): ISubscription; overload;
    procedure OnNext(const Data: T);
    procedure OnError(E: IThrowable);
    procedure OnCompleted;
    procedure ScheduleOn(Scheduler: IScheduler);
    procedure SetName(const Value: string);
  end;


  TFilter<T> = reference to function(const A: T): Boolean;
  TFilterStatic<T> = function(const A: T): Boolean;
  TMap<X, Y> = reference to function(const Data: X): Y;
  TMapStatic<X, Y> = function(const Data: X): Y;
  TOnSubscribe<T> = reference to procedure(O: IObserver<T>);
  TOnSubscribe2<T> = reference to procedure(O: ISubscriber<T>);
  TFlatMap<X, Y> = reference to function(const Data: X): IObservable<Y>;
  TFlatMapStatic<X, Y> = function(const Data: X): IObservable<Y>;
  TFlatMapIterable<T> = reference to function(const Data: T): IObservable<T>;
  TFlatMapIterableStatic<T> = reference to function(const Data: T): IObservable<T>;
  TDefer<T> = reference to function: IObservable<T>;
  TArrayOfRefs = array of IInterface;

  TScanRoutine<CTX, T> = reference to procedure(var Context: CTX; const Value: T);
  TReduceRoutine<ACCUM, T> = reference to function(const A: ACCUM; const Value: T): ACCUM;
  TCollectAction1<ITEM, T> = reference to procedure(const List: TList<ITEM>; const Value: T);
  TCollectAction2<KEY, ITEM, T> = reference to procedure(const Dict: TDictionary<KEY, ITEM>; const Value: T);

  IFlatMapObservable<X, Y> = interface(IObservable<Y>)
    procedure Spawn(const Routine: TFlatMap<X, Y>); overload;
    procedure Spawn(const Routine: TFlatMapStatic<X, Y>); overload;
    procedure SetMaxConcurrency(Value: Integer);
  end;

  IFlatMapIterableObservable<T> = interface(IObservable<T>)
    procedure Spawn(const Routine: TFlatMapIterable<T>); overload;
    procedure Spawn(const Routine: TFlatMapIterableStatic<T>); overload;
    procedure SetMaxConcurrency(Value: Integer);
  end;

  ///	<summary>
  ///  Abstract data flow, that give ability to get powerfull set of
  ///  operations and data type transformation.
  ///
  ///  - Avoid single data approach, keep in mind data streams
  ///  - implicit infrastructure, including Garbage collector for class instances
  ///    giving ability to spend low time for developing scalable multithreading
  ///    code
  ///
  /// </summary>
  TObservable<T> = record
  type
    TList = TList<T>;
  strict private
    Impl: IObservable<T>;
    Refs: TArrayOfRefs;
    FlatStreams: TArrayOfRefs;
    FFlatStreamKeys: array of string;
    FlatIterable: IFlatMapIterableObservable<T>;
    function GetImpl: IObservable<T>;
    function GetFlatStream<Y>: IFlatMapObservable<T, Y>;
    function GetFlatIterable: IFlatMapIterableObservable<T>;
  public
    ///	<summary>
    ///	  <para>
    ///	    OnSubscribe run on every new Subscription
    ///	  </para>
    ///	  <para>
    ///	    Powerfull method of Observable creation
    ///	  </para>
    ///	</summary>
    constructor Create(const OnSubscribe: TOnSubscribe<T>); overload;
    constructor Create(const OnSubscribe: TOnSubscribe2<T>); overload;

    ///	<summary>
    ///	  Make Observable, that raise pre-known data sequence
    ///	</summary>
    constructor Just(const Items: array of TSmartVariable<T>); overload;

    ///	<summary>
    ///	  Make Observable, that raise OnCompleted and nothing else
    ///	</summary>
    class function Empty: TObservable<T>; static;

    ///	<summary>
    ///	  Defer don't make new observable, but give ability to
    ///  define creation mechanism in the future, when any subscriber will appear
    ///	</summary>
    constructor Defer(const Routine: TDefer<T>);

    ///	<summary>
    ///	  Just sort of Observable will never raise anithing (usefull for testing purposes).
    ///	</summary>
    class function Never: TObservable<T>; static;

    ///	<summary>
    ///	  Merge N data streams
    ///	</summary>
    constructor Merge(var O1, O2: TObservable<T>); overload;
    constructor Merge(var O1, O2, O3: TObservable<T>); overload;

    function Subscribe(const OnNext: TOnNext<T>): ISubscription; overload;
    function Subscribe(const OnNext: TOnNext<T>; const OnError: TOnError): ISubscription; overload;
    function Subscribe(const OnNext: TOnNext<T>; const OnError: TOnError; const OnCompleted: TOnCompleted): ISubscription; overload;
    function Subscribe(const OnNext: TOnNext<T>; const OnCompleted: TOnCompleted): ISubscription; overload;
    function Subscribe(const OnError: TOnError): ISubscription; overload;
    function Subscribe(const OnCompleted: TOnCompleted): ISubscription; overload;
    function Subscribe(Subscriber: ISubscriber<T>): ISubscription; overload;

    ///	<summary>
    ///  Set scheduler for producing data flow to subscribers - upstream scheduling
    ///	</summary>
    procedure ScheduleOn(Scheduler: IScheduler);

    (* Операции над последовательностями *)

    ///	<summary>
    ///	  Mapping data type
    ///	</summary>
    function Map<Y>(const Routine: TMap<T, Y>): TObservable<Y>; overload;
    function Map<Y>(const Routine: TMapStatic<T, Y>): TObservable<Y>; overload;
    function Map(const Routine: TMap<T, T>): TObservable<T>; overload;
    function Map(const Routine: TMapStatic<T, T>): TObservable<T>; overload;

    ///	<summary>
    ///  Keep in mind: streams must be synchronized. Observable caching data
    ///	</summary>
    function Zip<Y>(var O: TObservable<Y>): TObservable<TZip<T, Y>>; overload;

    ///	<summary>
    ///  Speed of output stream is equal to speed of the Fastest one in couple
    ///	</summary>
    function CombineLatest<Y>(var O: TObservable<Y>): TObservable<TZip<T, Y>>; overload;

    ///	<summary>
    ///  Speed of output stream is equal to speed of the slowest one in couple
    ///	</summary>
    function WithLatestFrom<Y>(var Slow: TObservable<Y>): TObservable<TZip<T, Y>>; overload;

    ///	<summary>
    ///  Output stream accept items that was first, then items from
    ///  other streams are ignored until next iteration
    ///	</summary>
    function AMB<Y>(var O: TObservable<Y>): TObservable<TZip<T, Y>>; overload;
    function AMBWith<Y>(var Slow: TObservable<Y>): TObservable<TZip<T, Y>>; overload;
    //
    // Mathematical and Aggregate Operators
    function Scan<CTX>(const Initial: TSmartVariable<CTX>; const Scan: TScanRoutine<CTX, T>): TObservable<CTX>; overload;
    function Scan(const Initial: TSmartVariable<T>; const Scan: TScanRoutine<T, T>): TObservable<T>; overload;
    function Reduce<ACCUM>(const Reduce: TReduceRoutine<ACCUM, T>): TObservable<ACCUM>; overload;
    function Reduce(const Reduce: TReduceRoutine<T, T>): TObservable<T>; overload;

    function Collect<ITEM>(const Initial: array of TSmartVariable<ITEM>; const Action: TCollectAction1<ITEM, T>): TObservable<TList<ITEM>>; overload;
    function Collect<KEY, ITEM>(const Action: TCollectAction2<KEY, ITEM, T>): TObservable<TDictionary<KEY, ITEM>>; overload;
    function Distinct(Comparer: IComparer<T>): TObservable<T>; overload;

    ///	<summary>
    ///  Limit output stream to first Count items, then raise OnCompleted
    ///	</summary>
    function Take(Count: Integer): TObservable<T>;

    ///	<summary>
    ///   Raise only last Count items
    ///	</summary>
    function TakeLast(Count: Integer): TObservable<T>;


    ///	<summary>
    ///	  Skip first Count items
    ///	</summary>
    function Skip(Count: Integer): TObservable<T>;

    ///	<summary>
    ///	  The output stream will produce values with delay.
    //    Values are implicitly cached, this must be taken into account to avoid out-of-memory.
    ///	</summary>
    ///	<remarks>
    ///  The timer runs in a separate thread, this must be taken into account.
    ///  Use the Sheduler if you want to redirect the events to context
    ///  other threads.
    ///	</remarks>
    function Delay(aDelay: LongWord; aTimeUnit: LongWord = TimeUnit.SECONDS): TObservable<T>; overload;

    ///	<summary>
    ///	  Filtering
    ///	</summary>
    function Filter(const Routine: TFilter<T>): TObservable<T>; overload;
    function Filter(const Routine: TFilterStatic<T>): TObservable<T>; overload;

    ///	<summary>
    /// Transform a single value into a stream. Flows can work in
    /// context of different threads, to limit the speed of parallel
    /// streams, you can specify the MaxConcurrent parameter that specifies the value
    /// semaphore for competently working threads.
    ///	</summary>
    function FlatMap<Y>(const Routine: TFlatMap<T, Y>; const MaxConcurrent: LongWord=0): TObservable<Y>; overload;
    function FlatMap<Y>(const Routine: TFlatMapStatic<T, Y>; const MaxConcurrent: LongWord=0): TObservable<Y>; overload;
    function FlatMapIterable(const Routine: TFlatMapIterable<T>; const MaxConcurrent: LongWord=0): TObservable<T>; overload;
    function FlatMapIterable(const Routine: TFlatMapIterableStatic<T>; const MaxConcurrent: LongWord=0): TObservable<T>; overload;

    ///	<summary>
    ///	  Usefull constructors
    ///	</summary>
    class function From(Other: IObservable<T>): TObservable<T>; overload; static;
    class function From(Collection: IEnumerable<TSmartVariable<T>>): TObservable<T>; overload; static;
    class function From(Collection: TEnumerable<TSmartVariable<T>>): TObservable<T>; overload; static;

    ///	<summary>
    /// Call OnNext, OnError, Oncompleted directly, but not
    /// it is desirable, this is a bad practice.
    ///	</summary>
    procedure OnNext(const Data: T);
    procedure OnError(E: IThrowable);
    procedure OnCompleted;

    ///	<summary>
    ///	  Intercept an exception and notify all subscribers
    ///	</summary>
    procedure Catch;

    class operator Implicit(var A: TObservable<T>): IObservable<T>;
    class operator Implicit(A: IObservable<T>): TObservable<T>;

    // debug-only purposes
    procedure SetName(const Value: string);
  end;


  Observable = record
    // Zip
    class function Zip<A, B>(var OA: TObservable<A>; var OB: TObservable<B>): TObservable<TZip<A, B>>; overload; static;
    class function Zip<A, B>(var OA: TObservable<A>; var OB: TObservable<B>;
      const OnNext: TOnNext<TZip<A, B>>): TObservable<TZip<A, B>>; overload; static;
    class function Zip<A, B>(var OA: TObservable<A>; var OB: TObservable<B>;
      const OnNext: TOnNext<TZip<A, B>>; const OnCompleted: TOnCompleted): TObservable<TZip<A, B>>; overload; static;

    // CombineLatest
    class function CombineLatest<A, B>(var OA: TObservable<A>; var OB: TObservable<B>): TObservable<TZip<A, B>>; static;

    // WithLatestFrom
    class function WithLatestFrom<A, B>(var Fast: TObservable<A>; var Slow: TObservable<B>): TObservable<TZip<A, B>>; overload; static;
    class function WithLatestFrom<A, B>(var Fast: TObservable<A>; var Slow: TObservable<B>;
      const OnNext: TOnNext<TZip<A, B>>): TObservable<TZip<A, B>>; overload; static;
    class function WithLatestFrom<A, B>(var Fast: TObservable<A>; var Slow: TObservable<B>;
      const OnNext: TOnNext<TZip<A, B>>; const OnCompleted: TOnCompleted): TObservable<TZip<A, B>>; overload; static;

    // AMB
    class function AMB<A, B>(var OA: TObservable<A>; var OB: TObservable<B>): TObservable<TZip<A, B>>; overload; static;
    class function AMBWith<A, B>(var Fast: TObservable<A>; var Slow: TObservable<B>): TObservable<TZip<A, B>>; overload; static;
    class function AMBWith<A, B>(var Fast: TObservable<A>; var Slow: TObservable<B>;
      const OnNext: TOnNext<TZip<A, B>>): TObservable<TZip<A, B>>; overload; static;
    class function AMBWith<A, B>(var Fast: TObservable<A>; var Slow: TObservable<B>;
      const OnNext: TOnNext<TZip<A, B>>; const OnCompleted: TOnCompleted): TObservable<TZip<A, B>>; overload; static;

    // usefull calls
    ///	<summary>
    ///  Start the intervals. The counter works in the separate thread, it's necessary
    ///   consider.
    ///	</summary>
    class function Interval(Delay: LongWord; aTimeUnit: LongWord = TimeUnit.SECONDS): TObservable<LongWord>; overload; static;
    class function IntervalDelayed(InitialDelay: LongWord; Delay: LongWord; aTimeUnit: LongWord = TimeUnit.SECONDS): TObservable<LongWord>; overload; static;

    ///	<summary>
    ///	  Rx-style counters
    ///	</summary>
    class function Range(Start, Stop: Integer; Step: Integer=1): TObservable<Integer>; static;

    ///	<summary>
    /// Catch an exception
    /// (we assume that the call occurs inside the except ... end block)
    /// and fix the information about it in IThrowable
    ///	</summary>
    class function CatchException: IThrowable; static;
  end;

  TArrayOfRefsHelper = record helper for TArrayOfRefs
  strict private
    function FindIndex(A: IInterface): Integer;
  public
    procedure Append(A: IInterface);
    function  Contains(A: IInterface): Boolean;
    procedure Remove(A: IInterface);
  end;


implementation
uses Rx.Subjects, Rx.Observable.Just, Rx.Observable.Empty, Rx.Observable.Defer,
  Rx.Observable.Never, Rx.Observable.Filter, Rx.Observable.Map,
  Rx.Observable.Zip, TypInfo, Rx.Implementations, Rx.Observable.Take,
  Rx.Schedulers, Rx.Observable.FlatMap, Rx.Observable.Delay,
  Rx.Observable.AdvancedOps;

type

  TThrowableImpl = class(TInterfacedObject, IThrowable)
  strict private
    FCode: Integer;
    FClass: TClass;
    FMessage: string;
    FStackTrace: string;
    FToString: string;
  public
    constructor Create(E: Exception);
    function GetCode: Integer;
    function GetClass: TClass;
    function GetMessage: string;
    function GetStackTrace: string;
    function ToString: string; reintroduce;
  end;

  TIntervalObserverPImpl = class(TIntervalObserver);

{ TThrowableImpl }

constructor TThrowableImpl.Create(E: Exception);
begin
  FCode := 0;
  FClass := E.ClassType;
  FMessage := E.Message;
  FStackTrace := E.StackTrace;
  FToString := E.ToString;
end;

function TThrowableImpl.GetClass: TClass;
begin
  Result := FClass;
end;

function TThrowableImpl.GetCode: Integer;
begin
  Result := FCode;
end;

function TThrowableImpl.GetMessage: string;
begin
  Result := FMessage;
end;

function TThrowableImpl.GetStackTrace: string;
begin
  Result := FStackTrace;
end;

function TThrowableImpl.ToString: string;
begin
  Result := FToString;
end;

{ TObservable<T> }


function TObservable<T>.AMB<Y>(var O: TObservable<Y>): TObservable<TZip<T, Y>>;
var
  Joiner: TJoiner<T, Y>;
  Impl: TZipObserver<TZip<T, Y>>;
begin
  Impl := TZipObserver<TZip<T, Y>>.Create;
  Joiner := TJoiner<T, Y>.Create(Self.GetImpl, O.GetImpl,
    Impl.OnNextIcp, Impl.OnError, Impl.OnCompleted);
  Joiner.Strategy := TAMBStrategy<T, Y>.Create;
  Impl.Setup(Joiner);
  Result.Impl := Impl;
  Refs.Append(Result.Impl);
end;

function TObservable<T>.AMBWith<Y>(var Slow: TObservable<Y>): TObservable<TZip<T, Y>>;
var
  Joiner: TJoiner<T, Y>;
  Impl: TZipObserver<TZip<T, Y>>;
begin
  Impl := TZipObserver<TZip<T, Y>>.Create;
  Joiner := TJoiner<T, Y>.Create(Self.GetImpl, Slow.GetImpl,
    Impl.OnNextIcp, Impl.OnError, Impl.OnCompleted);
  Joiner.Strategy := TAMBWithStrategy<T, Y>.Create(fsA);
  Impl.Setup(Joiner);
  Result.Impl := Impl;
  Refs.Append(Result.Impl);
end;

procedure TObservable<T>.Catch;
var
  E: IThrowable;
begin
  E := Observable.CatchException;
  if Assigned(E) then
    GetImpl.OnError(E)
end;

function TObservable<T>.Collect<ITEM>(
  const Initial: array of TSmartVariable<ITEM>;
  const Action: TCollectAction1<ITEM, T>): TObservable<TList<ITEM>>;
var
  ItitialList: TList<TSmartVariable<Item>>;
  I: Integer;
begin
  ItitialList := TList<TSmartVariable<Item>>.Create;
  for I := 0 to High(Initial) do
    ItitialList.Add(Initial[I]);
  Result := TCollect1Observable<ITEM, T>.Create(GetImpl, ItitialList, Action);
  Result := Result.TakeLast(1);
end;

function TObservable<T>.Collect<KEY, ITEM>(
 const Action: TCollectAction2<KEY, ITEM, T>): TObservable<TDictionary<KEY, ITEM>>;
begin
  Result := TCollect2Observable<KEY, ITEM, T>.Create(GetImpl, nil, Action);
  Result := Result.TakeLast(1);
end;

function TObservable<T>.CombineLatest<Y>(
  var O: TObservable<Y>): TObservable<TZip<T, Y>>;
var
  Joiner: TJoiner<T, Y>;
  Impl: TZipObserver<TZip<T, Y>>;
begin
  Impl := TZipObserver<TZip<T, Y>>.Create;
  Joiner := TJoiner<T, Y>.Create(Self.GetImpl, O.GetImpl,
    Impl.OnNextIcp, Impl.OnError, Impl.OnCompleted);
  Joiner.Strategy := TCombineLatestStrategy<T, Y>.Create;
  Impl.Setup(Joiner);
  Result.Impl := Impl;
  Refs.Append(Result.Impl);
end;

constructor TObservable<T>.Create(const OnSubscribe: TOnSubscribe2<T>);
begin
  Impl := TPublishSubject<T>.Create(OnSubscribe);
end;

constructor TObservable<T>.Create(const OnSubscribe: TOnSubscribe<T>);
begin
  Impl := TPublishSubject<T>.Create(OnSubscribe);
end;

constructor TObservable<T>.Defer(const Routine: TDefer<T>);
begin
  Impl := Rx.Observable.Defer.TDefer<T>.Create(Routine);
end;

function TObservable<T>.Delay(aDelay, aTimeUnit: LongWord): TObservable<T>;
begin
  Result := TDelay<T>.Create(GetImpl, aDelay, aTimeUnit);
end;

function TObservable<T>.Distinct(Comparer: IComparer<T>): TObservable<T>;
begin

end;

class function TObservable<T>.Empty: TObservable<T>;
begin
  Result.Impl := TEmpty<T>.Create;
end;

function TObservable<T>.Filter(const Routine: TFilter<T>): TObservable<T>;
begin
  Result.Impl := Rx.Observable.Filter.TFilter<T>.Create(GetImpl, Routine);
  Refs.Append(Result.Impl);
end;

function TObservable<T>.Filter(const Routine: TFilterStatic<T>): TObservable<T>;
begin
  Result.Impl := Rx.Observable.Filter.TFilter<T>.CreateStatic(GetImpl, Routine);
  Refs.Append(Result.Impl);
end;

function TObservable<T>.FlatMap<Y>(const Routine: TFlatMap<T, Y>; const MaxConcurrent: LongWord): TObservable<Y>;
var
  O: IFlatMapObservable<T, Y>;
begin
  O := GetFlatStream<Y>;
  O.Spawn(Routine);
  O.SetMaxConcurrency(MaxConcurrent);
  Result.Impl := O;
end;

function TObservable<T>.FlatMap<Y>(const Routine: TFlatMapStatic<T, Y>;
  const MaxConcurrent: LongWord): TObservable<Y>;
var
  O: IFlatMapObservable<T, Y>;
begin
  O := GetFlatStream<Y>;
  O.Spawn(Routine);
  O.SetMaxConcurrency(MaxConcurrent);
  Result.Impl := O;
end;

function TObservable<T>.FlatMapIterable(
  const Routine: TFlatMapIterableStatic<T>;
  const MaxConcurrent: LongWord): TObservable<T>;
var
  O: IFlatMapIterableObservable<T>;
begin
  O := GetFlatIterable;
  O.Spawn(Routine);
  O.SetMaxConcurrency(MaxConcurrent);
  Result.Impl := O;
end;

function TObservable<T>.FlatMapIterable(
  const Routine: TFlatMapIterable<T>; const MaxConcurrent: LongWord): TObservable<T>;
var
  O: IFlatMapIterableObservable<T>;
begin
  O := GetFlatIterable;
  O.Spawn(Routine);
  O.SetMaxConcurrency(MaxConcurrent);
  Result.Impl := O;
end;

class function TObservable<T>.From(Collection: TEnumerable<TSmartVariable<T>>): TObservable<T>;
begin
  Result := TObservable<T>.Just(Collection.ToArray);
end;

class function TObservable<T>.From(Collection: IEnumerable<TSmartVariable<T>>): TObservable<T>;
begin
  Result.Impl := TJust<T>.Create(Collection);
end;

class function TObservable<T>.From(Other: IObservable<T>): TObservable<T>;
begin
  Result.Impl := Other;
end;

function TObservable<T>.GetFlatIterable: IFlatMapIterableObservable<T>;
begin
  if not Assigned(FlatIterable) then
    FlatIterable := Rx.Observable.FlatMap.TFlatMapIterableImpl<T>.Create(GetImpl);
  Result := FlatIterable
end;

function TObservable<T>.GetFlatStream<Y>: IFlatMapObservable<T, Y>;
var
  Key: string;
  ti: PTypeInfo;
  I: Integer;
begin
  ti := TypeInfo(Y);
  Key := string(ti.Name);
  for I := 0 to High(FFlatStreamKeys) do
    if Key = FFlatStreamKeys[I] then
      Exit(IFlatMapObservable<T, Y>(FlatStreams[I]));
  Result := Rx.Observable.FlatMap.TFlatMap<T,Y>.Create(GetImpl);
  SetLength(FFlatStreamKeys, Length(FFlatStreamKeys)+1);
  FlatStreams.Append(Result);
end;

function TObservable<T>.GetImpl: IObservable<T>;
begin
  if not Assigned(Impl) then
    Impl := TPublishSubject<T>.Create;
  Result := Impl;
end;

class operator TObservable<T>.Implicit(A: IObservable<T>): TObservable<T>;
begin
  Result.Impl := A;
end;

class operator TObservable<T>.Implicit(var A: TObservable<T>): IObservable<T>;
begin
  Result := A.GetImpl
end;

constructor TObservable<T>.Just(const Items: array of TSmartVariable<T>);
begin
  Impl := TJust<T>.Create(Items);
end;

function TObservable<T>.Map(const Routine: TMap<T, T>): TObservable<T>;
begin
  Result.Impl := Rx.Observable.Map.TMap<T, T>.Create(GetImpl, Routine);
  Refs.Append(Result.Impl);
end;

function TObservable<T>.Map(const Routine: TMapStatic<T, T>): TObservable<T>;
begin
  Result.Impl := Rx.Observable.Map.TMap<T, T>.CreateStatic(GetImpl, Routine);
  Refs.Append(Result.Impl);
end;

function TObservable<T>.Map<Y>(const Routine: TMapStatic<T, Y>): TObservable<Y>;
begin
  Result.Impl := Rx.Observable.Map.TMap<T, Y>.CreateStatic(GetImpl, Routine);
  Refs.Append(Result.Impl);
end;

function TObservable<T>.Map<Y>(const Routine: TMap<T, Y>): TObservable<Y>;
begin
  Result.Impl := Rx.Observable.Map.TMap<T, Y>.Create(GetImpl, Routine);
  Refs.Append(Result.Impl);
end;

constructor TObservable<T>.Merge(var O1, O2, O3: TObservable<T>);
var
  Impl_: TPublishSubject<T>;
  O1_, O2_, O3_: IObservable<T>;
begin
  Impl_ := TPublishSubject<T>.Create;
  O1_ := O1.GetImpl;
  O2_ := O2.GetImpl;
  O3_ := O3.GetImpl;
  Impl_.Merge(O1_);
  Impl_.Merge(O2_);
  Impl_.Merge(O3_);
  Impl := Impl_;
end;

constructor TObservable<T>.Merge(var O1, O2: TObservable<T>);
var
  Impl_: TPublishSubject<T>;
  O1_, O2_: IObservable<T>;
begin
  Impl_ := TPublishSubject<T>.Create;
  O1_ := O1.GetImpl;
  O2_ := O2.GetImpl;
  Impl_.Merge(O1_);
  Impl_.Merge(O2_);
  Impl := Impl_;
end;

class function TObservable<T>.Never: TObservable<T>;
begin
  Result.Impl := TNever<T>.Create;
end;

procedure TObservable<T>.OnCompleted;
begin
  GetImpl.OnCompleted
end;

procedure TObservable<T>.OnError(E: IThrowable);
begin
  GetImpl.OnError(E)
end;

procedure TObservable<T>.OnNext(const Data: T);
begin
  GetImpl.OnNext(Data)
end;

function TObservable<T>.Reduce(
  const Reduce: TReduceRoutine<T, T>): TObservable<T>;
begin
  Result := TReduceObservable<T, T>.Create(GetImpl, Reduce);
  Result := Result.TakeLast(1);
end;

function TObservable<T>.Reduce<ACCUM>(
  const Reduce: TReduceRoutine<ACCUM, T>): TObservable<ACCUM>;
begin
  Result := TReduceObservable<ACCUM, T>.Create(GetImpl, Reduce);
  Result := Result.TakeLast(1);
end;

function TObservable<T>.Subscribe(const OnError: TOnError): ISubscription;
begin
  Result := GetImpl.Subscribe(OnError);
end;

function TObservable<T>.Scan(const Initial: TSmartVariable<T>;
  const Scan: TScanRoutine<T, T>): TObservable<T>;
begin
  Result := TScanObservable<T, T>.Create(GetImpl, Initial, Scan);
end;

function TObservable<T>.Scan<CTX>(const Initial: TSmartVariable<CTX>;
  const Scan: TScanRoutine<CTX, T>): TObservable<CTX>;
begin
  Result := TScanObservable<CTX, T>.Create(GetImpl, Initial, Scan);
end;

procedure TObservable<T>.ScheduleOn(Scheduler: IScheduler);
begin
  GetImpl.ScheduleOn(Scheduler)
end;

procedure TObservable<T>.SetName(const Value: string);
begin
  GetImpl.SetName(Value);
end;

function TObservable<T>.Skip(Count: Integer): TObservable<T>;
begin
  Result.Impl := Rx.Observable.Take.TSkip<T>.Create(GetImpl, Count);
  Refs.Append(Result.Impl);
end;

function TObservable<T>.Subscribe(
  const OnCompleted: TOnCompleted): ISubscription;
begin
  Result := GetImpl.Subscribe(OnCompleted);
end;

function TObservable<T>.Subscribe(const OnNext: TOnNext<T>;
  const OnCompleted: TOnCompleted): ISubscription;
begin
  Result := GetImpl.Subscribe(OnNext, OnCompleted);
end;

function TObservable<T>.Subscribe(const OnNext: TOnNext<T>;
  const OnError: TOnError): ISubscription;
begin
  Result := GetImpl.Subscribe(OnNext, OnError);
end;

function TObservable<T>.Subscribe(const OnNext: TOnNext<T>;
  const OnError: TOnError; const OnCompleted: TOnCompleted): ISubscription;
begin
  Result := GetImpl.Subscribe(OnNext, OnError, OnCompleted);
end;

function TObservable<T>.Subscribe(const OnNext: TOnNext<T>): ISubscription;
begin
  Result := GetImpl.Subscribe(OnNext);
end;

function TObservable<T>.Zip<Y>(
  var O: TObservable<Y>): TObservable<TZip<T, Y>>;
var
  Joiner: TJoiner<T, Y>;
  Impl: TZipObserver<TZip<T, Y>>;
begin
  Impl := TZipObserver<TZip<T, Y>>.Create;
  Joiner := TJoiner<T, Y>.Create(Self.GetImpl, O.GetImpl,
    Impl.OnNextIcp, Impl.OnError, Impl.OnCompleted);
  Joiner.Strategy := TSyncStrategy<T, Y>.Create;
  Impl.Setup(Joiner);
  Result.Impl := Impl;
  Refs.Append(Result.Impl);
end;

function TObservable<T>.Subscribe(Subscriber: ISubscriber<T>): ISubscription;
begin
  Result := GetImpl.Subscribe(Subscriber);
end;

function TObservable<T>.Take(Count: Integer): TObservable<T>;
begin
  Result.Impl := Rx.Observable.Take.TTake<T>.Create(GetImpl, Count);
  Refs.Append(Result.Impl);
end;

function TObservable<T>.TakeLast(Count: Integer): TObservable<T>;
begin
  Result.Impl := Rx.Observable.Take.TTakeLast<T>.Create(GetImpl, Count);
  Refs.Append(Result.Impl);
end;

function TObservable<T>.WithLatestFrom<Y>(
  var Slow: TObservable<Y>): TObservable<TZip<T, Y>>;
var
  Joiner: TJoiner<T, Y>;
  Impl: TZipObserver<TZip<T, Y>>;
begin
  Impl := TZipObserver<TZip<T, Y>>.Create;
  Joiner := TJoiner<T, Y>.Create(Self.GetImpl, Slow.GetImpl,
    Impl.OnNextIcp, Impl.OnError, Impl.OnCompleted);
  Joiner.Strategy := TWithLatestFromStrategy<T, Y>.Create(fsA);
  Impl.Setup(Joiner);
  Result.Impl := Impl;
  Refs.Append(Result.Impl);
end;

{ TSmartVariable<T> }

procedure TSmartVariable<T>.Clear;
begin
  FObjRef := nil;
  FValue := FDefValue
end;

constructor TSmartVariable<T>.Create(const A: T);
begin
  Self := A;
end;

class operator TSmartVariable<T>.Equal(A, B: TSmartVariable<T>): Boolean;
var
  Comp: IComparer<T>;
begin
  Comp := TComparer<T>.Default;
  Result := Comp.Compare(A.FValue, B.FValue) = 0
end;

function TSmartVariable<T>.Get: T;
var
  Obj: TObject absolute Result;
begin
  Result := FValue;
  if IsObject then
    if Assigned(FObjRef) then
      Obj := (FObjRef as IAutoRefObject).GetValue
    else
      Obj := nil
end;

class operator TSmartVariable<T>.Implicit(A: TSmartVariable<T>): T;
var
  Obj: TObject absolute Result;
begin
  if IsObject then begin
    if Assigned(A.FObjRef) then
      Obj := (A.FObjRef as IAutoRefObject).GetValue
    else
      Obj := nil;
  end
  else begin
    Result := A.FValue
  end;
end;

class operator TSmartVariable<T>.Implicit(A: T): TSmartVariable<T>;
var
  Obj: TObject absolute A;
begin
  if IsObject then
    if Assigned(Obj) then
      Result.FObjRef := TAutoRefObjectImpl.Create(Obj)
    else
      Result.FValue := A
  else begin
    Result.FValue := A
  end;
end;

class function TSmartVariable<T>.IsObject: Boolean;
var
  ti: PTypeInfo;
  ObjValuePtr: PObject;
begin
  ti := TypeInfo(T);
  Result := ti.Kind = tkClass;
end;

{ Schedulers }

class function StdSchedulers.CreateCurrentThreadScheduler: ICurrentThreadScheduler;
begin
  Result := TCurrentThreadScheduler.Create
end;

class function StdSchedulers.CreateMainThreadScheduler: IMainThreadScheduler;
begin
  Result := TMainThreadScheduler.Create
end;

class function StdSchedulers.CreateNewThreadScheduler: INewThreadScheduler;
begin
  Result := TNewThreadScheduler.Create;
end;

class function StdSchedulers.CreateSeparateThreadScheduler: ISeparateThreadScheduler;
begin
  Result := TSeparateThreadScheduler.Create
end;

class function StdSchedulers.CreateThreadPoolScheduler(PoolSize: Integer): IThreadPoolScheduler;
begin
  Result := TThreadPoolScheduler.Create(PoolSize);
end;

{ TZip<X, Y> }

constructor TZip<X, Y>.Create(const A: X; const B: Y);
begin
  FAHolder := A;
  FBHolder := B;
end;

destructor TZip<X, Y>.Destroy;
begin
  FAHolder.Clear;
  FBHolder.Clear;
  inherited;
end;

function TZip<X, Y>.GetA: X;
begin
  Result := FAHolder
end;

function TZip<X, Y>.GetB: Y;
begin
  Result := FBHolder
end;

{ TArrayOfRefsHelper }

procedure TArrayOfRefsHelper.Append(A: IInterface);
begin
  SetLength(Self, Length(Self) + 1);
  Self[High(Self)] := A;
end;

function TArrayOfRefsHelper.Contains(A: IInterface): Boolean;
begin
  Result := FindIndex(A) <> -1;
end;

function TArrayOfRefsHelper.FindIndex(A: IInterface): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(Self) do
    if Self[I] = A then
      Exit(I);
end;

procedure TArrayOfRefsHelper.Remove(A: IInterface);
var
  Index, I: Integer;
begin
  Index := FindIndex(A);
  if Index <> -1 then begin
    for I := Index+1 to High(Self) do
      Self[I-1] := Self[I];
    SetLength(Self, Length(Self)-1);
  end;
end;

{ Observable }

class function Observable.AMB<A, B>(var OA: TObservable<A>;
  var OB: TObservable<B>): TObservable<TZip<A, B>>;
begin
  Result := OA.AMB<B>(OB);
end;

class function Observable.AMBWith<A, B>(var Fast: TObservable<A>;
  var Slow: TObservable<B>): TObservable<TZip<A, B>>;
begin
  Result := Fast.AMBWith<B>(Slow);
end;

class function Observable.AMBWith<A, B>(var Fast: TObservable<A>;
  var Slow: TObservable<B>;
  const OnNext: TOnNext<TZip<A, B>>): TObservable<TZip<A, B>>;
begin
  Result := Fast.AMBWith<B>(Slow);
  Result.Subscribe(OnNext);
end;

class function Observable.AMBWith<A, B>(var Fast: TObservable<A>;
  var Slow: TObservable<B>; const OnNext: TOnNext<TZip<A, B>>;
  const OnCompleted: TOnCompleted): TObservable<TZip<A, B>>;
begin
  Result := Fast.AMBWith<B>(Slow);
  Result.Subscribe(OnNext, OnCompleted);
end;

class function Observable.CatchException: IThrowable;
var
  E: Exception;
begin
  E := Exception(ExceptObject);
  if Assigned(E) then begin
    Result := TThrowableImpl.Create(E);
  end
  else
    Result := nil;
end;

class function Observable.CombineLatest<A, B>(var OA: TObservable<A>;
  var OB: TObservable<B>): TObservable<TZip<A, B>>;
begin
  Result := OA.CombineLatest<B>(OB)
end;

class function Observable.IntervalDelayed(InitialDelay, Delay,
  aTimeUnit: LongWord): TObservable<LongWord>;
begin
  case aTimeUnit of
    TimeUnit.MILLISECONDS: begin
      TIntervalObserverPImpl.CurDelay := Delay;
      TIntervalObserverPImpl.InitialDelay := InitialDelay;
    end;
    TimeUnit.SECONDS: begin
      TIntervalObserverPImpl.CurDelay := Delay*1000;
      TIntervalObserverPImpl.InitialDelay := InitialDelay*1000;
    end;
    TimeUnit.MINUTES: begin
      TIntervalObserverPImpl.CurDelay := Delay*1000*60;
      TIntervalObserverPImpl.InitialDelay := InitialDelay*1000*60;
    end;
  end;
  Result := TIntervalObserver.Create;
end;

class function Observable.Range(Start, Stop, Step: Integer): TObservable<Integer>;
var
  L: TList<TSmartVariable<Integer>>;
  Cur: Integer;
begin
  L := TList<TSmartVariable<Integer>>.Create;
  try
    Cur := Start;
    while Cur <= Stop do begin
      L.Add(Cur);
      Inc(Cur, Step);
    end;
    Result := TObservable<Integer>.From(L);
  finally
    L.Free;
  end;
end;

class function Observable.Interval(Delay, aTimeUnit: LongWord): TObservable<LongWord>;
begin
  case aTimeUnit of
    TimeUnit.MILLISECONDS:
      TIntervalObserverPImpl.CurDelay := Delay;
    TimeUnit.SECONDS:
      TIntervalObserverPImpl.CurDelay := Delay*1000;
    TimeUnit.MINUTES:
      TIntervalObserverPImpl.CurDelay := Delay*1000*60;
  end;
  TIntervalObserverPImpl.InitialDelay := 0;
  Result := TIntervalObserver.Create;
end;

class function Observable.Zip<A, B>(var OA: TObservable<A>; var OB: TObservable<B>): TObservable<TZip<A, B>>;
begin
  Result := OA.Zip<B>(OB)
end;

class function Observable.Zip<A, B>(var OA: TObservable<A>;
  var OB: TObservable<B>;
  const OnNext: TOnNext<TZip<A, B>>): TObservable<TZip<A, B>>;
begin
  Result := Zip<A, B>(OA, OB);
  Result.Subscribe(OnNext);
end;

class function Observable.WithLatestFrom<A, B>(var Fast: TObservable<A>;
  var Slow: TObservable<B>): TObservable<TZip<A, B>>;
begin
  Result := Fast.WithLatestFrom<B>(Slow);
end;

class function Observable.WithLatestFrom<A, B>(var Fast: TObservable<A>;
  var Slow: TObservable<B>;
  const OnNext: TOnNext<TZip<A, B>>): TObservable<TZip<A, B>>;
begin
  Result := Fast.WithLatestFrom<B>(Slow);
  Result.Subscribe(OnNext);
end;

class function Observable.Zip<A, B>(var OA: TObservable<A>;
  var OB: TObservable<B>; const OnNext: TOnNext<TZip<A, B>>;
  const OnCompleted: TOnCompleted): TObservable<TZip<A, B>>;
begin
  Result := Zip<A, B>(OA, OB);
  Result.Subscribe(OnNext, OnCompleted);
end;

class function Observable.WithLatestFrom<A, B>(var Fast: TObservable<A>;
  var Slow: TObservable<B>; const OnNext: TOnNext<TZip<A, B>>;
  const OnCompleted: TOnCompleted): TObservable<TZip<A, B>>;
begin
  Result := Fast.WithLatestFrom<B>(Slow);
  Result.Subscribe(OnNext, OnCompleted);
end;

end.



