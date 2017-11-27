unit Rx.Observable.Defer;

interface
uses Rx, Rx.Implementations;

type

  TDefer<T> = class(TObservableImpl<T>)
  type
    TFactory = Rx.TDefer<T>;
  strict private
    FFactory: TFactory;
  protected
    procedure OnSubscribe(Subscriber: ISubscriber<T>); override;
  public
    constructor Create(const Factory: TFactory);
    destructor Destroy; override;
  end;

implementation

{ TDefer<T> }

constructor TDefer<T>.Create(const Factory: TFactory);
begin
  inherited Create;
  FFactory := Factory;
end;

destructor TDefer<T>.Destroy;
begin
  FFactory := nil;
  inherited;
end;

procedure TDefer<T>.OnSubscribe(Subscriber: ISubscriber<T>);
var
  O: TObservable<T>;
begin
  O := FFactory();
  O.Subscribe(Subscriber);
end;

end.
