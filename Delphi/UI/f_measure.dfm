object MeasureForm: TMeasureForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Ma'#223'nahme'
  ClientHeight = 380
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
  object lblTitle: TLabel
    Left = 16
    Top = 16
    Width = 24
    Height = 15
    Caption = 'Titel'
  end
  object edtTitle: TEdit
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
    Height = 80
    ScrollBars = ssVertical
    TabOrder = 1
  end
  object lblResponsible: TLabel
    Left = 16
    Top = 168
    Width = 82
    Height = 15
    Caption = 'Verantwortlicher'
  end
  object edtResponsible: TEdit
    Left = 16
    Top = 186
    Width = 388
    Height = 23
    TabOrder = 2
  end
  object lblDueDate: TLabel
    Left = 16
    Top = 216
    Width = 25
    Height = 15
    Caption = 'Frist'
  end
  object chkHasDueDate: TCheckBox
    Left = 16
    Top = 234
    Width = 120
    Height = 17
    Caption = 'Frist setzen'
    TabOrder = 3
    OnClick = chkHasDueDateClick
  end
  object dtpDueDate: TDateTimePicker
    Left = 140
    Top = 232
    Width = 150
    Height = 23
    Date = 46086.000000000000000000
    Enabled = False
    Time = 46086.000000000000000000
    TabOrder = 4
  end
  object lblStatus: TLabel
    Left = 16
    Top = 264
    Width = 35
    Height = 15
    Caption = 'Status'
  end
  object cboStatus: TComboBox
    Left = 16
    Top = 282
    Width = 200
    Height = 23
    Style = csDropDownList
    TabOrder = 5
  end
  object btnOk: TButton
    Left = 228
    Top = 332
    Width = 85
    Height = 30
    Caption = 'OK'
    Default = True
    TabOrder = 6
    OnClick = btnOkClick
  end
  object btnCancel: TButton
    Left = 319
    Top = 332
    Width = 85
    Height = 30
    Cancel = True
    Caption = 'Abbrechen'
    ModalResult = 2
    TabOrder = 7
  end
end
