unit SubjectsTests;

interface
uses Classes, TestFramework, Rx, Generics.Collections, SysUtils,
  Rx.Subjects;

type

  TSubjectsTests = class(TTestCase)
  strict private
    FStream: TList<string>;
    FFreesLog: TList<string>;
    procedure OnItemFree;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure PublishSubject1;
    procedure PublishSubject2;
    procedure PublishSubject3;
    procedure ReplaySubject;
    procedure ReplaySubjectWithSize;
    procedure ReplaySubjectWithTime;

  end;


implementation
uses BaseTests;



{ TSubjectsTests }

procedure TSubjectsTests.OnItemFree;
begin
  FFreesLog.Add('destroy')
end;

procedure TSubjectsTests.PublishSubject1;
var
  O: TPublishSubject<Integer>;
  OnNext1, OnNext2: TOnNext<Integer>;
  OnCompleted1, OnCompleted2: TOnCompleted;
begin

  OnNext1 := procedure(const Data: Integer)
  begin
    FStream.Add(Format('[1]:%d', [Data]))
  end;

  OnNext2 := procedure(const Data: Integer)
  begin
    FStream.Add(Format('[2]:%d', [Data]))
  end;

  OnCompleted1 := procedure
  begin
    FStream.Add('[1]:completed')
  end;

  OnCompleted2 := procedure
  begin
    FStream.Add('[2]:completed')
  end;

  O := TPublishSubject<Integer>.Create;
  O.Subscribe(OnNext1, OnCompleted1);
  O.Subscribe(OnNext2, OnCompleted2);
  try
    O.OnNext(1);
    O.OnNext(2);
    O.OnNext(3);
    O.OnCompleted;

    Check(IsEqual(FStream, ['[1]:1', '[2]:1', '[1]:2', '[2]:2', '[1]:3', '[2]:3', '[1]:completed', '[2]:completed']));
  finally
    O.Free
  end;
end;

procedure TSubjectsTests.PublishSubject2;
var
  O: TPublishSubject<Integer>;
  OnNext1, OnNext2: TOnNext<Integer>;
  OnCompleted1, OnCompleted2: TOnCompleted;
  OnSubscribe: TOnSubscribe<Integer>;
begin

  OnSubscribe := procedure(O: IObserver<Integer>)
  begin
    O.OnNext(1);
    O.OnNext(2);
    O.OnNext(3);
    O.OnCompleted;
  end;

  OnNext1 := procedure(const Data: Integer)
  begin
    FStream.Add(Format('[1]:%d', [Data]))
  end;

  OnNext2 := procedure(const Data: Integer)
  begin
    FStream.Add(Format('[2]:%d', [Data]))
  end;

  OnCompleted1 := procedure
  begin
    FStream.Add('[1]:completed')
  end;

  OnCompleted2 := procedure
  begin
    FStream.Add('[2]:completed')
  end;

  O := TPublishSubject<Integer>.Create(OnSubscribe);
  try
    O.Subscribe(OnNext1, OnCompleted1);
    O.Subscribe(OnNext2, OnCompleted2);
    Check(IsEqual(FStream, ['[1]:1', '[1]:2', '[1]:3', '[1]:completed', '[2]:1', '[2]:2', '[2]:3', '[2]:completed']));
  finally
    O.Free
  end;
end;


procedure TSubjectsTests.PublishSubject3;
var
  O: TPublishSubject<Integer>;
  OnNext1, OnNext2: TOnNext<Integer>;
  OnError1, OnError2: TOnError;
begin

  OnNext1 := procedure(const Data: Integer)
  begin
    FStream.Add(Format('[1]:%d', [Data]))
  end;

  OnNext2 := procedure(const Data: Integer)
  begin
    FStream.Add(Format('[2]:%d', [Data]))
  end;

  OnError1 := procedure(Throwable: IThrowable)
  begin
    FStream.Add('[1]:error');
  end;

  OnError2 := procedure(Throwable: IThrowable)
  begin
    FStream.Add('[2]:error');
  end;

  O := TPublishSubject<Integer>.Create;
  O.Subscribe(OnNext1, OnError1);
  O.Subscribe(OnNext2, OnError2);
  try
    O.OnNext(1);
    O.OnNext(2);
    O.OnNext(3);

    try
      raise ETestError.Create('test');
    except
      O.OnError(Observable.CatchException)
    end;

    Check(IsEqual(FStream, ['[1]:1', '[2]:1', '[1]:2', '[2]:2', '[1]:3', '[2]:3', '[1]:error', '[2]:error']));
  finally
    O.Free
  end;
