/*
  Q Light Controller Plus
  programmermanager.cpp

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

#include <QQmlContext>
#include <QQuickView>
#include <QRegularExpression>
#include <QXmlStreamReader>
#include <QXmlStreamWriter>

#include <QDateTime>

#include "programmermanager.h"
#include "mastertimer.h"
#include "linkclock.h"
#include "playbackmanager.h"
#include "contextmanager.h"
#include "functionparent.h"
#include "rgbalgorithm.h"
#include "fixturegroup.h"
#include "qlcphysical.h"
#include "qlcfixturemode.h"
#include "qlccapability.h"
#include "qlcchannel.h"
#include "collection.h"
#include "chaserstep.h"
#include "chaser.h"
#include "rgbmatrix.h"
#include "fixture.h"
#include "scene.h"
#include "efx.h"
#include "doc.h"

/* Name prefix of the fixture groups created for the colour effects: hidden from the group keys */
#define TEMP_PREFIX QStringLiteral("· ")

namespace
{
    enum EffectKind { Move, Colour, Dimmer };

    struct EffectDef
    {
        const char *key;
        const char *label;
        EffectKind kind;
        int efxAlgorithm;       // Move
        const char *script;     // Colour / Dimmer: RGB script name
        qreal beatsPerStep;     // Move: beats per cycle; others: beats per step
    };

    const EffectDef EFFECTS[] =
    {
        { "move_circle",   QT_TRANSLATE_NOOP("ProgrammerManager", "Cercle"),      Move, EFX::Circle,    nullptr, 4 },
        { "move_eight",    QT_TRANSLATE_NOOP("ProgrammerManager", "Huit"),        Move, EFX::Eight,     nullptr, 8 },
        { "move_pan",      QT_TRANSLATE_NOOP("ProgrammerManager", "Balayage"),    Move, EFX::Line,      nullptr, 4 },
        { "move_tilt",     QT_TRANSLATE_NOOP("ProgrammerManager", "Vague"),       Move, EFX::Line2,     nullptr, 4 },
        { "move_diamond",  QT_TRANSLATE_NOOP("ProgrammerManager", "Losange"),     Move, EFX::Diamond,   nullptr, 4 },
        { "move_random",   QT_TRANSLATE_NOOP("ProgrammerManager", "Aléatoire"),   Move, EFX::Lissajous, nullptr, 16 },

        { "colour_rainbow",QT_TRANSLATE_NOOP("ProgrammerManager", "Arc-en-ciel"), Colour, 0, "Gradient",      0.25 },
        { "colour_alt",    QT_TRANSLATE_NOOP("ProgrammerManager", "Alterné"),     Colour, 0, "Alternate",     1 },
        { "colour_wave",   QT_TRANSLATE_NOOP("ProgrammerManager", "Onde"),        Colour, 0, "Sine Wave",     0.25 },
        { "colour_random", QT_TRANSLATE_NOOP("ProgrammerManager", "Étincelles"),  Colour, 0, "Random Single", 0.5 },

        { "dim_chase",     QT_TRANSLATE_NOOP("ProgrammerManager", "Chenillard"),  Dimmer, 0, "Juggle",        0.25 },
        { "dim_evenodd",   QT_TRANSLATE_NOOP("ProgrammerManager", "Pair / impair"), Dimmer, 0, "Even/Odd",    1 },
        { "dim_wave",      QT_TRANSLATE_NOOP("ProgrammerManager", "Respiration"), Dimmer, 0, "Sine Wave",     0.25 },
        { "dim_random",    QT_TRANSLATE_NOOP("ProgrammerManager", "Flashs"),      Dimmer, 0, "Random Single", 0.5 },
    };

    const EffectDef *effectDef(const QString &key)
    {
        for (const EffectDef &def : EFFECTS)
            if (key == QLatin1String(def.key))
                return &def;
        return nullptr;
    }

    QString kindName(EffectKind kind)
    {
        switch (kind)
        {
            case Move: return QStringLiteral("move");
            case Colour: return QStringLiteral("colour");
            default: return QStringLiteral("dimmer");
        }
    }
}

ProgrammerManager::ProgrammerManager(QQuickView *view, Doc *doc, ContextManager *ctx,
                                     PlaybackManager *playbacks, QObject *parent)
    : PreviewContext(view, doc, "PROGRAMMER", parent)
    , m_contextManager(ctx)
    , m_playbacks(playbacks)
    , m_pan(0)
    , m_tilt(0)
    , m_fan(0)
    , m_crossed(false)
    , m_bpm(120)
    , m_size(0.5)
    , m_spread(true)
    , m_cueCounter(0)
    , m_cueFade(0)
    , m_pendingCue(Function::invalidId())
    , m_colorMemories(MemoryCount)
    , m_positionMemories(MemoryCount)
    , m_tempoSource("manual")
    , m_sourceBpm(120)
    , m_tempoMult(1)
    , m_link(new LinkClock(this))
{
    setContextResource("qrc:/Programmer.qml");
    setContextTitle(tr("Programmer"));

    view->rootContext()->setContextProperty("programmer", this);

    connect(m_contextManager, &ContextManager::selectedFixturesChanged, this, &ProgrammerManager::slotSelectionChanged);
    connect(m_playbacks, &PlaybackManager::slotPicked, this, &ProgrammerManager::slotSlotPicked);
    m_sheetTimer.setInterval(200);
    connect(&m_sheetTimer, &QTimer::timeout, this, &ProgrammerManager::slotRefreshSheet);
    defaultMemories();
    connect(m_doc->masterTimer(), &MasterTimer::bpmNumberChanged, this, [this](int bpm)
    {
        if (m_tempoSource == "console" && bpm > 0)
            applyTempo(bpm);
    });
    connect(m_link, &LinkClock::tempoChanged, this, [this](qreal bpm)
    {
        if (m_tempoSource == "link")
            applyTempo(bpm);
    });
    connect(m_link, &LinkClock::peersChanged, this, [this](int peers)
    {
        if (peers > 0 && m_tempoSource == "link")
            applyTempo(m_link->tempo());
        emit tempoSourceChanged();
    });
    connect(m_contextManager, &ContextManager::dumpValuesCountChanged, this, &ProgrammerManager::programmerChanged);
    connect(m_doc, &Doc::fixtureGroupAdded, this, &ProgrammerManager::groupsChanged);
    connect(m_doc, &Doc::fixtureGroupRemoved, this, &ProgrammerManager::groupsChanged);
    connect(m_doc, &Doc::loaded, this, [this]()
    {
        m_effects.clear();
        // effects still running in the programmer when the project was saved:
        // never recorded, they are leftovers
        for (Function *f : m_doc->functions())
            if (f->name().startsWith(tr("Programmeur · ")))
                m_doc->deleteFunction(f->id());
        for (FixtureGroup *grp : m_doc->fixtureGroups())
            if (grp->name().startsWith(TEMP_PREFIX))
                m_doc->deleteFixtureGroup(grp->id());
        emit groupsChanged();
        emit effectsChanged();
        emit programmerChanged();
    });
    connect(m_doc, &Doc::cleared, this, [this]()
    {
        m_effects.clear();
        emit effectsChanged();
    });
}

