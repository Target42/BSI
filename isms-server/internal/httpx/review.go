package httpx

import (
	"errors"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/Target42/BSI/isms-server/internal/auth"
	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/Target42/BSI/isms-server/internal/notify"
	"github.com/Target42/BSI/isms-server/internal/repository"
)

type reviewActionRequest struct {
	Action         string  `json:"action"`
	Note           string  `json:"note"`
	RequirementIDs []int64 `json:"requirementIds"`
}

func applyBausteinReview(
	r *http.Request,
	store *repository.Store,
	project domain.Project,
	role string,
	userID, targetObjectID, bausteinID int64,
	action, note string,
	requirementIDs []int64,
) (domain.BausteinReview, error) {
	own, err := store.ApplicabilityMap(r.Context(), project.ID, targetObjectID)
	if err != nil {
		return domain.BausteinReview{}, err
	}
	if !domain.ApplicabilityCountsForReport(own[bausteinID]) {
		return domain.BausteinReview{}, domain.ErrReviewNotApplicable
	}
	current, err := store.GetBausteinReview(r.Context(), project.ID, targetObjectID, bausteinID)
	if err != nil {
		return domain.BausteinReview{}, err
	}
	action = strings.TrimSpace(action)
	if action == domain.ReviewActionReturn || action == domain.ReviewActionAccept {
		if !domain.ReviewAssignmentAllows(current.AssignedReviewerID, userID, role) {
			return domain.BausteinReview{}, domain.ErrForbiddenReview
		}
	}
	next, err := domain.ReviewTransition(project.WorkflowEnabled, current.State, action, role, note)
	if err != nil {
		return domain.BausteinReview{}, err
	}
	fromState := domain.NormalizeReviewState(current.State)
	now := time.Now().UTC()
	current.State = next
	switch strings.TrimSpace(action) {
	case domain.ReviewActionSubmit:
		current.SubmittedBy = userID
		current.SubmittedAt = &now
		current.ReviewedBy = 0
		current.ReviewedAt = nil
		current.ReviewNote = ""
		current.ReturnedRequirementIDs = nil
	case domain.ReviewActionReturn:
		ids := domain.NormalizeReturnedRequirementIDs(requirementIDs)
		if len(ids) > 0 {
			reqs, err := store.ListRequirements(r.Context(), bausteinID)
			if err != nil {
				return domain.BausteinReview{}, err
			}
			allowed := make([]int64, 0, len(reqs))
			for _, req := range reqs {
				if !req.Withdrawn {
					allowed = append(allowed, req.ID)
				}
			}
			if err := domain.ValidateReturnedRequirementIDs(ids, allowed); err != nil {
				return domain.BausteinReview{}, err
			}
		}
		current.ReviewedBy = userID
		current.ReviewedAt = &now
		current.ReviewNote = strings.TrimSpace(note)
		current.ReturnedRequirementIDs = ids
	case domain.ReviewActionAccept:
		current.ReviewedBy = userID
		current.ReviewedAt = &now
		current.ReviewNote = ""
		current.ReturnedRequirementIDs = nil
	}
	event := domain.BausteinReviewEvent{
		ProjectID:              project.ID,
		TargetObjectID:         targetObjectID,
		BausteinID:             bausteinID,
		Action:                 action,
		FromState:              fromState,
		ToState:                next,
		Note:                   current.ReviewNote,
		ReturnedRequirementIDs: current.ReturnedRequirementIDs,
		ActorID:                userID,
	}
	return store.SaveBausteinReviewWithEvent(r.Context(), current, event)
}

func assignBausteinReviewer(
	r *http.Request,
	store *repository.Store,
	project domain.Project,
	targetObjectID, bausteinID, reviewerID int64,
) (domain.BausteinReview, error) {
	own, err := store.ApplicabilityMap(r.Context(), project.ID, targetObjectID)
	if err != nil {
		return domain.BausteinReview{}, err
	}
	if !domain.ApplicabilityCountsForReport(own[bausteinID]) {
		return domain.BausteinReview{}, domain.ErrReviewNotApplicable
	}
	reviewerID, name, err := store.ResolveAssignedReviewer(r.Context(), project.ID, reviewerID)
	if err != nil {
		return domain.BausteinReview{}, err
	}
	current, err := store.GetBausteinReview(r.Context(), project.ID, targetObjectID, bausteinID)
	if err != nil {
		return domain.BausteinReview{}, err
	}
	current.AssignedReviewerID = reviewerID
	current.AssignedReviewerName = name
	return store.SaveBausteinReview(r.Context(), current)
}

