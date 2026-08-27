package httpx

import (
	"encoding/csv"
	"io"
	"strconv"
	"strings"

	"github.com/Target42/BSI/isms-server/internal/domain"
)

func writeSollIstCSV(w io.Writer, rows []domain.ReportRow) error {
	if _, err := w.Write([]byte{0xEF, 0xBB, 0xBF}); err != nil {
		return err
	}
	cw := csv.NewWriter(w)
	cw.Comma = ';'
	cw.UseCRLF = true
	header := []string{
		"Zielobjekt", "Baustein", "Baustein-Titel", "Anforderung", "Titel", "Stufe",
		"Anwendbarkeit", "Status", "Verantwortlich", "Frist", "Maßnahmen", "Überfällig",
	}
	if err := cw.Write(header); err != nil {
		return err
	}
	for _, row := range rows {
		overdue := "Nein"
		if row.Overdue {
			overdue = "Ja"
		}
		record := []string{
			row.TargetObjectName,
			row.BausteinExternalID,
			row.BausteinTitle,
			row.RequirementExternalID,
			row.RequirementTitle,
			row.Level,
			row.Applicability,
			row.Status,
			row.Responsible,
			csvDue(row.DueDate),
			strconv.Itoa(row.MeasureCount),
			overdue,
		}
		if err := cw.Write(record); err != nil {
			return err
		}
	}
	cw.Flush()
	return cw.Error()
}

func csvDue(raw *string) string {
	if raw == nil || *raw == "" {
		return ""
	}
	formatted := formatDueDate(raw)
	if formatted == "—" {
		return ""
	}
	return formatted
}

func csvFileName(projectName string) string {
	name := strings.TrimSpace(projectName)
	if name == "" {
		name = "projekt"
	}
	var b strings.Builder
	lastHyphen := false
	for _, r := range name {
		switch {
		case r >= 'a' && r <= 'z', r >= 'A' && r <= 'Z', r >= '0' && r <= '9':
			b.WriteRune(r)
			lastHyphen = false
		default:
			if !lastHyphen && b.Len() > 0 {
				b.WriteByte('-')
				lastHyphen = true
			}
		}
	}
	out := strings.Trim(b.String(), "-")
	if out == "" {
		out = "projekt"
	}
	return "soll-ist-" + out + ".csv"
}
