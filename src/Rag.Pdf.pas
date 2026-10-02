unit Rag.Pdf;

interface

uses System.SysUtils, Rag.Types;

type
  TRenderedPdfPage = record
    PageNumber, Width, Height, Stride: Integer;
    Pixels: TBytes; // BGRx, primeira linha no topo; quatro bytes por pixel.
  end;

  TPdfPageText = record
    PageNumber: Integer;
    Text: string;
    HasExtractedText: Boolean;
    HadUnmappedCharacters: Boolean;
  end;

function ReadPdfPages(const FileName, DllPath: string): TArray<TPdfPageText>;
function LoadPdfDocuments(const FileName, Access, DllPath: string): TArray<TDocument>;

function RenderPdfPage(const FileName, DllPath: string; PageNumber, Dpi: Integer): TRenderedPdfPage;

implementation

uses System.Classes, System.Math, System.IOUtils, System.SyncObjs, System.Character, Winapi.Windows, Rag.Ingestion;

type
  TGetPageSize = function(Page: Pointer): Double; cdecl;
  TBitmapCreate = function(Width, Height, Alpha: Integer): Pointer; cdecl;
  TBitmapDestroy = procedure(Bitmap: Pointer); cdecl;
  TBitmapFill = function(Bitmap: Pointer; Left, Top, Width, Height: Integer; Color: Cardinal): Integer; cdecl;
  TBitmapBuffer = function(Bitmap: Pointer): Pointer; cdecl;
  TBitmapStride = function(Bitmap: Pointer): Integer; cdecl;
  TRenderBitmap = procedure(Bitmap, Page: Pointer; X, Y, Width, Height, Rotation, Flags: Integer); cdecl;
  TInitLibrary = procedure; cdecl;
  TDestroyLibrary = procedure; cdecl;
  TLoadMemDocument = function(Data: Pointer; Size: NativeUInt;
    Password: PAnsiChar): Pointer; cdecl;
  TCloseDocument = procedure(Document: Pointer); cdecl;
  TGetPageCount = function(Document: Pointer): Integer; cdecl;
  TLoadPage = function(Document: Pointer; Index: Integer): Pointer; cdecl;
  TClosePage = procedure(Page: Pointer); cdecl;
  TTextLoadPage = function(Page: Pointer): Pointer; cdecl;
  TTextClosePage = procedure(TextPage: Pointer); cdecl;
  TTextCountChars = function(TextPage: Pointer): Integer; cdecl;
  TTextGetUnicode = function(TextPage: Pointer; Index: Integer): Cardinal; cdecl;
  TGetLastError = function: Cardinal; cdecl;

var
  PdfiumLock: TObject;

const
  LoadLibrarySearchDllLoadDir = $00000100;
  LoadLibrarySearchSystem32 = $00000800;

function RequireExport(Module: HMODULE; const Name: AnsiString): Pointer;
begin
  Result := GetProcAddress(Module, PAnsiChar(Name));
  if Result = nil then
    raise EReadError.Create('PDFium sem função necessária: ' + string(Name));
end;

function ReadPdfPages(const FileName, DllPath: string): TArray<TPdfPageText>;
var
  Module: HMODULE;
  InitLibrary: TInitLibrary;
  DestroyLibrary: TDestroyLibrary;
  LoadMemDocument: TLoadMemDocument;
  CloseDocument: TCloseDocument;
  GetPageCount: TGetPageCount;
  LoadPage: TLoadPage;
  ClosePage: TClosePage;
  TextLoadPage: TTextLoadPage;
  TextClosePage: TTextClosePage;
  TextCountChars: TTextCountChars;
  TextGetUnicode: TTextGetUnicode;
  GetPdfError: TGetLastError;
  Stream: TFileStream;
  Bytes: TBytes;
  Document, Page, TextPage: Pointer;
  PageCount, PageIndex, CharacterCount, CharacterIndex, TotalCharacters: Integer;
  CodePoint: Cardinal;
  Builder: TStringBuilder;
