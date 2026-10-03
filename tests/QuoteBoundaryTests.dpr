program QuoteBoundaryTests;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.JSON, Rag.Context, Rag.Answers;
var Context: TPreparedContext; Passed: Integer;
procedure Check(const Source, Quote: string;
  const Expected: Boolean; const Name: string);
var Root, Claim, Evidence: TJSONObject;
  Claims, Evidences: TJSONArray; Answer: TValidatedAnswer;
  Accepted: Boolean;
begin
  Context.Sources[0].Chunk.Text := Source;
  Root := TJSONObject.Create;
  try
    Root.AddPair('status', 'answered');
    Claims := TJSONArray.Create; Root.AddPair('claims', Claims);
    Claim := TJSONObject.Create; Claims.AddElement(Claim);
    Claim.AddPair('text', 'Verificacao do contrato literal.');
    Evidences := TJSONArray.Create; Claim.AddPair('evidence', Evidences);
    Evidence := TJSONObject.Create; Evidences.AddElement(Evidence);
    Evidence.AddPair('label', 'F1'); Evidence.AddPair('quote', Quote);
    Accepted := False;
    try Answer := ParseAnswer(Root.ToJSON, Context); Accepted := Answer.HasAnswer;
    except on E: EArgumentException do Accepted := False; end;
    if Accepted <> Expected then raise Exception.Create('FALHOU: ' + Name);
    Inc(Passed); Writeln('OK: ', Name);
  finally Root.Free; end;
end;
begin
  try
    SetLength(Context.Sources, 1); Context.Sources[0].LabelId := 'F1';
    Check('Somente o responsavel autoriza.', 'nte o responsavel', False, 'inicio no meio da palavra');
    Check('O prazo interno conhecido.', 'O prazo interno conhe', False, 'final no meio da palavra');
    Check('O prazo interno conhecido.', 'prazo interno conhecido', True, 'palavras completas sem pontuacao');
    Check('Xprazo interno conhecido; prazo interno conhecido.', 'prazo interno conhecido', True, 'segunda ocorrencia valida');
    Check('Autorizacao' + #$0301 + ' exigida.', 'Autorizacao', False, 'marca combinante nao separada');
    Check('Autorizacao' + #$0301 + ' exigida.', 'Autorizacao' + #$0301, True, 'marca combinante conservada');
    Writeln('PASSED=', Passed);
  except on E: Exception do begin Writeln(E.Message); ExitCode := 1; end; end;
end.
