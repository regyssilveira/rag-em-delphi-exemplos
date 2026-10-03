unit Rag.Persistence;

interface

uses System.SysUtils, System.Classes, System.IOUtils
  , System.JSON, System.Hash,
  System.Generics.Collections, Winapi.Windows,
    Rag.Types, Rag.Core,
  Rag.Vectors, Rag.Embeddings, Rag.Ingestion;

type
  TPreparedBase = record
    ModelIdentity: string;
    Dimension, MaxChars, Overlap: Integer;
    Documents: TArray<TDocument>;
    Items: TArray<TEmbeddedChunk>;
  end;
  TUpdateStats = record
    Reused, Embedded, Removed: Integer;
  end;

procedure ValidatePreparedBase(const Base:
  TPreparedBase);
procedure SavePreparedBase(const FileName: string;
  const Base: TPreparedBase);
function LoadPreparedBase(const FileName,
  ExpectedModelIdentity: string): TPreparedBase;
function PrepareBase(const Documents: TArray<
  TDocument>; const Previous: TPreparedBase;
  Provider: IEmbeddingProvider; Dimension, MaxChars,
    Overlap: Integer;
  out Stats: TUpdateStats): TPreparedBase;

implementation

procedure ValidatePreparedBase(const Base:
  TPreparedBase);
var
  Ids: TDictionary<string, Boolean>;
  Document: TDocument;
  Expected: TChunk;
  Actual: TEmbeddedChunk;
  Position: Integer;
