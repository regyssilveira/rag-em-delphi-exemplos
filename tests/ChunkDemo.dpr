program ChunkDemo;

{$APPTYPE CONSOLE}

uses System.SysUtils, Rag.Types, Rag.Core;

procedure Show(const Document: TDocument; MaxChars, Overlap: Integer);
var
  Chunk: TChunk;
begin
  Writeln('CONFIG ', MaxChars, '/', Overlap);
  for Chunk in SplitDocument(Document, MaxChars, Overlap) do
    Writeln(Chunk.StartOffset, ' | ', Length(Chunk.Text), ' | ', Chunk.Text);
end;

var
  Document: TDocument;
begin
  Document := Default(TDocument);
  Document.Id := 'recebimento';
  Document.Source := 'procedimento-ficticio';
  Document.Access := 'operacional';
  Document.Text := 'Somente o supervisor pode liberar um recebimento com divergência. ' +
    'A decisão deve incluir a justificativa no registro do recebimento.';
  Show(Document, 64, 0);
  Show(Document, 64, 16);
  Show(Document, 96, 16);
end.
