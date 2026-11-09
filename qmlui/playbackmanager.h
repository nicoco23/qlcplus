/*
  Q Light Controller Plus
  playbackmanager.h

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

#ifndef PLAYBACKMANAGER_H
#define PLAYBACKMANAGER_H

#include <QVariantList>
#include <QVector>
#include <QHash>
#include <QTimer>

#include "previewcontext.h"

class QXmlStreamReader;
class QXmlStreamWriter;
class Function;
class Doc;

#define KXMLQLCPlaybacks QStringLiteral("Playbacks")

/**
 * Console-style playback surface: pages of 8 playback faders (with GO,
 * FLASH and RELEASE) and a grid of execute buttons, each one mapped to
 * a Function. Designed to be played by hand from an Akai APC mini,
 * which is detected automatically and receives LED feedback.
 */
class PlaybackManager final : public PreviewContext
{
    Q_OBJECT

    Q_PROPERTY(int page READ page WRITE setPage NOTIFY pageChanged)
    Q_PROPERTY(int pageCount READ pageCount CONSTANT)
    Q_PROPERTY(int faderCount READ faderCount CONSTANT)
    Q_PROPERTY(int execColumns READ execColumns CONSTANT)
    Q_PROPERTY(int execRows READ execRows CONSTANT)
    Q_PROPERTY(QVariantList faders READ faders NOTIFY fadersChanged)
    Q_PROPERTY(QVariantList execs READ execs NOTIFY execsChanged)
    Q_PROPERTY(QVariantList pages READ pages NOTIFY pagesChanged)
    Q_PROPERTY(qreal grandMaster READ grandMaster WRITE setGrandMaster NOTIFY grandMasterChanged)
    Q_PROPERTY(QString controllerName READ controllerName NOTIFY controllerChanged)
    Q_PROPERTY(bool controllerFeedback READ controllerFeedback NOTIFY controllerChanged)
    Q_PROPERTY(QVariantList functionsList READ functionsList NOTIFY functionsListChanged)
    Q_PROPERTY(quint32 armedFunction READ armedFunction WRITE setArmedFunction NOTIFY armedFunctionChanged)
    Q_PROPERTY(QString pickMode READ pickMode WRITE setPickMode NOTIFY pickModeChanged)

public:
    static const int PageCount = 8;      // one per APC mini scene button
    static const int FaderCount = 8;
    static const int ExecColumns = 8;
    static const int ExecRows = 7;       // the 8th pad row is used for FLASH
    static const int ExecCount = ExecColumns * ExecRows;

    PlaybackManager(QQuickView *view, Doc *doc, QObject *parent = nullptr);
    ~PlaybackManager();

    int page() const;
    void setPage(int page);
    int pageCount() const { return PageCount; }
    int faderCount() const { return FaderCount; }
    int execColumns() const { return ExecColumns; }
    int execRows() const { return ExecRows; }

    QVariantList faders() const;
    QVariantList execs() const;
    QVariantList pages() const;

    qreal grandMaster() const;
    void setGrandMaster(qreal level);

    QString controllerName() const;
    bool controllerFeedback() const;

    QVariantList functionsList() const;

    /** Function waiting to be dropped on a playback or an execute button */
    quint32 armedFunction() const;
    void setArmedFunction(quint32 id);

    /* Playback faders (index on the current page) */
    Q_INVOKABLE void setFaderLevel(int index, qreal level);
    Q_INVOKABLE void go(int index);
    Q_INVOKABLE void back(int index);
    Q_INVOKABLE void flash(int index, bool pressed);
    Q_INVOKABLE void release(int index);
    Q_INVOKABLE void assignFader(int index, quint32 functionId);

    /* Execute grid (index on the current page) */
    Q_INVOKABLE void execPress(int index, bool pressed);
    Q_INVOKABLE void assignExec(int index, quint32 functionId);
    Q_INVOKABLE void setExecFlashMode(int index, bool flash);

