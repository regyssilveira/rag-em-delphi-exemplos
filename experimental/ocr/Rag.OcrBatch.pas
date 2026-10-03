unit Rag.OcrBatch;
interface
uses System.SysUtils, System.Classes, Rag.Types, Rag.Ocr;
type
  TOcrBatchPage = record
    DirectDocument: TDocument;
    Recognition: TOcrPage;
    PreviewPath: string;
    NeedsReview: Boolean;
  end;
  TOcrDecisionKind = (odAccept, odSkipWithoutText, odCancel);
  TOcrDecision = record
    Kind: TOcrDecisionKind;
    ReviewedText: string;
  end;
  TOcrDecisionCallback = reference to function(const Page: TOcrBatchPage): TOcrDecision;
  TOcrPreparedBatch = class
  private
    FPages: TArray<TOcrBatchPage>;
    FFolder, FSource, FAccess: string;
    FOwnFolder: Boolean;
    FSourceGuard: TFileStream;
    function GetPage(Index: Integer): TOcrBatchPage;
    function GetCount: Integer;
  public
    constructor Create(const PdfPath, PdfiumPath, WorkFolder, Access: string;
      Provider: IOcrProvider; const Cancelled: TFunc<Boolean> = nil);
    destructor Destroy; override;
    function CollectDocuments(const Decide: TOcrDecisionCallback;
      const Cancelled: TFunc<Boolean> = nil): TArray<TDocument>;
    property Count: Integer read GetCount;
    property Pages[Index: Integer]: TOcrBatchPage read GetPage;
  end;
implementation
uses System.IOUtils, System.Generics.Collections, Winapi.Windows,
  Rag.Pdf, Rag.Import;
procedure CheckCancelled(const Cancelled: TFunc<Boolean>);
begin
  if Assigned(Cancelled) and Cancelled() then raise EOcrCancelled.Create('Lote OCR cancelado');
end;
procedure WriteBitmap(const FileName: string; const Page: TRenderedPdfPage);
var Header: TBitmapFileHeader; Info: TBitmapInfoHeader; Stream: TFileStream;
begin
  if Page.Stride <> Page.Width * 4 then raise EReadError.Create('Passo de bitmap inesperado');
  Header := Default(TBitmapFileHeader); Info := Default(TBitmapInfoHeader);
  Header.bfType := $4D42; Header.bfOffBits := SizeOf(Header) + SizeOf(Info);
  Header.bfSize := Header.bfOffBits + Cardinal(Length(Page.Pixels));
  Info.biSize := SizeOf(Info); Info.biWidth := Page.Width; Info.biHeight := -Page.Height;
  Info.biPlanes := 1; Info.biBitCount := 32; Info.biCompression := BI_RGB;
  Info.biSizeImage := Length(Page.Pixels);
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    Stream.WriteBuffer(Header, SizeOf(Header)); Stream.WriteBuffer(Info, SizeOf(Info));
    Stream.WriteBuffer(Page.Pixels[0], Length(Page.Pixels));
  finally Stream.Free; end;
end;
constructor TOcrPreparedBatch.Create(const PdfPath, PdfiumPath, WorkFolder, Access: string;
  Provider: IOcrProvider; const Cancelled: TFunc<Boolean>);
var Extracted: TArray<TPdfPageText>; Rendered: TRenderedPdfPage; I: Integer;
  PreviewBytes, TextChars: Int64;
