#include "HttpMeasureRepository.h"

#include "domain/MeasureStatus.h"
#include "net/HttpJson.h"
#include "qjsonarray.h"

#include <QJsonDocument>
#include <QJsonObject>

HttpMeasureRepository::HttpMeasureRepository(ApiClient &client)
    : m_client(client)
{
}

QList<Measure> HttpMeasureRepository::loadMeasures(int projectId, int targetObjectId,
                                                   int requirementDbId) const
{
    int status = 0;
    const QJsonDocument doc = m_client.get(
        QStringLiteral("/api/v1/projects/%1/target-objects/%2/requirements/%3/measures")
            .arg(projectId)
            .arg(targetObjectId)
            .arg(requirementDbId),
        &status);
    if (status != 200 || !doc.isArray()) {
        m_lastError = m_client.lastError();
        return {};
    }

    QList<Measure> measures;
    for (const QJsonValue &value : doc.array()) {
        if (value.isObject())
            measures.append(measureFromJson(value.toObject()));
    }
    return measures;
}

QHash<int, int> HttpMeasureRepository::measureCounts(int projectId, int targetObjectId) const
{
    int status = 0;
    const QJsonDocument doc = m_client.get(
        QStringLiteral("/api/v1/projects/%1/target-objects/%2/measure-counts")
            .arg(projectId)
            .arg(targetObjectId),
        &status);
    if (status != 200 || !doc.isObject()) {
        m_lastError = m_client.lastError();
        return {};
    }

    QHash<int, int> counts;
    const QJsonObject obj = doc.object();
    for (auto it = obj.begin(); it != obj.end(); ++it)
        counts.insert(it.key().toInt(), it.value().toInt());
    return counts;
}

Measure HttpMeasureRepository::createMeasure(const Measure &measure)
{
    QJsonObject body;
    body.insert(QStringLiteral("title"), measure.title);
    body.insert(QStringLiteral("description"), measure.description);
    body.insert(QStringLiteral("responsible"), measure.responsible);
    if (measure.dueDate.isValid())
        body.insert(QStringLiteral("dueDate"), measure.dueDate.toString(Qt::ISODate));
    body.insert(QStringLiteral("status"), measureStatusToString(measure.status));

    int status = 0;
    const QJsonDocument doc = m_client.post(
        QStringLiteral("/api/v1/projects/%1/target-objects/%2/requirements/%3/measures")
            .arg(measure.projectId)
            .arg(measure.targetObjectId)
            .arg(measure.requirementDbId),
        body, &status);
    if (status != 201 || !doc.isObject()) {
        m_lastError = m_client.lastError();
        return {};
    }
    return measureFromJson(doc.object());
}

MeasureSaveResult HttpMeasureRepository::updateMeasure(const Measure &measure)
{
    QJsonObject body;
    body.insert(QStringLiteral("title"), measure.title);
    body.insert(QStringLiteral("description"), measure.description);
    body.insert(QStringLiteral("responsible"), measure.responsible);
    if (measure.dueDate.isValid())
        body.insert(QStringLiteral("dueDate"), measure.dueDate.toString(Qt::ISODate));
    body.insert(QStringLiteral("status"), measureStatusToString(measure.status));
    body.insert(QStringLiteral("version"), measure.version);

    int status = 0;
    const QJsonDocument doc =
        m_client.patch(QStringLiteral("/api/v1/measures/%1").arg(measure.id), body, &status);
    if (status == 200 && doc.isObject())
        return MeasureSaveResult::ok(measureFromJson(doc.object()));

    if (status == 409 && doc.isObject()) {
        const QJsonObject obj = doc.object();
        const QJsonValue current = obj.value(QStringLiteral("current"));
        if (current.isObject())
            return MeasureSaveResult::conflict(measureFromJson(current.toObject()));
    }

    m_lastError = m_client.lastError();
    if (status == 403)
        return MeasureSaveResult::forbidden();
    return MeasureSaveResult::failed();
}

bool HttpMeasureRepository::deleteMeasure(int measureId)
{
    int status = 0;
    if (!m_client.del(QStringLiteral("/api/v1/measures/%1").arg(measureId), &status)) {
        m_lastError = m_client.lastError();
        return false;
    }
    return status == 204;
}

QString HttpMeasureRepository::lastError() const
{
    if (!m_lastError.isEmpty())
        return m_lastError;
    return m_client.lastError();
}
