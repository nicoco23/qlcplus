/*
  Q Light Controller Plus
  Programmer.qml

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

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import org.qlcplus.classes 1.0
import "."

/** MagicQ style programmer: groups, attributes, effects, record. */
Rectangle
{
    id: pgRoot
    anchors.fill: parent
    color: UISettings.bgStronger

    property string contextName: "PROGRAMMER"

    readonly property real unit: UISettings.listItemHeight
    readonly property real gap: Math.max(3, unit * 0.12)
    readonly property bool hasSelection: programmer.selectionCount > 0
    property real intensity: 1.0
    property string lastMessage: ""

    Connections
    {
        target: programmer
        function onRecorded(name, where)
        {
            pgRoot.lastMessage = qsTr("« %1 » enregistré · %2").arg(name).arg(where)
            cueName.text = ""
        }
    }

    focus: true
    Component.onCompleted: Qt.callLater(forceActiveFocus)
    onVisibleChanged: if (visible) Qt.callLater(forceActiveFocus)
    Keys.onPressed: (event) =>
    {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
        {
            programmer.record(cueName.text, (event.modifiers & Qt.ShiftModifier) === 0)
            event.accepted = true
        }
        else if (event.key === Qt.Key_Backspace && (event.modifiers & Qt.ControlModifier))
        {
            programmer.clearProgrammer()
            event.accepted = true
        }
        else if (event.key === Qt.Key_Escape)
        {
            programmer.clearSelection()
            event.accepted = true
        }
    }

    /* ---------------------------------------------------------------- building blocks */

    component ConsoleKey: Rectangle
    {
        id: key
        property string text: ""
        property string subText: ""
        property color keyColor: UISettings.consoleAccent
        property color textColor: UISettings.fgMain
        property bool lit: false
        property real fontSize: UISettings.textSizeDefault * 0.75
        signal clicked(var mouse)

        radius: Math.min(8, height * 0.2)
        color: lit ? keyColor : (keyArea.pressed ? Qt.lighter(UISettings.bgControl, 1.3)
                                                 : (keyArea.containsMouse && enabled ? UISettings.bgControl : UISettings.bgMedium))
        border.color: lit ? Qt.lighter(keyColor, 1.3) : UISettings.borderColorDark
        opacity: enabled ? 1 : 0.4
        Behavior on color { ColorAnimation { duration: 80 } }

        Column
        {
            anchors.centerIn: parent
            width: parent.width - 6
            Text
            {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: key.text
                color: key.lit ? UISettings.bgStronger : key.textColor
                font.family: UISettings.titleFontName
                font.pixelSize: key.fontSize
                font.letterSpacing: 0.5
                elide: Text.ElideRight
            }
            Text
            {
                visible: key.subText !== ""
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: key.subText
                color: key.lit ? Qt.darker(key.keyColor, 2.2) : UISettings.fgMedium
                font.family: UISettings.robotoFontName
                font.pixelSize: key.fontSize * 0.75
                elide: Text.ElideRight
            }
        }
        MouseArea
        {
            id: keyArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: (mouse) => { pgRoot.forceActiveFocus(); key.clicked(mouse) }
        }
    }

    component Panel: Rectangle
    {
        property string title: ""
        property string hint: ""
        default property alias content: body.data
        color: UISettings.bgStrong
        radius: 4

        Text
        {
            id: titleText
            x: 8; y: 5
            text: parent.title
            color: UISettings.consoleAccent
            font.family: UISettings.titleFontName
            font.pixelSize: UISettings.textSizeDefault * 0.7
            font.letterSpacing: 1
        }
        Text
        {
            anchors.right: parent.right
            anchors.rightMargin: 8
            y: 6
            width: parent.width - titleText.width - 22
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
            text: parent.hint
            color: UISettings.fgMedium
            font.family: UISettings.robotoFontName
            font.pixelSize: UISettings.textSizeDefault * 0.6
        }
        Item
        {
            id: body
            anchors.fill: parent
            anchors.margins: 8
            anchors.topMargin: titleText.height + 10
        }
    }

    /** Horizontal fader, 0.0 - 1.0 */
    component HSlider: Item
    {
        id: sl
        property real value: 0
        property color fillColor: UISettings.consoleAccent
        property string label: ""
        property string valueText: ""
        signal moved(real v)
        implicitHeight: pgRoot.unit * 0.95

        Text
        {
            id: slLabel
            anchors.verticalCenter: parent.verticalCenter
            text: sl.label
            width: sl.label === "" ? 0 : pgRoot.unit * 2.2
            color: UISettings.fgLight
            font.family: UISettings.robotoFontName
            font.pixelSize: UISettings.textSizeDefault * 0.7
        }
        Rectangle
        {
            id: track
            anchors.left: slLabel.right
            anchors.right: slValue.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            height: Math.max(6, parent.height * 0.22)
            radius: height / 2
            color: UISettings.bgStronger
            border.color: UISettings.borderColorDark
            Rectangle
            {
                width: parent.width * sl.value
                height: parent.height
                radius: parent.radius
                color: sl.fillColor
                opacity: sl.enabled ? 1 : 0.4
            }
            Rectangle
            {
                x: parent.width * sl.value - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: sl.height * 0.55
                height: width
                radius: width / 2
                color: UISettings.fgMain
                border.color: UISettings.bgStronger
                border.width: 2
            }
        }
        Text
        {
            id: slValue
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: pgRoot.unit * 1.6
            horizontalAlignment: Text.AlignRight
            text: sl.valueText
            color: UISettings.fgMain
            font.family: UISettings.robotoFontName
            font.pixelSize: UISettings.textSizeDefault * 0.7
        }
        MouseArea
        {
            anchors.fill: track
            anchors.margins: -sl.height * 0.4
            preventStealing: true
            function upd(mx) { sl.moved(Math.max(0, Math.min(1, (mx - sl.height * 0.4) / track.width))) }
            onPressed: (mouse) => { pgRoot.forceActiveFocus(); upd(mouse.x) }
            onPositionChanged: (mouse) => upd(mouse.x)
        }
    }

    /* ---------------------------------------------------------------- layout */

    ColumnLayout
    {
        anchors.fill: parent
        anchors.margins: pgRoot.gap
        spacing: pgRoot.gap

        /* ---------------- selection */
        Panel
        {
            id: selPanel
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(pgRoot.unit * 3, groupFlow.implicitHeight + pgRoot.unit * 1.8)
            title: qsTr("SÉLECTION")
            hint: programmer.selectionText

            RowLayout
            {
                anchors.fill: parent
                spacing: pgRoot.gap * 2

                Flow
                {
                    id: groupFlow
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: pgRoot.gap

                    Repeater
                    {
                        model: programmer.groups
                        ConsoleKey
                        {
                            width: Math.max(pgRoot.unit * 3.2, implicitW)
                            readonly property real implicitW: nameMetrics.width + pgRoot.unit * 0.9
                            height: pgRoot.unit * 1.25
                            text: modelData.name
                            subText: modelData.count + (modelData.count > 1 ? qsTr(" machines") : qsTr(" machine"))
                            lit: modelData.selected
                            border.color: modelData.partial ? UISettings.consoleAccent : (lit ? Qt.lighter(keyColor, 1.3) : UISettings.borderColorDark)
                            onClicked: (mouse) => programmer.selectGroup(modelData.id, (mouse.modifiers & Qt.ShiftModifier) || (mouse.modifiers & Qt.ControlModifier))
                            TextMetrics
                            {
                                id: nameMetrics
                                font.family: UISettings.titleFontName
                                font.pixelSize: UISettings.textSizeDefault * 0.75
                                text: modelData.name
                            }
                        }
                    }

                    Text
                    {
                        visible: programmer.groups.length === 0
                        width: groupFlow.width
                        text: qsTr("Aucun groupe dans ce projet. Exporte le projet depuis KahoStage (/stage export-qlc) : un groupe par type de machine et tes groupes perso sont créés.")
                        wrapMode: Text.Wrap
                        color: UISettings.fgMedium
                        font.family: UISettings.robotoFontName
                        font.pixelSize: UISettings.textSizeDefault * 0.75
                    }
                }

                GridLayout
                {
                    Layout.alignment: Qt.AlignTop
                    columns: 2
                    rowSpacing: pgRoot.gap
                    columnSpacing: pgRoot.gap
                    ConsoleKey { Layout.preferredWidth: pgRoot.unit * 2.4; Layout.preferredHeight: pgRoot.unit * 0.95; text: qsTr("TOUT"); onClicked: programmer.selectAll() }
                    ConsoleKey { Layout.preferredWidth: pgRoot.unit * 2.4; Layout.preferredHeight: pgRoot.unit * 0.95; text: qsTr("AUCUN"); enabled: pgRoot.hasSelection; onClicked: programmer.clearSelection() }
                    ConsoleKey { Layout.preferredWidth: pgRoot.unit * 2.4; Layout.preferredHeight: pgRoot.unit * 0.95; text: qsTr("IMPAIRS"); enabled: programmer.selectionCount > 1; onClicked: programmer.selectOddEven(true) }
                    ConsoleKey { Layout.preferredWidth: pgRoot.unit * 2.4; Layout.preferredHeight: pgRoot.unit * 0.95; text: qsTr("PAIRS"); enabled: programmer.selectionCount > 1; onClicked: programmer.selectOddEven(false) }
                }
            }
        }

        /* ---------------- attributes + programmer */
        RowLayout
        {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: pgRoot.height - selPanel.height - effPanel.height - pgRoot.gap * 4
            Layout.maximumHeight: Layout.preferredHeight
            spacing: pgRoot.gap

            /* intensity */
            Panel
            {
                Layout.fillHeight: true
                Layout.preferredWidth: pgRoot.unit * 4.6
                title: qsTr("INTENSITÉ")
                enabled: pgRoot.hasSelection
                opacity: enabled ? 1 : 0.5

                ColumnLayout
                {
                    anchors.fill: parent
                    spacing: pgRoot.gap

                    Text
                    {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Math.round(pgRoot.intensity * 100) + "%"
                        color: UISettings.fgMain
                        font.family: UISettings.titleFontName
                        font.pixelSize: UISettings.textSizeDefault * 0.95
                    }
                    RowLayout
                    {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: pgRoot.gap
                        PlaybackFader
                        {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            value: pgRoot.intensity
                            active: true
                            levelColor: UISettings.consoleAccent
                            onMoved: (v) => { pgRoot.intensity = v; programmer.setIntensity(v) }
                        }
                        ColumnLayout
                        {
                            Layout.fillHeight: true
                            Layout.preferredWidth: pgRoot.unit * 1.6
                            spacing: pgRoot.gap
                            Repeater
                            {
                                model: [ 1.0, 0.75, 0.5, 0.25, 0 ]
                                ConsoleKey
                                {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    text: modelData === 1 ? qsTr("FULL") : (modelData === 0 ? qsTr("0") : Math.round(modelData * 100))
                                    lit: Math.abs(pgRoot.intensity - modelData) < 0.01
                                    onClicked: { pgRoot.intensity = modelData; programmer.setIntensity(modelData) }
                                }
                            }
                        }
                    }
                    Text
                    {
                        text: qsTr("STROBE")
                        color: UISettings.fgMedium
                        font.family: UISettings.titleFontName
                        font.pixelSize: UISettings.textSizeDefault * 0.6
                    }
                    GridLayout
                    {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: pgRoot.gap
                        columnSpacing: pgRoot.gap
                        Repeater
                        {
                            model: [ { v: 0, l: qsTr("OUVERT") }, { v: 0.2, l: qsTr("LENT") }, { v: 0.55, l: qsTr("MOYEN") }, { v: 1, l: qsTr("RAPIDE") } ]
                            ConsoleKey
                            {
                                Layout.fillWidth: true
                                Layout.preferredHeight: pgRoot.unit * 0.85
                                text: modelData.l
                                fontSize: UISettings.textSizeDefault * 0.6
                                keyColor: UISettings.fgMain
                                onClicked: programmer.setStrobe(modelData.v)
                            }
                        }
                    }
                }
            }

            /* colour */
            Panel
            {
                Layout.fillHeight: true
                Layout.preferredWidth: pgRoot.unit * 7.2
                title: qsTr("COULEUR")
                enabled: pgRoot.hasSelection
                opacity: enabled ? 1 : 0.5

                ColumnLayout
                {
                    anchors.fill: parent
                    spacing: pgRoot.gap

                    GridLayout
                    {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 4
                        rowSpacing: pgRoot.gap
                        columnSpacing: pgRoot.gap
                        Repeater
                        {
                            model: [
                                { c: "#ff2020", n: qsTr("Rouge") },   { c: "#ff6a00", n: qsTr("Orange") },
                                { c: "#ffb000", n: qsTr("Ambre") },   { c: "#fff200", n: qsTr("Jaune") },
                                { c: "#40ff30", n: qsTr("Vert") },    { c: "#00ffd0", n: qsTr("Cyan") },
                                { c: "#0090ff", n: qsTr("Bleu") },    { c: "#2020ff", n: qsTr("Bleu nuit") },
                                { c: "#a98bff", n: qsTr("KAHO") },    { c: "#9000ff", n: qsTr("Violet") },
                                { c: "#ff00c8", n: qsTr("Magenta") }, { c: "#ffffff", n: qsTr("Blanc") }
                            ]
                            Rectangle
                            {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 5
                                color: modelData.c
                                border.width: swArea.containsMouse ? 3 : 1
                                border.color: swArea.containsMouse ? UISettings.fgMain : Qt.darker(modelData.c, 1.6)
                                Text
                                {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottomMargin: 3
                                    text: modelData.n
                                    color: Qt.colorEqual(modelData.c, "#ffffff") || Qt.colorEqual(modelData.c, "#fff200")
                                           || Qt.colorEqual(modelData.c, "#40ff30") || Qt.colorEqual(modelData.c, "#00ffd0")
                                           ? "#15121f" : "white"
                                    font.family: UISettings.robotoFontName
                                    font.pixelSize: UISettings.textSizeDefault * 0.55
                                    font.bold: true
                                }
                                MouseArea
                                {
                                    id: swArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: { pgRoot.forceActiveFocus(); programmer.setColor(modelData.c) }
                                }
                            }
                        }
                    }

                    // free hue
                    Rectangle
                    {
                        Layout.fillWidth: true
                        Layout.preferredHeight: pgRoot.unit * 0.8
                        radius: 4
                        border.color: UISettings.borderColorDark
                        gradient: Gradient
                        {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#ff0000" }
                            GradientStop { position: 0.17; color: "#ffff00" }
                            GradientStop { position: 0.33; color: "#00ff00" }
                            GradientStop { position: 0.5; color: "#00ffff" }
                            GradientStop { position: 0.67; color: "#0000ff" }
                            GradientStop { position: 0.83; color: "#ff00ff" }
                            GradientStop { position: 1.0; color: "#ff0000" }
                        }
                        MouseArea
                        {
                            anchors.fill: parent
                            preventStealing: true
                            function pick(mx) { programmer.setColor(Qt.hsva(Math.max(0, Math.min(0.999, mx / width)), 1, 1, 1)) }
                            onPressed: (mouse) => { pgRoot.forceActiveFocus(); pick(mouse.x) }
                            onPositionChanged: (mouse) => pick(mouse.x)
                        }
                    }
                }
            }

            /* position + zoom */
            Panel
            {
                Layout.fillHeight: true
                Layout.fillWidth: true
                title: qsTr("POSITION")
                hint: qsTr("pan %1° · tilt %2° · éventail %3°").arg(Math.round(programmer.pan)).arg(Math.round(programmer.tilt)).arg(Math.round(programmer.fan))
                enabled: pgRoot.hasSelection
                opacity: enabled ? 1 : 0.5

                RowLayout
                {
                    anchors.fill: parent
                    spacing: pgRoot.gap * 2

                    // pan / tilt pad: horizontal = pan ±180°, vertical = tilt ±135° (up = towards the front)
                    Rectangle
                    {
                        id: pad
                        Layout.fillHeight: true
                        Layout.preferredWidth: height
                        Layout.maximumWidth: parent.width * 0.55
                        radius: 6
                        color: UISettings.bgStronger
                        border.color: UISettings.borderColorDark

                        readonly property real px: width / 2 + (programmer.pan / 360) * width
                        readonly property real py: height / 2 - (programmer.tilt / 270) * height

                        Rectangle { x: parent.width / 2; width: 1; height: parent.height; color: UISettings.bgControl }
                        Rectangle { y: parent.height / 2; height: 1; width: parent.width; color: UISettings.bgControl }
                        Rectangle
                        {
                            anchors.centerIn: parent
                            width: parent.width * 0.5
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.color: UISettings.bgControl
                        }
                        Text
                        {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 4
                            text: qsTr("AVANT")
                            color: UISettings.fgMedium
                            font.family: UISettings.robotoFontName
                            font.pixelSize: UISettings.textSizeDefault * 0.5
                        }
                        Text
                        {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            text: qsTr("ARRIÈRE")
                            color: UISettings.fgMedium
                            font.family: UISettings.robotoFontName
                            font.pixelSize: UISettings.textSizeDefault * 0.5
                        }
                        Rectangle
                        {
                            x: pad.px - width / 2
                            y: pad.py - height / 2
                            width: pgRoot.unit * 0.55
                            height: width
                            radius: width / 2
                            color: UISettings.consoleAccent
                            border.color: "white"
                            border.width: 2
                        }
                        MouseArea
                        {
                            anchors.fill: parent
                            preventStealing: true
                            function set(mx, my)
                            {
                                var pan = Math.max(-180, Math.min(180, (mx / width - 0.5) * 360))
                                var tilt = Math.max(-135, Math.min(135, (0.5 - my / height) * 270))
                                programmer.setPosition(pan, tilt)
                            }
                            onPressed: (mouse) => { pgRoot.forceActiveFocus(); set(mouse.x, mouse.y) }
                            onPositionChanged: (mouse) => set(mouse.x, mouse.y)
                        }
                    }

                    ColumnLayout
                    {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: pgRoot.gap

                        GridLayout
                        {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            columns: 2
                            rowSpacing: pgRoot.gap
                            columnSpacing: pgRoot.gap
                            Repeater
                            {
                                model: [
                                    { k: "centre", l: qsTr("CENTRE"), s: qsTr("droit") },
                                    { k: "face", l: qsTr("FACE"), s: qsTr("45° avant") },
                                    { k: "public", l: qsTr("PUBLIC"), s: qsTr("75° avant") },
                                    { k: "horizon", l: qsTr("HORIZON"), s: qsTr("90°") },
                                    { k: "fan", l: qsTr("ÉVENTAIL"), s: qsTr("60°") },
                                    { k: "fanwide", l: qsTr("ÉVENTAIL +"), s: qsTr("120°") },
                                    { k: "cross", l: qsTr("CROISÉ"), s: qsTr("1 sur 2") },
                                    { k: "back", l: qsTr("ARRIÈRE"), s: qsTr("45°") }
                                ]
                                ConsoleKey
                                {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    text: modelData.l
                                    subText: modelData.s
                                    fontSize: UISettings.textSizeDefault * 0.65
                                    onClicked: programmer.positionPreset(modelData.k)
                                }
                            }
                        }
                        HSlider
                        {
                            Layout.fillWidth: true
                            label: qsTr("Éventail")
                            value: programmer.fan / 180
                            valueText: Math.round(programmer.fan) + "°"
                            onMoved: (v) => programmer.fan = v * 180
                        }
                        HSlider
                        {
                            id: zoomSlider
                            Layout.fillWidth: true
                            label: qsTr("Zoom")
                            property real zoom: 0.5
                            value: zoom
                            valueText: zoom < 0.15 ? qsTr("serré") : (zoom > 0.85 ? qsTr("large") : Math.round(zoom * 100) + "%")
                            fillColor: UISettings.fgLight
                            onMoved: (v) => { zoom = v; programmer.setZoom(v) }
                        }
                    }
                }
            }

            /* programmer / record */
            Panel
            {
                Layout.fillHeight: true
                Layout.preferredWidth: pgRoot.unit * 6.4
                title: qsTr("PROGRAMMEUR")
                hint: programmer.programmerCount > 0 ? qsTr("%1 canaux").arg(programmer.programmerCount) : qsTr("vide")

                ColumnLayout
                {
                    anchors.fill: parent
                    spacing: pgRoot.gap

                    Text
                    {
                        visible: functionManager.isEditing
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: qsTr("Une fonction est ouverte dans Patch & prog : les valeurs partent dedans. Ferme-la pour utiliser le programmeur.")
                        color: UISettings.consoleRelease
                        font.family: UISettings.robotoFontName
                        font.pixelSize: UISettings.textSizeDefault * 0.65
                    }

                    // what the cue will contain
                    Rectangle
                    {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 4
                        color: UISettings.bgStronger
                        border.color: UISettings.borderColorDark

                        Column
                        {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 4

                            Text
                            {
                                width: parent.width
                                wrapMode: Text.Wrap
                                text: programmer.programmerCount > 0
                                      ? qsTr("Valeurs : %1 canaux").arg(programmer.programmerCount)
                                      : qsTr("Choisis un groupe, puis une couleur, une position, un effet…")
                                color: programmer.programmerCount > 0 ? UISettings.fgMain : UISettings.fgMedium
                                font.family: UISettings.robotoFontName
                                font.pixelSize: UISettings.textSizeDefault * 0.7
                            }
                            Repeater
                            {
                                model: programmer.effects
                                Row
                                {
                                    visible: modelData.running
                                    spacing: 6
                                    Rectangle
                                    {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 8; height: 8; radius: 4
                                        color: UISettings.consoleGo
                                    }
                                    Text
                                    {
                                        text: qsTr("Effet : %1").arg(modelData.label)
                                        color: UISettings.fgMain
                                        font.family: UISettings.robotoFontName
                                        font.pixelSize: UISettings.textSizeDefault * 0.7
                                    }
                                }
                            }
                        }
                    }

                    Rectangle
                    {
                        Layout.fillWidth: true
                        Layout.preferredHeight: pgRoot.unit * 0.95
                        radius: 4
                        color: UISettings.bgStronger
                        border.color: cueName.activeFocus ? UISettings.consoleAccent : UISettings.bgControl
                        TextInput
                        {
                            id: cueName
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            color: UISettings.fgMain
                            selectionColor: UISettings.kahoMauveDeep
                            font.family: UISettings.robotoFontName
                            font.pixelSize: UISettings.textSizeDefault * 0.8
                            clip: true
                            maximumLength: 40
                            Keys.onEscapePressed: pgRoot.forceActiveFocus()
                            onAccepted: { programmer.record(text, true); pgRoot.forceActiveFocus() }
                            Text
                            {
                                visible: cueName.text === ""
                                anchors.verticalCenter: parent.verticalCenter
                                text: programmer.nextCueName
                                color: UISettings.bgLighter
                                font: cueName.font
                            }
                        }
                    }

                    ConsoleKey
                    {
                        Layout.fillWidth: true
                        Layout.preferredHeight: pgRoot.unit * 1.5
                        text: qsTr("ENREGISTRER")
                        subText: qsTr("sur le 1er playback libre · Entrée")
                        lit: enabled
                        keyColor: UISettings.consoleRelease
                        fontSize: UISettings.textSizeDefault * 0.85
                        enabled: programmer.programmerCount > 0 || programmer.effects.some(function(e) { return e.running })
                        onClicked: programmer.record(cueName.text, true)
                    }
                    ConsoleKey
                    {
                        Layout.fillWidth: true
                        Layout.preferredHeight: pgRoot.unit * 1.1
                        text: qsTr("ENREGISTRER SUR…")
                        subText: qsTr("choisir l'emplacement · Maj+Entrée")
                        fontSize: UISettings.textSizeDefault * 0.7
                        enabled: programmer.programmerCount > 0 || programmer.effects.some(function(e) { return e.running })
                        onClicked: programmer.record(cueName.text, false)
                    }
                    ConsoleKey
                    {
                        Layout.fillWidth: true
                        Layout.preferredHeight: pgRoot.unit * 1.1
                        text: qsTr("CLEAR")
                        subText: qsTr("vider le programmeur · Ctrl+Retour")
                        textColor: UISettings.consoleRelease
                        fontSize: UISettings.textSizeDefault * 0.7
                        onClicked: programmer.clearProgrammer()
                    }
                    Text
                    {
                        Layout.fillWidth: true
                        visible: pgRoot.lastMessage !== ""
                        text: pgRoot.lastMessage
                        wrapMode: Text.Wrap
                        color: UISettings.consoleGo
                        font.family: UISettings.robotoFontName
                        font.pixelSize: UISettings.textSizeDefault * 0.65
                    }
                }
            }
        }

        /* ---------------- effects */
        Panel
        {
            id: effPanel
            Layout.fillWidth: true
            Layout.preferredHeight: pgRoot.unit * 4.3
            title: qsTr("EFFETS")
            hint: qsTr("un effet par famille · re-cliquer l'arrête · il suit le tempo réglé à droite")
            enabled: pgRoot.hasSelection
            opacity: enabled ? 1 : 0.5

            RowLayout
            {
                anchors.fill: parent
                spacing: pgRoot.gap * 3

                Repeater
                {
                    model: [ { kind: "move", l: qsTr("MOUVEMENT"), c: UISettings.typeEfx },
                             { kind: "colour", l: qsTr("COULEUR"), c: UISettings.typeMatrix },
                             { kind: "dimmer", l: qsTr("INTENSITÉ"), c: UISettings.typeScene } ]
                    ColumnLayout
                    {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Layout.preferredWidth: pgRoot.unit * (modelData.kind === "move" ? 9 : 6)
                        spacing: 3
                        readonly property string kind: modelData.kind
                        readonly property color kindColor: modelData.c
                        Text
                        {
                            text: modelData.l
                            color: modelData.c
                            font.family: UISettings.robotoFontName
                            font.pixelSize: UISettings.textSizeDefault * 0.6
                            font.bold: true
                        }
                        RowLayout
                        {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: pgRoot.gap
                            readonly property string kind: parent.kind
                            readonly property color kindColor: parent.kindColor
                            Repeater
                            {
                                model: programmer.effects.filter(function(e) { return e.kind === parent.kind })
                                ConsoleKey
                                {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    text: modelData.label
                                    fontSize: UISettings.textSizeDefault * 0.62
                                    lit: modelData.running
                                    keyColor: parent.kindColor
                                    onClicked: programmer.toggleEffect(modelData.key)
                                }
                            }
                        }
                    }
                }

                ColumnLayout
                {
                    Layout.fillHeight: true
                    Layout.fillWidth: false
                    Layout.preferredWidth: pgRoot.unit * 7
                    spacing: 2
                    HSlider
                    {
                        Layout.fillWidth: true
                        label: qsTr("Tempo")
                        value: (programmer.effectBpm - 40) / 200
                        valueText: Math.round(programmer.effectBpm) + " BPM"
                        onMoved: (v) => programmer.effectBpm = Math.round(40 + v * 200)
                    }
                    HSlider
                    {
                        Layout.fillWidth: true
                        label: qsTr("Taille")
                        value: programmer.effectSize
                        valueText: Math.round(programmer.effectSize * 100) + "%"
                        onMoved: (v) => programmer.effectSize = v
                    }
                    RowLayout
                    {
                        Layout.fillWidth: true
                        spacing: pgRoot.gap
                        ConsoleKey
                        {
                            Layout.fillWidth: true
                            Layout.preferredHeight: pgRoot.unit * 0.8
                            text: qsTr("½")
                            onClicked: programmer.effectBpm = programmer.effectBpm / 2
                        }
                        ConsoleKey
                        {
                            Layout.fillWidth: true
                            Layout.preferredHeight: pgRoot.unit * 0.8
                            text: qsTr("×2")
                            onClicked: programmer.effectBpm = programmer.effectBpm * 2
                        }
                        ConsoleKey
                        {
                            Layout.fillWidth: true
                            Layout.preferredHeight: pgRoot.unit * 0.8
                            Layout.preferredWidth: 2
                            text: programmer.effectSpread ? qsTr("DÉCALÉ") : qsTr("ENSEMBLE")
                            lit: programmer.effectSpread
                            fontSize: UISettings.textSizeDefault * 0.6
                            onClicked: programmer.effectSpread = !programmer.effectSpread
                        }
                    }
                }
            }
        }
    }
}
