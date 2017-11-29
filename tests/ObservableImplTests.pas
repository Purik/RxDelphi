unit ObservableImplTests;

interface
uses Classes, TestFramework, Rx, Generics.Collections, SysUtils;

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


  TSmartVariableTests = class(TTestCase)
  strict private
    FLog: TList<string>;
    FStream: TList<string>;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Sane;
    procedure Clear;
    procedure Visibility;
    procedure GarbageCollection1;
    procedure GarbageCollection2;
  end;

  TSubscriptionTests = class(TTestCase)
  strict private
    FStream: TList<string>;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure OnSubscribe;
    procedure SubscriptionLeave;
    procedure OnCompleted;
    procedure OnError;
    procedure Catch;
    procedure CatchEmpty;
    procedure StreamSequence;
    procedure Unsubscribe;
  end;

  TMergeTests = class(TTestCase)
  strict private
    FStream: TList<string>;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure PassingOnNext;
    procedure PassingOnError;
  end;

  TMemoryLeaksTests = class(TTestCase)
  strict private
    FStream: TList<string>;
    FFreesLog: TList<string>;
    procedure OnItemFree;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure EmptySubscribers;
    procedure MapCase1;
    procedure MapCase2;
    procedure Zip1;
    procedure Zip2;
  end;

  TOperationsTests = class(TTestCase)
  strict private
    FStream: TList<string>;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure FilterTest1;
    procedure FilterTest2;
    procedure FilterTest3;
    procedure FilterStatic;
    procedure MapTest1;
    procedure MapTest2;
    procedure MapStatic;
    procedure Merge1;
    procedure Merge2;
    procedure Merge3;
    procedure MergeDuplex;
    procedure Defer;
    procedure Zip1;
    procedure Zip2;
    procedure CombineLatest1;
    procedure WithLatestFrom1;
    procedure AMB1;
    procedure AMBWith;
    procedure Take;
    procedure Skip;
    procedure Delay;
    procedure FlatMapSane1;
    procedure FlatMapSane2;
    procedure FlatMapStatic;
    procedure FlatMapOnSubscribe;
  end;

  TAdvancedOpsTests = class(TTestCase)
  strict private
    FStream: TList<string>;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Scan;
    procedure ScanObjects;
    procedure Reduce;
    procedure ResuceZero;
    procedure CollectWithList;
    procedure CollectWithDict;
  end;

  TConstructorTests = class(TTestCase)
  strict private
    FStream: TList<string>;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Just;
    procedure Range;
    procedure Interval;
  end;


  TSchedulersTests = class(TTestCase)
  strict private
    FStream: TList<string>;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure MainThreadScheduler1;
    procedure MainThreadScheduler2;
    procedure SeparateThreadScheduler;
    procedure NewThreadScheduler;
    procedure ThreadPoolScheduler;
  end;

  // Use class instance wrapper for detectong memory leaks
  TInteger = class
  private
    FValue: Integer;
  public
    constructor Create(Value: Integer);
    property Value: Integer read FValue write FValue;
  end;

implementation
uses SyncObjs;

procedure Setup(L: TList<string>; const Collection: array of string);
var
  S: string;
begin
  L.Clear;
  for S in Collection do
    L.Add(S);
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

{ TSubscriptionTests }

procedure TSubscriptionTests.Catch;
var
  O: TObservable<string>;
  OnNext: TOnNext<string>;
  OnError: TOnError;
begin

  OnNext := procedure(const Data: string)
  begin
    FStream.Add(Data);
  end;

  OnError := procedure(Throwable: IThrowable)
  begin
    FStream.Add(Format('error:%s(%s)', [Throwable.GetClass.ClassName, Throwable.GetMessage]));
  end;

  O.Subscribe(OnNext, OnError);
  try
    O.OnNext('1');
    O.OnNext('2');
    O.OnNext('3');
    raise ETestError.Create('test');
    O.OnNext('4');
  except
    O.Catch;
  end;

  Check(IsEqual(FStream, ['1', '2', '3', 'error:ETestError(test)']));
end;

procedure TSubscriptionTests.CatchEmpty;
var
  O: TObservable<string>;
  OnError: TOnError;
begin
  OnError := procedure(Throwable: IThrowable)
  begin
    FStream.Add(Format('error:%s(%s)', [Throwable.GetClass.ClassName, Throwable.GetMessage]));
  end;

  O.Subscribe(OnError);

  O.OnNext('1');
  O.OnNext('2');
  O.Catch;

  CheckEquals(0, FStream.Count);
end;

procedure TSubscriptionTests.OnCompleted;
var
  O: TObservable<string>;
  OnSubscribe: TOnSubscribe<string>;
  OnNext: TOnNext<string>;
  OnCompleted: TOnCompleted;
begin
  OnSubscribe := procedure(S: IObserver<string>)
  begin
    S.OnNext('1');
    S.OnNext('2');
    S.OnNext('3');
    S.OnCompleted;
    S.OnNext('4');
  end;

  OnNext := procedure(const Data: string)
  begin
    FStream.Add(Data);
  end;

  OnCompleted := procedure
  begin
    FStream.Add('completed');
  end;

  O := TObservable<string>.Create(OnSubscribe);
  O.Subscribe(OnNext, OnCompleted);

  Check(IsEqual(FStream, ['1', '2', '3', 'completed']));
end;

procedure TSubscriptionTests.OnError;
var
  O: TObservable<string>;
  OnSubscribe: TOnSubscribe<string>;
  OnNext: TOnNext<string>;
  OnError: TOnError;
begin
  OnSubscribe := procedure(S: IObserver<string>)
  begin
    S.OnNext('1');
    S.OnNext('2');
    S.OnNext('3');
    S.OnError(nil);
    S.OnNext('4');
  end;

  OnNext := procedure(const Data: string)
  begin
    FStream.Add(Data);
  end;

  OnError := procedure(Throwable: IThrowable)
  begin
    FStream.Add('error');
  end;

  O := TObservable<string>.Create(OnSubscribe);
  O.Subscribe(OnNext, OnError);

  Check(IsEqual(FStream, ['1', '2', '3', 'error']));
end;

procedure TSubscriptionTests.OnSubscribe;
var
  O: TObservable<string>;
  OnSubscribe: TOnSubscribe<string>;
  OnNext: TOnNext<string>;
begin
  OnSubscribe := procedure(S: IObserver<string>)
  begin
    S.OnNext('1');
    S.OnNext('2');
    S.OnNext('3');
  end;

  OnNext := procedure(const Data: string)
  begin
    FStream.Add(Data);
  end;

  O := TObservable<string>.Create(OnSubscribe);
  O.Subscribe(OnNext);

  Check(IsEqual(FStream, ['1', '2', '3']));
end;

procedure TSubscriptionTests.SetUp;
begin
  inherited;
  FStream := TList<string>.Create;
end;

procedure TSubscriptionTests.StreamSequence;
var
  O: TObservable<string>;
  OnNextA: TOnNext<string>;
  OnNextB: TOnNext<string>;
begin
  OnNextA := procedure(const Data: string)
  begin
    FStream.Add('A' + Data);
  end;

  OnNextB := procedure(const Data: string)
  begin
    FStream.Add('B' + Data);
  end;

  O.Subscribe(OnNextA);
  O.OnNext('1');
  O.Subscribe(OnNextB);
  O.OnNext('2');
  O.OnNext('3');
  O.OnCompleted;
  O.OnNext('4');

  Check(IsEqual(FStream, ['A1', 'A2', 'B2', 'A3', 'B3']));
