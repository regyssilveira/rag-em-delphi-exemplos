program NativeOcrTests;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.IOUtils, System.JSON,
  Rag.Ocr, Rag.WindowsOcr;
var Provider: IOcrProvider; Page: TOcrPage; Root: TJSONObject;
begin
  try
    if ParamCount <> 3 then raise EArgumentException.Create('Use imagem branca resultado.json');
    Provider := TWindowsOcrProvider.Create;
    Page := Provider.Recognize(ParamStr(1), ParamStr(1), 1, nil);
    if not Page.Text.Contains('supervisor') or not Page.Text.Contains('não') or
      not Page.Text.Contains('2 dias') then raise Exception.Create('Regra conhecida alterada');
    Root := TJSONObject.Create;
    try
      Root.AddPair('recognized', Page.Text);
      Root.AddPair('identity', Page.RecognitionIdentity);
      Page := Provider.Recognize(ParamStr(2), ParamStr(2), 2, nil);
      if not Page.Text.Trim.IsEmpty then raise Exception.Create('Imagem branca produziu texto');
      Root.AddPair('blankPassed', TJSONBool.Create(True));
      TFile.WriteAllText(ParamStr(3), Root.ToJSON, TEncoding.UTF8);
    finally Root.Free; end;
    Writeln('NativeOcrProviderPassed=True');
  except on E: Exception do begin Writeln(E.ClassName, ': ', E.Message); ExitCode := 1; end; end;
end.
