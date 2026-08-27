package service

import (
	"sort"
	"strings"

	"github.com/Target42/BSI/isms-server/internal/domain"
)

const (
	TierCore          = "Kern"
	TierSupplementary = "Ergänzend"
	StatusRequired    = "Benötigt"
	StatusPossible    = "Möglicherweise"
)

type Recommendation struct {
	BausteinID      int64
	ExternalID      string
	Title           string
	GroupName       string
	Tier            string
	SuggestedStatus string
	Reason          string
}

type prefixRule struct {
	prefix string
	tier   string
	status string
	reason string
}

func BausteinPrefix(externalID string) string {
	id := strings.TrimSpace(externalID)
	dot := strings.Index(id, ".")
	if dot <= 0 {
		return strings.ToUpper(id)
	}
	return strings.ToUpper(id[:dot])
}

func BuildRecommendations(bausteine []domain.Baustein, target domain.TargetObject) []Recommendation {
	best := map[string]prefixRule{}
	for _, rule := range rulesForTarget(target) {
		best[rule.prefix] = rule
	}

	byID := make(map[int64]Recommendation)
	for _, b := range bausteine {
		rule, ok := best[BausteinPrefix(b.ExternalID)]
		if !ok {
			continue
		}
		rec := Recommendation{
			BausteinID:      b.ID,
			ExternalID:      b.ExternalID,
			Title:           b.Title,
			GroupName:       b.GroupName,
			Tier:            rule.tier,
			SuggestedStatus: rule.status,
			Reason:          rule.reason,
		}
		if b.GroupName != "" {
			rec.Reason = rule.reason + " (" + b.GroupName + ")"
		}
		existing, found := byID[b.ID]
		if !found || (existing.Tier == TierSupplementary && rec.Tier == TierCore) {
			byID[b.ID] = rec
		}
	}

	out := make([]Recommendation, 0, len(byID))
	for _, rec := range byID {
		out = append(out, rec)
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].Tier != out[j].Tier {
			return out[i].Tier == TierCore
		}
		return out[i].ExternalID < out[j].ExternalID
	})
	return out
}

func RecommendationHint(target domain.TargetObject) string {
	rules := rulesForTarget(target)
	if len(rules) == 0 {
		return ""
	}
	core := uniquePrefixes(rules, TierCore)
	extra := uniquePrefixes(rules, TierSupplementary)
	var b strings.Builder
	b.WriteString("Kern-Bausteine: ")
	b.WriteString(strings.Join(core, ", "))
	if len(extra) > 0 {
		b.WriteString("\nErgänzende Bausteine: ")
		b.WriteString(strings.Join(extra, ", "))
	}
	need := target.ProtectionNeed
	if need == "" {
		need = domain.NeedNormal
	}
	b.WriteString("\nSchutzbedarf: ")
	b.WriteString(need)
	if target.ProtectionNeed == domain.NeedElevated {
		b.WriteString("\nBei erhöhtem Schutzbedarf werden zusätzliche Bausteine (z. B. DER) empfohlen.")
	}
	return b.String()
}

func uniquePrefixes(rules []prefixRule, tier string) []string {
	seen := map[string]bool{}
	var out []string
	for _, rule := range rules {
		if rule.tier != tier || seen[rule.prefix] {
			continue
		}
		seen[rule.prefix] = true
		out = append(out, rule.prefix)
	}
	return out
}

func addRule(rules []prefixRule, prefix, tier, status, reason string) []prefixRule {
	for _, existing := range rules {
		if existing.prefix == prefix {
			return rules
		}
	}
	return append(rules, prefixRule{prefix: prefix, tier: tier, status: status, reason: reason})
}

func addCore(rules []prefixRule, prefixes []string, reason string) []prefixRule {
	for _, prefix := range prefixes {
		rules = addRule(rules, prefix, TierCore, StatusRequired, reason)
	}
	return rules
}

func addSupplementary(rules []prefixRule, prefixes []string, reason, status string) []prefixRule {
	for _, prefix := range prefixes {
		rules = addRule(rules, prefix, TierSupplementary, status, reason)
	}
	return rules
}

func rulesForTarget(target domain.TargetObject) []prefixRule {
	elevated := target.ProtectionNeed == domain.NeedElevated
	var rules []prefixRule
	switch domain.NormalizeTargetObjectType(target.Type) {
	case domain.TargetTypeScope:
		rules = addCore(rules, []string{"ISMS", "ORP", "CON"},
			"Organisationsweite Grundbausteine für den Informationsverbund")
		rules = addSupplementary(rules, []string{"OPS"},
			"Betriebliche Querschnittsaspekte im Gesamtverbund", StatusPossible)
		if elevated {
			rules = addSupplementary(rules, []string{"DER"},
				"Erkennung und Reaktion bei erhöhtem Schutzbedarf", StatusRequired)
		}
	case domain.TargetTypeProcess:
		rules = addCore(rules, []string{"ORP", "OPS"},
			"Organisation, Personal und Betrieb für Geschäftsprozesse")
		rules = addSupplementary(rules, []string{"CON"},
			"Übergreifende Konfiguration und Steuerung", StatusPossible)
		if elevated {
			rules = addSupplementary(rules, []string{"DER", "ISMS"},
				"Zusätzliche Schutz- und Steuerungsaspekte bei erhöhtem Schutzbedarf", StatusPossible)
		}
	case domain.TargetTypeApplication:
		rules = addCore(rules, []string{"APP"},
			"Anwendungsspezifische IT-Grundschutz-Bausteine")
		rules = addSupplementary(rules, []string{"OPS", "CON"},
			"Betrieb und Konfiguration der Anwendungsumgebung", StatusPossible)
		if elevated {
			rules = addSupplementary(rules, []string{"DER", "SYS"},
				"System- und Reaktionsaspekte bei erhöhtem Schutzbedarf", StatusPossible)
		}
	case domain.TargetTypeITSystem:
		rules = addCore(rules, []string{"SYS", "OPS"},
			"System- und Betriebsbausteine für IT-Systeme")
		rules = addSupplementary(rules, []string{"CON", "NET"},
			"Einbindung in Konfiguration und Netzwerk", StatusPossible)
		rules = addSupplementary(rules, []string{"IND"},
			"Industrielle oder spezialisierte Systemumgebungen", StatusPossible)
		if elevated {
			rules = addSupplementary(rules, []string{"DER"},
				"Erkennung und Reaktion bei erhöhtem Schutzbedarf", StatusRequired)
		}
	case domain.TargetTypeNetwork:
		rules = addCore(rules, []string{"NET"},
			"Netz- und Kommunikationsbausteine")
		rules = addSupplementary(rules, []string{"INF", "OPS", "CON"},
			"Infrastruktur, Betrieb und Konfiguration der Verbindung", StatusPossible)
		if elevated {
			rules = addSupplementary(rules, []string{"DER"},
				"Überwachung und Reaktion bei erhöhtem Schutzbedarf", StatusRequired)
		}
	case domain.TargetTypeInfrastructure:
		rules = addCore(rules, []string{"INF"},
			"Infrastrukturbausteine für Räume, Gebäude und Anlagen")
		rules = addSupplementary(rules, []string{"NET", "OPS", "IND"},
			"Anbindung, Betrieb und spezialisierte Infrastruktur", StatusPossible)
		if elevated {
			rules = addSupplementary(rules, []string{"DER", "CON"},
				"Zusätzliche Schutz- und Steuerungsaspekte bei erhöhtem Schutzbedarf", StatusPossible)
		}
	}
	return rules
}
