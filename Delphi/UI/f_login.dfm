object LoginForm: TLoginForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'ISMS Anmeldung'
  ClientHeight = 320
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
  object pnlMain: TPanel
    Left = 0
    Top = 0
    Width = 420
    Height = 320
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object lblIntro: TLabel
      Left = 16
      Top = 16
      Width = 388
      Height = 30
      AutoSize = False
      Caption = 'Lokaler Modus'
      WordWrap = True
    end
    object chkRemote: TCheckBox
      Left = 16
      Top = 56
      Width = 200
      Height = 17
      Caption = 'Server-Modus (Team)'
      TabOrder = 0
      OnClick = chkRemoteClick
    end
    object lblServer: TLabel
      Left = 16
      Top = 88
      Width = 58
      Height = 15
      Caption = 'Server-URL'
    end
    object edtServer: TEdit
      Left = 16
      Top = 106
      Width = 388
      Height = 23
      TabOrder = 1
      Text = 'http://localhost:8080'
      OnChange = edtServerChange
    end
    object lblEmail: TLabel
      Left = 16
      Top = 136
      Width = 32
      Height = 15
      Caption = 'E-Mail'
    end
    object edtEmail: TEdit
      Left = 16
      Top = 154
      Width = 388
      Height = 23
      TabOrder = 2
    end
    object lblPassword: TLabel
      Left = 16
      Top = 184
      Width = 50
      Height = 15
      Caption = 'Passwort'
    end
    object edtPassword: TEdit
      Left = 16
      Top = 202
      Width = 388
      Height = 23
      PasswordChar = '*'
      TabOrder = 3
    end
    object chkInsecureTls: TCheckBox
      Left = 16
      Top = 232
      Width = 250
      Height = 17
      Caption = 'TLS-Zertifikat nicht pr'#252'fen (Entwicklung)'
      TabOrder = 4
    end
    object btnOk: TButton
      Left = 228
      Top = 272
      Width = 85
      Height = 30
      Caption = 'OK'
      Default = True
      TabOrder = 5
      OnClick = btnOkClick
    end
    object btnCancel: TButton
      Left = 319
      Top = 272
      Width = 85
      Height = 30
      Cancel = True
      Caption = 'Abbrechen'
      ModalResult = 2
      TabOrder = 6
    end
  end
end
