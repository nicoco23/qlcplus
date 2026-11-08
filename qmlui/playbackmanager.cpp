/*
  Q Light Controller Plus
  playbackmanager.cpp

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

#include <QXmlStreamReader>
#include <QXmlStreamWriter>
#include <QQmlContext>
#include <QDebug>
#include <algorithm>

#include "playbackmanager.h"
#include "inputoutputmap.h"
#include "functionparent.h"
#include "chaseraction.h"
#include "outputpatch.h"
#include "inputpatch.h"
#include "function.h"
#include "chaser.h"
#include "doc.h"

#define KXMLQLCPlaybacksPage      QStringLiteral("Page")
#define KXMLQLCPlaybacksFader     QStringLiteral("Fader")
#define KXMLQLCPlaybacksExec      QStringLiteral("Exec")
#define KXMLQLCPlaybacksIndex     QStringLiteral("Index")
#define KXMLQLCPlaybacksFunction  QStringLiteral("Function")
#define KXMLQLCPlaybacksName      QStringLiteral("Name")
#define KXMLQLCPlaybacksLabel     QStringLiteral("Label")
#define KXMLQLCPlaybacksColor     QStringLiteral("Color")
#define KXMLQLCPlaybacksMode      QStringLiteral("Mode")
#define KXMLQLCPlaybacksFlash     QStringLiteral("Flash")

/** Parent IDs used to start functions from this surface. They sit far
 *  above Virtual Console widget IDs so they never collide with them. */
#define PLAYBACK_PARENT_BASE      0x7FFF0000

/** Refresh rate of the on-screen state and of the controller LEDs */
#define REFRESH_INTERVAL_MS       50

/*********************************************************************
 * Akai APC mini (first generation) MIDI map, as seen by QLC+
 * (CC n -> channel n, Note n -> channel 128 + n)
 *********************************************************************/
#define APC_FADER_FIRST           48     // CC 48..55: track faders
#define APC_FADER_MASTER          56     // CC 56: master fader
#define APC_NOTE_OFFSET           128
#define APC_GRID_FIRST            0      // notes 0..63, 0 = bottom left
#define APC_TRACK_FIRST           64     // notes 64..71, under the grid (red LED)
#define APC_SCENE_FIRST           82     // notes 82..89, right column, top to bottom (green LED)
#define APC_SHIFT                 98

/* LED values are DMX values: the MIDI plugin halves them into velocities */
#define LED_OFF                   0
#define LED_GREEN                 2
#define LED_GREEN_BLINK           4
#define LED_RED                   6
#define LED_RED_BLINK             8
#define LED_YELLOW                10
#define LED_YELLOW_BLINK          12
#define LED_ON                    2      // single color buttons
#define LED_BLINK                 4

PlaybackManager::PlaybackManager(QQuickView *view, Doc *doc, QObject *parent)
    : PreviewContext(view, doc, "PLAYBACKS", parent)
    , m_page(0)
    , m_faders(PageCount * FaderCount)
    , m_execs(PageCount * ExecCount)
    , m_pageNames(PageCount)
    , m_armedFunction(Function::invalidId())
    , m_grandMasterCache(-1)
    , m_refreshTicks(0)
    , m_controllerUniverse(0xFFFFFFFF)
    , m_controllerFeedback(false)
    , m_shift(false)
    , m_autoPatchDone(false)
{
    setContextResource("qrc:/Playbacks.qml");
    setContextTitle(tr("Playbacks"));

    view->rootContext()->setContextProperty("playbackManager", this);

    connect(m_doc, &Doc::functionRemoved, this, &PlaybackManager::slotFunctionRemoved);
    connect(m_doc, &Doc::functionAdded, this, &PlaybackManager::slotFunctionsChanged);
    connect(m_doc, &Doc::functionNameChanged, this, &PlaybackManager::slotFunctionsChanged);
    connect(m_doc, &Doc::loaded, this, &PlaybackManager::slotFunctionsChanged);
    connect(m_doc->inputOutputMap(), &InputOutputMap::inputValueChanged,
            this, &PlaybackManager::slotInputValueChanged);
    connect(m_doc->inputOutputMap(), &InputOutputMap::profileChanged,
            this, [this]() { detectController(); });

    m_refreshTimer.setInterval(REFRESH_INTERVAL_MS);
    connect(&m_refreshTimer, &QTimer::timeout, this, &PlaybackManager::slotRefresh);
    m_refreshTimer.start();

    slotFunctionsChanged();
}

