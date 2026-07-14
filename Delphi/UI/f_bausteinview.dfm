object BausteinViewForm: TBausteinViewForm
  Left = 0
  Top = 0
  Caption = 'Baustein'
  ClientHeight = 640
  ClientWidth = 980
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 15
  object lblHeader: TLabel
    Left = 12
    Top = 12
    Width = 956
    Height = 30
    Anchors = [akLeft, akTop, akRight]
    AutoSize = False
    WordWrap = True
  end
  object edtSearch: TEdit
    Left = 12
    Top = 48
    Width = 956
    Height = 23
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 0
    TextHint = 'In Anforderungen suchen'#8230
    OnChange = edtSearchChange
  end
  object sgRequirements: TStringGrid
    Left = 12
    Top = 80
    Width = 956
    Height = 220
    Anchors = [akLeft, akTop, akRight]
    ColCount = 4
    DefaultRowHeight = 20
    FixedCols = 0
    RowCount = 2
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goRowSelect]
    TabOrder = 1
    OnSelectCell = sgRequirementsSelectCell
  end
  object reRequirementText: TRichEdit
    Left = 12
    Top = 308
    Width = 956
    Height = 288
    Anchors = [akLeft, akTop, akRight, akBottom]
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 2
  end
  object btnClose: TButton
    Left = 883
    Top = 604
    Width = 85
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = 'Schlie'#223'en'
    TabOrder = 3
    OnClick = btnCloseClick
  end
end
