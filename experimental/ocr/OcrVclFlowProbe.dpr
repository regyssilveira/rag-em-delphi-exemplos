program OcrVclFlowProbe;
{$APPTYPE CONSOLE}
uses System.SysUtils, Vcl.Forms, Rag.MainForm;
begin
  try
    if ParamCount <> 6 then raise Exception.Create('Informe PDF, runtime, dados, trabalho, DLL e relatório');
    Application.Initialize;
    Application.CreateForm(TAssistantForm, AssistantForm);
    try
      AssistantForm.RunOcrCheck(ParamStr(1), ParamStr(2), ParamStr(3), ParamStr(4), ParamStr(5), ParamStr(6));
    finally AssistantForm.Free; end;
    Writeln('OCR_VCL_PASSED');
  except on E: Exception do begin Writeln(E.ClassName, ': ', E.Message); ExitCode := 1; end; end;
end.