end;

procedure TSubscriptionTests.SubscriptionLeave;
var
  O: TObservable<string>;
  OnSubscribe: TOnSubscribe<string>;
  OnNext: TOnNext<string>;
begin
  OnSubscribe := procedure(S: IObserver<string>)
  begin
    S.OnNext('1');
    S.OnNext('2');
    S.OnNext('3');
  end;

  OnNext := procedure(const Data: string)
  begin
    FStream.Add(Data);
  end;

  O := TObservable<string>.Create(OnSubscribe);
  O.Subscribe(OnNext);
  O.OnNext('4');
  O.OnCompleted;
  O.OnNext('5');

  Check(IsEqual(FStream, ['1', '2', '3', '4']));
end;

procedure TSubscriptionTests.TearDown;
begin
  inherited;
  FStream.Free;
end;

procedure TSubscriptionTests.Unsubscribe;
var
  O: TObservable<string>;
  OnNext: TOnNext<string>;
  Subscription: ISubscription;
begin

  OnNext := procedure(const Data: string)
  begin
    FStream.Add(Data);
  end;

  Subscription := O.Subscribe(OnNext);
  O.OnNext('1');
  O.OnNext('2');
  Subscription.Unsubscribe;
  O.OnNext('3');

  Check(IsEqual(FStream, ['1', '2']));
end;

{ TOperationsTests }

procedure TOperationsTests.AMB1;
begin

end;

procedure TOperationsTests.AMBWith;
begin

end;

procedure TOperationsTests.CombineLatest1;
var
  L: TObservable<string>;
  R: TObservable<Integer>;
  Comb: TObservable<TZip<string, Integer>>;

  OnNext: TOnNext<TZip<string, Integer>>;
  OnCompleted: TOnCompleted;

begin
  OnNext := procedure(const Data: TZip<string, Integer>)
  begin
    FStream.Add(Format('%s%d', [Data.A, Data.B]))
  end;

  OnCompleted := procedure
  begin
    FStream.Add('completed');
  end;

  Comb := L.CombineLatest<Integer>(R);
  Comb.Subscribe(OnNext, OnCompleted);

  Check(IsEqual(FStream, []));

  L.OnNext('A');
  L.OnNext('B');

  Check(IsEqual(FStream, []));

  R.OnNext(1);
  Check(IsEqual(FStream, ['B1']));

  R.OnNext(2);
  Check(IsEqual(FStream, ['B1', 'B2']));

  R.OnNext(3);
  R.OnNext(4);
  Check(IsEqual(FStream, ['B1', 'B2', 'B3', 'B4']));

  L.OnNext('C');
  Check(IsEqual(FStream, ['B1', 'B2', 'B3', 'B4', 'C4']));

  R.OnCompleted;
  Check(IsEqual(FStream, ['B1', 'B2', 'B3', 'B4', 'C4', 'completed']));

  L.OnNext('D');
  Check(IsEqual(FStream, ['B1', 'B2', 'B3', 'B4', 'C4', 'completed']));

end;

procedure TOperationsTests.Defer;
var
  Routine: TDefer<string>;
  O: TObservable<string>;
  Switch: Boolean;
  OnNext: TOnNext<string>;
  OnError: TOnError;
  OnCompleted: TOnCompleted;
  OnSubscribe1, OnSubscribe2: TOnSubscribe<string>;
begin

  OnNext := procedure(const Data: string)
  begin
    FStream.Add(Data);
  end;

  OnError := procedure(Throwable: IThrowable)
  begin
    FStream.Add('error');
  end;

  OnCompleted := procedure
  begin
    FStream.Add('completed');
  end;

  OnSubscribe1 := procedure(O: IObserver<string>)
  begin
    O.OnNext('A1');
    O.OnNext('A2');
    O.OnCompleted;
  end;

  OnSubscribe2 := procedure(O: IObserver<string>)
  begin
    O.OnNext('B1');
    O.OnNext('B2');
    O.OnError(nil);
  end;

  Routine := function: IObservable<string>
  var
    O: TObservable<string>;
  begin
    if Switch then
      O := TObservable<string>.Create(OnSubscribe1)
    else
      O := TObservable<string>.Create(OnSubscribe2);

    Result := O;
  end;

  O := TObservable<string>.Defer(Routine);

  // case 1
  try
    Switch := True;
    O.Subscribe(OnNext, OnError, OnCompleted);
    Check(IsEqual(FStream, ['A1', 'A2', 'completed']));

    FStream.Clear;

    // case 2
    Switch := False;
    O.Subscribe(OnNext, OnError, OnCompleted);
    Check(IsEqual(FStream, ['B1', 'B2', 'error']));

  finally
    OnSubscribe1 := nil;
    OnSubscribe2 := nil;
  end
end;

procedure TOperationsTests.Delay;
var
  O: TObservable<string>;
  E: TEvent;
  OnSubscribe: TOnSubscribe<string>;
  OnCompleted: TOnCompleted;
  OnNext: TOnNext<string>;
  Stamps: array of TDateTime;
  S: string;
  I, Val: Integer;
begin
  OnSubscribe := procedure(O: IObserver<string>)
  begin
    O.OnNext('0');
    O.OnNext('1');
    O.OnNext('2');
    O.OnCompleted;
  end;

  OnNext := procedure(const Data: string)
  var
    S: string;
  begin
    S := TimeToStr(Now*1000);
    FStream.Add(Format('%s_%s', [Data, S]));
  end;

  OnCompleted := procedure
  begin
    E.SetEvent;
  end;

  E := TEvent.Create;
  try
    O := TObservable<string>.Create(OnSubscribe);
    O.Delay(100, TimeUnit.MILLISECONDS).Subscribe(OnNext, OnCompleted);
    Check(E.WaitFor(500) = wrSignaled);
    CheckEquals(3, FStream.Count);
    SetLength(Stamps, FStream.Count);
    for I := 0 to FStream.Count-1 do begin
      Val := StrToInt(Copy(FStream[I], 1, 1));
      CheckEquals(I, Val);
      S := Copy(FStream[I], 3, Length(FStream[I])-2);
      Stamps[I] := StrToTime(S);
    end;
    for I := 0 to FStream.Count-2 do begin
      Check(Stamps[I+1] > Stamps[I]);
    end;
  finally
    E.Free
  end
end;

function FilterRoutine(const Data: string): Boolean;
begin
  Result := Data[1] = '*'
end;

procedure TOperationsTests.FilterStatic;
var
  O, FilterObs: TObservable<string>;
  OnSubscribe: TOnSubscribe<string>;
  OnNext: TOnNext<string>;
begin
  OnSubscribe := procedure(S: IObserver<string>)
  begin
    S.OnNext('1');
    S.OnNext('*2');
    S.OnNext('3');
    S.OnNext('*4');
    S.OnCompleted;
    S.OnNext('*5');
  end;

  OnNext := procedure(const Data: string)
  begin
    FStream.Add(Data);
  end;

  O := TObservable<string>.Create(OnSubscribe);
  FilterObs := O.Filter(FilterRoutine);
  FilterObs.Subscribe(OnNext);

  Check(IsEqual(FStream, ['*2', '*4']));
end;

procedure TOperationsTests.FilterTest1;
var
  O, FilterObs: TObservable<string>;
  OnSubscribe: TOnSubscribe<string>;
  Routine: TFilter<string>;
  OnNext: TOnNext<string>;
