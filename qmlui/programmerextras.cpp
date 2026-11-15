/*
  Q Light Controller Plus
  programmerextras.cpp

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

/* Undo ("Oops"), macros, views and the Akai APC mini pads in programmer mode. */

#include <QTimer>
#include <QSet>
#include <QHash>

#include "programmermanager.h"
#include "playbackmanager.h"
#include "contextmanager.h"
#include "fixturegroup.h"
#include "collection.h"
#include "chaserstep.h"
#include "chaser.h"
#include "scene.h"
#include "doc.h"

#define TEMP_PREFIX QStringLiteral("· ")
#define UNDO_DEPTH 25

/*********************************************************************
 * Undo
 *********************************************************************/

/** Everything a recording type action can change. Functions are never deleted by
 *  these actions, only created or edited, so the snapshot keeps what they held. */
struct ProgrammerManager::Snapshot
{
    QString label;

    QSet<quint32> functions;
    QSet<quint32> groups;
    QHash<quint32, QString> names;
    QHash<quint32, QString> groupNames;
    QHash<quint32, QPair<uint, uint>> fades;

    struct Stack
    {
        QList<ChaserStep> steps;
        Chaser::SpeedMode fadeIn, fadeOut, duration;
    };
    QHash<quint32, Stack> stacks;
    QHash<quint32, QList<quint32>> collections;
    QHash<quint32, QList<SceneValue>> scenes;

    PlaybackManager::Layout layout;

    QVector<Memory> colors, positions;
    QList<PresetRef> presetLinks, activeRefs;
    QMap<quint32, qreal> tempoLinks;
    QList<Effect> effects;
    QList<SceneValue> dump;
    QVector<Macro> macros;
    QVector<View> views;
    qreal pan, tilt, fan;
    bool crossed;
    int cueCounter;
};

void ProgrammerManager::pushUndo(const QString &label)
{
    // one user action can go through several recording steps: keep the first point only
    if (m_undoGuard || m_undoHold > 0)
        return;
    m_undoGuard = true;
    QTimer::singleShot(0, this, [this]() { m_undoGuard = false; });

    QSharedPointer<Snapshot> snap(new Snapshot);
    snap->label = label;

    for (Function *f : m_doc->functions())
    {
        snap->functions.insert(f->id());
        snap->names.insert(f->id(), f->name());
        snap->fades.insert(f->id(), { f->fadeInSpeed(), f->fadeOutSpeed() });

        if (Chaser *stack = qobject_cast<Chaser *>(f))
            snap->stacks.insert(f->id(), { stack->steps(), stack->fadeInMode(), stack->fadeOutMode(), stack->durationMode() });
        else if (Collection *coll = qobject_cast<Collection *>(f))
            snap->collections.insert(f->id(), coll->functions());
        else if (Scene *scene = qobject_cast<Scene *>(f))
            snap->scenes.insert(f->id(), scene->values());
    }
    for (FixtureGroup *grp : m_doc->fixtureGroups())
    {
        snap->groups.insert(grp->id());
        snap->groupNames.insert(grp->id(), grp->name());
    }

    snap->layout = m_playbacks->layout();
    snap->colors = m_colorMemories;
    snap->positions = m_positionMemories;
    snap->presetLinks = m_presetLinks;
    snap->activeRefs = m_activeRefs;
    snap->tempoLinks = m_tempoLinks;
    snap->effects = m_effects;
    snap->dump = m_contextManager->dumpValues();
    snap->macros = m_macros;
    snap->views = m_views;
    snap->pan = m_pan;
    snap->tilt = m_tilt;
    snap->fan = m_fan;
    snap->crossed = m_crossed;
    snap->cueCounter = m_cueCounter;

    m_undo.append(snap);
    while (m_undo.count() > UNDO_DEPTH)
        m_undo.removeFirst();
    emit undoChanged();
}

QString ProgrammerManager::undoText() const
{
    return m_undo.isEmpty() ? QString() : m_undo.last()->label;
}

