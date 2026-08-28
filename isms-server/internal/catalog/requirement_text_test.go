package catalog

import (
	"strings"
	"testing"
)

func TestFormatRequirementHTMLHighlightsModalVerbs(t *testing.T) {
	got := FormatRequirementHTML("Der IT-Betrieb MUSS Server härten. Abweichungen SOLLEN begründet werden.")
	if !strings.Contains(got, `class="kw-must">MUSS</span>`) {
		t.Fatalf("MUSS: %s", got)
	}
	if !strings.Contains(got, `class="kw-should">SOLLEN</span>`) {
		t.Fatalf("SOLLEN: %s", got)
	}
}

func TestFormatRequirementHTMLLongerPhraseFirst(t *testing.T) {
	got := FormatRequirementHTML("Die Verarbeitung MUSS NICHT protokolliert werden.")
	if strings.Contains(got, `class="kw-must">MUSS</span>`) {
		t.Fatalf("MUSS should not split MUSS NICHT: %s", got)
	}
	if !strings.Contains(got, `class="kw-must-not">MUSS NICHT</span>`) {
		t.Fatalf("MUSS NICHT: %s", got)
	}
}

func TestFormatRequirementHTMLWordBoundaryAndEscape(t *testing.T) {
	got := FormatRequirementHTML("MUSTER <script> MUSS und KÖNNEN")
	if strings.Contains(got, ">MUSTER</span>") {
		t.Fatalf("MUSTER must not match MUSS: %s", got)
	}
	if strings.Contains(got, "<script>") {
		t.Fatalf("must escape HTML: %s", got)
	}
	if !strings.Contains(got, `class="kw-can">KÖNNEN</span>`) {
		t.Fatalf("KÖNNEN: %s", got)
	}
}

func TestFormatRequirementHTMLEmpty(t *testing.T) {
	if got := FormatRequirementHTML(""); got != "" {
		t.Fatalf("got %q", got)
	}
}