PlaybackManager::~PlaybackManager()
{
}

/*********************************************************************
 * Pages
 *********************************************************************/

int PlaybackManager::page() const
{
    return m_page;
}

void PlaybackManager::setPage(int page)
{
    page = std::clamp(page, 0, PageCount - 1);
    if (page == m_page)
        return;

    m_page = page;

    // The physical faders do not move: a playback only follows its fader
    // again once the fader crosses the playback's current level
    for (int i = 0; i < FaderCount; i++)
        fader(m_page, i).needsPickup = (m_controllerUniverse != 0xFFFFFFFF);

    emit pageChanged();
    slotRefresh();
}

/*********************************************************************
 * State access
 *********************************************************************/

PlaybackManager::FaderState &PlaybackManager::fader(int page, int index)
{
    return m_faders[page * FaderCount + index];
}

PlaybackManager::ExecState &PlaybackManager::exec(int page, int index)
{
    return m_execs[page * ExecCount + index];
}

Function *PlaybackManager::functionAt(quint32 id) const
{
    if (id == Function::invalidId())
        return nullptr;
    return m_doc->function(id);
}

int PlaybackManager::parentId(bool isFader, int page, int index) const
{
    int slot = isFader ? page * FaderCount + index
                       : PageCount * FaderCount + page * ExecCount + index;
    return PLAYBACK_PARENT_BASE + slot;
}

QVariantMap PlaybackManager::describe(quint32 functionId, bool running) const
{
    QVariantMap map;
    Function *f = functionAt(functionId);
    map.insert("funcID", f ? f->id() : Function::invalidId());
    map.insert("label", f ? f->name() : QString());
    map.insert("type", f ? Function::typeToString(f->type()) : QString());
    map.insert("running", f ? running : false);

    QString step;
    Chaser *chaser = qobject_cast<Chaser *>(f);
    if (chaser && chaser->isRunning() && chaser->stepsCount() > 0)
        step = QString("%1/%2").arg(chaser->currentStepIndex() + 1).arg(chaser->stepsCount());
    map.insert("step", step);
    return map;
}

QVariantList PlaybackManager::faders() const
{
    return m_fadersCache;
}

QVariantList PlaybackManager::execs() const
{
    return m_execsCache;
}

QVariantList PlaybackManager::pages() const
{
    return m_pagesCache;
}

/*********************************************************************
 * Grand Master
 *********************************************************************/

qreal PlaybackManager::grandMaster() const
{
    return qreal(m_doc->inputOutputMap()->grandMasterValue()) / 255.0;
}

void PlaybackManager::setGrandMaster(qreal level)
{
    uchar value = uchar(std::clamp(level, 0.0, 1.0) * 255.0 + 0.5);
    if (value == m_doc->inputOutputMap()->grandMasterValue())
        return;
    m_doc->inputOutputMap()->setGrandMasterValue(value);
    emit grandMasterChanged();
}

/*********************************************************************
 * Function list (assignment panel)
 *********************************************************************/

QVariantList PlaybackManager::functionsList() const
{
    return m_functionsCache;
}

void PlaybackManager::slotFunctionsChanged()
{
    QList<Function *> list = m_doc->functions();
    std::sort(list.begin(), list.end(), [](Function *a, Function *b)
    {
        if (a->type() != b->type())
            return a->type() < b->type();
        return a->name().localeAwareCompare(b->name()) < 0;
    });

    m_functionsCache.clear();
    for (Function *f : list)
    {
        if (f->isVisible() == false)
            continue;
        QVariantMap map;
        map.insert("funcID", f->id());
        map.insert("label", f->name());
        map.insert("type", Function::typeToString(f->type()));
        m_functionsCache.append(map);
    }
    emit functionsListChanged();
    slotRefresh();
}

quint32 PlaybackManager::armedFunction() const
{
    return m_armedFunction;
}

void PlaybackManager::setArmedFunction(quint32 id)
{
    if (id == m_armedFunction)
        return;
    m_armedFunction = id;
    emit armedFunctionChanged();
}

void PlaybackManager::slotFunctionRemoved(quint32 id)
{
    for (FaderState &f : m_faders)
    {
        if (f.functionId == id)
            f = FaderState();
    }
    for (ExecState &e : m_execs)
    {
        if (e.functionId == id)
            e = ExecState();
    }
    if (m_armedFunction == id)
        setArmedFunction(Function::invalidId());
    slotFunctionsChanged();
}

/*********************************************************************
 * Running functions
 *********************************************************************/