begin
  OnSubscribe := procedure(S: IObserver<string>)
  begin
    S.OnNext('1');
    S.OnNext('*2');
    S.OnNext('3');
    S.OnNext('*4');
    S.OnCompleted;
    S.OnNext('*5');
  end;

  OnNext := procedure(const Data: string)
  begin
    FStream.Add(Data);
  end;

  Routine := function(const Data: string): Boolean
  begin
    Result := Data[1] = '*'
  end;

  O := TObservable<string>.Create(OnSubscribe);
  FilterObs := O.Filter(Routine);
  FilterObs.Subscribe(OnNext);

  Check(IsEqual(FStream, ['*2', '*4']));
end;

procedure TOperationsTests.FilterTest2;
var
  O, FilterObs: TObservable<string>;
  Routine: TFilter<string>;
  OnNext: TOnNext<string>;
begin

  OnNext := procedure(const Data: string)
  begin
    FStream.Add(Data);
  end;

  Routine := function(const Data: string): Boolean
  begin
    Result := Data[1] = '*'
  end;

  FilterObs := O.Filter(Routine);
  FilterObs.Subscribe(OnNext);

  O.OnNext('1');
  O.OnNext('*2');
  O.OnNext('3');
  O.OnNext('*4');
  O.OnCompleted;
  O.OnNext('*5');

  Check(IsEqual(FStream, ['*2', '*4']));
end;

procedure TOperationsTests.FilterTest3;
var
  O, FilterObs: TObservable<string>;
  OnSubscribe: TOnSubscribe<string>;
  Routine: TFilter<string>;
  OnNextA, OnNextB: TOnNext<string>;
begin
  OnSubscribe := procedure(S: IObserver<string>)
  begin
    S.OnNext('1');
    S.OnNext('*2');
    S.OnNext('3');
    S.OnNext('*4');
    S.OnCompleted;
    S.OnNext('*5');
  end;

  OnNextA := procedure(const Data: string)
  begin
    FStream.Add('A' + Data);
  end;

  OnNextB := procedure(const Data: string)
  begin
    FStream.Add('B' + Data);
  end;

  Routine := function(const Data: string): Boolean
  begin
    Result := Data[1] = '*'
  end;

  O := TObservable<string>.Create(OnSubscribe);
  FilterObs := O.Filter(Routine);
  FilterObs.Subscribe(OnNextA);
  FilterObs.Subscribe(OnNextB);

  Check(IsEqual(FStream, ['A*2', 'A*4', 'B*2', 'B*4']));
end;

procedure TOperationsTests.FlatMapOnSubscribe;
var
  O: TObservable<Integer>;
  Flat: TObservable<string>;
  Routine: TFlatMap<Integer, string>;
  OnNext: TOnNext<string>;
  OnCompleted: TOnCompleted;
  OnSubscribe: TOnSubscribe<Integer>;
begin

  OnSubscribe := procedure(O: IObserver<Integer>)
  begin
    O.OnNext(1);
    O.OnNext(10);
    O.OnCompleted;
    O.OnNext(20);
  end;

  O := TObservable<Integer>.Create(OnSubscribe);

  Routine := function(const Data: Integer): IObservable<string>
  var
    O: TObservable<string>;
  begin
    O := TObservable<string>.Just([
      IntToStr(Data),
      IntToStr(Data+1),
      IntToStr(Data+2)
    ]);
    Result := O;
  end;

  OnNext := procedure(const Data: string)
  begin
    FStream.Add(Data);
  end;

  OnCompleted := procedure
  begin
    FStream.Add('completed');
  end;

  Flat := O.FlatMap<string>(Routine);
  Flat.Subscribe(OnNext, OnCompleted);

  Check(IsEqual(FStream, ['1', '2', '3', '10', '11', '12']));

end;

procedure TOperationsTests.FlatMapSane1;
var
  O: TObservable<Integer>;
  Flat: TObservable<string>;
  Routine: TFlatMap<Integer, string>;
  OnNext: TOnNext<string>;
  OnCompleted: TOnCompleted;
begin

  Routine := function(const Data: Integer): IObservable<string>
  var
    O: TObservable<string>;
  begin
    O := TObservable<string>.Just([
      IntToStr(Data),
      IntToStr(Data+1),
      IntToStr(Data+2)
    ]);
    Result := O;
  end;

  OnNext := procedure(const Data: string)
  begin
    FStream.Add(Data);
  end;

  OnCompleted := procedure
  begin
    FStream.Add('completed');
  end;

  Flat := O.FlatMap<string>(Routine);
  Flat.Subscribe(OnNext, OnCompleted);

  O.OnNext(1);
  O.OnNext(10);
  O.OnCompleted;
  O.OnNext(11);

  Check(IsEqual(FStream, ['1', '2', '3', '10', '11', '12', 'completed']));


end;

procedure TOperationsTests.FlatMapSane2;
var
  O: TObservable<Integer>;
  Flat: TObservable<string>;
  Routine: TFlatMap<Integer, string>;
  OnNext: TOnNext<string>;
  OnError: TOnError;
begin

  Routine := function(const Data: Integer): IObservable<string>
  var
    O: TObservable<string>;
  begin
    O := TObservable<string>.Just([
      IntToStr(Data),
      IntToStr(Data+1),
      IntToStr(Data+2)
    ]);
    Result := O;
  end;

  OnNext := procedure(const Data: string)
  begin
    FStream.Add(Data);
  end;

  OnError := procedure(E: IThrowable)
  begin
    FStream.Add('error');
  end;

  Flat := O.FlatMap<string>(Routine);
  Flat.Subscribe(OnNext, OnError);

  O.OnNext(1);
  O.OnNext(10);
  O.OnError(nil);
  O.OnNext(20);

  Check(IsEqual(FStream, ['1', '2', '3', '10', '11', '12', 'error']));


end;


function FlatMapRoutine(const Data: Integer): IObservable<string>;
var
  O: TObservable<string>;
begin
  O := TObservable<string>.Just([
    IntToStr(Data),
    IntToStr(Data+1),
    IntToStr(Data+2)
  ]);
  Result := O;
end;

procedure TOperationsTests.FlatMapStatic;
var
  O: TObservable<Integer>;
  Flat: TObservable<string>;
  OnNext: TOnNext<string>;
  OnCompleted: TOnCompleted;
begin

  OnNext := procedure(const Data: string)
  begin
    FStream.Add(Data);
  end;

  OnCompleted := procedure
  begin
    FStream.Add('completed');
  end;

  Flat := O.FlatMap<string>(FlatMapRoutine);
  Flat.Subscribe(OnNext, OnCompleted);

  O.OnNext(1);
  O.OnNext(10);
  O.OnCompleted;
  O.OnNext(11);

  Check(IsEqual(FStream, ['1', '2', '3', '10', '11', '12', 'completed']));


end;

function MapRoutine(const Data: string): Integer;
begin
  Result := StrToIntDef(Data, -1)
end;

procedure TOperationsTests.MapStatic;
var
  O: TObservable<string>;
  MapObs: TObservable<Integer>;
  OnNext: TOnNext<Integer>;
begin

  OnNext := procedure(const Data: Integer)
  begin
    FStream.Add(IntToStr(Data));
  end;

  MapObs := O.Map<Integer>(MapRoutine);
  MapObs.Subscribe(OnNext);

  O.OnNext('1');
  O.OnNext('2');
  O.OnNext('-');
  O.OnNext('4');
  O.OnCompleted;
  O.OnNext('5');

  Check(IsEqual(FStream, ['1', '2', '-1', '4']));
