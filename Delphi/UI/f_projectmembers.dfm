object ProjectMembersForm: TProjectMembersForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Projektmitglieder'
  ClientHeight = 520
  ClientWidth = 720
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 15
  object lblIntro: TLabel
    Left = 16
    Top = 16
    Width = 688
    Height = 30
    AutoSize = False
    WordWrap = True
  end
  object sgMembers: TStringGrid
    Left = 16
    Top = 56
    Width = 688
    Height = 220
    ColCount = 3
    DefaultRowHeight = 22
    FixedCols = 0
    RowCount = 2
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goRowSelect]
    TabOrder = 0
    OnSelectCell = sgMembersSelectCell
    ColWidths = (
      200
      280
      120)
  end
  object btnChangeRole: TButton
    Left = 16
    Top = 288
    Width = 120
    Height = 25
    Caption = 'Rolle '#228'ndern'#8230
    TabOrder = 1
    OnClick = btnChangeRoleClick
  end
  object btnRemove: TButton
    Left = 142
    Top = 288
    Width = 100
    Height = 25
    Caption = 'Entfernen'
    TabOrder = 2
    OnClick = btnRemoveClick
  end
  object btnCreateUser: TButton
    Left = 504
    Top = 288
    Width = 200
    Height = 25
    Caption = 'Neuen Benutzer anlegen'#8230
    TabOrder = 3
    OnClick = btnCreateUserClick
  end
  object grpAdd: TGroupBox
    Left = 16
    Top = 324
    Width = 688
    Height = 148
    Caption = 'Mitglied hinzuf'#252'gen'
    TabOrder = 4
    object lblEmail: TLabel
      Left = 12
      Top = 24
      Width = 32
      Height = 15
      Caption = 'E-Mail'
    end
    object edtEmail: TEdit
      Left = 12
      Top = 42
      Width = 664
      Height = 23
      TabOrder = 0
      TextHint = 'kollege@example.com'
    end
    object lblUserPicker: TLabel
      Left = 12
      Top = 72
      Width = 78
      Height = 15
      Caption = 'Benutzer w'#228'hlen'
    end
    object cboUserPicker: TComboBox
      Left = 12
      Top = 90
      Width = 664
      Height = 23
      Style = csDropDownList
      TabOrder = 1
      OnChange = cboUserPickerChange
    end
    object lblRole: TLabel
      Left = 12
      Top = 120
      Width = 25
      Height = 15
      Caption = 'Rolle'
    end
    object cboRole: TComboBox
      Left = 60
      Top = 118
      Width = 180
      Height = 23
      Style = csDropDownList
      TabOrder = 2
    end
    object btnAdd: TButton
      Left = 580
      Top = 116
      Width = 96
      Height = 25
      Caption = 'Hinzuf'#252'gen'
      TabOrder = 3
      OnClick = btnAddClick
    end
  end
  object btnClose: TButton
    Left = 619
    Top = 484
    Width = 85
    Height = 30
    Cancel = True
    Caption = 'Schlie'#223'en'
    ModalResult = 2
    TabOrder = 5
  end
end
