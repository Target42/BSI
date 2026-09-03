unit f_texteditor;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ComCtrls;

// RichEdit-Konstanten f'r Windows-Rechtschreibkorrektur (CTF/TSF)
const
  EM_SETEDITSTYLEEX = WM_USER + 275;
  SES_EX_USESINGLELINE  = $00000001;
  SES_USECTF            = $00000001;  // EM_SETEDITSTYLE flag
  SES_EX_MULTITOUCH     = $08000000;

type
  TTextEditorForm = class(TForm)
    reText: TRichEdit;
    btnOk: TButton;
    btnCancel: TButton;
    procedure FormShow(Sender: TObject);
  public
    class function Execute(const ACaption: string; var AText: string;
      AReadOnly: Boolean = False): Boolean;
  end;

implementation

{$R *.dfm}

const
  // EM_SETEDITSTYLE (WM_USER+204): SES_USECTF aktiviert Text Services Framework
  // Das ist die einfachste Art, native Windows-Rechtschreibkorrektur zu aktivieren
  EM_SETEDITSTYLE_MSG = WM_USER + 204;
  SES_USECTF_FLAG     = $00010000;

procedure TTextEditorForm.FormShow(Sender: TObject);
begin
  // CTF (Component Text Framework) / TSF aktivieren:
  // Windows nutzt dann dieselbe Rechtschreibkorrektur wie WordPad/Notepad
  SendMessage(reText.Handle, EM_SETEDITSTYLE_MSG, SES_USECTF_FLAG, SES_USECTF_FLAG);
end;

class function TTextEditorForm.Execute(const ACaption: string; var AText: string;
  AReadOnly: Boolean): Boolean;
var
  Dlg: TTextEditorForm;
begin
  Dlg := TTextEditorForm.Create(Application);
  try
    Dlg.Caption := ACaption;
    Dlg.reText.PlainText := True;
    Dlg.reText.Text := AText;
    Dlg.reText.ReadOnly := AReadOnly;
    if AReadOnly then
    begin
      Dlg.btnOk.Visible := False;
      Dlg.btnCancel.Caption := 'Schlie'#223'en';
    end;
    Result := Dlg.ShowModal = mrOk;
    if Result then
      AText := Dlg.reText.Text;
  finally
    Dlg.Free;
  end;
end;

end.
