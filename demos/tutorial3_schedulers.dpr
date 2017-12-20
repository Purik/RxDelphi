program tutorial3_schedulers;

uses
  Vcl.Forms,
  fmTutorual3 in 'fmTutorual3.pas' {MainForm};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