void PlaybackManager::startFunction(Function *f, int parent, qreal intensity)
{
    if (f == nullptr)
        return;

    // A Chaser has to be started with an action, so that its first step
    // gets the right intensity (same as a Virtual Console button)
    if (f->type() == Function::ChaserType || f->type() == Function::SequenceType)
    {
        ChaserAction action;
        action.m_action = ChaserSetStepIndex;
        action.m_stepIndex = 0;
        action.m_masterIntensity = intensity;
        action.m_stepIntensity = 1.0;
        action.m_fadeMode = Chaser::FromFunction;
        qobject_cast<Chaser *>(f)->setAction(action);
    }

    f->start(m_doc->masterTimer(), FunctionParent(FunctionParent::ManualVCWidget, quint32(parent)));
}

void PlaybackManager::stopFunction(Function *f, int parent)
{
    if (f == nullptr || f->stopped())
        return;
    f->stop(FunctionParent(FunctionParent::ManualVCWidget, quint32(parent)));
}

void PlaybackManager::applyFaderLevel(int page, int index)
{
    FaderState &st = fader(page, index);
    Function *f = functionAt(st.functionId);
    if (f == nullptr)
        return;

    int parent = parentId(true, page, index);

    if (st.level <= 0.0)
    {
        if (st.flashing == false)
        {
            if (st.owned)
                stopFunction(f, parent);
            st.attributeId = -1;
            st.owned = false;
        }
        return;
    }

    if (st.attributeId == Function::invalidAttributeId() || f->stopped())
        st.attributeId = f->requestAttributeOverride(Function::Intensity, st.level);
    else
        f->adjustAttribute(st.level, st.attributeId);

    if (f->stopped())
    {
        startFunction(f, parent, st.level);
        st.owned = true;
    }
}

void PlaybackManager::setFaderLevel(int index, qreal level)
{
    if (index < 0 || index >= FaderCount)
        return;

    FaderState &st = fader(m_page, index);
    st.level = std::clamp(level, 0.0, 1.0);
    st.needsPickup = false;
    applyFaderLevel(m_page, index);
    slotRefresh();
}

void PlaybackManager::go(int index)
{
    if (index < 0 || index >= FaderCount)
        return;

    FaderState &st = fader(m_page, index);
    Function *f = functionAt(st.functionId);
    if (f == nullptr)
        return;

    Chaser *chaser = qobject_cast<Chaser *>(f);
    if (f->isRunning())
    {
        if (chaser)
        {
            ChaserAction action;
            action.m_action = ChaserNextStep;
            action.m_stepIndex = -1;
            action.m_masterIntensity = st.level > 0 ? st.level : 1.0;
            action.m_stepIntensity = 1.0;
            action.m_fadeMode = Chaser::FromFunction;
            chaser->setAction(action);
        }
        return;
    }

    // GO with the fader down plays the playback at full
    qreal level = st.level > 0 ? st.level : 1.0;
    st.attributeId = f->requestAttributeOverride(Function::Intensity, level);
    startFunction(f, parentId(true, m_page, index), level);
    st.owned = true;
    slotRefresh();
}

void PlaybackManager::back(int index)
{
    if (index < 0 || index >= FaderCount)
        return;

    Chaser *chaser = qobject_cast<Chaser *>(functionAt(fader(m_page, index).functionId));
    if (chaser == nullptr || chaser->isRunning() == false)
        return;

    ChaserAction action;
    action.m_action = ChaserPreviousStep;
    action.m_stepIndex = -1;
    action.m_masterIntensity = fader(m_page, index).level > 0 ? fader(m_page, index).level : 1.0;
    action.m_stepIntensity = 1.0;
    action.m_fadeMode = Chaser::FromFunction;
    chaser->setAction(action);
}

void PlaybackManager::flash(int index, bool pressed)
{
    if (index < 0 || index >= FaderCount)
        return;

    FaderState &st = fader(m_page, index);
    Function *f = functionAt(st.functionId);
    if (f == nullptr)
        return;

    int parent = parentId(true, m_page, index);
    st.flashing = pressed;

    if (f->type() == Function::SceneType)
    {
        if (pressed)
            f->flash(m_doc->masterTimer(), true, false);
        else
            f->unFlash(m_doc->masterTimer());
    }
    else if (pressed)
    {
        if (f->stopped())
        {
            st.flashStarted = true;
            st.owned = true;
            st.attributeId = f->requestAttributeOverride(Function::Intensity, 1.0);
            startFunction(f, parent, 1.0);
        }
        else if (st.attributeId != Function::invalidAttributeId())
        {
            f->adjustAttribute(1.0, st.attributeId);
        }
    }
    else
    {
        if (st.flashStarted)
        {
            stopFunction(f, parent);
            st.attributeId = -1;
            st.owned = false;
        }
        else if (st.attributeId != Function::invalidAttributeId())
        {
            f->adjustAttribute(st.level, st.attributeId);
        }
        st.flashStarted = false;
    }
    slotRefresh();
}

