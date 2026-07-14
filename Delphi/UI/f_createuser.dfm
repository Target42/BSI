object CreateUserForm: TCreateUserForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Neuen Benutzer anlegen'
  ClientHeight = 320
  ClientWidth = 460
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 15
  object lblIntro: TLabel
    Left = 16
    Top = 16
    Width = 428
    Height = 30
    AutoSize = False
    Caption = 
      'Legt einen Server-Benutzer an, der anschlie'#223'end Projekten zugewiesen' +
      ' werden kann.'
    WordWrap = True
  end
  object lblEmail: TLabel
    Left = 16
    Top = 56
    Width = 32
    Height = 15
    Caption = 'E-Mail'
  end
  object edtEmail: TEdit
    Left = 16
    Top = 74
    Width = 428
    Height = 23
    TabOrder = 0
    TextHint = 'kollege@example.com'
  end
  object lblDisplayName: TLabel
    Left = 16
    Top = 104
    Width = 72
    Height = 15
    Caption = 'Anzeigename'
  end
  object edtDisplayName: TEdit
    Left = 16
    Top = 122
    Width = 428
    Height = 23
    TabOrder = 1
  end
  object lblPassword: TLabel
    Left = 16
    Top = 152
    Width = 50
    Height = 15
    Caption = 'Passwort'
  end
  object edtPassword: TEdit
    Left = 16
    Top = 170
    Width = 428
    Height = 23
    PasswordChar = '*'
    TabOrder = 2
  end
  object lblConfirmPassword: TLabel
    Left = 16
    Top = 200
    Width = 103
    Height = 15
    Caption = 'Passwort best'#228'tigen'
  end
  object edtConfirmPassword: TEdit
    Left = 16
    Top = 218
    Width = 428
    Height = 23
    PasswordChar = '*'
    TabOrder = 3
  end
  object chkAdmin: TCheckBox
    Left = 16
    Top = 248
    Width = 200
    Height = 17
    Caption = 'Server-Administrator'
    TabOrder = 4
  end
  object btnOk: TButton
    Left = 268
    Top = 280
    Width = 85
    Height = 30
    Caption = 'OK'
    Default = True
    TabOrder = 5
    OnClick = btnOkClick
  end
  object btnCancel: TButton
    Left = 359
    Top = 280
    Width = 85
    Height = 30
    Cancel = True
    Caption = 'Abbrechen'
    ModalResult = 2
    TabOrder = 6
  end
end
