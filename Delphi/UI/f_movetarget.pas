unit f_movetarget;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, IsmsDomain;

type
  TMoveTargetForm = class(TForm)
    lblHint: TLabel;
    lstDestinations: TListBox;
    btnOk: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
  private
    FParentId: Integer;
    procedure OkClick(Sender: TObject);
    procedure DestinationsDblClick(Sender: TObject);
  public
    class function Execute(const AObjects: TArray<TTargetObject>;
      const AMoving: TTargetObject; out AParentId: Integer): Boolean;
  end;

implementation

{$R *.dfm}

procedure TMoveTargetForm.FormCreate(Sender: TObject);
begin
  btnOk.OnClick := OkClick;
  lstDestinations.OnDblClick := DestinationsDblClick;
end;

procedure TMoveTargetForm.OkClick(Sender: TObject);
begin
  if lstDestinations.ItemIndex < 0 then
  begin
    MessageDlg('Bitte ein Ziel in der Liste w'#$00E4'hlen.', mtInformation, [mbOK], 0);
    Exit;
  end;
  FParentId := Integer(lstDestinations.Items.Objects[lstDestinations.ItemIndex]);
  ModalResult := mrOk;
end;

procedure TMoveTargetForm.DestinationsDblClick(Sender: TObject);
begin
  OkClick(Sender);
end;

class function TMoveTargetForm.Execute(const AObjects: TArray<TTargetObject>;
  const AMoving: TTargetObject; out AParentId: Integer): Boolean;
var
  F: TMoveTargetForm;
  Dest: TTargetMoveDestination;
begin
  AParentId := 0;
  F := TMoveTargetForm.Create(Application);
  try
    F.lblHint.Caption :=
      'Neues '#$00FC'bergeordnetes Ziel f'#$00FC'r "' + TargetObjectCaption(AMoving) +
      '" w'#$00E4'hlen. Die Schicht entspricht der Gruppe im Baum (z. B. Anwendungen).';
    for Dest in PossibleTargetMoveDestinations(AObjects, AMoving) do
      F.lstDestinations.Items.AddObject(Dest.Caption, TObject(NativeInt(Dest.ParentId)));
    F.btnOk.Enabled := F.lstDestinations.Count > 0;
    if F.lstDestinations.Count > 0 then
      F.lstDestinations.ItemIndex := 0;
    if F.lstDestinations.Count = 0 then
    begin
      MessageDlg('F'#$00FC'r dieses Zielobjekt ist kein anderes g'#$00FC'ltiges '#$00FC +
        'bergeordnetes Objekt vorhanden.', mtInformation, [mbOK], 0);
      Exit(False);
    end;
    Result := F.ShowModal = mrOk;
    if Result then
      AParentId := F.FParentId;
  finally
    F.Free;
  end;
end;

end.
