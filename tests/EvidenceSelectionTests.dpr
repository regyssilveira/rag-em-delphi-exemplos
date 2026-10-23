program EvidenceSelectionTests;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.JSON, Rag.Types, Rag.Context, Rag.Answers,
  Rag.EvidenceContext, Rag.Generation.Extractive;
var Doc: TDocument; Ranked: TArray<TSearchResult>; Context: TPreparedContext;
  Answer: TValidatedAnswer; Checks: Integer; Bad: string; Rejected: Boolean;
  Parsed: TJSONValue; SourceObject: TJSONObject;
procedure Check(Value: Boolean; const Name: string);
begin
  if not Value then raise Exception.Create(Name);
  Inc(Checks); Writeln('OK: ', Name);
end;
begin
  try
    Doc := Default(TDocument);
    Doc.Id := 'own.md'; Doc.Source := 'own.md'; Doc.Access := 'operacional';
    Doc.Text := '# Procedimento' + #10#10 + '## Liberação' + #10#10 +
      'Somente a equipe de qualidade libera o lote após conferir o registro. ' +
      'A decisão inclui data e justificativa.';
    SetLength(Ranked, 1);
    Ranked[0].Chunk.DocumentId := Doc.Id;
    Ranked[0].Chunk.Id := 'own:chunk:1'; Ranked[0].Chunk.Source := Doc.Source;
    Ranked[0].Chunk.Access := Doc.Access;
    Ranked[0].Chunk.StartOffset := Pos('nte a equipe', Doc.Text);
    Ranked[0].Chunk.Text := Copy(Doc.Text, Ranked[0].Chunk.StartOffset, 35);
    Context := BuildEvidenceContext(Ranked, [Doc], 'operacional');
    Parsed := TJSONObject.ParseJSONValue(Context.Serialized);
    try
      SourceObject := (Parsed.FindValue('sources') as TJSONArray).Items[0] as TJSONObject;
      Check((SourceObject.GetValue<string>('documentTitle') = 'Procedimento') and
        (SourceObject.GetValue<string>('sectionTitle') = 'Liberação'),
        'Título e seção preservados no contexto, sem entrar na afirmação');
    finally Parsed.Free; end;
    Check((Length(Context.Sources) = 1) and
      Context.Sources[0].Chunk.Text.StartsWith('Somente') and
      Context.Sources[0].Chunk.Text.EndsWith('data e justificativa.'),
      'Parágrafo recomposto com exclusividade, condição e consequência');
    Check(Copy(Doc.Text, Context.Sources[0].Chunk.StartOffset,
      Length(Context.Sources[0].Chunk.Text)) = Context.Sources[0].Chunk.Text,
      'Posição exata no documento');
    Answer := TOllamaExtractiveProvider.DecodeSelection(
      '{"status":"answered","labels":["F1"]}', Context);
    Check(Answer.HasAnswer and (Answer.Claims[0].Text = Answer.Claims[0].Evidence[0].Quote)
      and (Answer.Claims[0].Text = Context.Sources[0].Chunk.Text),
      'Texto e evidência resolvidos sem paráfrase ou transcrição pelo modelo');
    Answer := TOllamaExtractiveProvider.DecodeSelection(
      '{"status":"insufficient","labels":[]}', Context);
    Check(not Answer.HasAnswer and (Length(Answer.Claims) = 0), 'Abstenção explícita');
    for Bad in [
      '{"status":"answered","labels":["F99"]}',
      '{"status":"answered","labels":["F1","F1"]}',
      '{"status":"answered","labels":[]}',
      '{"status":"insufficient","labels":["F1"]}',
      '{"status":"answered","labels":[1]}',
      '{"status":"answered","labels":["F1"],"text":"inventado"}',
      '{"status":"answered","status":"answered","labels":["F1"]}'] do
    begin
      Rejected := False;
      try TOllamaExtractiveProvider.DecodeSelection(Bad, Context);
      except on E: EArgumentException do Rejected := True; end;
      Check(Rejected, 'Contrato inválido recusado');
    end;
    SetLength(Ranked, 2); Ranked[1] := Ranked[0]; Ranked[1].Chunk.Id := 'second';
    Context := BuildEvidenceContext(Ranked, [Doc], 'operacional');
    Check(Length(Context.Sources) = 1, 'Parágrafo sobreposto não duplica evidência');
    Ranked[0].Chunk.Access := 'supervisor'; Ranked[1] := Ranked[0]; Doc.Access := 'supervisor';
    Context := BuildEvidenceContext(Ranked, [Doc], 'operacional');
    Check((Length(Context.Sources) = 0) and not Context.Serialized.Contains('qualidade'),
      'Documento restrito ausente antes da chamada ao modelo');
    Ranked[0].Chunk.Access := 'operacional';
    Rejected := False;
    try BuildEvidenceContext([Ranked[0]], [Doc], 'operacional');
    except on E: EArgumentException do Rejected := True; end;
    Check(Rejected, 'Classificação divergente não amplia acesso');
    Doc.Access := 'operacional'; Ranked[0].Chunk.Text := 'Texto que não pertence ao documento';
    Rejected := False;
    try BuildEvidenceContext([Ranked[0]], [Doc], 'operacional');
    except on E: EArgumentException do Rejected := True; end;
    Check(Rejected, 'Trecho forjado recusado');
    Doc.Text := StringOfChar('x', 1001); Ranked[0].Chunk.StartOffset := 1;
    Ranked[0].Chunk.Text := Copy(Doc.Text, 1, 100);
    Context := BuildEvidenceContext([Ranked[0]], [Doc], 'operacional');
    Check((Length(Context.Sources) = 0) and (Context.SkippedBudget = 1),
      'Parágrafo longo omitido sem corte silencioso');
    Writeln('CHECKS=', Checks);
  except on E: Exception do begin Writeln(E.Message); ExitCode := 1; end; end;
end.
