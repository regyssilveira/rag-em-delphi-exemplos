program PersistenceTests;

{$APPTYPE CONSOLE}

uses System.SysUtils, System.IOUtils, System.Classes, System.JSON,
  Rag.Types, Rag.Vectors, Rag.Embeddings, Rag.Persistence;

type
  TSyntheticProvider = class(TInterfacedObject, IEmbeddingProvider)
  public
    Calls: Integer;
    Identity: string;
    function GetModelIdentity: string;
    function EmbedDocument(const Text: string): TEmbedding;
    function EmbedQuery(const Text: string): TEmbedding;
  end;

function TSyntheticProvider.GetModelIdentity: string;
begin Result := Identity; end;
function TSyntheticProvider.EmbedDocument(const Text: string): TEmbedding;
begin Inc(Calls); Result := [1, Length(Text)]; end;
function TSyntheticProvider.EmbedQuery(const Text: string): TEmbedding;
begin Result := [1, Length(Text)]; end;

procedure Check(Value: Boolean; const MessageText: string);
begin
  if not Value then raise Exception.Create('FALHOU: ' + MessageText);
  Writeln('OK: ', MessageText);
end;

procedure RejectFile(const FileName, Identity: string);
var Rejected: Boolean;
begin
  Rejected := False;
  try LoadPreparedBase(FileName, Identity); except on EReadError do Rejected := True; on EConvertError do Rejected := True; end;
  Check(Rejected, 'base inválida rejeitada');
end;

var
  Provider: IEmbeddingProvider;
  Counting: TSyntheticProvider;
  Documents: TArray<TDocument>;
  Base, Loaded, Updated: TPreparedBase;
  Stats: TUpdateStats;
  FileName, CorruptFile, Original: string;
  Json: TJSONObject;
  Rejected: Boolean;
  LockStream: TFileStream;
  Bytes: TBytes;