void PlaybackManager::release(int index)
{
    if (index < 0 || index >= FaderCount)
        return;

    FaderState &st = fader(m_page, index);
    stopFunction(functionAt(st.functionId), parentId(true, m_page, index));
    st.attributeId = -1;
    st.owned = false;
    slotRefresh();
}

void PlaybackManager::assignFader(int index, quint32 functionId)
{
    if (index < 0 || index >= FaderCount)
        return;

    FaderState &st = fader(m_page, index);
    if (st.functionId != functionId)
        stopFunction(functionAt(st.functionId), parentId(true, m_page, index));

    st = FaderState();
    st.functionId = functionAt(functionId) ? functionId : Function::invalidId();
    m_doc->setModified();
    slotRefresh();
}

void PlaybackManager::execPress(int index, bool pressed)
{
    if (index < 0 || index >= ExecCount)
        return;

    ExecState &st = exec(m_page, index);
    Function *f = functionAt(st.functionId);
    if (f == nullptr)
        return;

    int parent = parentId(false, m_page, index);

    if (st.flashMode)
    {
        // momentary: on while held, back to the previous state when released
        if (pressed && f->stopped())
        {
            st.flashStarted = true;
            f->requestAttributeOverride(Function::Intensity, 1.0);
            startFunction(f, parent, 1.0);
        }
        else if (!pressed && st.flashStarted)
        {
            stopFunction(f, parent);
            st.flashStarted = false;
        }
        slotRefresh();
        return;
    }

    if (pressed == false)
        return;

    if (f->isRunning())
    {
        stopFunction(f, parent);
    }
    else
    {
        f->requestAttributeOverride(Function::Intensity, 1.0);
        startFunction(f, parent, 1.0);
    }
    slotRefresh();
}

void PlaybackManager::assignExec(int index, quint32 functionId)
{
    if (index < 0 || index >= ExecCount)
        return;

    ExecState &st = exec(m_page, index);
    if (st.functionId != functionId)
        stopFunction(functionAt(st.functionId), parentId(false, m_page, index));

    st = ExecState();
    st.functionId = functionAt(functionId) ? functionId : Function::invalidId();
    m_doc->setModified();
    slotRefresh();
}

void PlaybackManager::setExecFlashMode(int index, bool flash)
{
    if (index < 0 || index >= ExecCount)
        return;
    ExecState &st = exec(m_page, index);
    if (st.flashMode == flash)
        return;
    st.flashMode = flash;
    st.flashStarted = false;
    m_doc->setModified();
    slotRefresh();
}

void PlaybackManager::setFaderLabel(int index, const QString &label)
{
    if (index < 0 || index >= FaderCount)
        return;
    fader(m_page, index).label = label.trimmed();
    m_doc->setModified();
    slotRefresh();
}

void PlaybackManager::setFaderColor(int index, const QString &color)
{
    if (index < 0 || index >= FaderCount)
        return;
    fader(m_page, index).color = color;
    m_doc->setModified();
    slotRefresh();
}

void PlaybackManager::setExecLabel(int index, const QString &label)
{
    if (index < 0 || index >= ExecCount)
        return;
    exec(m_page, index).label = label.trimmed();
    m_doc->setModified();
    slotRefresh();
}

void PlaybackManager::setExecColor(int index, const QString &color)
{
    if (index < 0 || index >= ExecCount)
        return;
    exec(m_page, index).color = color;
    m_doc->setModified();
    slotRefresh();
}

void PlaybackManager::moveFader(int from, int to)
{
    if (from < 0 || from >= FaderCount || to < 0 || to >= FaderCount || from == to)
        return;
    // a running playback keeps running: only its slot (and parent id) changes
    FaderState &a = fader(m_page, from);
    FaderState &b = fader(m_page, to);
    Function *fa = functionAt(a.functionId), *fb = functionAt(b.functionId);
    if (fa && a.owned) stopFunction(fa, parentId(true, m_page, from));
    if (fb && b.owned) stopFunction(fb, parentId(true, m_page, to));
    std::swap(a, b);
    a.owned = b.owned = false;
    a.attributeId = b.attributeId = -1;
    a.level = b.level = 0;
    m_doc->setModified();
    slotRefresh();
}

