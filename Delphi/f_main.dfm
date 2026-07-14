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
  Position = poScreenCenter
  Menu = MainMenu
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  TextHeight = 15
  object splMain: TSplitter
    Left = 320
    Top = 0
    Width = 4
    Height = 831
  end
  object StatusBar: TStatusBar
    Left = 0
    Top = 831
    Width = 1400
    Height = 19
    Panels = <
      item
        Width = 350
      end
      item
        Width = 450
      end>
  end
  object pnlLeft: TPanel
    Left = 0
    Top = 0
    Width = 320
    Height = 831
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 0
    ExplicitHeight = 422
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
        ReadOnly = True
        PopupMenu = mnuTargets
        TabOrder = 1
        OnClick = tvTargetsClick
        OnChange = tvTargetsChange
        OnContextPopup = tvTargetsContextPopup
      end
    end
    object grpBausteine: TGroupBox
      Left = 0
      Top = 280
      Width = 320
      Height = 551
      Align = alClient
      Caption = 'IT-Grundschutz Bausteine'
      TabOrder = 1
      ExplicitHeight = 142
      DesignSize = (
        320
        551)
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
        TabOrder = 2
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
        ReadOnly = True
        TabOrder = 2
        OnChange = tvBausteineChange
        OnClick = tvBausteineClick
        OnContextPopup = tvBausteineContextPopup
        PopupMenu = mnuBaustein
      end
    end
  end
  object pnlCenter: TPanel
    Left = 324
    Top = 0
    Width = 1076
    Height = 831
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object splCenter: TSplitter
      Left = 0
      Top = 220
      Width = 1076
      Height = 4
      Cursor = crVSplit
      Align = alTop
      ExplicitTop = 200
    end
    object grpRequirements: TGroupBox
      Left = 0
      Top = 0
      Width = 1076
      Height = 220
      Align = alTop
      Caption = 'Anforderungen'
      TabOrder = 0
      DesignSize = (
        1076
        220)
      object cboAssignedBausteine: TComboBox
        Left = 8
        Top = 20
        Width = 1060
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        Style = csDropDownList
        TabOrder = 0
        OnChange = cboAssignedBausteineChange
      end
      object sgRequirements: TStringGrid
        Left = 8
        Top = 50
        Width = 1060
        Height = 162
        Anchors = [akLeft, akTop, akRight, akBottom]
        ColCount = 6
        DefaultRowHeight = 20
        FixedCols = 0
        RowCount = 2
        Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goRowSelect]
        TabOrder = 1
        OnSelectCell = sgRequirementsSelectCell
      end
    end
    object pnlDetail: TPanel
      Left = 0
      Top = 224
      Width = 1076
      Height = 607
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 1
      DesignSize = (
        1076
        607)
      object lblStatus: TLabel
        Left = 8
        Top = 108
        Width = 35
        Height = 15
        Caption = 'Status:'
      end
      object reRequirementText: TRichEdit
        Left = 0
        Top = 0
        Width = 1076
        Height = 100
        Align = alTop
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 0
      end
      object cboAssessmentStatus: TComboBox
        Left = 60
        Top = 104
        Width = 140
        Height = 23
        Style = csDropDownList
        TabOrder = 1
        OnChange = cboAssessmentStatusChange
      end
      object edtResponsible: TEdit
        Left = 280
        Top = 104
        Width = 200
        Height = 23
        TabOrder = 2
        TextHint = 'Verantwortlicher'
        OnExit = edtResponsibleExit
      end
      object chkHasDueDate: TCheckBox
        Left = 500
        Top = 106
        Width = 50
        Height = 17
        Caption = 'Frist'
        TabOrder = 3
        OnClick = chkHasDueDateClick
      end
      object dtpDueDate: TDateTimePicker
        Left = 560
        Top = 104
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
        Top = 136
        Width = 1060
        Height = 80
        Anchors = [akLeft, akTop, akRight]
        ScrollBars = ssVertical
        TabOrder = 5
        OnExit = memAssessmentNoteExit
      end
      object grpMeasures: TGroupBox
        Left = 8
        Top = 224
        Width = 1060
        Height = 375
        Anchors = [akLeft, akTop, akRight, akBottom]
        Caption = 'Ma'#223'nahmen'
        TabOrder = 6
        DesignSize = (
          1060
          375)
        object sgMeasures: TStringGrid
          Left = 8
          Top = 20
          Width = 1044
          Height = 315
          Anchors = [akLeft, akTop, akRight, akBottom]
          ColCount = 4
          DefaultRowHeight = 20
          FixedCols = 0
          RowCount = 2
          Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goRowSelect]
          TabOrder = 0
        end
        object btnAddMeasure: TButton
          Left = 8
          Top = 343
          Width = 85
          Height = 25
          Anchors = [akLeft, akBottom]
          Caption = 'Hinzuf'#252'gen'
          TabOrder = 1
          OnClick = DoAddMeasure
        end
        object btnEditMeasure: TButton
          Left = 100
          Top = 343
          Width = 85
          Height = 25
          Anchors = [akLeft, akBottom]
          Caption = 'Bearbeiten'
          TabOrder = 2
          OnClick = DoEditMeasure
        end
        object btnDeleteMeasure: TButton
          Left = 200
          Top = 343
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
        OnClick = DoCloseProject
      end
      object mnuSepSession: TMenuItem
        Caption = '-'
      end
      object mnuRelogin: TMenuItem
        Caption = 'Erneut anmelden'#8230
        OnClick = DoRelogin
      end
      object mnuSwitchUser: TMenuItem
        Caption = 'Abmelden / Benutzer wechseln'#8230
        OnClick = DoSwitchUser
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
        Caption = 'Projekt bearbeiten'#8230
        OnClick = DoEditProject
      end
      object mnuManageMembers: TMenuItem
        Caption = 'Projektmitglieder'#8230
        OnClick = DoManageMembers
      end
      object mnuDeleteProject: TMenuItem
        Caption = 'Projekt l'#246'schen'#8230
        OnClick = DoDeleteProject
      end
      object mnuSep2: TMenuItem
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