begin
  try
    FileName := TPath.Combine(ExtractFilePath(ParamStr(0)), 'synthetic-base.json');
    CorruptFile := FileName + '.invalid';
    Counting := TSyntheticProvider.Create;
    Counting.Identity := 'SYNTHETIC-MATH-ONLY-v1';
    Provider := Counting;
    SetLength(Documents, 2);
    Documents[0].Id := 'doc-a'; Documents[0].Source := 'own-a'; Documents[0].Access := 'operacional';
    Documents[0].Text := 'Somente o supervisor libera a divergência. A decisão exige justificativa.';
    Documents[0].PageNumber := 2;
    Documents[1].Id := 'doc-b'; Documents[1].Source := 'own-b'; Documents[1].Access := 'supervisor';
    Documents[1].Text := 'O prazo fictício é de dois dias úteis.';
    Base := PrepareBase(Documents, Default(TPreparedBase), Provider, 2, 64, 16, Stats);
    Check((Stats.Embedded = Length(Base.Items)) and (Stats.Reused = 0), 'primeira preparação gera todos os vetores');
    SavePreparedBase(FileName, Base);
    Loaded := LoadPreparedBase(FileName, Provider.ModelIdentity);
    Check(Loaded.Documents[0].Text = Documents[0].Text, 'texto e acentos preservados após reabertura');
    Check(Loaded.Items[0].Chunk.PageNumber = 2, 'origem e página preservadas');
    Check(Abs(CosineSimilarity(Loaded.Items[0].Vector, Base.Items[0].Vector) - 1) < 1E-12, 'vetor reaberto mantém direção');
    Counting.Calls := 0;
    Updated := PrepareBase(Documents, Loaded, Provider, 2, 64, 16, Stats);
    Check((Stats.Embedded = 0) and (Counting.Calls = 0) and (Stats.Reused = Length(Base.Items)), 'base sem alteração não chama provedor');
    Documents[1].Text := 'O prazo fictício é de três dias úteis.';
    Updated := PrepareBase(Documents, Loaded, Provider, 2, 64, 16, Stats);
    Check((Stats.Embedded = 1) and (Stats.Reused = Length(Base.Items) - 1), 'alteração reprocessa somente trecho afetado');
    Documents[0].Access := 'supervisor';
    Updated := PrepareBase(Documents, Updated, Provider, 2, 64, 16, Stats);
    Check((Stats.Embedded = 0) and (Updated.Items[0].Chunk.Access = 'supervisor'), 'metadado novo não herda acesso antigo');
    SetLength(Documents, 1);
    Loaded := Updated;
    Updated := PrepareBase(Documents, Loaded, Provider, 2, 64, 16, Stats);
    Check((Stats.Removed = 1) and (Length(Updated.Documents) = 1), 'documento excluído remove trecho');
    Counting.Identity := 'SYNTHETIC-MATH-ONLY-v2';
    Loaded := Updated;
    Updated := PrepareBase(Documents, Loaded, Provider, 2, 64, 16, Stats);
    Check((Stats.Reused = 0) and (Stats.Embedded = Length(Updated.Items)), 'modelo diferente exige reprocessar');
    Original := TFile.ReadAllText(FileName, TEncoding.UTF8);
    RejectFile(FileName, Provider.ModelIdentity);
    TFile.WriteAllText(CorruptFile, '{', TEncoding.UTF8);
    RejectFile(CorruptFile, Base.ModelIdentity);
    Json := TJSONObject.ParseJSONValue(Original) as TJSONObject;
    try
      Json.RemovePair('formatVersion').Free;
      Json.AddPair('formatVersion', TJSONNumber.Create(99));
      TFile.WriteAllText(CorruptFile, Json.ToJSON, TEncoding.UTF8);
    finally Json.Free; end;
    RejectFile(CorruptFile, Base.ModelIdentity);
    Json := TJSONObject.ParseJSONValue(Original) as TJSONObject;
    try
      ((Json.GetValue('documents') as TJSONArray).Items[0] as TJSONObject).RemovePair('textHash').Free;
      ((Json.GetValue('documents') as TJSONArray).Items[0] as TJSONObject).AddPair('textHash', 'corrupted');
      TFile.WriteAllText(CorruptFile, Json.ToJSON, TEncoding.UTF8);
    finally Json.Free; end;
    RejectFile(CorruptFile, Base.ModelIdentity);
    Bytes := [$C3, $28];
    TFile.WriteAllBytes(CorruptFile, Bytes);
    RejectFile(CorruptFile, Base.ModelIdentity);
    TFile.WriteAllText(CorruptFile, StringReplace(Original, '"formatVersion":1', '"formatVersion":1,"formatVersion":1', []), TEncoding.UTF8);
    RejectFile(CorruptFile, Base.ModelIdentity);
    Loaded := LoadPreparedBase(FileName, Base.ModelIdentity);
    LockStream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    Rejected := False;
    try
      try SavePreparedBase(FileName, Loaded); except on EOSError do Rejected := True; end;
    finally LockStream.Free; end;
    Check(Rejected and (TFile.ReadAllText(FileName, TEncoding.UTF8) = Original), 'substituição bloqueada preserva base anterior');
    Check(Length(TDirectory.GetFiles(ExtractFilePath(FileName), 'synthetic-base.json.*.tmp')) = 0, 'temporário próprio removido após falha');
    TFile.WriteAllText(FileName + '.interrupted.tmp', '{', TEncoding.UTF8);
    Loaded := LoadPreparedBase(FileName, Base.ModelIdentity);
    Check(Loaded.Documents[0].Text = Base.Documents[0].Text, 'temporário interrompido não substitui base oficial');
    TFile.Delete(FileName + '.interrupted.tmp');
    Base.Items[0].Chunk.Access := 'operacional';
    Base.Documents[0].Access := 'supervisor';
    Rejected := False;
    try SavePreparedBase(FileName, Base); except on EReadError do Rejected := True; end;
    Check(Rejected and (TFile.ReadAllText(FileName, TEncoding.UTF8) = Original), 'base incoerente não substitui arquivo válido');
    Provider := nil;
  except on E: Exception do begin Writeln(E.Message); ExitCode := 1; end; end;
end.
