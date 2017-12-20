object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'MainForm'
  ClientHeight = 524
  ClientWidth = 708
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object BtnSubscribe: TButton
    Left = 8
    Top = 8
    Width = 75
    Height = 25
    Caption = 'Subscribe'
    TabOrder = 0
    OnClick = BtnSubscribeClick
  end
  object BtnUnsubscribe: TButton
    Left = 104
    Top = 8
    Width = 75
    Height = 25
    Caption = 'Unsubscribe'
    Enabled = False
    TabOrder = 1
    OnClick = BtnUnsubscribeClick
  end
  object Content: TMemo
    Left = 0
    Top = 39
    Width = 708
    Height = 485
    Align = alBottom
    Anchors = [akLeft, akTop, akRight, akBottom]
    TabOrder = 2
    ExplicitLeft = 8
  end
end
