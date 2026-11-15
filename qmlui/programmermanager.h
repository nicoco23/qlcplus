/*
  Q Light Controller Plus
  programmermanager.h

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

#ifndef PROGRAMMERMANAGER_H
#define PROGRAMMERMANAGER_H

#include <QVariantList>
#include <QColor>
#include <QMap>
#include <QTimer>
#include <QStringList>
#include <QSharedPointer>
#include <QVector>

#include "previewcontext.h"
#include "scenevalue.h"

#define KXMLQLCProgrammer QStringLiteral("Programmer")

class QXmlStreamReader;
class QXmlStreamWriter;
class PlaybackManager;
class LinkClock;
class ContextManager;
class Function;
class Doc;

/**
 * MagicQ style programmer: pick a group of fixtures, apply intensity,
 * colour, position, zoom and ready made effects, then record the result
 * as a cue on a playback.
 *
 * Values are held by the ContextManager "dump" values (the QLC+ programmer)
 * and output live. Effects are real functions (relative EFX, RGB matrices)
 * created on the fly and kept when the cue is recorded.
 */
class ProgrammerManager final : public PreviewContext
{
    Q_OBJECT

    Q_PROPERTY(QVariantList groups READ groups NOTIFY groupsChanged)
    Q_PROPERTY(int selectionCount READ selectionCount NOTIFY selectionChanged)
    Q_PROPERTY(QString selectionText READ selectionText NOTIFY selectionChanged)
    Q_PROPERTY(int programmerCount READ programmerCount NOTIFY programmerChanged)
    Q_PROPERTY(QVariantList effects READ effects NOTIFY effectsChanged)
    Q_PROPERTY(qreal effectBpm READ effectBpm WRITE setEffectBpm NOTIFY effectParamsChanged)
    Q_PROPERTY(qreal effectSize READ effectSize WRITE setEffectSize NOTIFY effectParamsChanged)
    Q_PROPERTY(bool effectSpread READ effectSpread WRITE setEffectSpread NOTIFY effectParamsChanged)
    Q_PROPERTY(qreal effectPhase READ effectPhase WRITE setEffectPhase NOTIFY effectParamsChanged)
    Q_PROPERTY(qreal effectRate READ effectRate WRITE setEffectRate NOTIFY effectParamsChanged)
    Q_PROPERTY(int effectCount READ effectCount NOTIFY effectsChanged)
    Q_PROPERTY(QVariantList macros READ macros NOTIFY macrosChanged)
    Q_PROPERTY(QVariantList views READ views NOTIFY viewsChanged)
    Q_PROPERTY(QString undoText READ undoText NOTIFY undoChanged)
    Q_PROPERTY(qreal pan READ pan NOTIFY positionChanged)
    Q_PROPERTY(qreal tilt READ tilt NOTIFY positionChanged)
    Q_PROPERTY(qreal fan READ fan WRITE setFan NOTIFY positionChanged)
    Q_PROPERTY(QString nextCueName READ nextCueName NOTIFY programmerChanged)
    Q_PROPERTY(qreal cueFade READ cueFade WRITE setCueFade NOTIFY cueFadeChanged)
    Q_PROPERTY(QVariantList colorMemories READ colorMemories NOTIFY memoriesChanged)
    Q_PROPERTY(QVariantList positionMemories READ positionMemories NOTIFY memoriesChanged)
    Q_PROPERTY(QString tempoSource READ tempoSource WRITE setTempoSource NOTIFY tempoSourceChanged)
    Q_PROPERTY(qreal tempoMultiplier READ tempoMultiplier WRITE setTempoMultiplier NOTIFY effectParamsChanged)
    Q_PROPERTY(bool linkAvailable READ linkAvailable CONSTANT)
    Q_PROPERTY(int linkPeers READ linkPeers NOTIFY tempoSourceChanged)
    Q_PROPERTY(QVariantList fixtureSheet READ fixtureSheet NOTIFY fixtureSheetChanged)
    Q_PROPERTY(bool sheetActive READ sheetActive WRITE setSheetActive NOTIFY sheetActiveChanged)
    Q_PROPERTY(QStringList commandLog READ commandLog NOTIFY commandLogChanged)
    Q_PROPERTY(QString commandFeedback READ commandFeedback NOTIFY commandLogChanged)
    Q_PROPERTY(bool commandFailed READ commandFailed NOTIFY commandLogChanged)

public:
    ProgrammerManager(QQuickView *view, Doc *doc, ContextManager *ctx,
                      PlaybackManager *playbacks, QObject *parent = nullptr);
    ~ProgrammerManager();

    /* Selection */
    QVariantList groups() const;
    int selectionCount() const;
    QString selectionText() const;

    Q_INVOKABLE void selectGroup(quint32 groupId, bool additive);
    Q_INVOKABLE void selectAll();
    Q_INVOKABLE void clearSelection();
    /** Keep one fixture out of two (odd = 1st, 3rd, ...) of the current selection */
    Q_INVOKABLE void selectOddEven(bool odd);

