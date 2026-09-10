package notify

import "github.com/Target42/BSI/isms-server/internal/domain"

type Member struct {
	UserID int64
	Role   string
}

func Recipients(action string, actorID, assignedReviewerID, submittedBy int64, members []Member, responsible []int64) []int64 {
	seen := map[int64]struct{}{}
	add := func(id int64) {
		if id <= 0 || id == actorID {
			return
		}
		seen[id] = struct{}{}
	}
	switch action {
	case domain.ReviewActionSubmit:
		if assignedReviewerID > 0 {
			add(assignedReviewerID)
			break
		}
		for _, member := range members {
			if domain.CanReview(member.Role) {
				add(member.UserID)
			}
		}
	case domain.ReviewActionReturn:
		add(submittedBy)
		for _, member := range members {
			if domain.CanEditContent(member.Role) {
				add(member.UserID)
			}
		}
		for _, id := range responsible {
			add(id)
		}
	case domain.ReviewActionAccept:
		add(submittedBy)
	}
	out := make([]int64, 0, len(seen))
	for id := range seen {
		out = append(out, id)
	}
	return out
}