begin
  if not TPath.IsPathRooted(DllPath) then
    raise EArgumentException.Create('Informe caminho absoluto da DLL PDFium');
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    if (Stream.Size = 0) or (Stream.Size > 128 * 1024 * 1024) then
      raise EReadError.Create('PDF vazio ou maior que 128 MiB');
    SetLength(Bytes, Integer(Stream.Size));
    Stream.ReadBuffer(Bytes[0], Length(Bytes));
  finally
    Stream.Free;
  end;
  // PDFium usa estado global. Este módulo serializa todas as suas chamadas.
  TMonitor.Enter(PdfiumLock);
  try
    Module := LoadLibraryEx(PChar(DllPath), 0,
      LoadLibrarySearchDllLoadDir or LoadLibrarySearchSystem32);
    if Module = 0 then
      raise EReadError.Create('Não foi possível carregar PDFium; confira caminho e arquitetura: ' + SysErrorMessage(GetLastError));
    try
      InitLibrary := TInitLibrary(RequireExport(Module, 'FPDF_InitLibrary'));
      DestroyLibrary := TDestroyLibrary(RequireExport(Module, 'FPDF_DestroyLibrary'));
      LoadMemDocument := TLoadMemDocument(RequireExport(Module, 'FPDF_LoadMemDocument64'));
      CloseDocument := TCloseDocument(RequireExport(Module, 'FPDF_CloseDocument'));
      GetPageCount := TGetPageCount(RequireExport(Module, 'FPDF_GetPageCount'));
      LoadPage := TLoadPage(RequireExport(Module, 'FPDF_LoadPage'));
      ClosePage := TClosePage(RequireExport(Module, 'FPDF_ClosePage'));
      TextLoadPage := TTextLoadPage(RequireExport(Module, 'FPDFText_LoadPage'));
      TextClosePage := TTextClosePage(RequireExport(Module, 'FPDFText_ClosePage'));
      TextCountChars := TTextCountChars(RequireExport(Module, 'FPDFText_CountChars'));
      TextGetUnicode := TTextGetUnicode(RequireExport(Module, 'FPDFText_GetUnicode'));
      GetPdfError := TGetLastError(RequireExport(Module, 'FPDF_GetLastError'));
      InitLibrary();
      try
        Document := LoadMemDocument(@Bytes[0], Length(Bytes), nil);
        if Document = nil then
          raise EReadError.Create('PDF não pôde ser aberto; código PDFium ' + UIntToStr(GetPdfError()));
        try
          PageCount := GetPageCount(Document);
          if (PageCount < 1) or (PageCount > 1000) then
            raise EReadError.Create('PDF fora do limite didático de 1 a 1000 páginas');
          SetLength(Result, PageCount);
          TotalCharacters := 0;
          for PageIndex := 0 to PageCount - 1 do
          begin
            Page := LoadPage(Document, PageIndex);
            if Page = nil then raise EReadError.Create('Falha ao abrir página PDF');
            try
              TextPage := TextLoadPage(Page);
              if TextPage = nil then raise EReadError.Create('Falha ao preparar texto PDF');
              try
                CharacterCount := TextCountChars(TextPage);
                if (CharacterCount < 0) or (CharacterCount > 4 * 1024 * 1024) then
                  raise EReadError.Create('Texto da página fora do limite didático');
                Inc(TotalCharacters, CharacterCount);
                if TotalCharacters > 8 * 1024 * 1024 then
                  raise EReadError.Create('Texto total do PDF excede o limite didático');
                Result[PageIndex].PageNumber := PageIndex + 1;
                Result[PageIndex].HadUnmappedCharacters := False;
                Builder := TStringBuilder.Create;
                try
                  for CharacterIndex := 0 to CharacterCount - 1 do
                  begin
                    CodePoint := TextGetUnicode(TextPage, CharacterIndex);
                    if (CodePoint = 0) or (CodePoint > $10FFFF) or
                      ((CodePoint >= $D800) and (CodePoint <= $DFFF)) then
                    begin
                      Builder.Append(Char($FFFD));
                      Result[PageIndex].HadUnmappedCharacters := True;
                    end
                    else
                      Builder.Append(Char.ConvertFromUtf32(CodePoint));
                  end;
                  Result[PageIndex].Text := NormalizeText(Builder.ToString);
                  Result[PageIndex].HasExtractedText := Trim(Result[PageIndex].Text) <> '';
                finally
                  Builder.Free;
                end;
              finally
                TextClosePage(TextPage);
              end;
            finally
              ClosePage(Page);
            end;
          end;
        finally
          CloseDocument(Document);
        end;
      finally
        DestroyLibrary();
      end;
    finally
      FreeLibrary(Module);
    end;
  finally
    TMonitor.Exit(PdfiumLock);
  end;
