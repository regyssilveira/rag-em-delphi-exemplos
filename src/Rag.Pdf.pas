unit Rag.Pdf;

interface

uses System.SysUtils, Rag.Types;

type
  TPdfPageText = record
    PageNumber: Integer;
    Text: string;
    HasExtractedText: Boolean;
    HadUnmappedCharacters: Boolean;
  end;

function ReadPdfPages(const FileName, DllPath: string): TArray<TPdfPageText>;
function LoadPdfDocuments(const FileName, Access, DllPath: string): TArray<TDocument>;

implementation

uses System.Classes, System.IOUtils, System.SyncObjs, System.Character, Winapi.Windows, Rag.Ingestion;

type
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

initialization
  PdfiumLock := TObject.Create;
finalization
  PdfiumLock.Free;
end.
