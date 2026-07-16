object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'ISMS Werkzeug'
  ClientHeight = 850
  ClientWidth = 1400
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Menu = MainMenu
  Position = poScreenCenter
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  TextHeight = 15
  object splMain: TSplitter
    Left = 320
    Top = 29
    Width = 4
    Height = 802
    ExplicitTop = 0
    ExplicitHeight = 831
  end
  object ToolBar: TToolBar
    Left = 0
    Top = 0
    Width = 1400
    Height = 29
    ButtonHeight = 23
    ButtonWidth = 122
    Caption = 'ToolBar'
    ShowCaptions = True
    TabOrder = 2
    object btnToolNewProject: TToolButton
      Left = 0
      Top = 0
      Caption = 'Neues Projekt'
      OnClick = DoCreateProject
    end
    object btnToolOpenProject: TToolButton
      Left = 122
      Top = 0
      Caption = 'Projekt '#246'ffnen'
      OnClick = DoOpenProject
    end
    object btnToolAddTarget: TToolButton
      Left = 244
      Top = 0
      Caption = 'Zielobjekt hinzuf'#252'gen'
      OnClick = DoAddTarget
    end
    object btnToolImportCatalog: TToolButton
      Left = 366
      Top = 0
      Caption = 'Katalog importieren'
      OnClick = DoImportCatalog
    end
  end
  object StatusBar: TStatusBar
    Left = 0
    Top = 831
    Width = 1400
    Height = 19
    Panels = <
      item
        Width = 500
      end
      item
        Width = 450
      end
      item
        Width = 350
      end>
  end
  object pnlLeft: TPanel
    Left = 0
    Top = 29
    Width = 320
    Height = 802
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 0
    object grpTargets: TGroupBox
      Left = 0
      Top = 0
      Width = 320
      Height = 280
      Align = alTop
      Caption = 'Zielobjekte'
      TabOrder = 0
      DesignSize = (
        320
        280)
      object lblProjectProgress: TLabel
        Left = 8
        Top = 20
        Width = 304
        Height = 15
        Anchors = [akLeft, akTop, akRight]
        AutoSize = False
        Caption = 'Kein Projekt ge'#246'ffnet'
        WordWrap = True
      end
      object pbProjectProgress: TProgressBar
        Left = 8
        Top = 38
        Width = 304
        Height = 17
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 0
        Visible = False
      end
      object tvTargets: TTreeView
        Left = 8
        Top = 60
        Width = 304
        Height = 212
        Anchors = [akLeft, akTop, akRight, akBottom]
        HideSelection = False
        Indent = 19
        PopupMenu = mnuTargets
        ReadOnly = True
        TabOrder = 1
        OnChange = tvTargetsChange
        OnClick = tvTargetsClick
        OnContextPopup = tvTargetsContextPopup
      end
    end
    object grpBausteine: TGroupBox
      Left = 0
      Top = 280
      Width = 320
      Height = 522
      Align = alClient
      Caption = 'IT-Grundschutz Bausteine'
      TabOrder = 1
      DesignSize = (
        320
        522)
      object edtBausteinSearch: TEdit
        Left = 8
        Top = 20
        Width = 304
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 0
        TextHint = 'Bausteine durchsuchen'#8230
        OnChange = edtBausteinSearchChange
      end
      object chkFilterApplicable: TCheckBox
        Left = 8
        Top = 48
        Width = 200
        Height = 17
        Caption = 'Nur anwendbare Bausteine'
        TabOrder = 1
        OnClick = chkFilterApplicableClick
      end
      object chkHighlightRecommendations: TCheckBox
        Left = 8
        Top = 68
        Width = 220
        Height = 17
        Caption = 'Empfehlungen hervorheben'
        Checked = True
        State = cbChecked
        TabOrder = 3
        OnClick = chkHighlightRecommendationsClick
      end
      object tvBausteine: TTreeView
        Left = 8
        Top = 92
        Width = 304
        Height = 451
        Anchors = [akLeft, akTop, akRight, akBottom]
        HideSelection = False
        Indent = 19
        PopupMenu = mnuBaustein
        ReadOnly = True
        TabOrder = 2
        OnChange = tvBausteineChange
        OnClick = tvBausteineClick
        OnContextPopup = tvBausteineContextPopup
        OnCustomDrawItem = tvBausteineCustomDrawItem
        OnDblClick = tvBausteineDblClick
      end
    end
  end
  object pnlCenter: TPanel
    Left = 324
    Top = 29
    Width = 1076
    Height = 802
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object splCenter: TSplitter
      Left = 0
      Top = 280
      Width = 1076
      Height = 4
      Cursor = crVSplit
      Align = alTop
    end
    object grpRequirements: TGroupBox
      Left = 0
      Top = 0
      Width = 1076
      Height = 280
      Align = alTop
      Caption = 'Anforderungen'
      TabOrder = 0
      DesignSize = (
        1076
        280)
      object lblTargetProgress: TLabel
        Left = 8
        Top = 20
        Width = 1060
        Height = 30
        Anchors = [akLeft, akTop, akRight]
        AutoSize = False
        WordWrap = True
      end
      object lblBaustein: TLabel
        Left = 8
        Top = 80
        Width = 45
        Height = 15
        Caption = 'Baustein'
      end
      object pbTargetProgress: TProgressBar
        Left = 8
        Top = 52
        Width = 1060
        Height = 17
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 0
        Visible = False
      end
      object cboAssignedBausteine: TComboBox
        Left = 62
        Top = 76
        Width = 1006
        Height = 23
        Style = csDropDownList
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 1
        OnChange = cboAssignedBausteineChange
      end
      object sgRequirements: TStringGrid
        Left = 8
        Top = 106
        Width = 1060
        Height = 166
        Anchors = [akLeft, akTop, akRight, akBottom]
        ColCount = 8
        DefaultRowHeight = 20
        FixedCols = 0
        RowCount = 2
        Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goRowSelect]
        TabOrder = 2
        OnDrawCell = sgRequirementsDrawCell
        OnSelectCell = sgRequirementsSelectCell
      end
    end
    object pnlDetail: TPanel
      Left = 0
      Top = 284
      Width = 1076
      Height = 518
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 1
      DesignSize = (
        1076
        518)
      object lblRequirementText: TLabel
        Left = 8
        Top = 8
        Width = 92
        Height = 15
        Caption = 'Anforderungstext'
      end
      object lblStatus: TLabel
        Left = 8
        Top = 138
        Width = 32
        Height = 15
        Caption = 'Status'
      end
      object lblResponsible: TLabel
        Left = 8
        Top = 168
        Width = 94
        Height = 15
        Caption = 'Umsetzung durch'
      end
      object lblAssessmentNote: TLabel
        Left = 8
        Top = 248
        Width = 60
        Height = 15
        Caption = 'Umsetzung'
      end
      object reRequirementText: TRichEdit
        Left = 8
        Top = 28
        Width = 1060
        Height = 100
        Anchors = [akLeft, akTop, akRight]
        Font.Charset = ANSI_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 0
      end
      object cboAssessmentStatus: TComboBox
        Left = 56
        Top = 134
        Width = 160
        Height = 23
        Style = csDropDownList
        TabOrder = 1
        OnChange = cboAssessmentStatusChange
      end
      object edtResponsible: TEdit
        Left = 8
        Top = 188
        Width = 1060
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 2
        TextHint = 'Verantwortliche Person oder Rolle'
        OnExit = edtResponsibleExit
      end
      object chkHasDueDate: TCheckBox
        Left = 8
        Top = 220
        Width = 80
        Height = 17
        Caption = 'Frist setzen'
        TabOrder = 3
        OnClick = chkHasDueDateClick
      end
      object dtpDueDate: TDateTimePicker
        Left = 96
        Top = 216
        Width = 120
        Height = 23
        Date = 46217.000000000000000000
        Time = 0.696151574076793600
        Enabled = False
        TabOrder = 4
        OnChange = dtpDueDateChange
      end
      object memAssessmentNote: TMemo
        Left = 8
        Top = 268
        Width = 1060
        Height = 80
        Anchors = [akLeft, akTop, akRight]
        ScrollBars = ssVertical
        TabOrder = 5
        OnChange = memAssessmentNoteChange
        OnExit = memAssessmentNoteExit
      end
      object grpMeasures: TGroupBox
        Left = 8
        Top = 356
        Width = 1060
        Height = 154
        Anchors = [akLeft, akTop, akRight, akBottom]
        Caption = 'Ma'#223'nahmen'
        TabOrder = 6
        DesignSize = (
          1060
          154)
        object sgMeasures: TStringGrid
          Left = 8
          Top = 20
          Width = 1044
          Height = 286
          Anchors = [akLeft, akTop, akRight, akBottom]
          ColCount = 4
          DefaultRowHeight = 20
          FixedCols = 0
          RowCount = 2
          Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goRowSelect]
          TabOrder = 0
          OnDblClick = sgMeasuresDblClick
        end
        object btnAddMeasure: TButton
          Left = 8
          Top = 314
          Width = 85
          Height = 25
          Anchors = [akLeft, akBottom]
          Caption = 'Hinzuf'#252'gen'
          TabOrder = 1
          OnClick = DoAddMeasure
        end
        object btnEditMeasure: TButton
          Left = 100
          Top = 314
          Width = 85
          Height = 25
          Anchors = [akLeft, akBottom]
          Caption = 'Bearbeiten'
          TabOrder = 2
          OnClick = DoEditMeasure
        end
        object btnDeleteMeasure: TButton
          Left = 200
          Top = 314
          Width = 75
          Height = 25
          Anchors = [akLeft, akBottom]
          Caption = 'L'#246'schen'
          TabOrder = 3
          OnClick = DoDeleteMeasure
        end
      end
    end
  end
  object MainMenu: TMainMenu
    Left = 40
    Top = 40
    object mnuFile: TMenuItem
      Caption = 'Datei'
      object mnuImportCatalog: TMenuItem
        Caption = 'IT-Grundschutz XML importieren'#8230
        OnClick = DoImportCatalog
      end
      object mnuNewProject: TMenuItem
        Caption = 'Neues Projekt'#8230
        OnClick = DoCreateProject
      end
      object mnuOpenProject: TMenuItem
        Caption = 'Projekt '#246'ffnen'#8230
        OnClick = DoOpenProject
      end
      object mnuCloseProject: TMenuItem
        Caption = 'Projekt schlie'#223'en'
        ShortCut = 49159
        OnClick = DoCloseProject
      end
      object mnuSep1: TMenuItem
        Caption = '-'
      end
      object mnuExit: TMenuItem
        Caption = 'Beenden'
        OnClick = endProgramm
      end
    end
    object mnuProject: TMenuItem
      Caption = 'Projekt'
      object mnuEditProject: TMenuItem
        Caption = 'Projekteigenschaften'#8230
        OnClick = DoEditProject
      end
      object mnuDeleteProject: TMenuItem
        Caption = 'Projekt l'#246'schen'#8230
        OnClick = DoDeleteProject
      end
      object mnuManageMembers: TMenuItem
        Caption = 'Projektmitglieder'#8230
        OnClick = DoManageMembers
      end
      object mnuSwitchUser: TMenuItem
        Caption = 'Abmelden / Benutzer wechseln'#8230
        OnClick = DoSwitchUser
      end
      object mnuRelogin: TMenuItem
        Caption = 'Server-Sitzung erneuern'#8230
        OnClick = DoRelogin
      end
      object mnuSepSession: TMenuItem
        Caption = '-'
      end
      object mnuAddTarget: TMenuItem
        Caption = 'Zielobjekt hinzuf'#252'gen'#8230
        OnClick = DoAddTarget
      end
      object mnuEditTarget: TMenuItem
        Caption = 'Zielobjekt bearbeiten'#8230
        OnClick = DoEditTarget
      end
      object mnuDeleteTarget: TMenuItem
        Caption = 'Zielobjekt l'#246'schen'#8230
        OnClick = DoDeleteTarget
      end
      object mnuSep3: TMenuItem
        Caption = '-'
      end
      object mnuApplyRecommendations: TMenuItem
        Caption = 'Baustein-Empfehlungen '#252'bernehmen'#8230
        OnClick = DoApplyRecommendations
      end
    end
    object mnuReports: TMenuItem
      Caption = 'Berichte'
      object mnuSollIst: TMenuItem
        Caption = 'Soll-Ist-'#220'bersicht'#8230
        OnClick = DoShowSollIstReport
      end
    end
    object mnuCatalog: TMenuItem
      Caption = 'Katalog'
      object mnuViewBaustein: TMenuItem
        Caption = 'Baustein anzeigen'#8230
        OnClick = DoViewBaustein
      end
      object mnuCatalogSearch: TMenuItem
        Caption = 'Volltextsuche'#8230
        ShortCut = 24646
        OnClick = DoCatalogSearch
      end
    end
  end
  object FDGUIxWaitCursor1: TFDGUIxWaitCursor
    Provider = 'Forms'
    Left = 136
    Top = 40
  end
  object mnuBaustein: TPopupMenu
    Left = 200
    Top = 120
    object mniBausteinView: TMenuItem
      Caption = 'Baustein anzeigen'#8230
      OnClick = BausteinViewMenuClick
    end
    object mniBausteinSep1: TMenuItem
      Caption = '-'
    end
    object mniBausteinRequired: TMenuItem
      Caption = 'Ben'#246'tigt'
      OnClick = ApplicabilityRequiredClick
    end
    object mniBausteinPossible: TMenuItem
      Caption = 'M'#246'glicherweise'
      OnClick = ApplicabilityPossibleClick
    end
    object mniBausteinNotApplicable: TMenuItem
      Caption = 'Nicht relevant'
      OnClick = ApplicabilityNotApplicableClick
    end
    object mniBausteinSep2: TMenuItem
      Caption = '-'
    end
    object mniBausteinReset: TMenuItem
      Caption = 'Zur'#252'cksetzen'
      OnClick = ApplicabilityResetClick
    end
  end
  object mnuTargets: TPopupMenu
    Left = 264
    Top = 120
    object mniTargetAdd: TMenuItem
      Caption = 'Zielobjekt hinzuf'#252'gen'#8230
      OnClick = DoAddTarget
    end
    object mniTargetEdit: TMenuItem
      Caption = 'Zielobjekt bearbeiten'#8230
      OnClick = DoEditTarget
    end
    object mniTargetDelete: TMenuItem
      Caption = 'Zielobjekt l'#246'schen'#8230
      OnClick = DoDeleteTarget
    end
    object mniTargetSep: TMenuItem
      Caption = '-'
    end
    object mniTargetRecommendations: TMenuItem
      Caption = 'Baustein-Empfehlungen '#252'bernehmen'#8230
      OnClick = DoApplyRecommendations
    end
  end
end
