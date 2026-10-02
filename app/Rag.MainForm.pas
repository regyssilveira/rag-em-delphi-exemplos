unit Rag.MainForm;

interface

uses System.SysUtils, System.Classes, Vcl.Forms, Vcl.Controls, Vcl.StdCtrls,
  Vcl.ExtCtrls, Rag.Assistant;

type
  TQueryWorker = class(TThread)
  private
    FBasePath, FQuestion, FProfile: string;
  protected
    procedure Execute; override;
  public
    Response: TAssistantResponse;
    ErrorMessage: string;
    WasCancelled: Boolean;
    ImportFiles: TArray<string>;
    ImportAccess, PdfiumPath: string;
    ImportMode, Committed: Boolean;
    RemoveMode: Boolean;
    CatalogMode: Boolean;
    CatalogSources: TArray<string>;
    RemoveSource: string;
    ImportSummary: string;
    constructor Create(const BasePath, Question, Profile: string);
    function CancellationRequested: Boolean;
  end;

  TAssistantForm = class(TForm)
  private
    FBasePath: TEdit;
    FQuestion: TMemo;
    FProfile: TComboBox;
    FAsk, FBrowse, FCancel, FImport, FRemove, FCatalog: TButton;
    FOrigins: TComboBox;
    FImportAccess: TComboBox;
    FAnswer, FSource: TMemo;
    FSources: TListBox;
    FStatus: TLabel;
    FWorker: TQueryWorker;
    FResponse: TAssistantResponse;
    procedure BrowseBase(Sender: TObject);
    procedure ImportDocuments(Sender: TObject);
    procedure StartImport(const Files: TArray<string>);
    procedure RemoveSource(Sender: TObject);
    procedure LoadCatalog(Sender: TObject);
    procedure Ask(Sender: TObject);
    procedure Finished(Sender: TObject);
    procedure SelectSource(Sender: TObject);
    procedure ProfileChanged(Sender: TObject);
    procedure CheckClose(Sender: TObject; var CanClose: Boolean);
    procedure SetBusy(Value: Boolean);
    procedure CancelQuery(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    procedure RunFlowCheck(const BasePath, ReportPath: string);
    procedure RunAdminCheck(const BasePath, ReportPath: string);
  end;

var AssistantForm: TAssistantForm;

implementation

uses System.IOUtils, System.JSON, Winapi.Windows, Vcl.Dialogs,
  Rag.Persistence, Rag.Embeddings, Rag.Generation, Rag.Answers,
  Rag.Context, Rag.Presentation, Rag.BaseEditor, Rag.Types;

constructor TQueryWorker.Create(const BasePath, Question, Profile: string);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FBasePath := BasePath;
  FQuestion := Question;
  FProfile := Profile;
end;

function TQueryWorker.CancellationRequested: Boolean;
begin
  Result := Terminated;
end;

procedure TQueryWorker.Execute;
var Base: TPreparedBase; Embeddings: IEmbeddingProvider; Generator: IAnswerProvider;
  Stats: TUpdateStats;
  Origins: TStringList; Document: TDocument;
begin
  try
    try
    if Terminated then Exit;
    if CatalogMode then
    begin
      Base := LoadPreparedBase(FBasePath,
        'embeddinggemma:300m@85462619ee721b466c5927d109d4cb765861907d5417b9109caebc4e614679f1|retrieval-prefix-v1|dim=768');
      Origins := TStringList.Create;
      try
        Origins.Sorted := True;
        Origins.CaseSensitive := False;
        Origins.Duplicates := dupIgnore;
        for Document in Base.Documents do Origins.Add(Document.Source);
        CatalogSources := Origins.ToStringArray;
      finally Origins.Free; end;
      Exit;
    end;
    if RemoveMode then
    begin
      Base := RemoveSourceAndSave(FBasePath, RemoveSource,
        'embeddinggemma:300m@85462619ee721b466c5927d109d4cb765861907d5417b9109caebc4e614679f1|retrieval-prefix-v1|dim=768',
        function: Boolean begin Result := Terminated; end);
      Committed := True;
      ImportSummary := Format('Origem removida da base; %d documentos restantes. Arquivo original preservado.',
        [Length(Base.Documents)]);
      Exit;
    end;
    Embeddings := TOllamaEmbeddingProvider.Create('embeddinggemma:300m',
      '85462619ee721b466c5927d109d4cb765861907d5417b9109caebc4e614679f1', 768);
    if Terminated then Exit;
    if ImportMode then
    begin
      Base := ImportPrepareSave(FBasePath, ImportFiles, ImportAccess, PdfiumPath,
        Embeddings, 768, 380, 60, Stats,
        function: Boolean begin Result := Terminated; end);
      Committed := True;
      ImportSummary := Format('Base gravada: %d documentos, %d vetores novos, %d reutilizados.',
        [Length(Base.Documents), Stats.Embedded, Stats.Reused]);
      Exit;
    end;
    Base := LoadPreparedBase(FBasePath, Embeddings.ModelIdentity);
    Generator := TOllamaAnswerProvider.Create;
    Response := QueryPreparedBase(Base, FQuestion, FProfile, Embeddings, Generator,
      function: Boolean begin Result := Terminated; end);
    except
      on E: EAbort do WasCancelled := True;
      on E: Exception do ErrorMessage := E.Message;
    end;
  finally
    if Terminated and not Committed then WasCancelled := True;
  end;
end;

constructor TAssistantForm.Create(AOwner: TComponent);
var TopPanel, QuestionPanel, SourcePanel: TPanel; Title, ProfileLabel: TLabel;
begin
  inherited CreateNew(AOwner);
  Caption := 'Assistente documental — RAG em Delphi';
  Width := 1000;
  Height := 720;
  Constraints.MinWidth := 850;
  Constraints.MinHeight := 620;
  Position := poScreenCenter;
  Font.Name := 'Segoe UI';
  Font.Size := 10;
  OnCloseQuery := CheckClose;
  TopPanel := TPanel.Create(Self);
  TopPanel.Parent := Self;
  TopPanel.Align := alTop;
  TopPanel.Height := 172;
  TopPanel.Width := ClientWidth;
  TopPanel.BevelOuter := bvNone;
  Title := TLabel.Create(Self);
  Title.Parent := TopPanel;
  Title.SetBounds(16, 10, 760, 20);
  Title.Caption := 'Consulte os procedimentos e confira as passagens que sustentam a resposta.';
  FBasePath := TEdit.Create(Self);
  FBasePath.Parent := TopPanel;
  FBasePath.SetBounds(16, 40, 740, 27);
  FBasePath.Anchors := [akLeft, akTop, akRight];
  FBasePath.Text := TPath.Combine(ExtractFilePath(Application.ExeName), 'integrated-base.json');
  FBrowse := TButton.Create(Self);
  FBrowse.Parent := TopPanel;
  FBrowse.SetBounds(774, 38, 180, 30);
  FBrowse.Anchors := [akTop, akRight];
  FBrowse.Caption := 'Abrir base preparada';
  FBrowse.OnClick := BrowseBase;
  FImportAccess := TComboBox.Create(Self);
  FImportAccess.Parent := TopPanel;
  FImportAccess.SetBounds(16, 84, 230, 27);
  FImportAccess.Style := csDropDownList;
  FImportAccess.Items.Add('operacional');
  FImportAccess.Items.Add('supervisor');
  FImportAccess.ItemIndex := 0;
  FImportAccess.Hint := 'Classificação dos documentos importados';
  FImportAccess.ShowHint := True;
  FImport := TButton.Create(Self);
  FImport.Parent := TopPanel;
  FImport.SetBounds(264, 82, 330, 30);
  FImport.Caption := 'Importar ou atualizar documentos';
  FImport.OnClick := ImportDocuments;
  FRemove := TButton.Create(Self);
  FRemove.Parent := TopPanel;
  FRemove.SetBounds(612, 82, 342, 30);
  FRemove.Anchors := [akTop, akRight];
  FRemove.Caption := 'Remover origem selecionada';
  FRemove.OnClick := RemoveSource;
  FCatalog := TButton.Create(Self);
  FCatalog.Parent := TopPanel;
  FCatalog.SetBounds(16, 126, 230, 30);
  FCatalog.Caption := 'Carregar origens da base';
  FCatalog.OnClick := LoadCatalog;
  FOrigins := TComboBox.Create(Self);
  FOrigins.Parent := TopPanel;
  FOrigins.SetBounds(264, 128, 690, 27);
  FOrigins.Anchors := [akLeft, akTop, akRight];
  FOrigins.Style := csDropDownList;
  QuestionPanel := TPanel.Create(Self);
  QuestionPanel.Parent := Self;
  QuestionPanel.Top := TopPanel.Height;
  QuestionPanel.Align := alTop;
  QuestionPanel.Height := 158;
  QuestionPanel.Width := ClientWidth;
  QuestionPanel.BevelOuter := bvNone;
  ProfileLabel := TLabel.Create(Self);
  ProfileLabel.Parent := QuestionPanel;
  ProfileLabel.SetBounds(16, 4, 740, 20);
  ProfileLabel.Caption := 'Perfil didático de acesso (não representa autenticação no ERP):';
  FProfile := TComboBox.Create(Self);
  FProfile.Parent := QuestionPanel;
  FProfile.SetBounds(16, 29, 180, 27);
  FProfile.Style := csDropDownList;
  FProfile.Items.Add('operacional');
  FProfile.Items.Add('supervisor');
  FProfile.ItemIndex := 0;
  FProfile.OnChange := ProfileChanged;
  FQuestion := TMemo.Create(Self);
  FQuestion.Parent := QuestionPanel;
  FQuestion.SetBounds(16, 65, 740, 76);
  FQuestion.Anchors := [akLeft, akTop, akRight];
  FQuestion.MaxLength := 1000;
  FQuestion.Lines.Text := 'Quem pode liberar um recebimento com divergência?';
  FAsk := TButton.Create(Self);
  FAsk.Parent := QuestionPanel;
  FAsk.SetBounds(774, 65, 180, 34);
  FAsk.Anchors := [akTop, akRight];
  FAsk.Caption := 'Consultar documentos';
  FAsk.OnClick := Ask;
  FCancel := TButton.Create(Self);
  FCancel.Parent := QuestionPanel;
  FCancel.SetBounds(774, 108, 180, 30);
  FCancel.Anchors := [akTop, akRight];
  FCancel.Caption := 'Cancelar operação';
  FCancel.OnClick := CancelQuery;
  FStatus := TLabel.Create(Self);
  FStatus.Parent := Self;
  FStatus.Top := ClientHeight;
  FStatus.AutoSize := False;
  FStatus.Align := alBottom;
  FStatus.Height := 28;
  FStatus.Caption := ' Abra uma base preparada e faça uma pergunta.';
  SourcePanel := TPanel.Create(Self);
  SourcePanel.Parent := Self;
  SourcePanel.Top := ClientHeight - FStatus.Height - 220;
  SourcePanel.Align := alBottom;
  SourcePanel.Height := 220;
  SourcePanel.Width := ClientWidth;
  SourcePanel.BevelOuter := bvNone;
  FSources := TListBox.Create(Self);
  FSources.Parent := SourcePanel;
  FSources.Align := alLeft;
  FSources.Width := 310;
  FSources.OnClick := SelectSource;
  FSource := TMemo.Create(Self);
  FSource.Parent := SourcePanel;
  FSource.Align := alClient;
  FSource.ReadOnly := True;
  FSource.ScrollBars := ssVertical;
  FAnswer := TMemo.Create(Self);
  FAnswer.Parent := Self;
  FAnswer.Align := alClient;
  FAnswer.ReadOnly := True;
  FAnswer.ScrollBars := ssVertical;
  FBasePath.OnChange := ProfileChanged;
  SetBusy(False);
end;

procedure TAssistantForm.SetBusy(Value: Boolean);
begin
  FAsk.Enabled := not Value;
  FImport.Enabled := not Value;
  FRemove.Enabled := not Value;
  FCatalog.Enabled := not Value;
  FOrigins.Enabled := not Value;
  FImportAccess.Enabled := not Value;
  FBrowse.Enabled := not Value;
  FBasePath.Enabled := not Value;
  FQuestion.Enabled := not Value;
  FProfile.Enabled := not Value;
  FCancel.Enabled := Value;
end;

procedure TAssistantForm.CancelQuery(Sender: TObject);
begin
  if FWorker <> nil then
  begin
    FWorker.Terminate;
    FCancel.Enabled := False;
    FStatus.Caption := ' Cancelamento solicitado; aguarde a operação em andamento terminar.';
  end;
end;

procedure TAssistantForm.ProfileChanged(Sender: TObject);
begin
  if Sender = FBasePath then FOrigins.Clear;
  FResponse := Default(TAssistantResponse);
  FAnswer.Clear;
  FSource.Clear;
  FSources.Clear;
end;

procedure TAssistantForm.BrowseBase(Sender: TObject);
var Dialog: TOpenDialog;
begin
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Filter := 'Base preparada (*.json)|*.json';
    Dialog.Options := Dialog.Options + [ofFileMustExist];
    if Dialog.Execute then
    begin
      FBasePath.Text := Dialog.FileName;
      ProfileChanged(Self);
    end;
  finally Dialog.Free; end;
end;

procedure TAssistantForm.Ask(Sender: TObject);
var Question: string;
begin
  if FWorker <> nil then Exit;
  Question := Trim(FQuestion.Lines.Text);
  if Question.IsEmpty or not TFile.Exists(FBasePath.Text) then
  begin
    FStatus.Caption := ' Informe uma pergunta e selecione uma base existente.';
    Exit;
  end;
  ProfileChanged(Self);
  FWorker := TQueryWorker.Create(FBasePath.Text, Question, FProfile.Text);
  FWorker.OnTerminate := Finished;
  SetBusy(True);
  FStatus.Caption := ' Consultando documentos; aguarde a conclusão.';
  FWorker.Start;
end;

procedure TAssistantForm.ImportDocuments(Sender: TObject);
var Dialog: TOpenDialog; Files: TArray<string>; I: Integer;
begin
  if FWorker <> nil then Exit;
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Filter := 'Documentos (*.txt;*.md;*.docx;*.pdf)|*.txt;*.md;*.docx;*.pdf';
    Dialog.Options := Dialog.Options + [ofFileMustExist, ofAllowMultiSelect];
    if Dialog.Execute then
    begin
      SetLength(Files, Dialog.Files.Count);
      for I := 0 to Dialog.Files.Count - 1 do Files[I] := Dialog.Files[I];
      StartImport(Files);
    end;
  finally Dialog.Free; end;
end;

procedure TAssistantForm.StartImport(const Files: TArray<string>);
begin
  if FWorker <> nil then Exit;
  if Trim(FBasePath.Text).IsEmpty then
  begin
    FStatus.Caption := ' Informe o caminho do arquivo de base a criar ou atualizar.';
    Exit;
  end;
  ProfileChanged(Self);
  FWorker := TQueryWorker.Create(FBasePath.Text, '', '');
  FWorker.ImportMode := True;
  FWorker.ImportFiles := Copy(Files);
  FWorker.ImportAccess := FImportAccess.Text;
  FWorker.PdfiumPath := TPath.Combine(ExtractFilePath(Application.ExeName), 'pdfium/bin/pdfium.dll');
  FWorker.OnTerminate := Finished;
  SetBusy(True);
  FStatus.Caption := ' Importando e preparando documentos; aguarde a gravação.';
  FWorker.Start;
end;

procedure TAssistantForm.LoadCatalog(Sender: TObject);
begin
  if FWorker <> nil then Exit;
  FOrigins.Clear;
  FWorker := TQueryWorker.Create(FBasePath.Text, '', '');
  FWorker.CatalogMode := True;
  FWorker.OnTerminate := Finished;
  SetBusy(True);
  FStatus.Caption := ' Carregando catálogo administrativo de origens; aguarde.';
  FWorker.Start;
end;

procedure TAssistantForm.RemoveSource(Sender: TObject);
var SourcePath: string;
begin
  if FWorker <> nil then Exit;
  if FOrigins.ItemIndex < 0 then
  begin
    FStatus.Caption := ' Carregue o catálogo e selecione uma origem para remover da base.';
    Exit;
  end;
  SourcePath := FOrigins.Text;
  if MessageDlg('Remover todos os documentos e trechos desta origem da base? ' +
    SourcePath + sLineBreak + 'O arquivo original será preservado.',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  ProfileChanged(Self);
  FWorker := TQueryWorker.Create(FBasePath.Text, '', '');
  FWorker.RemoveMode := True;
  FWorker.RemoveSource := SourcePath;
  FWorker.OnTerminate := Finished;
  SetBusy(True);
  FStatus.Caption := ' Removendo origem da base; aguarde a confirmação.';
  FWorker.Start;
end;

procedure TAssistantForm.Finished(Sender: TObject);
var Worker: TQueryWorker; Source: TContextSource;
begin
  Worker := TQueryWorker(Sender);
  try
    if (Worker.ImportMode or Worker.RemoveMode) and Worker.Committed then
    begin
      FOrigins.Clear;
      FStatus.Caption := ' ' + Worker.ImportSummary;
      Exit;
    end;
    if Worker.WasCancelled or Worker.CancellationRequested then
    begin
      FStatus.Caption := ' Operação cancelada; nenhum resultado dessa operação foi apresentado.';
      Exit;
    end;
    if Worker.ErrorMessage <> '' then
    begin
      FStatus.Caption := ' Operação não concluída: ' + Worker.ErrorMessage;
      Exit;
    end;
    if Worker.CatalogMode then
    begin
      FOrigins.Items.AddStrings(Worker.CatalogSources);
      if FOrigins.Items.Count > 0 then FOrigins.ItemIndex := 0;
      FStatus.Caption := ' Catálogo administrativo carregado; selecione uma origem.';
      Exit;
    end;
    FResponse := Worker.Response;
    FAnswer.Text := FormatAnswer(FResponse.Answer);
    for Source in FResponse.Context.Sources do
      FSources.Items.Add(Source.LabelId + ' — ' + Source.Chunk.DocumentId);
    FStatus.Caption := ' Consulta concluída. Selecione uma fonte para conferir seu texto.';
  finally
    FWorker := nil;
    SetBusy(False);
    TThread.ForceQueue(nil,
      procedure begin Worker.Free; end);
  end;
end;

procedure TAssistantForm.SelectSource(Sender: TObject);
var Index: Integer;
begin
  Index := FSources.ItemIndex;
  if (Index >= 0) and (Index < Length(FResponse.Context.Sources)) then
  begin
    FSource.Lines.BeginUpdate;
    try
      FSource.Clear;
      FSource.Lines.Add(FResponse.Context.Sources[Index].Chunk.Source);
      if FResponse.Context.Sources[Index].Chunk.PageNumber > 0 then
        FSource.Lines.Add('Página: ' + IntToStr(FResponse.Context.Sources[Index].Chunk.PageNumber));
      FSource.Lines.Add('');
      FSource.Lines.Add(FResponse.Context.Sources[Index].Chunk.Text);
    finally FSource.Lines.EndUpdate; end;
  end;
end;

procedure TAssistantForm.CheckClose(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := FWorker = nil;
  if not CanClose then FStatus.Caption := ' Aguarde a operação terminar antes de fechar.';
end;

procedure TAssistantForm.RunAdminCheck(const BasePath, ReportPath: string);
var TestBase, Selected: string; Started: UInt64; Base: TPreparedBase;
  Report: TJSONObject;
  procedure WaitForWorker;
  begin
    Started := GetTickCount64;
    while FWorker <> nil do
    begin
      Application.ProcessMessages;
      CheckSynchronize(10);
      if GetTickCount64 - Started > 60000 then raise Exception.Create('Tempo administrativo excedido');
    end;
  end;
begin
  TestBase := TPath.Combine(ExtractFilePath(ReportPath), 'admin-base-' + UIntToStr(GetTickCount64) + '.json');
  TFile.Copy(BasePath, TestBase);
  FBasePath.Text := TestBase;
  FCatalog.Click;
  WaitForWorker;
  if FOrigins.Items.Count <> 3 then raise Exception.Create('Catálogo não contém as três origens');
  Selected := FOrigins.Items[0];
  FWorker := TQueryWorker.Create(TestBase, '', '');
  FWorker.RemoveMode := True;
  FWorker.RemoveSource := Selected;
  FWorker.OnTerminate := Finished;
  SetBusy(True);
  FWorker.Start;
  WaitForWorker;
  if not string(FStatus.Caption).Contains('Origem removida') then raise Exception.Create('Remoção não confirmada');
  if FOrigins.Items.Count <> 0 then raise Exception.Create('Catálogo obsoleto permaneceu visível');
  Base := LoadPreparedBase(TestBase,
    'embeddinggemma:300m@85462619ee721b466c5927d109d4cb765861907d5417b9109caebc4e614679f1|retrieval-prefix-v1|dim=768');
  if Length(Base.Documents) <> 2 then raise Exception.Create('Documentos não removidos');
  if not TFile.Exists(Selected) then raise Exception.Create('Original ausente');
  FCatalog.Click;
  WaitForWorker;
  if (FOrigins.Items.Count <> 2) or (FOrigins.Items.IndexOf(Selected) >= 0) then
    raise Exception.Create('Catálogo não refletiu remoção');
  Report := TJSONObject.Create;
  try
    Report.AddPair('passed', TJSONBool.Create(True));
    Report.AddPair('scope', 'Catálogo e worker de remoção por handlers VCL em cópia da base; não exercita diálogo de confirmação nem inspeção visual.');
    Report.AddPair('remainingDocuments', TJSONNumber.Create(Length(Base.Documents)));
    Report.AddPair('originalPreserved', TJSONBool.Create(True));
    TFile.WriteAllText(ReportPath, Report.ToJSON, TEncoding.UTF8);
  finally Report.Free; end;
end;

procedure TAssistantForm.RunFlowCheck(const BasePath, ReportPath: string);
var Report: TJSONObject; Checks: TJSONArray; Started: UInt64; CanClose: Boolean;
  OriginalWorker: TQueryWorker; Source: TContextSource;
  ImportInput, ImportBase, BeforeImport: string; ImportedBase: TPreparedBase;

  procedure Check(Value: Boolean; const Name: string);
  begin
    if not Value then raise Exception.Create('Falhou: ' + Name);
    Checks.Add(Name);
    TFile.WriteAllText(ReportPath, Report.ToJSON, TEncoding.UTF8);
  end;

  procedure WaitForQuery;
  begin
    Started := GetTickCount64;
    while FWorker <> nil do
    begin
      Application.ProcessMessages;
      CheckSynchronize(10);
      if GetTickCount64 - Started > 240000 then
      begin
        CancelQuery(Self);
        raise Exception.Create('Tempo da prova excedido');
      end;
    end;
  end;

begin
  Report := TJSONObject.Create;
  Checks := TJSONArray.Create;
  Report.AddPair('checks', Checks);
  Report.AddPair('passed', TJSONBool.Create(False));
  TFile.WriteAllText(ReportPath, Report.ToJSON, TEncoding.UTF8);
  try
    FBasePath.Text := BasePath;
    FProfile.ItemIndex := 0;
    FQuestion.Lines.Text := 'Quem pode liberar um recebimento com divergência?';
    FAsk.Click;
    Check((FWorker <> nil) and not FAsk.Enabled and not FProfile.Enabled and
      FCancel.Enabled, 'consulta bloqueia ações incompatíveis e permite cancelar');
    CanClose := True;
    CheckClose(Self, CanClose);
    Check(not CanClose, 'fechamento recusado enquanto worker está ativo');
    OriginalWorker := FWorker;
    Ask(Self);
    Check(FWorker = OriginalWorker, 'segunda consulta não cria outro worker');
    WaitForQuery;
    Check(FAsk.Enabled and not FCancel.Enabled and FResponse.Answer.HasAnswer and
      FAnswer.Lines.Text.ToLower.Contains('supervisor') and
      FAnswer.Lines.Text.Contains('Citação:'), 'resposta real apresentada com citação');
    Check(FSources.Count > 0, 'contexto consultado disponível para conferência');
    FSources.ItemIndex := 0;
    SelectSource(Self);
    Check(FSource.Lines.Text.Contains(FResponse.Context.Sources[0].Chunk.Text),
      'seleção mostra passagem resolvida localmente');
    Report.AddPair('supportedAnswer', FAnswer.Lines.Text);
    FQuestion.Lines.Text := 'Quem aprova o ajuste de estoque?';
    FAsk.Click;
    WaitForQuery;
    Check(not FResponse.Answer.HasAnswer and FAnswer.Lines.Text.Contains('Não encontrei evidência'),
      'perfil operacional recebe abstenção para regra restrita');
    for Source in FResponse.Context.Sources do
      Check(Source.Chunk.Access = 'operacional', 'fonte do contexto respeita perfil operacional');
    FProfile.ItemIndex := 1;
    ProfileChanged(Self);
    Check((FSources.Count = 0) and (FAnswer.Lines.Count = 0) and
      (Length(FResponse.Context.Sources) = 0), 'mudança de perfil limpa apresentação e contexto anterior');
    FAsk.Click;
    WaitForQuery;
    Check(FResponse.Answer.HasAnswer and FAnswer.Lines.Text.ToLower.Contains('supervisor'),
      'perfil supervisor consulta regra de ajuste');
    FProfile.ItemIndex := 0;
    ProfileChanged(Self);
    Check((FSources.Count = 0) and FSource.Lines.Text.IsEmpty and FAnswer.Lines.Text.IsEmpty,
      'volta ao operacional remove conteúdo restrito da janela');
    FQuestion.Lines.Text := 'Quem pode liberar um recebimento com divergência?';
    FAsk.Click;
    CancelQuery(Self);
    WaitForQuery;
    Check((FSources.Count = 0) and FAnswer.Lines.Text.IsEmpty and
      string(FStatus.Caption).Contains('cancelada') and FAsk.Enabled,
      'cancelamento descarta resultado e libera próxima consulta');
    ImportBase := TPath.Combine(ExtractFilePath(ReportPath), 'vcl-import-' + UIntToStr(GetTickCount64) + '.json');
    ImportInput := ChangeFileExt(ImportBase, '.txt');
    TFile.WriteAllText(ImportInput, 'O supervisor aprova a contagem de estoque.', TEncoding.UTF8);
    FBasePath.Text := ImportBase;
    FImportAccess.ItemIndex := 0;
    StartImport([ImportInput]);
    Check(not FImport.Enabled and not FAsk.Enabled, 'importação bloqueia operações concorrentes');
    WaitForQuery;
    Check(TFile.Exists(ImportBase) and string(FStatus.Caption).Contains('Base gravada'), 'importação VCL grava base com embeddings reais');
    ImportedBase := LoadPreparedBase(ImportBase,
      'embeddinggemma:300m@85462619ee721b466c5927d109d4cb765861907d5417b9109caebc4e614679f1|retrieval-prefix-v1|dim=768');
    Check((Length(ImportedBase.Documents) = 1) and (Length(ImportedBase.Items) = 1), 'base importada reabre com documento e vetor');
    FImportAccess.ItemIndex := 1;
    StartImport([ImportInput]);
    WaitForQuery;
    ImportedBase := LoadPreparedBase(ImportBase,
      'embeddinggemma:300m@85462619ee721b466c5927d109d4cb765861907d5417b9109caebc4e614679f1|retrieval-prefix-v1|dim=768');
    Check((ImportedBase.Documents[0].Access = 'supervisor') and string(FStatus.Caption).Contains('1 reutilizados'), 'reimportação VCL atualiza classificação e reutiliza vetor');
    BeforeImport := TFile.ReadAllText(ImportBase, TEncoding.UTF8);
    StartImport([ImportInput + '.ausente']);
    WaitForQuery;
    Check((TFile.ReadAllText(ImportBase, TEncoding.UTF8) = BeforeImport) and string(FStatus.Caption).Contains('não concluída'), 'falha de importação conserva base anterior');
    Report.RemovePair('passed').Free;
    Report.AddPair('passed', TJSONBool.Create(True));
    Report.AddPair('scope', 'Consulta e importação real por controles e handlers VCL em janela oculta; não aprova inspeção visual, OCR ou remoção pela janela.');
    TFile.WriteAllText(ReportPath, Report.ToJSON, TEncoding.UTF8);
  finally Report.Free; end;
end;

end.
