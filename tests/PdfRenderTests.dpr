program PdfRenderTests;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.Classes, System.IOUtils
  , Winapi.Windows, Rag.Pdf;

procedure WriteBitmap(const FileName: string; const
  Page: TRenderedPdfPage);
var Stream: TFileStream; Header: TBitmapFileHeader;
  Info: TBitmapInfoHeader;
begin

  Header := Default(TBitmapFileHeader); Info :=
    Default(TBitmapInfoHeader);
  Header.bfType := $4D42; Header.bfOffBits := SizeOf
    (Header) + SizeOf(Info);
  Header.bfSize := Header.bfOffBits + Cardinal(
    Length(Page.Pixels));
  Info.biSize := SizeOf(Info); Info.biWidth :=
    Page.Width; Info.biHeight := -Page.Height;
  Info.biPlanes := 1; Info.biBitCount := 32;
    Info.biCompression := BI_RGB;
  Info.biSizeImage := Length(Page.Pixels);
  Stream := TFileStream.Create(FileName, fmCreate);
  try

    Stream.WriteBuffer(Header, SizeOf(Header));
      Stream.WriteBuffer(Info, SizeOf(Info));
    Stream.WriteBuffer(Page.Pixels[0], Length(
      Page.Pixels));
  finally Stream.Free; end;
end;

procedure CheckOutputPaths(const PdfPath, DllPath,
  OutputPath: string);
var Destination, ProtectedPath: string;
begin

  for Destination in TArray<string>.Create(
    OutputPath, OutputPath + '-blank.bmp') do
    for ProtectedPath in TArray<string>.Create(
      PdfPath, DllPath,
      TPath.Combine(TPath.GetDirectoryName(PdfPath),
        'encrypted.pdf')) do
      if SameFileName(TPath.GetFullPath(Destination)
        ,
        TPath.GetFullPath(ProtectedPath)) then
        raise EArgumentException.Create(
          'Saída não pode substituir ' + 'entrada');
end;

var Page: TRenderedPdfPage; Rejected: Boolean; I:
  Integer;
begin

  try

    if ParamCount <> 3 then raise Exception.Create(
      'Informe PDF, DLL e saída ' + 'BMP');
    CheckOutputPaths(ParamStr(1), ParamStr(2),
      ParamStr(3));
    Page := RenderPdfPage(ParamStr(1), ParamStr(2),
      2, 200);
    if (Page.PageNumber <> 2) or (Page.Width <= 0)
      or (Page.Height <= 0)
      or (Length(Page.Pixels) <> Page.Stride *
        Page.Height) then
      raise Exception.Create('Imagem inconsistente')
        ;
    WriteBitmap(ParamStr(3), Page);
    Rejected := False;
    try RenderPdfPage(ParamStr(1), ParamStr(2), 0,
      200);
    except on E: EArgumentException do Rejected :=
      True; end;
    if not Rejected then raise Exception.Create(
      'Página zero aceita');
    Rejected := False;
    try RenderPdfPage(ParamStr(1), ParamStr(2), 1,
      301);
    except on E: EArgumentException do Rejected :=
      True; end;
    if not Rejected then raise Exception.Create(
      'Resolução inválida aceita');
    Rejected := False;
    try RenderPdfPage(ParamStr(1), ParamStr(2), 1001
      , 200);
    except on E: EReadError do Rejected := True; end
      ;
    if not Rejected then raise Exception.Create(
      'Página inexistente aceita');
    Page := RenderPdfPage(ParamStr(1), ParamStr(2),
      3, 200);
    for I := 0 to High(Page.Pixels) do
      if (I mod 4 <> 3) and (Page.Pixels[I] <> 255)
        then
        raise Exception.Create(
          'Página branca contém ' + 'pixel colorido'
          );
    WriteBitmap(ParamStr(3) + '-blank.bmp', Page);
    Rejected := False;
    try RenderPdfPage(TPath.Combine(
      TPath.GetDirectoryName(ParamStr(1)),
      'encrypted.pdf'), ParamStr(2), 1, 200);
    except on E: EReadError do Rejected := True; end
      ;
    if not Rejected then raise Exception.Create(
      'PDF protegido aceito sem ' + 'senha');
    Writeln('OK: imagem consistente, ' +
      'página branca e quatro ' +
      'entradas inválidas ' + 'recusadas');
  except on E: Exception do begin Writeln(E.Message)
    ; ExitCode := 1; end; end;
end.
