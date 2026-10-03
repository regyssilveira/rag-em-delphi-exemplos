program OcrBatchTests;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.Classes, System.IOUtils
  , System.Hash, Rag.Ocr, Rag.OcrBatch,
  Rag.Types, Rag.Vectors, Rag.Embeddings,
    Rag.Persistence, Rag.BaseEditor;
type

  TSyntheticProvider = class(TInterfacedObject,
    IEmbeddingProvider)
    function GetModelIdentity: string;
    function EmbedDocument(const Text: string):
      TEmbedding;
    function EmbedQuery(const Text: string):
      TEmbedding;
  end;
function TSyntheticProvider.GetModelIdentity: string
  ;
begin Result := 'SYNTHETIC-OCR-BATCH-ONLY-v1'; end;
function TSyntheticProvider.EmbedDocument(const Text
  : string): TEmbedding;
begin Result := [1, Length(Text)]; end;
function TSyntheticProvider.EmbedQuery(const Text:
  string): TEmbedding;
begin Result := [1, Length(Text)]; end;
var Checks: Integer;
procedure Check(Value: Boolean; const MessageText:
  string);
begin

  if not Value then raise Exception.Create(
    MessageText);
  Inc(Checks); Writeln('OK: ', MessageText);
end;
function AcceptKnown(const Page: TOcrBatchPage):
  TOcrDecision;
begin

  Result := Default(TOcrDecision);
  if Page.Recognition.Text.Trim.IsEmpty then
    Result.Kind := odSkipWithoutText
  else begin Result.Kind := odAccept;
    Result.ReviewedText := Page.Recognition.Text;
    end;
end;
var Ocr: IOcrProvider; Embeddings:
  IEmbeddingProvider; Batch: TOcrPreparedBatch;
  Documents: TArray<TDocument>; Base, Loaded:
    TPreparedBase; Stats: TUpdateStats;
  Exe, Data, Folder, Pdf, Dll, BasePath, Original,
    Preview: string; Rejected: Boolean;
  Writer: TFileStream;
begin

  try

    if ParamCount <> 5 then raise Exception.Create(
      'Informe runtime, dados, ' +
      'pasta, PDF e DLL');
    Exe := ParamStr(1); Data := ParamStr(2); Folder
      := ParamStr(3); Pdf := ParamStr(4); Dll :=
      ParamStr(5);
    Ocr := TTesseractProcessProvider.Create(Exe,
      Data, Folder,
      THashSHA2.GetHashStringFromFile(Exe),
        THashSHA2.GetHashStringFromFile(
        TPath.Combine(Data, 'por.traineddata')));
    Embeddings := TSyntheticProvider.Create;
      BasePath := TPath.Combine(Folder,
      'ocr-batch-base.json');
    Batch := TOcrPreparedBatch.Create(Pdf, Dll,
      Folder, 'operacional', Ocr);
    try

      Rejected := False;
      try Writer := TFileStream.Create(Pdf,
        fmOpenWrite or fmShareDenyNone); Writer.Free
        ;
      except on E: EFOpenError do Rejected := True;
        end;
      Check(Rejected, 'origem protegida contra ' +
        'escrita durante o lote');
      Check((Batch.Count = 3) and not Batch.Pages[0]
        .NeedsReview
        and Batch.Pages[1].NeedsReview and
          Batch.Pages[2].NeedsReview,
          'páginas digitais e ' +
          'reconhecidas separadas');
      Check(Batch.Pages[1].Recognition.Text.Contains
        ('Somente o supervisor pode ' + 'liberar.'),
        'página escaneada ' + 'reconhecida');
      Check(Batch.Pages[2].
        Recognition.Text.Trim.IsEmpty,
        'página branca sem texto ' + 'reconhecido');
      Preview := Batch.Pages[1].PreviewPath;
      Documents := Batch.CollectDocuments(
        AcceptKnown);
      Check((Length(Documents) = 2) and not
        Documents[0].WasOcrReviewed and Documents[1]
        .WasOcrReviewed,
        'aceitação e exclusão ' +
          'explícitas compõem dois ' + 'documentos')
          ;
      Base := ReviewedSourcePrepareSave(BasePath,
        Documents, Embeddings, 2, 380, 60, Stats);
      Loaded := LoadPreparedBase(BasePath,
        Embeddings.ModelIdentity);
      Check((Length(Loaded.Documents) = 2) and (
        Loaded.Documents[1].RecognizedText =
        Batch.Pages[1].Recognition.Text),
        'lote gravado conserva ' +
          'reconhecimento original');
      Original := TFile.ReadAllText(BasePath,
        TEncoding.UTF8); Rejected := False;
      try Batch.CollectDocuments(function(const Page
        : TOcrBatchPage): TOcrDecision
        begin Result := Default(TOcrDecision);
          Result.Kind := odCancel; end);
      except on E: EOcrCancelled do Rejected := True
        ; end;
      Check(Rejected and (TFile.ReadAllText(BasePath
        , TEncoding.UTF8) = Original),
        'cancelar revisão preserva ' +
        'base anterior');
      Rejected := False;
      try ReviewedSourcePrepareSave(BasePath,
        Documents, Embeddings, 2, 380, 60, Stats,
        function: Boolean begin Result := True; end)
          ;
      except on E: EAbort do Rejected := True; end;
      Check(Rejected and (TFile.ReadAllText(BasePath
        , TEncoding.UTF8) = Original),
        'cancelar preparação ' +
        'preserva base anterior');
      Base := ReviewedSourcePrepareSave(BasePath,
        Documents, Embeddings, 2, 380, 60, Stats);
      Check((Stats.Embedded = 0) and (Stats.Reused =
        Length(Base.Items)),
        'reimportação compatível ' +
        'reutiliza vetores');
      Rejected := False;
      try Batch.CollectDocuments(function(const Page
        : TOcrBatchPage): TOcrDecision
        begin Result := Default(TOcrDecision);
          Result.Kind := odSkipWithoutText; end);
      except on E: EArgumentException do Rejected :=
        True; end;
      Check(Rejected, 'texto reconhecido não ' +
        'pode ser excluído como ' + 'vazio');
    finally Batch.Free; end;
    Check(not TFile.Exists(Preview) and not
      TDirectory.Exists(TPath.GetDirectoryName(
      Preview)), 'prévias próprias ' +
      'removidas ao finalizar ' + 'lote');
    Check(TFile.Exists(Pdf), 'documento original ' +
      'preservado');
    Writeln('CHECKS=', Checks);
  except on E: Exception do begin Writeln(E.Message)
    ; ExitCode := 1; end; end;
end.
