object TextEditorForm: TTextEditorForm
  Left = 0
  Top = 0
  BorderStyle = bsSizeable
  Caption = 'Texteditor'
  ClientHeight = 420
  ClientWidth = 640
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnShow = FormShow
  DesignSize = (
    640
    420)
  PixelsPerInch = 96
  object reText: TRichEdit
    Left = 8
    Top = 8
    Width = 624
    Height = 368
    Anchors = [akLeft, akTop, akRight, akBottom]
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    Lines.Strings = (
      '')
    ParentFont = False
    ScrollBars = ssVertical
    TabOrder = 0
    WantReturns = True
    WordWrap = True
  end
  object btnOk: TButton
    Left = 461
    Top = 386
    Width = 80
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = #220'bernehmen'
    Default = True
    ModalResult = 1
    TabOrder = 1
  end
  object btnCancel: TButton
    Left = 551
    Top = 386
    Width = 80
    Height = 25
    Anchors = [akRight, akBottom]
    Cancel = True
    Caption = 'Abbrechen'
    ModalResult = 2
    TabOrder = 2
  end
end
