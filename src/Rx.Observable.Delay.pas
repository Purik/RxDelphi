unit Rx.Observable.Delay;

interface
uses Rx, Rx.Implementations, Generics.Collections, Rx.Subjects;

type

  TDelay<T> = class(TPublishSubject<T>)
  type
    TValue = TSmartVariable<T>;
  strict private
    FCache: TList<TValue>;
    FCompleted: Boolean;
    FError: IThrowable;
    FInterval: TObservable<LongWord>;
    FSubscription: ISubscription;
    procedure OnTimeout(const Iter: LongWord);
  public
    constructor Create(Source: IObservable<T>;
      aInterval: LongWord; aTimeUnit: LongWord = TimeUnit.SECONDS);
    destructor Destroy; override;
    procedure OnNext(const Data: T); override;
    procedure OnError(E: IThrowable); override;
    procedure OnCompleted; override;
  end;

implementation

{ TDelay<T> }

constructor TDelay<T>.Create(Source: IObservable<T>;
  aInterval: LongWord; aTimeUnit: LongWord = TimeUnit.SECONDS);
begin
  inherited Create;
  FCache := TList<TValue>.Create;
  Merge(Source);
  FInterval := Observable.Interval(aInterval, aTimeUnit);
  FSubscription := FInterval.Subscribe(OnTimeout);
end;

destructor TDelay<T>.Destroy;
begin
  FSubscription.Unsubscribe;
  FCache.Free;
  FInterval := nil;
  inherited;
end;

procedure TDelay<T>.OnCompleted;
var
  DoRaise: Boolean;
begin
  Lock;
  try
    FCompleted := True;
    DoRaise := FCache.Count = 0;
  finally
    Unlock;
  end;
  if DoRaise then
    inherited OnCompleted;
end;

procedure TDelay<T>.OnError(E: IThrowable);
var
  DoRaise: Boolean;
begin
  Lock;
  try
    FError := E;
    DoRaise := FCache.Count = 0;
  finally
    Unlock;
  end;
  if DoRaise then
    inherited OnError(E);
end;

procedure TDelay<T>.OnNext(const Data: T);
begin
  // hide parent logic
  Lock;
  try
    FCache.Add(Data)
  finally
    Unlock;
  end;
end;

procedure TDelay<T>.OnTimeout(const Iter: LongWord);
var
  Value: TValue;
  ValueExists: Boolean;
  IsCompleted: Boolean;
begin
  Lock;
  try
    ValueExists := FCache.Count > 0;
    if ValueExists then begin
      Value := FCache[0];
      FCache.Delete(0);
    end;
    IsCompleted := FCompleted or Assigned(FError);
  finally
    Unlock;
  end;
  if ValueExists then
    inherited OnNext(Value)
  else begin
    if IsCompleted then
      if Assigned(FError) then
        inherited OnError(FError)
      else
        inherited OnCompleted;
  end;
end;

end.

