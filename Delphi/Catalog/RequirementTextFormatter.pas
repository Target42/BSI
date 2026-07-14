unit RequirementTextFormatter;

interface

uses
  Vcl.ComCtrls, Vcl.Graphics, System.SysUtils, System.RegularExpressions;

type
  TRequirementTextFormatter = class
  public
    class procedure ApplyToRichEdit(ARichEdit: TRichEdit; const AText: string);
  end;

implementation

type
  THighlightRule = record
    Word: string;
    Color: TColor;
    Bold: Boolean;
    Italic: Boolean;
  end;

const
  HIGHLIGHT_RULES: array[0..20] of THighlightRule = (
    (Word: 'MUSS NICHT'; Color: $001C1CB7; Bold: True; Italic: False),
    (Word: 'SOLL NICHT'; Color: $000051E6; Bold: True; Italic: False),
    (Word: 'DARF NICHT'; Color: $00287D2E; Bold: True; Italic: False),
    (Word: 'KÖNNEN NICHT'; Color: $00616161; Bold: False; Italic: True),
    (Word: 'KANN NICHT'; Color: $00616161; Bold: False; Italic: True),
    (Word: 'MÜSSEN'; Color: $002840C6; Bold: True; Italic: False),
    (Word: 'MUSSTEN'; Color: $002840C6; Bold: True; Italic: False),
    (Word: 'MUSSTE'; Color: $002840C6; Bold: True; Italic: False),
    (Word: 'SOLLTEN'; Color: $000051E6; Bold: True; Italic: False),
    (Word: 'SOLLTE'; Color: $000051E6; Bold: True; Italic: False),
    (Word: 'SOLLEN'; Color: $000051E6; Bold: True; Italic: False),
    (Word: 'KÖNNEN'; Color: $00616161; Bold: False; Italic: True),
    (Word: 'KONNTEN'; Color: $00616161; Bold: False; Italic: True),
    (Word: 'KONNTE'; Color: $00616161; Bold: False; Italic: True),
    (Word: 'DÜRFEN'; Color: $00287D2E; Bold: True; Italic: False),
    (Word: 'DURFTEN'; Color: $00287D2E; Bold: True; Italic: False),
    (Word: 'DURFTE'; Color: $00287D2E; Bold: True; Italic: False),
    (Word: 'MUSS'; Color: $002840C6; Bold: True; Italic: False),
    (Word: 'SOLL'; Color: $000051E6; Bold: True; Italic: False),
    (Word: 'KANN'; Color: $00616161; Bold: False; Italic: True),
    (Word: 'DARF'; Color: $00287D2E; Bold: True; Italic: False)
  );

function WordPattern(const AWord: string): string;
begin
  Result := '(?<![A-Za-zÄÖÜäöüß])(' + TRegEx.Escape(AWord) + ')(?![A-Za-zÄÖÜäöüß])';
end;

class procedure TRequirementTextFormatter.ApplyToRichEdit(ARichEdit: TRichEdit; const AText: string);
var
  Rule: THighlightRule;
  Match: TMatch;
  Regex: TRegEx;
  I: Integer;
  Style: TFontStyles;
begin
  ARichEdit.Text := AText;
  ARichEdit.SelStart := 0;
  ARichEdit.SelLength := Length(ARichEdit.Text);
  ARichEdit.SelAttributes.Color := clWindowText;
  ARichEdit.SelAttributes.Style := [];

  for I := Low(HIGHLIGHT_RULES) to High(HIGHLIGHT_RULES) do
  begin
    Rule := HIGHLIGHT_RULES[I];
    Regex := TRegEx.Create(WordPattern(Rule.Word), [roIgnoreCase]);
    Match := Regex.Match(AText);
    while Match.Success do
    begin
      ARichEdit.SelStart := Match.Index;
      ARichEdit.SelLength := Match.Length;
      ARichEdit.SelAttributes.Color := Rule.Color;
      Style := [];
      if Rule.Bold then
        Include(Style, fsBold);
      if Rule.Italic then
        Include(Style, fsItalic);
      ARichEdit.SelAttributes.Style := Style;
      Match := Match.NextMatch;
    end;
  end;
  ARichEdit.SelLength := 0;
end;

end.