ProgrammerManager::~ProgrammerManager()
{
}

/*********************************************************************
 * Selection
 *********************************************************************/

QList<quint32> ProgrammerManager::selectedFixtures() const
{
    QList<quint32> selected = m_contextManager->selectedFixtureIDList();
    QList<quint32> ordered;

    // keep the order of the group the selection came from (odd/even, fan, effects)
    for (quint32 id : m_selectionOrder)
        if (selected.contains(id))
            ordered.append(id);

    QList<quint32> rest;
    for (quint32 id : selected)
        if (ordered.contains(id) == false)
            rest.append(id);
    std::sort(rest.begin(), rest.end());

    return ordered + rest;
}

QVariantList ProgrammerManager::groups() const
{
    QVariantList list;
    QList<quint32> selected = m_contextManager->selectedFixtureIDList();

    for (FixtureGroup *grp : m_doc->fixtureGroups())
    {
        if (grp->name().startsWith(TEMP_PREFIX))
            continue;

        QList<quint32> ids = grp->fixtureList();
        int inSelection = 0;
        for (quint32 id : ids)
            if (selected.contains(id))
                inSelection++;

        QVariantMap map;
        map.insert("id", grp->id());
        map.insert("name", grp->name());
        map.insert("count", ids.count());
        map.insert("selected", ids.isEmpty() == false && inSelection == ids.count());
        map.insert("partial", inSelection > 0 && inSelection < ids.count());
        list.append(map);
    }
    return list;
}

int ProgrammerManager::selectionCount() const
{
    return m_contextManager->selectedFixtureIDList().count();
}

QString ProgrammerManager::selectionText() const
{
    QList<quint32> ids = selectedFixtures();
    if (ids.isEmpty())
        return tr("Aucune machine sélectionnée");

    QStringList names;
    for (quint32 id : ids)
    {
        Fixture *fxi = m_doc->fixture(id);
        if (fxi)
            names.append(fxi->name());
    }
    if (names.count() <= 4)
        return names.join(" · ");
    return tr("%1 · %2 · … · %3").arg(names.at(0), names.at(1), names.last());
}

void ProgrammerManager::slotSelectionChanged()
{
    emit selectionChanged();
    emit groupsChanged();
    emit programmerChanged();
}

void ProgrammerManager::selectGroup(quint32 groupId, bool additive)
{
    FixtureGroup *grp = m_doc->fixtureGroup(groupId);
    if (grp == nullptr)
        return;

    QList<quint32> ids = grp->fixtureList();
    QList<quint32> selected = m_contextManager->selectedFixtureIDList();
    bool allSelected = ids.isEmpty() == false;
    for (quint32 id : ids)
        if (selected.contains(id) == false)
            allSelected = false;

    if (additive && allSelected)
    {
        // second tap with SHIFT: remove the group from the selection
        for (quint32 id : ids)
            m_contextManager->setFixtureIDSelection(id, false);
        return;
    }

    if (additive == false)
    {
        m_contextManager->resetFixtureSelection();
        m_selectionOrder.clear();
    }

    for (quint32 id : ids)
    {
        if (m_selectionOrder.contains(id) == false)
            m_selectionOrder.append(id);
        m_contextManager->setFixtureIDSelection(id, true);
    }
}

void ProgrammerManager::selectAll()
{
    m_contextManager->resetFixtureSelection();
    m_selectionOrder.clear();
    for (Fixture *fxi : m_doc->fixtures())
    {
        m_selectionOrder.append(fxi->id());
        m_contextManager->setFixtureIDSelection(fxi->id(), true);
    }
}

void ProgrammerManager::clearSelection()
{
    m_contextManager->resetFixtureSelection();
    m_selectionOrder.clear();
}

void ProgrammerManager::selectOddEven(bool odd)
{
    QList<quint32> ids = selectedFixtures();
    for (int i = 0; i < ids.count(); i++)
    {
        bool keep = (i % 2 == 0) == odd;
        if (keep == false)
            m_contextManager->setFixtureIDSelection(ids.at(i), false);
    }
}

/*********************************************************************
 * Attributes
 *********************************************************************/

void ProgrammerManager::setIntensity(qreal level)
{
    m_contextManager->setChannelValueByType(QLCChannel::Intensity, qRound(qBound(0.0, level, 1.0) * 255));
}

void ProgrammerManager::setColor(QColor color)
{
    dropActiveRefs("color", selectedFixtures());
    m_lastColor = color;
    m_contextManager->setColorValue(color, QColor(0, 0, 0));
}

void ProgrammerManager::setStrobe(qreal speed)
{
    QList<SceneValue> values;
    for (quint32 id : selectedFixtures())
    {
        Fixture *fxi = m_doc->fixture(id);
        if (fxi == nullptr)
            continue;

        for (quint32 ch = 0; ch < fxi->channels(); ch++)
        {
            const QLCChannel *channel = fxi->channel(ch);
            if (channel == nullptr || channel->group() != QLCChannel::Shutter)
                continue;

            // look for the "open" and the "strobe" ranges of the channel
            uchar value = 0;
            for (QLCCapability *cap : channel->capabilities())
            {
                if (speed <= 0 && cap->preset() == QLCCapability::ShutterOpen)
                {
                    value = cap->middle();
                    break;
                }
                if (speed > 0 && (cap->preset() == QLCCapability::StrobeSlowToFast ||
                                  cap->preset() == QLCCapability::StrobeFrequency ||
                                  cap->preset() == QLCCapability::StrobeFreqRange))
                {
                    value = uchar(cap->min() + (cap->max() - cap->min()) * qBound(0.0, speed, 1.0));
                    break;
                }
            }
            values.append(SceneValue(id, ch, value));
        }
    }
    m_contextManager->setChannelValues(values);
}