bool ProgrammerManager::undo()
{
    if (m_undo.isEmpty())
        return false;

    QSharedPointer<Snapshot> snap = m_undo.takeLast();
    m_undoHold++;       // nothing done here is itself an undo point

    // 1. what was created since goes away
    QList<quint32> created;
    for (Function *f : m_doc->functions())
        if (snap->functions.contains(f->id()) == false)
            created.append(f->id());
    for (quint32 id : created)
    {
        Function *f = m_doc->function(id);
        if (f == nullptr)
            continue;
        if (f->isRunning())
            f->stopAndWait();
        m_doc->deleteFunction(id);
    }
    QList<quint32> createdGroups;
    for (FixtureGroup *grp : m_doc->fixtureGroups())
        if (snap->groups.contains(grp->id()) == false)
            createdGroups.append(grp->id());
    for (quint32 id : createdGroups)
        m_doc->deleteFixtureGroup(id);

    // 2. what was edited gets its content back
    for (Function *f : m_doc->functions())
    {
        quint32 id = f->id();
        if (snap->names.value(id) != f->name())
            f->setName(snap->names.value(id));
        QPair<uint, uint> fade = snap->fades.value(id);
        if (f->fadeInSpeed() != fade.first)
            f->setFadeInSpeed(fade.first);
        if (f->fadeOutSpeed() != fade.second)
            f->setFadeOutSpeed(fade.second);

        if (Chaser *stack = qobject_cast<Chaser *>(f))
        {
            if (snap->stacks.contains(id) == false)
                continue;
            const Snapshot::Stack &old = snap->stacks[id];
            bool same = old.steps.count() == stack->stepsCount()
                        && old.fadeIn == stack->fadeInMode() && old.fadeOut == stack->fadeOutMode()
                        && old.duration == stack->durationMode();
            for (int i = 0; same && i < old.steps.count(); i++)
            {
                const ChaserStep *now = stack->stepAt(i);
                const ChaserStep &was = old.steps.at(i);
                same = now->fid == was.fid && now->fadeIn == was.fadeIn && now->fadeOut == was.fadeOut
                       && now->hold == was.hold && now->duration == was.duration;
            }
            if (same)
                continue;
            // a running stack would point to a step that may be gone
            if (stack->isRunning())
                stack->stopAndWait();
            while (stack->stepsCount() > 0)
                stack->removeStep(0);
            for (const ChaserStep &step : old.steps)
                stack->addStep(step);
            stack->setFadeInMode(old.fadeIn);
            stack->setFadeOutMode(old.fadeOut);
            stack->setDurationMode(old.duration);
        }
        else if (Collection *coll = qobject_cast<Collection *>(f))
        {
            QList<quint32> old = snap->collections.value(id);
            if (old == coll->functions())
                continue;
            const QList<quint32> now = coll->functions();
            for (quint32 child : now)
                coll->removeFunction(child);
            for (quint32 child : old)
                coll->addFunction(child);
        }
        else if (Scene *scene = qobject_cast<Scene *>(f))
        {
            const QList<SceneValue> old = snap->scenes.value(id);
            const QList<SceneValue> now = scene->values();
            bool same = old.count() == now.count();
            for (int i = 0; same && i < old.count(); i++)
                same = old.at(i).fxi == now.at(i).fxi && old.at(i).channel == now.at(i).channel
                       && old.at(i).value == now.at(i).value;
            if (same)
                continue;
            for (const SceneValue &sv : now)
            {
                bool kept = false;
                for (const SceneValue &o : old)
                    if (o.fxi == sv.fxi && o.channel == sv.channel)
                        kept = true;
                if (kept)
                    continue;
                // a channel added since: bring it down on a running scene, then forget it
                scene->setValue(SceneValue(sv.fxi, sv.channel, 0), false, false);
                scene->unsetValue(sv.fxi, sv.channel);
            }
            for (const SceneValue &o : old)
                scene->setValue(o, false, false);
        }
    }
    for (FixtureGroup *grp : m_doc->fixtureGroups())
        if (snap->groupNames.value(grp->id()) != grp->name())
            grp->setName(snap->groupNames.value(grp->id()));

    // 3. playbacks, presets, programmer
    m_playbacks->restoreLayout(snap->layout);

    m_colorMemories = snap->colors;
    m_positionMemories = snap->positions;
    m_presetLinks = snap->presetLinks;
    m_activeRefs = snap->activeRefs;
    m_tempoLinks = snap->tempoLinks;
    m_macros = snap->macros;
    m_views = snap->views;
    m_cueCounter = snap->cueCounter;

    // effects running now and not then were deleted above; those of then run again if they still exist
    m_effects.clear();
    for (const Effect &e : snap->effects)
    {
        Function *f = m_doc->function(e.functionId);
        if (f == nullptr)
            continue;
        m_effects.append(e);
        if (f->isRunning() == false)
            f->start(m_doc->masterTimer(), FunctionParent::master());
    }
    updateEffectParams();

    // the programmer output is cleared at the next DMX tick: give the values back after it
    m_contextManager->resetDumpValues();
    QList<SceneValue> dump = snap->dump;
    QTimer::singleShot(80, this, [this, dump]()
    {
        for (const SceneValue &sv : dump)
            if (m_doc->fixture(sv.fxi) != nullptr)
                m_contextManager->setDumpValue(sv.fxi, sv.channel, sv.value);
        emit programmerChanged();
    });
    m_pan = snap->pan;
    m_tilt = snap->tilt;
    m_fan = snap->fan;
    m_crossed = snap->crossed;

    m_undoHold--;
    m_doc->setModified();

    emit positionChanged();
    emit effectsChanged();
    emit programmerChanged();
    emit memoriesChanged();
    emit macrosChanged();
    emit viewsChanged();
    emit groupsChanged();
    emit undoChanged();
    return true;
}

