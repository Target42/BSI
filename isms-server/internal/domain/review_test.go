package domain

import "testing"

func TestReviewAllowsContentEdit(t *testing.T) {
	if !ReviewAllowsContentEdit(false, ReviewSubmitted) {
		t.Fatal("disabled workflow stays writable")
	}
	if !ReviewAllowsContentEdit(true, ReviewInProgress) || !ReviewAllowsContentEdit(true, ReviewReturned) {
		t.Fatal("in progress and returned stay writable")
	}
	if ReviewAllowsContentEdit(true, ReviewSubmitted) || ReviewAllowsContentEdit(true, ReviewAccepted) {
		t.Fatal("submitted and accepted must lock content")
	}
}

func TestReviewAllowsBausteinEdit(t *testing.T) {
	if !ReviewAllowsBausteinEdit(true, ReviewReturned, nil) {
		t.Fatal("full return keeps baustein writable")
	}
	if ReviewAllowsBausteinEdit(true, ReviewReturned, []int64{3, 8}) {
		t.Fatal("partial return must lock baustein-level writes")
	}
	if ReviewAllowsBausteinEdit(true, ReviewSubmitted, nil) {
		t.Fatal("submitted must lock baustein")
	}
}

func TestReviewAllowsRequirementEdit(t *testing.T) {
	if !ReviewAllowsRequirementEdit(true, ReviewReturned, nil, 3) {
		t.Fatal("full return keeps every requirement writable")
	}
	if !ReviewAllowsRequirementEdit(true, ReviewReturned, []int64{3, 8}, 3) {
		t.Fatal("returned requirement must stay writable")
	}
	if ReviewAllowsRequirementEdit(true, ReviewReturned, []int64{3, 8}, 9) {
		t.Fatal("other requirements stay locked on partial return")
	}
	if ReviewAllowsRequirementEdit(true, ReviewSubmitted, []int64{3}, 3) {
		t.Fatal("submitted stays locked even with leftover ids")
	}
}

func TestValidateReturnedRequirementIDs(t *testing.T) {
	if err := ValidateReturnedRequirementIDs([]int64{3, 3, 8}, []int64{1, 3, 8}); err != nil {
		t.Fatalf("valid ids: %v", err)
	}
	if err := ValidateReturnedRequirementIDs([]int64{9}, []int64{1, 3, 8}); err != ErrInvalidReturnedRequirements {
		t.Fatalf("unknown id: %v", err)
	}
	if err := ValidateReturnedRequirementIDs(nil, []int64{1}); err != nil {
		t.Fatalf("empty ids: %v", err)
	}
}

func TestReviewTransition(t *testing.T) {
	next, err := ReviewTransition(true, ReviewInProgress, ReviewActionSubmit, RoleEditor, "")
	if err != nil || next != ReviewSubmitted {
		t.Fatalf("submit: %q %v", next, err)
	}
	next, err = ReviewTransition(true, ReviewSubmitted, ReviewActionAccept, RoleOwner, "")
	if err != nil || next != ReviewAccepted {
		t.Fatalf("accept: %q %v", next, err)
	}
	next, err = ReviewTransition(true, ReviewSubmitted, ReviewActionReturn, RoleOwner, "Bitte Logging ergänzen")
	if err != nil || next != ReviewReturned {
		t.Fatalf("return: %q %v", next, err)
	}
	next, err = ReviewTransition(true, ReviewAccepted, ReviewActionReturn, RoleOwner, "Nacharbeit")
	if err != nil || next != ReviewReturned {
		t.Fatalf("reopen accepted: %q %v", next, err)
	}
	if _, err := ReviewTransition(true, ReviewSubmitted, ReviewActionReturn, RoleOwner, "  "); err != ErrReviewNoteRequired {
		t.Fatalf("empty note: %v", err)
	}
	if _, err := ReviewTransition(true, ReviewSubmitted, ReviewActionAccept, RoleEditor, ""); err != ErrForbiddenReview {
		t.Fatalf("editor accept: %v", err)
	}
	if _, err := ReviewTransition(true, ReviewAccepted, ReviewActionSubmit, RoleEditor, ""); err != ErrInvalidReviewTransition {
		t.Fatalf("submit accepted: %v", err)
	}
	if _, err := ReviewTransition(false, ReviewInProgress, ReviewActionSubmit, RoleOwner, ""); err != ErrWorkflowDisabled {
		t.Fatalf("disabled: %v", err)
	}
	next, err = ReviewTransition(true, ReviewSubmitted, ReviewActionReturn, RoleReviewer, "Lücken")
	if err != nil || next != ReviewReturned {
		t.Fatalf("reviewer return: %q %v", next, err)
	}
	if _, err := ReviewTransition(true, ReviewInProgress, ReviewActionSubmit, RoleReviewer, ""); err != ErrForbiddenReview {
		t.Fatalf("reviewer submit: %v", err)
	}
}

func TestReviewActionFlags(t *testing.T) {
	if !CanSubmitReview(true, false, ReviewReturned, RoleEditor) {
		t.Fatal("editor should resubmit after return")
	}
	if CanSubmitReview(true, true, ReviewInProgress, RoleOwner) {
		t.Fatal("inherited cannot be submitted")
	}
	if CanSubmitReview(true, false, ReviewInProgress, RoleReviewer) {
		t.Fatal("reviewer cannot submit")
	}
	if !CanReturnReview(true, false, ReviewAccepted, RoleOwner, 0, 1) {
		t.Fatal("owner can reopen accepted")
	}
	if !CanReturnReview(true, false, ReviewSubmitted, RoleReviewer, 0, 2) {
		t.Fatal("reviewer can return")
	}
	if CanAcceptReview(true, false, ReviewInProgress, RoleOwner, 0, 1) {
		t.Fatal("accept only from submitted")
	}
	if CanAcceptReview(true, false, ReviewSubmitted, RoleEditor, 0, 3) {
		t.Fatal("editor cannot accept")
	}
	if !CanAcceptReview(true, false, ReviewSubmitted, RoleReviewer, 0, 2) {
		t.Fatal("reviewer can accept")
	}
	if !CanAcceptReview(true, false, ReviewSubmitted, RoleReviewer, 2, 2) {
		t.Fatal("assigned reviewer can accept")
	}
	if CanAcceptReview(true, false, ReviewSubmitted, RoleReviewer, 9, 2) {
		t.Fatal("other reviewer cannot accept assigned baustein")
	}
	if !CanAcceptReview(true, false, ReviewSubmitted, RoleOwner, 9, 1) {
		t.Fatal("owner can accept assigned baustein")
	}
	if !CanAssignReviewer(RoleEditor) || !CanAssignReviewer(RoleOwner) {
		t.Fatal("owner and editor can assign")
	}
	if CanAssignReviewer(RoleReviewer) {
		t.Fatal("reviewer cannot assign")
	}
	if !CanBeAssignedReviewer(RoleReviewer) || !CanBeAssignedReviewer(RoleOwner) || CanBeAssignedReviewer(RoleEditor) {
		t.Fatal("only reviewer and owner can be assigned")
	}
}

func TestCountReviewQueue(t *testing.T) {
	submitted, returned := CountReviewQueue([]BausteinReview{
		{State: ReviewSubmitted},
		{State: ReviewSubmitted},
		{State: ReviewReturned},
		{State: ReviewInProgress},
	})
	if submitted != 2 || returned != 1 {
		t.Fatalf("got submitted=%d returned=%d", submitted, returned)
	}
}
