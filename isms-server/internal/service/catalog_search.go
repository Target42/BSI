package service

import (
	"strings"
	"unicode/utf8"

	"github.com/Target42/BSI/isms-server/internal/domain"
)

const CatalogSearchLimit = 200

type CatalogHit struct {
	BausteinID       int64
	RequirementID    int64
	GroupName        string
	BausteinLabel    string
	RequirementLabel string
	MatchField       string
	Snippet          string
}

func SearchCatalog(bausteine []domain.Baustein, requirements []domain.Requirement, needle string, limit int) ([]CatalogHit, bool) {
	needle = strings.TrimSpace(needle)
	if needle == "" || limit <= 0 {
		return nil, false
	}
	byID := make(map[int64]domain.Baustein, len(bausteine))
	for _, b := range bausteine {
		byID[b.ID] = b
	}
	withReqHit := make(map[int64]bool)
	hits := make([]CatalogHit, 0, 32)
	for _, r := range requirements {
		field, preview := requirementMatch(r, needle)
		if field == "" {
			continue
		}
		b, ok := byID[r.BausteinID]
		if !ok {
			continue
		}
		withReqHit[r.BausteinID] = true
		hits = append(hits, CatalogHit{
			BausteinID:       r.BausteinID,
			RequirementID:    r.ID,
			GroupName:        b.GroupName,
			BausteinLabel:    strings.TrimSpace(b.ExternalID + " " + b.Title),
			RequirementLabel: strings.TrimSpace(r.ExternalID + " " + r.Title),
			MatchField:       field,
			Snippet:          matchSnippet(preview, needle),
		})
		if len(hits) > limit {
			return hits[:limit], true
		}
	}
	for _, b := range bausteine {
		if withReqHit[b.ID] {
			continue
		}
		field, preview := bausteinMatch(b, needle)
		if field == "" {
			continue
		}
		hits = append(hits, CatalogHit{
			BausteinID:       b.ID,
			GroupName:        b.GroupName,
			BausteinLabel:    strings.TrimSpace(b.ExternalID + " " + b.Title),
			RequirementLabel: "—",
			MatchField:       field,
			Snippet:          matchSnippet(preview, needle),
		})
		if len(hits) > limit {
			return hits[:limit], true
		}
	}
	return hits, false
}

func requirementMatch(r domain.Requirement, needle string) (field, preview string) {
	switch {
	case containsFold(r.Text, needle):
		return "Anforderungstext", r.Text
	case containsFold(r.Title, needle):
		return "Anforderungstitel", r.Title
	case containsFold(r.ExternalID, needle):
		return "Anforderungs-ID", r.ExternalID
	case containsFold(r.ResponsibleRole, needle):
		return "Rolle", r.ResponsibleRole
	default:
		return "", ""
	}
}

func bausteinMatch(b domain.Baustein, needle string) (field, preview string) {
	switch {
	case containsFold(b.ExternalID, needle):
		return "Baustein-ID", b.ExternalID
	case containsFold(b.Title, needle):
		return "Baustein-Titel", b.Title
	case containsFold(b.GroupName, needle):
		return "Kapitel", b.GroupName
	default:
		return "", ""
	}
}

func containsFold(haystack, needle string) bool {
	return strings.Contains(strings.ToLower(haystack), strings.ToLower(needle))
}

func matchSnippet(text, needle string) string {
	text = strings.Join(strings.Fields(text), " ")
	if text == "" {
		return ""
	}
	lower := strings.ToLower(text)
	idx := strings.Index(lower, strings.ToLower(needle))
	if idx < 0 {
		return truncateBytes(text, 90)
	}
	start := idx - 45
	if start < 0 {
		start = 0
	}
	end := idx + len(needle) + 45
	if end > len(text) {
		end = len(text)
	}
	start = rewindUTF8(text, start)
	end = advanceUTF8(text, end)
	out := strings.TrimSpace(text[start:end])
	if start > 0 {
		out = "…" + out
	}
	if end < len(text) {
		out += "…"
	}
	return out
}

func truncateBytes(text string, max int) string {
	if len(text) <= max {
		return text
	}
	end := advanceUTF8(text, max)
	return strings.TrimSpace(text[:end]) + "…"
}

func rewindUTF8(s string, i int) int {
	for i > 0 && !utf8.RuneStart(s[i]) {
		i--
	}
	return i
}

func advanceUTF8(s string, i int) int {
	if i >= len(s) {
		return len(s)
	}
	for i < len(s) && !utf8.RuneStart(s[i]) {
		i++
	}
	return i
}
