(*
  Реализация типичных Observable.

  Прежде чем принять решение о реализации собственного Observable,
  загляните сюда.

  --- Неявная инфраструктура ---

  Cуществуют принципы, которые могут быть не очевидны в коде.
  Один из важнейших заключается в том, что ни одно событие не будет выдано
  после того, как последовательность завершена (onError или onCompleted).
  Реализация subject’ уважает эти принципы.

  Безопасность не может быть гарантирована везде, где используется Rx,
  поэтому вам лучше быть осведомленным и не нарушать этот принцип,
  так как это может привести к неопределенным последствиям.
*)
unit Rx.Subjects;

interface
uses Rx, Rx.Implementations, Generics.Collections;

type

  ///	<summary>
  ///	  Cамая простая реализация Subject. Когда данные передаются в
  ///	  PublishSubject, он выдает их всем подписчикам, которые подписаны на
  ///	  него в данный момент.
  ///	</summary>
  TPublishSubject<T> = class(TObservableImpl<T>)
  public
    procedure OnNext(const Data: T); override;
  end;

  ///	<summary>
  ///	  Имеет специальную возможность кэшировать все поступившие в него данные.
  ///	  Когда у него появляется новый подписчик, последовательность выдана ему
  ///	  начиная с начала. Все последующие поступившие данные будут выдаваться
  ///	  подписчикам как обычно.
  ///	</summary>
  TReplaySubject<T> = class(TPublishSubject<T>)
  type
    TValue = TSmartVariable<T>;
    TVaueDescr = record
      Value: TValue;
      Stamp: TTime;
    end;
  strict private
    FCache: TList<TVaueDescr>;
  protected
    procedure OnSubscribe(Subscriber: ISubscriber<T>); override;
  public
    constructor Create;

    ///	<summary>
    ///	  <para>
    ///	    Кэшировать всё подряд не всегда лучшая идея, так как
    ///	    последовательности могут быть длинными или даже бесконечными.
    ///	  </para>
    ///	  <para>
    ///	    CreateWithSize ограничивает размер буфера, а
    ///     CreateWithTime время, которое объекты будут оставаться в кеше.
    ///	  </para>
    ///	</summary>
    constructor CreateWithSize(Size: LongWord);
    constructor CreateWithTime(Time: LongWord;
      TimeUnit: LongWord = Rx.TimeUnit.MILLISECONDS; From: TDateTime=Rx.StdSchedulers.IMMEDIATE);
    destructor Destroy; override;
    procedure OnNext(const Data: T); override;
  end;


  ///	<summary>
  ///	  BehaviorSubject хранит только последнее значение. Это то же самое, что
  ///	  и ReplaySubject, но с буфером размером 1. Во время создания ему может
  ///	  быть присвоено начальное значение, таким образом гарантируя, что данные
  ///	  всегда будут доступны новым подписчикам.
  ///	</summary>
  TBehaviorSubject<T> = class(TPublishSubject<T>)
  strict private
    FValue: TSmartVariable<T>;
    FValueExists: Boolean;
  protected
    procedure OnSubscribe(Subscriber: ISubscriber<T>); override;
  public
    constructor Create(const Value: T); overload;
    procedure OnNext(const Data: T); override;
  end;


  ///	<summary>
  ///	  Также хранит последнее значение. Разница в том, что он не выдает данных
  ///	  до тех пока не завершится последовательность. Его используют, когда
  ///	  нужно выдать единое значение и тут же завершиться.
  ///	</summary>
  TAsyncSubject<T> = class(TObservableImpl<T>)
  type
    TValue = TSmartVariable<T>;
  strict private
    FCache: TList<TValue>;
  protected
    property Cache: TList<TValue> read FCache;
  public
    constructor Create;
    destructor Destroy; override;
    procedure OnNext(const Data: T); override;
    procedure OnCompleted; override;
  end;

implementation
uses SysUtils, Rx.Schedulers;

{ TPublishSubject<T> }

procedure TPublishSubject<T>.OnNext(const Data: T);
var
  Contract: IContract;
  Ref: TSmartVariable<T>;
begin
  inherited;
  Ref := Data;
  if Supports(Scheduler, StdSchedulers.ICurrentThreadScheduler) then
    for Contract in Freeze do
      Contract.GetSubscriber.OnNext(TSmartVariable<T>.Create(Data))
  else
    for Contract in Freeze do
      Scheduler.Invoke(TOnNextAction<T>.Create(Data, Contract))
end;

{ TReplaySubject<T> }

constructor TReplaySubject<T>.Create;
begin
  FCache := TList<TVaueDescr>.Create;
end;

constructor TReplaySubject<T>.CreateWithSize(Size: LongWord);
begin
  Create;
end;

constructor TReplaySubject<T>.CreateWithTime(Time: LongWord; TimeUnit: LongWord;
  From: TDateTime);
begin
  Create;
end;

destructor TReplaySubject<T>.Destroy;
begin
  FCache.Free;
  inherited;
end;

procedure TReplaySubject<T>.OnNext(const Data: T);
var
  Descr: TVaueDescr;
begin
  inherited OnNext(Data);
  Descr.Value := Data;
  Descr.Stamp := Now;
  FCache.Add(Descr);
end;

procedure TReplaySubject<T>.OnSubscribe(Subscriber: ISubscriber<T>);
var
  Descr: TVaueDescr;
begin
  inherited;
  for Descr in FCache do
    Subscriber.OnNext(Descr.Value);
end;

{ TBehaviorSubject<T> }

constructor TBehaviorSubject<T>.Create(const Value: T);
begin
  inherited Create;
  FValue := Value;
  FValueExists := True;
end;

procedure TBehaviorSubject<T>.OnNext(const Data: T);
begin
  inherited;
  FValue := Data;
  FValueExists := True;
end;

procedure TBehaviorSubject<T>.OnSubscribe(Subscriber: ISubscriber<T>);
begin
  inherited;
  if FValueExists then
    Subscriber.OnNext(FValue);
end;

{ TAsyncSubject<T> }

constructor TAsyncSubject<T>.Create;
begin
  inherited Create;
  FCache := TList<TValue>.Create;
end;

destructor TAsyncSubject<T>.Destroy;
begin
  FCache.Free;
  inherited;
end;

procedure TAsyncSubject<T>.OnCompleted;
var
  Value: TValue;
  Contract: IContract;
begin
  if Supports(Scheduler, StdSchedulers.ICurrentThreadScheduler) then
    for Contract in Freeze do
      for Value in FCache do
        Contract.GetSubscriber.OnNext(Value)
  else
    for Contract in Freeze do
      for Value in FCache do
        Scheduler.Invoke(TOnNextAction<T>.Create(Value, Contract));
  inherited;
end;

procedure TAsyncSubject<T>.OnNext(const Data: T);
begin
  inherited;
  FCache.Add(Data);
end;

end.
