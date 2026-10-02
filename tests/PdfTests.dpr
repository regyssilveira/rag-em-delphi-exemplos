program PdfTests;

{$APPTYPE CONSOLE}

uses System.SysUtils, System.IOUtils, Rag.Types, Rag.Core, Rag.Pdf;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then raise Exception.Create('FALHOU: ' + MessageText);
  Writeln('OK: ', MessageText);
end;

procedure CheckRejected(const FileName, DllPath, ExpectedMessage: string);
var Pages: TArray<TPdfPageText>; Rejected: Boolean;
begin
  Rejected := False;
  try
    Pages := ReadPdfPages(FileName, DllPath);
  except
    on Error: Exception do
      if Pos(ExpectedMessage, Error.Message) > 0 then Rejected := True
      else raise;
  end;
  Check(Rejected, 'rejeição explícita: ' + ExpectedMessage);
end;

var
  DllPath, FixturePath, DigitalFile, MixedFile, UnicodeFile: string;
  Pages: TArray<TPdfPageText>;
  Documents: TArray<TDocument>;
  Chunks: TArray<TChunk>;
begin
  try
    if ParamCount <> 2 then raise Exception.Create('Informe DLL absoluta e pasta fixtures/pdf');
    DllPath := ParamStr(1);
    FixturePath := ParamStr(2);
    DigitalFile := TPath.Combine(FixturePath, 'digital.pdf');
    MixedFile := TPath.Combine(FixturePath, 'mixed.pdf');
    Pages := ReadPdfPages(DigitalFile, DllPath);
    Check(Length(Pages) = 2, 'PDF digital tem duas páginas');
    Check(Pages[0].PageNumber = 1, 'primeira página numerada em 1');
    Check(Pages[1].PageNumber = 2, 'segunda página numerada em 2');
    Check(Pos('divergência', Pages[0].Text) > 0, 'acentos da página 1 preservados');
    Check(Pos('não retornam automaticamente', Pages[1].Text) > 0, 'negação da página 2 preservada');
    Check(Pages[0].HasExtractedText and Pages[1].HasExtractedText, 'páginas digitais contêm texto');
    Check(not Pages[0].HadUnmappedCharacters and not Pages[1].HadUnmappedCharacters, 'mapeamento Unicode válido no fixture');
    Documents := LoadPdfDocuments(DigitalFile, 'operacional', DllPath);
    Check(Documents[1].PageNumber = 2, 'documento mantém página física');
    Check(Documents[0].Id <> Documents[1].Id, 'páginas têm identidades distintas');
    Check(Documents[1].Source = TPath.GetFullPath(DigitalFile), 'fonte aponta ao arquivo original');
    Chunks := SplitDocument(Documents[1], 100, 20);
    Check((Length(Chunks) > 0) and (Chunks[0].PageNumber = 2), 'trecho herda página de origem');
    Pages := ReadPdfPages(MixedFile, DllPath);
    Check(Length(Pages) = 3, 'PDF misto mantém três páginas');
    Check(Pages[0].HasExtractedText, 'página textual identificada');
    Check((not Pages[1].HasExtractedText) and (Pages[1].Text = ''), 'imagem não inventa camada textual');
    Check((not Pages[2].HasExtractedText) and (Pages[2].Text = ''), 'página branca permanece sem texto');
    UnicodeFile := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'café-测试.pdf');
    TFile.Copy(DigitalFile, UnicodeFile, True);
    Pages := ReadPdfPages(UnicodeFile, DllPath);
    Check(Length(Pages) = 2, 'caminho Unicode funciona por leitura em memória');
    CheckRejected(DigitalFile, 'pdfium.dll', 'caminho absoluto');
    CheckRejected(DigitalFile, TPath.Combine(TPath.GetDirectoryName(DllPath), 'absent.dll'), 'carregar PDFium');
    CheckRejected(TPath.Combine(FixturePath, 'encrypted.pdf'), DllPath, 'código PDFium');
    CheckRejected(TPath.Combine(TPath.GetDirectoryName(FixturePath), 'unsupported.pdf'), DllPath, 'código PDFium');
    Pages := ReadPdfPages(DigitalFile, DllPath);
    Check(Length(Pages) = 2, 'leitor continua utilizável após erros');
    Writeln('TODAS AS VERIFICAÇÕES PDF PASSARAM');
  except
    on Error: Exception do begin Writeln(Error.Message); ExitCode := 1; end;
  end;
end.
