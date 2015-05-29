program PowerdesignerAssistant;

uses
  Forms,
  fMain in 'fMain.pas' {FrmMain},
  uShared in 'uShared.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'Powerdesigner assistant';
  Application.CreateForm(TFrmMain, FrmMain);
  Application.Run;
end.