void ProgrammerManager::setZoom(qreal amount)
{
    amount = qBound(0.0, amount, 1.0);
    QList<SceneValue> values;
    for (quint32 id : selectedFixtures())
    {
        Fixture *fxi = m_doc->fixture(id);
        if (fxi == nullptr)
            continue;

        for (quint32 ch = 0; ch < fxi->channels(); ch++)
        {
            const QLCChannel *channel = fxi->channel(ch);
            if (channel == nullptr)
                continue;
            if (channel->preset() == QLCChannel::BeamZoomSmallBig)
                values.append(SceneValue(id, ch, uchar(qRound(amount * 255))));
            else if (channel->preset() == QLCChannel::BeamZoomBigSmall)
                values.append(SceneValue(id, ch, uchar(qRound((1.0 - amount) * 255))));
        }
    }
    m_contextManager->setChannelValues(values);
}

void ProgrammerManager::setPosition(qreal panDegrees, qreal tiltDegrees)
{
    dropActiveRefs("position", selectedFixtures());
    m_pan = panDegrees;
    m_tilt = tiltDegrees;
    applyPosition();
    emit positionChanged();
}

void ProgrammerManager::setFan(qreal degrees)
{
    dropActiveRefs("position", selectedFixtures());
    m_fan = degrees;
    applyPosition();
    emit positionChanged();
}

void ProgrammerManager::positionPreset(const QString &name)
{
    dropActiveRefs("position", selectedFixtures());
    m_crossed = false;
    if (name == "centre")         { m_pan = 0; m_tilt = 0;   m_fan = 0; }
    else if (name == "face")      { m_pan = 0; m_tilt = 45;  m_fan = 0; }
    else if (name == "public")    { m_pan = 0; m_tilt = 75;  m_fan = 0; }
    else if (name == "horizon")   { m_pan = 0; m_tilt = 90;  m_fan = 0; }
    else if (name == "back")      { m_pan = 0; m_tilt = -45; m_fan = 0; }
    else if (name == "fan")       { m_pan = 0; m_tilt = 45;  m_fan = 60; }
    else if (name == "fanwide")   { m_pan = 0; m_tilt = 70;  m_fan = 120; }
    else if (name == "cross")     { m_pan = 0; m_tilt = 45;  m_fan = 50; m_crossed = true; }
    applyPosition();
    emit positionChanged();
}

QList<SceneValue> ProgrammerManager::positionValues(qreal pan, qreal tilt, qreal fan, bool crossed,
                                                    const QList<quint32> &ids) const
{
    int count = ids.count();
    QList<SceneValue> values;

    for (int i = 0; i < count; i++)
    {
        Fixture *fxi = m_doc->fixture(ids.at(i));
        if (fxi == nullptr || fxi->fixtureMode() == nullptr)
            continue;

        QLCPhysical phy = fxi->fixtureMode()->physical();
        qreal panMax = phy.focusPanMax() ? phy.focusPanMax() : 360;
        qreal tiltMax = phy.focusTiltMax() ? phy.focusTiltMax() : 270;

        // spread the pan across the selection, or cross every other fixture
        qreal offset = 0;
        if (crossed)
            offset = (i % 2 == 0 ? -0.5 : 0.5) * fan;
        else if (count > 1)
            offset = (qreal(i) / (count - 1) - 0.5) * fan;

        qreal panDeg = qBound(0.0, panMax / 2 + pan + offset, panMax);
        qreal tiltDeg = qBound(0.0, tiltMax / 2 + tilt, tiltMax);

        values.append(fxi->positionToValues(QLCChannel::Pan, panDeg));
        values.append(fxi->positionToValues(QLCChannel::Tilt, tiltDeg));
    }
    return values;
}

void ProgrammerManager::applyPosition()
{
    m_contextManager->setChannelValues(positionValues(m_pan, m_tilt, m_fan, m_crossed, selectedFixtures()));
}

/*********************************************************************
 * Effects
 *********************************************************************/

QVariantList ProgrammerManager::effects() const
{
    QVariantList list;
    for (const EffectDef &def : EFFECTS)
    {
        QVariantMap map;
        map.insert("key", QString(def.key));
        map.insert("label", tr(def.label));
        map.insert("kind", kindName(def.kind));
        map.insert("running", m_effects.contains(def.key));
        list.append(map);
    }
    return list;
}

uint ProgrammerManager::effectDuration(const QString &key) const
{
    const EffectDef *def = effectDef(key);
    qreal beat = 60000.0 / qBound(20.0, m_bpm, 300.0);
    return uint(qMax(20.0, beat * (def ? def->beatsPerStep : 1)));
}

Function *ProgrammerManager::createEffect(const QString &key, const QList<quint32> &fixtures)
{
    const EffectDef *def = effectDef(key);
    if (def == nullptr || fixtures.isEmpty())
        return nullptr;

    QString name = tr("Programmeur · %1").arg(tr(def->label));

    if (def->kind == Move)
    {
        EFX *efx = new EFX(m_doc);
        efx->setName(name);
        efx->setAlgorithm(EFX::Algorithm(def->efxAlgorithm));
        // relative: the pattern moves around the programmer (or the cue) position
        efx->setIsRelative(true);
        efx->setXOffset(127);
        efx->setYOffset(127);

        int added = 0;
        for (quint32 id : fixtures)
        {
            Fixture *fxi = m_doc->fixture(id);
            if (fxi == nullptr)
                continue;
            if (fxi->channelNumber(QLCChannel::Pan, QLCChannel::MSB) == QLCChannel::invalid() &&
                fxi->channelNumber(QLCChannel::Tilt, QLCChannel::MSB) == QLCChannel::invalid())
                continue;
            if (efx->addFixture(id, 0))
                added++;
        }
        if (added == 0)
        {
            delete efx;
            return nullptr;
        }

        if (m_doc->addFunction(efx) == false)
        {
            delete efx;
            return nullptr;
        }
        m_effects.insert(key, { efx->id(), FixtureGroup::invalidId() });
        m_tempoLinks.insert(efx->id(), def->beatsPerStep);
        return efx;
    }

    // colour / intensity effects: an RGB matrix on a row made of the selection
    FixtureGroup *grp = new FixtureGroup(m_doc);
    grp->setName(TEMP_PREFIX + name);
    grp->setSize(QSize(fixtures.count(), 1));
    for (int i = 0; i < fixtures.count(); i++)
        grp->assignFixture(fixtures.at(i), QLCPoint(i, 0));
    if (m_doc->addFixtureGroup(grp) == false)
    {
        delete grp;
        return nullptr;
    }

    RGBMatrix *mtx = new RGBMatrix(m_doc);
    mtx->setName(name);
    mtx->setFixtureGroup(grp->id());
    RGBAlgorithm *algo = RGBAlgorithm::algorithm(m_doc, QString(def->script));
    if (algo != nullptr)
        mtx->setAlgorithm(algo);
    mtx->setDimmerControl(false);

    if (def->kind == Dimmer)
    {
        mtx->setControlMode(RGBMatrix::ControlModeDimmer);
        mtx->setColor(0, Qt::white);
        mtx->setColor(1, Qt::black);
    }
    else
    {
        mtx->setControlMode(RGBMatrix::ControlModeRgb);
        // two colours: the one in the programmer (if any) and white
        QColor main(QColor::fromHsv(270, 140, 255));
        for (const SceneValue &sv : m_contextManager->dumpValues())
        {
            Fixture *fxi = m_doc->fixture(sv.fxi);
            const QLCChannel *ch = fxi ? fxi->channel(sv.channel) : nullptr;
            if (ch == nullptr || fixtures.contains(sv.fxi) == false || ch->group() != QLCChannel::Intensity)
                continue;
            if (ch->colour() == QLCChannel::Red) main.setRed(sv.value);
            else if (ch->colour() == QLCChannel::Green) main.setGreen(sv.value);
            else if (ch->colour() == QLCChannel::Blue) main.setBlue(sv.value);
        }
        mtx->setColor(0, main);
        mtx->setColor(1, key == "colour_alt" ? QColor(Qt::white) : QColor(Qt::black));
    }

    if (m_doc->addFunction(mtx) == false)
    {
        delete mtx;
        m_doc->deleteFixtureGroup(grp->id());
        return nullptr;
    }
    m_effects.insert(key, { mtx->id(), grp->id() });
    m_tempoLinks.insert(mtx->id(), def->beatsPerStep);
    return mtx;
}

