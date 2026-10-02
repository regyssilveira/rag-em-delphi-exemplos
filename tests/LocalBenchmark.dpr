program LocalBenchmark;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.Classes, System.IOUtils, System.JSON, System.Diagnostics,
  Winapi.Windows, Winapi.PsAPI, Rag.Types, Rag.Persistence, Rag.Vectors, Rag.Lexical;

var Base:TPreparedBase; Items:TArray<TEmbeddedChunk>; Chunks:TArray<TChunk>;
  Lexical:TLexicalIndex; Vector:TVectorIndex; Found:TArray<TSearchResult>;
  Watch:TStopwatch; Report,Row:TJSONObject; Rows:TJSONArray;
  Replica,I,J,Position,RepeatCount:Integer; BuildLexical,BuildVector,SearchLexical,SearchVector:Double;
  Memory:PROCESS_MEMORY_COUNTERS; QueryVector:TEmbedding;
begin
try
  if ParamCount<>2 then raise Exception.Create('Informe base original e relatório');
  Base:=LoadPreparedBase(ParamStr(1),
    'embeddinggemma:300m@85462619ee721b466c5927d109d4cb765861907d5417b9109caebc4e614679f1|retrieval-prefix-v1|dim=768');
  if Length(Base.Items)=0 then raise Exception.Create('Base vazia');
  QueryVector:=Copy(Base.Items[0].Vector); RepeatCount:=20;
  Report:=TJSONObject.Create;
  try
    Rows:=TJSONArray.Create; Report.AddPair('measurements',Rows);
    Report.AddPair('scope','Microbenchmark local com replicações dos mesmos trechos/vetores. Consulta usa vetor de documento armazenado, não embedding de pergunta nova. Sem geração, sem qualidade ou escala empresarial demonstrada.');
    Report.AddPair('iterations',TJSONNumber.Create(RepeatCount));
    Report.AddPair('dimension',TJSONNumber.Create(Base.Dimension));
    for Replica in [1,10,100] do
    begin
      SetLength(Items,Length(Base.Items)*Replica); SetLength(Chunks,Length(Items));
      Position:=0;
      for J:=1 to Replica do
        for I:=0 to High(Base.Items) do
        begin
          Items[Position]:=Base.Items[I];
          Items[Position].Chunk.Id:=IntToStr(J)+':'+Base.Items[I].Chunk.Id;
          Items[Position].Chunk.DocumentId:=IntToStr(J)+':'+Base.Items[I].Chunk.DocumentId;
          Chunks[Position]:=Items[Position].Chunk; Inc(Position);
        end;
      Watch:=TStopwatch.StartNew; Lexical:=TLexicalIndex.Create(Chunks);
      BuildLexical:=Watch.Elapsed.TotalMilliseconds;
      try
        Watch:=TStopwatch.StartNew; Vector:=TVectorIndex.Create(Items,Base.ModelIdentity);
        BuildVector:=Watch.Elapsed.TotalMilliseconds;
        try
          Lexical.Search('Quem pode liberar um recebimento com divergência?','operacional',6);
          Vector.Search(QueryVector,Base.ModelIdentity,'operacional',6);
          Watch:=TStopwatch.StartNew;
          for I:=1 to RepeatCount do Found:=Lexical.Search('Quem pode liberar um recebimento com divergência?','operacional',6);
          SearchLexical:=Watch.Elapsed.TotalMilliseconds/RepeatCount;
          if Length(Found)=0 then raise Exception.Create('Busca lexical sem resultados');
          Watch:=TStopwatch.StartNew;
          for I:=1 to RepeatCount do Found:=Vector.Search(QueryVector,Base.ModelIdentity,'operacional',6);
          SearchVector:=Watch.Elapsed.TotalMilliseconds/RepeatCount;
          if Length(Found)=0 then raise Exception.Create('Busca vetorial sem resultados');
          Memory:=Default(PROCESS_MEMORY_COUNTERS); Memory.cb:=SizeOf(Memory);
          if not GetProcessMemoryInfo(GetCurrentProcess,@Memory,SizeOf(Memory)) then RaiseLastOSError;
          Row:=TJSONObject.Create; Rows.AddElement(Row);
          Row.AddPair('chunks',TJSONNumber.Create(Length(Items)));
          Row.AddPair('replicas',TJSONNumber.Create(Replica));
          Row.AddPair('buildLexicalMs',TJSONNumber.Create(BuildLexical));
          Row.AddPair('buildVectorMs',TJSONNumber.Create(BuildVector));
          Row.AddPair('meanLexicalSearchMs',TJSONNumber.Create(SearchLexical));
          Row.AddPair('meanVectorSearchMs',TJSONNumber.Create(SearchVector));
          Row.AddPair('workingSetBytes',TJSONNumber.Create(Int64(Memory.WorkingSetSize)));
        finally Vector.Free; end;
      finally Lexical.Free; end;
    end;
    TFile.WriteAllText(ParamStr(2),Report.ToJSON,TEncoding.UTF8);
    Writeln('OK: três tamanhos, vinte consultas locais por método');
  finally Report.Free; end;
except on E:Exception do begin Writeln(E.Message); ExitCode:=1; end; end;
end.
