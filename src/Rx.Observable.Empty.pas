unit Rx.Observable.Empty;

interface
uses Rx, Rx.Implementations;

type

  TEmpty<T> = class(TObservableImpl<T>)
  protected
    procedure OnSubscribe(Subscriber: ISubscriber<T>); override;
  public
    procedure OnNext(const Data: T); override;
    procedure OnError(E: IThrowable); override;
    procedure OnCompleted; override;
  end;

implementation

{ TEmpty<T> }

procedure TEmpty<T>.OnCompleted;
begin
  // nothing
end;

procedure TEmpty<T>.OnError(E: IThrowable);
begin
  // nothing
end;

procedure TEmpty<T>.OnNext(const Data: T);
begin
  // nothing
end;

procedure TEmpty<T>.OnSubscribe(Subscriber: ISubscriber<T>);
begin
  Subscriber.OnCompleted;
end;

end.
