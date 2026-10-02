unit Rag.Hybrid;

interface

uses System.SysUtils, System.Generics.Collections, Rag.Types;

function FuseRankings(const Lexical, Vector: TArray<TSearchResult>;
  const Profile: string; TopK: Integer; RankConstant: Integer = 60): TArray<TSearchResult>;

implementation

function SameChunk(const Left, Right: TChunk): Boolean;
begin
  Result := (Left.Id = Right.Id) and (Left.DocumentId = Right.DocumentId) and
    (Left.Text = Right.Text) and (Left.Source = Right.Source) and
    (Left.Access = Right.Access) and (Left.PageNumber = Right.PageNumber) and
    (Left.StartOffset = Right.StartOffset);
end;

function FuseRankings(const Lexical, Vector: TArray<TSearchResult>;
  const Profile: string; TopK, RankConstant: Integer): TArray<TSearchResult>;
var
  Entries: TList<TSearchResult>;
  Positions: TDictionary<string, Integer>;
  I, J: Integer;
  Temporary: TSearchResult;

  procedure AddRanking(const Ranking: TArray<TSearchResult>);
  var
    Seen: TDictionary<string, Boolean>;
    Entry, Current: TSearchResult;
    Rank, Position: Integer;
  begin
    Seen := TDictionary<string, Boolean>.Create;
    try
      Rank := 0;
      for Entry in Ranking do
      begin
        if (Entry.Chunk.Access <> 'operacional') and
          not ((Profile = 'supervisor') and (Entry.Chunk.Access = 'supervisor')) then Continue;
        if Entry.Chunk.Id.Trim.IsEmpty or Seen.ContainsKey(Entry.Chunk.Id) then
          raise EArgumentException.Create('Identidade ausente ou repetida no ranking');
        Seen.Add(Entry.Chunk.Id, True);
        Inc(Rank);
        if Positions.TryGetValue(Entry.Chunk.Id, Position) then
        begin
          Current := Entries[Position];
          if not SameChunk(Current.Chunk, Entry.Chunk) then
            raise EArgumentException.Create('Rankings de versões incompatíveis');
          Current.Score := Current.Score + 1.0 / (RankConstant + Rank);
          Entries[Position] := Current;
        end
        else
        begin
          Positions.Add(Entry.Chunk.Id, Entries.Count);
          Current.Chunk := Entry.Chunk;
          Current.Score := 1.0 / (RankConstant + Rank);
          Entries.Add(Current);
        end;
      end;
    finally Seen.Free; end;
  end;

begin
  if (Profile <> 'operacional') and (Profile <> 'supervisor') then
    raise EArgumentException.Create('Perfil desconhecido');
  if (TopK <= 0) or (TopK > 1000) or (RankConstant < 1) or (RankConstant > 1000000) or
    (Length(Lexical) > 1000) or (Length(Vector) > 1000) then
    raise EArgumentException.Create('Parâmetros de fusão inválidos');
  Entries := TList<TSearchResult>.Create;
  Positions := TDictionary<string, Integer>.Create;
  try
    AddRanking(Lexical);
    AddRanking(Vector);
    for I := 1 to Entries.Count - 1 do
    begin
      J := I;
      while (J > 0) and (Entries[J].Score > Entries[J - 1].Score) do
      begin
        Temporary := Entries[J - 1];
        Entries[J - 1] := Entries[J];
        Entries[J] := Temporary;
        Dec(J);
      end;
    end;
    while Entries.Count > TopK do Entries.Delete(Entries.Count - 1);
    Result := Entries.ToArray;
  finally
    Positions.Free;
    Entries.Free;
  end;
end;

end.
