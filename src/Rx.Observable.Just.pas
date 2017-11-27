unit Rx.Observable.Just;

interface
uses Rx, Rx.Implementations;

type

  TJust<T> = class(TObservableImpl<T>)
  type
    TValuesCollection = array of TSmartVariable<T>;
  strict private
    FItems: TValuesCollection;
    FEnumerator: IEnumerator<TSmartVariable<T>>;
    procedure ItemsEnumerate(O: IObserver<T>);
    procedure EnumeratorEnumerate(O: IObserver<T>);
  public
    constructor Create(const Items: array of TSmartVariable<T>); overload;
    constructor Create(Enumerator: IEnumerator<TSmartVariable<T>>); overload;
    constructor Create(Enumerable: IEnumerable<TSmartVariable<T>>); overload;
  end;

implementation

{ TJust<T> }

constructor TJust<T>.Create(const Items: array of TSmartVariable<T>);
var
  I: Integer;
begin
  inherited Create(ItemsEnumerate);
  SetLength(FItems, Length(Items));
  for I := 0 to High(Items) do
    FItems[I] := Items[I];
end;

constructor TJust<T>.Create(Enumerator: IEnumerator<TSmartVariable<T>>);
begin
  inherited Create(EnumeratorEnumerate);
  FEnumerator := Enumerator;
end;

constructor TJust<T>.Create(Enumerable: IEnumerable<TSmartVariable<T>>);
begin
  Create(Enumerable.GetEnumerator)
end;

procedure TJust<T>.EnumeratorEnumerate(O: IObserver<T>);
var
  I: T;
begin
  FEnumerator.Reset;
  while FEnumerator.MoveNext do
    O.OnNext(FEnumerator.Current);
end;

procedure TJust<T>.ItemsEnumerate(O: IObserver<T>);
var
  Item: TSmartVariable<T>;
begin
  for Item in FItems do
    O.OnNext(Item);
  O.OnCompleted;
end;

end.
