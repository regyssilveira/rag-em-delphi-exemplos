unit Rag.Import;

interface

uses System.SysUtils, Rag.Types;

function MergeImportedDocuments(const Existing: TArray<TDocument>;
  const FileNames: TArray<string>; const Access, PdfiumPath: string): TArray<TDocument>;
function RemoveDocumentSource(const Existing: TArray<TDocument>;
  const SourcePath: string): TArray<TDocument>;

implementation

uses System.Classes, System.IOUtils, System.Generics.Collections, System.Generics.Defaults,
  Rag.Core, Rag.Pdf;

function SameSource(const Left, Right: string): Boolean;
begin
  Result := IEqualityComparer<string>(TIStringComparer.Ordinal).Equals(
    TPath.GetFullPath(Left), TPath.GetFullPath(Right));
end;

function RemoveDocumentSource(const Existing: TArray<TDocument>;
  const SourcePath: string): TArray<TDocument>;
var Documents: TList<TDocument>; Document: TDocument;
begin
  if SourcePath.Trim.IsEmpty then raise EArgumentException.Create('Origem ausente');
  Documents := TList<TDocument>.Create;
  try
    for Document in Existing do
      if not SameSource(Document.Source, SourcePath) then Documents.Add(Document);
    Result := Documents.ToArray;
  finally Documents.Free; end;
end;

function MergeImportedDocuments(const Existing: TArray<TDocument>;
  const FileNames: TArray<string>; const Access, PdfiumPath: string): TArray<TDocument>;
var Documents: TList<TDocument>; InputPaths, Ids: TDictionary<string, Boolean>;
  FileName, FullPath: string; Imported: TArray<TDocument>; Document: TDocument;
  I: Integer;
begin
  if (Access <> 'operacional') and (Access <> 'supervisor') then
    raise EArgumentException.Create('Classificação de acesso desconhecida');
  if (Length(FileNames) = 0) or (Length(FileNames) > 500) or (Length(Existing) > 10000) then
    raise EArgumentException.Create('Quantidade de documentos fora dos limites');
  Documents := TList<TDocument>.Create;
  InputPaths := TDictionary<string, Boolean>.Create(TIStringComparer.Ordinal);
  Ids := TDictionary<string, Boolean>.Create(TIStringComparer.Ordinal);
  try
    Documents.AddRange(Existing);
    for FileName in FileNames do
    begin
      FullPath := TPath.GetFullPath(FileName);
      if InputPaths.ContainsKey(FullPath) then
        raise EArgumentException.Create('Mesmo arquivo selecionado mais de uma vez');
      InputPaths.Add(FullPath, True);
      if SameText(TPath.GetExtension(FullPath), '.pdf') then
        Imported := LoadPdfDocuments(FullPath, Access, PdfiumPath)
      else
      begin
        SetLength(Imported, 1);
        Imported[0] := LoadDocument(FullPath, Access);
      end;
      for Document in Imported do
        if Document.Text.Trim.IsEmpty then
          raise EReadError.CreateFmt('Origem %s, página %d: sem texto extraído. Confira se a página é branca ou necessita de OCR.',
            [Document.Source, Document.PageNumber]);
      for I := Documents.Count - 1 downto 0 do
        if SameSource(Documents[I].Source, FullPath) then Documents.Delete(I);
      Documents.AddRange(Imported);
      if Documents.Count > 10000 then raise EReadError.Create('Limite de documentos excedido');
    end;
    for Document in Documents do
    begin
      if Ids.ContainsKey(Document.Id) then
        raise EReadError.Create('Identidade repetida na coleção: ' + Document.Id + '. Use nomes de arquivos distintos.');
      Ids.Add(Document.Id, True);
    end;
    Result := Documents.ToArray;
  finally Ids.Free; InputPaths.Free; Documents.Free; end;
end;

end.