end;

function LoadPdfDocuments(const FileName, Access, DllPath: string): TArray<TDocument>;
var
  Pages: TArray<TPdfPageText>;
  I: Integer;
begin
  Pages := ReadPdfPages(FileName, DllPath);
  SetLength(Result, Length(Pages));
  for I := 0 to High(Pages) do
  begin
    if Pages[I].HadUnmappedCharacters then
      raise EReadError.Create('PDF contém caracteres sem mapeamento Unicode; confira a página ' + IntToStr(Pages[I].PageNumber));
    Result[I].Id := TPath.GetFileName(FileName) + ':page:' + IntToStr(Pages[I].PageNumber);
    Result[I].Source := TPath.GetFullPath(FileName);
    Result[I].Text := Pages[I].Text;
    Result[I].Access := Access;
    Result[I].PageNumber := Pages[I].PageNumber;
  end;
end;

function RenderPdfPage(const FileName, DllPath: string; PageNumber, Dpi: Integer): TRenderedPdfPage;
var Module: HMODULE; Bytes: TBytes; Stream: TFileStream;
  InitLibrary: TInitLibrary; DestroyLibrary: TDestroyLibrary;
  LoadDocument: TLoadMemDocument; CloseDocument: TCloseDocument;
  CountPages: TGetPageCount; LoadPage: TLoadPage; ClosePage: TClosePage;
  PageWidth, PageHeight: TGetPageSize; CreateBitmap: TBitmapCreate;
  DestroyBitmap: TBitmapDestroy; FillBitmap: TBitmapFill;
  Buffer: TBitmapBuffer; Stride: TBitmapStride; Render: TRenderBitmap;
  Document, Page, Bitmap, Data: Pointer; WidthPoints, HeightPoints: Double;
  Count: Integer; ByteCount: Int64;
