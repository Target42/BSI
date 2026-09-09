package domain

import (
	"errors"
	"sort"
	"strings"
	"time"
)

const (
	ReviewInProgress = "in_progress"
	ReviewSubmitted  = "submitted"
	ReviewReturned   = "returned"
	ReviewAccepted   = "accepted"

	ReviewActionSubmit = "submit"
	ReviewActionReturn = "return"
	ReviewActionAccept = "accept"
)

var (
	ErrWorkflowDisabled            = errors.New("workflow disabled")
	ErrInvalidReviewAction         = errors.New("invalid review action")
	ErrInvalidReviewTransition     = errors.New("invalid review transition")
	ErrReviewNoteRequired          = errors.New("review note required")
	ErrForbiddenReview             = errors.New("forbidden review action")
	ErrReviewLocked                = errors.New("review locked")
	ErrReviewInherited             = errors.New("inherited baustein")
	ErrReviewNotApplicable         = errors.New("baustein not applicable")
	ErrInvalidReturnedRequirements = errors.New("invalid returned requirements")
)

type BausteinReview struct {
	ProjectID              int64      `json:"projectId"`
	TargetObjectID         int64      `json:"targetObjectId"`
	BausteinID             int64      `json:"bausteinId"`
	State                  string     `json:"state"`
	ReviewNote             string     `json:"reviewNote"`
	ReturnedRequirementIDs []int64    `json:"returnedRequirementIds,omitempty"`
	SubmittedBy            int64      `json:"submittedBy,omitempty"`
	SubmittedAt            *time.Time `json:"submittedAt,omitempty"`
	ReviewedBy             int64      `json:"reviewedBy,omitempty"`
	ReviewedAt             *time.Time `json:"reviewedAt,omitempty"`
	UpdatedAt              time.Time  `json:"updatedAt,omitempty"`
}

func NormalizeReviewState(value string) string {
	switch strings.TrimSpace(value) {
	case ReviewSubmitted, ReviewReturned, ReviewAccepted:
		return strings.TrimSpace(value)
	default:
		return ReviewInProgress
	}
}

func ReviewStateLabel(value string) string {
	switch NormalizeReviewState(value) {
	case ReviewSubmitted:
		return "Zur Prüfung"
	case ReviewReturned:
		return "Zurückgegeben"
	case ReviewAccepted:
		return "Abgenommen"
	default:
		return "In Bearbeitung"
	}
}

func DefaultBausteinReview(projectID, targetObjectID, bausteinID int64) BausteinReview {
	return BausteinReview{
		ProjectID:              projectID,
		TargetObjectID:         targetObjectID,
		BausteinID:             bausteinID,
		State:                  ReviewInProgress,
		ReturnedRequirementIDs: []int64{},
	}
}

func NormalizeReturnedRequirementIDs(ids []int64) []int64 {
	if len(ids) == 0 {
		return []int64{}
	}
	seen := make(map[int64]struct{}, len(ids))
	out := make([]int64, 0, len(ids))
	for _, id := range ids {
		if id <= 0 {
			continue
		}
		if _, ok := seen[id]; ok {
			continue
		}
		seen[id] = struct{}{}
		out = append(out, id)
	}
	sort.Slice(out, func(i, j int) bool { return out[i] < out[j] })
	return out
}

func ContainsReturnedRequirementID(ids []int64, requirementID int64) bool {
	if requirementID <= 0 {
		return false
	}
	for _, id := range ids {
		if id == requirementID {
			return true
		}
	}
	return false
}

func ValidateReturnedRequirementIDs(ids, allowed []int64) error {
	ids = NormalizeReturnedRequirementIDs(ids)
	if len(ids) == 0 {
		return nil
	}
	ok := make(map[int64]struct{}, len(allowed))
	for _, id := range allowed {
		if id > 0 {
			ok[id] = struct{}{}
		}
	}
	for _, id := range ids {
		if _, found := ok[id]; !found {
			return ErrInvalidReturnedRequirements
		}
	}
	return nil
}

func ReviewAllowsContentEdit(workflowEnabled bool, state string) bool {
	if !workflowEnabled {
		return true
	}
	switch NormalizeReviewState(state) {
	case ReviewSubmitted, ReviewAccepted:
		return false
	default:
		return true
	}
}

func ReviewAllowsBausteinEdit(workflowEnabled bool, state string, returnedIDs []int64) bool {
	if !ReviewAllowsContentEdit(workflowEnabled, state) {
		return false
	}
	if !workflowEnabled {
		return true
	}
	if NormalizeReviewState(state) == ReviewReturned && len(NormalizeReturnedRequirementIDs(returnedIDs)) > 0 {
		return false
	}
	return true
}

func ReviewAllowsRequirementEdit(workflowEnabled bool, state string, returnedIDs []int64, requirementID int64) bool {
	if !workflowEnabled {
		return true
	}
	state = NormalizeReviewState(state)
	switch state {
	case ReviewSubmitted, ReviewAccepted:
		return false
	case ReviewReturned:
		ids := NormalizeReturnedRequirementIDs(returnedIDs)
		if len(ids) == 0 {
			return true
		}
		return ContainsReturnedRequirementID(ids, requirementID)
	default:
		return true
	}
}

func CanSubmitReview(workflowEnabled, inherited bool, state, role string) bool {
	if !workflowEnabled || inherited || !CanEditContent(role) {
		return false
	}
	switch NormalizeReviewState(state) {
	case ReviewInProgress, ReviewReturned:
		return true
	default:
		return false
	}
}

func CanReturnReview(workflowEnabled, inherited bool, state, role string) bool {
	if !workflowEnabled || inherited || !CanReview(role) {
		return false
	}
	switch NormalizeReviewState(state) {
	case ReviewSubmitted, ReviewAccepted:
		return true
	default:
		return false
	}
}

func CanAcceptReview(workflowEnabled, inherited bool, state, role string) bool {
	if !workflowEnabled || inherited || !CanReview(role) {
		return false
	}
	return NormalizeReviewState(state) == ReviewSubmitted
}

func ReviewTransition(workflowEnabled bool, state, action, role, note string) (string, error) {
	if !workflowEnabled {
		return "", ErrWorkflowDisabled
	}
	state = NormalizeReviewState(state)
	switch strings.TrimSpace(action) {
	case ReviewActionSubmit:
		if !CanEditContent(role) {
			return "", ErrForbiddenReview
		}
		if state != ReviewInProgress && state != ReviewReturned {
			return "", ErrInvalidReviewTransition
		}
		return ReviewSubmitted, nil
	case ReviewActionReturn:
		if !CanReview(role) {
			return "", ErrForbiddenReview
		}
		if state != ReviewSubmitted && state != ReviewAccepted {
			return "", ErrInvalidReviewTransition
		}
		if strings.TrimSpace(note) == "" {
			return "", ErrReviewNoteRequired
		}
		return ReviewReturned, nil
	case ReviewActionAccept:
		if !CanReview(role) {
			return "", ErrForbiddenReview
		}
		if state != ReviewSubmitted {
			return "", ErrInvalidReviewTransition
		}
		return ReviewAccepted, nil
	default:
		return "", ErrInvalidReviewAction
	}
}

func CountReviewQueue(reviews []BausteinReview) (submitted, returned int) {
	for _, review := range reviews {
		switch NormalizeReviewState(review.State) {
		case ReviewSubmitted:
			submitted++
		case ReviewReturned:
			returned++
		}
	}
	return submitted, returned
}
