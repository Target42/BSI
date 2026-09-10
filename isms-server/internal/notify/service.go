package notify

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"strings"
	"time"

	"github.com/Target42/BSI/isms-server/internal/domain"
	"github.com/Target42/BSI/isms-server/internal/repository"
)

type Mailer interface {
	Send(ctx context.Context, to, subject, body string) error
}

type Event struct {
	Project        domain.Project
	TargetObjectID int64
	BausteinID     int64
	Action         string
	ActorID        int64
	ActorName      string
	Review         domain.BausteinReview
}

type Service struct {
	store  *repository.Store
	mailer Mailer
}

func New(store *repository.Store, mailer Mailer) *Service {
	return &Service{store: store, mailer: mailer}
}

func (s *Service) OnReview(ctx context.Context, event Event) error {
	if s == nil || s.store == nil {
		return nil
	}
	kind := kindForAction(event.Action)
	if kind == "" {
		return nil
	}
	members, err := s.store.ListProjectMembers(ctx, event.Project.ID)
	if err != nil {
		return err
	}
	memberList := make([]Member, 0, len(members))
	for _, member := range members {
		memberList = append(memberList, Member{UserID: member.UserID, Role: member.Role})
	}
	var responsible []int64
	if event.Action == domain.ReviewActionReturn {
		responsible, err = s.store.ListBausteinResponsibleUserIDs(ctx, event.Project.ID, event.TargetObjectID, event.BausteinID)
		if err != nil {
			return err
		}
	}
	ids := Recipients(event.Action, event.ActorID, event.Review.AssignedReviewerID, event.Review.SubmittedBy, memberList, responsible)
	if len(ids) == 0 {
		return nil
	}
	title, body := s.reviewCopy(ctx, event)
	linkPath := fmt.Sprintf("/projects/%d/targets/%d?baustein=%d", event.Project.ID, event.TargetObjectID, event.BausteinID)
	items := make([]domain.Notification, 0, len(ids))
	for _, userID := range ids {
		items = append(items, domain.Notification{
			UserID:         userID,
			ProjectID:      event.Project.ID,
			TargetObjectID: event.TargetObjectID,
			BausteinID:     event.BausteinID,
			Kind:           kind,
			Title:          title,
			Body:           body,
			LinkPath:       linkPath,
		})
	}
	if err := s.store.InsertNotifications(ctx, items); err != nil {
		return err
	}
	s.sendMail(ids, title, body, linkPath)
	return nil
}

func (s *Service) sendMail(userIDs []int64, title, body, linkPath string) {
	if s.mailer == nil || len(userIDs) == 0 {
		return
	}
	ids := append([]int64(nil), userIDs...)
	store := s.store
	mailer := s.mailer
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
		defer cancel()
		users, err := store.UsersByIDs(ctx, ids)
		if err != nil {
			slog.Error("notification mail: load users", "err", err)
			return
		}
		public := strings.TrimRight(strings.TrimSpace(os.Getenv("MAIL_PUBLIC_URL")), "/")
		text := body
		if public != "" && linkPath != "" {
			text += "\n\n" + public + linkPath
		}
		for _, user := range users {
			to := strings.TrimSpace(user.Email)
			if to == "" {
				continue
			}
			if err := mailer.Send(ctx, to, title, text); err != nil {
				slog.Error("notification mail send failed", "err", err, "userId", user.ID)
			}
		}
	}()
}

func (s *Service) reviewCopy(ctx context.Context, event Event) (string, string) {
	actor := strings.TrimSpace(event.ActorName)
	if actor == "" {
		actor = "Ein Mitglied"
	}
	place := strings.TrimSpace(event.Project.Name)
	if place == "" {
		place = "einem Projekt"
	}
	targetName := "einem Zielobjekt"
	if event.TargetObjectID > 0 {
		if target, err := s.store.GetTargetObject(ctx, event.TargetObjectID); err == nil && strings.TrimSpace(target.Name) != "" {
			targetName = strings.TrimSpace(target.Name)
		}
	}
	bausteinName := "einen Baustein"
	if event.BausteinID > 0 {
		if baustein, err := s.store.GetBaustein(ctx, event.BausteinID); err == nil {
			label := strings.TrimSpace(strings.TrimSpace(baustein.ExternalID) + " " + strings.TrimSpace(baustein.Title))
			if label != "" {
				bausteinName = label
			}
		}
	}
	switch event.Action {
	case domain.ReviewActionSubmit:
		return "Baustein zur Prüfung",
			fmt.Sprintf("%s hat %s an %s in %s zur Prüfung eingereicht.", actor, bausteinName, targetName, place)
	case domain.ReviewActionReturn:
		body := fmt.Sprintf("%s hat %s an %s in %s zur Nacharbeit zurückgegeben.", actor, bausteinName, targetName, place)
		if note := strings.TrimSpace(event.Review.ReviewNote); note != "" {
			body += " Begründung: " + note
		}
		return "Baustein zurückgegeben", body
	case domain.ReviewActionAccept:
		return "Baustein abgenommen",
			fmt.Sprintf("%s hat %s an %s in %s abgenommen.", actor, bausteinName, targetName, place)
	default:
		return "Prüfung", fmt.Sprintf("%s hat den Laufzettel für %s geändert.", actor, bausteinName)
	}
}

func kindForAction(action string) string {
	switch action {
	case domain.ReviewActionSubmit:
		return domain.NotifyReviewSubmitted
	case domain.ReviewActionReturn:
		return domain.NotifyReviewReturned
	case domain.ReviewActionAccept:
		return domain.NotifyReviewAccepted
	default:
		return ""
	}
}
