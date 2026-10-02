unit Rag.Context;

interface

uses System.SysUtils, Rag.Types;

type
  TContextSource = record
    LabelId: string;
    Chunk: TChunk;
  end;
  TPreparedContext = record
    Serialized: string;
    Sources: TArray<TContextSource>;
    SkippedForbidden: Integer;
    SkippedBudget: Integer;
  end;

function BuildContext(const Ranked: TArray<TSearchResult>; const Profile: string;
  MaxChars: Integer; MaxChunks: Integer = 6): TPreparedContext;

implementation

uses System.JSON, System.Generics.Collections;

function SerializeSources(const Sources: TArray<TContextSource>): string;
var Root: TJSONObject; Items: TJSONArray; Item: TJSONObject; Source: TContextSource;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('format', 'rag-context-v1');
    Items := TJSONArray.Create;
    Root.AddPair('sources', Items);
    for Source in Sources do
    begin
      Item := TJSONObject.Create;
      Items.AddElement(Item);
      Item.AddPair('label', Source.LabelId);
      Item.AddPair('chunkId', Source.Chunk.Id);
      Item.AddPair('documentId', Source.Chunk.DocumentId);
      Item.AddPair('source', Source.Chunk.Source);
      Item.AddPair('page', TJSONNumber.Create(Source.Chunk.PageNumber));
      Item.AddPair('start', TJSONNumber.Create(Source.Chunk.StartOffset));
      Item.AddPair('text', Source.Chunk.Text);
    end;
    Result := Root.ToJSON;
  finally Root.Free; end;
end;

procedure ValidateUnicode(const Value: string);
var I: Integer; C: Word;
begin
  I := 1;
  while I <= Length(Value) do
  begin
    C := Ord(Value[I]);
    if (C >= $D800) and (C <= $DBFF) then
    begin
      if (I = Length(Value)) or (Ord(Value[I + 1]) < $DC00) or
        (Ord(Value[I + 1]) > $DFFF) then raise EArgumentException.Create('Par Unicode incompleto');
      Inc(I);
    end
    else if (C >= $DC00) and (C <= $DFFF) then
      raise EArgumentException.Create('Par Unicode incompleto');
    Inc(I);
  end;
end;

function BuildContext(const Ranked: TArray<TSearchResult>; const Profile: string;
  MaxChars: Integer; MaxChunks: Integer): TPreparedContext;
var
  Candidate: TSearchResult;
  Selected, Trial: TArray<TContextSource>;
  Seen: TDictionary<string, Boolean>;
  Serialized: string;
  Count: Integer;
begin
  Result := Default(TPreparedContext);
  if (Profile <> 'operacional') and (Profile <> 'supervisor') then
    raise EArgumentException.Create('Perfil desconhecido');
  if (MaxChars < 128) or (MaxChars > 1000000) or (MaxChunks < 1) or
    (MaxChunks > 100) or (Length(Ranked) > 1000) then
    raise EArgumentException.Create('Limites de contexto inválidos');
  Seen := TDictionary<string, Boolean>.Create;
  try
    for Candidate in Ranked do
    begin
      if (Candidate.Chunk.Access <> 'operacional') and
        ((Candidate.Chunk.Access <> 'supervisor') or (Profile <> 'supervisor')) then
      begin Inc(Result.SkippedForbidden); Continue; end;
      if Candidate.Chunk.Id.IsEmpty or Candidate.Chunk.DocumentId.IsEmpty or
        Candidate.Chunk.Source.IsEmpty or Candidate.Chunk.Text.Trim.IsEmpty or
        (Candidate.Chunk.PageNumber < 0) or (Candidate.Chunk.StartOffset < 1) then
        raise EArgumentException.Create('Metadados de contexto inválidos');
      if Seen.ContainsKey(Candidate.Chunk.Id) then
        raise EArgumentException.Create('Trecho duplicado no contexto');
      Seen.Add(Candidate.Chunk.Id, True);
      ValidateUnicode(Candidate.Chunk.Id);
      ValidateUnicode(Candidate.Chunk.DocumentId);
      ValidateUnicode(Candidate.Chunk.Source);
      ValidateUnicode(Candidate.Chunk.Text);
      Count := Length(Selected);
      if Count >= MaxChunks then begin Inc(Result.SkippedBudget); Continue; end;
      Trial := Copy(Selected);
      SetLength(Trial, Count + 1);
      Trial[Count].LabelId := 'F' + IntToStr(Count + 1);
      Trial[Count].Chunk := Candidate.Chunk;
      Serialized := SerializeSources(Trial);
      if Length(Serialized) > MaxChars then
      begin Inc(Result.SkippedBudget); Continue; end;
      Selected := Trial;
    end;
    Result.Sources := Selected;
    Result.Serialized := SerializeSources(Selected);
  finally Seen.Free; end;
end;

end.
