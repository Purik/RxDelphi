unit Rx.Observable.Filter;

interface
uses Rx, Rx.Subjects;

type

  TFilter<T> = class(TPublishSubject<T>)
  strict private
    FRoutine: Rx.TFilter<T>;
    FRoutineStatic: Rx.TFilterStatic<T>;
  public
    constructor Create(Source: IObservable<T>; const Routine: Rx.TFilter<T>);
    constructor CreateStatic(Source: IObservable<T>; const Routine: Rx.TFilterStatic<T>);
    procedure OnNext(const Data: T); override;
  end;

implementation

{ TFilter<T> }

constructor TFilter<T>.Create(Source: IObservable<T>;
  const Routine: Rx.TFilter<T>);
begin
  inherited Create;
  FRoutine := Routine;
  Merge(Source);
end;

constructor TFilter<T>.CreateStatic(Source: IObservable<T>;
  const Routine: Rx.TFilterStatic<T>);
begin
  inherited Create;
  FRoutineStatic := Routine;
  Merge(Source);
end;

procedure TFilter<T>.OnNext(const Data: T);
begin
  if Assigned(FRoutine) then begin
    if FRoutine(Data) then
      inherited;
  end
  else if FRoutineStatic(Data) then
    inherited;
end;

end.
