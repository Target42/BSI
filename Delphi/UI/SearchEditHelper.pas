unit SearchEditHelper;

interface

uses
  System.SysUtils, System.Classes, Vcl.StdCtrls, Vcl.Buttons, Vcl.Controls;

type
  TSearchClearButton = class(TComponent)
  private
    FEdit: TEdit;
    FButton: TSpeedButton;
    FOnSearchChange: TNotifyEvent;
    procedure ButtonClick(Sender: TObject);
    procedure EditChange(Sender: TObject);
    procedure UpdateButton;
  public
    constructor Create(AOwner: TComponent; AEdit: TEdit); reintroduce;
    property OnSearchChange: TNotifyEvent read FOnSearchChange write FOnSearchChange;
  end;

implementation

constructor TSearchClearButton.Create(AOwner: TComponent; AEdit: TEdit);
var
  RightMargin: Integer;
begin
  inherited Create(AOwner);
  FEdit := AEdit;
  RightMargin := AEdit.Parent.ClientWidth - (AEdit.Left + AEdit.Width);
  if RightMargin < 0 then
    RightMargin := 8;
  FButton := TSpeedButton.Create(AOwner);
  FButton.Parent := AEdit.Parent;
  FButton.Width := 20;
  FButton.Height := AEdit.Height - 2;
  FButton.Top := AEdit.Top + 1;
  FButton.Anchors := [akTop, akRight];
  FButton.Left := AEdit.Parent.ClientWidth - RightMargin - FButton.Width;
  FButton.Flat := True;
  FButton.Caption := #215;
  FButton.Hint := 'L'#246'schen';
  FButton.ShowHint := True;
  FButton.Visible := Trim(FEdit.Text) <> '';
  FButton.OnClick := ButtonClick;
  FEdit.OnChange := EditChange;
end;

procedure TSearchClearButton.UpdateButton;
begin
  FButton.Visible := Trim(FEdit.Text) <> '';
end;

procedure TSearchClearButton.EditChange(Sender: TObject);
begin
  UpdateButton;
  if Assigned(FOnSearchChange) then
    FOnSearchChange(Sender);
end;

procedure TSearchClearButton.ButtonClick(Sender: TObject);
begin
  FEdit.Text := '';
  if FEdit.CanFocus then
    FEdit.SetFocus;
end;

end.