void ProgrammerManager::toggleEffect(const QString &key)
{
    if (m_effects.contains(key))
    {
        removeEffect(key, true);
        emit effectsChanged();
        return;
    }

    const EffectDef *def = effectDef(key);
    if (def == nullptr)
        return;

    // only one effect per family: a new circle replaces the eight
    QStringList same;
    for (auto it = m_effects.cbegin(); it != m_effects.cend(); ++it)
    {
        const EffectDef *other = effectDef(it.key());
        if (other && other->kind == def->kind)
            same.append(it.key());
    }
    for (const QString &k : same)
        removeEffect(k, true);

    QList<quint32> fixtures = selectedFixtures();

    // the effect takes over the attribute: release the programmer values it drives,
    // otherwise they would hide it
    if (def->kind != Move)
    {
        QList<SceneValue> release;
        for (const SceneValue &sv : m_contextManager->dumpValues())
        {
            if (fixtures.contains(sv.fxi) == false)
                continue;
            Fixture *fxi = m_doc->fixture(sv.fxi);
            const QLCChannel *ch = fxi ? fxi->channel(sv.channel) : nullptr;
            if (ch == nullptr || ch->group() != QLCChannel::Intensity)
                continue;
            bool isDimmer = ch->colour() == QLCChannel::NoColour;
            if ((def->kind == Dimmer) == isDimmer)
                release.append(sv);
        }
        m_contextManager->unsetDumpChannels(release);
    }

    Function *f = createEffect(key, fixtures);
    if (f != nullptr)
    {
        updateEffectParams();
        f->start(m_doc->masterTimer(), FunctionParent::master());
    }
    emit effectsChanged();
}

void ProgrammerManager::removeEffect(const QString &key, bool deleteFunction)
{
    if (m_effects.contains(key) == false)
        return;

    Effect e = m_effects.take(key);
    Function *f = m_doc->function(e.functionId);
    if (f != nullptr)
    {
        if (f->isRunning())
        {
            if (deleteFunction)
                f->stopAndWait();
            else
                f->stop(FunctionParent::master());
        }
        if (deleteFunction)
        {
            m_tempoLinks.remove(e.functionId);
            m_doc->deleteFunction(e.functionId);
        }
    }
    if (deleteFunction && e.groupId != FixtureGroup::invalidId())
        m_doc->deleteFixtureGroup(e.groupId);
}

void ProgrammerManager::clearEffects()
{
    const QStringList keys = m_effects.keys();
    for (const QString &key : keys)
        removeEffect(key, true);
    emit effectsChanged();
}

void ProgrammerManager::updateEffectParams()
{
    // every effect recorded in a cue keeps following the show tempo
    qreal beat = 60000.0 / qBound(20.0, m_bpm, 300.0);
    for (auto it = m_tempoLinks.begin(); it != m_tempoLinks.end(); )
    {
        Function *f = m_doc->function(it.key());
        if (f == nullptr)
        {
            it = m_tempoLinks.erase(it);
            continue;
        }
        f->setDuration(uint(qMax(20.0, beat * it.value())));
        ++it;
    }

    for (auto it = m_effects.cbegin(); it != m_effects.cend(); ++it)
    {
        Function *f = m_doc->function(it.value().functionId);
        if (f == nullptr)
            continue;

        f->setDuration(effectDuration(it.key()));

        EFX *efx = qobject_cast<EFX *>(f);
        if (efx != nullptr)
        {
            // relative pattern: 255 would sweep the whole pan/tilt range, keep it stage sized
            int size = qRound(6 + m_size * 80);
            efx->setWidth(size);
            efx->setHeight(size);
            efx->setPropagationMode(m_spread ? EFX::Asymmetric : EFX::Parallel);
        }
    }
}

void ProgrammerManager::setEffectBpm(qreal bpm)
{
    // set by hand: stop following the console or Link
    if (m_tempoSource != "manual")
        setTempoSource("manual");
    m_tempoMult = 1;
    applyTempo(bpm);
}

void ProgrammerManager::applyTempo(qreal sourceBpm)
{
    m_sourceBpm = qBound(20.0, sourceBpm, 300.0);
    qreal bpm = qBound(20.0, m_sourceBpm * m_tempoMult, 300.0);
    if (qAbs(bpm - m_bpm) < 0.005)
        return;
    m_bpm = bpm;
    updateEffectParams();
    emit effectParamsChanged();
}

void ProgrammerManager::setTempoMultiplier(qreal mult)
{
    m_tempoMult = qBound(0.125, mult, 8.0);
    applyTempo(m_sourceBpm);
    emit effectParamsChanged();
}

void ProgrammerManager::setTempoSource(const QString &source)
{
    QString src = (source == "console" || (source == "link" && linkAvailable())) ? source : QStringLiteral("manual");
    if (src == m_tempoSource)
        return;
    m_tempoSource = src;
    m_link->setEnabled(src == "link");
    if (src == "console" && m_doc->masterTimer()->bpmNumber() > 0)
        applyTempo(m_doc->masterTimer()->bpmNumber());
    else if (src == "link" && m_link->peers() > 0)
        applyTempo(m_link->tempo());
    else if (src == "manual")
    {
        // keep the tempo we had, as a plain manual value
        m_sourceBpm = m_bpm;
        m_tempoMult = 1;
    }
    m_doc->setModified();
    emit tempoSourceChanged();
    emit effectParamsChanged();
}

