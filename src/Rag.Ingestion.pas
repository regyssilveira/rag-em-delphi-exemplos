unit Rag.Ingestion;

interface

uses System.SysUtils;

function NormalizeText(const Value: string): string;
function ReadUtf8Text(const FileName: string): string;
function ReadDocxText(const FileName: string): string;

implementation

uses
  System.Classes, System.IOUtils, System.Zip, System.Win.ComObj,
  Winapi.ActiveX, Winapi.Windows, Winapi.msxml;

const
  MaxTextBytes = 16 * 1024 * 1024;
  WordNamespace = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

function NormalizeText(const Value: string): string;
begin
  Result := StringReplace(Value, #13#10, #10, [rfReplaceAll]);
  Result := StringReplace(Result, #13, #10, [rfReplaceAll]);
end;

function DecodeUtf8(const Bytes: TBytes): string;
var
  CharacterCount: Integer;
begin
  if Length(Bytes) = 0 then Exit('');
  CharacterCount := MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
    PAnsiChar(@Bytes[0]), Length(Bytes), nil, 0);
  if CharacterCount = 0 then
    raise EConvertError.Create('Arquivo não contém UTF-8 válido');
  SetLength(Result, CharacterCount);
  if MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
    PAnsiChar(@Bytes[0]), Length(Bytes), PChar(Result), CharacterCount) = 0 then
    RaiseLastOSError;
  if (Length(Result) > 0) and (Result[1] = #$FEFF) then
    Delete(Result, 1, 1);
  if Pos(#0, Result) > 0 then
    raise EConvertError.Create('Texto contém caractere nulo');
  Result := NormalizeText(Result);
end;

function ReadLimited(Stream: TStream): TBytes;
var
  Buffer: array[0..8191] of Byte;
  Count, PreviousLength: Integer;
begin
  Result := nil;
  repeat
    Count := Stream.Read(Buffer, SizeOf(Buffer));
    PreviousLength := Length(Result);
    if PreviousLength + Count > MaxTextBytes then
      raise EReadError.Create('Texto excede o limite de 16 MiB');
    SetLength(Result, PreviousLength + Count);
    if Count > 0 then
      Move(Buffer[0], Result[PreviousLength], Count);
  until Count = 0;
end;

function ReadUtf8Text(const FileName: string): string;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    if Stream.Size > MaxTextBytes then
      raise EReadError.Create('Arquivo textual excede o limite de 16 MiB');
    Result := DecodeUtf8(ReadLimited(Stream));
  finally
    Stream.Free;
  end;
end;

function ParagraphText(const Paragraph: IXMLDOMNode): string;
var
  Nodes: IXMLDOMNodeList;
  Node: IXMLDOMNode;
  I: Integer;
begin
  Result := '';
  Nodes := Paragraph.selectNodes('.//w:t | .//w:tab | .//w:br');
  for I := 0 to Nodes.length - 1 do
  begin
    Node := Nodes.item[I];
    if Node.baseName = 't' then
      Result := Result + Node.text
    else if Node.baseName = 'tab' then
      Result := Result + #9
    else
      Result := Result + #10;
  end;
end;

function ExtractBody(const Document: IXMLDOMDocument2): string;
var
  Body, Block, Row, Cell: IXMLDOMNode;
  Blocks, Rows, Cells, Paragraphs: IXMLDOMNodeList;
  Lines: TStringList;
  I, J, K, P: Integer;
  RowText, CellText: string;
begin
  Body := Document.selectSingleNode('/w:document/w:body');
  if Body = nil then
    raise EReadError.Create('DOCX sem corpo WordprocessingML suportado');
  if Document.selectNodes('//w:ins | //w:del | //w:moveFrom | //w:moveTo | //w:drawing | //w:pict | //w:altChunk | //w:fldChar | //w:instrText | //w:fldSimple | //w:gridSpan | //w:vMerge | //w:sdt | //w:footnoteReference | //w:endnoteReference').length > 0 then
    raise EReadError.Create('DOCX contém elementos fora do escopo: imagens, revisões, campos, controles, notas ou células mescladas');
  if Document.selectNodes('//w:tbl//w:tbl').length > 0 then
    raise EReadError.Create('Tabelas aninhadas não são suportadas');
  Lines := TStringList.Create;
  try
    Blocks := Body.childNodes;
    for I := 0 to Blocks.length - 1 do
    begin
      Block := Blocks.item[I];
      if Block.nodeType <> NODE_ELEMENT then Continue;
      if Block.namespaceURI <> WordNamespace then
        raise EReadError.Create('Elemento de outro namespace no corpo');
      if Block.baseName = 'p' then
        Lines.Add(ParagraphText(Block))
      else if Block.baseName = 'tbl' then
      begin
        Rows := Block.selectNodes('w:tr');
        for J := 0 to Rows.length - 1 do
        begin
          Row := Rows.item[J];
          Cells := Row.selectNodes('w:tc');
          RowText := '';
          for K := 0 to Cells.length - 1 do
          begin
            Cell := Cells.item[K];
            Paragraphs := Cell.selectNodes('w:p');
            CellText := '';
            for P := 0 to Paragraphs.length - 1 do
            begin
              if P > 0 then CellText := CellText + ' / ';
              CellText := CellText + ParagraphText(Paragraphs.item[P]);
            end;
            if K > 0 then RowText := RowText + #9;
            RowText := RowText + CellText;
          end;
          Lines.Add(RowText);
        end;
      end
      else if Block.baseName <> 'sectPr' then
        raise EReadError.Create('Bloco DOCX fora do escopo: ' + Block.baseName);
    end;
    Result := NormalizeText(Lines.Text);
  finally
    Lines.Free;
  end;
end;

function ParseDocxXml(const Bytes: TBytes): string;
var
  Document: IXMLDOMDocument2;
begin
  Document := CreateComObject(CLASS_DOMDocument60) as IXMLDOMDocument2;
  Document.async := False;
  Document.validateOnParse := False;
  Document.resolveExternals := False;
  Document.preserveWhiteSpace := True;
  Document.setProperty('ProhibitDTD', True);
  Document.setProperty('SelectionLanguage', 'XPath');
  Document.setProperty('SelectionNamespaces', 'xmlns:w="' + WordNamespace + '"');
  if not Document.loadXML(DecodeUtf8(Bytes)) then
    raise EReadError.Create('XML inválido no DOCX: ' + Document.parseError.reason);
  Result := ExtractBody(Document);
end;

function ReadDocxText(const FileName: string): string;
var
  Archive: TZipFile;
  EntryIndex: Integer;
  Stream: TStream;
  Header: TZipHeader;
  Bytes: TBytes;
  ComInitialization: HRESULT;
begin
  Archive := TZipFile.Create;
  try
    Archive.Open(FileName, zmRead);
    EntryIndex := Archive.IndexOf('word/document.xml');
    if EntryIndex < 0 then
      raise EReadError.Create('DOCX sem word/document.xml; pacote não suportado');
    if Archive.FileInfo[EntryIndex].UncompressedSize64 > MaxTextBytes then
      raise EReadError.Create('XML do DOCX excede 16 MiB');
    Archive.Read(EntryIndex, Stream, Header, True);
    try
      Bytes := ReadLimited(Stream);
    finally
      Stream.Free;
    end;
  finally
    Archive.Free;
  end;
  ComInitialization := CoInitializeEx(nil, COINIT_APARTMENTTHREADED);
  if Failed(ComInitialization) and (ComInitialization <> RPC_E_CHANGED_MODE) then
    OleCheck(ComInitialization);
  try
    // A função auxiliar libera todas as interfaces COM antes deste finally.
    Result := ParseDocxXml(Bytes);
  finally
    if Succeeded(ComInitialization) then CoUninitialize;
  end;
end;

end.
