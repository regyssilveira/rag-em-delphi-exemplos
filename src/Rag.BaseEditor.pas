unit Rag.BaseEditor;

interface

uses System.SysUtils, Rag.Persistence,
  Rag.Embeddings, Rag.Types;

function RemoveSourceAndSave(const BasePath,
  SourcePath, ExpectedModelIdentity: string;
  const IsCancelled: TFunc<Boolean> = nil):
    TPreparedBase;

function ImportPrepareSave(const BasePath: string;
  const FileNames: TArray<string>;
  const Access, PdfiumPath: string; Provider:
    IEmbeddingProvider;
  Dimension, MaxChars, Overlap: Integer; out Stats:
    TUpdateStats;
  const IsCancelled: TFunc<Boolean> = nil):
    TPreparedBase;

function ReviewedSourcePrepareSave(const BasePath:
  string; const Documents: TArray<TDocument>;
  Provider: IEmbeddingProvider; Dimension, MaxChars,
    Overlap: Integer;
  out Stats: TUpdateStats; const IsCancelled: TFunc<
    Boolean> = nil): TPreparedBase;

implementation

uses System.Classes, System.IOUtils,
  System.Generics.Collections,
  System.Generics.Defaults, Rag.Import, Rag.Vectors;

function RemoveSourceAndSave(const BasePath,
  SourcePath, ExpectedModelIdentity: string;
  const IsCancelled: TFunc<Boolean>): TPreparedBase;
var Previous: TPreparedBase; Remaining: TDictionary<
  string, Boolean>;
  Items: TList<TEmbeddedChunk>; Document: TDocument;
    Item: TEmbeddedChunk;
begin
  if Assigned(IsCancelled) and IsCancelled() then
    raise EAbort.Create('Remoção cancelada');
  Previous := LoadPreparedBase(BasePath,
    ExpectedModelIdentity);
  Result := Previous;
  Result.Documents := RemoveDocumentSource(
    Previous.Documents, SourcePath);
  if Length(Result.Documents) = Length(
    Previous.Documents) then
    raise EArgumentException.Create(
      'Origem não encontrada na ' + 'base');
  Remaining := TDictionary<string, Boolean>.Create;
  Items := TList<TEmbeddedChunk>.Create;
  try
    for Document in Result.Documents do
      Remaining.Add(Document.Id, True);
    for Item in Previous.Items do
      if Remaining.ContainsKey(Item.Chunk.DocumentId
        ) then Items.Add(Item);
    Result.Items := Items.ToArray;
    ValidatePreparedBase(Result);
    if Assigned(IsCancelled) and IsCancelled() then
      raise EAbort.Create('Remoção cancelada');
    SavePreparedBase(BasePath, Result);
  finally Items.Free; Remaining.Free; end;
end;

type
  TCancellableEmbeddings = class(TInterfacedObject,
    IEmbeddingProvider)
  private
    FProvider: IEmbeddingProvider;
    FCancelled: TFunc<Boolean>;
    procedure CheckCancelled;
  public
    constructor Create(Provider: IEmbeddingProvider;
      const Cancelled: TFunc<Boolean>);
    function GetModelIdentity: string;
    function EmbedDocument(const Text: string):
      TEmbedding;
    function EmbedQuery(const Text: string):
      TEmbedding;
  end;

constructor TCancellableEmbeddings.Create(Provider:
  IEmbeddingProvider;
  const Cancelled: TFunc<Boolean>);
begin
  inherited Create;
  FProvider := Provider;
  FCancelled := Cancelled;
end;

procedure TCancellableEmbeddings.CheckCancelled;
begin
  if Assigned(FCancelled) and FCancelled() then
    raise EAbort.Create('Preparação cancelada ' +
      'antes da gravação');
end;

function TCancellableEmbeddings.GetModelIdentity:
  string;
begin
  CheckCancelled;
  Result := FProvider.ModelIdentity;
end;

function TCancellableEmbeddings.EmbedDocument(const
  Text: string): TEmbedding;
begin
  CheckCancelled;
  Result := FProvider.EmbedDocument(Text);
  CheckCancelled;
end;

function TCancellableEmbeddings.EmbedQuery(const
  Text: string): TEmbedding;
begin
  CheckCancelled;
  Result := FProvider.EmbedQuery(Text);
  CheckCancelled;
end;

function ImportPrepareSave(const BasePath: string;
  const FileNames: TArray<string>;
  const Access, PdfiumPath: string; Provider:
    IEmbeddingProvider;
  Dimension, MaxChars, Overlap: Integer; out Stats:
    TUpdateStats;
  const IsCancelled: TFunc<Boolean>): TPreparedBase;
var Previous: TPreparedBase; Documents: TArray<
  TDocument>;
  Guarded: IEmbeddingProvider;
