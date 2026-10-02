program IntegratedDemo;

{$APPTYPE CONSOLE}

uses System.SysUtils, System.IOUtils, System.JSON, Rag.Types, Rag.Core,
  Rag.Vectors, Rag.Embeddings, Rag.Persistence, Rag.Lexical, Rag.Hybrid,
  Rag.Context, Rag.Answers, Rag.Generation;

const
  EmbeddingModel = 'embeddinggemma:300m';
  EmbeddingDigest = '85462619ee721b466c5927d109d4cb765861907d5417b9109caebc4e614679f1';

var
  Embeddings: IEmbeddingProvider;
  Generator: IAnswerProvider;
  Documents: TArray<TDocument>;
  Chunks: TArray<TChunk>;
  Base: TPreparedBase;
  Stats: TUpdateStats;
  Lexical: TLexicalIndex;
  Vector: TVectorIndex;
  Context: TPreparedContext;
  Answer: TValidatedAnswer;
  Value: TJSONValue;
  Questions: TJSONArray;
  QuestionObject: TJSONValue;
  Claim: TAnswerClaim;
  Evidence: TAnswerEvidence;
  I, Passed, Failed: Integer;
  Profile, Question, ExpectedSource, ExpectedEvidence, Id: string;
  FoundSource, FoundEvidence, ExpectedAnswer: Boolean;
begin
  try
    if ParamCount <> 2 then raise Exception.Create('Use data/corpus data/evaluation/questions.json');
    Embeddings := TOllamaEmbeddingProvider.Create(EmbeddingModel, EmbeddingDigest, 768);
    Generator := TOllamaAnswerProvider.Create;
    SetLength(Documents, 3);
    Documents[0] := LoadDocument(TPath.Combine(ParamStr(1), 'recebimento.md'), 'operacional');
    Documents[1] := LoadDocument(TPath.Combine(ParamStr(1), 'devolucoes.md'), 'operacional');
    Documents[2] := LoadDocument(TPath.Combine(ParamStr(1), 'estoque.md'), 'supervisor');
    Base := PrepareBase(Documents, Default(TPreparedBase), Embeddings, 768, 380, 60, Stats);
    SavePreparedBase(TPath.Combine(ExtractFilePath(ParamStr(0)), 'integrated-base.json'), Base);
    Base := LoadPreparedBase(TPath.Combine(ExtractFilePath(ParamStr(0)), 'integrated-base.json'), Embeddings.ModelIdentity);
    SetLength(Chunks, Length(Base.Items));
    for I := 0 to High(Chunks) do Chunks[I] := Base.Items[I].Chunk;
    Lexical := TLexicalIndex.Create(Chunks);
    Vector := TVectorIndex.Create(Base.Items, Embeddings.ModelIdentity);
    try
      Value := TJSONObject.ParseJSONValue(TFile.ReadAllText(ParamStr(2), TEncoding.UTF8));
      try
        if not (Value is TJSONArray) then raise Exception.Create('Perguntas inválidas');
        Questions := TJSONArray(Value);
        Passed := 0;
        Failed := 0;
        for QuestionObject in Questions do
        begin
          Id := QuestionObject.FindValue('id').Value;
          Question := QuestionObject.FindValue('question').Value;
          Profile := QuestionObject.FindValue('profile').Value;
          ExpectedAnswer := not (QuestionObject.FindValue('expected_source') is TJSONNull);
          ExpectedSource := QuestionObject.FindValue('expected_source').Value;
          ExpectedEvidence := QuestionObject.FindValue('expected_evidence').Value;
          try
            Context := BuildContext(FuseRankings(Lexical.Search(Question, Profile, 6),
              Vector.Search(Embeddings.EmbedQuery(Question), Embeddings.ModelIdentity, Profile, 6),
              Profile, 6), Profile, 6000, 6);
            Answer := Generator.Generate(Question, Context);
            TFile.WriteAllText(TPath.Combine(ExtractFilePath(ParamStr(0)), 'integrated-' + Id + '.json'), Generator.LastResponse, TEncoding.UTF8);
            FoundSource := False;
            FoundEvidence := False;
            for Claim in Answer.Claims do
            begin
              if (Id = 'Q04') and Claim.Text.TrimLeft.ToLower.StartsWith('sim') then
                raise Exception.Create('Resposta afirmativa contradiz a regra de não retorno automático');
              Writeln(Id, ' CLAIM ', Claim.Text);
              for Evidence in Claim.Evidence do
              begin
                Writeln(Id, ' SOURCE ', Evidence.Source.Chunk.Id, ' QUOTE ', Evidence.Quote);
                if Evidence.Source.Chunk.DocumentId = ExpectedSource then FoundSource := True;
                if not ExpectedEvidence.IsEmpty and Evidence.Quote.ToLower.Contains(ExpectedEvidence.ToLower) then FoundEvidence := True;
                if (Profile = 'operacional') and (Evidence.Source.Chunk.Access <> 'operacional') then
                  raise Exception.Create('Fonte restrita na resposta');
              end;
            end;
            if (Answer.HasAnswer <> ExpectedAnswer) or
              (ExpectedAnswer and not (FoundSource and FoundEvidence)) then
              raise Exception.Create('Resposta diverge da evidência esperada');
            Inc(Passed);
            Writeln('OK: ', Id);
          except on E: Exception do
            begin
              Inc(Failed);
              TFile.WriteAllText(TPath.Combine(ExtractFilePath(ParamStr(0)), 'integrated-' + Id + '.json'), Generator.LastResponse, TEncoding.UTF8);
              Writeln('FAIL: ', Id, ' | ', E.Message);
            end;
          end;
        end;
        Writeln('PASSED=', Passed, ' FAILED=', Failed);
        if Failed > 0 then ExitCode := 1;
      finally Value.Free; end;
    finally Vector.Free; Lexical.Free; end;
  except on E: Exception do begin Writeln(E.Message); ExitCode := 1; end; end;
end.