end;

procedure TOperationsTests.MapTest1;
var
  O: TObservable<string>;
  MapObs: TObservable<Integer>;
  Routine: TMap<string, Integer>;
  OnNext: TOnNext<Integer>;
begin

  OnNext := procedure(const Data: Integer)
  begin
    FStream.Add(IntToStr(Data));
  end;

  Routine := function(const Data: string): Integer
  begin
    Result := StrToIntDef(Data, -1)
  end;

  MapObs := O.Map<Integer>(Routine);
  MapObs.Subscribe(OnNext);

  O.OnNext('1');
  O.OnNext('2');
  O.OnNext('-');
  O.OnNext('4');
  O.OnCompleted;
  O.OnNext('5');

  Check(IsEqual(FStream, ['1', '2', '-1', '4']));
end;

procedure TOperationsTests.MapTest2;
var
  O: TObservable<string>;
  MapObs: TObservable<Integer>;
  Routine: TMap<string, Integer>;
  OnNextA, OnNextB: TOnNext<Integer>;
  OnSubscribe: TOnSubscribe<string>;
begin

  OnSubscribe := procedure(S: IObserver<string>)
  begin
    S.OnNext('1');
    S.OnNext('2');
    S.OnNext('_');
    S.OnNext('4');
    S.OnCompleted;
    S.OnNext('5');
  end;

  OnNextA := procedure(const Data: Integer)
  begin
    FStream.Add('A' + IntToStr(Data));
  end;

  OnNextB := procedure(const Data: Integer)
  begin
    FStream.Add('B' + IntToStr(Data));
  end;

  Routine := function(const Data: string): Integer
  begin
    Result := StrToIntDef(Data, -1)
  end;

  O := TObservable<string>.Create(OnSubscribe);
  MapObs := O.Map<Integer>(Routine);
  MapObs.Subscribe(OnNextA);
  MapObs.Subscribe(OnNextB);

  Check(IsEqual(FStream, ['A1', 'A2', 'A-1', 'A4', 'B1', 'B2', 'B-1', 'B4']));
end;

procedure TOperationsTests.Merge1;
var
  O, O1, O2: TObservable<string>;
  OnSubscribe1, OnSubscribe2: TOnSubscribe<string>;
  OnNext: TOnNext<string>;
  OnCompleted: TOnCompleted;
begin
  OnSubscribe1 := procedure(S: IObserver<string>)
  begin
    S.OnNext('A1');
    S.OnNext('A2');
  end;

  OnSubscribe2 := procedure(S: IObserver<string>)
  begin
    S.OnNext('B1');
    S.OnNext('B2');
    S.OnCompleted;
  end;

  OnNext := procedure(const Data: string)
  begin
    FStream.Add(Data);
  end;

  OnCompleted := procedure
  begin
    FStream.Add('completed');
  end;

  O1 := TObservable<string>.Create(OnSubscribe1);
  O2 := TObservable<string>.Create(OnSubscribe2);
  O := TObservable<string>.Merge(O1, O2);
  O.Subscribe(OnNext, OnCompleted);
  Check(IsEqual(FStream, ['A1', 'A2', 'B1', 'B2', 'completed']));
end;

procedure TOperationsTests.Merge2;
var
  O, O1, O2: TObservable<string>;
  OnSubscribe1, OnSubscribe2: TOnSubscribe<string>;
  OnNext: TOnNext<string>;
  OnCompleted: TOnCompleted;
begin
  OnSubscribe1 := procedure(S: IObserver<string>)
  begin
    S.OnNext('A1');
    S.OnNext('A2');
    S.OnCompleted;
    S.OnNext('A3');
  end;

  OnSubscribe2 := procedure(S: IObserver<string>)
  begin
    S.OnNext('B1');
    S.OnNext('B2');
  end;

  OnNext := procedure(const Data: string)
  begin
    FStream.Add(Data);
  end;

  OnCompleted := procedure
  begin
    FStream.Add('completed');
  end;

  O := TObservable<string>.Merge(O1, O2);
  O.Subscribe(OnNext, OnCompleted);

  O1.OnNext('A1');
  O2.OnNext('B1');
  O1.OnNext('A2');
  O2.OnNext('B2');
  O1.OnCompleted;
  O2.OnNext('B3');

  Check(IsEqual(FStream, ['A1', 'B1', 'A2', 'B2', 'completed']));
end;

procedure TOperationsTests.Merge3;
var
  O, O1, O2, O3: TObservable<string>;
  OnSubscribe1, OnSubscribe2: TOnSubscribe<string>;
  OnNext: TOnNext<string>;
  OnCompleted: TOnCompleted;
begin
  OnSubscribe1 := procedure(S: IObserver<string>)
  begin
    S.OnNext('A1');
    S.OnNext('A2');
    S.OnCompleted;
    S.OnNext('A3');
    S.OnCompleted;
  end;

  OnSubscribe2 := procedure(S: IObserver<string>)
  begin
    S.OnNext('B1');
    S.OnNext('B2');
  end;

  OnNext := procedure(const Data: string)
  begin
    FStream.Add(Data);
  end;

  OnCompleted := procedure
  begin
    FStream.Add('completed');
  end;

  O := TObservable<string>.Merge(O1, O2, O3);
  O.Subscribe(OnNext, OnCompleted);

  O1.OnNext('A1');
  O2.OnNext('B1');
  O1.OnNext('A2');
  O2.OnNext('B2');
  O3.OnNext('C1');
  O1.OnCompleted;
  O2.OnNext('B3');

  Check(IsEqual(FStream, ['A1', 'B1', 'A2', 'B2', 'C1', 'completed']));
end;

procedure TOperationsTests.MergeDuplex;
var
  O, O1: TObservable<string>;
  OnSubscribe: TOnSubscribe<string>;
  OnNext: TOnNext<string>;
begin
  OnSubscribe := procedure(S: IObserver<string>)
  begin
    S.OnNext('1');
    S.OnNext('2');
  end;

  OnNext := procedure(const Data: string)
  begin
    FStream.Add(Data);
  end;

  O1 := TObservable<string>.Create(OnSubscribe);
  O := TObservable<string>.Merge(O1, O1);
  O.Subscribe(OnNext);
  Check(IsEqual(FStream, ['1', '2']));
end;

procedure TOperationsTests.SetUp;
begin
  inherited;
  FStream := TList<string>.Create;
end;

procedure TOperationsTests.Skip;
var
  O: TObservable<Integer>;
  OnSubscribe: TOnSubscribe<Integer>;
  OnNext: TOnNext<Integer>;
begin
  OnSubscribe := procedure(O: IObserver<Integer>)
  begin
    O.OnNext(1);
    O.OnNext(2);
    O.OnNext(3);
    O.OnNext(4);
    O.OnNext(5);
  end;

  OnNext := procedure(const Data: Integer)
  begin
    FStream.Add(IntToStr(Data));
  end;

  O := TObservable<Integer>.Create(OnSubscribe);
  O.Skip(3).Subscribe(OnNext);

  Check(IsEqual(FStream, ['4', '5']));
end;

procedure TOperationsTests.Take;
var
  O: TObservable<Integer>;
  OnSubscribe: TOnSubscribe<Integer>;
  OnNext: TOnNext<Integer>;
