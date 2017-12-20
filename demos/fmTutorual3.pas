unit fmTutorual3;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Rx, Entities;

type
  TMainForm = class(TForm)
    BtnSubscribe: TButton;
    BtnUnsubscribe: TButton;
    Content: TMemo;
    procedure BtnSubscribeClick(Sender: TObject);
    procedure BtnUnsubscribeClick(Sender: TObject);
  private
    FSubscription: ISubscription;
    function GetTwitter: TObservable<TTwit>;
    procedure OnTwit(const A: TTwit);
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

procedure TMainForm.BtnSubscribeClick(Sender: TObject);
var
  Twitter: TObservable<TTwit>;
begin
  Twitter := GetTwitter;
  // All callbacks will be scheduled to MainThread to avoid GUI
  // multithreading problem
  Twitter.ScheduleOn(StdSchedulers.CreateMainThreadScheduler);
  FSubscription := Twitter.Subscribe(OnTwit);
  // GUI
  BtnSubscribe.Enabled := False;
  BtnUnsubscribe.Enabled := True;
end;

procedure TMainForm.BtnUnsubscribeClick(Sender: TObject);
begin
  FSubscription.Unsubscribe;
  // GUI
  BtnSubscribe.Enabled := True;
  BtnUnsubscribe.Enabled := False;
end;

function TMainForm.GetTwitter: TObservable<TTwit>;
begin

end;

procedure TMainForm.OnTwit(const A: TTwit);
begin
  Content.Lines.Add('');
  Content.Lines.Add(Format('From: %s', [A.Author]));
  Content.Lines.Add('_________________');
  Content.Lines.Add(A.Text);
end;

end.
