program OcrImageTests;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.Classes, System.IOUtils, Rag.Ocr, Rag.OcrImages;
var Checks: Integer;
procedure Check(Value: Boolean; const MessageText: string);
begin
  if not Value then raise Exception.Create(MessageText);
  Inc(Checks); Writeln('OK: ', MessageText);
end;
procedure Reject(const Path, Expected: string);
var Failed: Boolean; Bitmap: TOcrBitmap;
begin
  Failed := False;
  try Bitmap := ReadOcrImage(Path);
  except on E: Exception do Failed := E.Message.Contains(Expected); end;
  Check(Failed, 'recusa ' + Expected);
end;
var Fixture, Folder, Preview, Large: string; Png, Jpeg, Bmp, Alpha, Reopened: TOcrBitmap;
  Stream: TFileStream; Cancelled: Boolean;
begin
  try
    if ParamCount <> 2 then raise Exception.Create('Informe fixtures e pasta gravável');
    Fixture := ParamStr(1); Folder := ParamStr(2);
    Png := ReadOcrImage(TPath.Combine(Fixture, 'ocr-reference.png'));
    Jpeg := ReadOcrImage(TPath.Combine(Fixture, 'ocr-reference.jpg'));
    Bmp := ReadOcrImage(TPath.Combine(Fixture, 'ocr-reference.bmp'));
    Check((Png.Width = Bmp.Width) and (Png.Height = Bmp.Height)
      and CompareMem(@Png.Pixels[0], @Bmp.Pixels[0], Length(Png.Pixels)), 'PNG e BMP preservam pixels opacos');
    Check((Jpeg.Width = Png.Width) and (Jpeg.Height = Png.Height), 'JPEG preserva dimensões');
    Check((Png.Stride = Png.Width * 4) and (Length(Png.Pixels) = Png.Stride * Png.Height), 'buffer limitado de quatro bytes por pixel');
    Alpha := ReadOcrImage(TPath.Combine(Fixture, 'alpha.png'));
    Check((Alpha.Pixels[0] = 255) and (Alpha.Pixels[1] = 255)
      and (Alpha.Pixels[2] = 255) and (Alpha.Pixels[3] = 255), 'transparência total sobre branco');
    Check((Alpha.Pixels[4] = 127) and (Alpha.Pixels[5] = 152)
      and (Alpha.Pixels[6] = 177) and (Alpha.Pixels[7] = 255), 'transparência parcial sobre branco');
    Preview := TPath.Combine(Folder, 'image-test-' + TGUID.NewGuid.ToString + '.bmp');
    try
      SaveOcrBitmap(Preview, Png); Reopened := ReadOcrImage(Preview);
      Check((Reopened.Width = Png.Width) and (Reopened.Height = Png.Height)
        and CompareMem(@Png.Pixels[0], @Reopened.Pixels[0], Length(Png.Pixels)), 'prévia BMP conserva orientação e pixels');
    finally if TFile.Exists(Preview) then TFile.Delete(Preview); end;
    Reject(TPath.Combine(Fixture, 'unsupported.gif'), 'Use PNG, JPEG ou BMP');
    Reject(TPath.Combine(Fixture, 'rotated.jpg'), 'orientação de leitura');
    Reject(TPath.Combine(Fixture, 'too-wide.png'), 'vinte milhões de pixels');
    Reject(TPath.Combine(Fixture, 'too-many-pixels.png'), 'vinte milhões de pixels');
    Reject(TPath.Combine(Fixture, 'empty.png'), 'Imagem vazia');
    Cancelled := False;
    try Png := ReadOcrImage(TPath.Combine(Fixture, 'ocr-reference.png'),
      function: Boolean begin Result := True; end);
    except on E: EOcrCancelled do Cancelled := True; end;
    Check(Cancelled, 'cancelamento antes da leitura');
    Large := TPath.Combine(Folder, 'image-limit-' + TGUID.NewGuid.ToString + '.png');
    try
      Stream := TFileStream.Create(Large, fmCreate);
      try Stream.Size := 64 * 1024 * 1024 + 1; finally Stream.Free; end;
      Reject(Large, 'maior que 64 MiB');
    finally if TFile.Exists(Large) then TFile.Delete(Large); end;
    Writeln('CHECKS=', Checks);
  except on E: Exception do begin Writeln(E.ClassName, ': ', E.Message); ExitCode := 1; end; end;
end.