begin
  Result := Default(TRenderedPdfPage);
  if not TPath.IsPathRooted(DllPath) then raise EArgumentException.Create('Informe DLL absoluta');
  if (PageNumber < 1) or (Dpi < 72) or (Dpi > 300) then
    raise EArgumentException.Create('Página ou resolução fora do limite');
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    if (Stream.Size < 1) or (Stream.Size > 128 * 1024 * 1024) then
      raise EReadError.Create('PDF vazio ou maior que 128 MiB');
    SetLength(Bytes, Integer(Stream.Size)); Stream.ReadBuffer(Bytes[0], Length(Bytes));
  finally Stream.Free; end;
  TMonitor.Enter(PdfiumLock);
  try
    Module := LoadLibraryEx(PChar(DllPath), 0, LoadLibrarySearchDllLoadDir or LoadLibrarySearchSystem32);
    if Module = 0 then raise EReadError.Create('Não foi possível carregar PDFium');
    try
      InitLibrary := TInitLibrary(RequireExport(Module, 'FPDF_InitLibrary'));
      DestroyLibrary := TDestroyLibrary(RequireExport(Module, 'FPDF_DestroyLibrary'));
      LoadDocument := TLoadMemDocument(RequireExport(Module, 'FPDF_LoadMemDocument64'));
      CloseDocument := TCloseDocument(RequireExport(Module, 'FPDF_CloseDocument'));
      CountPages := TGetPageCount(RequireExport(Module, 'FPDF_GetPageCount'));
      LoadPage := TLoadPage(RequireExport(Module, 'FPDF_LoadPage'));
      ClosePage := TClosePage(RequireExport(Module, 'FPDF_ClosePage'));
      PageWidth := TGetPageSize(RequireExport(Module, 'FPDF_GetPageWidth'));
      PageHeight := TGetPageSize(RequireExport(Module, 'FPDF_GetPageHeight'));
      CreateBitmap := TBitmapCreate(RequireExport(Module, 'FPDFBitmap_Create'));
      DestroyBitmap := TBitmapDestroy(RequireExport(Module, 'FPDFBitmap_Destroy'));
      FillBitmap := TBitmapFill(RequireExport(Module, 'FPDFBitmap_FillRect'));
      Buffer := TBitmapBuffer(RequireExport(Module, 'FPDFBitmap_GetBuffer'));
      Stride := TBitmapStride(RequireExport(Module, 'FPDFBitmap_GetStride'));
      Render := TRenderBitmap(RequireExport(Module, 'FPDF_RenderPageBitmap'));
      InitLibrary();
      try
        Document := LoadDocument(@Bytes[0], Length(Bytes), nil);
        if Document = nil then raise EReadError.Create('PDF não pôde ser aberto');
        try
          Count := CountPages(Document);
          if (Count < 1) or (Count > 1000) or (PageNumber > Count) then
            raise EReadError.Create('Página inexistente ou quantidade fora do limite');
          Page := LoadPage(Document, PageNumber - 1);
          if Page = nil then raise EReadError.Create('Falha ao abrir página');
          try
            WidthPoints := PageWidth(Page); HeightPoints := PageHeight(Page);
            if IsNan(WidthPoints) or IsInfinite(WidthPoints) or IsNan(HeightPoints) or IsInfinite(HeightPoints)
              or (WidthPoints <= 0) or (HeightPoints <= 0)
              or (WidthPoints > 10000 * 72 / Dpi) or (HeightPoints > 10000 * 72 / Dpi) then
              raise EReadError.Create('Dimensões da página fora do limite');
            Result.Width := Ceil(WidthPoints * Dpi / 72);
            Result.Height := Ceil(HeightPoints * Dpi / 72);
            if Int64(Result.Width) * Result.Height > 20000000 then
              raise EReadError.Create('Imagem excede vinte milhões de pixels');
            Bitmap := CreateBitmap(Result.Width, Result.Height, 0);
            if Bitmap = nil then raise EReadError.Create('Falha ao criar bitmap PDF');
            try
              if FillBitmap(Bitmap, 0, 0, Result.Width, Result.Height, $FFFFFFFF) = 0 then
                raise EReadError.Create('Falha ao preencher fundo');
              Render(Bitmap, Page, 0, 0, Result.Width, Result.Height, 0, 1);
              Result.Stride := Stride(Bitmap); Data := Buffer(Bitmap);
              ByteCount := Int64(Result.Stride) * Result.Height;
              if (Data = nil) or (Result.Stride < Result.Width * 4) or (ByteCount > 80000000) then
                raise EReadError.Create('Buffer de imagem fora do limite');
              SetLength(Result.Pixels, Integer(ByteCount));
              Move(Data^, Result.Pixels[0], Integer(ByteCount));
              Result.PageNumber := PageNumber;
            finally DestroyBitmap(Bitmap); end;
          finally ClosePage(Page); end;
        finally CloseDocument(Document); end;
      finally DestroyLibrary(); end;
    finally FreeLibrary(Module); end;
  finally TMonitor.Exit(PdfiumLock); end;
end;

initialization
  PdfiumLock := TObject.Create;
finalization
  PdfiumLock.Free;
end.
