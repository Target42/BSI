object TargetObjectForm: TTargetObjectForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Zielobjekt'
  ClientHeight = 320
  ClientWidth = 420
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
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
  object lblType: TLabel
    Left = 16
    Top = 64
    Width = 22
    Height = 15
    Caption = 'Typ'
  end
  object cboType: TComboBox
    Left = 16
    Top = 82
    Width = 388
    Height = 23
    Style = csDropDownList
    TabOrder = 1
  end
  object lblProtection: TLabel
    Left = 16
    Top = 112
    Width = 66
    Height = 15
    Caption = 'Schutzbedarf'
  end
  object cboProtection: TComboBox
    Left = 16
    Top = 130
    Width = 388
    Height = 23
    Style = csDropDownList
    TabOrder = 2
  end
  object lblDescription: TLabel
    Left = 16
    Top = 160
    Width = 61
    Height = 15
    Caption = 'Beschreibung'
  end
  object memDescription: TMemo
    Left = 16
    Top = 178
    Width = 388
    Height = 90
    ScrollBars = ssVertical
    TabOrder = 3
  end
  object btnOk: TButton
    Left = 228
    Top = 280
    Width = 85
    Height = 30
    Caption = 'OK'
    Default = True
    TabOrder = 4
    OnClick = btnOkClick
  end
  object btnCancel: TButton
    Left = 319
    Top = 280
    Width = 85
    Height = 30
    Cancel = True
    Caption = 'Abbrechen'
    ModalResult = 2
    TabOrder = 5
  end
end