begin
  OnSubscribe := procedure(O: IObserver<Integer>)
  begin
    O.OnNext(1);
    O.OnNext(2);
    O.OnNext(3);
    O.OnNext(4);
    O.OnNext(5);
  end;

  OnNext := procedure(const Data: Integer)
  begin
    FStream.Add(IntToStr(Data));
  end;

  O := TObservable<Integer>.Create(OnSubscribe);
  O.Take(3).Subscribe(OnNext);

  Check(IsEqual(FStream, ['1', '2', '3']));
end;

procedure TOperationsTests.TearDown;
begin
  inherited;
  FStream.Free;
end;

procedure TOperationsTests.WithLatestFrom1;
var
  L: TObservable<string>;
  R: TObservable<Integer>;
  WL: TObservable<TZip<string, Integer>>;

  OnNext: TOnNext<TZip<string, Integer>>;
  OnCompleted: TOnCompleted;

begin
  OnNext := procedure(const Data: TZip<string, Integer>)
  begin
    FStream.Add(Format('%s%d', [Data.A, Data.B]))
  end;

  OnCompleted := procedure
  begin
    FStream.Add('completed');
  end;

  WL := L.WithLatestFrom<Integer>(R);
  WL.Subscribe(OnNext, OnCompleted);

  Check(IsEqual(FStream, []));

  L.OnNext('A');
  L.OnNext('B');

  Check(IsEqual(FStream, []));

  R.OnNext(1);
  Check(IsEqual(FStream, ['B1']));

  R.OnNext(2);
  Check(IsEqual(FStream, ['B1']));

  R.OnNext(3);
  R.OnNext(4);
  Check(IsEqual(FStream, ['B1']));

  L.OnNext('C');
  Check(IsEqual(FStream, ['B1', 'C4']));

  R.OnCompleted;
  Check(IsEqual(FStream, ['B1', 'C4', 'completed']));

  L.OnNext('D');
  Check(IsEqual(FStream, ['B1', 'C4', 'completed']));

end;

procedure TOperationsTests.Zip1;
var
  L: TObservable<string>;
  R: TObservable<Integer>;
  Zip: TObservable<TZip<string, Integer>>;

  OnNext: TOnNext<TZip<string, Integer>>;
  OnCompleted: TOnCompleted;

begin
  OnNext := procedure(const Data: TZip<string, Integer>)
  begin
    FStream.Add(Format('%s%d', [Data.A, Data.B]))
  end;

  OnCompleted := procedure
  begin
    FStream.Add('completed');
  end;

  Zip := L.Zip<Integer>(R);
  Zip.Subscribe(OnNext, OnCompleted);

  Check(IsEqual(FStream, []));

  L.OnNext('A');
  L.OnNext('B');

  Check(IsEqual(FStream, []));

  R.OnNext(1);
  Check(IsEqual(FStream, ['A1']));

  R.OnNext(2);
  Check(IsEqual(FStream, ['A1', 'B2']));

  R.OnNext(3);
  R.OnNext(4);
  Check(IsEqual(FStream, ['A1', 'B2']));

  L.OnNext('C');
  Check(IsEqual(FStream, ['A1', 'B2', 'C3']));

  R.OnCompleted;
  Check(IsEqual(FStream, ['A1', 'B2', 'C3', 'completed']));

  L.OnNext('D');
  Check(IsEqual(FStream, ['A1', 'B2', 'C3', 'completed']));

end;

procedure TOperationsTests.Zip2;
var
  L: TObservable<string>;
  R: TObservable<Integer>;
  Zip: TObservable<TZip<string, Integer>>;

  OnNext: TOnNext<TZip<string, Integer>>;
  OnCompleted: TOnCompleted;
  OnSubscribeLeft: TOnSubscribe<string>;
  OnSubscribeRight: TOnSubscribe<Integer>;

begin
  OnNext := procedure(const Data: TZip<string, Integer>)
  begin
    FStream.Add(Format('%s%d', [Data.A, Data.B]))
  end;

  OnCompleted := procedure
  begin
    FStream.Add('completed');
  end;

  OnSubscribeLeft := procedure(Observer: IObserver<string>)
  begin
    Observer.OnNext('A');
    Observer.OnNext('B');
  end;

  OnSubscribeRight := procedure(Observer: IObserver<Integer>)
  begin
    Observer.OnNext(1);
    Observer.OnNext(2);
    Observer.OnNext(3);
  end;

  L := TObservable<string>.Create(OnSubscribeLeft);
  R := TObservable<Integer>.Create(OnSubscribeRight);

  Zip := L.Zip<Integer>(R);
  Zip.Subscribe(OnNext, OnCompleted);

  Check(IsEqual(FStream, ['A1', 'B2']));

  L.OnNext('C');
  L.OnCompleted;
  Check(IsEqual(FStream, ['A1', 'B2', 'C3', 'completed']));

end;

{ TSmartVariableTests }

procedure TSmartVariableTests.Clear;
var
  A: TLoggingObj;
  Variable: TSmartVariable<TLoggingObj>;

  Logger: TThreadProcedure;
begin

  Logger := procedure
  begin
    FLog.Add('*');
  end;

  A := TLoggingObj.Create(Logger);

  Variable := A;
  Variable.Clear;
  CheckEquals(1, FLog.Count);
end;

procedure TSmartVariableTests.GarbageCollection1;
var
  O: TObservable<TLoggingObj>;
  Logger: TThreadProcedure;
  OnNext: TOnNext<TLoggingObj>;
begin
  Logger := procedure
  begin
    FLog.Add('*');
  end;

  OnNext := procedure(const Data: TLoggingObj)
  begin
    FStream.Add(Format('%p', [Pointer(Data)]))
  end;

  O.Subscribe(OnNext);
  O.OnNext(TLoggingObj.Create(Logger));
  O.OnNext(TLoggingObj.Create(Logger));
  O.OnNext(TLoggingObj.Create(Logger));
  Logger := nil;

  CheckEquals(3, FStream.Count);
  CheckEquals(3, FLog.Count);
end;

procedure TSmartVariableTests.GarbageCollection2;
begin

end;

procedure TSmartVariableTests.Sane;
var
  A1, A2: TLoggingObj;
  Variable: TSmartVariable<TLoggingObj>;

  Logger: TThreadProcedure;
begin

  Logger := procedure
  begin
    FLog.Add('*');
  end;

  A1 := TLoggingObj.Create(Logger);
  A2 := TLoggingObj.Create(Logger);

  Variable := A1;
  CheckTrue(A1 = Variable.Get);
  CheckFalse(A2 = Variable.Get);

  CheckEquals(0, FLog.Count);

  Variable := A2;
  CheckEquals(1, FLog.Count);

end;

procedure TSmartVariableTests.SetUp;
begin
  inherited;
  FLog := TList<string>.Create;
  FStream := TList<string>.Create;
end;

procedure TSmartVariableTests.TearDown;
begin
  inherited;
  FLog.Free;
  FStream.Free;
end;

procedure TSmartVariableTests.Visibility;
var
  InternalCall: TThreadProcedure;
  Logger: TThreadProcedure;
begin

  Logger := procedure
  begin
    FLog.Add('*');
  end;

  InternalCall := procedure
  var
    A: TSmartVariable<TLoggingObj>;
  begin
    A := TLoggingObj.Create(Logger);
  end;

  InternalCall();
  Logger := nil;  // чистим транзитивные замыкания

  CheckEquals(1, FLog.Count);
end;

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

{ TMemoryLeaksTests }

