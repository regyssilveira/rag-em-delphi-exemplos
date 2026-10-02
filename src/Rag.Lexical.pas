unit Rag.Lexical;

interface

uses System.SysUtils, System.Character, System.Math,
  System.Generics.Collections, Rag.Types;

type
  TLexicalIndex = class
  private
    FChunks: TArray<TChunk>;
    FLengths: TArray<Integer>;
    FFrequencies: TObjectList<TDictionary<string, Integer>>;
    FPostings: TObjectDictionary<string, TList<Integer>>;
  public
    constructor Create(const Chunks: TArray<TChunk>);
    destructor Destroy; override;
    function Search(const Query, Profile: string; TopK: Integer;
      K1: Double = 1.2; B: Double = 0.75): TArray<TSearchResult>;
  end;

function TokenizeLexical(const Value: string): TArray<string>;

implementation

function TokenizeLexical(const Value: string): TArray<string>;
var
  Character: Char;
  WordValue: string;
  Tokens: TList<string>;
begin
  Tokens := TList<string>.Create;
  try
    WordValue := '';
    for Character in LowerCase(Value) + ' ' do
      if Character.IsLetterOrDigit then
        WordValue := WordValue + Character
      else if WordValue <> '' then
      begin
        Tokens.Add(WordValue);
        WordValue := '';
      end;
    Result := Tokens.ToArray;
  finally
    Tokens.Free;
  end;
end;

constructor TLexicalIndex.Create(const Chunks: TArray<TChunk>);
var
  I, Frequency: Integer;
  Term: string;
  Tokens: TArray<string>;
  Frequencies: TDictionary<string, Integer>;
  Posting: TList<Integer>;
begin
  inherited Create;
  FChunks := Copy(Chunks);
  SetLength(FLengths, Length(Chunks));
  FFrequencies := TObjectList<TDictionary<string, Integer>>.Create(True);
  FPostings := TObjectDictionary<string, TList<Integer>>.Create([doOwnsValues]);
  for I := 0 to High(Chunks) do
  begin
    Frequencies := TDictionary<string, Integer>.Create;
    FFrequencies.Add(Frequencies);
    Tokens := TokenizeLexical(Chunks[I].Text);
    FLengths[I] := Length(Tokens);
    for Term in Tokens do
    begin
      if Frequencies.TryGetValue(Term, Frequency) then
        Frequencies[Term] := Frequency + 1
      else
        Frequencies.Add(Term, 1);
    end;
    for Term in Frequencies.Keys do
    begin
      if not FPostings.TryGetValue(Term, Posting) then
      begin
        Posting := TList<Integer>.Create;
        FPostings.Add(Term, Posting);
      end;
      Posting.Add(I);
    end;
  end;
end;

destructor TLexicalIndex.Destroy;
begin
  FPostings.Free;
  FFrequencies.Free;
  inherited;
end;

function TLexicalIndex.Search(const Query, Profile: string; TopK: Integer;
  K1, B: Double): TArray<TSearchResult>;
var
  Allowed: TArray<Boolean>;
  Scores: TArray<Double>;
  QueryTerms: TDictionary<string, Boolean>;
  Posting: TList<Integer>;
  Items: TList<TSearchResult>;
  Item, Temporary: TSearchResult;
  Term: string;
  I, J, Count, DocumentFrequency, Frequency: Integer;
  TotalLength: Int64;
  AverageLength, InverseFrequency, Denominator: Double;
begin
  if (Profile <> 'operacional') and (Profile <> 'supervisor') then
    raise EArgumentException.Create('Perfil desconhecido');
  if (TopK <= 0) or (TopK > 1000) or IsNan(K1) or IsInfinite(K1) or
    (K1 <= 0) or IsNan(B) or IsInfinite(B) or (B < 0) or (B > 1) then
    raise EArgumentException.Create('Parâmetros de busca inválidos');
  SetLength(Allowed, Length(FChunks));
  SetLength(Scores, Length(FChunks));
  Count := 0;
  TotalLength := 0;
  for I := 0 to High(FChunks) do
  begin
    Allowed[I] := (FLengths[I] > 0) and ((FChunks[I].Access = 'operacional') or
      ((Profile = 'supervisor') and (FChunks[I].Access = 'supervisor')));
    if Allowed[I] then
    begin
      Inc(Count);
      Inc(TotalLength, FLengths[I]);
    end;
  end;
  if Count = 0 then Exit(nil);
  AverageLength := TotalLength / Count;
  QueryTerms := TDictionary<string, Boolean>.Create;
  Items := TList<TSearchResult>.Create;
  try
    for Term in TokenizeLexical(Query) do
      QueryTerms.AddOrSetValue(Term, True);
    for Term in QueryTerms.Keys do
    begin
      if not FPostings.TryGetValue(Term, Posting) then Continue;
      DocumentFrequency := 0;
      for I in Posting do
        if Allowed[I] then Inc(DocumentFrequency);
      if DocumentFrequency = 0 then Continue;
      InverseFrequency := Ln(1 + (Count - DocumentFrequency + 0.5) /
        (DocumentFrequency + 0.5));
      for I in Posting do
        if Allowed[I] then
        begin
          Frequency := FFrequencies[I][Term];
          Denominator := Frequency + K1 * (1 - B + B * FLengths[I] / AverageLength);
          Scores[I] := Scores[I] + InverseFrequency * Frequency * (K1 + 1) / Denominator;
        end;
    end;
    for I := 0 to High(FChunks) do
      if Scores[I] > 0 then
      begin
        Item.Chunk := FChunks[I];
        Item.Score := Scores[I];
        Items.Add(Item);
      end;
    for I := 1 to Items.Count - 1 do
    begin
      J := I;
      while (J > 0) and (Items[J].Score > Items[J - 1].Score) do
      begin
        Temporary := Items[J - 1];
        Items[J - 1] := Items[J];
        Items[J] := Temporary;
        Dec(J);
      end;
    end;
    while Items.Count > TopK do Items.Delete(Items.Count - 1);
    Result := Items.ToArray;
  finally
    Items.Free;
    QueryTerms.Free;
  end;
end;

end.