void PlaybackManager::moveExec(int from, int to)
{
    if (from < 0 || from >= ExecCount || to < 0 || to >= ExecCount || from == to)
        return;
    std::swap(exec(m_page, from), exec(m_page, to));
    exec(m_page, from).flashStarted = false;
    exec(m_page, to).flashStarted = false;
    m_doc->setModified();
    slotRefresh();
}

bool PlaybackManager::assignToFree(quint32 functionId)
{
    if (functionAt(functionId) == nullptr)
        return false;
    for (int i = 0; i < FaderCount; i++)
    {
        if (functionAt(fader(m_page, i).functionId) == nullptr)
        {
            assignFader(i, functionId);
            return true;
        }
    }
    for (int i = 0; i < ExecCount; i++)
    {
        if (functionAt(exec(m_page, i).functionId) == nullptr)
        {
            assignExec(i, functionId);
            return true;
        }
    }
    return false;
}

void PlaybackManager::setPageName(int page, const QString &name)
{
    if (page < 0 || page >= PageCount)
        return;
    m_pageNames[page] = name.trimmed();
    m_doc->setModified();
    slotRefresh();
}

void PlaybackManager::releaseAll()
{
    for (int p = 0; p < PageCount; p++)
    {
        for (int i = 0; i < FaderCount; i++)
        {
            FaderState &st = fader(p, i);
            stopFunction(functionAt(st.functionId), parentId(true, p, i));
            st.attributeId = -1;
            st.level = 0;
            st.owned = false;
        }
        for (int i = 0; i < ExecCount; i++)
            stopFunction(functionAt(exec(p, i).functionId), parentId(false, p, i));
    }
    slotRefresh();
}

/*********************************************************************
 * Periodic refresh (UI + controller LEDs)
 *********************************************************************/

void PlaybackManager::slotRefresh()
{
    QVariantList faders;
    for (int i = 0; i < FaderCount; i++)
    {
        const FaderState &st = fader(m_page, i);
        Function *f = functionAt(st.functionId);
        QVariantMap map = describe(st.functionId, f && f->isRunning() && st.owned);
        map.insert("name", map.value("label"));
        if (f && !st.label.isEmpty())
            map.insert("label", st.label);
        map.insert("color", f ? st.color : QString());
        map.insert("level", st.level);
        map.insert("pickup", st.needsPickup);
        map.insert("flashing", st.flashing);
        faders.append(map);
    }
    if (faders != m_fadersCache)
    {
        m_fadersCache = faders;
        emit fadersChanged();
    }

    QVariantList execs;
    for (int i = 0; i < ExecCount; i++)
    {
        const ExecState &st = exec(m_page, i);
        Function *f = functionAt(st.functionId);
        QVariantMap map = describe(st.functionId, f && f->isRunning());
        map.insert("name", map.value("label"));
        if (f && !st.label.isEmpty())
            map.insert("label", st.label);
        map.insert("color", f ? st.color : QString());
        map.insert("flashMode", st.flashMode);
        execs.append(map);
    }
    if (execs != m_execsCache)
    {
        m_execsCache = execs;
        emit execsChanged();
    }

    QVariantList pages;
    for (int p = 0; p < PageCount; p++)
    {
        bool used = false, running = false;
        for (int i = 0; i < FaderCount; i++)
        {
            Function *f = functionAt(fader(p, i).functionId);
            used |= f != nullptr;
            running |= f && f->isRunning();
        }
        for (int i = 0; i < ExecCount; i++)
        {
            Function *f = functionAt(exec(p, i).functionId);
            used |= f != nullptr;
            running |= f && f->isRunning();
        }
        QVariantMap map;
        map.insert("used", used);
        map.insert("running", running);
        map.insert("name", m_pageNames.at(p));
        pages.append(map);
    }
    if (pages != m_pagesCache)
    {
        m_pagesCache = pages;
        emit pagesChanged();
    }

    qreal gm = grandMaster();
    if (gm != m_grandMasterCache)
    {
        m_grandMasterCache = gm;
        emit grandMasterChanged();
    }

    // Look for the controller (plugged in later, profile changed...) every 2 seconds
    if (m_refreshTicks++ % (2000 / REFRESH_INTERVAL_MS) == 0)
        detectController();

    updateControllerLeds(false);
}