bool ProgrammerManager::linkAvailable() const
{
    return LinkClock::available();
}

int ProgrammerManager::linkPeers() const
{
    return m_link->peers();
}

void ProgrammerManager::tap()
{
    qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (m_taps.isEmpty() == false && now - m_taps.last() > 2500)
        m_taps.clear();
    m_taps.append(now);
    while (m_taps.count() > 8)
        m_taps.removeFirst();
    if (m_taps.count() < 2)
        return;
    qreal interval = qreal(m_taps.last() - m_taps.first()) / (m_taps.count() - 1);
    if (interval > 0)
        setEffectBpm(qRound(60000.0 / interval * 10) / 10.0);
}

/*********************************************************************
 * Presets followed by the recorded cues
 *********************************************************************/

void ProgrammerManager::dropActiveRefs(const QString &kind, const QList<quint32> &fixtures)
{
    for (int i = m_activeRefs.count() - 1; i >= 0; i--)
    {
        PresetRef &ref = m_activeRefs[i];
        if (ref.kind != kind)
            continue;
        for (quint32 id : fixtures)
            ref.fixtures.removeAll(id);
        if (ref.fixtures.isEmpty())
            m_activeRefs.removeAt(i);
    }
}

void ProgrammerManager::linkActiveRefs(quint32 sceneId)
{
    for (const PresetRef &active : m_activeRefs)
    {
        // what the scene held for these fixtures is replaced
        for (int i = m_presetLinks.count() - 1; i >= 0; i--)
        {
            PresetRef &link = m_presetLinks[i];
            if (link.sceneId != sceneId || link.kind != active.kind)
                continue;
            for (quint32 id : active.fixtures)
                link.fixtures.removeAll(id);
            if (link.fixtures.isEmpty())
                m_presetLinks.removeAt(i);
        }
        PresetRef link = active;
        link.sceneId = sceneId;
        m_presetLinks.append(link);
    }
}

int ProgrammerManager::presetCueCount(const QString &kind, int index) const
{
    QSet<quint32> scenes;
    for (const PresetRef &link : m_presetLinks)
        if (link.kind == kind && link.index == index && m_doc->function(link.sceneId) != nullptr)
            scenes.insert(link.sceneId);
    return scenes.count();
}

int ProgrammerManager::applyPresetToCues(const QString &kind, int index)
{
    const QVector<Memory> &list = kind == "color" ? m_colorMemories : m_positionMemories;
    if (index < 0 || index >= list.count() || list[index].used == false)
        return 0;
    const Memory &m = list[index];

    QSet<quint32> scenes;
    for (int i = m_presetLinks.count() - 1; i >= 0; i--)
    {
        const PresetRef &link = m_presetLinks.at(i);
        if (link.kind != kind || link.index != index)
            continue;
        Scene *scene = qobject_cast<Scene *>(m_doc->function(link.sceneId));
        if (scene == nullptr)
        {
            m_presetLinks.removeAt(i);      // the cue was deleted
            continue;
        }

        QList<SceneValue> values;
        if (kind == "color")
        {
            for (quint32 id : link.fixtures)
            {
                Fixture *fxi = m_doc->fixture(id);
                if (fxi == nullptr)
                    continue;
                QVector<quint32> rgb = fxi->rgbChannels();
                if (rgb.count() == 3)
                {
                    values.append(SceneValue(id, rgb[0], uchar(m.color.red())));
                    values.append(SceneValue(id, rgb[1], uchar(m.color.green())));
                    values.append(SceneValue(id, rgb[2], uchar(m.color.blue())));
                }
            }
        }
        else
            values = positionValues(m.pan, m.tilt, m.fan, m.crossed, link.fixtures);

        for (const SceneValue &sv : values)
            scene->setValue(sv, false, false);      // a running cue follows live (no HTP check: lower values too)
        scenes.insert(link.sceneId);
    }
    if (scenes.isEmpty() == false)
        m_doc->setModified();
    return scenes.count();
}

void ProgrammerManager::setEffectSize(qreal size)
{
    size = qBound(0.0, size, 1.0);
    if (qFuzzyCompare(size + 1, m_size + 1))
        return;
    m_size = size;
    updateEffectParams();
    emit effectParamsChanged();
}

void ProgrammerManager::setEffectSpread(bool spread)
{
    if (spread == m_spread)
        return;
    m_spread = spread;
    updateEffectParams();
    emit effectParamsChanged();
}

/*********************************************************************
 * Programmer
 *********************************************************************/

int ProgrammerManager::programmerCount() const
{
    return m_contextManager->dumpValues().count();
}

QString ProgrammerManager::nextCueName() const
{
    int highest = m_cueCounter;
    static const QRegularExpression re(QStringLiteral("^Cue (\\d+)$"));
    for (Function *f : m_doc->functions())
    {
        QRegularExpressionMatch m = re.match(f->name());
        if (m.hasMatch())
            highest = qMax(highest, m.captured(1).toInt());
    }
    return QString("Cue %1").arg(highest + 1);
}

bool ProgrammerManager::hasContent() const
{
    return m_contextManager->dumpValues().isEmpty() == false || m_effects.isEmpty() == false;
}

quint32 ProgrammerManager::buildCue(const QString &cueName)
{
    QList<SceneValue> values = m_contextManager->dumpValues();
    QList<quint32> parts;
    bool multiple = (values.isEmpty() ? 0 : 1) + m_effects.count() > 1;

    if (values.isEmpty() == false)
    {
        Scene *scene = new Scene(m_doc);
        scene->setName(multiple ? tr("%1 · base").arg(cueName) : cueName);
        for (const SceneValue &sv : values)
            scene->setValue(sv);
        uint fade = uint(qRound(m_cueFade * 1000));
        scene->setFadeInSpeed(fade);
        scene->setFadeOutSpeed(fade);
        if (m_doc->addFunction(scene) == false)
        {
            delete scene;
            return Function::invalidId();
        }
        linkActiveRefs(scene->id());
        parts.append(scene->id());
    }

    for (auto it = m_effects.cbegin(); it != m_effects.cend(); ++it)
    {
        Function *f = m_doc->function(it.value().functionId);
        const EffectDef *def = effectDef(it.key());
        if (f == nullptr)
            continue;
        f->setName(multiple ? tr("%1 · %2").arg(cueName, def ? tr(def->label) : QString()) : cueName);
        // the fixture group of a matrix becomes a normal one
        FixtureGroup *grp = m_doc->fixtureGroup(it.value().groupId);
        if (grp != nullptr)
            grp->setName(tr("%1 · groupe").arg(cueName));
        parts.append(f->id());
    }

    if (parts.isEmpty())
        return Function::invalidId();

    quint32 cueId = parts.first();
    if (parts.count() > 1)
    {
        Collection *coll = new Collection(m_doc);
        coll->setName(cueName);
        if (m_doc->addFunction(coll) == false)
        {
            delete coll;
            return Function::invalidId();
        }
        for (quint32 id : parts)
            coll->addFunction(id);
        cueId = coll->id();
    }

    resetAfterRecord();
    return cueId;
}

