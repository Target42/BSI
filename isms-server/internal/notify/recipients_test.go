package notify

import (
	"testing"

	"github.com/Target42/BSI/isms-server/internal/domain"
)

func TestRecipientsSubmitAssigned(t *testing.T) {
	got := Recipients(domain.ReviewActionSubmit, 1, 9, 0, []Member{
		{UserID: 9, Role: domain.RoleReviewer},
		{UserID: 2, Role: domain.RoleReviewer},
	}, nil)
	if len(got) != 1 || got[0] != 9 {
		t.Fatalf("assigned reviewer: %v", got)
	}
}

func TestRecipientsSubmitUnassigned(t *testing.T) {
	got := Recipients(domain.ReviewActionSubmit, 3, 0, 0, []Member{
		{UserID: 1, Role: domain.RoleOwner},
		{UserID: 2, Role: domain.RoleReviewer},
		{UserID: 3, Role: domain.RoleEditor},
		{UserID: 4, Role: domain.RoleViewer},
	}, nil)
	if !containsAll(got, 1, 2) || contains(got, 3) || contains(got, 4) {
		t.Fatalf("unassigned reviewers: %v", got)
	}
}

func TestRecipientsReturn(t *testing.T) {
	got := Recipients(domain.ReviewActionReturn, 9, 9, 3, []Member{
		{UserID: 1, Role: domain.RoleOwner},
		{UserID: 3, Role: domain.RoleEditor},
		{UserID: 9, Role: domain.RoleReviewer},
	}, []int64{8, 3})
	if !containsAll(got, 1, 3, 8) || contains(got, 9) {
		t.Fatalf("return: %v", got)
	}
}

func TestRecipientsAccept(t *testing.T) {
	got := Recipients(domain.ReviewActionAccept, 1, 0, 3, nil, nil)
	if len(got) != 1 || got[0] != 3 {
		t.Fatalf("accept: %v", got)
	}
	if len(Recipients(domain.ReviewActionAccept, 3, 0, 3, nil, nil)) != 0 {
		t.Fatal("actor should not be notified")
	}
}

func contains(ids []int64, want int64) bool {
	for _, id := range ids {
		if id == want {
			return true
		}
	}
	return false
}

func containsAll(ids []int64, want ...int64) bool {
	for _, id := range want {
		if !contains(ids, id) {
			return false
		}
	}
	return true
}
