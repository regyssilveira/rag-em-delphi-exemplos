unit Rag.Assistant;

interface

uses System.SysUtils, Rag.Persistence, Rag.Embeddings, Rag.Generation,
  Rag.Context, Rag.Answers;

type
  TAssistantResponse = record
    Context: TPreparedContext;
    Answer: TValidatedAnswer;
  end;

function QueryPreparedBase(const Base: TPreparedBase; const Question, Profile: string;
  Embeddings: IEmbeddingProvider; Generator: IAnswerProvider): TAssistantResponse;

implementation

uses Rag.Types, Rag.Lexical, Rag.Vectors, Rag.Hybrid;

function QueryPreparedBase(const Base: TPreparedBase; const Question, Profile: string;
  Embeddings: IEmbeddingProvider; Generator: IAnswerProvider): TAssistantResponse;
var
  Chunks: TArray<TChunk>;
  Lexical: TLexicalIndex;
  Vector: TVectorIndex;
  I, Allowed: Integer;
begin
  Result := Default(TAssistantResponse);
  if (Profile <> 'operacional') and (Profile <> 'supervisor') then
    raise EArgumentException.Create('Perfil desconhecido');
  if Question.Trim.IsEmpty or (Length(Question) > 1000) then
    raise EArgumentException.Create('Pergunta fora dos limites');
  ValidatePreparedBase(Base);
  Allowed := 0;
  for I := 0 to High(Base.Items) do
    if (Base.Items[I].Chunk.Access = 'operacional') or
      ((Profile = 'supervisor') and (Base.Items[I].Chunk.Access = 'supervisor')) then Inc(Allowed);
  if Allowed = 0 then
  begin
    Result.Context := BuildContext(nil, Profile, 6000, 6);
    Exit;
  end;
  if (Embeddings = nil) or (Generator = nil) then
    raise EArgumentException.Create('Provedores ausentes');
  if Base.ModelIdentity <> Embeddings.ModelIdentity then
    raise EArgumentException.Create('Modelo incompatível com a base');
  SetLength(Chunks, Length(Base.Items));
  for I := 0 to High(Chunks) do Chunks[I] := Base.Items[I].Chunk;
  Lexical := TLexicalIndex.Create(Chunks);
  try
    Vector := TVectorIndex.Create(Base.Items, Base.ModelIdentity);
    try
      Result.Context := BuildContext(FuseRankings(Lexical.Search(Question, Profile, 6),
        Vector.Search(Embeddings.EmbedQuery(Question), Base.ModelIdentity, Profile, 6),
        Profile, 6), Profile, 6000, 6);
      if Length(Result.Context.Sources) > 0 then
        Result.Answer := Generator.Generate(Question, Result.Context);
    finally Vector.Free; end;
  finally Lexical.Free; end;
end;

end.
