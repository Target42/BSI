object ProjectOpenForm: TProjectOpenForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Projekt '#246'ffnen'
  ClientHeight = 330
  ClientWidth = 520
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 15
  object lblHint: TLabel
    Left = 16
    Top = 16
    Width = 488
    Height = 30
    AutoSize = False
    Caption = 'IT-Grundschutz-Projekte'
    WordWrap = True
  end
  object lstProjects: TListBox
    Left = 16
    Top = 52
    Width = 488
    Height = 220
    ItemHeight = 15
    TabOrder = 0
    OnDblClick = lstProjectsDblClick
  end
  object btnOk: TButton
    Left = 328
    Top = 284
    Width = 85
    Height = 30
    Caption = #214'ffnen'
    Default = True
    TabOrder = 1
    OnClick = btnOkClick
  end
  object btnCancel: TButton
    Left = 419
    Top = 284
    Width = 85
    Height = 30
    Cancel = True
    Caption = 'Abbrechen'
    ModalResult = 2
    TabOrder = 2
  end
end
