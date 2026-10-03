unit Rag.Ocr;

interface

uses System.SysUtils, Rag.Types;

type
  EOcrCancelled = class(Exception);
  EOcrTimeout = class(Exception);
  TOcrPage = record
    Source: string;
    PageNumber: Integer;
    Text: string;
    RecognitionIdentity: string;
  end;
  IOcrProvider = interface
    ['{673C656B-5E8A-4B24-82E3-65888C797A57}']
    function Recognize(const ImagePath, OriginalSource: string; PageNumber: Integer;
      const Cancelled: TFunc<Boolean>): TOcrPage;
  end;
  TTesseractProcessProvider = class(TInterfacedObject, IOcrProvider)
  private
    FExe, FData, FWorkFolder, FExeHash, FDataHash: string;
    FTimeoutMs: Cardinal;
    procedure VerifyArtifacts;
  public
    constructor Create(const ExePath, DataFolder, WorkFolder, ExeSha256, DataSha256: string;
      TimeoutMs: Cardinal = 60000);
    function Recognize(const ImagePath, OriginalSource: string; PageNumber: Integer;
      const Cancelled: TFunc<Boolean>): TOcrPage;
  end;
  TOcrReview = class
  private
    FPage: TOcrPage;
    FAccepted: Boolean;
    FReviewedText: string;
  public
    constructor Create(const Page: TOcrPage);
    procedure AcceptText(const ReviewedText: string);
    function Document(const Access: string): TDocument;
    property Accepted: Boolean read FAccepted;
    property Page: TOcrPage read FPage;
    property ReviewedText: string read FReviewedText;
  end;

implementation

uses System.Classes, System.IOUtils, System.Hash, Winapi.Windows, Rag.Ingestion;

procedure CheckCancelled(const Cancelled: TFunc<Boolean>);
begin
  if Assigned(Cancelled) and Cancelled() then raise EOcrCancelled.Create('OCR cancelado');
end;

