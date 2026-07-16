object ReportForm: TReportForm
  Left = 0
  Top = 0
  Caption = 'Soll-Ist-Bericht'
  ClientHeight = 600
  ClientWidth = 1000
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 15
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 1000
    Height = 72
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblScope: TLabel
      Left = 12
      Top = 14
      Width = 76
      Height = 15
      Caption = 'Berichtsumfang'
    end
    object cboScope: TComboBox
      Left = 104
      Top = 10
      Width = 400
      Height = 23
      Style = csDropDownList
      TabOrder = 0
      OnChange = cboScopeChange
    end
    object btnRefresh: TButton
      Left = 520
      Top = 9
      Width = 90
      Height = 25
      Caption = 'Aktualisieren'
      TabOrder = 1
      OnClick = btnRefreshClick
    end
    object lblSummary: TLabel
      Left = 12
      Top = 42
      Width = 976
      Height = 15
      Anchors = [akLeft, akTop, akRight]
      AutoSize = False
      Caption = 'Zusammenfassung'
      WordWrap = True
    end
  end
  object sgReport: TStringGrid
    Left = 0
    Top = 72
    Width = 1000
    Height = 480
    Align = alClient
    ColCount = 9
    DefaultRowHeight = 20
    FixedCols = 0
    RowCount = 2
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goRowSelect]
    TabOrder = 1
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 552
    Width = 1000
    Height = 48
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object btnExportCsv: TButton
      Left = 12
      Top = 10
      Width = 140
      Height = 28
      Caption = 'Als CSV exportieren'#8230
      TabOrder = 0
      OnClick = btnExportCsvClick
    end
    object btnExportPdf: TButton
      Left = 160
      Top = 10
      Width = 150
      Height = 28
      Caption = 'Als PDF exportieren'#8230
      TabOrder = 1
      OnClick = btnExportPdfClick
    end
    object btnClose: TButton
      Left = 900
      Top = 10
      Width = 85
      Height = 28
      Anchors = [akTop, akRight]
      Caption = 'Schlie'#223'en'
      TabOrder = 2
      OnClick = btnCloseClick
    end
  end
end
