/*
  Q Light Controller Plus
  linkclock.h

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

#ifndef LINKCLOCK_H
#define LINKCLOCK_H

#include <QObject>
#include <QTimer>

/**
 * KAHO: tempo of an Ableton Link session (rekordbox, Ableton Live, Traktor...
 * on the same network). Built only with the KAHO_ABLETON_LINK CMake option;
 * without it available() is false and nothing else happens.
 */
class LinkClock final : public QObject
{
    Q_OBJECT

public:
    explicit LinkClock(QObject *parent = nullptr);
    ~LinkClock();

    static bool available();

    void setEnabled(bool enable);
    bool isEnabled() const { return m_enabled; }

    /** Number of other Link applications in the session */
    int peers() const { return m_peers; }
    qreal tempo() const { return m_tempo; }

signals:
    void tempoChanged(qreal bpm);
    void peersChanged(int peers);

private slots:
    void slotPoll();

private:
    struct Private;
    Private *d;
    QTimer m_timer;
    bool m_enabled;
    int m_peers;
    qreal m_tempo;
};

#endif // LINKCLOCK_H