procedure TMemoryLeaksTests.EmptySubscribers;
var
  O: TObservable<TLoggingObj>;
begin
  O.OnNext(TLoggingObj.Create(OnItemFree));
  CheckEquals(1, FFreesLog.Count);
end;

procedure TMemoryLeaksTests.MapCase1;
var
  O: TObservable<TLoggingObj>;
  OnNext: TOnNext<TLoggingObjDescendant>;
  Mapper: TMap<TLoggingObj, TLoggingObjDescendant>;
begin
  OnNext := procedure (const Data: TLoggingObjDescendant)
  begin
    FStream.Add('*');
  end;

  Mapper := function(const Data: TLoggingObj): TLoggingObjDescendant
  begin
    Result := TLoggingObjDescendant.Create(OnItemFree);
  end;

  O.Map<TLoggingObjDescendant>(Mapper);

  O.OnNext(TLoggingObj.Create(OnItemFree));
  CheckEquals(2, FFreesLog.Count);

  FFreesLog.Clear;

  O.Map<TLoggingObjDescendant>(Mapper).Subscribe(OnNext);
  O.Map<TLoggingObjDescendant>(Mapper).Subscribe(OnNext);
  O.Map<TLoggingObjDescendant>(Mapper).Subscribe(OnNext);

  O.OnNext(TLoggingObj.Create(OnItemFree));
  CheckEquals(3, FStream.Count);
  CheckEquals(2 + 3, FFreesLog.Count);
end;

procedure TMemoryLeaksTests.MapCase2;
var
  O: TObservable<TLoggingObj>;
  OnNext: TOnNext<TLoggingObjDescendant>;
  Mapper: TMap<TLoggingObj, TLoggingObjDescendant>;

  procedure SubscribeOutOfScope;
  begin
    O.Map<TLoggingObjDescendant>(Mapper).Subscribe(OnNext);
    O.Map<TLoggingObjDescendant>(Mapper).Subscribe(OnNext);
    O.Map<TLoggingObjDescendant>(Mapper).Subscribe(OnNext);
  end;

begin

  OnNext := procedure (const Data: TLoggingObjDescendant)
  begin
    FStream.Add('*');
  end;

  Mapper := function(const Data: TLoggingObj): TLoggingObjDescendant
  begin
    Result := TLoggingObjDescendant.Create(OnItemFree);
  end;

  SubscribeOutOfScope;

  O.OnNext(TLoggingObj.Create(OnItemFree));
  CheckEquals(3, FStream.Count);
  CheckEquals(2 + 2, FFreesLog.Count);
end;

procedure TMemoryLeaksTests.OnItemFree;
begin
  FFreesLog.Add('destroy')
end;

procedure TMemoryLeaksTests.SetUp;
begin
  inherited;
  FStream := TList<string>.Create;
  FFreesLog := TList<string>.Create;
end;

procedure TMemoryLeaksTests.TearDown;
begin
  inherited;
  FStream.Free;
  FFreesLog.Free;
end;

procedure TMemoryLeaksTests.Zip1;
var
  A: TObservable<TLoggingObj>;
  B: TObservable<TLoggingObjDescendant>;
  Z: TObservable<TZip<TLoggingObj, TLoggingObjDescendant>>;
  OnNext: TOnNext<TZip<TLoggingObj, TLoggingObjDescendant>>;
begin

  OnNext := procedure (const Data: TZip<TLoggingObj, TLoggingObjDescendant>)
  begin
    FStream.Add('*');
  end;

  Z := A.Zip<TLoggingObjDescendant>(B);

  A.OnNext(TLoggingObj.Create(OnItemFree));
  B.OnNext(TLoggingObjDescendant.Create(OnItemFree));
  CheckEquals(2, FFreesLog.Count);

  FFreesLog.Clear;

  Z.Subscribe(OnNext);
  Z.Subscribe(OnNext);
  Z.Subscribe(OnNext);

  A.OnNext(TLoggingObj.Create(OnItemFree));
  B.OnNext(TLoggingObjDescendant.Create(OnItemFree));

  CheckEquals(3, FStream.Count);
  CheckEquals(2, FFreesLog.Count);
end;

procedure TMemoryLeaksTests.Zip2;
var
  A: TObservable<TLoggingObj>;
  B: TObservable<TLoggingObjDescendant>;
  Z: TObservable<TZip<TLoggingObj, TLoggingObjDescendant>>;
  OnNext: TOnNext<TZip<TLoggingObj, TLoggingObjDescendant>>;

  procedure SubscribeOutOfScope;
  begin
    Z.Subscribe(OnNext);
    Z.Subscribe(OnNext);
    Z.Subscribe(OnNext);
  end;

begin

  OnNext := procedure (const Data: TZip<TLoggingObj, TLoggingObjDescendant>)
  begin
    FStream.Add('*');
  end;

  Z := A.Zip<TLoggingObjDescendant>(B);

  SubscribeOutOfScope;
  A.OnNext(TLoggingObj.Create(OnItemFree));
  B.OnNext(TLoggingObjDescendant.Create(OnItemFree));

  CheckEquals(3, FStream.Count);
  CheckEquals(2, FFreesLog.Count);
end;

{ TConstructorTests }

procedure TConstructorTests.Interval;
var
  O: TObservable<LongWord>;
  OnNext: TOnNext<LongWord>;
  Sub: ISubscription;
begin

  OnNext := procedure(const Data: LongWord)
  begin
    FStream.Add(IntToStr(Data));
  end;

  O := Rx.Observable.Interval(1);
  Sub := O.Subscribe(OnNext);

  Sleep(3500);
  Check(IsEqual(FStream, ['0', '1', '2']));
end;

procedure TConstructorTests.Just;
var
  O: TObservable<string>;
  OnNext: TOnNext<string>;
  OnCompleted: TOnCompleted;
  A: array of TSmartVariable<string>;
begin
  OnNext := procedure(const Data: string)
  begin
    FStream.Add(Data);
  end;

  OnCompleted := procedure
  begin
    FStream.Add('completed');
  end;

  O := TObservable<string>.Just(['1', '2', '3']);
  O.Subscribe(OnNext, OnCompleted);

  Check(IsEqual(FStream, ['1', '2', '3', 'completed']));
  FStream.Clear;

  SetLength(A, 3);
  A[0] := '10';
  A[1] := '11';
  A[2] := '12' ;

  O := TObservable<string>.Just(A);
  O.Subscribe(OnNext, OnCompleted);

  Check(IsEqual(FStream, ['10', '11', '12', 'completed']));
end;

procedure TConstructorTests.Range;
var
  O: TObservable<Integer>;
  OnNext: TOnNext<Integer>;
  OnCompleted: TOnCompleted;
begin
  O := Rx.Observable.Range(1, 10, 2);

  OnNext := procedure(const Data: Integer)
  begin
    FStream.Add(IntToStr(Data))
  end;

  OnCompleted := procedure
  begin
    FStream.Add('Completed');
  end;

  O.Subscribe(OnNext, OnCompleted);

  Check(IsEqual(FStream, ['1', '3', '5', '7', '9', 'Completed']));
end;

procedure TConstructorTests.SetUp;
begin
  inherited;
  FStream := TList<string>.Create;
end;

procedure TConstructorTests.TearDown;
begin
  inherited;
  FStream.Free;
end;

{ TSchedulersTests }

procedure TSchedulersTests.MainThreadScheduler1;
var
  O: TObservable<Integer>;
  OnNext: TOnNext<Integer>;
  OnCompleted: TOnCompleted;
  OnSubscribe: TOnSubscribe<Integer>;
  ThreadID: LongWord;
  Expected: string;
