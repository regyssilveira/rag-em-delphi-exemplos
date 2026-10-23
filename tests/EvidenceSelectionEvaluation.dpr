program EvidenceSelectionEvaluation;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.Classes, System.IOUtils, System.JSON,
  System.Generics.Collections, System.Diagnostics, Rag.Types, Rag.Core, Rag.Vectors,
  Rag.Embeddings, Rag.Persistence, Rag.Generation, Rag.Generation.Extractive,
  Rag.ExtractiveAssistant, Rag.Answers, Rag.Context;
var Documents: TList<TDocument>; Name, Access, Id, Question, Profile, Folder: string;
  Embeddings: IEmbeddingProvider; Generator: IAnswerProvider;
  Base: TPreparedBase; Stats: TUpdateStats; Value, CaseValue, Minimum: TJSONValue;
  Response: TAssistantResponse; Claim: TAnswerClaim; Evidence: TAnswerEvidence;
  Report, Row, Item: TJSONObject; Rows, Claims, Evidences: TJSONArray;
  ExpectedSource, ExpectedEvidence: string; ExpectedAnswer, Found, ClaimMinimum: Boolean;
  Passed, Failed: Integer; Watch: TStopwatch;
begin
  try
    if ParamCount <> 3 then raise Exception.Create('Informe corpus, perguntas e pasta nova');
    Folder := TPath.GetFullPath(ParamStr(3));
    if TDirectory.Exists(Folder) then raise Exception.Create('Use uma pasta nova por rodada');
    TDirectory.CreateDirectory(Folder);
    Embeddings := TOllamaEmbeddingProvider.Create('embeddinggemma:300m',
      '85462619ee721b466c5927d109d4cb765861907d5417b9109caebc4e614679f1', 768);
    Generator := TOllamaExtractiveProvider.Create;
    Documents := TList<TDocument>.Create;
    try
      for Name in TDirectory.GetFiles(ParamStr(1), '*.md') do
      begin
        Access := 'operacional';
        if SameText(TPath.GetFileName(Name), 'estoque.md') then Access := 'supervisor';
        Documents.Add(LoadDocument(Name, Access));
      end;
      Base := PrepareBase(Documents.ToArray, Default(TPreparedBase),
        Embeddings, 768, 380, 60, Stats);
    finally Documents.Free; end;
    SavePreparedBase(TPath.Combine(Folder, 'base.json'), Base);
    Base := LoadPreparedBase(TPath.Combine(Folder, 'base.json'), Embeddings.ModelIdentity);
    Value := TJSONObject.ParseJSONValue(TFile.ReadAllText(ParamStr(2), TEncoding.UTF8));
    Report := TJSONObject.Create;
    try
      if not (Value is TJSONArray) then raise Exception.Create('Perguntas inválidas');
      Rows := TJSONArray.Create; Report.AddPair('cases', Rows);
      Report.AddPair('generationIdentity', Generator.ModelIdentity);
      Passed := 0; Failed := 0;
      Watch := TStopwatch.StartNew;
      for CaseValue in TJSONArray(Value) do
      begin
        if Watch.Elapsed.TotalMinutes > 10 then
          raise EAnswerTransportError.Create('Orçamento de dez minutos excedido');
        Id := CaseValue.GetValue<string>('id');
        Question := CaseValue.GetValue<string>('question');
        Profile := CaseValue.GetValue<string>('profile');
        ExpectedAnswer := not (CaseValue.FindValue('expected_source') is TJSONNull);
        ExpectedSource := ''; ExpectedEvidence := '';
        if ExpectedAnswer then
        begin
          ExpectedSource := CaseValue.GetValue<string>('expected_source');
          ExpectedEvidence := CaseValue.GetValue<string>('expected_evidence');
        end;
        Row := TJSONObject.Create; Rows.AddElement(Row);
        Row.AddPair('id', Id); Row.AddPair('question', Question); Row.AddPair('profile', Profile);
        Row.AddPair('expectedAnswer', TJSONBool.Create(ExpectedAnswer));
        try
          Response := QueryPreparedBase(Base, Question, Profile, Embeddings, Generator);
          TFile.WriteAllText(TPath.Combine(Folder, 'extended-context-' + Id + '.json'),
            Response.Context.Serialized, TEncoding.UTF8);
          Row.AddPair('context', TJSONObject.ParseJSONValue(Response.Context.Serialized));
          Row.AddPair('hasAnswer', TJSONBool.Create(Response.Answer.HasAnswer));
          Claims := TJSONArray.Create; Row.AddPair('claims', Claims); Found := False;
          for Claim in Response.Answer.Claims do
          begin
            Item := TJSONObject.Create.AddPair('text', Claim.Text);
            Claims.AddElement(Item); Evidences := TJSONArray.Create;
            Item.AddPair('evidence', Evidences);
            ClaimMinimum := CaseValue.FindValue('expected_claim_any') = nil;
            if not ClaimMinimum then
              for Minimum in TJSONArray(CaseValue.FindValue('expected_claim_any')) do
                if Claim.Text.ToLower.Contains(Minimum.Value.ToLower) then ClaimMinimum := True;
            for Evidence in Claim.Evidence do
            begin
              if (Claim.Text <> Evidence.Quote) or
                (Evidence.Quote <> Evidence.Source.Chunk.Text) then
                raise Exception.Create('Texto extrativo modificado');
              if (Profile = 'operacional') and (Evidence.Source.Chunk.Access <> 'operacional') then
                raise Exception.Create('Fonte restrita');
              Evidences.AddElement(TJSONObject.Create.AddPair('source',
                Evidence.Source.Chunk.DocumentId).AddPair('quote', Evidence.Quote));
              if (Evidence.Source.Chunk.DocumentId = ExpectedSource) and
                Evidence.Quote.ToLower.Contains(ExpectedEvidence.ToLower) and ClaimMinimum then Found := True;
            end;
          end;
          if (Response.Answer.HasAnswer <> ExpectedAnswer) or
            (ExpectedAnswer and not Found) then raise Exception.Create('Resposta diverge da referência');
          Row.AddPair('passed', TJSONBool.Create(True)); Inc(Passed);
          Writeln('OK: ', Id);
        except on E: Exception do
          begin
            Row.AddPair('passed', TJSONBool.Create(False));
            Row.AddPair('error', E.Message); Inc(Failed); Writeln('FAIL: ', Id, ' | ', E.Message);
            if E is EAnswerTransportError then
            begin
              TFile.WriteAllText(TPath.Combine(Folder, 'extended-answer-' + Id + '.json'),
                Generator.LastResponse, TEncoding.UTF8);
              Report.AddPair('executionComplete', TJSONBool.Create(False));
              TFile.WriteAllText(TPath.Combine(Folder, 'evaluation.json'), Report.ToJSON, TEncoding.UTF8);
              raise;
            end;
          end;
        end;
        TFile.WriteAllText(TPath.Combine(Folder, 'extended-answer-' + Id + '.json'),
          Generator.LastResponse, TEncoding.UTF8);
        TFile.WriteAllText(TPath.Combine(Folder, 'evaluation.json'), Report.ToJSON, TEncoding.UTF8);
        Flush(Output);
      end;
      Report.AddPair('passed', TJSONNumber.Create(Passed));
      Report.AddPair('failed', TJSONNumber.Create(Failed));
      TFile.WriteAllText(TPath.Combine(Folder, 'evaluation.json'), Report.ToJSON, TEncoding.UTF8);
      Writeln('PASSED=', Passed, ' FAILED=', Failed);
      if Failed > 0 then ExitCode := 1;
    finally Report.Free; Value.Free; end;
  except on E: Exception do begin Writeln(E.Message); ExitCode := 1; end; end;
end.
