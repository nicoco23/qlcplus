/*
  Q Light Controller Plus
  programmercommands.cpp

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

/* KAHO: second part of ProgrammerManager — fixture sheet and command line */

#include <QRegularExpression>

#include "programmermanager.h"
#include "playbackmanager.h"
#include "contextmanager.h"
#include "inputoutputmap.h"
#include "fixturegroup.h"
#include "qlcchannel.h"
#include "universe.h"
#include "fixture.h"
#include "doc.h"

#define TEMP_PREFIX QStringLiteral("· ")

/*********************************************************************
 * Fixture sheet
 *********************************************************************/

void ProgrammerManager::setSheetActive(bool active)
{
    if (active == m_sheetTimer.isActive())
        return;
    if (active)
    {
        m_sheetTimer.start();
        slotRefreshSheet();
    }
    else
        m_sheetTimer.stop();
    emit sheetActiveChanged();
}

void ProgrammerManager::slotRefreshSheet()
{
    QList<Universe *> universes = m_doc->inputOutputMap()->universes();
    QList<quint32> selected = m_contextManager->selectedFixtureIDList();

    // channels held by the programmer, per fixture
    QHash<quint32, QSet<quint32>> held;
    for (const SceneValue &sv : m_contextManager->dumpValues())
        held[sv.fxi].insert(sv.channel);

    QList<Fixture *> fixtures = m_doc->fixtures();
    std::sort(fixtures.begin(), fixtures.end(), [](Fixture *a, Fixture *b) { return a->id() < b->id(); });

    QVariantList sheet;
    for (Fixture *fxi : fixtures)
    {
        Universe *uni = fxi->universe() < quint32(universes.count()) ? universes.at(fxi->universe()) : nullptr;
        const QSet<quint32> prog = held.value(fxi->id());
        auto value = [&](quint32 ch) -> int
        {
            if (uni == nullptr || ch == QLCChannel::invalid())
                return -1;
            return uni->preGMValue(int(fxi->address() + ch));
        };

        QVariantMap row;
        row.insert("id", fxi->id());
        row.insert("name", fxi->name());
        row.insert("selected", selected.contains(fxi->id()));

        quint32 dimCh = fxi->masterIntensityChannel();
        int dim = value(dimCh);
        row.insert("dim", dim < 0 ? -1 : qRound(dim / 2.55));
        row.insert("dimProg", prog.contains(dimCh));

        QVector<quint32> rgb = fxi->rgbChannels();
        if (rgb.count() == 3)
        {
            row.insert("color", QColor(value(rgb[0]), value(rgb[1]), value(rgb[2])).name());
            row.insert("colorProg", prog.contains(rgb[0]) || prog.contains(rgb[1]) || prog.contains(rgb[2]));
        }
        else
        {
            row.insert("color", QString());
            row.insert("colorProg", false);
        }

        quint32 panCh = fxi->channelNumber(QLCChannel::Pan, QLCChannel::MSB);
        quint32 tiltCh = fxi->channelNumber(QLCChannel::Tilt, QLCChannel::MSB);
        int pan = value(panCh), tilt = value(tiltCh);
        row.insert("pan", pan < 0 ? QString() : QString::number(qRound(pan / 2.55)));
        row.insert("tilt", tilt < 0 ? QString() : QString::number(qRound(tilt / 2.55)));
        row.insert("posProg", prog.contains(panCh) || prog.contains(tiltCh));

        QString beam;
        bool beamProg = false;
        for (quint32 ch = 0; ch < fxi->channels(); ch++)
        {
            const QLCChannel *channel = fxi->channel(ch);
            if (channel == nullptr || ch == dimCh)
                continue;
            if (channel->group() == QLCChannel::Beam || channel->group() == QLCChannel::Shutter)
            {
                int v = value(ch);
                if (channel->group() == QLCChannel::Shutter)
                {
                    if (v >= 10)
                        beam += (beam.isEmpty() ? "" : " · ") + tr("strobe");
                }
                else
                    beam = QString::number(qRound(v / 2.55)) + (beam.isEmpty() ? "" : " · " + beam);
                beamProg |= prog.contains(ch);
            }
        }
        row.insert("beam", beam);
        row.insert("beamProg", beamProg);
        sheet.append(row);
    }

    if (sheet != m_sheet)
    {
        m_sheet = sheet;
        emit fixtureSheetChanged();
    }
}

