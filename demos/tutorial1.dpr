program tutorial1;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Rx,
  System.SysUtils,
  StdHandlers in 'StdHandlers.pas';

var
  Timer: TObservable<LongWord>;
  Input: TObservable<string>;
  Output: TObservable<TZip<LongWord, string>>;

begin

  Timer := Observable.Interval(1, TimeUnit.SECONDS);
  Input := TObservable<string>.Just(['one', 'two', 'three', 'four', 'five']);

  { Build result data stream }
  Output := Observable.Zip<LongWord, string>(Timer, Input);
  Output.Subscribe(
    StdHandlers.PrintString,
    StdHandlers.PressEnter
  );
  Output.WaitCompletition(INFINITE);

end.