    /* Custom label and color of a slot ("" = function name / type color) */
    Q_INVOKABLE void setFaderLabel(int index, const QString &label);
    Q_INVOKABLE void setFaderColor(int index, const QString &color);
    Q_INVOKABLE void setExecLabel(int index, const QString &label);
    Q_INVOKABLE void setExecColor(int index, const QString &color);

    /** Swap or move two slots of the current page (drag & drop) */
    Q_INVOKABLE void moveFader(int from, int to);
    Q_INVOKABLE void moveExec(int from, int to);

    /** Put a function on the first free playback of the page, or the first free
     *  execute button if every playback is used. Returns false if the page is full */
    Q_INVOKABLE bool assignToFree(quint32 functionId);

    Q_INVOKABLE void setPageName(int page, const QString &name);

    /** "Pick" mode, used by the programmer: the next slot clicked is reported
     *  with slotPicked() instead of being assigned ("" = off) */
    QString pickMode() const;
    void setPickMode(const QString &mode);
    Q_INVOKABLE void pickSlot(bool isFader, int index);

    /** Function held by a slot of the current page */
    quint32 slotFunction(bool isFader, int index);
    /** Put another function on a slot, keeping its name and colour */
    void replaceSlotFunction(bool isFader, int index, quint32 functionId);

    /** Release every playback and execute started from here */
    Q_INVOKABLE void releaseAll();

    void resetContents();
    bool loadXML(QXmlStreamReader &root);
    bool saveXML(QXmlStreamWriter *doc) const;

signals:
    void pageChanged();
    void fadersChanged();
    void execsChanged();
    void pagesChanged();
    void grandMasterChanged();
    void controllerChanged();
    void functionsListChanged();
    void armedFunctionChanged();
    void pickModeChanged();
    void slotPicked(QString mode, bool isFader, int index, quint32 functionId);

private slots:
    void slotRefresh();
    void slotInputValueChanged(quint32 universe, quint32 channel, uchar value, const QString &key);
    void slotFunctionRemoved(quint32 id);
    void slotFunctionsChanged();

private:
    struct FaderState
    {
        quint32 functionId = 0xFFFFFFFF;
        qreal level = 0.0;
        int attributeId = -1;
        bool flashStarted = false;
        bool flashing = false;
        bool needsPickup = false;
        bool owned = false;         // started from this playback (not by a chaser, a VC button...)
        QString label;
        QString color;
    };

    struct ExecState
    {
        quint32 functionId = 0xFFFFFFFF;
        bool flashStarted = false;
        bool flashMode = false;     // momentary: runs only while the button is held
        QString label;
        QString color;
    };

    FaderState &fader(int page, int index);
    ExecState &exec(int page, int index);
    Function *functionAt(quint32 id) const;
    int parentId(bool isFader, int page, int index) const;

    void startFunction(Function *f, int parent, qreal intensity);
    void stopFunction(Function *f, int parent);
    void applyFaderLevel(int page, int index);
    QVariantMap describe(quint32 functionId, bool running) const;

    /* Akai APC mini */
    void detectController();
    bool autoPatchController();
    void ensureFeedbackPatch();
    void updateControllerLeds(bool force);
    void sendLed(quint32 note, uchar value, bool force);

private:
    int m_page;
    QVector<FaderState> m_faders;   // PageCount * FaderCount
    QVector<ExecState> m_execs;     // PageCount * ExecCount
    QStringList m_pageNames;        // PageCount
    quint32 m_armedFunction;
    QString m_pickMode;

    QVariantList m_fadersCache;
    QVariantList m_execsCache;
    QVariantList m_pagesCache;
    QVariantList m_functionsCache;
    qreal m_grandMasterCache;

    QTimer m_refreshTimer;
    int m_refreshTicks;

    quint32 m_controllerUniverse;
    QString m_controllerName;
    bool m_controllerFeedback;
    bool m_shift;
    bool m_autoPatchDone;
    QHash<quint32, uchar> m_ledCache;
};

#endif // PLAYBACKMANAGER_H
