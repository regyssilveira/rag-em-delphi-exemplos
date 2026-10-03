program FoundationTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.IOUtils, Rag.Types, Rag.Core;

procedure Check(Condition: Boolean; const MessageText:
string);
begin
  if not Condition then
    raise Exception.Create('FALHOU: ' + MessageText);
  Writeln('OK: ', MessageText);
end;

var
  Document: TDocument;
  Chunks: TArray<TChunk>;
  Results: TArray<TSearchResult>;
  I, NextOffset: Integer;
  InvalidRejected: Boolean;
begin
  try
    if ParamCount <> 1 then
      raise Exception.Create(
      'Informe a pasta data/corpus' );
    Document := LoadDocument(TPath.Combine(ParamStr(1),
    'recebimento.md' ), 'operacional' );
    Check(Pos( 'divergência' , Document.Text) > 0,
    'leitura UTF-8 preserva acentos' );
    Chunks := SplitDocument(Document, 380, 60);
    Check(Length(Chunks) > 1,
    'documento dividido em vários trechos' );
    NextOffset := 1;
    for I := 0 to High(Chunks) do
    begin
      Check(Length(Chunks[I].Text) <= 380,
      'limite do trecho ' + IntToStr(I));
      Check(Chunks[I].StartOffset <= NextOffset,
      'sem lacuna no trecho ' + IntToStr(I));
      Check(Chunks[I].Text = Copy(Document.Text,
      Chunks[I].StartOffset,
        Length(Chunks[I].Text)),
        'origem rastreável do trecho ' + IntToStr(I));
      NextOffset := Chunks[I].StartOffset +
      Length(Chunks[I].Text);
    end;
    Check(NextOffset = Length(Document.Text) + 1,
    'cobertura até o fim do documento' );
    Results := SearchLexical(Chunks,
    'recebimento divergência supervisor' , 'operacional'
    , 3);
    Check(Length(Results) > 0,
    'busca encontra evidências' );
    Check(Results[0].Chunk.DocumentId = 'recebimento.md'
    , 'resultado mantém fonte' );
    Results := SearchLexical(Chunks, 'comissão vendedor'
    , 'operacional' , 3);
    Check(Length(Results) = 0, ( 'consulta sem termos '
    + 'conhecidos não cria evidência' ) );
    Document := LoadDocument(TPath.Combine(ParamStr(1),
    'estoque.md' ), 'supervisor' );
    Chunks := SplitDocument(Document, 380, 60);
    Results := SearchLexical(Chunks, 'ajuste estoque' ,
    'operacional' , 3);
    Check(Length(Results) = 0, (
    'perfil operacional não ' +
    'recupera documento restrito' ) );
    Results := SearchLexical(Chunks, 'ajuste estoque' ,
    'supervisor' , 3);
    Check(Length(Results) > 0, (
    'supervisor recupera documento ' + 'permitido' ) );
    Document.Text := '';
    Chunks := SplitDocument(Document, 380, 60);
    Check(Length(Chunks) = 0,
    'documento vazio não produz trechos' );
    InvalidRejected := False;
    try
      Chunks := SplitDocument(Document, 32, 32);
    except
      on EArgumentException do InvalidRejected := True;
    end;
    Check(InvalidRejected,
    'sobreposição inválida rejeitada' );
    Writeln('TODAS AS VERIFICAÇÕES PASSARAM');
  except
    on Error: Exception do
    begin
      Writeln(Error.Message);
      ExitCode := 1;
    end;
  end;
end.
