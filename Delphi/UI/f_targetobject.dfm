object TargetObjectForm: TTargetObjectForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Zielobjekt'
  ClientHeight = 352
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
  object lblParent: TLabel
    Left = 16
    Top = 12
    Width = 388
    Height = 32
    AutoSize = False
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clGrayText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
    WordWrap = True
  end
  object lblName: TLabel
    Left = 16
    Top = 48
    Width = 27
    Height = 15
    Caption = 'Name'
  end
  object edtName: TEdit
    Left = 16
    Top = 66
    Width = 388
    Height = 23
    TabOrder = 0
  end
  object lblType: TLabel
    Left = 16
    Top = 96
    Width = 22
    Height = 15
    Caption = 'Typ'
  end
  object cboType: TComboBox
    Left = 16
    Top = 114
    Width = 388
    Height = 23
    Style = csDropDownList
    TabOrder = 1
  end
  object lblProtection: TLabel
    Left = 16
    Top = 144
    Width = 66
    Height = 15
    Caption = 'Schutzbedarf'
  end
  object cboProtection: TComboBox
    Left = 16
    Top = 162
    Width = 388
    Height = 23
    Style = csDropDownList
    TabOrder = 2
  end
  object lblDescription: TLabel
    Left = 16
    Top = 192
    Width = 61
    Height = 15
    Caption = 'Beschreibung'
  end
  object memDescription: TMemo
    Left = 16
    Top = 210
    Width = 388
    Height = 90
    ScrollBars = ssVertical
    TabOrder = 3
  end
  object btnOk: TButton
    Left = 228
    Top = 312
    Width = 85
    Height = 30
    Caption = 'OK'
    Default = True
    TabOrder = 4
    OnClick = btnOkClick
  end
  object btnCancel: TButton
    Left = 319
    Top = 312
    Width = 85
    Height = 30
    Cancel = True
    Caption = 'Abbrechen'
    ModalResult = 2
    TabOrder = 5
  end
end
