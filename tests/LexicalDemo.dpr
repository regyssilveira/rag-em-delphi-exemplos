program LexicalDemo;

{$APPTYPE CONSOLE}

uses System.SysUtils, System.IOUtils, System.Generics.Collections,
  Rag.Types, Rag.Core, Rag.Lexical;

procedure Query(Index: TLexicalIndex; const Text, Profile: string);
var
  Item: TSearchResult;
  Results: TArray<TSearchResult>;
begin
  Writeln('QUERY ', Profile, ' | ', Text);
  Results := Index.Search(Text, Profile, 3);
  if Length(Results) = 0 then Writeln('SEM CORRESPONDENCIA');
  for Item in Results do
    Writeln(Item.Chunk.Id, ' | ', FormatFloat('0.0000', Item.Score), ' | ', Item.Chunk.Text);
end;

var
  AllChunks: TList<TChunk>;
  Document: TDocument;
  Chunk: TChunk;
  Name, Access: string;
  Index: TLexicalIndex;
begin
  try
    if ParamCount <> 1 then raise Exception.Create('Informe data/corpus');
    AllChunks := TList<TChunk>.Create;
    try
      for Name in ['recebimento.md', 'devolucoes.md', 'estoque.md'] do
      begin
        Access := 'operacional';
        if Name = 'estoque.md' then Access := 'supervisor';
        Document := LoadDocument(TPath.Combine(ParamStr(1), Name), Access);
        for Chunk in SplitDocument(Document, 380, 60) do AllChunks.Add(Chunk);
      end;
      Index := TLexicalIndex.Create(AllChunks.ToArray);
      try
        Query(Index, 'recebimento divergência supervisor', 'operacional');
        Query(Index, 'comissão vendedor', 'operacional');
        Query(Index, 'ajuste estoque', 'operacional');
        Query(Index, 'ajuste estoque', 'supervisor');
      finally Index.Free; end;
    finally AllChunks.Free; end;
  except
    on E: Exception do begin Writeln(E.Message); ExitCode := 1; end;
  end;
end.
