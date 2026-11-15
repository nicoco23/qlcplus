/*
  Q Light Controller Plus
  linkclock.cpp

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

#include "linkclock.h"

#ifdef KAHO_ABLETON_LINK
#include <ableton/Link.hpp>

struct LinkClock::Private
{
    Private() : link(120.0) { }
    ableton::Link link;
};
#else
struct LinkClock::Private { };
#endif

LinkClock::LinkClock(QObject *parent)
    : QObject(parent)
    , d(nullptr)
    , m_enabled(false)
    , m_peers(0)
    , m_tempo(120)
{
    m_timer.setInterval(150);
    connect(&m_timer, &QTimer::timeout, this, &LinkClock::slotPoll);
}

LinkClock::~LinkClock()
{
    setEnabled(false);
    delete d;
}

bool LinkClock::available()
{
#ifdef KAHO_ABLETON_LINK
    return true;
#else
    return false;
#endif
}

void LinkClock::setEnabled(bool enable)
{
    if (available() == false || enable == m_enabled)
        return;
    m_enabled = enable;

#ifdef KAHO_ABLETON_LINK
    // the session is only joined when asked for: no network traffic otherwise
    if (enable && d == nullptr)
        d = new Private;
    if (d != nullptr)
        d->link.enable(enable);
#endif

    if (enable)
    {
        m_timer.start();
        slotPoll();
    }
    else
    {
        m_timer.stop();
        if (m_peers != 0)
        {
            m_peers = 0;
            emit peersChanged(0);
        }
    }
}

void LinkClock::slotPoll()
{
#ifdef KAHO_ABLETON_LINK
    if (d == nullptr)
        return;
    int peers = int(d->link.numPeers());
    if (peers != m_peers)
    {
        m_peers = peers;
        emit peersChanged(peers);
    }
    qreal tempo = d->link.captureAppSessionState().tempo();
    if (qAbs(tempo - m_tempo) > 0.01)
    {
        m_tempo = tempo;
        // alone in the session the tempo is only our own default: nothing to follow
        if (peers > 0)
            emit tempoChanged(tempo);
    }
#endif
}