/*********************************************************************
 * Akai APC mini
 *********************************************************************/

QString PlaybackManager::controllerName() const
{
    return m_controllerName;
}

bool PlaybackManager::controllerFeedback() const
{
    return m_controllerFeedback;
}

void PlaybackManager::detectController()
{
    InputOutputMap *ioMap = m_doc->inputOutputMap();
    quint32 found = 0xFFFFFFFF;
    QString name;

    for (quint32 u = 0; u < ioMap->universesCount(); u++)
    {
        InputPatch *ip = ioMap->inputPatch(u);
        if (ip == nullptr || ip->isPatched() == false)
            continue;

        QString profile = ip->profileName();
        QString input = ip->inputName();
        bool apcProfile = profile.contains("APC Mini", Qt::CaseInsensitive)
                          && profile.contains("mk2", Qt::CaseInsensitive) == false;
        bool apcDevice = input.contains("APC MINI", Qt::CaseInsensitive)
                         && input.contains("mk2", Qt::CaseInsensitive) == false;
        if (apcProfile || apcDevice)
        {
            found = u;
            name = QString("APC mini · U%1").arg(u + 1);
            break;
        }
    }

    // Plug and play: patch the APC mini input ourselves, once, if nobody did
    if (found == 0xFFFFFFFF && m_autoPatchDone == false && autoPatchController())
        return detectController();

    bool changed = found != m_controllerUniverse;
    m_controllerUniverse = found;
    m_controllerName = name;

    if (found != 0xFFFFFFFF)
        ensureFeedbackPatch();

    bool feedback = found != 0xFFFFFFFF && ioMap->feedbackPatch(found) != nullptr
                    && ioMap->feedbackPatch(found)->isPatched();
    if (feedback != m_controllerFeedback)
    {
        m_controllerFeedback = feedback;
        changed = true;
    }

    if (changed)
    {
        emit controllerChanged();
        updateControllerLeds(true);
    }
}

bool PlaybackManager::autoPatchController()
{
    InputOutputMap *ioMap = m_doc->inputOutputMap();
    const QString plugin("MIDI");
    QStringList inputs = ioMap->pluginInputs(plugin);

    int line = -1;
    for (int i = 0; i < inputs.count(); i++)
    {
        if (inputs.at(i).contains("APC MINI", Qt::CaseInsensitive)
            && inputs.at(i).contains("mk2", Qt::CaseInsensitive) == false)
        {
            line = i;
            break;
        }
    }
    if (line < 0)
        return false;   // not plugged in (yet): try again later

    m_autoPatchDone = true;

    // Use the last universe without an input: inputs never touch DMX output
    for (int u = int(ioMap->universesCount()) - 1; u >= 0; u--)
    {
        InputPatch *ip = ioMap->inputPatch(quint32(u));
        if (ip != nullptr && ip->isPatched())
            continue;

        bool ok = ioMap->setInputPatch(quint32(u), plugin, inputs.at(line), inputs.at(line),
                                       quint32(line), QString("Akai APC Mini"));
        qDebug() << "[Playbacks] APC mini input patched on universe" << u + 1 << ok;
        if (ok)
            m_doc->setModified();
        return ok;
    }
    return false;
}

void PlaybackManager::ensureFeedbackPatch()
{
    InputOutputMap *ioMap = m_doc->inputOutputMap();
    OutputPatch *fb = ioMap->feedbackPatch(m_controllerUniverse);
    if (fb != nullptr && fb->isPatched())
        return;

    // The APC mini LEDs are driven by the MIDI output of the same device:
    // patch it as feedback so that the pads light up without any setup
    InputPatch *ip = ioMap->inputPatch(m_controllerUniverse);
    QStringList outputs = ioMap->pluginOutputs(ip->pluginName());
    for (int i = 0; i < outputs.count(); i++)
    {
        if (outputs.at(i).compare(ip->inputName(), Qt::CaseInsensitive) == 0
            || outputs.at(i).contains("APC MINI", Qt::CaseInsensitive))
        {
            ioMap->setOutputPatch(m_controllerUniverse, ip->pluginName(), outputs.at(i), outputs.at(i),
                                  quint32(i), true);
            qDebug() << "[Playbacks] APC mini feedback patched on" << outputs.at(i);
            return;
        }
    }
}

