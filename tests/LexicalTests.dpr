program LexicalTests;

{$APPTYPE CONSOLE}

uses System.SysUtils, System.Math, Rag.Types, Rag.Lexical;

procedure Check(Value: Boolean; const MessageText: string);
begin
  if not Value then raise Exception.Create('FALHOU: ' + MessageText);
  Writeln('OK: ', MessageText);
end;

function Chunk(const Id, Text, Access: string): TChunk;
begin
  Result := Default(TChunk);
  Result.Id := Id;
  Result.DocumentId := Id;
  Result.Source := 'own-fixture';
  Result.Text := Text;
  Result.Access := Access;
  Result.PageNumber := 3;
end;

var
  Chunks: TArray<TChunk>;
  Index, PublicIndex: TLexicalIndex;
  Results, Repeated, PublicResults: TArray<TSearchResult>;
  Invalid: Boolean;
  Expected: Double;
begin
  try
    Chunks := [Chunk('a', 'estoque estoque supervisor', 'operacional'),
      Chunk('b', 'estoque vendas vendas', 'operacional'),
      Chunk('restricted', 'estoque sigilo sigilo', 'supervisor')];
    Index := TLexicalIndex.Create(Chunks);
    PublicIndex := TLexicalIndex.Create([Chunks[0], Chunks[1]]);
    try
      Results := Index.Search('estoque', 'operacional', 10);
      Check(Length(Results) = 2, 'somente dois trechos permitidos');
      Check(Results[0].Chunk.Id = 'a', 'frequência influencia relevância');
      Expected := Ln(1 + 0.5 / 2.5) * 2 * 2.2 / (2 + 1.2);
      Check(Abs(Results[0].Score - Expected) < 1E-12, 'pontuação confere com cálculo independente');
      PublicResults := PublicIndex.Search('estoque', 'operacional', 10);
      Check(Abs(PublicResults[0].Score - Results[0].Score) < 1E-12, 'trecho restrito não altera estatísticas públicas');
      Repeated := Index.Search('ESTOQUE estoque', 'operacional', 10);
      Check(Abs(Repeated[0].Score - Results[0].Score) < 1E-12, 'caixa e repetição da consulta normalizadas');
      Check(Results[0].Chunk.PageNumber = 3, 'página original preservada');
      Check(Length(Index.Search('sigilo', 'operacional', 10)) = 0, 'termo restrito não recuperado');
      Check(Length(Index.Search('sigilo', 'supervisor', 10)) = 1, 'supervisor recupera trecho restrito');
      Check(Length(Index.Search('inexistente', 'operacional', 10)) = 0, 'termo desconhecido retorna vazio');
      Check(Length(Index.Search('...', 'operacional', 10)) = 0, 'consulta sem termos retorna vazio');
      Check(Length(Index.Search('estoque', 'operacional', 1)) = 1, 'TopK limita resultado');
      Invalid := False;
      try Index.Search('estoque', 'anônimo', 1); except on EArgumentException do Invalid := True; end;
      Check(Invalid, 'perfil desconhecido rejeitado');
      Invalid := False;
      try Index.Search('estoque', 'operacional', 0); except on EArgumentException do Invalid := True; end;
      Check(Invalid, 'TopK inválido rejeitado');
      Check(Length(TokenizeLexical('não 2 não')) = 3, 'negações e números preservados no índice');
    finally
      PublicIndex.Free;
      Index.Free;
    end;
    Index := TLexicalIndex.Create(nil);
    try
      Check(Length(Index.Search('estoque', 'operacional', 3)) = 0, 'índice vazio retorna vazio');
    finally Index.Free; end;
  except
    on E: Exception do begin Writeln(E.Message); ExitCode := 1; end;
  end;
end.
