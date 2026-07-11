package catalog

import (
	"fmt"
	"regexp"
	"strings"

	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/beevik/etree"
)

const (
	StandardITGrundschutz = "IT-Grundschutz"
	DefaultCatalogVersion = "2023"
)

type ImportResult struct {
	CatalogVersion string
	Bausteine      []domain.Baustein
	Requirements   []domain.Requirement
	ErrorMessage   string
	Success        bool
}

var (
	bausteinTitlePattern     = regexp.MustCompile(`^([A-Z]{2,4}(?:\.\d+)+)\s+(.+)$`)
	requirementTitlePattern  = regexp.MustCompile(`^([A-Z]{2,4}(?:\.\d+)+\.A\d+)\s+(.+)$`)
	levelMarkerPattern       = regexp.MustCompile(`\(([BSH])\)`)
	rolePattern              = regexp.MustCompile(`\[([^\]]+)\]`)
	htmlTagPattern           = regexp.MustCompile(`<[^>]+>`)
)

func ImportFromFile(path string) ImportResult {
	result := ImportResult{CatalogVersion: DefaultCatalogVersion}

	doc := etree.NewDocument()
	if err := doc.ReadFromFile(path); err != nil {
		result.ErrorMessage = fmt.Sprintf("Datei konnte nicht gelesen werden: %s (%v)", path, err)
		return result
	}

	root := doc.Root()
	if root == nil || root.Tag != "book" {
		if root != nil {
			result.ErrorMessage = fmt.Sprintf("Unerwartete Wurzel: %s", root.Tag)
		} else {
			result.ErrorMessage = "Leeres XML-Dokument"
		}
		return result
	}

	walkNode(root, "", -1, "", &result)
	result.Success = result.ErrorMessage == ""
	return result
}

func walkNode(node *etree.Element, groupName string, currentBausteinIndex int, currentLevel string, result *ImportResult) {
	if node == nil {
		return
	}

	activeGroup := groupName
	activeBausteinIndex := currentBausteinIndex
	activeLevel := currentLevel

	switch node.Tag {
	case "chapter":
		if title := elementTitle(node); title != "" {
			activeGroup = title
		}
	case "section":
		title := sectionTitle(node)
		if parsed, ok := tryParseBaustein(title, activeGroup); ok {
			result.Bausteine = append(result.Bausteine, parsed)
			activeBausteinIndex = len(result.Bausteine) - 1
			activeLevel = "Unbekannt"
		} else if title == "Anforderungen" {
			activeLevel = "Unbekannt"
		} else {
			if sectionLevel := requirementLevelFromSectionTitle(title); sectionLevel != "" {
				activeLevel = sectionLevel
			}
			if activeBausteinIndex >= 0 {
				if parsed, ok := tryParseRequirement(title, result.Bausteine[activeBausteinIndex], activeLevel, node); ok {
					result.Requirements = append(result.Requirements, parsed)
				}
			}
		}
	}

	for _, child := range node.ChildElements() {
		walkNode(child, activeGroup, activeBausteinIndex, activeLevel, result)
	}
}

func elementTitle(node *etree.Element) string {
	if node == nil || (node.Tag != "section" && node.Tag != "chapter") {
		return ""
	}
	if title := node.SelectElement("title"); title != nil {
		return strings.TrimSpace(title.Text())
	}
	return ""
}

func sectionTitle(node *etree.Element) string {
	return elementTitle(node)
}

func tryParseBaustein(title, groupName string) (domain.Baustein, bool) {
	if requirementTitlePattern.MatchString(title) {
		return domain.Baustein{}, false
	}
	match := bausteinTitlePattern.FindStringSubmatch(title)
	if match == nil {
		return domain.Baustein{}, false
	}
	return domain.Baustein{
		Standard:       StandardITGrundschutz,
		ExternalID:     match[1],
		Title:          strings.TrimSpace(match[2]),
		GroupName:      groupName,
		CatalogVersion: DefaultCatalogVersion,
	}, true
}

func tryParseRequirement(title string, baustein domain.Baustein, level string, sectionNode *etree.Element) (domain.Requirement, bool) {
	match := requirementTitlePattern.FindStringSubmatch(title)
	if match == nil {
		return domain.Requirement{}, false
	}

	reqTitle := strings.TrimSpace(match[2])
	req := domain.Requirement{
		Standard:           StandardITGrundschutz,
		ExternalID:         match[1],
		BausteinExternalID: baustein.ExternalID,
		Title:              reqTitle,
		Text:               strings.Join(collectParagraphs(sectionNode), "\n\n"),
		Withdrawn:          strings.HasPrefix(strings.ToUpper(reqTitle), "ENTFALLEN"),
	}

	if levelMatch := levelMarkerPattern.FindStringSubmatch(title); levelMatch != nil {
		req.Level = requirementLevelFromMarker(levelMatch[1])
	} else {
		req.Level = level
	}
	if req.Level == "" {
		req.Level = "Unbekannt"
	}

	if roleMatch := rolePattern.FindStringSubmatch(title); roleMatch != nil {
		req.ResponsibleRole = strings.TrimSpace(roleMatch[1])
	}
	return req, true
}

func requirementLevelFromSectionTitle(title string) string {
	switch title {
	case "Basis-Anforderungen":
		return "Basis"
	case "Standard-Anforderungen":
		return "Standard"
	case "Anforderungen bei erhöhtem Schutzbedarf":
		return "Erhöht"
	default:
		return ""
	}
}

func requirementLevelFromMarker(marker string) string {
	switch marker {
	case "B":
		return "Basis"
	case "S":
		return "Standard"
	case "H":
		return "Erhöht"
	default:
		return "Unbekannt"
	}
}

func collectParagraphs(node *etree.Element) []string {
	if node == nil {
		return nil
	}
	if node.Tag == "para" {
		text := stripMarkup(collectText(node))
		if text == "" {
			return nil
		}
		return []string{text}
	}
	var paragraphs []string
	for _, child := range node.ChildElements() {
		paragraphs = append(paragraphs, collectParagraphs(child)...)
	}
	return paragraphs
}

func collectText(node *etree.Element) string {
	if node == nil {
		return ""
	}
	var parts []string
	for _, child := range node.Child {
		switch t := child.(type) {
		case *etree.CharData:
			text := strings.TrimSpace(t.Data)
			if text != "" {
				parts = append(parts, text)
			}
		case *etree.Element:
			if t.Tag == "linebreak" {
				parts = append(parts, "\n")
			} else {
				part := collectText(t)
				if part != "" {
					parts = append(parts, part)
				}
			}
		}
	}
	return strings.Join(parts, " ")
}

func stripMarkup(text string) string {
	cleaned := htmlTagPattern.ReplaceAllString(text, "")
	return strings.Join(strings.Fields(cleaned), " ")
}
