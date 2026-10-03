unit Rag.OcrImages;
interface
uses System.SysUtils;
type
  TOcrBitmap = record
    Width, Height, Stride: Integer;
    Pixels: TBytes;
  end;
function ReadOcrImage(const FileName: string; const Cancelled: TFunc<Boolean> = nil): TOcrBitmap;
procedure SaveOcrBitmap(const FileName: string; const Bitmap: TOcrBitmap);
implementation
uses System.Classes, Winapi.Windows, Winapi.ActiveX, Winapi.Wincodec,
  System.Win.ComObj, Rag.Ocr;
procedure CheckCancelled(const Cancelled: TFunc<Boolean>);
begin
  if Assigned(Cancelled) and Cancelled() then raise EOcrCancelled.Create('Leitura de imagem cancelada');
end;
procedure CheckJpegOrientation(Frame: IWICBitmapFrameDecode);
var Reader: IWICMetadataQueryReader; Value: TPropVariant; Status: HRESULT;
begin
  OleCheck(Frame.GetMetadataQueryReader(Reader));
  Value := Default(TPropVariant);
  try
    Status := Reader.GetMetadataByName('/app1/ifd/{ushort=274}', Value);
    if Cardinal(Status) = WINCODEC_ERR_PROPERTYNOTFOUND then Exit;
    OleCheck(Status);
    if (Value.vt <> VT_UI2) or (Value.uiVal <> 1) then
      raise EReadError.Create('Salve o JPEG com os pixels na orientação de leitura antes de importar');
  finally PropVariantClear(Value); end;
end;
function DecodeImage(const FileName: string; const Cancelled: TFunc<Boolean>): TOcrBitmap;
var Factory: IWICImagingFactory; Decoder: IWICBitmapDecoder; Frame: IWICBitmapFrameDecode;
  Converter: IWICFormatConverter; Info: IWICBitmapDecoderInfo;
  Container, Vendor: TGUID; Width, Height, Count: UINT; Offset, Channel, Alpha: Integer;
begin
  Result := Default(TOcrBitmap);
  OleCheck(CoCreateInstance(CLSID_WICImagingFactory, nil, CLSCTX_INPROC_SERVER,
    IID_IWICImagingFactory, Factory));
  OleCheck(Factory.CreateDecoderFromFilename(PChar(FileName), GUID_VendorMicrosoft,
    GENERIC_READ, WICDecodeMetadataCacheOnDemand, Decoder));
  OleCheck(Decoder.GetDecoderInfo(Info)); OleCheck(Info.GetVendorGUID(Vendor));
  if not IsEqualGUID(Vendor, GUID_VendorMicrosoft)
    and not IsEqualGUID(Vendor, GUID_VendorMicrosoftBuiltIn) then
    raise EReadError.Create('Codec de imagem não pertence ao percurso nativo validado');
  OleCheck(Decoder.GetContainerFormat(Container));
  if not IsEqualGUID(Container, GUID_ContainerFormatPng)
    and not IsEqualGUID(Container, GUID_ContainerFormatJpeg)
    and not IsEqualGUID(Container, GUID_ContainerFormatBmp) then
    raise EReadError.Create('Use PNG, JPEG ou BMP');
  OleCheck(Decoder.GetFrameCount(Count));
  if Count <> 1 then raise EReadError.Create('Imagem com múltiplos quadros não suportada');
  OleCheck(Decoder.GetFrame(0, Frame)); OleCheck(Frame.GetSize(Width, Height));
  if (Width = 0) or (Height = 0) or (Width > 10000) or (Height > 10000)
    or (UInt64(Width) * Height > 20000000) then
    raise EReadError.Create('Imagem excede dimensões ou vinte milhões de pixels');
  if IsEqualGUID(Container, GUID_ContainerFormatJpeg) then CheckJpegOrientation(Frame);
  CheckCancelled(Cancelled);
  Result.Width := Width; Result.Height := Height; Result.Stride := Width * 4;
  SetLength(Result.Pixels, Result.Stride * Result.Height);
  OleCheck(Factory.CreateFormatConverter(Converter));
  OleCheck(Converter.Initialize(Frame, GUID_WICPixelFormat32bppBGRA,
    WICBitmapDitherTypeNone, nil, 0, WICBitmapPaletteTypeCustom));
  OleCheck(Converter.CopyPixels(nil, Result.Stride, Length(Result.Pixels), @Result.Pixels[0]));
  CheckCancelled(Cancelled);
  Offset := 0;
  while Offset < Length(Result.Pixels) do
  begin
    if Offset mod (Result.Stride * 32) = 0 then CheckCancelled(Cancelled);
    Alpha := Result.Pixels[Offset + 3];
    for Channel := 0 to 2 do
      Result.Pixels[Offset + Channel] :=
        (Integer(Result.Pixels[Offset + Channel]) * Alpha + 255 * (255 - Alpha) + 127) div 255;
    Result.Pixels[Offset + 3] := 255; Inc(Offset, 4);
  end;
end;
function ReadOcrImage(const FileName: string; const Cancelled: TFunc<Boolean>): TOcrBitmap;
var Stream: TFileStream; Status: HRESULT; OwnCom: Boolean;
begin
  CheckCancelled(Cancelled);
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    if (Stream.Size = 0) or (Stream.Size > 64 * 1024 * 1024) then
      raise EReadError.Create('Imagem vazia ou maior que 64 MiB');
    Status := CoInitializeEx(nil, COINIT_MULTITHREADED);
    OwnCom := (Status = S_OK) or (Status = S_FALSE);
    if not OwnCom and (Status <> RPC_E_CHANGED_MODE) then OleCheck(Status);
    try
      // Interfaces are released by DecodeImage before balancing COM initialization.
      Result := DecodeImage(FileName, Cancelled);
    finally if OwnCom then CoUninitialize; end;
  finally Stream.Free; end;
end;
procedure SaveOcrBitmap(const FileName: string; const Bitmap: TOcrBitmap);
var Header: TBitmapFileHeader; Info: TBitmapInfoHeader; Stream: TFileStream;
begin
  if (Bitmap.Width <= 0) or (Bitmap.Height <= 0) or (Bitmap.Width > 10000)
    or (Bitmap.Height > 10000) or (Int64(Bitmap.Width) * Bitmap.Height > 20000000)
    or (Bitmap.Stride <> Bitmap.Width * 4)
    or (Length(Bitmap.Pixels) <> Int64(Bitmap.Stride) * Bitmap.Height) then
    raise EArgumentException.Create('Bitmap de OCR inválido');
  Header := Default(TBitmapFileHeader); Info := Default(TBitmapInfoHeader);
  Header.bfType := $4D42; Header.bfOffBits := SizeOf(Header) + SizeOf(Info);
  Header.bfSize := Header.bfOffBits + Cardinal(Length(Bitmap.Pixels));
  Info.biSize := SizeOf(Info); Info.biWidth := Bitmap.Width; Info.biHeight := -Bitmap.Height;
  Info.biPlanes := 1; Info.biBitCount := 32; Info.biCompression := BI_RGB;
  Info.biSizeImage := Length(Bitmap.Pixels);
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    Stream.WriteBuffer(Header, SizeOf(Header)); Stream.WriteBuffer(Info, SizeOf(Info));
    Stream.WriteBuffer(Bitmap.Pixels[0], Length(Bitmap.Pixels));
  finally Stream.Free; end;
end;
end.