/*********************************************************************
 * Macros
 *********************************************************************/

QVariantList ProgrammerManager::macros() const
{
    QVariantList list;
    for (const Macro &m : m_macros)
    {
        QVariantMap map;
        map.insert("used", m.commands.isEmpty() == false);
        map.insert("name", m.name);
        map.insert("commands", m.commands);
        list.append(map);
    }
    return list;
}

void ProgrammerManager::macroRun(int index)
{
    if (index < 0 || index >= m_macros.count() || m_macros.at(index).commands.isEmpty())
        return;
    // a macro may call another one, not itself for ever
    if (m_macroDepth >= 4)
        return;
    m_macroDepth++;
    const QStringList lines = m_macros.at(index).commands.split(';', Qt::SkipEmptyParts);
    for (const QString &line : lines)
        executeCommand(line);
    m_macroDepth--;
}

void ProgrammerManager::macroStore(int index, const QString &name, const QString &commands)
{
    if (index < 0 || index >= m_macros.count())
        return;
    QString text = commands.trimmed();
    if (text.isEmpty())
    {
        macroClear(index);
        return;
    }
    pushUndo(tr("macro enregistrée"));
    m_macros[index] = { name.trimmed().isEmpty() ? tr("Macro %1").arg(index + 1) : name.trimmed(), text };
    m_doc->setModified();
    emit macrosChanged();
}

void ProgrammerManager::macroClear(int index)
{
    if (index < 0 || index >= m_macros.count() || m_macros.at(index).commands.isEmpty())
        return;
    pushUndo(tr("macro effacée"));
    m_macros[index] = Macro();
    m_doc->setModified();
    emit macrosChanged();
}

/*********************************************************************
 * Views
 *********************************************************************/

QVariantList ProgrammerManager::views() const
{
    QVariantList list;
    for (const View &v : m_views)
    {
        QVariantMap map;
        map.insert("used", v.used);
        map.insert("name", v.name);
        map.insert("page", v.page + 1);
        map.insert("active", v.used && v.context == m_contextManager->currentContext()
                             && v.page == m_playbacks->page());
        list.append(map);
    }
    return list;
}

void ProgrammerManager::viewRecall(int index)
{
    if (index < 0 || index >= m_views.count() || m_views.at(index).used == false)
        return;
    const View &v = m_views.at(index);
    m_playbacks->setPage(v.page);
    m_contextManager->switchToContext(v.context);
    emit viewsChanged();
}

void ProgrammerManager::viewStore(int index, const QString &name)
{
    if (index < 0 || index >= m_views.count())
        return;
    pushUndo(tr("vue enregistrée"));
    View &v = m_views[index];
    QString keep = v.used ? v.name : QString();
    v.used = true;
    v.context = m_contextManager->currentContext();
    v.page = m_playbacks->page();
    v.name = name.trimmed().isEmpty() ? (keep.isEmpty() ? tr("Vue %1").arg(index + 1) : keep) : name.trimmed();
    m_doc->setModified();
    emit viewsChanged();
}

