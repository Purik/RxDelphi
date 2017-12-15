program tutorial2_map;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Rx,
  System.SysUtils,
  StdHandlers in 'StdHandlers.pas',
  Entities in 'Entities.pas';

var
  Input: TObservable<TPerson>;
  Output: TObservable<string>;
  Categorize: TMap<TPerson, string>;

begin
  // Check memory leaks after application termination
  ReportMemoryLeaksOnShutdown := True;

  { Extract ages of persons and categorize them by generation types}
  Categorize := function(const Person: TPerson): string
  begin
    if Person.Age < 12 then
      Result := 'child'
    else if Person.Age < 18 then
      Result := 'teenager'
    else
      Result := 'adult'
  end;

  { Run conveyor }
  Input := TObservable<TPerson>.Create(StdHandlers.RandomPersons);
  Output := Input.Map<string>(Categorize);
  Output.Subscribe(
    StdHandlers.WriteLn,
    StdHandlers.PressEnter
  );
  Output.WaitCompletition(INFINITE)

end.
