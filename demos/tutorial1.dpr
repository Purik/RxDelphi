program tutorial1;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Rx,
  System.SysUtils;

var
  OnData: TOnNext<TZip<LongWord, string>>;
  OnCompleted: TOnCompleted;

  Timer: TObservable<LongWord>;
  Input: TObservable<string>;
  Output: TObservable<TZip<LongWord, string>>;

begin

  OnData := procedure(const Data: TZip<LongWord, string>)
  begin
    WriteLn('');
    WriteLn('Timestamp: ' + TimeToStr(Now));
    WriteLn(Format('iter: %d     value: %s', [Data.A, Data.B]))
  end;

  OnCompleted := procedure
  begin
    WriteLn('');
    WriteLn('Press ENTER to Exit');
    Readln;
  end;

  Timer := Observable.Interval(1, TimeUnit.SECONDS);
  Input := TObservable<string>.Just(['one', 'two', 'three', 'four', 'five']);

  { Build result data stream }
  Output := Observable.Zip<LongWord, string>(Timer, Input);
  Output.Subscribe(OnData, OnCompleted);
  Output.WaitCompletition(INFINITE);

end.
