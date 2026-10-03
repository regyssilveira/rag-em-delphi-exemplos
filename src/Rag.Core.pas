unit Rag.Core;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils,
  System.Generics.Collections, System.Math, System.Character, Rag.Types;

function LoadDocument(const FileName, Access: string): TDocument;
function SplitDocument(const Document: TDocument;
  MaxChars, Overlap: Integer): TArray<TChunk>;
function SearchLexical(const Chunks: TArray<TChunk>;
  const Query, Profile: string; TopK: Integer): TArray<TSearchResult>;

implementation

uses Rag.Ingestion;

function LoadDocument(const FileName, Access: string): TDocument;
begin
  Result := Default(TDocument);
  if not TFile.Exists(FileName) then
    raise EFileNotFoundException.Create('Documento não encontrado: ' + FileName);
  Result.Id := TPath.GetFileName(FileName);
  Result.Source := TPath.GetFullPath(FileName);
  if SameText(TPath.GetExtension(FileName), '.docx') then
    Result.Text := ReadDocxText(FileName)
  else if SameText(TPath.GetExtension(FileName), '.txt') or
    SameText(TPath.GetExtension(FileName), '.md') then
    Result.Text := ReadUtf8Text(FileName)
  else
    raise EReadError.Create('Formato ainda não suportado: ' + TPath.GetExtension(FileName));
  Result.Access := Access;
  Result.PageNumber := 0;
end;

function SplitDocument(const Document: TDocument;
  MaxChars, Overlap: Integer): TArray<TChunk>;
var
  ChunkList: TList<TChunk>;
  Chunk: TChunk;
  StartPosition, LastPosition, Boundary, TextLength, PreviousStart: Integer;
begin
  if (MaxChars < 32) or (Overlap < 0) or (Overlap >= MaxChars) then
    raise EArgumentException.Create('Tamanho ou sobreposição inválidos');
  ChunkList := TList<TChunk>.Create;
  try
    StartPosition := 1;
    TextLength := Length(Document.Text);
    while StartPosition <= TextLength do
    begin
      LastPosition := Min(StartPosition + MaxChars - 1, TextLength);
      // Evita separar um par UTF-16 entre dois trechos.
      if (LastPosition < TextLength) and
        (Ord(Document.Text[LastPosition]) >= $D800) and
        (Ord(Document.Text[LastPosition]) <= $DBFF) then
        Dec(LastPosition);
      if LastPosition < TextLength then
      begin
        Boundary := LastPosition;
        while (Boundary > StartPosition + Overlap) and
          not CharInSet(Document.Text[Boundary], [#10, ' ', #9]) do
          Dec(Boundary);
        if Boundary > StartPosition + Overlap then
          LastPosition := Boundary;
      end;
      Chunk.Id := Document.Id + ':' + IntToStr(ChunkList.Count + 1);
      Chunk.DocumentId := Document.Id;
      Chunk.Source := Document.Source;
      Chunk.Access := Document.Access;
      Chunk.PageNumber := Document.PageNumber;
      Chunk.StartOffset := StartPosition;
      Chunk.Text := Copy(Document.Text, StartPosition,
        LastPosition - StartPosition + 1);
      ChunkList.Add(Chunk);
      if LastPosition = TextLength then
        Break;
      PreviousStart := StartPosition;
      StartPosition := Max(PreviousStart + 1, LastPosition - Overlap + 1);
      if (StartPosition > 1) and
        (Ord(Document.Text[StartPosition]) >= $DC00) and
        (Ord(Document.Text[StartPosition]) <= $DFFF) then
      begin
        if StartPosition - 1 > PreviousStart then
          Dec(StartPosition)
        else
          Inc(StartPosition);
      end;
    end;
    Result := ChunkList.ToArray;
  finally
    ChunkList.Free;
  end;
end;

function Terms(const Value: string): TArray<string>;
var
  Character: Char;
  Normalized, WordValue: string;
  TermList: TList<string>;
begin
  Normalized := LowerCase(Value);
  TermList := TList<string>.Create;
  try
    WordValue := '';
    for Character in Normalized + ' ' do
      if Character.IsLetterOrDigit then
        WordValue := WordValue + Character
      else
      begin
        if (Length(WordValue) >= 3) and (WordValue <> 'quem') and
          (WordValue <> 'qual') and (WordValue <> 'para') and
          (WordValue <> 'uma') and (WordValue <> 'com') and
          (WordValue <> 'pode') and (WordValue <> 'que') and
          not TermList.Contains(WordValue) then
          TermList.Add(WordValue);
        WordValue := '';
      end;
    Result := TermList.ToArray;
  finally
    TermList.Free;
  end;
end;

function SearchLexical(const Chunks: TArray<TChunk>;
  const Query, Profile: string; TopK: Integer): TArray<TSearchResult>;
var
  QueryTerms, ChunkTerms: TArray<string>;
  TermValue, ChunkTerm: string;
  Chunk: TChunk;
  Item, Temporary: TSearchResult;
  Results: TList<TSearchResult>;
  Hits, I, J: Integer;
begin
  if TopK <= 0 then
    raise EArgumentException.Create('TopK deve ser positivo');
  QueryTerms := Terms(Query);
  Results := TList<TSearchResult>.Create;
  try
    for Chunk in Chunks do
    begin
      // Demonstração de autorização; identidade fornecida pelo chamador.
      if (Chunk.Access <> 'operacional') and
        not ((Profile = 'supervisor') and (Chunk.Access = 'supervisor')) then
        Continue;
      ChunkTerms := Terms(Chunk.Text);
      Hits := 0;
      for TermValue in QueryTerms do
        for ChunkTerm in ChunkTerms do
          if TermValue = ChunkTerm then
          begin
            Inc(Hits);
            Break;
          end;
      if Hits = 0 then
        Continue;
      Item.Chunk := Chunk;
      Item.Score := Hits / Length(QueryTerms);
      Results.Add(Item);
    end;
    // Ordenação simples para a base pequena; empates preservam a entrada.
    for I := 1 to Results.Count - 1 do
    begin
      J := I;
      while (J > 0) and (Results[J].Score > Results[J - 1].Score) do
      begin
        Temporary := Results[J - 1];
        Results[J - 1] := Results[J];
        Results[J] := Temporary;
        Dec(J);
      end;
    end;
    while Results.Count > TopK do
      Results.Delete(Results.Count - 1);
    Result := Results.ToArray;
  finally
    Results.Free;
  end;
end;

end.
