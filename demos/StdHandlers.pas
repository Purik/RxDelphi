unit StdHandlers;

interface
uses SysUtils, Entities, Rx;

var
  PrintString: TOnNext<TZip<LongWord, string>>;
  WriteLn: TOnNext<string>;
  PressEnter: TOnCompleted;
  RandomPersons: TOnSubscribe<TPerson>;

implementation

initialization

  WriteLn := procedure(const Line: string)
  begin
    System.WriteLn(Line);
  end;

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

  RandomPersons := procedure(O: IObserver<TPerson>)
  begin
    O.OnNext(
      TPerson.Create('David', 'Snow', '')
    );
    O.OnNext(
      TPerson.Create('Helen', 'Peterson', '')
    );
    O.OnNext(
      TPerson.Create('Helga', 'Yensen', '')
    );
    O.OnNext(
      TPerson.Create('Djohn', 'Petrucchi', '')
    );
    O.OnNext(
      TPerson.Create('Tom', 'Soyer', '')
    );
    O.OnNext(
      TPerson.Create('Lev', 'Tolstoy', '')
    );
    O.OnNext(
      TPerson.Create('Pavel', 'Minenkov', '')
    );
    O.OnCompleted;
  end;


end.
