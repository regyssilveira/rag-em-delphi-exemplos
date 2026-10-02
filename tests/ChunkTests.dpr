program ChunkTests;

{$APPTYPE CONSOLE}

uses System.SysUtils, System.Character, Rag.Types, Rag.Core;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then raise Exception.Create(MessageText);
  Writeln('OK: ', MessageText);
end;

procedure Validate(const Text: string; MaxChars, Overlap: Integer);
var
  Document: TDocument;
  Chunks: TArray<TChunk>;
  Chunk: TChunk;
  PreviousOffset, Covered, LastCode: Integer;
begin
  Document := Default(TDocument);
  Document.Id := 'case';
  Document.Source := 'own-fixture';
  Document.Access := 'supervisor';
  Document.PageNumber := 7;
  Document.Text := Text;
  Chunks := SplitDocument(Document, MaxChars, Overlap);
  PreviousOffset := 0;
  Covered := 1;
  for Chunk in Chunks do
  begin
    if (Chunk.StartOffset <= PreviousOffset) or (Chunk.StartOffset > Covered) then
      raise Exception.Create('Progressão ou cobertura inválida');
    if (Chunk.Text <> Copy(Text, Chunk.StartOffset, Length(Chunk.Text))) or
       (Length(Chunk.Text) > MaxChars) or Chunk.Text.IsEmpty then
      raise Exception.Create('Conteúdo ou limite inválido');
    if (Ord(Chunk.Text[1]) >= $DC00) and (Ord(Chunk.Text[1]) <= $DFFF) then
      raise Exception.Create('Trecho começa na metade de um par');
    LastCode := Ord(Chunk.Text[Length(Chunk.Text)]);
    if (LastCode >= $D800) and (LastCode <= $DBFF) then
      raise Exception.Create('Trecho termina na metade de um par');
    if (Chunk.PageNumber <> 7) or (Chunk.Access <> 'supervisor') or
       (Chunk.Source <> 'own-fixture') or (Chunk.DocumentId <> 'case') then
      raise Exception.Create('Metadados perdidos');
    PreviousOffset := Chunk.StartOffset;
    Covered := Chunk.StartOffset + Length(Chunk.Text);
  end;
  if Covered <> Length(Text) + 1 then raise Exception.Create('Cobertura incompleta');
end;

var
  PairText: string;
  Width, Overlap, Position: Integer;
begin
  try
    PairText := Char.ConvertFromUtf32($1F4E6);
    Validate(StringOfChar('A', 31) + PairText + StringOfChar('B', 45), 32, 31);
    Check(True, 'sobreposição máxima e par Unicode terminam sem laço infinito');
    for Width := 32 to 40 do
      for Overlap := 0 to Width - 1 do
        for Position := 0 to Width do
          Validate(StringOfChar('A', Position) + PairText + StringOfChar('B', 90), Width, Overlap);
    Check(True, '12.048 combinações de largura, sobreposição e posição Unicode');
    Validate('Somente o supervisor pode liberar o recebimento. A decisão deve incluir justificativa.', 64, 16);
    Check(True, 'fronteiras textuais mantêm cobertura e metadados');
    Validate('', 64, 16);
    Check(True, 'texto vazio não inventa trecho');
  except
    on E: Exception do
    begin
      Writeln('FALHOU: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