void ProgrammerManager::resetAfterRecord()
{
    // the effects now belong to the cue: stop them without deleting them
    const QStringList keys = m_effects.keys();
    for (const QString &key : keys)
        removeEffect(key, false);
    m_contextManager->resetDumpValues();
    m_activeRefs.clear();
    m_cueCounter++;
    m_pan = m_tilt = m_fan = 0;
    m_crossed = false;
    emit positionChanged();
    emit effectsChanged();
    emit programmerChanged();
    emit memoriesChanged();     // cue counts of the presets
}

quint32 ProgrammerManager::record(const QString &name, bool toFreeSlot)
{
    QString cueName = name.trimmed().isEmpty() ? nextCueName() : name.trimmed();
    quint32 cueId = buildCue(cueName);
    if (cueId == Function::invalidId())
        return cueId;

    if (toFreeSlot && m_playbacks->assignToFree(cueId))
    {
        emit recorded(cueName, tr("premier emplacement libre de la page"));
    }
    else
    {
        m_playbacks->setArmedFunction(cueId);
        m_contextManager->switchToContext("PLAYBACKS");
        emit recorded(cueName, tr("à placer : clique sur un playback ou un bouton"));
    }
    return cueId;
}

void ProgrammerManager::recordAppend(const QString &name)
{
    if (hasContent() == false)
        return;
    m_pendingName = name.trimmed().isEmpty() ? nextCueName() : name.trimmed();
    m_pendingCue = buildCue(m_pendingName);
    if (m_pendingCue == Function::invalidId())
        return;
    m_playbacks->setPickMode("append");
    m_contextManager->switchToContext("PLAYBACKS");
}

void ProgrammerManager::startUpdate()
{
    if (hasContent() == false)
        return;
    m_playbacks->setPickMode("update");
    m_contextManager->switchToContext("PLAYBACKS");
}

void ProgrammerManager::slotSlotPicked(QString mode, bool isFader, int index, quint32 functionId)
{
    if (mode == "append")
        appendToSlot(isFader, index, functionId);
    else if (mode == "update")
        updateSlot(isFader, index, functionId);
}

void ProgrammerManager::appendToSlot(bool isFader, int index, quint32 slotFid)
{
    quint32 cue = m_pendingCue;
    m_pendingCue = Function::invalidId();
    if (m_doc->function(cue) == nullptr)
        return;

    Function *current = m_doc->function(slotFid);
    if (current == nullptr)
    {
        // empty slot: the cue simply goes there
        m_playbacks->replaceSlotFunction(isFader, index, cue);
        emit recorded(m_pendingName, tr("placé sur l'emplacement choisi"));
        return;
    }

    Chaser *stack = qobject_cast<Chaser *>(current);
    if (stack == nullptr)
    {
        // turn the slot into a cue stack: the current cue, then the new one, GO goes to the next
        stack = new Chaser(m_doc);
        stack->setName(tr("Pile · %1").arg(current->name()));
        stack->setRunOrder(Function::Loop);
        stack->setFadeInMode(Chaser::Default);
        stack->setFadeOutMode(Chaser::Default);
        stack->setDurationMode(Chaser::Common);
        stack->setDuration(Function::infiniteSpeed());
        if (m_doc->addFunction(stack) == false)
        {
            delete stack;
            return;
        }
        stack->addStep(ChaserStep(current->id()));
        stack->addStep(ChaserStep(cue));
        m_playbacks->replaceSlotFunction(isFader, index, stack->id());
    }
    else
    {
        stack->addStep(ChaserStep(cue));
    }
    m_doc->setModified();
    emit recorded(m_pendingName, tr("ajouté en pas %1 de « %2 »").arg(stack->stepsCount()).arg(stack->name()));
}

void ProgrammerManager::updateSlot(bool isFader, int index, quint32 slotFid)
{
    Function *f = m_doc->function(slotFid);
    if (f == nullptr || hasContent() == false)
        return;

    // the function to update: the slot's one, or the current step of a cue stack
    Chaser *stack = qobject_cast<Chaser *>(f);
    int stepIndex = -1;
    if (stack != nullptr && stack->stepsCount() > 0)
    {
        stepIndex = stack->isRunning() ? qMax(0, stack->currentStepIndex()) : 0;
        ChaserStep *step = stack->stepAt(stepIndex);
        f = step ? m_doc->function(step->fid) : nullptr;
        if (f == nullptr)
            return;
    }

    Collection *coll = qobject_cast<Collection *>(f);
    Scene *scene = qobject_cast<Scene *>(f);
    if (coll != nullptr)
    {
        for (quint32 id : coll->functions())
        {
            scene = qobject_cast<Scene *>(m_doc->function(id));
            if (scene)
                break;
        }
    }

    QList<SceneValue> values = m_contextManager->dumpValues();
    if (values.isEmpty() == false)
    {
        if (scene == nullptr)
        {
            scene = new Scene(m_doc);
            scene->setName(tr("%1 · base").arg(f->name()));
            if (m_doc->addFunction(scene) == false)
            {
                delete scene;
                return;
            }
            if (coll)
                coll->addFunction(scene->id(), 0);
        }
        for (const SceneValue &sv : values)
            scene->setValue(sv);
        linkActiveRefs(scene->id());
    }

    if (m_effects.isEmpty() == false)
    {
        if (coll == nullptr)
        {
            // a plain scene (or effect) becomes a collection holding it and the new effects
            coll = new Collection(m_doc);
            coll->setName(f->name());
            if (m_doc->addFunction(coll) == false)
            {
                delete coll;
                return;
            }
            coll->addFunction(f->id());
            f->setName(tr("%1 · base").arg(f->name()));
            if (stack != nullptr)
                stack->stepAt(stepIndex)->fid = coll->id();
            else
                m_playbacks->replaceSlotFunction(isFader, index, coll->id());
        }
        for (auto it = m_effects.cbegin(); it != m_effects.cend(); ++it)
        {
            Function *fx = m_doc->function(it.value().functionId);
            const EffectDef *def = effectDef(it.key());
            if (fx == nullptr)
                continue;
            fx->setName(tr("%1 · %2").arg(coll->name(), def ? tr(def->label) : QString()));
            FixtureGroup *grp = m_doc->fixtureGroup(it.value().groupId);
            if (grp)
                grp->setName(tr("%1 · groupe").arg(coll->name()));
            coll->addFunction(fx->id());
        }
    }

    QString name = coll ? coll->name() : f->name();
    resetAfterRecord();
    m_doc->setModified();
    emit recorded(name, stack ? tr("pas %1 mis à jour").arg(stepIndex + 1) : tr("mis à jour"));
}