begin
  if Base.ModelIdentity.Trim.IsEmpty or (
    Base.Dimension < 1) or (Base.Dimension > 65536)
    or
    (Base.MaxChars < 32) or (Base.Overlap < 0) or (
      Base.Overlap >= Base.MaxChars) then
    raise EReadError.Create(
      'Contrato da base inválido');
  if (Length(Base.Documents) > 10000) or (Length(
    Base.Items) > 100000) then
    raise EReadError.Create(
      'Limite da base excedido');
  Ids := TDictionary<string, Boolean>.Create;
  try
    Position := 0;
    for Document in Base.Documents do
    begin
      if Document.Id.Trim.IsEmpty or
        Document.Source.Trim.IsEmpty or
        ((Document.Access <> 'operacional') and (
          Document.Access <> 'supervisor')) or
        (Document.PageNumber < 0) or Ids.ContainsKey
          (Document.Id) then
        raise EReadError.Create(
          'Identidade ou metadados ' +
          'de documento inválidos');
      if Length(Document.RecognizedText) > 1024 *
        1024 then
        raise EReadError.Create(
          'Texto reconhecido fora do ' + 'limite');
      if Document.WasOcrReviewed then
      begin
        if Document.RecognitionIdentity.Trim.IsEmpty
          or (Length(Document.RecognitionIdentity) >
          512)
          or Document.Text.Trim.IsEmpty or
            Document.RecognizedText.Contains(#0)
            then
          raise EReadError.Create(
            'Proveniência OCR inválida');
      end
      else if (Document.RecognitionIdentity <> '')
        or (Document.RecognizedText <> '') then
        raise EReadError.Create(
          'Documento sem revisão ' +
          'contém proveniência OCR');
      Ids.Add(Document.Id, True);
      for Expected in SplitDocument(Document,
        Base.MaxChars, Base.Overlap) do
      begin
        if Position >= Length(Base.Items) then raise
          EReadError.Create('Trecho ausente');
        Actual := Base.Items[Position];
        if (Actual.Chunk.Id <> Expected.Id) or (
          Actual.Chunk.DocumentId <>
          Expected.DocumentId) or
          (Actual.Chunk.Text <> Expected.Text) or (
            Actual.Chunk.Source <> Expected.Source)
            or
          (Actual.Chunk.Access <> Expected.Access)
            or (Actual.Chunk.PageNumber <>
            Expected.PageNumber) or
          (Actual.Chunk.StartOffset <>
            Expected.StartOffset) or (Length(
            Actual.Vector) <> Base.Dimension) then
          raise EReadError.Create(
            'Trecho ou dimensão ' +
            'incoerente com documento');
        NormalizeEmbedding(Actual.Vector);
        Inc(Position);
      end;
    end;
    if Position <> Length(Base.Items) then raise
      EReadError.Create('Trechos excedentes');
  finally Ids.Free; end;
end;

function RequiredField(Value: TJSONValue; const Name
  : string): TJSONValue;
var
  ObjectValue: TJSONObject;
  I, Count: Integer;
begin
  if not (Value is TJSONObject) then raise
    EReadError.Create('Objeto inválido');
  ObjectValue := Value as TJSONObject;
  Result := nil;
  Count := 0;
  for I := 0 to ObjectValue.Count - 1 do
    if ObjectValue.Pairs[I].JsonString.Value = Name
      then
    begin
      Inc(Count);
      Result := ObjectValue.Pairs[I].JsonValue;
    end;
  if Count <> 1 then raise EReadError.Create(
    'Campo ausente ou ' + 'repetido: ' + Name);
end;

function RequiredString(Value: TJSONValue; const
  Name: string): string;
var Field: TJSONValue;
begin
  Field := RequiredField(Value, Name);
  if not (Field is TJSONString) then raise
    EReadError.Create('Campo textual inválido: ' +
    Name);
  Result := Field.Value;
end;

function RequiredInteger(Value: TJSONValue; const
  Name: string): Integer;
var Field: TJSONValue;
begin
  Field := RequiredField(Value, Name);
  if not (Field is TJSONNumber) or not TryStrToInt(
    Field.Value, Result) then
    raise EReadError.Create(
      'Campo inteiro inválido: ' + Name);
end;

function RequiredArray(Value: TJSONValue; const Name
  : string): TJSONArray;
begin
  if not (RequiredField(Value, Name) is TJSONArray)
    then raise EReadError.Create('Array inválido: '
    + Name);
  Result := RequiredField(Value, Name) as TJSONArray
    ;
end;

function RequiredBoolean(Value: TJSONValue; const
  Name: string): Boolean;
var Field: TJSONValue;
begin
  Field := RequiredField(Value, Name);
  if not (Field is TJSONBool) then raise
    EReadError.Create('Campo booleano inválido: ' +
    Name);
  Result := (Field as TJSONBool).AsBoolean;
end;

procedure SavePreparedBase(const FileName: string;
  const Base: TPreparedBase);
var
  Json, ObjectValue: TJSONObject;
  Documents, Items, Vector: TJSONArray;
  Document: TDocument;
  Item: TEmbeddedChunk;
  Component: Double;
  Bytes: TBytes;
  Stream: TFileStream;
  FullPath, TemporaryPath: string;
  Unique: TGUID;
begin
  ValidatePreparedBase(Base);
  FullPath := TPath.GetFullPath(FileName);
  if not TDirectory.Exists(TPath.GetDirectoryName(
    FullPath)) then
    raise EDirectoryNotFoundException.Create(
      'Pasta da base inexistente');
  CreateGUID(Unique);
  TemporaryPath := FullPath + '.' + GUIDToString(
    Unique) + '.tmp';
  Json := TJSONObject.Create;
  try
    Json.AddPair('formatVersion', TJSONNumber.Create
      (2));
    Json.AddPair('preparation',
      'normalized-text-split-v1');
    Json.AddPair('modelIdentity', Base.ModelIdentity
      );
    Json.AddPair('dimension', TJSONNumber.Create(
      Base.Dimension));
    Json.AddPair('maxChars', TJSONNumber.Create(
      Base.MaxChars));
    Json.AddPair('overlap', TJSONNumber.Create(
      Base.Overlap));
    Documents := TJSONArray.Create;
    Json.AddPair('documents', Documents);
    for Document in Base.Documents do
    begin
      ObjectValue := TJSONObject.Create;
      Documents.AddElement(ObjectValue);
      ObjectValue.AddPair('id', Document.Id);
      ObjectValue.AddPair('source', Document.Source)
        ;
      ObjectValue.AddPair('access', Document.Access)
        ;
      ObjectValue.AddPair('page', TJSONNumber.Create
        (Document.PageNumber));
      ObjectValue.AddPair('text', Document.Text);
      ObjectValue.AddPair('textHash',
        THashSHA2.GetHashString(Document.Text));
      ObjectValue.AddPair('ocrReviewed',
        TJSONBool.Create(Document.WasOcrReviewed));
      ObjectValue.AddPair('recognitionIdentity',
        Document.RecognitionIdentity);
      ObjectValue.AddPair('recognizedText',
        Document.RecognizedText);
      ObjectValue.AddPair('recognizedTextHash',
        THashSHA2.GetHashString(
        Document.RecognizedText));
    end;
    Items := TJSONArray.Create;
    Json.AddPair('items', Items);
    for Item in Base.Items do
    begin
      ObjectValue := TJSONObject.Create;
      Items.AddElement(ObjectValue);
      ObjectValue.AddPair('id', Item.Chunk.Id);
      ObjectValue.AddPair('documentId',
        Item.Chunk.DocumentId);
      ObjectValue.AddPair('source',
        Item.Chunk.Source);
      ObjectValue.AddPair('access',
        Item.Chunk.Access);
      ObjectValue.AddPair('page', TJSONNumber.Create
        (Item.Chunk.PageNumber));
      ObjectValue.AddPair('offset',
        TJSONNumber.Create(Item.Chunk.StartOffset));
      ObjectValue.AddPair('text', Item.Chunk.Text);
      Vector := TJSONArray.Create;
      ObjectValue.AddPair('vector', Vector);
      for Component in Item.Vector do
        Vector.AddElement(TJSONNumber.Create(
        Component));
    end;
    Bytes := TEncoding.UTF8.GetBytes(Json.ToJSON);
    if Length(Bytes) > 16 * 1024 * 1024 then raise
      EWriteError.Create('Base excede 16 MiB');
    try
      Stream := TFileStream.Create(TemporaryPath,
        fmCreate or fmShareExclusive);
      try
        Stream.WriteBuffer(Bytes[0], Length(Bytes));
        if not FlushFileBuffers(Stream.Handle) then
          RaiseLastOSError;
      finally Stream.Free; end;
      if not MoveFileEx(PChar(TemporaryPath), PChar(
        FullPath),
        MOVEFILE_REPLACE_EXISTING or
          MOVEFILE_WRITE_THROUGH) then
          RaiseLastOSError;
    finally
      if TFile.Exists(TemporaryPath) then
        TFile.Delete(TemporaryPath);
    end;
  finally Json.Free; end;
end;

function LoadPreparedBase(const FileName,
  ExpectedModelIdentity: string): TPreparedBase;
var
  Json, Value: TJSONValue;
  Documents, Items, Vector: TJSONArray;
  I, J, FormatVersion: Integer;
begin
  Result := Default(TPreparedBase);
  if ExpectedModelIdentity.Trim.IsEmpty then raise
    EArgumentException.Create(
    'Modelo esperado ausente');
  Json := TJSONObject.ParseJSONValue(ReadUtf8Text(
    FileName));
  if Json = nil then raise EReadError.Create(
    'Base JSON inválida');
  try
    FormatVersion := RequiredInteger(Json,
      'formatVersion');
    if not (Json is TJSONObject) or not (
      FormatVersion in [1, 2]) or
      (RequiredString(Json, 'preparation') <>
        'normalized-text-split-v1') then
      raise EReadError.Create('Versão da base não '
        + 'suportada');
    Result.ModelIdentity := RequiredString(Json,
      'modelIdentity');
    if Result.ModelIdentity <> ExpectedModelIdentity
      then raise EReadError.Create('Modelo da base '
      + 'incompatível');
    Result.Dimension := RequiredInteger(Json,
      'dimension');
    Result.MaxChars := RequiredInteger(Json,
      'maxChars');
    Result.Overlap := RequiredInteger(Json,
      'overlap');
    Documents := RequiredArray(Json, 'documents');
    Items := RequiredArray(Json, 'items');
    if (Documents.Count > 10000) or (Items.Count >
      100000) then raise EReadError.Create(
      'Limite da base excedido');
    SetLength(Result.Documents, Documents.Count);
    for I := 0 to Documents.Count - 1 do
    begin
      Value := Documents.Items[I];
      if not (Value is TJSONObject) then raise
        EReadError.Create('Documento JSON inválido')
        ;
      Result.Documents[I].Id := RequiredString(Value
        , 'id');
      Result.Documents[I].Source := RequiredString(
        Value, 'source');
      Result.Documents[I].Access := RequiredString(
        Value, 'access');
      Result.Documents[I].PageNumber :=
        RequiredInteger(Value, 'page');
      Result.Documents[I].Text := RequiredString(
        Value, 'text');
      if FormatVersion = 2 then
      begin
        Result.Documents[I].WasOcrReviewed :=
          RequiredBoolean(Value, 'ocrReviewed');
        Result.Documents[I].RecognitionIdentity :=
          RequiredString(Value,
          'recognitionIdentity');
        Result.Documents[I].RecognizedText :=
          RequiredString(Value, 'recognizedText');
        if RequiredString(Value,
          'recognizedTextHash') <>
          THashSHA2.GetHashString(Result.Documents[I
          ].RecognizedText) then
          raise EReadError.Create(
            'Hash do texto reconhecido ' +
            'inconsistente');
      end
      else if ((Value as TJSONObject).GetValue(
        'ocrReviewed') <> nil)
        or ((Value as TJSONObject).GetValue(
          'recognitionIdentity') <> nil)
        or ((Value as TJSONObject).GetValue(
          'recognizedText') <> nil)
        or ((Value as TJSONObject).GetValue(
          'recognizedTextHash') <> nil) then
        raise EReadError.Create(
          'Proveniência OCR exige ' + 'versão 2');
      if RequiredString(Value, 'textHash') <>
        THashSHA2.GetHashString(Result.Documents[I].
        Text) then
        raise EReadError.Create(
          'Hash textual inconsistente');
    end;
    SetLength(Result.Items, Items.Count);
    for I := 0 to Items.Count - 1 do
    begin
      Value := Items.Items[I];
      if not (Value is TJSONObject) then raise
        EReadError.Create('Trecho JSON inválido');
      Result.Items[I].Chunk.Id := RequiredString(
        Value, 'id');
      Result.Items[I].Chunk.DocumentId :=
        RequiredString(Value, 'documentId');
      Result.Items[I].Chunk.Source := RequiredString
        (Value, 'source');
      Result.Items[I].Chunk.Access := RequiredString
        (Value, 'access');
      Result.Items[I].Chunk.PageNumber :=
        RequiredInteger(Value, 'page');
      Result.Items[I].Chunk.StartOffset :=
        RequiredInteger(Value, 'offset');
      Result.Items[I].Chunk.Text := RequiredString(
        Value, 'text');
      Vector := RequiredArray(Value, 'vector');
      if (Vector.Count <> Result.Dimension) or (
        Vector.Count > 65536) then raise
        EReadError.Create('Dimensão inválida');
      SetLength(Result.Items[I].Vector, Vector.Count
        );
      for J := 0 to Vector.Count - 1 do
      begin
        if not (Vector.Items[J] is TJSONNumber) then
          raise EReadError.Create(
          'Vetor não numérico');
        Result.Items[I].Vector[J] := (Vector.Items[J
          ] as TJSONNumber).AsDouble;
      end;
    end;
    ValidatePreparedBase(Result);
  finally Json.Free; end;
end;

function PrepareBase(const Documents: TArray<
  TDocument>; const Previous: TPreparedBase;
  Provider: IEmbeddingProvider; Dimension, MaxChars,
    Overlap: Integer;
  out Stats: TUpdateStats): TPreparedBase;
var
  Items: TList<TEmbeddedChunk>;
  OldItems: TDictionary<string, Integer>;
  Used: TDictionary<string, Boolean>;
  Document: TDocument;
  Chunk: TChunk;
  Item: TEmbeddedChunk;
  OldPosition, I: Integer;
  Compatible: Boolean;
begin
  if Provider = nil then raise
    EArgumentException.Create('Provedor ausente');
  Stats := Default(TUpdateStats);
  Result := Default(TPreparedBase);
  Result.ModelIdentity := Provider.ModelIdentity;
  Result.Dimension := Dimension;
  Result.MaxChars := MaxChars;
  Result.Overlap := Overlap;
  Result.Documents := Copy(Documents);
  if Previous.ModelIdentity <> '' then
    ValidatePreparedBase(Previous);
  Compatible := (Previous.ModelIdentity =
    Result.ModelIdentity) and
    (Previous.Dimension = Dimension) and (
      Previous.MaxChars = MaxChars) and (
      Previous.Overlap = Overlap);
  Items := TList<TEmbeddedChunk>.Create;
  OldItems := TDictionary<string, Integer>.Create;
  Used := TDictionary<string, Boolean>.Create;
  try
    for I := 0 to High(Previous.Items) do
      OldItems.Add(Previous.Items[I].Chunk.Id, I);
    for Document in Documents do
      for Chunk in SplitDocument(Document, MaxChars,
        Overlap) do
      begin
        Item.Chunk := Chunk;
        if Compatible and OldItems.TryGetValue(
          Chunk.Id, OldPosition) and
          (Previous.Items[OldPosition].Chunk.Text =
            Chunk.Text) then
        begin
          Item.Vector := Copy(Previous.Items[
            OldPosition].Vector);
          Inc(Stats.Reused);
        end
        else
        begin
          Item.Vector := Provider.EmbedDocument(
            Chunk.Text);
          Inc(Stats.Embedded);
        end;
        Used.Add(Chunk.Id, True);
        Items.Add(Item);
      end;
    for I := 0 to High(Previous.Items) do
      if not Used.ContainsKey(Previous.Items[I].
        Chunk.Id) then Inc(Stats.Removed);
    Result.Items := Items.ToArray;
    ValidatePreparedBase(Result);
  finally
    Used.Free;
    OldItems.Free;
    Items.Free;
  end;
end;

end.