    /* Attributes, applied to the selected fixtures */
    Q_INVOKABLE void setIntensity(qreal level);
    Q_INVOKABLE void setColor(QColor color);
    Q_INVOKABLE void setStrobe(qreal speed);           // 0 = open
    Q_INVOKABLE void setZoom(qreal amount);            // 0 = narrow, 1 = wide

    /** Position in degrees from the centre (tilt > 0 = towards the front of the fixture) */
    Q_INVOKABLE void setPosition(qreal panDegrees, qreal tiltDegrees);
    Q_INVOKABLE void positionPreset(const QString &name);
    qreal pan() const { return m_pan; }
    qreal tilt() const { return m_tilt; }
    qreal fan() const { return m_fan; }
    void setFan(qreal degrees);

    /* Effects */
    QVariantList effects() const;
    Q_INVOKABLE void toggleEffect(const QString &key);
    Q_INVOKABLE void clearEffects();

    qreal effectBpm() const { return m_bpm; }
    void setEffectBpm(qreal bpm);
    qreal effectSize() const { return m_size; }
    void setEffectSize(qreal size);
    bool effectSpread() const { return m_phase > 0; }
    void setEffectSpread(bool spread);
    /** Phase spread over the fixtures of a movement effect, in degrees (0 = all together,
     *  360 = one full cycle from the first to the last fixture) */
    qreal effectPhase() const { return m_phase; }
    void setEffectPhase(qreal degrees);
    /** Speed of an effect against the show tempo (0.25, 0.5, 1, 2, 4) */
    qreal effectRate() const { return m_rate; }
    void setEffectRate(qreal rate);
    /** Effects running in the programmer (several can run on different fixtures) */
    int effectCount() const { return int(m_effects.count()); }

    /* Programmer */
    int programmerCount() const;
    QString nextCueName() const;

    /**
     * Record the programmer (values + running effects) as a new function.
     * @param toFreeSlot put it on the first free playback of the current page,
     *        otherwise it is armed in the Playbacks window to be placed by hand
     * @return the new function ID, or Function::invalidId() if nothing to record
     */
    Q_INVOKABLE quint32 record(const QString &name, bool toFreeSlot);

    /** Release everything held by the programmer (values and effects) */
    Q_INVOKABLE void clearProgrammer();

    /** Record a cue and add it to a playback picked in the Playbacks window:
     *  the playback becomes a cue stack (GO = next cue) */
    Q_INVOKABLE void recordAppend(const QString &name);

    /** Merge the programmer into the cue of a playback picked in the Playbacks
     *  window (the current step for a cue stack) */
    Q_INVOKABLE void startUpdate();

    /** Open white at full on the selection, centred, to find the fixtures */
    Q_INVOKABLE void locate();

    /** Fade time of the recorded cues, in seconds */
    qreal cueFade() const { return m_cueFade; }
    void setCueFade(qreal seconds);

    /* Memories: user colour and position palettes (saved in the project) */
    static const int MemoryCount = 16;
    QVariantList colorMemories() const;
    QVariantList positionMemories() const;
    /** Recall a memory, or store the current colour / position in an empty one */
    Q_INVOKABLE void memoryPress(const QString &kind, int index);
    Q_INVOKABLE void memoryClear(const QString &kind, int index);
    /** Store the current colour / position in a preset, replacing what it held */
    Q_INVOKABLE bool memoryStore(const QString &kind, int index);
    Q_INVOKABLE void memoryRename(const QString &kind, int index, const QString &name);

    /* Show tempo: every effect made here (in the programmer or in a recorded cue) follows it.
     * Source: "manual" (slider, TAP), "console" (the QLC+ BPM: internal, MIDI clock, audio)
     * or "link" (Ableton Link session: rekordbox, Live...) */
    QString tempoSource() const { return m_tempoSource; }
    void setTempoSource(const QString &source);
    qreal tempoMultiplier() const { return m_tempoMult; }
    void setTempoMultiplier(qreal mult);
    bool linkAvailable() const;
    int linkPeers() const;
    Q_INVOKABLE void tap();

    /* Undo ("Oops"): takes back the last recording type action (store, update, delete,
     * preset change, playback assignment, clear of the programmer) */
    QString undoText() const;
    Q_INVOKABLE bool undo();

    /* Macros: a named list of commands, separated by ";" */
    static const int MacroCount = 16;
    QVariantList macros() const;
    Q_INVOKABLE void macroRun(int index);
    Q_INVOKABLE void macroStore(int index, const QString &name, const QString &commands);
    Q_INVOKABLE void macroClear(int index);

    /* Views: a window and a playback page recalled with one key */
    static const int ViewCount = 6;
    QVariantList views() const;
    Q_INVOKABLE void viewRecall(int index);
    Q_INVOKABLE void viewStore(int index, const QString &name);
    Q_INVOKABLE void viewClear(int index);

    /** Rename a fixture group of the pool */
    Q_INVOKABLE void renameGroup(quint32 groupId, const QString &name);

    /** Number of recorded cues that follow a preset */
    int presetCueCount(const QString &kind, int index) const;

