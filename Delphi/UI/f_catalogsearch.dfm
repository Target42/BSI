object CatalogSearchForm: TCatalogSearchForm
  Left = 0
  Top = 0
  Caption = 'Katalog-Volltextsuche'
  ClientHeight = 680
  ClientWidth = 1100
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 15
  object lblHint: TLabel
    Left = 12
    Top = 12
    Width = 1076
    Height = 30
    Anchors = [akLeft, akTop, akRight]
    AutoSize = False
    Caption = 
      'Durchsucht Baustein-Namen, Kapitel und alle Anforderungstexte im ' +
      'IT-Grundschutz-Katalog.'
    WordWrap = True
  end
  object edtSearch: TEdit
    Left = 12
    Top = 48
    Width = 1076
    Height = 23
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 0
    TextHint = 'Suchbegriff eingeben, z. B. Intrusion, Backup, Firewall'#8230
    OnChange = edtSearchChange
  end
  object sgResults: TStringGrid
    Left = 12
    Top = 80
    Width = 1076
    Height = 320
    Anchors = [akLeft, akTop, akRight]
    ColCount = 5
    DefaultRowHeight = 20
    FixedCols = 0
    RowCount = 2
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goRowSelect]
    TabOrder = 1
    OnDblClick = sgResultsDblClick
    OnSelectCell = sgResultsSelectCell
  end
  object rePreview: TRichEdit
    Left = 12
    Top = 408
    Width = 1076
    Height = 232
    Anchors = [akLeft, akTop, akRight, akBottom]
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 2
  end
  object btnOpenBaustein: TButton
    Left = 12
    Top = 648
    Width = 120
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'Baustein '#246'ffnen'#8230
    TabOrder = 3
    OnClick = btnOpenBausteinClick
  end
  object btnClose: TButton
    Left = 1003
    Top = 648
    Width = 85
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = 'Schlie'#223'en'
    TabOrder = 4
    OnClick = btnCloseClick
  end
end
