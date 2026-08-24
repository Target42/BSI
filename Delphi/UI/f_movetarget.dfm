object MoveTargetForm: TMoveTargetForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Zielobjekt verschieben'
  ClientHeight = 380
  ClientWidth = 480
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  TextHeight = 15
  object lblHint: TLabel
    Left = 16
    Top = 12
    Width = 448
    Height = 48
    AutoSize = False
    WordWrap = True
  end
  object lstDestinations: TListBox
    Left = 16
    Top = 68
    Width = 448
    Height = 260
    ItemHeight = 15
    TabOrder = 0
  end
  object btnOk: TButton
    Left = 308
    Top = 344
    Width = 75
    Height = 25
    Caption = 'OK'
    Default = True
    ModalResult = 0
    TabOrder = 1
  end
  object btnCancel: TButton
    Left = 389
    Top = 344
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Abbrechen'
    ModalResult = 2
    TabOrder = 2
  end
end
