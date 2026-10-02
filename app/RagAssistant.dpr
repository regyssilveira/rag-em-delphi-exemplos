program RagAssistant;

uses System.SysUtils, System.IOUtils, Vcl.Forms,
  Rag.MainForm in 'Rag.MainForm.pas';

begin
  try
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TAssistantForm, AssistantForm);
  if (ParamCount = 3) and (ParamStr(1) = '--flow-check') then
  begin
    AssistantForm.RunFlowCheck(ParamStr(2), ParamStr(3));
    AssistantForm.Free;
  end
  else Application.Run;
  except
    on E: Exception do
    begin
      if (ParamCount = 3) and (ParamStr(1) = '--flow-check') then
      begin
        if not TFile.Exists(ParamStr(3)) then
          TFile.WriteAllText(ParamStr(3), '{"passed":false}', TEncoding.UTF8);
        TFile.WriteAllText(ParamStr(3) + '.error.txt', E.ClassName + ': ' + E.Message, TEncoding.UTF8);
        Halt(1);
      end;
      raise;
    end;
  end;
end.