begin
  Stats := Default(TUpdateStats);
  if Provider = nil then raise
    EArgumentException.Create('Provedor ausente');
  if BasePath.Trim.IsEmpty then raise
    EArgumentException.Create('Destino ausente');
  Guarded := TCancellableEmbeddings.Create(Provider,
    IsCancelled);
  Previous := Default(TPreparedBase);
  if TFile.Exists(BasePath) then
    Previous := LoadPreparedBase(BasePath,
      Guarded.ModelIdentity);
  Documents := MergeImportedDocuments(
    Previous.Documents, FileNames, Access,
    PdfiumPath);
  Result := PrepareBase(Documents, Previous, Guarded
    , Dimension, MaxChars, Overlap, Stats);
  if Assigned(IsCancelled) and IsCancelled() then
    raise EAbort.Create('Preparação cancelada ' +
      'antes da gravação');
  SavePreparedBase(BasePath, Result);
  (* Depois de iniciar a gravação, o resultado é *)
  (* confirmado ou uma exceção é propagada. *)
  (* Um cancelamento tardio não transforma uma *)
  (* gravação concluída em cancelamento. *)
end;

function ReviewedSourcePrepareSave(const BasePath:
  string; const Documents: TArray<TDocument>;
  Provider: IEmbeddingProvider; Dimension, MaxChars,
    Overlap: Integer;
  out Stats: TUpdateStats; const IsCancelled: TFunc<
    Boolean>): TPreparedBase;
var Previous: TPreparedBase; Merged: TList<TDocument
  >; Ids: TDictionary<string, Boolean>;
  Guarded: IEmbeddingProvider; Document: TDocument;
    Source, Access: string; TotalChars: Int64;
begin
  Stats := Default(TUpdateStats);
  if (Provider = nil) or BasePath.Trim.IsEmpty or (
    Length(Documents) = 0)
    or (Length(Documents) > 1000) then raise
      EArgumentException.Create(
      'Lote revisado ou destino ' + 'inválido');
  Guarded := TCancellableEmbeddings.Create(Provider,
    IsCancelled);
  Source := TPath.GetFullPath(Documents[0].Source);
    Access := Documents[0].Access;
  for Document in Documents do
  begin
    if Document.Source.Trim.IsEmpty or
      Document.Id.Trim.IsEmpty or
      Document.Text.Trim.IsEmpty
      or (Document.PageNumber < 0) or (
        Document.Access <> Access)
      or ((Access <> 'operacional') and (Access <>
        'supervisor'))
      or not IEqualityComparer<string>(
        TIStringComparer.Ordinal).Equals(
        TPath.GetFullPath(Document.Source), Source)
      or Document.Text.Contains(#0) then raise
        EArgumentException.Create(
        'Documento revisado ' + 'inválido');
    if Document.WasOcrReviewed then
    begin
      if Document.RecognitionIdentity.Trim.IsEmpty
        or (Length(Document.RecognitionIdentity) >
        512)
        or (Length(Document.RecognizedText) > 1024 *
          1024) or Document.RecognizedText.Contains(
          #0) then
        raise EArgumentException.Create(
          'Proveniência do lote ' + 'inválida');
    end
    else if (Document.RecognitionIdentity <> '') or
      (Document.RecognizedText <> '') then
      raise EArgumentException.Create(
        'Proveniência sem revisão');
  end;
  Previous := Default(TPreparedBase);
  if TFile.Exists(BasePath) then Previous :=
    LoadPreparedBase(BasePath, Guarded.ModelIdentity
    );
  Merged := TList<TDocument>.Create; Ids :=
    TDictionary<string, Boolean>.Create(
    TIStringComparer.Ordinal);
  try
    Merged.AddRange(RemoveDocumentSource(
      Previous.Documents, Source)); Merged.AddRange(
      Documents);
    if Merged.Count > 10000 then raise
      EReadError.Create('Limite de documentos ' +
      'excedido');
    TotalChars := 0;
    for Document in Merged do
    begin
      if Ids.ContainsKey(Document.Id) then raise
        EArgumentException.Create(
        'Identidade de documento ' + 'repetida');
      Ids.Add(Document.Id, True); Inc(TotalChars,
        Length(Document.Text));
    end;
    if TotalChars > MaxImportedTextChars then raise
      EReadError.Create('Limite agregado de texto '
      + 'excedido');
    Result := PrepareBase(Merged.ToArray, Previous,
      Guarded, Dimension, MaxChars, Overlap, Stats);
    if Assigned(IsCancelled) and IsCancelled() then
      raise EAbort.Create('Preparação cancelada ' +
      'antes da gravação');
    SavePreparedBase(BasePath, Result);
  finally Ids.Free; Merged.Free; end;
end;

end.
