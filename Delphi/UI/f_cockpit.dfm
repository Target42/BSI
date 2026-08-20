object CockpitForm: TCockpitForm
  Left = 0
  Top = 0
  Caption = 'Aufgaben-Cockpit'
  ClientHeight = 620
  ClientWidth = 1100
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  TextHeight = 15
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 1100
    Height = 96
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblKind: TLabel
      Left = 12
      Top = 14
      Width = 16
      Height = 15
      Caption = 'Art'
    end
    object cboKind: TComboBox
      Left = 36
      Top = 10
      Width = 140
      Height = 23
      Style = csDropDownList
      TabOrder = 0
    end
    object lblDue: TLabel
      Left = 188
      Top = 14
      Width = 26
      Height = 15
      Caption = 'Frist'
    end
    object cboDue: TComboBox
      Left = 220
      Top = 10
      Width = 150
      Height = 23
      Style = csDropDownList
      TabOrder = 1
    end
    object chkHideDone: TCheckBox
      Left = 384
      Top = 12
      Width = 150
      Height = 17
      Caption = 'Erledigte ausblenden'
      Checked = True
      State = cbChecked
      TabOrder = 2
    end
    object chkMine: TCheckBox
      Left = 540
      Top = 12
      Width = 100
      Height = 17
      Caption = 'Nur meine'
      TabOrder = 3
    end
    object lblPerson: TLabel
      Left = 650
      Top = 14
      Width = 84
      Height = 15
      Caption = 'Verantwortlich'
    end
    object edtPerson: TEdit
      Left = 744
      Top = 10
      Width = 200
      Height = 23
      TabOrder = 4
    end
    object lblSummary: TLabel
      Left = 12
      Top = 48
      Width = 1076
      Height = 36
      Anchors = [akLeft, akTop, akRight]
      AutoSize = False
      Caption = 'Zusammenfassung'
      WordWrap = True
    end
  end
  object sgItems: TStringGrid
    Left = 0
    Top = 96
    Width = 1100
    Height = 476
    Align = alClient
    ColCount = 8
    DefaultRowHeight = 20
    FixedCols = 0
    RowCount = 2
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goColSizing, goRowSelect, goThumbTracking]
    TabOrder = 1
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 572
    Width = 1100
    Height = 48
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object btnOpen: TButton
      Left = 12
      Top = 10
      Width = 160
      Height = 28
      Caption = 'Im Projekt '#246'ffnen'
      Default = True
      TabOrder = 0
    end
    object btnClose: TButton
      Left = 1003
      Top = 10
      Width = 85
      Height = 28
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = 'Schlie'#223'en'
      TabOrder = 1
    end
  end
end
