object ProjectForm: TProjectForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Projekt'
  ClientHeight = 330
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
    Height = 90
    ScrollBars = ssVertical
    TabOrder = 1
  end
  object rgVisibility: TRadioGroup
    Left = 16
    Top = 180
    Width = 388
    Height = 100
    Caption = 'Sichtbarkeit'
    ItemIndex = 0
    Items.Strings = (
      'Privat '#8212' nur Projektmitglieder'
      #214'ffentlich '#8212' ohne Anmeldung sichtbar')
    TabOrder = 2
  end
  object btnOk: TButton
    Left = 228
    Top = 290
    Width = 85
    Height = 30
    Caption = 'OK'
    Default = True
    TabOrder = 3
    OnClick = btnOkClick
  end
  object btnCancel: TButton
    Left = 319
    Top = 290
    Width = 85
    Height = 30
    Cancel = True
    Caption = 'Abbrechen'
    ModalResult = 2
    TabOrder = 4
  end
end
