package httpx

import (
	"fmt"
	"net/http"
	"strings"

	"github.com/Target42/BSI/isms-server/internal/auth"
	"github.com/Target42/BSI/isms-server/internal/domain"
)

func (u *webUI) projectSettingsGet(w http.ResponseWriter, r *http.Request) {
	user, project, role, ok := u.projectAccess(w, r, "viewer")
	if !ok {
		return
	}
	u.renderProjectSettings(w, r, user, project, role, "")
}

func (u *webUI) renderProjectSettings(w http.ResponseWriter, r *http.Request, user *auth.Claims, project domain.Project, role, errMsg string) {
	u.render(w, r, "project_settings", webPage{
		DisplayName: displayName(user),
		CanEdit:     roleCanEdit(role),
		CanOwn:      roleCanOwn(role),
		IsMember:    project.IsMember,
		Project:     project,
		Error:       errMsg,
	})
}

func (u *webUI) projectSettingsSave(w http.ResponseWriter, r *http.Request) {
	user, project, role, ok := u.projectAccess(w, r, "editor")
	if !ok {
		return
	}
	if err := r.ParseForm(); err != nil {
		u.renderProjectSettings(w, r, user, project, role, "Ungültige Anfrage.")
		return
	}
	name := strings.TrimSpace(r.FormValue("name"))
	if name == "" {
		u.renderProjectSettings(w, r, user, project, role, "Name ist erforderlich.")
		return
	}
	updated, err := u.store.UpdateProject(r.Context(), domain.Project{
		ID:          project.ID,
		Name:        name,
		Description: strings.TrimSpace(r.FormValue("description")),
		Visibility:  visibilityForSave(project, role, r.FormValue("visibility")),
	})
	if err != nil {
		u.renderProjectSettings(w, r, user, project, role, "Projekt konnte nicht gespeichert werden.")
		return
	}
	http.Redirect(w, r, u.href(fmt.Sprintf("/projects/%d?saved=settings", updated.ID)), http.StatusSeeOther)
}

func (u *webUI) projectDelete(w http.ResponseWriter, r *http.Request) {
	user, project, role, ok := u.projectAccess(w, r, "owner")
	if !ok {
		return
	}
	if err := r.ParseForm(); err != nil {
		u.renderProjectSettings(w, r, user, project, role, "Ungültige Anfrage.")
		return
	}
	confirm := strings.TrimSpace(r.FormValue("confirm"))
	if confirm != project.Name {
		u.renderProjectSettings(w, r, user, project, role, "Zum Löschen den Projektnamen genau so eintragen.")
		return
	}
	if err := u.store.DeleteProject(r.Context(), project.ID); err != nil {
		u.renderProjectSettings(w, r, user, project, role, "Projekt konnte nicht gelöscht werden.")
		return
	}
	http.Redirect(w, r, u.href("/projects?saved=deleted"), http.StatusSeeOther)
}

func visibilityForSave(project domain.Project, role, formValue string) string {
	if roleCanOwn(role) {
		return domain.NormalizeVisibility(formValue)
	}
	return domain.NormalizeVisibility(project.Visibility)
}
