program SecurityBoundaryTests;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.Classes, System.IOUtils, System.JSON,
  Rag.Types, Rag.Core, Rag.Persistence, Rag.Context;

procedure Check(Value: Boolean; const Name: string);
begin if not Value then raise Exception.Create(Name); Writeln('OK: ', Name); end;

var Base: TPreparedBase; Document: TDocument; Chunks: TArray<TChunk>;
  Ranking: TArray<TSearchResult>; Context: TPreparedContext;
  Folder, FileName, Text: string; Json: TJSONValue; I: Integer; Failed: Boolean;
begin
try
  Folder:=TPath.Combine(ParamStr(1),'bin/security-fixtures');
  TDirectory.CreateDirectory(Folder);
  FileName:=TPath.Combine(Folder,'restricted-base.json');
  Base:=Default(TPreparedBase);
  Base.ModelIdentity:='SYNTHETIC-SECURITY-BOUNDARY';
  Base.Dimension:=2; Base.MaxChars:=200; Base.Overlap:=20;
  Document:=Default(TDocument);
  Document.Id:='RESTRICTED'; Document.Source:='fictitious-secret.txt';
  Document.Access:='supervisor'; Document.Text:='SENTINEL_FICTITIOUS_RESTRICTED: supervisor approves stock adjustment.';
  Base.Documents:=[Document]; Chunks:=SplitDocument(Document,200,20);
  SetLength(Base.Items,Length(Chunks)); SetLength(Ranking,Length(Chunks));
  for I:=0 to High(Chunks) do
  begin
    Base.Items[I].Chunk:=Chunks[I]; Base.Items[I].Vector:=[1.0,0.0];
    Ranking[I].Chunk:=Chunks[I]; Ranking[I].Score:=1;
  end;
  Context:=BuildContext(Ranking,'operacional',2000);
  Check((Length(Context.Sources)=0) and not Context.Serialized.Contains('SENTINEL'),
    'contexto operacional exclui documento supervisor');
  Failed:=False;
  try BuildContext(Ranking,'administrador-inventado',2000);
  except on E:EArgumentException do Failed:=True; end;
  Check(Failed,'perfil desconhecido recusado');
  SavePreparedBase(FileName,Base);
  Text:=TFile.ReadAllText(FileName,TEncoding.UTF8);
  Check(Text.Contains('SENTINEL_FICTITIOUS_RESTRICTED'),
    'arquivo persistido permite leitura direta do texto restrito');
  Json:=TJSONObject.ParseJSONValue(Text);
  try
    for I:=0 to (Json.FindValue('documents') as TJSONArray).Count-1 do
    begin
      ((Json.FindValue('documents') as TJSONArray).Items[I] as TJSONObject).RemovePair('access').Free;
      ((Json.FindValue('documents') as TJSONArray).Items[I] as TJSONObject).AddPair('access','operacional');
    end;
    for I:=0 to (Json.FindValue('items') as TJSONArray).Count-1 do
    begin
      ((Json.FindValue('items') as TJSONArray).Items[I] as TJSONObject).RemovePair('access').Free;
      ((Json.FindValue('items') as TJSONArray).Items[I] as TJSONObject).AddPair('access','operacional');
    end;
    TFile.WriteAllText(FileName,Json.ToJSON,TEncoding.UTF8);
  finally Json.Free; end;
  Base:=LoadPreparedBase(FileName,'SYNTHETIC-SECURITY-BOUNDARY');
  Check(Base.Documents[0].Access='operacional',
    'alteração coerente de classificação aceita sem autenticação do arquivo');
  Ranking[0].Chunk:=Base.Items[0].Chunk;
  Context:=BuildContext(Ranking,'operacional',2000);
  Check(Context.Serialized.Contains('SENTINEL_FICTITIOUS_RESTRICTED'),
    'filtro segue classificação adulterada quando armazenamento não é protegido');
except on E:Exception do begin Writeln(E.Message); ExitCode:=1; end; end;
end.
