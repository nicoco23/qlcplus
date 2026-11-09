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

#include "previewcontext.h"

#define KXMLQLCProgrammer QStringLiteral("Programmer")

class QXmlStreamReader;
class QXmlStreamWriter;
class PlaybackManager;
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
    Q_PROPERTY(qreal pan READ pan NOTIFY positionChanged)
    Q_PROPERTY(qreal tilt READ tilt NOTIFY positionChanged)
    Q_PROPERTY(qreal fan READ fan WRITE setFan NOTIFY positionChanged)
    Q_PROPERTY(QString nextCueName READ nextCueName NOTIFY programmerChanged)
    Q_PROPERTY(qreal cueFade READ cueFade WRITE setCueFade NOTIFY cueFadeChanged)
    Q_PROPERTY(QVariantList colorMemories READ colorMemories NOTIFY memoriesChanged)
    Q_PROPERTY(QVariantList positionMemories READ positionMemories NOTIFY memoriesChanged)

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
    bool effectSpread() const { return m_spread; }
    void setEffectSpread(bool spread);

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
    static const int MemoryCount = 8;
    QVariantList colorMemories() const;
    QVariantList positionMemories() const;
    /** Recall a memory, or store the current colour / position in an empty one */
    Q_INVOKABLE void memoryPress(const QString &kind, int index);
    Q_INVOKABLE void memoryClear(const QString &kind, int index);

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

private slots:
    void slotSelectionChanged();
    void slotSlotPicked(QString mode, bool isFader, int index, quint32 functionId);

private:
    QList<quint32> selectedFixtures() const;
    void applyPosition();
    Function *createEffect(const QString &key, const QList<quint32> &fixtures);
    void removeEffect(const QString &key, bool deleteFunction);
    void updateEffectParams();
    uint effectDuration(const QString &key) const;

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

private:
    ContextManager *m_contextManager;
    PlaybackManager *m_playbacks;

    QList<quint32> m_selectionOrder;    // order of the last selected group
    qreal m_pan, m_tilt, m_fan;
    bool m_crossed;

    struct Effect
    {
        quint32 functionId;
        quint32 groupId;                // fixture group created for an RGB matrix
    };
    QMap<QString, Effect> m_effects;

    qreal m_bpm;
    qreal m_size;
    bool m_spread;
    int m_cueCounter;
    qreal m_cueFade;
    QColor m_lastColor;

    quint32 m_pendingCue;           // cue waiting to be added to a picked playback
    QString m_pendingName;

    QVector<Memory> m_colorMemories;
    QVector<Memory> m_positionMemories;
};

#endif // PROGRAMMERMANAGER_H