void ProgrammerManager::selectIds(const QList<quint32> &ids, bool additive, bool remove)
{
    if (remove)
    {
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
        if (m_doc->fixture(id) == nullptr)
            continue;
        if (m_selectionOrder.contains(id) == false)
            m_selectionOrder.append(id);
        m_contextManager->setFixtureIDSelection(id, true);
    }
}

void ProgrammerManager::selectFixture(quint32 fixtureId, bool additive)
{
    bool isSelected = m_contextManager->selectedFixtureIDList().contains(fixtureId);
    if (additive && isSelected)
        selectIds({ fixtureId }, true, true);
    else
        selectIds({ fixtureId }, additive, false);
    if (m_sheetTimer.isActive())
        slotRefreshSheet();
}

/*********************************************************************
 * Command line
 *********************************************************************/

namespace
{
    bool isNumber(const QString &t)
    {
        bool ok = false;
        t.toDouble(&ok);
        return ok;
    }

    /** "3", "3 Thru 6", "1 + 4 Thru 6 - 5" starting at tokens[pos]; numbers are 1-based */
    bool parseList(const QStringList &tokens, int &pos, QList<int> &out)
    {
        bool any = false;
        bool minus = false;
        while (pos < tokens.count())
        {
            if (isNumber(tokens.at(pos)) == false)
                break;
            int from = tokens.at(pos++).toInt();
            int to = from;
            if (pos + 1 < tokens.count() && (tokens.at(pos) == "thru" || tokens.at(pos) == "t") && isNumber(tokens.at(pos + 1)))
            {
                to = tokens.at(pos + 1).toInt();
                pos += 2;
            }
            if (to < from)
                std::swap(from, to);
            for (int n = from; n <= to && n - from < 1000; n++)
            {
                if (minus)
                    out.removeAll(n);
                else if (out.contains(n) == false)
                    out.append(n);
            }
            any = true;
            if (pos + 1 < tokens.count() && (tokens.at(pos) == "+" || tokens.at(pos) == "-") && isNumber(tokens.at(pos + 1)))
            {
                minus = tokens.at(pos) == "-";
                pos++;
                continue;
            }
            break;
        }
        return any;
    }

    QColor namedColour(const QString &name)
    {
        static const QHash<QString, QString> fr =
        {
            { "rouge", "#ff2020" }, { "orange", "#ff6a00" }, { "ambre", "#ffb000" }, { "jaune", "#fff200" },
            { "vert", "#40ff30" }, { "cyan", "#00ffd0" }, { "bleu", "#0090ff" }, { "violet", "#9000ff" },
            { "magenta", "#ff00c8" }, { "blanc", "#ffffff" }, { "rose", "#ff7ad9" }, { "kaho", "#a98bff" },
            { "red", "#ff2020" }, { "amber", "#ffb000" }, { "yellow", "#fff200" }, { "green", "#40ff30" },
            { "blue", "#0090ff" }, { "white", "#ffffff" }, { "pink", "#ff7ad9" }, { "purple", "#9000ff" },
        };
        if (fr.contains(name))
            return QColor(fr.value(name));
        if (name.startsWith('#'))
            return QColor(name);
        return QColor();
    }
}

