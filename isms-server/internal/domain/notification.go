package domain

import "time"

const (
	NotifyReviewSubmitted = "review_submitted"
	NotifyReviewReturned  = "review_returned"
	NotifyReviewAccepted  = "review_accepted"
)

type Notification struct {
	ID             int64      `json:"id"`
	UserID         int64      `json:"userId"`
	ProjectID      int64      `json:"projectId"`
	ProjectName    string     `json:"projectName,omitempty"`
	TargetObjectID int64      `json:"targetObjectId,omitempty"`
	BausteinID     int64      `json:"bausteinId,omitempty"`
	Kind           string     `json:"kind"`
	Title          string     `json:"title"`
	Body           string     `json:"body"`
	LinkPath       string     `json:"linkPath,omitempty"`
	ReadAt         *time.Time `json:"readAt,omitempty"`
	CreatedAt      time.Time  `json:"createdAt"`
}

func NotificationKindLabel(kind string) string {
	switch kind {
	case NotifyReviewSubmitted:
		return "Zur Prüfung"
	case NotifyReviewReturned:
		return "Zurückgegeben"
	case NotifyReviewAccepted:
		return "Abgenommen"
	default:
		return kind
	}
}
