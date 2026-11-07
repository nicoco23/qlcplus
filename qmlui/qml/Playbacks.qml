/*
  Q Light Controller Plus
  Playbacks.qml

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

Rectangle
{
    id: pbRoot
    anchors.fill: parent
    color: UISettings.bgStronger

    property string contextName: "PLAYBACKS"

    readonly property real unit: UISettings.listItemHeight
    readonly property real gap: Math.max(3, unit * 0.12)
    readonly property bool assigning: playbackManager.armedFunction !== 4294967295

    function typeColor(type)
    {
        switch (type)
        {
            case "Scene": return UISettings.typeScene
            case "Chaser":
            case "Sequence": return UISettings.typeChaser
            case "EFX": return UISettings.typeEfx
            case "RGBMatrix": return UISettings.typeMatrix
            case "Collection": return UISettings.typeCollection
            case "": return "transparent"
            default: return UISettings.typeOther
        }
    }

    function typeLabel(type)
    {
        switch (type)
        {
            case "Scene": return qsTr("SCENE")
            case "Chaser": return qsTr("CHASER")
            case "Sequence": return qsTr("SEQ")
            case "EFX": return qsTr("EFX")
            case "RGBMatrix": return qsTr("MATRIX")
            case "Collection": return qsTr("COLL")
            default: return type.toUpperCase()
        }
    }

    /* A flat console key */
    component ConsoleKey: Rectangle
    {
        id: key
        property string text: ""
        property color keyColor: UISettings.bgControl
        property color textColor: UISettings.fgMain
        property bool lit: false
        property alias pressed: keyArea.pressed
        property real fontSize: UISettings.textSizeDefault * 0.85
        signal clicked()
        signal keyPressed()
        signal keyReleased()

        radius: Math.min(8, height * 0.2)
        color: lit ? keyColor : (keyArea.pressed ? Qt.lighter(UISettings.bgControl, 1.3) : UISettings.bgMedium)
        border.color: lit ? Qt.lighter(keyColor, 1.3) : UISettings.borderColorDark
        border.width: 1

        Text
        {
            anchors.centerIn: parent
            text: key.text
            color: key.lit ? UISettings.bgStronger : key.textColor
            font.family: UISettings.titleFontName
            font.pixelSize: key.fontSize
            font.letterSpacing: 1
        }

        MouseArea
        {
            id: keyArea
            anchors.fill: parent
            onClicked: key.clicked()
            onPressed: key.keyPressed()
            onReleased: key.keyReleased()
            onCanceled: key.keyReleased()
        }
    }

    ColumnLayout
    {
        anchors.fill: parent
        anchors.margins: pbRoot.gap
        spacing: pbRoot.gap

        /* ---------------------------------------------------------------- top bar */
        Rectangle
        {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: pbRoot.unit * 1.25
            color: UISettings.bgStrong
            radius: 3

            RowLayout
            {
                anchors.fill: parent
                anchors.margins: pbRoot.gap
                spacing: pbRoot.gap

                Text
                {
                    text: qsTr("PAGE")
                    color: UISettings.fgMedium
                    font.family: UISettings.titleFontName
                    font.pixelSize: UISettings.textSizeDefault * 0.8
                    font.bold: true
                    Layout.rightMargin: pbRoot.gap
                }

                Repeater
                {
                    model: playbackManager.pageCount
                    ConsoleKey
                    {
                        Layout.preferredWidth: pbRoot.unit * 1.6
                        Layout.fillHeight: true
                        text: index + 1
                        lit: playbackManager.page === index
                        keyColor: UISettings.consoleAccent
                        onClicked: playbackManager.page = index

                        // something is running on that page
                        Rectangle
                        {
                            visible: index < playbackManager.pages.length && playbackManager.pages[index].running
                            width: parent.height * 0.22
                            height: width
                            radius: width / 2
                            color: UISettings.consoleGo
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 3
                        }
                        Rectangle
                        {
                            visible: index < playbackManager.pages.length && playbackManager.pages[index].used
                                     && playbackManager.page !== index
                            width: parent.width * 0.5
                            height: 2
                            color: UISettings.fgMedium
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottomMargin: 3
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // assignment hint
                Text
                {
                    visible: pbRoot.assigning
                    text: qsTr("Clique sur un playback ou un bouton pour y placer la fonction · Échap pour annuler")
                    color: UISettings.consoleAccent
                    font.family: UISettings.robotoFontName
                    font.pixelSize: UISettings.textSizeDefault * 0.8
                    elide: Text.ElideRight
                    Layout.maximumWidth: pbRoot.width * 0.35
                }

                // controller status
                Rectangle
                {
                    Layout.fillHeight: true
                    Layout.preferredWidth: ctrlText.implicitWidth + pbRoot.unit * 1.2
                    radius: height / 2
                    color: UISettings.bgMedium
                    border.color: playbackManager.controllerName !== "" ? UISettings.consoleGo : UISettings.borderColorDark

                    Rectangle
                    {
                        id: ctrlDot
                        width: parent.height * 0.3
                        height: width
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.height * 0.35
                        color: playbackManager.controllerName === "" ? UISettings.fgMedium
                               : (playbackManager.controllerFeedback ? UISettings.consoleGo : UISettings.consoleAccent)
                    }
                    Text
                    {
                        id: ctrlText
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: ctrlDot.right
                        anchors.leftMargin: 6
                        text: playbackManager.controllerName === "" ? qsTr("Aucun APC mini")
                              : playbackManager.controllerName + (playbackManager.controllerFeedback ? "" : qsTr(" · LED off"))
                        color: UISettings.fgLight
                        font.family: UISettings.robotoFontName
                        font.pixelSize: UISettings.textSizeDefault * 0.8
                    }
                }

                ConsoleKey
                {
                    Layout.preferredWidth: pbRoot.unit * 4
                    Layout.fillHeight: true
                    text: qsTr("RELEASE ALL")
                    textColor: UISettings.consoleRelease
                    onClicked: playbackManager.releaseAll()
                }
            }
        }

        /* ---------------------------------------------------------------- middle: execute grid + functions */
        RowLayout
        {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: pbRoot.gap

            GridLayout
            {
                id: execGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: playbackManager.execColumns
                rowSpacing: pbRoot.gap
                columnSpacing: pbRoot.gap

                Repeater
                {
                    model: playbackManager.execs

                    Rectangle
                    {
                        id: execCell
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 10
                        Layout.preferredHeight: 10

                        readonly property bool assigned: modelData.funcID !== 4294967295
                        readonly property color tColor: pbRoot.typeColor(modelData.type)

                        radius: 4
                        color: modelData.running ? Qt.darker(tColor, 1.6)
                               : (assigned ? UISettings.bgStrong : Qt.darker(UISettings.bgStrong, 1.25))
                        border.width: modelData.running ? 2 : 1
                        border.color: modelData.running ? tColor
                                      : (execArea.containsMouse && pbRoot.assigning ? UISettings.consoleAccent : UISettings.borderColorDark)

                        // type stripe
                        Rectangle
                        {
                            visible: execCell.assigned
                            width: parent.width
                            height: Math.max(3, parent.height * 0.08)
                            radius: 4
                            color: execCell.tColor
                        }

                        Text
                        {
                            visible: execCell.assigned
                            anchors.fill: parent
                            anchors.margins: 4
                            anchors.topMargin: parent.height * 0.12
                            anchors.bottomMargin: execCell.height > pbRoot.unit * 1.5 ? parent.height * 0.18 : 2
                            text: modelData.label
                            color: modelData.running ? "white" : UISettings.fgLight
                            font.family: UISettings.robotoFontName
                            font.pixelSize: Math.max(9, Math.min(UISettings.textSizeDefault * 0.95, parent.height * 0.3))
                            fontSizeMode: Text.Fit
                            minimumPixelSize: 8
                            font.bold: modelData.running
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text
                        {
                            visible: execCell.assigned && execCell.height > pbRoot.unit * 1.5
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.margins: 3
                            text: modelData.step !== "" ? modelData.step : pbRoot.typeLabel(modelData.type)
                            color: execCell.tColor
                            font.family: UISettings.robotoFontName
                            font.pixelSize: UISettings.textSizeDefault * 0.6
                        }

                        Text
                        {
                            visible: !execCell.assigned
                            anchors.centerIn: parent
                            text: index + 1
                            color: UISettings.bgLight
                            font.family: UISettings.robotoFontName
                            font.pixelSize: UISettings.textSizeDefault * 0.7
                        }

                        MouseArea
                        {
                            id: execArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onPressed: (mouse) =>
                            {
                                if (mouse.button === Qt.RightButton)
                                {
                                    playbackManager.assignExec(index, 4294967295)
                                    return
                                }
                                if (pbRoot.assigning)
                                {
                                    playbackManager.assignExec(index, playbackManager.armedFunction)
                                    playbackManager.armedFunction = 4294967295
                                    return
                                }
                                playbackManager.execPress(index, true)
                            }
                        }
                    }
                }
            }

            /* functions list */
            Rectangle
            {
                Layout.fillHeight: true
                Layout.preferredWidth: Math.min(pbRoot.width * 0.22, pbRoot.unit * 9)
                color: UISettings.bgStrong
                radius: 3

                Rectangle
                {
                    id: fnHeader
                    width: parent.width
                    height: pbRoot.unit
                    color: UISettings.sectionHeader
                    radius: 3
                    Text
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        text: qsTr("Fonctions")
                        color: UISettings.fgMain
                        font.family: UISettings.titleFontName
                        font.pixelSize: UISettings.textSizeDefault * 0.8
                        font.bold: true
                    }
                }

                ListView
                {
                    id: fnList
                    anchors.top: fnHeader.bottom
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 2
                    clip: true
                    model: playbackManager.functionsList
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { }

                    delegate: Rectangle
                    {
                        width: fnList.width
                        height: pbRoot.unit * 0.9
                        readonly property bool armed: playbackManager.armedFunction === modelData.funcID
                        color: armed ? Qt.darker(UISettings.consoleAccent, 1.8) : (fnArea.containsMouse ? UISettings.bgMedium : "transparent")
                        border.color: armed ? UISettings.consoleAccent : "transparent"

                        Rectangle
                        {
                            width: 4
                            height: parent.height - 4
                            anchors.verticalCenter: parent.verticalCenter
                            x: 3
                            color: pbRoot.typeColor(modelData.type)
                        }
                        Text
                        {
                            x: 12
                            width: parent.width - x - typeText.width - 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: UISettings.fgMain
                            elide: Text.ElideRight
                            font.family: UISettings.robotoFontName
                            font.pixelSize: UISettings.textSizeDefault * 0.85
                        }
                        Text
                        {
                            id: typeText
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: pbRoot.typeLabel(modelData.type)
                            color: pbRoot.typeColor(modelData.type)
                            font.family: UISettings.robotoFontName
                            font.pixelSize: UISettings.textSizeDefault * 0.6
                        }
                        MouseArea
                        {
                            id: fnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: playbackManager.armedFunction = parent.armed ? 4294967295 : modelData.funcID
                        }
                    }

                    Text
                    {
                        visible: fnList.count === 0
                        anchors.centerIn: parent
                        width: parent.width - 20
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTr("Aucune fonction. Crée des scènes et des chasers dans « Appareils & fonctions ».")
                        color: UISettings.fgMedium
                        font.family: UISettings.robotoFontName
                        font.pixelSize: UISettings.textSizeDefault * 0.8
                    }
                }
            }
        }

        /* ---------------------------------------------------------------- bottom: playbacks */
        RowLayout
        {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: Math.max(pbRoot.height * 0.5, pbRoot.unit * 9)
            spacing: pbRoot.gap

            Repeater
            {
                model: playbackManager.faders

                Rectangle
                {
                    id: strip
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 10

                    readonly property bool assigned: modelData.funcID !== 4294967295
                    readonly property color tColor: pbRoot.typeColor(modelData.type)

                    radius: 4
                    color: UISettings.bgStrong
                    border.width: 1
                    border.color: stripHeaderArea.containsMouse && pbRoot.assigning ? UISettings.consoleAccent
                                  : (modelData.running ? strip.tColor : UISettings.borderColorDark)

                    ColumnLayout
                    {
                        anchors.fill: parent
                        anchors.margins: pbRoot.gap
                        spacing: pbRoot.gap

                        // header: number, name, type / step
                        Rectangle
                        {
                            Layout.fillWidth: true
                            Layout.preferredHeight: pbRoot.unit * 1.7
                            radius: 3
                            color: modelData.running ? Qt.darker(strip.tColor, 1.7) : UISettings.bgMedium

                            Rectangle
                            {
                                visible: strip.assigned
                                width: parent.width
                                height: 3
                                color: strip.tColor
                            }
                            Text
                            {
                                x: 5; y: 5
                                text: "PB " + (index + 1)
                                color: UISettings.fgMedium
                                font.family: UISettings.robotoFontName
                                font.pixelSize: UISettings.textSizeDefault * 0.6
                                font.bold: true
                            }
                            Text
                            {
                                anchors.right: parent.right
                                anchors.rightMargin: 5
                                y: 5
                                text: modelData.step !== "" ? modelData.step : pbRoot.typeLabel(modelData.type)
                                color: strip.tColor
                                font.family: UISettings.robotoFontName
                                font.pixelSize: UISettings.textSizeDefault * 0.6
                            }
                            Text
                            {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 5
                                text: strip.assigned ? modelData.label : qsTr("— vide —")
                                color: strip.assigned ? UISettings.fgMain : UISettings.bgLight
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                font.family: UISettings.robotoFontName
                                font.pixelSize: UISettings.textSizeDefault * 0.85
                                font.bold: modelData.running
                            }
                            MouseArea
                            {
                                id: stripHeaderArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) =>
                                {
                                    if (mouse.button === Qt.RightButton)
                                        playbackManager.assignFader(index, 4294967295)
                                    else if (pbRoot.assigning)
                                    {
                                        playbackManager.assignFader(index, playbackManager.armedFunction)
                                        playbackManager.armedFunction = 4294967295
                                    }
                                }
                            }
                        }

                        // level readout
                        Text
                        {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData.pickup ? qsTr("REPRISE")
                                  : (modelData.running && modelData.level === 0 ? qsTr("GO · 100%") : Math.round(modelData.level * 100) + "%")
                            color: modelData.pickup ? UISettings.consoleAccent
                                   : (modelData.level > 0 ? UISettings.fgMain : UISettings.fgMedium)
                            font.family: UISettings.robotoFontName
                            font.pixelSize: UISettings.textSizeDefault * 0.8
                            font.bold: true
                        }

                        PlaybackFader
                        {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: pbRoot.unit * 2
                            enabled: strip.assigned
                            value: modelData.level
                            ghost: modelData.pickup
                            active: modelData.running
                            levelColor: strip.assigned ? strip.tColor : UISettings.bgLight
                            onMoved: (v) => playbackManager.setFaderLevel(index, v)
                        }

                        RowLayout
                        {
                            Layout.fillWidth: true
                            Layout.fillHeight: false
                            Layout.preferredHeight: pbRoot.unit * 0.9
                            spacing: pbRoot.gap

                            ConsoleKey
                            {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: "◀"
                                enabled: strip.assigned
                                onClicked: playbackManager.back(index)
                            }
                            ConsoleKey
                            {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: "REL"
                                textColor: UISettings.consoleRelease
                                enabled: strip.assigned
                                onClicked: playbackManager.release(index)
                            }
                        }

                        ConsoleKey
                        {
                            Layout.fillWidth: true
                            Layout.preferredHeight: pbRoot.unit * 1.1
                            text: "GO"
                            lit: modelData.running
                            keyColor: UISettings.consoleGo
                            textColor: UISettings.consoleGo
                            enabled: strip.assigned
                            onClicked: playbackManager.go(index)
                        }

                        ConsoleKey
                        {
                            Layout.fillWidth: true
                            Layout.preferredHeight: pbRoot.unit * 1.1
                            text: "FLASH"
                            lit: modelData.flashing
                            keyColor: UISettings.consoleAccent
                            textColor: UISettings.consoleAccent
                            enabled: strip.assigned
                            onKeyPressed: playbackManager.flash(index, true)
                            onKeyReleased: playbackManager.flash(index, false)
                        }
                    }
                }
            }

            /* grand master */
            Rectangle
            {
                Layout.fillHeight: true
                Layout.preferredWidth: pbRoot.unit * 2.6
                radius: 4
                color: UISettings.bgStrong
                border.color: UISettings.borderColorDark

                ColumnLayout
                {
                    anchors.fill: parent
                    anchors.margins: pbRoot.gap
                    spacing: pbRoot.gap

                    Rectangle
                    {
                        Layout.fillWidth: true
                        Layout.preferredHeight: pbRoot.unit * 1.7
                        radius: 3
                        color: UISettings.bgMedium
                        Text
                        {
                            anchors.centerIn: parent
                            text: qsTr("GRAND\nMASTER")
                            horizontalAlignment: Text.AlignHCenter
                            color: UISettings.consoleRelease
                            font.family: UISettings.titleFontName
                            font.pixelSize: UISettings.textSizeDefault * 0.7
                            font.bold: true
                        }
                    }
                    Text
                    {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Math.round(playbackManager.grandMaster * 100) + "%"
                        color: UISettings.fgMain
                        font.family: UISettings.robotoFontName
                        font.pixelSize: UISettings.textSizeDefault * 0.8
                        font.bold: true
                    }
                    PlaybackFader
                    {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        value: playbackManager.grandMaster
                        active: true
                        levelColor: UISettings.consoleRelease
                        onMoved: (v) => playbackManager.grandMaster = v
                    }
                    ConsoleKey
                    {
                        Layout.fillWidth: true
                        Layout.preferredHeight: pbRoot.unit * 1.1
                        text: "DBO"
                        lit: playbackManager.grandMaster === 0
                        keyColor: UISettings.consoleRelease
                        textColor: UISettings.consoleRelease
                        onClicked: playbackManager.grandMaster = playbackManager.grandMaster > 0 ? 0 : 1
                    }
                }
            }
        }
    }

    focus: true
    Keys.onEscapePressed: playbackManager.armedFunction = 4294967295
}
