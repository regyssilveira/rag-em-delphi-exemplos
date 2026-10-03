program OcrInvalidTextChild;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.IOUtils;
begin
  if ParamCount < 2 then Halt(1);
  TFile.WriteAllBytes(ParamStr(2) + '.txt', TBytes.Create($C3, $28));
end.
