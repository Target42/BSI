object TargetObjectForm: TTargetObjectForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Zielobjekt'
  ClientHeight = 560
  ClientWidth = 440
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
    Width = 408
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
    Width = 408
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
    Width = 408
    Height = 23
    Style = csDropDownList
    TabOrder = 1
  end
  object chkInherit: TCheckBox
    Left = 16
    Top = 146
    Width = 408
    Height = 17
    Caption = 'Schutzbedarf vom '#252'bergeordneten Objekt '#252'bernehmen'
    TabOrder = 2
  end
  object lblConfidentiality: TLabel
    Left = 16
    Top = 172
    Width = 80
    Height = 15
    Caption = 'Vertraulichkeit'
  end
  object cboConfidentiality: TComboBox
    Left = 16
    Top = 190
    Width = 408
    Height = 23
    Style = csDropDownList
    TabOrder = 3
  end
  object lblIntegrity: TLabel
    Left = 16
    Top = 220
    Width = 47
    Height = 15
    Caption = 'Integrit'#228't'
  end
  object cboIntegrity: TComboBox
    Left = 16
    Top = 238
    Width = 408
    Height = 23
    Style = csDropDownList
    TabOrder = 4
  end
  object lblAvailability: TLabel
    Left = 16
    Top = 268
    Width = 74
    Height = 15
    Caption = 'Verf'#252'gbarkeit'
  end
  object cboAvailability: TComboBox
    Left = 16
    Top = 286
    Width = 408
    Height = 23
    Style = csDropDownList
    TabOrder = 5
  end
  object lblOverall: TLabel
    Left = 16
    Top = 318
    Width = 408
    Height = 32
    AutoSize = False
    Caption = 'Gesamt nach Maximumprinzip: Normal (Basis + Standard)'
    WordWrap = True
  end
  object lblProtectionNote: TLabel
    Left = 16
    Top = 354
    Width = 61
    Height = 15
    Caption = 'Begr'#252'ndung'
  end
  object memProtectionNote: TMemo
    Left = 16
    Top = 372
    Width = 408
    Height = 48
    ScrollBars = ssVertical
    TabOrder = 6
  end
  object lblDescription: TLabel
    Left = 16
    Top = 428
    Width = 61
    Height = 15
    Caption = 'Beschreibung'
  end
  object memDescription: TMemo
    Left = 16
    Top = 446
    Width = 408
    Height = 64
    ScrollBars = ssVertical
    TabOrder = 7
  end
  object btnOk: TButton
    Left = 248
    Top = 520
    Width = 85
    Height = 30
    Caption = 'OK'
    Default = True
    TabOrder = 8
  end
  object btnCancel: TButton
    Left = 339
    Top = 520
    Width = 85
    Height = 30
    Cancel = True
    Caption = 'Abbrechen'
    ModalResult = 2
    TabOrder = 9
  end
end
