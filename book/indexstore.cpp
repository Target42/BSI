#include "indexstore.h"
#include "book/basenode.h"
#include "book/indexnode.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QFile>
#include <QDir>

IndexStore::IndexStore() {}

IndexNode *IndexStore::root() const
{
    return m_root;
}

void IndexStore::setRoot(IndexNode *newRoot)
{
    m_root = newRoot;
}

QString IndexStore::home() const
{
    return m_home;
}

void IndexStore::setHome(const QString &newHome)
{
    m_home = newHome;
}

bool IndexStore::load()
{
    bool result = false;

    if ( m_home.isEmpty() == true)
    {
        return result;
    }
    QString fname = QDir::cleanPath(m_home + QDir::separator() + "index.json");
    QFile file(fname);
    if (file.open(QIODevice::ReadOnly | QIODevice::Text) == false)
    {
        return result;
    }

    QByteArray jsonData = file.readAll();
    file.close();

    QJsonDocument jsonDocument = QJsonDocument::fromJson(jsonData);

    if (jsonDocument.isNull() == true )
    {
        return result;
    }
    if ( jsonDocument.isObject() == true)
    {
        QJsonObject root = jsonDocument.object();
        QJsonArray arr = root["states"].toArray();

        QMap<QString, BaseNode::tTemplateState> map;
        buildMap(arr, map);
        setStates(m_root, map);

        result = true;

    }
    return result;

}

bool IndexStore::save()
{
    bool result = false;

    if ( m_home.isEmpty() == true)
    {
        return result;
    }
    QString fname = QDir::cleanPath(m_home + QDir::separator() + "index.json");
    QJsonArray arr;
    addIndex(arr, m_root);

    QJsonObject root;

    root["states"] = arr;
    QJsonDocument doc(root);

    QFile file(fname);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text) == false)
    {
        return result;
    }

    file.write(doc.toJson(QJsonDocument::Indented));
    file.close();
    result = true;

    return result;
}

void IndexStore::addIndex(QJsonArray &arr, IndexNode *node)
{
    QJsonObject data;

    if ( node->node() != nullptr)
    {
        data["name"] = node->id();
        data["state"] = BaseNode::templateStateToText(node->node()->templateState());

        arr.append(data);
    }
    foreach( IndexNode* child, node->childs())
    {
        addIndex(arr, child);
    }
}

void IndexStore::buildMap(QJsonArray &arr, QMap<QString, BaseNode::tTemplateState> &map)
{
    for( int i = 0 ; i < arr.size() ; i++ )
    {
        QJsonObject row;

        row = arr.at(i).toObject();
        map.insert( row["name"].toString(),  BaseNode::TestToTemplateState(row["state"].toString()));
    }
}

void IndexStore::setStates(IndexNode *root, QMap<QString, BaseNode::tTemplateState> &map)
{
    if ( root->node() != nullptr)
    {
        auto iter = map.find(root->id());

        if ( iter != map.end())
        {
            root->node()->setTemplateState(iter.value());
        }
    }
    foreach(IndexNode* child, root->childs())
    {
        setStates(child, map);
    }
}
