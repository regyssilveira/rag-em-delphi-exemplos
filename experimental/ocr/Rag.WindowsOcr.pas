unit Rag.WindowsOcr;

interface

uses System.SysUtils, Rag.Ocr;

type
  TWindowsOcrProvider = class(TInterfacedObject, IOcrProvider)
  private
    FTimeoutMs: Cardinal;
  public
    constructor Create(TimeoutMs: Cardinal = 15000);
    function Recognize(const ImagePath, OriginalSource: string;
      PageNumber: Integer; const Cancelled: TFunc<Boolean>): TOcrPage;
  end;

function HasWindowsOcrPackageIdentity: Boolean;

implementation

uses System.Classes, System.Win.WinRT, System.Win.ComObj,
  Winapi.Windows, Winapi.WinRT, Winapi.Foundation, Winapi.Media,
  Winapi.GraphicsRT, Winapi.Storage.Streams, Winapi.CommonTypes,
  Rag.OcrImages, Rag.Ingestion;

function GetCurrentPackageFullName(var PackageFullNameLength: Cardinal;
  PackageFullName: PWideChar): Longint; stdcall;
  external 'kernel32.dll' name 'GetCurrentPackageFullName';

function HasWindowsOcrPackageIdentity: Boolean;
var PackageLength: Cardinal;
begin
  PackageLength := 0;
  Result := GetCurrentPackageFullName(PackageLength, nil) = ERROR_INSUFFICIENT_BUFFER;
end;

procedure CheckCancelled(const Cancelled: TFunc<Boolean>);
begin
  if Assigned(Cancelled) and Cancelled() then
    raise EOcrCancelled.Create('OCR nativo cancelado');
end;

function ActivateStatics(const Name: string; const Id: TGUID): IInspectable;
var ClassName: TWindowsString;
begin
  ClassName := TWindowsString.Create(Name);
  OleCheck(RoGetActivationFactory(ClassName, Id, Result));
end;

constructor TWindowsOcrProvider.Create(TimeoutMs: Cardinal);
begin
  inherited Create;
  if (TimeoutMs < 100) or (TimeoutMs > 60000) then
    raise EArgumentException.Create('Tempo limite OCR inválido');
  FTimeoutMs := TimeoutMs;
end;

function TWindowsOcrProvider.Recognize(const ImagePath,
  OriginalSource: string; PageNumber: Integer;
  const Cancelled: TFunc<Boolean>): TOcrPage;
var
  PackageLength: Cardinal;
  Pixels: TOcrBitmap;
  OcrStatics: Ocr_IOcrEngineStatics;
  BitmapStatics: Imaging_ISoftwareBitmapStatics;
  Factory: IInspectable;
  ClassName: TWindowsString;
  Writer: IDataWriter;
  Bitmap: Imaging_ISoftwareBitmap;
  Engine: Ocr_IOcrEngine;
  Operation: IAsyncOperation_1__Ocr_IOcrResult;
  Info: IAsyncInfo;
  Recognized: Ocr_IOcrResult;
  Started: UInt64;
  LanguageTag: string;
begin
  Result := Default(TOcrPage);
  CheckCancelled(Cancelled);
  if (PageNumber < 0) or OriginalSource.Trim.IsEmpty then
    raise EArgumentException.Create('Origem ou página OCR inválida');
  PackageLength := 0;
  if GetCurrentPackageFullName(PackageLength, nil) <> ERROR_INSUFFICIENT_BUFFER then
    raise EInvalidOpException.Create('OCR nativo exige aplicação com identidade de pacote MSIX');
  OleCheck(RoInitialize(RO_INIT_MULTITHREADED));
  try
    Pixels := ReadOcrImage(ImagePath, Cancelled);
    OcrStatics := ActivateStatics('Windows.Media.Ocr.OcrEngine',
      StringToGUID('{5BFFA85A-3384-3540-9940-699120D428A8}')) as Ocr_IOcrEngineStatics;
    if (Pixels.Width > Integer(OcrStatics.MaxImageDimension)) or
      (Pixels.Height > Integer(OcrStatics.MaxImageDimension)) then
      raise EArgumentException.Create('Imagem excede o limite do OCR do Windows');
    BitmapStatics := ActivateStatics('Windows.Graphics.Imaging.SoftwareBitmap',
      StringToGUID('{DF0385DB-672F-4A9D-806E-C2442F343E86}')) as Imaging_ISoftwareBitmapStatics;
    ClassName := TWindowsString.Create('Windows.Storage.Streams.DataWriter');
    OleCheck(RoActivateInstance(ClassName, Factory));
    Writer := Factory as IDataWriter;
    Writer.WriteBytes(Length(Pixels.Pixels), @Pixels.Pixels[0]);
    Bitmap := BitmapStatics.CreateCopyFromBuffer(Writer.DetachBuffer,
      Imaging_BitmapPixelFormat.Bgra8, Pixels.Width, Pixels.Height,
      Imaging_BitmapAlphaMode.Ignore);
    Engine := OcrStatics.TryCreateFromUserProfileLanguages;
    if Engine = nil then raise EInvalidOpException.Create('Idioma OCR indisponível no Windows');
    LanguageTag := TWindowsString.HStringToString(Engine.RecognizerLanguage.LanguageTag);
    CheckCancelled(Cancelled);
    Operation := Engine.RecognizeAsync(Bitmap);
    Info := Operation as IAsyncInfo;
    Started := GetTickCount64;
    while Info.Status = AsyncStatus.Started do
    begin
      if Assigned(Cancelled) and Cancelled() then
      begin
        Info.Cancel;
        raise EOcrCancelled.Create('OCR nativo cancelado');
      end;
      if GetTickCount64 - Started > FTimeoutMs then
      begin
        Info.Cancel;
        raise EOcrTimeout.Create('Tempo OCR nativo excedido');
      end;
      Sleep(10);
    end;
    CheckCancelled(Cancelled);
    if Info.Status <> AsyncStatus.Completed then
      raise EReadError.CreateFmt('OCR nativo não concluído: %d', [Ord(Info.Status)]);
    Recognized := Operation.GetResults;
    Result.Source := OriginalSource;
    Result.PageNumber := PageNumber;
    Result.Text := NormalizeText(TWindowsString.HStringToString(Recognized.Text));
    Result.RecognitionIdentity := 'windows-media-ocr|lang=' + LanguageTag +
      '|windows=' + TOSVersion.ToString;
  finally
    Recognized := nil;
    Info := nil;
    Operation := nil;
    Engine := nil;
    Bitmap := nil;
    Writer := nil;
    Factory := nil;
    BitmapStatics := nil;
    OcrStatics := nil;
    RoUninitialize;
  end;
end;

end.
