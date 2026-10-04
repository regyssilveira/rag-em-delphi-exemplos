program WindowsOcrGuardTests;
{$APPTYPE CONSOLE}
uses System.SysUtils, Rag.Ocr, Rag.WindowsOcr;
var Provider: IOcrProvider; Passed: Integer;
begin
  try
    Passed := 0;
    try Provider := TWindowsOcrProvider.Create(0);
      raise Exception.Create('Tempo inválido aceito');
    except on E: EArgumentException do Inc(Passed); end;
    Provider := TWindowsOcrProvider.Create;
    try Provider.Recognize('', 'imagem', 0,
      function: Boolean begin Result := True; end);
      raise Exception.Create('Cancelamento ignorado');
    except on E: EOcrCancelled do Inc(Passed); end;
    try Provider.Recognize('', '', -1, nil);
      raise Exception.Create('Origem inválida aceita');
    except on E: EArgumentException do Inc(Passed); end;
    Writeln('PASSED=', Passed);
    if Passed <> 3 then ExitCode := 1;
  except on E: Exception do begin Writeln(E.ClassName, ': ', E.Message); ExitCode := 1; end; end;
end.
