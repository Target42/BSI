object BausteinRecommendationForm: TBausteinRecommendationForm
  Left = 0
  Top = 0
  Caption = 'Baustein-Empfehlungen '#252'bernehmen'
  ClientHeight = 520
  ClientWidth = 920
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
    Width = 896
    Height = 60
    Anchors = [akLeft, akTop, akRight]
    AutoSize = False
    WordWrap = True
  end
  object sgRecommendations: TStringGrid
    Left = 12
    Top = 80
    Width = 896
    Height = 360
    Anchors = [akLeft, akTop, akRight, akBottom]
    ColCount = 5
    DefaultRowHeight = 20
    FixedCols = 0
    RowCount = 2
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goRowSelect]
    TabOrder = 0
    OnClick = sgRecommendationsClick
    OnDblClick = sgRecommendationsDblClick
  end
  object lblStatus: TLabel
    Left = 12
    Top = 448
    Width = 70
    Height = 15
    Anchors = [akLeft, akBottom]
    Caption = 'Markieren als:'
  end
  object cboStatus: TComboBox
    Left = 88
    Top = 444
    Width = 180
    Height = 23
    Anchors = [akLeft, akBottom]
    Style = csDropDownList
    TabOrder = 1
  end
  object btnOk: TButton
    Left = 732
    Top = 480
    Width = 80
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = 'OK'
    Default = True
    TabOrder = 2
    OnClick = btnOkClick
  end
  object btnCancel: TButton
    Left = 828
    Top = 480
    Width = 80
    Height = 25
    Anchors = [akRight, akBottom]
    Cancel = True
    Caption = 'Abbrechen'
    ModalResult = 2
    TabOrder = 3
  end
end