void ProgrammerManager::locate()
{
    m_contextManager->highlightFixtureSelection();
    positionPreset("centre");
}

void ProgrammerManager::setCueFade(qreal seconds)
{
    seconds = qBound(0.0, seconds, 10.0);
    if (qFuzzyCompare(seconds + 1, m_cueFade + 1))
        return;
    m_cueFade = seconds;
    emit cueFadeChanged();
}

/*********************************************************************
 * Memories (user palettes)
 *********************************************************************/

QVariantList ProgrammerManager::memoryList(const QVector<Memory> &list, bool colour) const
{
    QVariantList out;
    for (const Memory &m : list)
    {
        QVariantMap map;
        map.insert("used", m.used);
        map.insert("name", m.name);
        map.insert("cues", m.used ? presetCueCount(colour ? "color" : "position", int(out.count())) : 0);
        if (colour)
            map.insert("color", m.used ? m.color : QColor(Qt::transparent));
        out.append(map);
    }
    return out;
}

QVariantList ProgrammerManager::colorMemories() const
{
    return memoryList(m_colorMemories, true);
}

QVariantList ProgrammerManager::positionMemories() const
{
    return memoryList(m_positionMemories, false);
}

void ProgrammerManager::memoryPress(const QString &kind, int index)
{
    QVector<Memory> &list = kind == "color" ? m_colorMemories : m_positionMemories;
    if (index < 0 || index >= list.count())
        return;

    Memory &m = list[index];
    if (m.used)
    {
        // recall
        QList<quint32> ids = selectedFixtures();
        dropActiveRefs(kind, ids);
        if (ids.isEmpty() == false)
            m_activeRefs.append({ Function::invalidId(), kind, index, ids });
        if (kind == "color")
        {
            m_lastColor = m.color;
            m_contextManager->setColorValue(m.color, QColor(0, 0, 0));
        }
        else
        {
            m_pan = m.pan;
            m_tilt = m.tilt;
            m_fan = m.fan;
            m_crossed = m.crossed;
            applyPosition();
            emit positionChanged();
        }
        return;
    }

    // store
    if (kind == "color")
    {
        if (m_lastColor.isValid() == false)
            return;
        m.color = m_lastColor;
        m.name = m_lastColor.name();
    }
    else
    {
        m.pan = m_pan;
        m.tilt = m_tilt;
        m.fan = m_fan;
        m.crossed = m_crossed;
        m.name = m_crossed ? tr("Croisé") : (m_fan > 0 ? tr("Éventail %1°").arg(qRound(m_fan))
                                                     : tr("%1° / %2°").arg(qRound(m_pan)).arg(qRound(m_tilt)));
    }
    m.used = true;
    m_doc->setModified();
    emit memoriesChanged();
}

void ProgrammerManager::memoryClear(const QString &kind, int index)
{
    QVector<Memory> &list = kind == "color" ? m_colorMemories : m_positionMemories;
    if (index < 0 || index >= list.count() || list[index].used == false)
        return;
    list[index] = Memory();
    for (int i = m_presetLinks.count() - 1; i >= 0; i--)
        if (m_presetLinks.at(i).kind == kind && m_presetLinks.at(i).index == index)
            m_presetLinks.removeAt(i);
    m_doc->setModified();
    emit memoriesChanged();
}

void ProgrammerManager::resetContents()
{
    m_colorMemories = QVector<Memory>(MemoryCount);
    m_positionMemories = QVector<Memory>(MemoryCount);
    m_pendingCue = Function::invalidId();
    m_tempoLinks.clear();
    m_presetLinks.clear();
    m_activeRefs.clear();
    defaultMemories();
    emit memoriesChanged();
}

/** Presets a new project starts with (a saved project brings its own) */
void ProgrammerManager::defaultMemories()
{
    static const struct { const char *name; const char *color; } colours[] =
    {
        { QT_TRANSLATE_NOOP("ProgrammerManager", "Rouge"), "#ff2020" }, { QT_TRANSLATE_NOOP("ProgrammerManager", "Orange"), "#ff6a00" },
        { QT_TRANSLATE_NOOP("ProgrammerManager", "Ambre"), "#ffb000" }, { QT_TRANSLATE_NOOP("ProgrammerManager", "Jaune"), "#fff200" },
        { QT_TRANSLATE_NOOP("ProgrammerManager", "Vert"), "#40ff30" },  { QT_TRANSLATE_NOOP("ProgrammerManager", "Cyan"), "#00ffd0" },
        { QT_TRANSLATE_NOOP("ProgrammerManager", "Bleu"), "#0090ff" },  { QT_TRANSLATE_NOOP("ProgrammerManager", "Bleu nuit"), "#2020ff" },
        { QT_TRANSLATE_NOOP("ProgrammerManager", "KAHO"), "#a98bff" },  { QT_TRANSLATE_NOOP("ProgrammerManager", "Violet"), "#9000ff" },
        { QT_TRANSLATE_NOOP("ProgrammerManager", "Magenta"), "#ff00c8" }, { QT_TRANSLATE_NOOP("ProgrammerManager", "Blanc"), "#ffffff" },
    };
    int i = 0;
    for (const auto &c : colours)
    {
        Memory &m = m_colorMemories[i++];
        m.used = true;
        m.name = tr(c.name);
        m.color = QColor(c.color);
    }

    static const struct { const char *name; qreal pan, tilt, fan; bool crossed; } positions[] =
    {
        { QT_TRANSLATE_NOOP("ProgrammerManager", "Centre"), 0, 0, 0, false },
        { QT_TRANSLATE_NOOP("ProgrammerManager", "Face"), 0, 45, 0, false },
        { QT_TRANSLATE_NOOP("ProgrammerManager", "Public"), 0, 75, 0, false },
        { QT_TRANSLATE_NOOP("ProgrammerManager", "Horizon"), 0, 90, 0, false },
        { QT_TRANSLATE_NOOP("ProgrammerManager", "Éventail"), 0, 45, 60, false },
        { QT_TRANSLATE_NOOP("ProgrammerManager", "Éventail +"), 0, 70, 120, false },
        { QT_TRANSLATE_NOOP("ProgrammerManager", "Croisé"), 0, 45, 50, true },
        { QT_TRANSLATE_NOOP("ProgrammerManager", "Arrière"), 0, -45, 0, false },
    };
    i = 0;
    for (const auto &p : positions)
    {
        Memory &m = m_positionMemories[i++];
        m.used = true;
        m.name = tr(p.name);
        m.pan = p.pan; m.tilt = p.tilt; m.fan = p.fan; m.crossed = p.crossed;
    }
}

