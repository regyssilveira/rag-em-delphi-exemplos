program OcrReviewFormProbe;
uses System.SysUtils, Vcl.Forms, Rag.Ocr, Rag.OcrReviewForm;
var Page: TOcrPage; Dialog: TOcrReviewForm;
begin
  Application.Initialize;
  Page := Default(TOcrPage); Page.Source := 'fictitious.pdf'; Page.PageNumber := 2;
  Page.Text := 'Somente o supervisor pode liberar.';
  Page.RecognitionIdentity := 'SYNTHETIC-REVIEW-FORM-v1';
  Dialog := TOcrReviewForm.CreateReview(nil, Page, ParamStr(1), 'operacional');
  try Dialog.RunHandlerChecks; finally Dialog.Free; end;
  Page.Text := '';
  Dialog := TOcrReviewForm.CreateReview(nil, Page, ParamStr(1), 'operacional');
  try Dialog.RunEmptyHandlerChecks; finally Dialog.Free; end;
end.
