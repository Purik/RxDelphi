unit StdHandlers;

interface
uses SysUtils, Rx;

var
  PrintString: TOnNext<TZip<LongWord, string>>;
  PressEnter: TOnCompleted;

implementation

initialization

  PrintString := procedure(const Data: TZip<LongWord, string>)
  begin
    WriteLn('');
    WriteLn('Timestamp: ' + TimeToStr(Now));
    WriteLn(Format('iter: %d     value: %s', [Data.A, Data.B]))
  end;

  PressEnter := procedure
  begin
    WriteLn('');
    WriteLn('Press ENTER to Exit');
    Readln;
  end;

end.
