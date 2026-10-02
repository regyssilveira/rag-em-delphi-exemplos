program VectorTests;

{$APPTYPE CONSOLE}

uses System.SysUtils, System.Math, Rag.Types, Rag.Vectors;

procedure Check(Value: Boolean; const MessageText: string);
begin
  if not Value then raise Exception.Create('FALHOU: ' + MessageText);
  Writeln('OK: ', MessageText);
end;

procedure RejectVector(const Vector: TEmbedding);
var
  Rejected: Boolean;
begin
  Rejected := False;
  try NormalizeEmbedding(Vector); except on EArgumentException do Rejected := True; end;
  Check(Rejected, 'vetor inválido rejeitado');
end;

var
  Items: TArray<TEmbeddedChunk>;
  Index: TVectorIndex;
  Results: TArray<TSearchResult>;
  Invalid: Boolean;
  Normalized: TEmbedding;
begin
  try
    Check(Abs(CosineSimilarity([1, 0], [2, 0]) - 1) < 1E-12, 'direções iguais');
    Check(Abs(CosineSimilarity([1, 0], [0, 1])) < 1E-12, 'direções ortogonais');
    Check(Abs(CosineSimilarity([1, 0], [-1, 0]) + 1) < 1E-12, 'direções opostas');
    Check(Abs(CosineSimilarity([3, 4], [1, 0]) - 0.6) < 1E-12, 'exemplo 3-4-5');
    Check(Abs(CosineSimilarity([1E300, 1E300], [1, 1]) - 1) < 1E-12, 'normalização evita overflow');
    Check(Abs(CosineSimilarity([1E-300, 1E-300], [1, 1]) - 1) < 1E-12, 'normalização evita underflow');
    RejectVector(nil); RejectVector([0, 0]); RejectVector([NaN, 1]); RejectVector([Infinity, 1]);
    Invalid := False;
    try CosineSimilarity([1, 0], [1]); except on EArgumentException do Invalid := True; end;
    Check(Invalid, 'dimensões distintas rejeitadas');
    SetLength(Items, 3);
    Items[0].Chunk.Id := 'public-a'; Items[0].Chunk.Access := 'operacional'; Items[0].Vector := [1, 0];
    Items[1].Chunk.Id := 'public-b'; Items[1].Chunk.Access := 'operacional'; Items[1].Vector := [0.6, 0.8];
    Items[2].Chunk.Id := 'restricted'; Items[2].Chunk.Access := 'supervisor'; Items[2].Vector := [1, 0];
    Items[0].Chunk.PageNumber := 9;
    Index := TVectorIndex.Create(Items, 'synthetic-test-v1');
    try
      Items[0].Vector[0] := 0;
      Results := Index.Search([1, 0], 'synthetic-test-v1', 'operacional', 10);
      Check(Length(Results) = 2, 'filtro exclui vetor restrito');
      Check(Results[0].Chunk.Id = 'public-a', 'ordenação por cosseno e cópia independente');
      Check(Results[0].Chunk.PageNumber = 9, 'página preservada');
      Check(Length(Index.Search([1, 0], 'synthetic-test-v1', 'supervisor', 10)) = 3, 'supervisor recupera permitido');
      Check(Length(Index.Search([1, 0], 'synthetic-test-v1', 'operacional', 10, 0.9)) = 1, 'limiar explícito');
      Invalid := False;
      try Index.Search([1, 0], 'other-model', 'operacional', 1); except on EArgumentException do Invalid := True; end;
      Check(Invalid, 'identidade de modelo diferente rejeitada');
      Invalid := False;
      try Index.Search([1], 'synthetic-test-v1', 'operacional', 1); except on EArgumentException do Invalid := True; end;
      Check(Invalid, 'dimensão de consulta inválida rejeitada');
      Invalid := False;
      try Index.Search([1, 0], 'synthetic-test-v1', 'anônimo', 1); except on EArgumentException do Invalid := True; end;
      Check(Invalid, 'perfil desconhecido rejeitado');
    finally Index.Free; end;
    Index := TVectorIndex.Create(nil, 'synthetic-test-v1');
    try Check(Length(Index.Search([1, 0], 'synthetic-test-v1', 'operacional', 1)) = 0, 'índice vazio'); finally Index.Free; end;
  except on E: Exception do begin Writeln(E.Message); ExitCode := 1; end; end;
end.
