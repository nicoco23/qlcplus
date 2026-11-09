/*
  Q Light Controller Plus
  kahostageimport.cpp

  Copyright (c) Massimo Callegari
  Copyright (c) KAHO

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0.txt

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QVector3D>
#include <QFile>

#include "kahostageimport.h"
#include "monitorproperties.h"
#include "contextmanager.h"
#include "fixture.h"
#include "doc.h"

/* Name of the trusses created by the import: they are replaced on the next import */
#define TRUSS_PREFIX QStringLiteral("KahoStage truss ")

KahoStageImport::KahoStageImport(Doc *doc, ContextManager *ctx, QObject *parent)
    : QObject(parent)
    , m_doc(doc)
    , m_contextManager(ctx)
{
}

QString KahoStageImport::importScene(const QUrl &fileUrl)
{
    QString path = fileUrl.isLocalFile() ? fileUrl.toLocalFile() : fileUrl.toString();
    QFile file(path);
    if (file.open(QIODevice::ReadOnly) == false)
        return tr("Impossible d'ouvrir %1").arg(path);

    QJsonParseError err;
    QJsonDocument json = QJsonDocument::fromJson(file.readAll(), &err);
    if (json.isNull() || json.object().value("format").toString() != "kahostage-scene")
        return tr("Ce fichier n'est pas une scène KahoStage (KahoStage-scene.json).");

    QJsonObject root = json.object();
    MonitorProperties *mon = m_doc->monitorProperties();

    QJsonArray grid = root.value("grid").toArray();
    if (grid.size() == 3)
    {
        mon->setGridUnits(MonitorProperties::Meters);
        mon->setGridSize(QVector3D(grid.at(0).toDouble(), grid.at(1).toDouble(), grid.at(2).toDouble()));
    }

    // fixtures are matched by name (the Minecraft fixture ID, e.g. "lyre-3")
    QHash<QString, Fixture *> byName;
    for (Fixture *fxi : m_doc->fixtures())
        byName.insert(fxi->name(), fxi);

    int placed = 0;
    QStringList missing;
    const QJsonArray fixtures = root.value("fixtures").toArray();
    for (const QJsonValue &v : fixtures)
    {
        QJsonObject o = v.toObject();
        Fixture *fxi = byName.value(o.value("name").toString());
        if (fxi == nullptr)
        {
            missing.append(o.value("name").toString());
            continue;
        }

        quint32 id = fxi->id();
        mon->setFixturePosition(id, 0, 0, QVector3D(o.value("x").toDouble(), o.value("y").toDouble(), o.value("z").toDouble()));
        mon->setFixtureRotation(id, 0, 0, QVector3D(o.value("rx").toDouble(), o.value("ry").toDouble(), o.value("rz").toDouble()));

        quint32 flags = mon->fixtureFlags(id, 0, 0);
        flags &= ~(MonitorProperties::InvertedPanFlag | MonitorProperties::InvertedTiltFlag);
        if (o.value("invertPan").toBool())
            flags |= MonitorProperties::InvertedPanFlag;
        if (o.value("invertTilt").toBool())
            flags |= MonitorProperties::InvertedTiltFlag;
        mon->setFixtureFlags(id, 0, 0, flags);
        placed++;
    }

    // trusses: remove the ones of a previous import, then add the new ones
    quint32 nextId = 0;
    for (quint32 itemID : mon->genericItemsID())
    {
        if (mon->itemName(itemID).startsWith(TRUSS_PREFIX))
            mon->removeItem(itemID);
        else
            nextId = qMax(nextId, itemID + 1);
    }

    int trusses = 0;
    const QJsonArray meshes = root.value("meshes").toArray();
    for (const QJsonValue &v : meshes)
    {
        QJsonObject o = v.toObject();
        quint32 itemID = nextId++;
        mon->setItemResource(itemID, o.value("res").toString());
        mon->setItemName(itemID, TRUSS_PREFIX + QString::number(++trusses));
        mon->setItemPosition(itemID, QVector3D(o.value("x").toDouble(), o.value("y").toDouble(), o.value("z").toDouble()));
        mon->setItemRotation(itemID, QVector3D(0, o.value("ry").toDouble(), 0));
        mon->setItemScale(itemID, QVector3D(o.value("sx").toDouble(1), o.value("sy").toDouble(1), o.value("sz").toDouble(1)));
        mon->setItemFlags(itemID, MonitorProperties::LockedFlag);
    }

    m_doc->setModified();
    m_contextManager->resetContexts();

    QString report = tr("%n machine(s) placée(s)", "", placed);
    if (trusses)
        report += tr(", %n truss", "", trusses);
    if (missing.isEmpty() == false)
        report += tr(". Introuvables dans ce projet : %1").arg(missing.join(", "));
    return report + ".";
}