void PlaybackManager::sendLed(quint32 note, uchar value, bool force)
{
    if (force == false && m_ledCache.value(note, 0xFF) == value)
        return;
    m_ledCache[note] = value;
    m_doc->inputOutputMap()->sendFeedBack(m_controllerUniverse, APC_NOTE_OFFSET + note, value, QVariant());
}

void PlaybackManager::updateControllerLeds(bool force)
{
    if (m_controllerUniverse == 0xFFFFFFFF)
        return;
    if (force)
        m_ledCache.clear();

    // Execute grid: pad rows 2..8 (top pad row = first execute row)
    for (int i = 0; i < ExecCount; i++)
    {
        int row = i / ExecColumns, col = i % ExecColumns;
        quint32 note = APC_GRID_FIRST + (ExecRows - row) * 8 + col;
        Function *f = functionAt(exec(m_page, i).functionId);
        uchar led = f == nullptr ? LED_OFF : (f->isRunning() ? LED_GREEN : LED_YELLOW);
        sendLed(note, led, force);
    }

    for (int i = 0; i < FaderCount; i++)
    {
        const FaderState &st = fader(m_page, i);
        Function *f = functionAt(st.functionId);
        bool running = f && f->isRunning() && st.owned;

        // Bottom pad row: FLASH
        uchar flashLed = f == nullptr ? LED_OFF : (st.flashing ? LED_YELLOW : (running ? LED_RED_BLINK : LED_RED));
        sendLed(APC_GRID_FIRST + i, flashLed, force);

        // Buttons under the grid: GO (lit while the playback runs)
        sendLed(APC_TRACK_FIRST + i, running ? LED_ON : LED_OFF, force);
    }

    // Right column: pages (current page lit, pages with something running blink)
    for (int p = 0; p < PageCount; p++)
    {
        bool running = p < m_pagesCache.count() && m_pagesCache.at(p).toMap().value("running").toBool();
        uchar led = p == m_page ? LED_ON : (running ? LED_BLINK : LED_OFF);
        sendLed(APC_SCENE_FIRST + p, led, force);
    }
}

void PlaybackManager::slotInputValueChanged(quint32 universe, quint32 channel, uchar value, const QString &key)
{
    Q_UNUSED(key)

    if (universe != m_controllerUniverse || m_controllerUniverse == 0xFFFFFFFF)
        return;

    qreal level = qreal(value) / 255.0;

    if (channel >= APC_FADER_FIRST && channel < APC_FADER_FIRST + FaderCount)
    {
        int index = int(channel - APC_FADER_FIRST);
        FaderState &st = fader(m_page, index);
        if (st.needsPickup)
        {
            // soft takeover: wait for the fader to reach the playback level
            if (qAbs(level - st.level) > 0.04)
            {
                slotRefresh();
                return;
            }
            st.needsPickup = false;
        }
        setFaderLevel(index, level);
        return;
    }

    if (channel == APC_FADER_MASTER)
    {
        setGrandMaster(level);
        return;
    }

    if (channel < APC_NOTE_OFFSET)
        return;

    quint32 note = channel - APC_NOTE_OFFSET;
    bool pressed = value > 0;

    if (note == APC_SHIFT)
    {
        m_shift = pressed;
        return;
    }

    if (note < APC_GRID_FIRST + 64)
    {
        int row = int(note) / 8, col = int(note) % 8;
        if (row == 0)
            flash(col, pressed);
        else
            execPress((ExecRows - row) * ExecColumns + col, pressed);
        return;
    }

    if (note >= APC_TRACK_FIRST && note < APC_TRACK_FIRST + FaderCount)
    {
        if (pressed == false)
            return;
        int index = int(note - APC_TRACK_FIRST);
        if (m_shift)
            release(index);   // SHIFT + GO = release
        else
            go(index);
        return;
    }

    if (note >= APC_SCENE_FIRST && note < APC_SCENE_FIRST + PageCount)
    {
        if (pressed)
        {
            if (m_shift && note == APC_SCENE_FIRST + PageCount - 1)
                releaseAll();  // SHIFT + last scene button = release all
            else
                setPage(int(note - APC_SCENE_FIRST));
        }
        return;
    }
}

/*********************************************************************
 * Load & Save
 *********************************************************************/

void PlaybackManager::resetContents()
{
    m_faders = QVector<FaderState>(PageCount * FaderCount);
    m_execs = QVector<ExecState>(PageCount * ExecCount);
    m_pageNames = QStringList();
    for (int p = 0; p < PageCount; p++)
        m_pageNames.append(QString());
    m_page = 0;
    m_armedFunction = Function::invalidId();
    m_autoPatchDone = false;
    emit pageChanged();
    emit armedFunctionChanged();
    slotFunctionsChanged();
}