begin

  OnSubscribe := procedure(O: IObserver<Integer>)
  var
    Th: TThread;
  begin
    Th := TThread.CreateAnonymousThread(procedure
      begin
        O.OnNext(1);
        O.OnNext(10);
        O.OnCompleted;
        O.OnNext(20);
      end);
    ThreadID := Th.ThreadID;
    Th.Start;
    Sleep(1000);
  end;

  O := TObservable<Integer>.Create(OnSubscribe);

  OnNext := procedure(const Data: Integer)
  begin
    FStream.Add('next:'+IntToStr(TThread.CurrentThread.ThreadID));
  end;

  OnCompleted := procedure
  begin
    FStream.Add('completed:'+IntToStr(TThread.CurrentThread.ThreadID));
  end;

  O.Subscribe(OnNext, OnCompleted);

  Expected := 'next:' + IntToStr(ThreadID);
  Check(IsEqual(FStream, [Expected, Expected, 'completed:' + IntToStr(ThreadID)]));

  FStream.Clear;
  O.ScheduleOn(StdSchedulers.CreateMainThreadScheduler);
  O.Subscribe(OnNext, OnCompleted);

  Expected := 'next:' + IntToStr(MainThreadID);

  CheckSynchronize(100);
  CheckSynchronize(100);
  CheckSynchronize(100);
  CheckSynchronize(100);

  Check(IsEqual(FStream, [Expected, Expected, 'completed:' + IntToStr(MainThreadID)]));

end;

procedure TSchedulersTests.MainThreadScheduler2;
var
  O: TObservable<Integer>;
  OnNext: TOnNext<Integer>;
  OnCompleted: TOnCompleted;
  ThreadID: LongWord;
  Expected: string;
  Th: TThread;
begin

  OnNext := procedure(const Data: Integer)
  begin
    FStream.Add('next:'+IntToStr(TThread.CurrentThread.ThreadID));
  end;

  OnCompleted := procedure
  begin
    FStream.Add('completed:'+IntToStr(TThread.CurrentThread.ThreadID));
  end;

  O.Subscribe(OnNext, OnCompleted);

  Th := TThread.CreateAnonymousThread(
  procedure
  begin
    O.OnNext(1);
    O.OnNext(10);
    O.OnCompleted;
    O.OnNext(20);
  end);
  ThreadID := Th.ThreadID;
  Th.Start;
  Sleep(1000);

  Expected := 'next:' + IntToStr(ThreadID);
  Check(IsEqual(FStream, [Expected, Expected, 'completed:' + IntToStr(ThreadID)]));

  FStream.Clear;
  O.ScheduleOn(StdSchedulers.CreateMainThreadScheduler);
  O.Subscribe(OnNext, OnCompleted);

  Expected := 'next:' + IntToStr(MainThreadID);

  Th := TThread.CreateAnonymousThread(
  procedure
  begin
    O.OnNext(1);
    O.OnNext(10);
    O.OnCompleted;
    O.OnNext(20);
  end);
  Th.Start;
  Sleep(1000);

  CheckSynchronize(100);
  CheckSynchronize(100);
  CheckSynchronize(100);
  CheckSynchronize(100);

  Check(IsEqual(FStream, [Expected, Expected, 'completed:' + IntToStr(MainThreadID)]));

end;

procedure TSchedulersTests.NewThreadScheduler;
begin

end;

procedure TSchedulersTests.SeparateThreadScheduler;
var
  O: TObservable<Integer>;
  OnNext: TOnNext<Integer>;
  OnCompleted: TOnCompleted;
  ThreadID: LongWord;
  Expected: string;
  Th: TThread;
begin
  ThreadID := 0;

  OnNext := procedure(const Data: Integer)
  begin
    if ThreadID = 0 then
      ThreadID := TThread.CurrentThread.ThreadID;
    FStream.Add('next:'+IntToStr(TThread.CurrentThread.ThreadID));
  end;

  OnCompleted := procedure
  begin
    FStream.Add('completed:'+IntToStr(TThread.CurrentThread.ThreadID));
  end;

  O.ScheduleOn(StdSchedulers.CreateSeparateThreadScheduler);
  O.Subscribe(OnNext, OnCompleted);

  Th := TThread.CreateAnonymousThread(
  procedure
  begin
    O.OnNext(1);
    O.OnNext(2);
    O.OnCompleted;
    O.OnNext(3);
  end);
  Th.Start;
  Sleep(5000);

  CheckFalse(ThreadID = MainThreadID);
  Expected := 'next:' + IntToStr(ThreadID);
  Check(IsEqual(FStream, [Expected, Expected, 'completed:' + IntToStr(ThreadID)]));

end;

procedure TSchedulersTests.SetUp;
begin
  inherited;
  FStream := TList<string>.Create;
end;

procedure TSchedulersTests.TearDown;
begin
  inherited;
  FStream.Free;
end;

procedure TSchedulersTests.ThreadPoolScheduler;
begin

end;

{ TAdvancedOpsTests }

procedure TAdvancedOpsTests.ScanObjects;
var
  O, Progress: TObservable<TInteger>;
  OnSubscribe: TOnSubscribe<TInteger>;
  OnNext: TOnNext<TInteger>;
  Scan: TScanRoutine<TInteger, TInteger>;
begin
  Scan := procedure(var Progress: TInteger; const Cur: TInteger)
  begin
    Progress.Value := Progress.Value + Cur.Value;
  end;

  OnSubscribe := procedure(O: IObserver<TInteger>)
  begin
    O.OnNext(TInteger.Create(10));
    O.OnNext(TInteger.Create(30));
    O.OnNext(TInteger.Create(10));
  end;

  OnNext := procedure(const Progress: TInteger)
  begin
    FStream.Add(IntToStr(Progress.Value));
  end;


  O := TObservable<TInteger>.Create(OnSubscribe);
  Progress := O.Scan(TInteger.Create(0), Scan);

  Progress.Subscribe(OnNext);

  Check(IsEqual(FStream, ['10', '40', '50']));
end;

procedure TAdvancedOpsTests.CollectWithDict;
var
  O: TObservable<TInteger>;
  CollectO: TObservable<TDictionary<Integer, TInteger>>;
  OnSubscribe: TOnSubscribe<TInteger>;
  OnNext: TOnNext<TDictionary<Integer, TInteger>>;
  Collect: TCollectAction2<Integer, TInteger, TInteger>;
  OnCompleted: TOnCompleted;
begin
  Collect := procedure(const Dict: TDictionary<Integer, TInteger>; const Value: TInteger)
  var
    Key: Integer;
  begin
    Key := Value.Value;
    if Dict.ContainsKey(Key) then
      Dict[Key].Value := Dict[Key].Value + 1
    else
      Dict.Add(Key, TInteger.Create(1));
  end;

  OnSubscribe := procedure(O: IObserver<TInteger>)
  begin
    O.OnNext(TInteger.Create(1));
    O.OnNext(TInteger.Create(2));
    O.OnNext(TInteger.Create(2));
    O.OnNext(TInteger.Create(3));
    O.OnNext(TInteger.Create(1));
    O.OnNext(TInteger.Create(1));
  end;

  OnNext := procedure(const Dict: TDictionary<Integer, TInteger>)
  var
    KV: TPair<Integer, TInteger>;
  begin
    for KV in Dict do begin
      FStream.Add(Format('%d:%d', [KV.Key, KV.Value.Value]))
    end;
  end;

  OnCompleted := procedure
  begin
    FStream.Add('completed');
  end;


  O := TObservable<TInteger>.Create(OnSubscribe);
  CollectO := O.Collect<Integer, TInteger>(Collect);

  CollectO.Subscribe(OnNext, OnCompleted);

  Check(IsEqual(FStream, []));

  O.OnCompleted;

  Check(IsEqual(FStream, ['3:1', '2:2', '1:3', 'completed']));
