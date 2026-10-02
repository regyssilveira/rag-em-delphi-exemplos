program EmbeddingDemo;

{$APPTYPE CONSOLE}

uses System.SysUtils, System.IOUtils, System.Generics.Collections,
  Rag.Types, Rag.Core, Rag.Vectors, Rag.Embeddings;

const
  Model = 'embeddinggemma:300m';
  Digest = '85462619ee721b466c5927d109d4cb765861907d5417b9109caebc4e614679f1';

procedure Search(Index: TVectorIndex; Provider: IEmbeddingProvider; const Query, Profile: string);
var
  Result: TSearchResult;
begin
  Writeln('QUERY ', Profile, ' | ', Query);
  for Result in Index.Search(Provider.EmbedQuery(Query), Provider.ModelIdentity, Profile, 3) do
    Writeln(Result.Chunk.Id, ' | ', FormatFloat('0.0000', Result.Score));
end;

var
  Provider: IEmbeddingProvider;
  AllItems: TList<TEmbeddedChunk>;
  Document: TDocument;
  Chunk: TChunk;
  Item: TEmbeddedChunk;
  Index: TVectorIndex;
  Name, Access: string;
begin
  try
    if ParamCount <> 1 then raise Exception.Create('Informe data/corpus');
    Provider := TOllamaEmbeddingProvider.Create(Model, Digest, 768);
    AllItems := TList<TEmbeddedChunk>.Create;
    try
      for Name in ['recebimento.md', 'devolucoes.md', 'estoque.md'] do
      begin
        Access := 'operacional';
        if Name = 'estoque.md' then Access := 'supervisor';
        Document := LoadDocument(TPath.Combine(ParamStr(1), Name), Access);
        for Chunk in SplitDocument(Document, 380, 60) do
        begin
          Item.Chunk := Chunk;
          Item.Vector := Provider.EmbedDocument(Chunk.Text);
          AllItems.Add(Item);
        end;
      end;
      Index := TVectorIndex.Create(AllItems.ToArray, Provider.ModelIdentity);
      try
        Writeln('Dimension=', Index.Dimension);
        Writeln('EmbeddedChunks=', AllItems.Count);
        Search(Index, Provider, 'Quem autoriza uma entrega com quantidade diferente?', 'operacional');
        Search(Index, Provider, 'Qual é a comissão do vendedor?', 'operacional');
        Search(Index, Provider, 'Quem aprova ajustes no saldo do depósito?', 'supervisor');
        Search(Index, Provider, 'Quem aprova ajustes no saldo do depósito?', 'operacional');
      finally Index.Free; end;
    finally AllItems.Free; end;
    Provider := nil;
  except on E: Exception do begin Writeln(E.Message); ExitCode := 1; end; end;
end.