QString ProgrammerManager::executeCommand(const QString &command)
{
    QString text = command.trimmed();
    if (text.isEmpty())
        return QString();

    // tokens: words, numbers, + and -, "quoted names"; "4.2" stays one token
    QStringList tokens;
    static const QRegularExpression re(QStringLiteral("\"([^\"]*)\"|([+\\-])(?=\\s|\\d|$)|([^\\s\"]+)"));
    QRegularExpressionMatchIterator it = re.globalMatch(text);
    while (it.hasNext())
    {
        QRegularExpressionMatch m = it.next();
        if (m.capturedStart(1) >= 0)
            tokens.append(QChar('"') + m.captured(1));      // leading quote marks a name
        else if (m.capturedStart(2) >= 0)
            tokens.append(m.captured(2));
        else
            tokens.append(m.captured(3).toLower());
    }

    bool ok = true;
    QString result = runCommand(tokens, ok);

    m_commandFeedback = result;
    m_commandFailed = !ok;
    m_commandLog.append(text + "   →   " + result);
    while (m_commandLog.count() > 60)
        m_commandLog.removeFirst();
    emit commandLogChanged();
    if (m_sheetTimer.isActive())
        slotRefreshSheet();
    return result;
}

QString ProgrammerManager::runCommand(const QStringList &tokens, bool &ok)
{
    ok = true;
    int pos = 0;
    QStringList done;
    auto fail = [&](const QString &msg) { ok = false; return msg; };
    auto name = [&](int p) { return p < tokens.count() && tokens.at(p).startsWith('"') ? tokens.at(p).mid(1) : QString(); };
    auto rest = [&](int p)
    {
        QStringList words;
        for (int i = p; i < tokens.count(); i++)
            words.append(tokens.at(i).startsWith('"') ? tokens.at(i).mid(1) : tokens.at(i));
        return words.join(' ');
    };
    // "exec 3", "executor 3" or just "3" -> 0-based playback index, -1 if missing
    auto execIndex = [&](int &p)
    {
        if (p < tokens.count() && (tokens.at(p) == "exec" || tokens.at(p) == "executor" || tokens.at(p) == "playback" || tokens.at(p) == "pb"))
            p++;
        if (p < tokens.count() && isNumber(tokens.at(p)))
        {
            int n = tokens.at(p++).toInt();
            if (n >= 1 && n <= PlaybackManager::FaderCount)
                return n - 1;
        }
        return -1;
    };
    // "preset 4.2", "color 2", "position 3" -> kind + 0-based index
    auto presetRef = [&](int &p, QString &kind, int &index)
    {
        if (p >= tokens.count())
            return false;
        QString t = tokens.at(p);
        if (t == "preset" && p + 1 < tokens.count())
        {
            QStringList parts = tokens.at(p + 1).split('.');
            if (parts.count() != 2)
                return false;
            // preset types follow the usual numbering: 2 = position, 4 = colour
            if (parts.at(0) == "4") kind = "color";
            else if (parts.at(0) == "2") kind = "position";
            else return false;
            index = parts.at(1).toInt() - 1;
            p += 2;
        }
        else if ((t == "color" || t == "colour" || t == "couleur" || t == "position" || t == "pos")
                 && p + 1 < tokens.count() && isNumber(tokens.at(p + 1)))
        {
            kind = (t == "position" || t == "pos") ? "position" : "color";
            index = tokens.at(p + 1).toInt() - 1;
            p += 2;
        }
        else
            return false;
        return index >= 0 && index < MemoryCount;
    };

    while (pos < tokens.count())
    {
        QString t = tokens.at(pos);

        /* ---------------- selection */
        bool plus = false, minus = false;
        if ((t == "+" || t == "-") && pos + 1 < tokens.count())
        {
            plus = t == "+";
            minus = t == "-";
            t = tokens.at(++pos);
        }
        if (t == "group" || t == "g" || t == "groupe")
        {
            pos++;
            QList<int> numbers;
            if (parseList(tokens, pos, numbers) == false)
                return fail(tr("Group : numéro attendu (ex. Group 1 Thru 3)"));
            QList<FixtureGroup *> pool;
            for (FixtureGroup *grp : m_doc->fixtureGroups())
                if (grp->name().startsWith(TEMP_PREFIX) == false)
                    pool.append(grp);
            QList<quint32> ids;
            QStringList names;
            for (int n : numbers)
            {
                if (n < 1 || n > pool.count())
                    return fail(tr("Group %1 n'existe pas").arg(n));
                ids.append(pool.at(n - 1)->fixtureList());
                names.append(pool.at(n - 1)->name());
            }
            selectIds(ids, plus, minus);
            done.append(tr("%1 : %2 machines").arg(names.join(" + ")).arg(selectionCount()));
            continue;
        }
        if (t == "fixture" || t == "fix" || t == "f" || isNumber(t))
        {
            if (isNumber(t) == false)
                pos++;
            QList<int> numbers;
            if (parseList(tokens, pos, numbers) == false)
                return fail(tr("Fixture : numéro attendu (ex. Fixture 1 Thru 4)"));
            QList<quint32> ids;
            for (int n : numbers)
                if (n >= 1 && m_doc->fixture(quint32(n - 1)) != nullptr)
                    ids.append(quint32(n - 1));
            if (ids.isEmpty())
                return fail(tr("Aucune machine à ces numéros"));
            selectIds(ids, plus, minus);
            done.append(tr("%1 machine(s) sélectionnée(s)").arg(selectionCount()));
            continue;
        }
        if (plus || minus)
            return fail(tr("Après + ou - : Group ou Fixture"));

        if (t == "all" || t == "tout")       { selectAll(); pos++; done.append(tr("tout sélectionné")); continue; }
        if (t == "odd" || t == "impairs")    { selectOddEven(true); pos++; done.append(tr("impairs")); continue; }
        if (t == "even" || t == "pairs")     { selectOddEven(false); pos++; done.append(tr("pairs")); continue; }

        /* ---------------- values */
        if (t == "at" || t == "@" || t == "full" || t == "zero")
        {
            qreal level = -1;
            if (t == "full") level = 1;
            else if (t == "zero") level = 0;
            else if (pos + 1 < tokens.count())
            {
                QString v = tokens.at(++pos);
                if (v == "full") level = 1;
                else if (v == "zero") level = 0;
                else if (isNumber(v)) level = qBound(0.0, v.toDouble(), 100.0) / 100.0;
            }
            if (level < 0)
                return fail(tr("At : valeur attendue (0 à 100, ou Full)"));
            if (selectionCount() == 0)
                return fail(tr("Aucune machine sélectionnée"));
            setIntensity(level);
            pos++;
            done.append(tr("intensité %1 %").arg(qRound(level * 100)));
            continue;
        }
        if (t == "locate")   { if (selectionCount() == 0) return fail(tr("Aucune machine sélectionnée")); locate(); pos++; done.append(tr("locate")); continue; }

        {
            QString kind;
            int index = -1, p = pos;
            if (presetRef(p, kind, index))
            {
                QVector<Memory> &list = kind == "color" ? m_colorMemories : m_positionMemories;
                if (list[index].used == false)
                    return fail(tr("Ce preset est vide"));
                if (selectionCount() == 0)
                    return fail(tr("Aucune machine sélectionnée"));
                memoryPress(kind, index);
                pos = p;
                done.append(tr("preset « %1 »").arg(list[index].name));
                continue;
            }
        }
        if ((t == "color" || t == "colour" || t == "couleur") && pos + 1 < tokens.count())
        {
            QColor c = namedColour(tokens.at(pos + 1).startsWith('"') ? tokens.at(pos + 1).mid(1).toLower() : tokens.at(pos + 1));
            if (c.isValid() == false)
                return fail(tr("Couleur inconnue : %1").arg(tokens.at(pos + 1)));
            if (selectionCount() == 0)
                return fail(tr("Aucune machine sélectionnée"));
            setColor(c);
            pos += 2;
            done.append(tr("couleur %1").arg(c.name()));
            continue;
        }
        if (t == "effect" || t == "effet" || t == "fx")
        {
            if (pos + 1 >= tokens.count())
                return fail(tr("Effect : numéro, nom ou Off attendu"));
            QString arg = rest(pos + 1).toLower();
            if (arg == "off")
            {
                clearEffects();
                done.append(tr("effets arrêtés"));
                return done.join(" · ");
            }
            if (selectionCount() == 0)
                return fail(tr("Aucune machine sélectionnée"));
            const QVariantList list = effects();
            for (int i = 0; i < list.count(); i++)
            {
                QVariantMap e = list.at(i).toMap();
                if (arg == QString::number(i + 1) || e.value("label").toString().toLower() == arg)
                {
                    toggleEffect(e.value("key").toString());
                    done.append(tr("effet « %1 »").arg(e.value("label").toString()));
                    return done.join(" · ");
                }
            }
            return fail(tr("Effet inconnu : %1").arg(arg));
        }
        if ((t == "fade" || t == "fondu") && pos + 1 < tokens.count() && isNumber(tokens.at(pos + 1)))
        {
            setCueFade(tokens.at(pos + 1).toDouble());
            pos += 2;
            done.append(tr("fondu %1 s").arg(cueFade()));
            continue;
        }
        if ((t == "bpm" || t == "tempo") && pos + 1 < tokens.count() && isNumber(tokens.at(pos + 1)))
        {
            setEffectBpm(tokens.at(pos + 1).toDouble());
            pos += 2;
            done.append(tr("%1 BPM").arg(qRound(effectBpm())));
            continue;
        }

        /* ---------------- programmer */
        if (t == "clear")
        {
            if (selectionCount() > 0) { clearSelection(); done.append(tr("sélection vidée")); }
            else { clearProgrammer(); done.append(tr("programmeur vidé")); }
            pos++;
            continue;
        }
        if (t == "clearall")
        {
            clearSelection();
            clearProgrammer();
            pos++;
            done.append(tr("sélection et programmeur vidés"));
            continue;
        }

        if (t == "store" || t == "record")
        {
            int p = pos + 1;
            QString kind;
            int index = -1;
            if (presetRef(p, kind, index))
            {
                if (memoryStore(kind, index) == false)
                    return fail(kind == "color" ? tr("Choisis d'abord une couleur") : tr("Preset invalide"));
                if (name(p).isEmpty() == false)
                    memoryRename(kind, index, name(p));
                done.append(tr("preset %1 %2 enregistré").arg(kind == "color" ? tr("couleur") : tr("position")).arg(index + 1));
                return done.join(" · ");
            }
            if (hasContent() == false)
                return fail(tr("Le programmeur est vide"));
            if (p < tokens.count() && (tokens.at(p) == "cue" || tokens.at(p) == "sequence" || tokens.at(p) == "seq"))
                p++;
            int slot = -1;
            if (p < tokens.count() && (tokens.at(p) == "exec" || tokens.at(p) == "executor" || tokens.at(p) == "playback" || tokens.at(p) == "pb"))
            {
                slot = execIndex(p);
                if (slot < 0)
                    return fail(tr("Store Exec : numéro de 1 à %1").arg(PlaybackManager::FaderCount));
            }
            QString cueName = name(p);
            if (slot < 0)
            {
                record(cueName, true);
                done.append(tr("cue enregistré sur le premier playback libre"));
            }
            else
            {
                m_pendingName = cueName.isEmpty() ? nextCueName() : cueName;
                m_pendingCue = buildCue(m_pendingName);
                appendToSlot(true, slot, m_playbacks->slotFunction(true, slot));
                done.append(tr("« %1 » enregistré sur l'exécuteur %2").arg(m_pendingName).arg(slot + 1));
            }
            return done.join(" · ");
        }
        if (t == "update")
        {
            int p = pos + 1;
            int slot = execIndex(p);
            if (slot < 0)
                return fail(tr("Update Exec : numéro de 1 à %1").arg(PlaybackManager::FaderCount));
            if (hasContent() == false)
                return fail(tr("Le programmeur est vide"));
            if (m_doc->function(m_playbacks->slotFunction(true, slot)) == nullptr)
                return fail(tr("L'exécuteur %1 est vide").arg(slot + 1));
            updateSlot(true, slot, m_playbacks->slotFunction(true, slot));
            done.append(tr("exécuteur %1 mis à jour").arg(slot + 1));
            return done.join(" · ");
        }

        /* ---------------- playback */
        if (t == "go" || t == "go+" || t == "on" || t == "goback" || t == "go-" || t == "off" || t == "release")
        {
            int p = pos + 1;
            if ((t == "off" || t == "release") && p < tokens.count() && (tokens.at(p) == "all" || tokens.at(p) == "tout"))
            {
                m_playbacks->releaseAll();
                done.append(tr("tout relâché"));
                return done.join(" · ");
            }
            int slot = execIndex(p);
            if (slot < 0)
                return fail(tr("%1 : numéro d'exécuteur de 1 à %2").arg(t).arg(PlaybackManager::FaderCount));
            if (t == "goback" || t == "go-") m_playbacks->back(slot);
            else if (t == "off" || t == "release") m_playbacks->release(slot);
            else m_playbacks->go(slot);
            pos = p;
            done.append(tr("%1 exécuteur %2").arg(t).arg(slot + 1));
            continue;
        }
        if (t == "page" && pos + 1 < tokens.count() && isNumber(tokens.at(pos + 1)))
        {
            int n = tokens.at(pos + 1).toInt();
            if (n < 1 || n > PlaybackManager::PageCount)
                return fail(tr("Page de 1 à %1").arg(PlaybackManager::PageCount));
            m_playbacks->setPage(n - 1);
            pos += 2;
            done.append(tr("page %1").arg(n));
            continue;
        }
        if (t == "blackout" || t == "bo")
        {
            m_playbacks->setGrandMaster(m_playbacks->grandMaster() > 0 ? 0 : 1);
            pos++;
            done.append(m_playbacks->grandMaster() > 0 ? tr("blackout levé") : tr("blackout"));
            continue;
        }
        if (t == "delete" || t == "label")
        {
            int p = pos + 1;
            QString kind;
            int index = -1;
            if (presetRef(p, kind, index))
            {
                if (t == "delete") memoryClear(kind, index);
                else memoryRename(kind, index, name(p));
                done.append(t == "delete" ? tr("preset effacé") : tr("preset renommé"));
                return done.join(" · ");
            }
            int slot = execIndex(p);
            if (slot < 0)
                return fail(tr("%1 : Exec N ou Preset T.N attendu").arg(t));
            if (t == "delete") m_playbacks->assignFader(slot, Function::invalidId());
            else m_playbacks->setFaderLabel(slot, name(p));
            done.append(t == "delete" ? tr("exécuteur %1 vidé").arg(slot + 1) : tr("exécuteur %1 renommé").arg(slot + 1));
            return done.join(" · ");
        }
        if (t == "help" || t == "?" || t == "aide")
            return tr("Group 1 Thru 3 · Fixture 4 + 6 · At 50 · Full · Color Rouge · Preset 4.2 · Effect Cercle · Store Exec 2 \"nom\" · Store Preset 4.13 · Update Exec 2 · Go 2 · GoBack 2 · Off 2 · Off All · Page 2 · Clear · ClearAll · Blackout");

        return fail(tr("Commande inconnue : %1 (tape Help)").arg(t.startsWith('"') ? t.mid(1) : t));
    }

    return done.isEmpty() ? QString() : done.join(" · ");
}
