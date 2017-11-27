unit Rx.Observable.Take;

interface
uses Rx, Rx.Subjects;

type

  TTake<T> = class(TPublishSubject<T>)
  strict private
    FCounter: Integer;
    FLimit: Integer;
    FSubscription: ISubscription;
  public
    constructor Create(Source: IObservable<T>; Limit: Integer);
    procedure OnNext(const Data: T); override;
  end;

  TSkip<T> = class(TPublishSubject<T>)
  strict private
    FCounter: Integer;
  public
    constructor Create(Source: IObservable<T>; Limit: Integer);
    procedure OnNext(const Data: T); override;
  end;

  TTakeLast<T> = class(TAsyncSubject<T>)
  strict private
    FLimit: Integer;
  public
    constructor Create(Source: IObservable<T>; Limit: Integer);
    procedure OnNext(const Data: T); override;
  end;

implementation

{ TTake<T> }

constructor TTake<T>.Create(Source: IObservable<T>; Limit: Integer);
begin
  inherited Create;
  FSubscription := Merge(Source);
  FLimit := Limit
end;

procedure TTake<T>.OnNext(const Data: T);
var
  RaiseMethod: Boolean;
begin
  if not FSubscription.IsUnsubscribed then begin
    Lock;
    Inc(FCounter);
    RaiseMethod := FCounter <= FLimit;
    if not RaiseMethod then begin
      FSubscription.Unsubscribe;
    end;
    Unlock;
    if RaiseMethod then
      inherited OnNext(Data)
    else
      OnCompleted;
  end
end;

{ TSkip<T> }

constructor TSkip<T>.Create(Source: IObservable<T>; Limit: Integer);
begin
  inherited Create;
  Merge(Source);
  FCounter := Limit
end;

procedure TSkip<T>.OnNext(const Data: T);
var
  RaiseMethod: Boolean;
begin
  Lock;
  RaiseMethod := FCounter <= 0;
  if not RaiseMethod then
    Dec(FCounter);
  Unlock;
  if RaiseMethod then
   inherited OnNext(Data);
end;

{ TTakeLast<T> }

constructor TTakeLast<T>.Create(Source: IObservable<T>; Limit: Integer);
begin
  inherited Create;
  Merge(Source);
  FLimit := Limit
end;

procedure TTakeLast<T>.OnNext(const Data: T);
begin
  Lock;
  try
    if Cache.Count >= FLimit then
      Cache.DeleteRange(0, Cache.Count - FLimit + 1);

    inherited OnNext(Data);
  finally
    Unlock;
  end;
end;

end.