bool ProgrammerManager::memoryStore(const QString &kind, int index)
{
    QVector<Memory> &list = kind == "color" ? m_colorMemories : m_positionMemories;
    if (index < 0 || index >= list.count())
        return false;
    if (kind == "color" && m_lastColor.isValid() == false)
        return false;
    QString keep = list[index].used ? list[index].name : QString();
    list[index] = Memory();
    memoryPress(kind, index);       // empty slot: stores
    if (keep.isEmpty() == false && kind != "color")
        list[index].name = keep;
    applyPresetToCues(kind, index);
    emit memoriesChanged();
    return true;
}

void ProgrammerManager::memoryRename(const QString &kind, int index, const QString &name)
{
    QVector<Memory> &list = kind == "color" ? m_colorMemories : m_positionMemories;
    if (index < 0 || index >= list.count() || list[index].used == false || name.trimmed().isEmpty())
        return;
    list[index].name = name.trimmed();
    m_doc->setModified();
    emit memoriesChanged();
}

bool ProgrammerManager::loadXML(QXmlStreamReader &root)
{
    if (root.name() != KXMLQLCProgrammer)
        return false;

    m_colorMemories = QVector<Memory>(MemoryCount);
    m_positionMemories = QVector<Memory>(MemoryCount);
    {
        QXmlStreamAttributes pa = root.attributes();
        if (pa.hasAttribute("Bpm"))
        {
            m_tempoMult = 1;
            applyTempo(pa.value("Bpm").toDouble());
        }
        setTempoSource(pa.value("TempoSource").toString());
    }
    while (root.readNextStartElement())
    {
        if (root.name() == QLatin1String("Tempo"))
        {
            QXmlStreamAttributes a = root.attributes();
            m_tempoLinks.insert(a.value("Function").toUInt(), qMax(0.01, a.value("Beats").toDouble()));
        }
        else if (root.name() == QLatin1String("Link"))
        {
            QXmlStreamAttributes a = root.attributes();
            PresetRef link;
            link.sceneId = a.value("Scene").toUInt();
            link.kind = a.value("Kind") == QLatin1String("Color") ? "color" : "position";
            link.index = a.value("Index").toInt();
            const QStringList ids = a.value("Fixtures").toString().split(',', Qt::SkipEmptyParts);
            for (const QString &id : ids)
                link.fixtures.append(id.toUInt());
            if (link.fixtures.isEmpty() == false)
                m_presetLinks.append(link);
        }
        if (root.name() == QLatin1String("Memory"))
        {
            QXmlStreamAttributes a = root.attributes();
            bool colour = a.value("Kind") == QLatin1String("Color");
            int index = a.value("Index").toInt();
            QVector<Memory> &list = colour ? m_colorMemories : m_positionMemories;
            if (index >= 0 && index < list.count())
            {
                Memory &m = list[index];
                m.used = true;
                m.name = a.value("Name").toString();
                if (colour)
                    m.color = QColor(a.value("Color").toString());
                else
                {
                    m.pan = a.value("Pan").toDouble();
                    m.tilt = a.value("Tilt").toDouble();
                    m.fan = a.value("Fan").toDouble();
                    m.crossed = a.value("Crossed") == QLatin1String("1");
                }
            }
        }
        root.skipCurrentElement();
    }
    emit memoriesChanged();
    return true;
}

bool ProgrammerManager::saveXML(QXmlStreamWriter *doc) const
{
    doc->writeStartElement(KXMLQLCProgrammer);
    doc->writeAttribute("TempoSource", m_tempoSource);
    doc->writeAttribute("Bpm", QString::number(m_sourceBpm));
    for (auto it = m_tempoLinks.cbegin(); it != m_tempoLinks.cend(); ++it)
    {
        if (m_doc->function(it.key()) == nullptr)
            continue;
        doc->writeStartElement("Tempo");
        doc->writeAttribute("Function", QString::number(it.key()));
        doc->writeAttribute("Beats", QString::number(it.value()));
        doc->writeEndElement();
    }
    for (const PresetRef &link : m_presetLinks)
    {
        if (m_doc->function(link.sceneId) == nullptr)
            continue;
        QStringList ids;
        for (quint32 id : link.fixtures)
            ids.append(QString::number(id));
        doc->writeStartElement("Link");
        doc->writeAttribute("Scene", QString::number(link.sceneId));
        doc->writeAttribute("Kind", link.kind == "color" ? "Color" : "Position");
        doc->writeAttribute("Index", QString::number(link.index));
        doc->writeAttribute("Fixtures", ids.join(','));
        doc->writeEndElement();
    }
    for (int pass = 0; pass < 2; pass++)
    {
        const QVector<Memory> &list = pass == 0 ? m_colorMemories : m_positionMemories;
        for (int i = 0; i < list.count(); i++)
        {
            const Memory &m = list.at(i);
            if (m.used == false)
                continue;
            doc->writeStartElement("Memory");
            doc->writeAttribute("Kind", pass == 0 ? "Color" : "Position");
            doc->writeAttribute("Index", QString::number(i));
            doc->writeAttribute("Name", m.name);
            if (pass == 0)
                doc->writeAttribute("Color", m.color.name());
            else
            {
                doc->writeAttribute("Pan", QString::number(m.pan));
                doc->writeAttribute("Tilt", QString::number(m.tilt));
                doc->writeAttribute("Fan", QString::number(m.fan));
                doc->writeAttribute("Crossed", m.crossed ? "1" : "0");
            }
            doc->writeEndElement();
        }
    }
    doc->writeEndElement();
    return true;
}

void ProgrammerManager::clearProgrammer()
{
    clearEffects();
    m_contextManager->resetDumpValues();
    m_activeRefs.clear();
    m_pan = m_tilt = m_fan = 0;
    m_crossed = false;
    emit positionChanged();
    emit programmerChanged();
}