func mapReviewError(w http.ResponseWriter, err error) bool {
	switch {
	case errors.Is(err, domain.ErrWorkflowDisabled):
		writeError(w, http.StatusBadRequest, "workflow_disabled")
	case errors.Is(err, domain.ErrInvalidReviewAction):
		writeError(w, http.StatusBadRequest, "invalid_review_action")
	case errors.Is(err, domain.ErrReviewNoteRequired):
		writeError(w, http.StatusBadRequest, "review_note_required")
	case errors.Is(err, domain.ErrInvalidReturnedRequirements):
		writeError(w, http.StatusBadRequest, "invalid_returned_requirements")
	case errors.Is(err, domain.ErrReviewNotApplicable), errors.Is(err, domain.ErrReviewInherited):
		writeError(w, http.StatusConflict, "baustein_not_applicable")
	case errors.Is(err, domain.ErrInvalidReviewTransition):
		writeError(w, http.StatusConflict, "invalid_review_transition")
	case errors.Is(err, domain.ErrReviewLocked):
		writeError(w, http.StatusConflict, "review_locked")
	case errors.Is(err, domain.ErrForbiddenReview), errors.Is(err, repository.ErrForbidden):
		writeError(w, http.StatusForbidden, "forbidden")
	case errors.Is(err, domain.ErrInvalidReviewer):
		writeError(w, http.StatusBadRequest, "invalid_reviewer")
	default:
		return false
	}
	return true
}

func reviewLockMessage(state string) string {
	switch domain.NormalizeReviewState(state) {
	case domain.ReviewSubmitted:
		return "Dieser Baustein ist zur Prüfung eingereicht und kann nicht geändert werden."
	case domain.ReviewAccepted:
		return "Dieser Baustein ist abgenommen und kann nicht geändert werden."
	case domain.ReviewReturned:
		return "Nur die zurückgegebenen Anforderungen können bearbeitet werden."
	default:
		return "Dieser Baustein ist gesperrt."
	}
}

func reviewActionMessage(action string) string {
	switch strings.TrimSpace(action) {
	case domain.ReviewActionSubmit:
		return "Baustein zur Prüfung eingereicht."
	case domain.ReviewActionReturn:
		return "Baustein zurückgegeben."
	case domain.ReviewActionAccept:
		return "Baustein abgenommen."
	default:
		return "Laufzettel gespeichert."
	}
}

func reviewWebError(err error) string {
	switch {
	case errors.Is(err, domain.ErrWorkflowDisabled):
		return "Der Prüfkreislauf ist für dieses Projekt ausgeschaltet."
	case errors.Is(err, domain.ErrReviewNoteRequired):
		return "Bitte eine Begründung für die Rückgabe eintragen."
	case errors.Is(err, domain.ErrInvalidReturnedRequirements):
		return "Bitte nur Anforderungen dieses Bausteins zurückgeben."
	case errors.Is(err, domain.ErrInvalidReviewTransition):
		return "Diese Aktion ist im aktuellen Laufzettel-Zustand nicht möglich."
	case errors.Is(err, domain.ErrForbiddenReview):
		return "Dafür fehlt die Berechtigung."
	case errors.Is(err, domain.ErrInvalidReviewer):
		return "Bitte einen Prüfer oder Besitzer des Projekts zuweisen."
	case errors.Is(err, domain.ErrReviewNotApplicable), errors.Is(err, domain.ErrReviewInherited):
		return "Nur eigene, anwendbare Bausteine können eingereicht werden."
	case errors.Is(err, domain.ErrReviewLocked):
		return reviewLockMessage(domain.ReviewSubmitted)
	default:
		return "Laufzettel konnte nicht gespeichert werden."
	}
}

func notifyAfterReview(n *notify.Service, r *http.Request, project domain.Project, targetID, bausteinID int64, action string, user *auth.Claims, item domain.BausteinReview) {
	if n == nil || r == nil || user == nil {
		return
	}
	if err := n.OnReview(r.Context(), notify.Event{
		Project:        project,
		TargetObjectID: targetID,
		BausteinID:     bausteinID,
		Action:         action,
		ActorID:        user.UserID,
		ActorName:      user.DisplayName,
		Review:         item,
	}); err != nil {
		slog.Error("review notification failed", "err", err, "action", action, "projectId", project.ID)
	}
}
