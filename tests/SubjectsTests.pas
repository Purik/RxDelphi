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
  Expected, Actual: string;
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
