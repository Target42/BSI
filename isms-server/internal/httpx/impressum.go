package httpx

import (
	"net/http"
	"os"
	"strings"
)

// legalNotice holds the operator identity required by § 5 DDG.
// Each deployment names its own operator; the values come from the environment.
type legalNotice struct {
	Name           string
	Street         string
	PostalCode     string
	City           string
	Country        string
	Email          string
	Phone          string
	PhoneHref      string
	Representative string
	Register       string
	VATID          string
	Responsible    string
	Complete       bool
}

func legalNoticeFromEnv() legalNotice {
	notice := legalNotice{
		Name:           strings.TrimSpace(os.Getenv("IMPRESSUM_NAME")),
		Street:         strings.TrimSpace(os.Getenv("IMPRESSUM_STREET")),
		PostalCode:     strings.TrimSpace(os.Getenv("IMPRESSUM_POSTAL_CODE")),
		City:           strings.TrimSpace(os.Getenv("IMPRESSUM_CITY")),
		Country:        strings.TrimSpace(os.Getenv("IMPRESSUM_COUNTRY")),
		Email:          strings.TrimSpace(os.Getenv("IMPRESSUM_EMAIL")),
		Phone:          strings.TrimSpace(os.Getenv("IMPRESSUM_PHONE")),
		Representative: strings.TrimSpace(os.Getenv("IMPRESSUM_REPRESENTATIVE")),
		Register:       strings.TrimSpace(os.Getenv("IMPRESSUM_REGISTER")),
		VATID:          strings.TrimSpace(os.Getenv("IMPRESSUM_VAT_ID")),
		Responsible:    strings.TrimSpace(os.Getenv("IMPRESSUM_RESPONSIBLE")),
	}
	notice.PhoneHref = phoneHref(notice.Phone)
	notice.Complete = notice.Name != "" && notice.Street != "" && notice.PostalCode != "" && notice.City != "" && notice.Email != ""
	return notice
}

func phoneHref(phone string) string {
	var b strings.Builder
	for _, r := range phone {
		if r == '+' || (r >= '0' && r <= '9') {
			b.WriteRune(r)
		}
	}
	return b.String()
}

func (u *webUI) impressumGet(w http.ResponseWriter, r *http.Request) {
	u.render(w, r, "impressum", webPage{Title: "Impressum"})
}
