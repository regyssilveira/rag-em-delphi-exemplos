program CacheDemo;

{$APPTYPE CONSOLE}

uses System.SysUtils, System.IOUtils, System.JSON, System.Generics.Collections,
  Rag.Types, Rag.Core, Rag.Vectors, Rag.Embeddings, Rag.Persistence,
  Rag.Lexical, Rag.Hybrid;

const
  Model = 'embeddinggemma:300m';
  Digest = '85462619ee721b466c5927d109d4cb765861907d5417b9109caebc4e614679f1';
  Identity = Model + '@' + Digest + '|retrieval-prefix-v1|dim=768';

procedure Check(Value: Boolean; const MessageText: string);
begin
  if not Value then raise Exception.Create('FALHOU: ' + MessageText);
  Writeln('OK: ', MessageText);
end;

function QueryFile: string;
begin Result := TPath.Combine(ExtractFilePath(ParamStr(0)), 'cache-query.json'); end;
function BaseFile: string;
begin Result := TPath.Combine(ExtractFilePath(ParamStr(0)), 'real-cache.json'); end;

procedure SaveQuery(const Vector: TEmbedding);
var Json: TJSONObject; Values: TJSONArray; Component: Double;
begin
  Json := TJSONObject.Create;
  try
    Json.AddPair('modelIdentity', Identity);
    Values := TJSONArray.Create;
    Json.AddPair('vector', Values);
    for Component in Vector do Values.AddElement(TJSONNumber.Create(Component));
    TFile.WriteAllText(QueryFile, Json.ToJSON, TEncoding.UTF8);
  finally Json.Free; end;
end;

function LoadQuery: TEmbedding;
var Json: TJSONValue; Values: TJSONArray; I: Integer;
begin
  Json := TJSONObject.ParseJSONValue(TFile.ReadAllText(QueryFile, TEncoding.UTF8));
  if Json = nil then raise Exception.Create('Consulta JSON inválida');
  try
    if (Json.FindValue('modelIdentity') = nil) or (Json.FindValue('modelIdentity').Value <> Identity) or
      not (Json.FindValue('vector') is TJSONArray) then raise Exception.Create('Contrato da consulta inválido');
    Values := Json.FindValue('vector') as TJSONArray;
    if Values.Count <> 768 then raise Exception.Create('Dimensão da consulta inválida');
    SetLength(Result, Values.Count);
    for I := 0 to Values.Count - 1 do
    begin
      if not (Values.Items[I] is TJSONNumber) then raise Exception.Create('Componente inválido');
      Result[I] := (Values.Items[I] as TJSONNumber).AsDouble;
    end;
  finally Json.Free; end;
end;

procedure Prepare;
var
  Documents: TArray<TDocument>;
  Provider: IEmbeddingProvider;
  Base, Previous: TPreparedBase;
  Stats: TUpdateStats;
  Query: TEmbedding;
begin
  if ParamCount <> 3 then raise Exception.Create('Use --prepare data/corpus data/updates');
  Provider := TOllamaEmbeddingProvider.Create(Model, Digest, 768);
  SetLength(Documents, 3);
  Documents[0] := LoadDocument(TPath.Combine(ParamStr(2), 'recebimento.md'), 'operacional');
  Documents[1] := LoadDocument(TPath.Combine(ParamStr(2), 'devolucoes.md'), 'operacional');
  Documents[2] := LoadDocument(TPath.Combine(ParamStr(2), 'estoque.md'), 'supervisor');
  Base := PrepareBase(Documents, Default(TPreparedBase), Provider, 768, 380, 60, Stats);
  Check((Stats.Embedded = 8) and (Length(Base.Items) = 8), 'base real preparada com oito trechos');
  SavePreparedBase(BaseFile, Base);
  Previous := LoadPreparedBase(BaseFile, Identity);
  Base := PrepareBase(Documents, Previous, Provider, 768, 380, 60, Stats);
  Check((Stats.Embedded = 0) and (Stats.Reused = 8), 'reabertura reutiliza oito embeddings reais');
  Previous := Base;
  Documents[1].Text := LoadDocument(TPath.Combine(ParamStr(3), 'devolucoes-v2.md'), 'operacional').Text;
  Base := PrepareBase(Documents, Previous, Provider, 768, 380, 60, Stats);
  Check((Stats.Embedded > 0) and (Stats.Reused > 0), 'atualização real gera afetados e reutiliza demais');
  Writeln('UPDATE embedded=', Stats.Embedded, ' reused=', Stats.Reused, ' removed=', Stats.Removed);
  Check(Base.Documents[1].Text.Contains('três dias úteis') and not Base.Documents[1].Text.Contains('dois dias úteis'), 'prazo atualizado sem regra antiga');
  Previous := Base;
  SetLength(Documents, 2);
  Base := PrepareBase(Documents, Previous, Provider, 768, 380, 60, Stats);
  Check((Stats.Removed = 2) and (Length(Base.Items) = 6), 'exclusão real remove os dois trechos de estoque');
  SavePreparedBase(BaseFile, Base);
  Query := Provider.EmbedQuery('Qual é o prazo interno de análise de devolução?');
  SaveQuery(Query);
  Provider := nil;
end;

procedure Offline;
var
  Base: TPreparedBase;
  Chunks: TArray<TChunk>;
  Lexical: TLexicalIndex;
  Vector: TVectorIndex;
  Results: TArray<TSearchResult>;
  Query: TEmbedding;
  I: Integer;
  FoundUpdated: Boolean;
begin
  Base := LoadPreparedBase(BaseFile, Identity);
  Query := LoadQuery;
  SetLength(Chunks, Length(Base.Items));
  for I := 0 to High(Chunks) do Chunks[I] := Base.Items[I].Chunk;
  Lexical := TLexicalIndex.Create(Chunks);
  Vector := TVectorIndex.Create(Base.Items, Identity);
  try
    Results := FuseRankings(Lexical.Search('prazo interno análise devolução', 'operacional', 6),
      Vector.Search(Query, Identity, 'operacional', 6), 'operacional', 3);
    Check(Length(Results) > 0, 'base reaberta permite fusão sem provedor');
    FoundUpdated := False;
    for I := 0 to High(Results) do
    begin
      Writeln('HYBRID ', Results[I].Chunk.Id, ' | ', FormatFloat('0.000000', Results[I].Score));
      if Results[I].Chunk.Text.Contains('três dias úteis') then FoundUpdated := True;
      if Results[I].Chunk.Text.Contains('dois dias úteis') then raise Exception.Create('Regra antiga recuperada');
      if Results[I].Chunk.DocumentId = 'estoque.md' then raise Exception.Create('Documento excluído recuperado');
    end;
    Check(FoundUpdated, 'ranking híbrido contém prazo novo e exclui versão antiga');
  finally Vector.Free; Lexical.Free; end;
end;

begin
  try
    if ParamStr(1) = '--prepare' then Prepare
    else if (ParamStr(1) = '--offline') and (ParamCount = 1) then Offline
    else raise Exception.Create('Modo inválido');
  except on E: Exception do begin Writeln(E.Message); ExitCode := 1; end; end;
end.
