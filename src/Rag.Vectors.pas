unit Rag.Vectors;

interface

uses System.SysUtils, System.Math, System.Generics.Collections, Rag.Types;

type
  TEmbedding = TArray<Double>;
  TEmbeddedChunk = record
    Chunk: TChunk;
    Vector: TEmbedding;
  end;
  TVectorIndex = class
  private
    FItems: TArray<TEmbeddedChunk>;
    FModelIdentity: string;
    FDimension: Integer;
  public
    constructor Create(const Items: TArray<TEmbeddedChunk>; const ModelIdentity: string);
    function Search(const Query: TEmbedding; const ModelIdentity, Profile: string;
      TopK: Integer; MinimumScore: Double = 0): TArray<TSearchResult>;
    property Dimension: Integer read FDimension;
    property ModelIdentity: string read FModelIdentity;
  end;

function NormalizeEmbedding(const Vector: TEmbedding): TEmbedding;
function CosineSimilarity(const Left, Right: TEmbedding): Double;

implementation

function NormalizeEmbedding(const Vector: TEmbedding): TEmbedding;
var
  I: Integer;
  Scale, Sum, Norm, Value: Double;
begin
  if (Length(Vector) = 0) or (Length(Vector) > 65536) then
    raise EArgumentException.Create('Dimensão inválida');
  Scale := 0;
  for Value in Vector do
  begin
    if IsNan(Value) or IsInfinite(Value) then
      raise EArgumentException.Create('Componente não finito');
    Scale := Max(Scale, Abs(Value));
  end;
  if Scale = 0 then raise EArgumentException.Create('Vetor nulo');
  Sum := 0;
  for Value in Vector do Sum := Sum + Sqr(Value / Scale);
  Norm := Sqrt(Sum);
  SetLength(Result, Length(Vector));
  for I := 0 to High(Vector) do Result[I] := (Vector[I] / Scale) / Norm;
end;

function CosineSimilarity(const Left, Right: TEmbedding): Double;
var
  A, B: TEmbedding;
  I: Integer;
begin
  if Length(Left) <> Length(Right) then
    raise EArgumentException.Create('Dimensões incompatíveis');
  A := NormalizeEmbedding(Left);
  B := NormalizeEmbedding(Right);
  Result := 0;
  for I := 0 to High(A) do Result := Result + A[I] * B[I];
  Result := EnsureRange(Result, -1.0, 1.0);
end;

constructor TVectorIndex.Create(const Items: TArray<TEmbeddedChunk>; const ModelIdentity: string);
var
  I: Integer;
begin
  inherited Create;
  if ModelIdentity.Trim.IsEmpty then raise EArgumentException.Create('Identidade do modelo ausente');
  FModelIdentity := ModelIdentity;
  SetLength(FItems, Length(Items));
  if Length(Items) > 0 then FDimension := Length(Items[0].Vector);
  for I := 0 to High(Items) do
  begin
    if Length(Items[I].Vector) <> FDimension then
      raise EArgumentException.Create('Dimensões incompatíveis na base');
    FItems[I].Chunk := Items[I].Chunk;
    FItems[I].Vector := NormalizeEmbedding(Items[I].Vector);
  end;
end;

function TVectorIndex.Search(const Query: TEmbedding; const ModelIdentity, Profile: string;
  TopK: Integer; MinimumScore: Double): TArray<TSearchResult>;
var
  Normalized: TEmbedding;
  Results: TList<TSearchResult>;
  Item, Temporary: TSearchResult;
  I, J, Component: Integer;
begin
  if ModelIdentity <> FModelIdentity then raise EArgumentException.Create('Modelo incompatível');
  if (Profile <> 'operacional') and (Profile <> 'supervisor') then
    raise EArgumentException.Create('Perfil desconhecido');
  if (TopK <= 0) or (TopK > 1000) or IsNan(MinimumScore) or IsInfinite(MinimumScore) or
     (MinimumScore < -1) or (MinimumScore > 1) then
    raise EArgumentException.Create('Parâmetros de busca inválidos');
  Normalized := NormalizeEmbedding(Query);
  if (Length(FItems) > 0) and (Length(Query) <> FDimension) then
    raise EArgumentException.Create('Dimensão da consulta incompatível');
  Results := TList<TSearchResult>.Create;
  try
    for I := 0 to High(FItems) do
    begin
      if (FItems[I].Chunk.Access <> 'operacional') and
        not ((Profile = 'supervisor') and (FItems[I].Chunk.Access = 'supervisor')) then Continue;
      Item.Score := 0;
      for Component := 0 to High(Normalized) do
        Item.Score := Item.Score + Normalized[Component] * FItems[I].Vector[Component];
      Item.Score := EnsureRange(Item.Score, -1.0, 1.0);
      if Item.Score < MinimumScore then Continue;
      Item.Chunk := FItems[I].Chunk;
      Results.Add(Item);
    end;
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
    while Results.Count > TopK do Results.Delete(Results.Count - 1);
    Result := Results.ToArray;
  finally Results.Free; end;
end;

end.
