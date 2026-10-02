unit Rag.Answers;

interface

uses System.SysUtils, Rag.Context;

type
  TAnswerEvidence = record
    Source: TContextSource;
    Quote: string;
  end;
  TAnswerClaim = record
    Text: string;
    Evidence: TArray<TAnswerEvidence>;
  end;
  TValidatedAnswer = record
    HasAnswer: Boolean;
    Claims: TArray<TAnswerClaim>;
  end;

function ParseAnswer(const Payload: string; const Context: TPreparedContext): TValidatedAnswer;

implementation

uses System.JSON, System.Generics.Collections;

procedure RequireFields(const Obj: TJSONObject; const Names: array of string);
var Name: string; Pair: TJSONPair; Count: Integer;
begin
  if Obj.Count <> Length(Names) then raise EArgumentException.Create('Campos de resposta inesperados');
  for Name in Names do
  begin
    Count := 0;
    for Pair in Obj do if Pair.JsonString.Value = Name then Inc(Count);
    if Count <> 1 then raise EArgumentException.Create('Campo ausente ou duplicado');
  end;
end;

function ReadString(const Obj: TJSONObject; const Name: string; MaxLength: Integer): string;
var Value: TJSONValue;
begin
  Value := Obj.GetValue(Name);
  if not (Value is TJSONString) then raise EArgumentException.Create('String de resposta esperada');
  Result := Value.Value;
  if Result.Trim.IsEmpty or (Length(Result) > MaxLength) then
    raise EArgumentException.Create('Texto de resposta fora dos limites');
end;

function ParseAnswer(const Payload: string; const Context: TPreparedContext): TValidatedAnswer;
var
  Value: TJSONValue;
  Root, ClaimObject, EvidenceObject: TJSONObject;
  Claims, Evidence: TJSONArray;
  Labels: TDictionary<string, TContextSource>;
  Seen: TDictionary<string, Boolean>;
  Source: TContextSource;
  Status, LabelId, Quote: string;
  I, J: Integer;
begin
  Result := Default(TValidatedAnswer);
  if (Length(Payload) = 0) or (Length(Payload) > 65536) then
    raise EArgumentException.Create('Resposta fora dos limites');
  Value := TJSONObject.ParseJSONValue(Payload);
  if Value = nil then raise EArgumentException.Create('Resposta JSON inválida');
  try
    if not (Value is TJSONObject) then raise EArgumentException.Create('Objeto de resposta esperado');
    Root := TJSONObject(Value);
    RequireFields(Root, ['status', 'claims']);
    Status := ReadString(Root, 'status', 20);
    if not (Root.GetValue('claims') is TJSONArray) then raise EArgumentException.Create('Lista de afirmações esperada');
    Claims := TJSONArray(Root.GetValue('claims'));
    if Status = 'insufficient' then
    begin
      if Claims.Count <> 0 then raise EArgumentException.Create('Abstenção não pode incluir afirmações');
      Exit;
    end;
    if (Status <> 'answered') or (Claims.Count < 1) or (Claims.Count > 8) then
      raise EArgumentException.Create('Estado ou quantidade de afirmações inválidos');
    Labels := TDictionary<string, TContextSource>.Create;
    Seen := TDictionary<string, Boolean>.Create;
    try
      for Source in Context.Sources do
      begin
        if Source.LabelId.IsEmpty or Labels.ContainsKey(Source.LabelId) then
          raise EArgumentException.Create('Rótulos de contexto inválidos');
        Labels.Add(Source.LabelId, Source);
      end;
      SetLength(Result.Claims, Claims.Count);
      for I := 0 to Claims.Count - 1 do
      begin
        if not (Claims.Items[I] is TJSONObject) then raise EArgumentException.Create('Afirmação inválida');
        ClaimObject := TJSONObject(Claims.Items[I]);
        RequireFields(ClaimObject, ['text', 'evidence']);
        Result.Claims[I].Text := ReadString(ClaimObject, 'text', 2000);
        if not (ClaimObject.GetValue('evidence') is TJSONArray) then raise EArgumentException.Create('Lista de evidências esperada');
        Evidence := TJSONArray(ClaimObject.GetValue('evidence'));
        if (Evidence.Count < 1) or (Evidence.Count > 6) then raise EArgumentException.Create('Afirmação sem evidência ou com excesso');
        SetLength(Result.Claims[I].Evidence, Evidence.Count);
        Seen.Clear;
        for J := 0 to Evidence.Count - 1 do
        begin
          if not (Evidence.Items[J] is TJSONObject) then raise EArgumentException.Create('Evidência inválida');
          EvidenceObject := TJSONObject(Evidence.Items[J]);
          RequireFields(EvidenceObject, ['label', 'quote']);
          LabelId := ReadString(EvidenceObject, 'label', 20);
          Quote := ReadString(EvidenceObject, 'quote', 1000);
          if (Length(Quote.Trim) < 10) or not Labels.TryGetValue(LabelId, Source) then
            raise EArgumentException.Create('Citação curta ou fonte ausente');
          if Source.Chunk.Text.IndexOf(Quote) < 0 then raise EArgumentException.Create('Citação não pertence ao trecho');
          if Seen.ContainsKey(LabelId) then raise EArgumentException.Create('Fonte repetida na afirmação');
          Seen.Add(LabelId, True);
          Result.Claims[I].Evidence[J].Source := Source;
          Result.Claims[I].Evidence[J].Quote := Quote;
        end;
      end;
      Result.HasAnswer := True;
    finally Seen.Free; Labels.Free; end;
  finally Value.Free; end;
end;

end.
