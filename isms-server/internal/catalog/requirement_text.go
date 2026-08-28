package catalog

import (
	"html"
	"strings"
)

type highlightRule struct {
	word  string
	class string
}

// Longer phrases first so SOLLTE is not split into SOLL + TE.
var requirementHighlightRules = []highlightRule{
	{"MUSS NICHT", "kw-must-not"},
	{"SOLL NICHT", "kw-should"},
	{"DARF NICHT", "kw-may"},
	{"KÖNNEN NICHT", "kw-can"},
	{"KANN NICHT", "kw-can"},
	{"MÜSSEN", "kw-must"},
	{"MUSSTEN", "kw-must"},
	{"MUSSTE", "kw-must"},
	{"SOLLTEN", "kw-should"},
	{"SOLLTE", "kw-should"},
	{"SOLLEN", "kw-should"},
	{"KÖNNEN", "kw-can"},
	{"KONNTEN", "kw-can"},
	{"KONNTE", "kw-can"},
	{"DÜRFEN", "kw-may"},
	{"DURFTEN", "kw-may"},
	{"DURFTE", "kw-may"},
	{"MUSS", "kw-must"},
	{"SOLL", "kw-should"},
	{"KANN", "kw-can"},
	{"DARF", "kw-may"},
}

type highlightSpan struct {
	start int
	end   int
	class string
}

func FormatRequirementHTML(text string) string {
	if text == "" {
		return ""
	}
	spans := findRequirementHighlights(text)
	var b strings.Builder
	pos := 0
	for _, span := range spans {
		b.WriteString(html.EscapeString(text[pos:span.start]))
		b.WriteString(`<span class="`)
		b.WriteString(span.class)
		b.WriteString(`">`)
		b.WriteString(html.EscapeString(text[span.start:span.end]))
		b.WriteString(`</span>`)
		pos = span.end
	}
	b.WriteString(html.EscapeString(text[pos:]))
	return b.String()
}

func findRequirementHighlights(text string) []highlightSpan {
	runes := []rune(text)
	claimed := make([]bool, len(runes))
	var spans []highlightSpan
	for _, rule := range requirementHighlightRules {
		word := []rune(rule.word)
		if len(word) == 0 || len(word) > len(runes) {
			continue
		}
		for i := 0; i <= len(runes)-len(word); i++ {
			if claimed[i] {
				continue
			}
			if i > 0 && isRequirementWordChar(runes[i-1]) {
				continue
			}
			if i+len(word) < len(runes) && isRequirementWordChar(runes[i+len(word)]) {
				continue
			}
			if !equalFoldRunes(runes[i:i+len(word)], word) {
				continue
			}
			overlap := false
			for j := 0; j < len(word); j++ {
				if claimed[i+j] {
					overlap = true
					break
				}
			}
			if overlap {
				continue
			}
			for j := 0; j < len(word); j++ {
				claimed[i+j] = true
			}
			startBytes := len(string(runes[:i]))
			endBytes := startBytes + len(string(runes[i:i+len(word)]))
			spans = append(spans, highlightSpan{start: startBytes, end: endBytes, class: rule.class})
		}
	}
	sortSpans(spans)
	return spans
}

func sortSpans(spans []highlightSpan) {
	for i := 1; i < len(spans); i++ {
		for j := i; j > 0 && spans[j].start < spans[j-1].start; j-- {
			spans[j], spans[j-1] = spans[j-1], spans[j]
		}
	}
}

func equalFoldRunes(a, b []rune) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if toRequirementLower(a[i]) != toRequirementLower(b[i]) {
			return false
		}
	}
	return true
}

func toRequirementLower(r rune) rune {
	switch r {
	case 'Ä':
		return 'ä'
	case 'Ö':
		return 'ö'
	case 'Ü':
		return 'ü'
	}
	if r >= 'A' && r <= 'Z' {
		return r + ('a' - 'A')
	}
	return r
}

func isRequirementWordChar(r rune) bool {
	switch {
	case r >= 'A' && r <= 'Z', r >= 'a' && r <= 'z':
		return true
	case r == 'Ä' || r == 'Ö' || r == 'Ü' || r == 'ä' || r == 'ö' || r == 'ü' || r == 'ß':
		return true
	default:
		return false
	}
}
