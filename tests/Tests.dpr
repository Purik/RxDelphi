program Tests;
{

  Delphi DUnit Test Project
  -------------------------
  This project contains the DUnit test framework and the GUI/Console test runners.
  Add "CONSOLE_TESTRUNNER" to the conditional defines entry in the project options
  to use the console test runner.  Otherwise the GUI test runner will be used by
  default.

}

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  DUnitTestRunner,
  ObservableImplTests in 'ObservableImplTests.pas',
  Rx.Fibers in '..\src\Rx.Fibers.pas',
  Rx.Implementations in '..\src\Rx.Implementations.pas',
  Rx.Observable.AdvancedOps in '..\src\Rx.Observable.AdvancedOps.pas',
  Rx.Observable.Defer in '..\src\Rx.Observable.Defer.pas',
  Rx.Observable.Delay in '..\src\Rx.Observable.Delay.pas',
  Rx.Observable.Empty in '..\src\Rx.Observable.Empty.pas',
  Rx.Observable.Filter in '..\src\Rx.Observable.Filter.pas',
  Rx.Observable.FlatMap in '..\src\Rx.Observable.FlatMap.pas',
  Rx.Observable.Just in '..\src\Rx.Observable.Just.pas',
  Rx.Observable.Map in '..\src\Rx.Observable.Map.pas',
  Rx.Observable.Never in '..\src\Rx.Observable.Never.pas',
  Rx.Observable.Take in '..\src\Rx.Observable.Take.pas',
  Rx.Observable.Zip in '..\src\Rx.Observable.Zip.pas',
  Rx in '..\src\Rx.pas',
  Rx.Schedulers in '..\src\Rx.Schedulers.pas',
  Rx.Subjects in '..\src\Rx.Subjects.pas';

{$R *.RES}

begin
  DUnitTestRunner.RunRegisteredTests;
  ReportMemoryLeaksOnShutdown := True;
end.

