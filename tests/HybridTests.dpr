program HybridTests;

{$APPTYPE CONSOLE}

uses System.SysUtils, System.Math, Rag.Types, Rag.Hybrid;

procedure Check(Value: Boolean; const MessageText: string);
begin
  if not Value then raise Exception.Create('FALHOU: ' + MessageText);
  Writeln('OK: ', MessageText);
end;

function Entry(const Id, Access: string; Score: Double): TSearchResult;
begin
  Result := Default(TSearchResult);
  Result.Chunk.Id := Id;
  Result.Chunk.DocumentId := 'own-fixture';
  Result.Chunk.Source := 'own-fixture';
  Result.Chunk.Text := Id;
  Result.Chunk.Access := Access;
  Result.Chunk.PageNumber := 4;
  Result.Score := Score;
end;

var
  A, B, C, Restricted, Modified: TSearchResult;
  Results, Rescaled, Filtered: TArray<TSearchResult>;
  Invalid: Boolean;
begin
  try
    A := Entry('a', 'operacional', 100); B := Entry('b', 'operacional', 90);
    C := Entry('c', 'operacional', 0.6); Restricted := Entry('r', 'supervisor', 1000);
    Results := FuseRankings([A, B], [B, C], 'operacional', 10);
    Check((Length(Results) = 3) and (Results[0].Chunk.Id = 'b'), 'concordância dos rankings promove candidato');
    Check(Abs(Results[0].Score - (1.0 / 62 + 1.0 / 61)) < 1E-12, 'pontuação baseada em posições');
    A.Score := 1E-10; B.Score := 1E-20; C.Score := 1E20;
    Rescaled := FuseRankings([A, B], [B, C], 'operacional', 10);
    Check(Abs(Results[0].Score - Rescaled[0].Score) < 1E-12, 'escalas originais não alteram fusão');
    Filtered := FuseRankings([Restricted, A, B], [B, C], 'operacional', 10);
    Check((Length(Filtered) = 3) and (Abs(Filtered[0].Score - Results[0].Score) < 1E-12), 'restrito não desloca posições permitidas');
    Check(Results[0].Chunk.PageNumber = 4, 'metadados preservados');
    Check(Length(FuseRankings([A, B], nil, 'operacional', 1)) = 1, 'ranking único e limite');
    Check(Length(FuseRankings(nil, nil, 'operacional', 3)) = 0, 'rankings vazios');
    Results := FuseRankings([A, B], [B, A], 'operacional', 10);
    Check(Results[0].Chunk.Id = 'a', 'empate preserva primeira ordem de entrada');
    Invalid := False;
    try FuseRankings([A, A], nil, 'operacional', 3); except on EArgumentException do Invalid := True; end;
    Check(Invalid, 'duplicata no mesmo ranking rejeitada');
    Modified := A; Modified.Chunk.Text := 'outro conteúdo';
    Invalid := False;
    try FuseRankings([A], [Modified], 'operacional', 3); except on EArgumentException do Invalid := True; end;
    Check(Invalid, 'versões divergentes rejeitadas');
    Invalid := False;
    try FuseRankings([A], nil, 'anônimo', 3); except on EArgumentException do Invalid := True; end;
    Check(Invalid, 'perfil desconhecido rejeitado');
    Invalid := False;
    try FuseRankings([A], nil, 'operacional', 0); except on EArgumentException do Invalid := True; end;
    Check(Invalid, 'limite inválido rejeitado');
  except on E: Exception do begin Writeln(E.Message); ExitCode := 1; end; end;
end.