bool PlaybackManager::loadXML(QXmlStreamReader &root)
{
    if (root.name() != KXMLQLCPlaybacks)
    {
        qWarning() << Q_FUNC_INFO << "Playbacks node not found";
        return false;
    }

    resetContents();

    while (root.readNextStartElement())
    {
        if (root.name() != KXMLQLCPlaybacksPage)
        {
            root.skipCurrentElement();
            continue;
        }

        int page = root.attributes().value(KXMLQLCPlaybacksIndex).toInt();
        if (page >= 0 && page < PageCount)
            m_pageNames[page] = root.attributes().value(KXMLQLCPlaybacksName).toString();
        while (root.readNextStartElement())
        {
            QXmlStreamAttributes attrs = root.attributes();
            int index = attrs.value(KXMLQLCPlaybacksIndex).toInt();
            quint32 fid = attrs.value(KXMLQLCPlaybacksFunction).toUInt();

            if (page >= 0 && page < PageCount)
            {
                QString label = attrs.value(KXMLQLCPlaybacksLabel).toString();
                QString color = attrs.value(KXMLQLCPlaybacksColor).toString();
                if (root.name() == KXMLQLCPlaybacksFader && index >= 0 && index < FaderCount)
                {
                    FaderState &st = fader(page, index);
                    st.functionId = fid;
                    st.label = label;
                    st.color = color;
                }
                else if (root.name() == KXMLQLCPlaybacksExec && index >= 0 && index < ExecCount)
                {
                    ExecState &st = exec(page, index);
                    st.functionId = fid;
                    st.label = label;
                    st.color = color;
                    st.flashMode = attrs.value(KXMLQLCPlaybacksMode) == KXMLQLCPlaybacksFlash;
                }
            }
            root.skipCurrentElement();
        }
    }

    slotRefresh();
    return true;
}

bool PlaybackManager::saveXML(QXmlStreamWriter *doc) const
{
    doc->writeStartElement(KXMLQLCPlaybacks);

    for (int p = 0; p < PageCount; p++)
    {
        bool pageOpen = false;
        auto openPage = [&]()
        {
            if (pageOpen)
                return;
            doc->writeStartElement(KXMLQLCPlaybacksPage);
            doc->writeAttribute(KXMLQLCPlaybacksIndex, QString::number(p));
            if (!m_pageNames.at(p).isEmpty())
                doc->writeAttribute(KXMLQLCPlaybacksName, m_pageNames.at(p));
            pageOpen = true;
        };
        if (!m_pageNames.at(p).isEmpty())
            openPage();

        for (int i = 0; i < FaderCount; i++)
        {
            const FaderState &st = m_faders.at(p * FaderCount + i);
            quint32 fid = st.functionId;
            if (functionAt(fid) == nullptr)
                continue;
            openPage();
            doc->writeStartElement(KXMLQLCPlaybacksFader);
            doc->writeAttribute(KXMLQLCPlaybacksIndex, QString::number(i));
            doc->writeAttribute(KXMLQLCPlaybacksFunction, QString::number(fid));
            if (!st.label.isEmpty())
                doc->writeAttribute(KXMLQLCPlaybacksLabel, st.label);
            if (!st.color.isEmpty())
                doc->writeAttribute(KXMLQLCPlaybacksColor, st.color);
            doc->writeEndElement();
        }
        for (int i = 0; i < ExecCount; i++)
        {
            const ExecState &st = m_execs.at(p * ExecCount + i);
            quint32 fid = st.functionId;
            if (functionAt(fid) == nullptr)
                continue;
            openPage();
            doc->writeStartElement(KXMLQLCPlaybacksExec);
            doc->writeAttribute(KXMLQLCPlaybacksIndex, QString::number(i));
            doc->writeAttribute(KXMLQLCPlaybacksFunction, QString::number(fid));
            if (!st.label.isEmpty())
                doc->writeAttribute(KXMLQLCPlaybacksLabel, st.label);
            if (!st.color.isEmpty())
                doc->writeAttribute(KXMLQLCPlaybacksColor, st.color);
            if (st.flashMode)
                doc->writeAttribute(KXMLQLCPlaybacksMode, KXMLQLCPlaybacksFlash);
            doc->writeEndElement();
        }

        if (pageOpen)
            doc->writeEndElement();
    }

    doc->writeEndElement();
    return true;
}
