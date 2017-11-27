unit Rx.Observable.Never;

interface
uses Rx, Rx.Implementations;

type

  TNever<T> = class(TObservableImpl<T>)
  public
    procedure OnNext(const Data: T); override;
    procedure OnError(E: IThrowable); override;
    procedure OnCompleted; override;
  end;


implementation

{ TNever<T> }

procedure TNever<T>.OnCompleted;
begin
  // nothing
end;

procedure TNever<T>.OnError(E: IThrowable);
begin
  // nothing
end;

procedure TNever<T>.OnNext(const Data: T);
begin
  // nothing
end;

end.