begin
  inherited Create;
  CheckCancelled(Cancelled);
  if Provider = nil then raise EArgumentException.Create('Reconhecedor ausente');
  if (Access <> 'operacional') and (Access <> 'supervisor') then
    raise EArgumentException.Create('Classificação desconhecida');
  if not TPath.IsPathRooted(WorkFolder) or not TDirectory.Exists(WorkFolder) then
    raise EArgumentException.Create('Pasta absoluta de trabalho ausente');
  FSource := TPath.GetFullPath(PdfPath); FAccess := Access;
  FSourceGuard := TFileStream.Create(FSource, fmOpenRead or fmShareDenyWrite);
  FFolder := TPath.Combine(TPath.GetFullPath(WorkFolder), 'ocr-batch-' + TGUID.NewGuid.ToString);
  if TDirectory.Exists(FFolder) then raise EReadError.Create('Pasta temporária já existe');
  TDirectory.CreateDirectory(FFolder); FOwnFolder := True;
  Extracted := ReadPdfPages(FSource, PdfiumPath);
  SetLength(FPages, Length(Extracted)); PreviewBytes := 0; TextChars := 0;
  for I := 0 to High(Extracted) do
  begin
    CheckCancelled(Cancelled);
    FPages[I].NeedsReview := not Extracted[I].HasExtractedText or Extracted[I].HadUnmappedCharacters;
    if FPages[I].NeedsReview then
    begin
      Rendered := RenderPdfPage(FSource, PdfiumPath, I + 1, 200);
      Inc(PreviewBytes, Length(Rendered.Pixels) + SizeOf(TBitmapFileHeader) + SizeOf(TBitmapInfoHeader));
      if PreviewBytes > 128 * 1024 * 1024 then raise EReadError.Create('Pré-visualizações excedem 128 MiB');
      FPages[I].PreviewPath := TPath.Combine(FFolder, IntToStr(I + 1) + '.bmp');
      WriteBitmap(FPages[I].PreviewPath, Rendered); Rendered := Default(TRenderedPdfPage);
      CheckCancelled(Cancelled);
      FPages[I].Recognition := Provider.Recognize(FPages[I].PreviewPath, FSource, I + 1, Cancelled);
      if (FPages[I].Recognition.Source <> FSource) or (FPages[I].Recognition.PageNumber <> I + 1)
        or FPages[I].Recognition.RecognitionIdentity.Trim.IsEmpty then
        raise EReadError.Create('Reconhecimento perdeu origem ou página');
      Inc(TextChars, Length(FPages[I].Recognition.Text));
    end
    else
    begin
      FPages[I].DirectDocument := Default(TDocument);
      FPages[I].DirectDocument.Id := TPath.GetFileName(FSource) + ':page:' + IntToStr(I + 1);
      FPages[I].DirectDocument.Source := FSource; FPages[I].DirectDocument.PageNumber := I + 1;
      FPages[I].DirectDocument.Access := Access; FPages[I].DirectDocument.Text := Extracted[I].Text;
      Inc(TextChars, Length(Extracted[I].Text));
    end;
    if TextChars > MaxImportedTextChars then raise EReadError.Create('Texto do lote excede o limite');
  end;
end;
destructor TOcrPreparedBatch.Destroy;
var Page: TOcrBatchPage;
begin
  try
    for Page in FPages do
      if (Page.PreviewPath <> '') and TFile.Exists(Page.PreviewPath) then TFile.Delete(Page.PreviewPath);
    if FOwnFolder and TDirectory.Exists(FFolder) then TDirectory.Delete(FFolder, False);
  finally FSourceGuard.Free; inherited; end;
end;
function TOcrPreparedBatch.GetCount: Integer;
begin Result := Length(FPages); end;
function TOcrPreparedBatch.GetPage(Index: Integer): TOcrBatchPage;
begin
  if (Index < 0) or (Index >= Length(FPages)) then raise EArgumentOutOfRangeException.Create('Página fora do lote');
  Result := FPages[Index];
end;
function TOcrPreparedBatch.CollectDocuments(const Decide: TOcrDecisionCallback;
  const Cancelled: TFunc<Boolean>): TArray<TDocument>;
var Documents: TList<TDocument>; Page: TOcrBatchPage; Decision: TOcrDecision;
  Review: TOcrReview; Document: TDocument; TextChars: Int64;
begin
  if not Assigned(Decide) then raise EArgumentException.Create('Decisão de revisão ausente');
  Documents := TList<TDocument>.Create;
  try
    TextChars := 0;
    for Page in FPages do
    begin
      CheckCancelled(Cancelled);
      if not Page.NeedsReview then Document := Page.DirectDocument
      else
      begin
        Decision := Decide(Page); CheckCancelled(Cancelled);
        case Decision.Kind of
          odCancel: raise EOcrCancelled.Create('Revisão cancelada; base não gravada');
          odSkipWithoutText:
            begin
              if not Page.Recognition.Text.Trim.IsEmpty then raise EArgumentException.Create('Exclusão exige ausência de texto reconhecido');
              Continue;
            end;
          odAccept:
            begin
              Review := TOcrReview.Create(Page.Recognition);
              try Review.AcceptText(Decision.ReviewedText); Document := Review.Document(FAccess);
              finally Review.Free; end;
            end;
        else raise EArgumentException.Create('Decisão desconhecida'); end;
      end;
      Inc(TextChars, Length(Document.Text));
      if TextChars > MaxImportedTextChars then raise EReadError.Create('Texto revisado excede o limite');
      Documents.Add(Document);
    end;
    if Documents.Count = 0 then raise EReadError.Create('Nenhum documento aceito; use remoção explícita para excluir origem');
    Result := Documents.ToArray;
  finally Documents.Free; end;
end;
end.