end;

procedure TAdvancedOpsTests.CollectWithList;
var
  O: TObservable<TInteger>;
  CollectO: TObservable<TList<TInteger>>;
  OnSubscribe: TOnSubscribe<TInteger>;
  OnNext: TOnNext<TList<TInteger>>;
  Collect: TCollectAction1<TInteger, TInteger>;
begin
  Collect := procedure(const List: TList<TInteger>; const Value: TInteger)
  var
    Found: Boolean;
    I: Integer;
  begin
    Found := False;
    for I := 0 to List.Count-1 do
      if List[I].Value = Value.Value then begin
        Found := True;
        Break
      end;
    if not Found then
      List.Add(Value)
  end;

  OnSubscribe := procedure(O: IObserver<TInteger>)
  begin
    O.OnNext(TInteger.Create(30));
    O.OnNext(TInteger.Create(10));
    O.OnNext(TInteger.Create(50));
    O.OnNext(TInteger.Create(10));
  end;

  OnNext := procedure(const Collection: TList<TInteger>)
  var
    I: Integer;
    Item: TInteger;
  begin
    for I := 0 to Collection.Count-1 do begin
      Item := Collection[I];
      FStream.Add(IntToStr(Item.Value));
    end;
  end;


  O := TObservable<TInteger>.Create(OnSubscribe);
  CollectO := O.Collect<TInteger>([TInteger.Create(10)], Collect);

  CollectO.Subscribe(OnNext);

  Check(IsEqual(FStream, []));

  O.OnCompleted;

  Check(IsEqual(FStream, ['10', '30', '50']));
end;

procedure TAdvancedOpsTests.Reduce;
var
  O, Progress: TObservable<Integer>;
  OnSubscribe: TOnSubscribe<Integer>;
  OnNext: TOnNext<Integer>;
  Reduce: TReduceRoutine<Integer, Integer>;
begin
  Reduce := function(const Accum: Integer; const Item: Integer): Integer
  begin
    Result := Accum + Item
  end;

  OnSubscribe := procedure(O: IObserver<Integer>)
  begin
    O.OnNext(10);
    O.OnNext(30);
    O.OnNext(10);
  end;

  OnNext := procedure(const Progress: Integer)
  begin
    FStream.Add(IntToStr(Progress));
  end;


  O := TObservable<Integer>.Create(OnSubscribe);
  Progress := O.Reduce(Reduce);

  Progress.Subscribe(OnNext);

  Check(IsEqual(FStream, []));

  O.OnCompleted;
  Check(IsEqual(FStream, ['50']));
end;

procedure TAdvancedOpsTests.ResuceZero;
var
  O, Progress: TObservable<Integer>;
  OnSubscribe: TOnSubscribe<Integer>;
  OnNext: TOnNext<Integer>;
  Reduce: TReduceRoutine<Integer, Integer>;
begin
  Reduce := function(const Accum: Integer; const Item: Integer): Integer
  begin
    Result := Accum + Item
  end;

  OnSubscribe := procedure(O: IObserver<Integer>)
  begin
    O.OnCompleted;
    O.OnNext(10)
  end;

  OnNext := procedure(const Progress: Integer)
  begin
    FStream.Add(IntToStr(Progress));
  end;


  O := TObservable<Integer>.Create(OnSubscribe);
  Progress := O.Reduce(Reduce);
  Check(IsEqual(FStream, []));
end;

procedure TAdvancedOpsTests.Scan;
var
  O, Progress: TObservable<Integer>;
  OnSubscribe: TOnSubscribe<Integer>;
  OnNext: TOnNext<Integer>;
  Scan: TScanRoutine<Integer, Integer>;
begin
  Scan := procedure(var Progress: Integer; const Cur: Integer)
  begin
    Progress := Progress + Cur;
  end;

  OnSubscribe := procedure(O: IObserver<Integer>)
  begin
    O.OnNext(10);
    O.OnNext(30);
    O.OnNext(10);
  end;

  OnNext := procedure(const Progress: Integer)
  begin
    FStream.Add(IntToStr(Progress));
  end;


  O := TObservable<Integer>.Create(OnSubscribe);
  Progress := O.Scan(0, Scan);

  Progress.Subscribe(OnNext);

  Check(IsEqual(FStream, ['10', '40', '50']));
end;

procedure TAdvancedOpsTests.SetUp;
begin
  inherited;
  FStream := TList<string>.Create;
end;

procedure TAdvancedOpsTests.TearDown;
begin
  inherited;
  FStream.Free;
end;

{ TMergeTests }

procedure TMergeTests.PassingOnError;
var
  Source, Dest1, Dest2: TObservable<string>;
  Map: TMap<string, string>;
  OnError1, OnError2: TOnError;
begin
  Map := function(const Data: string): string
  begin
    Result := Data
  end;

  OnError1 := procedure(E: IThrowable)
  begin
    FStream.Add('error:1')
  end;

  OnError2 := procedure(E: IThrowable)
  begin
    FStream.Add('error:2')
  end;

  Source.SetName('Source');
  Dest1 := Source.Map<string>(Map);
  Dest1.SetName('Dest1');
  Dest1.Subscribe(nil, OnError1);
  Dest2 := Source.Map<string>(Map);
  Dest2.Subscribe(nil, OnError2);

  Source.OnError(nil);

  Check(IsEqual(FStream, ['error:1', 'error:2']));
end;

procedure TMergeTests.PassingOnNext;
var
  Source, Dest1, Dest2: TObservable<string>;
  Map: TMap<string, string>;
  OnNext1, OnNext2: TOnNext<string>;
begin
  Map := function(const Data: string): string
  begin
    Result := Data
  end;

  OnNext1 := procedure(const Data: string)
  begin
    FStream.Add(Data + ':1')
  end;

  OnNext2 := procedure(const Data: string)
  begin
    FStream.Add(Data + ':2')
  end;

  Dest1 := Source.Map<string>(Map);
  Dest1.Subscribe(OnNext1);
  Dest2 := Source.Map<string>(Map);
  Dest2.Subscribe(OnNext2);

  Source.OnNext('A');
  Source.OnNext('B');
  Source.OnNext('C');

  Check(IsEqual(FStream, ['A:1', 'A:2', 'B:1', 'B:2', 'C:1', 'C:2']));
end;

procedure TMergeTests.SetUp;
begin
  inherited;
  FStream := TList<string>.Create;
end;

procedure TMergeTests.TearDown;
begin
  inherited;
  FStream.Free;
end;

{ TInteger }

constructor TInteger.Create(Value: Integer);
begin
  FValue := Value
end;

initialization

  RegisterTests('Observable', [
    TSmartVariableTests.Suite,
    TSubscriptionTests.Suite,
    TMergeTests.Suite,
    TOperationsTests.Suite,
    TAdvancedOpsTests.Suite,
    TMemoryLeaksTests.Suite,
    TConstructorTests.Suite,
    TSchedulersTests.Suite
  ]);

end.