function QuoteArgument(const Value: string): string;
begin
  if Value.Contains('"') or Value.Contains(#13) or Value.Contains(#10) then
    raise EArgumentException.Create('Argumento de processo inválido');
  Result := '"' + Value + '"';
end;

constructor TTesseractProcessProvider.Create(const ExePath, DataFolder, WorkFolder,
  ExeSha256, DataSha256: string; TimeoutMs: Cardinal);
begin
  inherited Create;
  if not TPath.IsPathRooted(ExePath) or not TPath.IsPathRooted(DataFolder)
    or not TPath.IsPathRooted(WorkFolder) then raise EArgumentException.Create('Use caminhos absolutos');
  if (TimeoutMs < 100) or (TimeoutMs > 60000) then raise EArgumentException.Create('Tempo limite inválido');
  if (Length(ExeSha256) <> 64) or (Length(DataSha256) <> 64) then
    raise EArgumentException.Create('Hashes esperados ausentes');
  FExe := TPath.GetFullPath(ExePath); FData := TPath.GetFullPath(DataFolder);
  FWorkFolder := TPath.GetFullPath(WorkFolder); FExeHash := ExeSha256; FDataHash := DataSha256;
  FTimeoutMs := TimeoutMs;
  if not TDirectory.Exists(FWorkFolder) then raise EArgumentException.Create('Pasta de trabalho ausente');
  VerifyArtifacts;
end;

procedure TTesseractProcessProvider.VerifyArtifacts;
begin
  if not TFile.Exists(FExe) or not TFile.Exists(TPath.Combine(FData, 'por.traineddata')) then
    raise EReadError.Create('Executável ou dados de português ausentes');
  if not SameText(THashSHA2.GetHashStringFromFile(FExe), FExeHash)
    or not SameText(THashSHA2.GetHashStringFromFile(TPath.Combine(FData, 'por.traineddata')), FDataHash) then
    raise EReadError.Create('Artefato OCR difere da identidade esperada');
end;

function TTesseractProcessProvider.Recognize(const ImagePath, OriginalSource: string;
  PageNumber: Integer; const Cancelled: TFunc<Boolean>): TOcrPage;
var Startup: TStartupInfo; Process: TProcessInformation; Command, Base, OutputPath: string;
  State, Code: Cardinal; Started: UInt64; Stream: TFileStream;
  Bytes: TBytes; Encoding: TUTF8Encoding; Running: Boolean;
begin
  Result := Default(TOcrPage); CheckCancelled(Cancelled);
  if (PageNumber < 0) or OriginalSource.Trim.IsEmpty then
    raise EArgumentException.Create('Origem ou página inválida');
  if not TFile.Exists(ImagePath) then raise EReadError.Create('Imagem ausente');
  VerifyArtifacts; CheckCancelled(Cancelled);
  Base := TPath.Combine(FWorkFolder, 'ocr-' + TGUID.NewGuid.ToString);
  OutputPath := Base + '.txt';
  Command := QuoteArgument(FExe) + ' ' + QuoteArgument(TPath.GetFullPath(ImagePath)) +
    ' ' + QuoteArgument(Base) + ' --tessdata-dir ' + QuoteArgument(FData) + ' -l por --psm 6';
  Startup := Default(TStartupInfo); Startup.cb := SizeOf(Startup);
  Process := Default(TProcessInformation); UniqueString(Command);
  try
    if not CreateProcess(PChar(FExe), PChar(Command), nil, nil, False,
      CREATE_NO_WINDOW, nil, PChar(TPath.GetDirectoryName(FExe)), Startup, Process) then RaiseLastOSError;
    Running := True;
    try
      Started := GetTickCount64;
      repeat
        CheckCancelled(Cancelled);
        State := WaitForSingleObject(Process.hProcess, 50);
        if State = WAIT_OBJECT_0 then begin Running := False; Break; end;
        if State = WAIT_FAILED then RaiseLastOSError;
        if GetTickCount64 - Started >= FTimeoutMs then raise EOcrTimeout.Create('Tempo de OCR excedido');
      until False;
      CheckCancelled(Cancelled);
      if not GetExitCodeProcess(Process.hProcess, Code) then RaiseLastOSError;
      if Code <> 0 then raise EReadError.CreateFmt('OCR falhou com código %d', [Code]);
      Stream := TFileStream.Create(OutputPath, fmOpenRead or fmShareDenyWrite);
      try
        if Stream.Size > 1024 * 1024 then raise EReadError.Create('Texto OCR excede 1 MiB');
        SetLength(Bytes, Integer(Stream.Size));
        if Length(Bytes) > 0 then Stream.ReadBuffer(Bytes[0], Length(Bytes));
      finally Stream.Free; end;
      Encoding := TUTF8Encoding.Create(False);
      try
        if (Length(Bytes) > 0) and not Encoding.IsBufferValid(@Bytes[0], Length(Bytes)) then
          raise EConvertError.Create('Saída OCR não contém UTF-8 válido');
        Result.Text := Encoding.GetString(Bytes);
        if (Length(Result.Text) > 0) and (Result.Text[1] = #$FEFF) then Delete(Result.Text, 1, 1);
        if Result.Text.Contains(#0) then raise EConvertError.Create('Saída OCR contém caractere nulo');
        Result.Text := NormalizeText(Result.Text);
      finally Encoding.Free; end;
      Result.Source := TPath.GetFullPath(OriginalSource); Result.PageNumber := PageNumber;
      Result.RecognitionIdentity := 'tesseract-process|exe=' + FExeHash + '|por=' + FDataHash + '|psm=6';
    finally
      try
        if Running then
        begin
          if not TerminateProcess(Process.hProcess, 1) then
          begin
            Code := GetLastError;
            if WaitForSingleObject(Process.hProcess, 0) <> WAIT_OBJECT_0 then
              raise EOSError.CreateFmt('Falha ao encerrar OCR: %d', [Code]);
          end;
          if WaitForSingleObject(Process.hProcess, 5000) <> WAIT_OBJECT_0 then
            raise EReadError.Create('Não foi possível confirmar encerramento do OCR');
        end;
      finally CloseHandle(Process.hThread); CloseHandle(Process.hProcess); end;
    end;
  finally
    if TFile.Exists(OutputPath) then TFile.Delete(OutputPath);
  end;
end;

constructor TOcrReview.Create(const Page: TOcrPage);
begin
  inherited Create;
  if Page.Source.Trim.IsEmpty or (Page.PageNumber < 0) or Page.RecognitionIdentity.Trim.IsEmpty then
    raise EArgumentException.Create('Resultado sem proveniência');
  FPage := Page; FAccepted := False;
end;

procedure TOcrReview.AcceptText(const ReviewedText: string);
begin
  if ReviewedText.Trim.IsEmpty or (Length(ReviewedText) > 500000) then
    raise EArgumentException.Create('Texto revisado vazio ou fora do limite');
  FReviewedText := NormalizeText(ReviewedText); FAccepted := True;
end;

function TOcrReview.Document(const Access: string): TDocument;
begin
  if not FAccepted then raise EInvalidOpException.Create('Texto OCR ainda não revisado');
  if (Access <> 'operacional') and (Access <> 'supervisor') then
    raise EArgumentException.Create('Classificação desconhecida');
  Result := Default(TDocument); Result.Source := FPage.Source; Result.PageNumber := FPage.PageNumber;
  Result.Id := TPath.GetFileName(FPage.Source);
  if FPage.PageNumber > 0 then Result.Id := Result.Id + ':page:' + IntToStr(FPage.PageNumber);
  Result.Text := FReviewedText; Result.Access := Access;
  Result.WasOcrReviewed := True;
  Result.RecognitionIdentity := FPage.RecognitionIdentity;
  Result.RecognizedText := FPage.Text;
end;

end.
