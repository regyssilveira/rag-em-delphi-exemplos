program ContextDemo;

{$APPTYPE CONSOLE}

uses System.SysUtils, System.IOUtils, System.JSON, Rag.Types,
  Rag.Persistence, Rag.Lexical, Rag.Context;

const
  Identity = 'embeddinggemma:300m@85462619ee721b466c5927d109d4cb765861907d5417b9109caebc4e614679f1|retrieval-prefix-v1|dim=768';

var
  Base: TPreparedBase;
  Chunks: TArray<TChunk>;
  Index: TLexicalIndex;
  Context: TPreparedContext;
  Source: TContextSource;
  I: Integer;
  FoundUpdated: Boolean;
begin
  try
    Base := LoadPreparedBase(TPath.Combine(ExtractFilePath(ParamStr(0)), 'real-cache.json'), Identity);
    SetLength(Chunks, Length(Base.Items));
    for I := 0 to High(Chunks) do Chunks[I] := Base.Items[I].Chunk;
    Index := TLexicalIndex.Create(Chunks);
    try
      Context := BuildContext(Index.Search('prazo interno análise devolução', 'operacional', 6),
        'operacional', 1800, 3);
      FoundUpdated := False;
      for Source in Context.Sources do
      begin
        Writeln(Source.LabelId, ' -> ', Source.Chunk.Id, ' | ', Source.Chunk.Source);
        if Source.Chunk.Text.Contains('três dias úteis') then FoundUpdated := True;
        if Source.Chunk.Text.Contains('dois dias úteis') or
          (Source.Chunk.DocumentId = 'estoque.md') then raise Exception.Create('Fonte indevida');
      end;
      if not FoundUpdated then raise Exception.Create('Prazo atualizado ausente do contexto');
      if Length(Context.Serialized) > 1800 then raise Exception.Create('Orçamento excedido');
      Writeln('OK: contexto local conserva prazo atualizado e fontes permitidas');
      Writeln('CHARS=', Length(Context.Serialized), ' SOURCES=', Length(Context.Sources));
    finally Index.Free; end;
  except on E: Exception do begin Writeln(E.Message); ExitCode := 1; end; end;
end.