end;

procedure TSubjectsTests.ReplaySubject;
var
  O: TReplaySubject<Integer>;
  OnNext1, OnNext2, OnNext3: TOnNext<Integer>;
  OnCompleted1, OnCompleted2: TOnCompleted;
begin

  OnNext1 := procedure(const Data: Integer)
  begin
    FStream.Add(Format('[1]:%d', [Data]))
  end;

  OnNext2 := procedure(const Data: Integer)
  begin
    FStream.Add(Format('[2]:%d', [Data]))
  end;

  OnNext3 := procedure(const Data: Integer)
  begin
    FStream.Add(Format('[3]:%d', [Data]))
  end;

  OnCompleted1 := procedure
  begin
    FStream.Add('[1]:completed')
  end;

  OnCompleted2 := procedure
  begin
    FStream.Add('[2]:completed')
  end;

  O := TReplaySubject<Integer>.Create;
  O.Subscribe(OnNext1, OnCompleted1);

  try
    O.OnNext(1);
    O.OnNext(2);
    O.OnNext(3);
    O.Subscribe(OnNext2, OnCompleted2);
    O.OnCompleted;
    O.Subscribe(OnNext3);

    Check(IsEqual(FStream, ['[1]:1', '[1]:2', '[1]:3', '[2]:1', '[2]:2', '[2]:3', '[1]:completed', '[2]:completed']));
  finally
    O.Free
  end;
end;

procedure TSubjectsTests.ReplaySubjectWithSize;
var
  O: TReplaySubject<Integer>;
  OnNext: TOnNext<Integer>;
  OnCompleted: TOnCompleted;
begin

  OnNext := procedure(const Data: Integer)
  begin
    FStream.Add(Format('%d', [Data]))
  end;

  OnCompleted := procedure
  begin
    FStream.Add('completed')
  end;

  O := TReplaySubject<Integer>.CreateWithSize(3);

  try
    O.OnNext(1);
    O.OnNext(2);
    O.OnNext(3);
    O.OnNext(4);
    O.OnNext(5);
    O.Subscribe(OnNext, OnCompleted);
    O.OnNext(6);
    O.OnCompleted;
    O.OnNext(7);

    Check(IsEqual(FStream, ['3', '4', '5', '6', 'completed']));
  finally
    O.Free
  end;
end;

procedure TSubjectsTests.ReplaySubjectWithTime;
var
  O: TReplaySubject<Integer>;
  OnNext: TOnNext<Integer>;
  OnCompleted: TOnCompleted;
begin

  OnNext := procedure(const Data: Integer)
  begin
    FStream.Add(Format('%d', [Data]))
  end;

  OnCompleted := procedure
  begin
    FStream.Add('completed')
  end;

  O := TReplaySubject<Integer>.CreateWithTime(100, Rx.TimeUnit.MILLISECONDS, Now + EncodeTime(0, 0, 0, 100));
  try
    O.OnNext(1); // must be losed cause of initial from parameter
    Sleep(100);
    O.OnNext(2);
    Sleep(90);
    O.OnNext(3);
    Sleep(10);
    O.OnNext(4);
    Sleep(10);
    O.OnNext(5);
    O.OnNext(6);
    O.Subscribe(OnNext, OnCompleted);
    O.OnCompleted;

    Check(IsEqual(FStream, ['3', '4', '5', '6', 'completed']));
  finally
    O.Free
  end;
end;

procedure TSubjectsTests.SetUp;
begin
  inherited;
  FStream := TList<string>.Create;
  FFreesLog := TList<string>.Create;
end;

procedure TSubjectsTests.TearDown;
begin
  inherited;
  FStream.Free;
  FFreesLog.Free;
end;

initialization

  RegisterTests('Subjects', [
    TSubjectsTests.Suite
  ]);

end.