    /* Fixture sheet: one row per fixture with its live output, refreshed while a view shows it */
    QVariantList fixtureSheet() const { return m_sheet; }
    bool sheetActive() const { return m_sheetTimer.isActive(); }
    void setSheetActive(bool active);
    /** Select a fixture from the sheet (additive = keep the current selection) */
    Q_INVOKABLE void selectFixture(quint32 fixtureId, bool additive);

    /* Command line ("Group 1 At 50", "Store Exec 2", "Go 3"...) */
    Q_INVOKABLE QString executeCommand(const QString &command);
    QStringList commandLog() const { return m_commandLog; }
    QString commandFeedback() const { return m_commandFeedback; }
    bool commandFailed() const { return m_commandFailed; }

    void resetContents();
    bool loadXML(QXmlStreamReader &root);
    bool saveXML(QXmlStreamWriter *doc) const;

signals:
    void groupsChanged();
    void selectionChanged();
    void programmerChanged();
    void effectsChanged();
    void effectParamsChanged();
    void positionChanged();
    void recorded(QString name, QString where);
    void cueFadeChanged();
    void memoriesChanged();
    void fixtureSheetChanged();
    void tempoSourceChanged();
    void sheetActiveChanged();
    void commandLogChanged();
    void macrosChanged();
    void viewsChanged();
    void undoChanged();

private slots:
    void slotSelectionChanged();
    void slotSlotPicked(QString mode, bool isFader, int index, quint32 functionId);
    void slotRefreshSheet();
    void slotGridPad(int row, int col, bool shift);
    void updateGridLeds();

private:
    QList<quint32> selectedFixtures() const;
    void applyPosition();
    Function *createEffect(const QString &key, const QList<quint32> &fixtures);
    void removeEffectAt(int index, bool deleteFunction);
    void updateEffectParams();
    /** Effects the size / phase / rate controls act on: those of the selection, or all */
    QList<int> effectsInScope() const;
    void pushUndo(const QString &label);

    struct Memory
    {
        bool used = false;
        QString name;
        QColor color;
        qreal pan = 0, tilt = 0, fan = 0;
        bool crossed = false;
    };
    QVariantList memoryList(const QVector<Memory> &list, bool colour) const;

    bool hasContent() const;
    quint32 buildCue(const QString &cueName);
    void resetAfterRecord();
    void appendToSlot(bool isFader, int index, quint32 slotFid);
    void updateSlot(bool isFader, int index, quint32 slotFid);
    void defaultMemories();
    void applyTempo(qreal sourceBpm);
    QList<SceneValue> positionValues(qreal pan, qreal tilt, qreal fan, bool crossed, const QList<quint32> &ids) const;
    void dropActiveRefs(const QString &kind, const QList<quint32> &fixtures);
    void linkActiveRefs(quint32 sceneId);
    int applyPresetToCues(const QString &kind, int index);
    QString runCommand(const QStringList &tokens, bool &ok);
    void selectIds(const QList<quint32> &ids, bool additive, bool remove);

private:
    ContextManager *m_contextManager;
    PlaybackManager *m_playbacks;

    QList<quint32> m_selectionOrder;    // order of the last selected group
    qreal m_pan, m_tilt, m_fan;
    bool m_crossed;

    struct Effect
    {
        QString key;
        quint32 functionId;
        quint32 groupId;                // fixture group created for an RGB matrix
        QList<quint32> fixtures;
        qreal size;
        qreal phase;
        qreal rate;
    };
    QList<Effect> m_effects;

    qreal m_bpm;
    qreal m_size;
    qreal m_phase;
    qreal m_rate;
    int m_cueCounter;
    qreal m_cueFade;
    QColor m_lastColor;

    quint32 m_pendingCue;           // cue waiting to be added to a picked playback
    QString m_pendingName;

    QVector<Memory> m_colorMemories;
    QVector<Memory> m_positionMemories;

    /* tempo */
    QString m_tempoSource;
    qreal m_sourceBpm;
    qreal m_tempoMult;
    LinkClock *m_link;
    QList<qint64> m_taps;
    QMap<quint32, qreal> m_tempoLinks;      // effect function -> beats per step: follows the show tempo

    /* presets recalled in the programmer, and the cues recorded from them */
    struct PresetRef
    {
        quint32 sceneId;
        QString kind;                       // "color" or "position"
        int index;
        QList<quint32> fixtures;            // in selection order (fan)
    };
    QList<PresetRef> m_activeRefs;          // sceneId unused
    QList<PresetRef> m_presetLinks;

    QTimer m_sheetTimer;
    QVariantList m_sheet;

    struct Macro { QString name; QString commands; };
    QVector<Macro> m_macros;
    int m_macroDepth = 0;
    struct View { bool used = false; QString name; QString context; int page = 0; };
    QVector<View> m_views;

    struct Snapshot;
    QList<QSharedPointer<Snapshot>> m_undo;
    bool m_undoGuard = false;
    int m_undoHold = 0;

    QStringList m_commandLog;
    QString m_commandFeedback;
    bool m_commandFailed = false;
};

#endif // PROGRAMMERMANAGER_H