void ProgrammerManager::viewClear(int index)
{
    if (index < 0 || index >= m_views.count() || m_views.at(index).used == false)
        return;
    pushUndo(tr("vue effacée"));
    m_views[index] = View();
    m_doc->setModified();
    emit viewsChanged();
}

void ProgrammerManager::renameGroup(quint32 groupId, const QString &name)
{
    FixtureGroup *grp = m_doc->fixtureGroup(groupId);
    if (grp == nullptr || name.trimmed().isEmpty())
        return;
    pushUndo(tr("groupe renommé"));
    grp->setName(name.trimmed());
    m_doc->setModified();
    emit groupsChanged();
}

/*********************************************************************
 * Akai APC mini pads in programmer mode
 *
 * rows 1-2: groups 1-16            (SHIFT = add to / remove from the selection)
 * rows 3-4: colour presets 1-16    (SHIFT = store the current colour)
 * rows 5-6: position presets 1-16  (SHIFT = store the current position)
 * row 7:    CLEAR, all, odd, even, full, zero, Oops, TAP
 *********************************************************************/

void ProgrammerManager::slotGridPad(int row, int col, bool shift)
{
    if (row < 0 || row > 6 || col < 0 || col > 7)
        return;

    if (row < 2)
    {
        QList<FixtureGroup *> pool;
        for (FixtureGroup *grp : m_doc->fixtureGroups())
            if (grp->name().startsWith(TEMP_PREFIX) == false)
                pool.append(grp);
        int n = row * 8 + col;
        if (n < pool.count())
            selectGroup(pool.at(n)->id(), shift);
        return;
    }
    if (row < 6)
    {
        QString kind = row < 4 ? "color" : "position";
        int n = (row < 4 ? row - 2 : row - 4) * 8 + col;
        const QVector<Memory> &list = row < 4 ? m_colorMemories : m_positionMemories;
        if (n >= list.count())
            return;
        if (shift)
            memoryStore(kind, n);
        else if (list.at(n).used && selectionCount() > 0)
            memoryPress(kind, n);
        return;
    }
    switch (col)
    {
        case 0: executeCommand(shift ? "ClearAll" : "Clear"); break;
        case 1: selectAll(); break;
        case 2: selectOddEven(true); break;
        case 3: selectOddEven(false); break;
        case 4: if (selectionCount() > 0) setIntensity(1); break;
        case 5: if (selectionCount() > 0) setIntensity(0); break;
        case 6: undo(); break;
        default: tap(); break;
    }
}

void ProgrammerManager::updateGridLeds()
{
    if (m_playbacks->apcMode() != "prog")
        return;

    QVector<uchar> leds(PlaybackManager::ExecCount, uchar(PlaybackManager::LedOff));
    const QVariantList grps = groups();
    for (int i = 0; i < grps.count() && i < 16; i++)
    {
        QVariantMap g = grps.at(i).toMap();
        leds[i] = g.value("selected").toBool() ? PlaybackManager::LedGreen
                  : (g.value("partial").toBool() ? PlaybackManager::LedGreenBlink : PlaybackManager::LedYellow);
    }
    for (int i = 0; i < 16; i++)
    {
        if (i < m_colorMemories.count() && m_colorMemories.at(i).used)
            leds[16 + i] = PlaybackManager::LedGreen;
        if (i < m_positionMemories.count() && m_positionMemories.at(i).used)
            leds[32 + i] = PlaybackManager::LedRed;
    }
    leds[48] = hasContent() || selectionCount() > 0 ? PlaybackManager::LedRedBlink : PlaybackManager::LedRed;
    for (int i = 49; i < 54; i++)
        leds[i] = PlaybackManager::LedYellow;
    leds[54] = m_undo.isEmpty() ? PlaybackManager::LedOff : PlaybackManager::LedRed;
    leds[55] = PlaybackManager::LedGreen;
    m_playbacks->setGridLeds(leds);
}
