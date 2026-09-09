#ifndef DOMAIN_BAUSTEINREVIEW_H
#define DOMAIN_BAUSTEINREVIEW_H

#include <QList>
#include <QString>

inline const QString ReviewStateInProgress = QStringLiteral("in_progress");
inline const QString ReviewStateSubmitted = QStringLiteral("submitted");
inline const QString ReviewStateReturned = QStringLiteral("returned");
inline const QString ReviewStateAccepted = QStringLiteral("accepted");

inline const QString ReviewActionSubmit = QStringLiteral("submit");
inline const QString ReviewActionReturn = QStringLiteral("return");
inline const QString ReviewActionAccept = QStringLiteral("accept");

struct BausteinReview {
    int projectId = 0;
    int targetObjectId = 0;
    int bausteinId = 0;
    QString state = ReviewStateInProgress;
    QString reviewNote;
    QList<int> returnedRequirementIds;
};

struct ReviewSaveResult {
    enum class Status { Ok, Forbidden, NoteRequired, Invalid, Failed };

    Status status = Status::Failed;
    BausteinReview review;

    static ReviewSaveResult ok(const BausteinReview &review)
    {
        ReviewSaveResult result;
        result.status = Status::Ok;
        result.review = review;
        return result;
    }

    static ReviewSaveResult failed(Status status = Status::Failed)
    {
        ReviewSaveResult result;
        result.status = status;
        return result;
    }
};

inline QString normalizeReviewState(const QString &value)
{
    const QString state = value.trimmed();
    if (state == ReviewStateSubmitted || state == ReviewStateReturned || state == ReviewStateAccepted)
        return state;
    return ReviewStateInProgress;
}

inline QString reviewStateLabel(const QString &value)
{
    const QString state = normalizeReviewState(value);
    if (state == ReviewStateSubmitted)
        return QStringLiteral("Zur Prüfung");
    if (state == ReviewStateReturned)
        return QStringLiteral("Zurückgegeben");
    if (state == ReviewStateAccepted)
        return QStringLiteral("Abgenommen");
    return QStringLiteral("In Bearbeitung");
}

inline BausteinReview defaultBausteinReview(int projectId, int targetObjectId, int bausteinId)
{
    BausteinReview review;
    review.projectId = projectId;
    review.targetObjectId = targetObjectId;
    review.bausteinId = bausteinId;
    review.state = ReviewStateInProgress;
    return review;
}

inline bool reviewAllowsContentEdit(bool workflowEnabled, const QString &state)
{
    if (!workflowEnabled)
        return true;
    const QString normalized = normalizeReviewState(state);
    return normalized != ReviewStateSubmitted && normalized != ReviewStateAccepted;
}

inline bool reviewAllowsBausteinEdit(bool workflowEnabled, const QString &state,
                                    const QList<int> &returnedIds)
{
    if (!reviewAllowsContentEdit(workflowEnabled, state))
        return false;
    return !(workflowEnabled && normalizeReviewState(state) == ReviewStateReturned
             && !returnedIds.isEmpty());
}

inline bool reviewAllowsRequirementEdit(bool workflowEnabled, const QString &state,
                                       const QList<int> &returnedIds, int requirementId)
{
    if (!workflowEnabled)
        return true;
    const QString normalized = normalizeReviewState(state);
    if (normalized == ReviewStateSubmitted || normalized == ReviewStateAccepted)
        return false;
    if (normalized == ReviewStateReturned && !returnedIds.isEmpty())
        return returnedIds.contains(requirementId);
    return true;
}

inline bool canEditContentRole(const QString &role)
{
    return role == QStringLiteral("owner") || role == QStringLiteral("editor");
}

inline bool canReviewRole(const QString &role)
{
    return role == QStringLiteral("owner") || role == QStringLiteral("reviewer");
}

inline bool canSubmitReview(bool workflowEnabled, bool inherited, const QString &state,
                            const QString &role)
{
    if (!workflowEnabled || inherited || !canEditContentRole(role))
        return false;
    const QString normalized = normalizeReviewState(state);
    return normalized == ReviewStateInProgress || normalized == ReviewStateReturned;
}

inline bool canReturnReview(bool workflowEnabled, bool inherited, const QString &state,
                            const QString &role)
{
    if (!workflowEnabled || inherited || !canReviewRole(role))
        return false;
    const QString normalized = normalizeReviewState(state);
    return normalized == ReviewStateSubmitted || normalized == ReviewStateAccepted;
}

inline bool canAcceptReview(bool workflowEnabled, bool inherited, const QString &state,
                            const QString &role)
{
    if (!workflowEnabled || inherited || !canReviewRole(role))
        return false;
    return normalizeReviewState(state) == ReviewStateSubmitted;
}

inline QString reviewLockMessage(const QString &state = QString())
{
    const QString normalized = normalizeReviewState(state);
    if (normalized == ReviewStateAccepted)
        return QStringLiteral("Dieser Baustein ist abgenommen und kann nicht geändert werden.");
    if (normalized == ReviewStateSubmitted)
        return QStringLiteral(
            "Dieser Baustein ist zur Prüfung eingereicht und kann nicht geändert werden.");
    if (normalized == ReviewStateReturned)
        return QStringLiteral("Nur die zurückgegebenen Anforderungen können bearbeitet werden.");
    return QStringLiteral(
        "Dieser Baustein ist zur Prüfung oder abgenommen und kann nicht geändert werden.");
}

inline QString reviewActionMessage(const QString &action)
{
    if (action == ReviewActionSubmit)
        return QStringLiteral("Baustein zur Prüfung eingereicht.");
    if (action == ReviewActionReturn)
        return QStringLiteral("Baustein zurückgegeben.");
    if (action == ReviewActionAccept)
        return QStringLiteral("Baustein abgenommen.");
    return QStringLiteral("Laufzettel gespeichert.");
}

inline QString reviewClientErrorMessage(const QString &code)
{
    if (code == QStringLiteral("review_locked"))
        return reviewLockMessage();
    if (code == QStringLiteral("review_note_required"))
        return QStringLiteral("Bitte eine Begründung für die Rückgabe eintragen.");
    if (code == QStringLiteral("invalid_returned_requirements"))
        return QStringLiteral("Bitte nur Anforderungen dieses Bausteins zurückgeben.");
    if (code == QStringLiteral("invalid_review_transition"))
        return QStringLiteral("Diese Aktion ist im aktuellen Laufzettel-Zustand nicht möglich.");
    if (code == QStringLiteral("workflow_disabled"))
        return QStringLiteral("Der Prüfkreislauf ist für dieses Projekt ausgeschaltet.");
    if (code == QStringLiteral("baustein_not_applicable"))
        return QStringLiteral("Nur eigene, anwendbare Bausteine können eingereicht werden.");
    if (code == QStringLiteral("forbidden"))
        return QStringLiteral("Dafür fehlt die Berechtigung.");
    return QStringLiteral("Laufzettel konnte nicht gespeichert werden.");
}

#endif
