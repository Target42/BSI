object ProjectForm: TProjectForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Projekt'
  ClientHeight = 240
  ClientWidth = 420
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 15
  object lblName: TLabel
    Left = 16
    Top = 16
    Width = 27
    Height = 15
    Caption = 'Name'
  end
  object edtName: TEdit
    Left = 16
    Top = 34
    Width = 388
    Height = 23
    TabOrder = 0
  end
  object lblDescription: TLabel
    Left = 16
    Top = 64
    Width = 61
    Height = 15
    Caption = 'Beschreibung'
  end
  object memDescription: TMemo
    Left = 16
    Top = 82
    Width = 388
    Height = 110
    ScrollBars = ssVertical
    TabOrder = 1
  end
  object btnOk: TButton
    Left = 228
    Top = 200
    Width = 85
    Height = 30
    Caption = 'OK'
    Default = True
    TabOrder = 2
    OnClick = btnOkClick
  end
  object btnCancel: TButton
    Left = 319
    Top = 200
    Width = 85
    Height = 30
    Cancel = True
    Caption = 'Abbrechen'
    ModalResult = 2
    TabOrder = 3
  end
end
