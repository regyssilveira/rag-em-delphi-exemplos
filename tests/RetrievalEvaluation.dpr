program RetrievalEvaluation;
{$APPTYPE CONSOLE}
uses System.Math, System.SysUtils, System.Classes, System.IOUtils, System.JSON,
  Rag.Types, Rag.Persistence, Rag.Embeddings, Rag.Vectors, Rag.Lexical, Rag.Hybrid;

function RankingReport(const Ranking: TArray<TSearchResult>;
  const ExpectedSource, Evidence, Profile: string): TJSONObject;
var Items: TJSONArray; Item: TSearchResult; Position, FirstRelevant: Integer;
  Entry: TJSONObject;
begin
  Result := TJSONObject.Create;
  Items := TJSONArray.Create;
  Result.AddPair('ranking', Items);
  FirstRelevant := 0; Position := 0;
  for Item in Ranking do
  begin
    Inc(Position);
    if (Item.Chunk.Access <> 'operacional') and
      not ((Profile = 'supervisor') and (Item.Chunk.Access = 'supervisor')) then
      raise Exception.Create('Trecho fora do perfil');
    Entry := TJSONObject.Create;
    Entry.AddPair('chunkId', Item.Chunk.Id);
    Entry.AddPair('documentId', Item.Chunk.DocumentId);
    Entry.AddPair('score', TJSONNumber.Create(Item.Score));
    Items.AddElement(Entry);
    if (FirstRelevant = 0) and (ExpectedSource <> '') and
      (Item.Chunk.DocumentId = ExpectedSource) and Item.Chunk.Text.Contains(Evidence) then
      FirstRelevant := Position;
  end;
  Result.AddPair('firstRelevantRank', TJSONNumber.Create(FirstRelevant));
  Result.AddPair('hasExpectedEvidence', TJSONBool.Create(FirstRelevant > 0));
end;

var Base: TPreparedBase; Provider: IEmbeddingProvider; Chunks: TArray<TChunk>;
  Lexical: TLexicalIndex; Vector: TVectorIndex; Questions: TJSONValue;
  Question: TJSONValue; Output: TJSONObject; Cases: TJSONArray; Row: TJSONObject;
  Query, Profile, ExpectedSource, Evidence: string; QueryVector: TEmbedding;
  L, V, H: TArray<TSearchResult>; I, K: Integer;
begin
try
  if ParamCount <> 3 then raise Exception.Create('Informe base, perguntas e relatório');
  Provider := TOllamaEmbeddingProvider.Create('embeddinggemma:300m',
    '85462619ee721b466c5927d109d4cb765861907d5417b9109caebc4e614679f1', 768);
  Base := LoadPreparedBase(ParamStr(1), Provider.ModelIdentity);
  SetLength(Chunks, Length(Base.Items));
  for I := 0 to High(Chunks) do Chunks[I] := Base.Items[I].Chunk;
  Lexical := TLexicalIndex.Create(Chunks);
  Vector := TVectorIndex.Create(Base.Items, Base.ModelIdentity);
  Questions := TJSONObject.ParseJSONValue(TFile.ReadAllText(ParamStr(2), TEncoding.UTF8));
  Output := TJSONObject.Create;
  try
    if not (Questions is TJSONArray) then raise Exception.Create('Perguntas inválidas');
    Cases := TJSONArray.Create; Output.AddPair('cases', Cases);
    Output.AddPair('embeddingIdentity', Base.ModelIdentity);
    Output.AddPair('scope', 'Recuperação em perguntas próprias; sem geração ou avaliação semântica geral. Rank 0 significa nenhuma evidência esperada entre os resultados.');
    for Question in Questions as TJSONArray do
    begin
      Query := Question.GetValue<string>('question');
      Profile := Question.GetValue<string>('profile');
      ExpectedSource := ''; Evidence := '';
      if not (Question.FindValue('expected_source') is TJSONNull) then
      begin
        ExpectedSource := Question.GetValue<string>('expected_source');
        Evidence := Question.GetValue<string>('expected_evidence');
      end;
      QueryVector := Provider.EmbedQuery(Query);
      for K in [1, 3, 6] do
      begin
        L := Lexical.Search(Query, Profile, 6);
        V := Vector.Search(QueryVector, Base.ModelIdentity, Profile, 6);
        H := FuseRankings(L, V, Profile, K);
        SetLength(L, Min(K, Length(L))); SetLength(V, Min(K, Length(V)));
        Row := TJSONObject.Create; Cases.AddElement(Row);
        Row.AddPair('id', Question.GetValue<string>('id'));
        Row.AddPair('profile', Profile); Row.AddPair('topK', TJSONNumber.Create(K));
        Row.AddPair('answerable', TJSONBool.Create(ExpectedSource <> ''));
        Row.AddPair('lexical', RankingReport(L, ExpectedSource, Evidence, Profile));
        Row.AddPair('vector', RankingReport(V, ExpectedSource, Evidence, Profile));
        Row.AddPair('hybrid', RankingReport(H, ExpectedSource, Evidence, Profile));
      end;
    end;
    TFile.WriteAllText(ParamStr(3), Output.ToJSON, TEncoding.UTF8);
    Writeln('OK: ', Cases.Count, ' casos, ', (Questions as TJSONArray).Count, ' consultas vetoriais reais, três métodos');
  finally Output.Free; Questions.Free; Vector.Free; Lexical.Free; end;
except on E: Exception do begin Writeln(E.Message); ExitCode := 1; end; end;
end.
