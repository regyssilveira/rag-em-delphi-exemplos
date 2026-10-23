unit Rag.EvidenceContext;

interface

uses System.SysUtils, Rag.Types, Rag.Context;

function BuildEvidenceContext(const Ranked: TArray<TSearchResult>;
  const Documents: TArray<TDocument>; const Profile: string;
  MaxChars: Integer = 6000): TPreparedContext;

implementation

uses System.StrUtils, System.Generics.Collections, System.JSON;

function BuildEvidenceContext(const Ranked: TArray<TSearchResult>;
  const Documents: TArray<TDocument>; const Profile: string;
  MaxChars: Integer): TPreparedContext;
var Candidate, Expanded: TSearchResult; Document: TDocument;
  Items: TList<TSearchResult>; Seen: TDictionary<string, Boolean>;
  Found: Boolean; LineStart, LineEnd, First, Last, A, B: Integer;
  SkippedLong, SkippedForbidden: Integer; Line: string;

  procedure AddHeadings;
  var Root: TJSONObject; Values: TJSONArray; I, P, E: Integer;
    Title, Section, Heading: string; Source: TContextSource;
    Current: TDocument;
  begin
    Root := TJSONObject.ParseJSONValue(Result.Serialized) as TJSONObject;
    try
      Values := Root.GetValue('sources') as TJSONArray;
      for I := 0 to High(Result.Sources) do
      begin
        Source := Result.Sources[I]; Title := ''; Section := '';
        for Current in Documents do
          if Current.Id = Source.Chunk.DocumentId then Break;
        P := 1;
        while P < Source.Chunk.StartOffset do
        begin
          E := PosEx(#10, Current.Text, P);
          if E = 0 then E := Length(Current.Text) + 1;
          Heading := Copy(Current.Text, P, E - P).Trim;
          if Heading.StartsWith('# ') then
          begin Title := Heading.Substring(2).Trim; Section := ''; end
          else if Heading.StartsWith('##') then
          begin
            while Heading.StartsWith('#') do Delete(Heading, 1, 1);
            Section := Heading.Trim;
          end;
          P := E + 1;
        end;
        (Values.Items[I] as TJSONObject).AddPair('documentTitle', Title);
        (Values.Items[I] as TJSONObject).AddPair('sectionTitle', Section);
      end;
      while (Length(Root.ToJSON) > MaxChars) and (Values.Count > 0) do
      begin
        Values.Remove(Values.Count - 1).Free;
        SetLength(Result.Sources, Length(Result.Sources) - 1);
        Inc(Result.SkippedBudget);
      end;
      Result.Serialized := Root.ToJSON;
    finally Root.Free; end;
  end;

  procedure AddParagraph;
  var Id: string;
  begin
    if First = 0 then Exit;
    if (First <= Candidate.Chunk.StartOffset + Length(Candidate.Chunk.Text) - 1)
      and (Last >= Candidate.Chunk.StartOffset) then
    begin
      Id := Document.Id + ':paragraph:' + IntToStr(First);
      if not Seen.ContainsKey(Id) then
      begin
        Seen.Add(Id, True);
        if Last - First + 1 > 1000 then Inc(SkippedLong)
        else if Last - First + 1 >= 10 then
        begin
          Expanded := Candidate;
          Expanded.Chunk.Id := Id;
          Expanded.Chunk.StartOffset := First;
          Expanded.Chunk.Text := Copy(Document.Text, First, Last - First + 1);
          if Items.Count >= 1000 then
            raise EArgumentException.Create('Quantidade de parágrafos excedida');
          Items.Add(Expanded);
        end;
      end;
    end;
    First := 0;
  end;

begin
  if (Profile <> 'operacional') and (Profile <> 'supervisor') then
    raise EArgumentException.Create('Perfil desconhecido');
  if (Length(Ranked) > 1000) or (Length(Documents) > 10000) then
    raise EArgumentException.Create('Quantidade fora dos limites');
  Items := TList<TSearchResult>.Create;
  Seen := TDictionary<string, Boolean>.Create;
  SkippedLong := 0;
  SkippedForbidden := 0;
  try
    for Candidate in Ranked do
    begin
      if (Candidate.Chunk.Access <> 'operacional') and
        not ((Profile = 'supervisor') and (Candidate.Chunk.Access = 'supervisor')) then
      begin Inc(SkippedForbidden); Continue; end;
      Found := False;
      for Document in Documents do
        if Document.Id = Candidate.Chunk.DocumentId then
        begin Found := True; Break; end;
      if not Found then raise EArgumentException.Create('Documento do trecho ausente');
      if (Document.Access <> Candidate.Chunk.Access) or
        (Document.Source <> Candidate.Chunk.Source) or
        (Document.PageNumber <> Candidate.Chunk.PageNumber) or
        (Candidate.Chunk.StartOffset < 1) or Candidate.Chunk.Text.IsEmpty or
        (Copy(Document.Text, Candidate.Chunk.StartOffset,
          Length(Candidate.Chunk.Text)) <> Candidate.Chunk.Text) then
        raise EArgumentException.Create('Trecho incompatível com documento');
      First := 0; Last := 0; LineStart := 1;
      while LineStart <= Length(Document.Text) do
      begin
        LineEnd := PosEx(#10, Document.Text, LineStart);
        if LineEnd = 0 then LineEnd := Length(Document.Text) + 1;
        A := LineStart; B := LineEnd - 1;
        while (A <= B) and CharInSet(Document.Text[A], [' ', #9, #13]) do Inc(A);
        while (B >= A) and CharInSet(Document.Text[B], [' ', #9, #13]) do Dec(B);
        Line := Copy(Document.Text, A, B - A + 1);
        if Line.IsEmpty or Line.StartsWith('#') then AddParagraph
        else
        begin
          if First = 0 then First := A;
          Last := B;
        end;
        LineStart := LineEnd + 1;
      end;
      AddParagraph;
    end;
    Result := BuildContext(Items.ToArray, Profile, MaxChars, 12);
    AddHeadings;
    Inc(Result.SkippedBudget, SkippedLong);
    Inc(Result.SkippedForbidden, SkippedForbidden);
  finally Seen.Free; Items.Free; end;
end;

end.
