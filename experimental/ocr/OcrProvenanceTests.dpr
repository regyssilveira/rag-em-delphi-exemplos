program OcrProvenanceTests;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.Classes, System.IOUtils, System.JSON,
  Rag.Types, Rag.Core, Rag.Ocr, Rag.Embeddings, Rag.Vectors, Rag.Persistence;
type
  TSyntheticProvider = class(TInterfacedObject, IEmbeddingProvider)
    function GetModelIdentity: string;
    function EmbedDocument(const Text: string): TEmbedding;
    function EmbedQuery(const Text: string): TEmbedding;
  end;
function TSyntheticProvider.GetModelIdentity: string;
begin Result := 'SYNTHETIC-OCR-PROVENANCE-v1'; end;
function TSyntheticProvider.EmbedDocument(const Text: string): TEmbedding;
begin Result := [1, Length(Text)]; end;
function TSyntheticProvider.EmbedQuery(const Text: string): TEmbedding;
begin Result := [1, Length(Text)]; end;
var Checks: Integer; FileName, InvalidFile, Original: string;
procedure Check(Value: Boolean; const MessageText: string);
begin
  if not Value then raise Exception.Create(MessageText);
  Inc(Checks); Writeln('OK: ', MessageText);
end;
procedure Reject(Json: TJSONObject; const Identity: string);
var Rejected: Boolean;
begin
  TFile.WriteAllText(InvalidFile, Json.ToJSON, TEncoding.UTF8); Rejected := False;
  try LoadPreparedBase(InvalidFile, Identity); except on E: EReadError do Rejected := True; end;
  Check(Rejected, 'proveniência inconsistente recusada');
end;
function FirstDocument(Json: TJSONObject): TJSONObject;
begin Result := (Json.GetValue('documents') as TJSONArray).Items[0] as TJSONObject; end;
var Provider: IEmbeddingProvider; Page: TOcrPage; Review: TOcrReview; Doc: TDocument;
  Base, Loaded, Updated: TPreparedBase; Stats: TUpdateStats;
  Json, Obj: TJSONObject; Rejected: Boolean; I: Integer; FieldName: string;
begin
  try
    if ParamCount <> 2 then raise Exception.Create('Informe pasta própria e raiz dos exemplos');
    FileName := TPath.Combine(ParamStr(1), 'ocr-provenance.json'); InvalidFile := FileName + '.invalid';
    Provider := TSyntheticProvider.Create;
    Page := Default(TOcrPage); Page.Source := TPath.Combine(ParamStr(1), 'fictitious.pdf');
    Page.PageNumber := 2; Page.Text := 'O prazo é de 20 dias úteis.';
    Page.RecognitionIdentity := 'SYNTHETIC-RECOGNITION-ONLY-v1';
    Review := TOcrReview.Create(Page);
    try
      Review.AcceptText('O prazo é de 2 dias úteis.'); Doc := Review.Document('operacional');
    finally Review.Free; end;
    Base := PrepareBase([Doc], Default(TPreparedBase), Provider, 2, 380, 60, Stats);
    SavePreparedBase(FileName, Base); Loaded := LoadPreparedBase(FileName, Provider.ModelIdentity);
    Check(Loaded.Documents[0].WasOcrReviewed, 'estado de revisão reaberto');
    Check(Loaded.Documents[0].RecognizedText = Page.Text, 'texto reconhecido original reaberto');
    Check(Loaded.Documents[0].Text = Doc.Text, 'correção reaberta sem substituir original');
    Check((Loaded.Documents[0].RecognitionIdentity = Page.RecognitionIdentity)
      and (Loaded.Documents[0].PageNumber = 2), 'identidade e página reabertas');
    Check(Loaded.Items[0].Chunk.Text = Doc.Text, 'trechos usam somente texto revisado');
    Original := TFile.ReadAllText(FileName, TEncoding.UTF8);
    Json := TJSONObject.ParseJSONValue(Original) as TJSONObject;
    try
      Check((Json.GetValue('formatVersion') as TJSONNumber).AsInt = 2, 'gravação usa versão 2');
      Obj := FirstDocument(Json); Obj.RemovePair('recognizedTextHash').Free;
      Obj.AddPair('recognizedTextHash', 'invalid'); Reject(Json, Provider.ModelIdentity);
    finally Json.Free; end;
    Json := TJSONObject.ParseJSONValue(Original) as TJSONObject;
    try FirstDocument(Json).AddPair('ocrReviewed', TJSONBool.Create(True)); Reject(Json, Provider.ModelIdentity);
    finally Json.Free; end;
    Json := TJSONObject.ParseJSONValue(Original) as TJSONObject;
    try Obj := FirstDocument(Json); Obj.RemovePair('ocrReviewed').Free;
      Obj.AddPair('ocrReviewed', TJSONBool.Create(False)); Reject(Json, Provider.ModelIdentity);
    finally Json.Free; end;
    Json := TJSONObject.ParseJSONValue(Original) as TJSONObject;
    try Json.RemovePair('formatVersion').Free; Json.AddPair('formatVersion', TJSONNumber.Create(1));
      Reject(Json, Provider.ModelIdentity);
      for FieldName in ['ocrReviewed', 'recognitionIdentity', 'recognizedText', 'recognizedTextHash'] do
        FirstDocument(Json).RemovePair(FieldName).Free;
      TFile.WriteAllText(InvalidFile, Json.ToJSON, TEncoding.UTF8);
      Updated := LoadPreparedBase(InvalidFile, Provider.ModelIdentity);
      Check(not Updated.Documents[0].WasOcrReviewed and (Updated.Documents[0].RecognitionIdentity = ''),
        'base v1 não inventa histórico de revisão');
      SavePreparedBase(InvalidFile, Updated); Updated := LoadPreparedBase(InvalidFile, Provider.ModelIdentity);
      Check(Updated.Documents[0].Text = Doc.Text, 'base v1 regravada conserva conteúdo');
    finally Json.Free; end;
    Doc.RecognitionIdentity := 'SYNTHETIC-RECOGNITION-ONLY-v2';
    Updated := PrepareBase([Doc], Loaded, Provider, 2, 380, 60, Stats);
    Check((Stats.Embedded = 0) and (Stats.Reused = Length(Loaded.Items))
      and (Updated.Documents[0].RecognitionIdentity = Doc.RecognitionIdentity), 'metadado atualizado sem novo embedding');
    Updated.Documents[0].RecognitionIdentity := ''; Rejected := False;
    try SavePreparedBase(FileName, Updated); except on E: EReadError do Rejected := True; end;
    Check(Rejected and (TFile.ReadAllText(FileName, TEncoding.UTF8) = Original), 'revisão sem identidade não substitui base');
    Doc := LoadDocument(TPath.Combine(ParamStr(2), 'data/corpus/recebimento.md'), 'operacional');
    Check(not Doc.WasOcrReviewed and (Doc.RecognizedText = ''), 'leitor direto inicializa metadados vazios');
    Loaded := LoadPreparedBase(TPath.Combine(ParamStr(2), 'bin/integrated-base.json'),
      'embeddinggemma:300m@85462619ee721b466c5927d109d4cb765861907d5417b9109caebc4e614679f1|retrieval-prefix-v1|dim=768');
    for I := 0 to High(Loaded.Documents) do
      if Loaded.Documents[I].WasOcrReviewed then raise Exception.Create('Base original ganhou metadado OCR');
    Check(Length(Loaded.Items) = 8, 'base original real v1 continua abrindo sem modelos');
    Writeln('CHECKS=', Checks);
  except on E: Exception do begin Writeln(E.Message); ExitCode := 1; end; end;
end.
