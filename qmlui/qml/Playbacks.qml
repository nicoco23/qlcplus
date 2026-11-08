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
    readonly property real noFunction: 4294967295
    readonly property bool assigning: playbackManager.armedFunction !== noFunction

    /* "Déplacer" from the slot menu: next click on a slot of the same kind swaps them */
    property string moveKind: ""        // "", "fader", "exec"
    property int moveFrom: -1
    readonly property bool moving: moveKind !== ""

    /* a function is being dragged from the list */
    property bool dragging: false

    /* playbacks flashed from the keyboard (Alt + digit) */
    property var flashKeys: ({})

    readonly property bool targeting: assigning || dragging

    readonly property var swatchColors: [ "#a98bff", "#6b9bff", "#5ad1e6", "#5fd39a",
                                     "#ffe066", "#ffb86b", "#ff6b7a", "#ff7ad9", "#e8e6f0" ]

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

    function slotColor(data)
    {
        return data.color !== undefined && data.color !== "" ? data.color : typeColor(data.type)
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

    function cancelModes()
    {
        playbackManager.armedFunction = noFunction
        moveKind = ""
        moveFrom = -1
    }

    /** Common click handling of a slot when a mode is active. Returns true if consumed. */
    function slotModeClick(kind, index)
    {
        if (assigning)
        {
            if (kind === "fader")
                playbackManager.assignFader(index, playbackManager.armedFunction)
            else
                playbackManager.assignExec(index, playbackManager.armedFunction)
            playbackManager.armedFunction = noFunction
            return true
        }
        if (moving)
        {
            if (kind === moveKind)
            {
                if (kind === "fader")
                    playbackManager.moveFader(moveFrom, index)
                else
                    playbackManager.moveExec(moveFrom, index)
            }
            moveKind = ""
            moveFrom = -1
            return true
        }
        return false
    }

    /** Digit 1-9 of a key event, whatever the keyboard layout (AZERTY gives "&é\"'..." without Shift) */
    function digitOf(event)
    {
        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9)
            return event.key - Qt.Key_1 + 1
        var sc = event.nativeScanCode
        if (Qt.platform.os === "windows" && sc >= 2 && sc <= 10)
            return sc - 1
        if (Qt.platform.os === "linux" && sc >= 10 && sc <= 18)
            return sc - 9
        return 0
    }

    focus: true
    // keyboard shortcuts work as soon as the window is shown, without a first click
    Component.onCompleted: Qt.callLater(forceActiveFocus)
    onVisibleChanged: if (visible) Qt.callLater(forceActiveFocus)

    Keys.onPressed: (event) =>
    {
        if (event.key === Qt.Key_Escape)
        {
            cancelModes()
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown)
        {
            playbackManager.page = playbackManager.page + (event.key === Qt.Key_PageUp ? -1 : 1)
            event.accepted = true
            return
        }
        var n = digitOf(event)
        if (n >= 1 && n <= playbackManager.faderCount)
        {
            if (event.modifiers & Qt.ControlModifier)
                playbackManager.release(n - 1)
            else if (event.modifiers & Qt.AltModifier)
            {
                if (!event.isAutoRepeat && !flashKeys[n])
                {
                    flashKeys[n] = true
                    playbackManager.flash(n - 1, true)
                }
            }
            else
                playbackManager.go(n - 1)
            event.accepted = true
        }
    }
    Keys.onReleased: (event) =>
    {
        var n = digitOf(event)
        if (n >= 1 && !event.isAutoRepeat && flashKeys[n])
        {
            delete flashKeys[n]
            playbackManager.flash(n - 1, false)
            event.accepted = true
        }
    }

    /* A flat console key */
    component ConsoleKey: Rectangle
    {
        id: key
        property string text: ""
        property string hint: ""
        property color keyColor: UISettings.bgControl
        property color textColor: UISettings.fgMain
        property bool lit: false
        property alias pressed: keyArea.pressed
        property real fontSize: UISettings.textSizeDefault * 0.85
        signal clicked()
        signal keyPressed()
        signal keyReleased()

        radius: Math.min(8, height * 0.2)
        color: lit ? keyColor : (keyArea.pressed ? Qt.lighter(UISettings.bgControl, 1.3)
                                                 : (keyArea.containsMouse && enabled ? UISettings.bgControl : UISettings.bgMedium))
        border.color: lit ? Qt.lighter(keyColor, 1.3) : UISettings.borderColorDark
        border.width: 1
        opacity: enabled ? 1 : 0.45

        Behavior on color { ColorAnimation { duration: 80 } }

        Text
        {
            anchors.centerIn: parent
            text: key.text
            color: key.lit ? UISettings.bgStronger : key.textColor
            font.family: UISettings.titleFontName
            font.pixelSize: key.fontSize
            font.letterSpacing: 1
        }
        Text
        {
            visible: key.hint !== "" && key.height > 18
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 3
            text: key.hint
            color: key.lit ? Qt.darker(key.keyColor, 2) : UISettings.bgLighter
            font.family: UISettings.robotoFontName
            font.pixelSize: UISettings.textSizeDefault * 0.5
        }

        MouseArea
        {
            id: keyArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: { pbRoot.forceActiveFocus(); key.clicked() }
            onPressed: key.keyPressed()
            onReleased: key.keyReleased()
            onCanceled: key.keyReleased()
        }
    }

    /* Pulsing outline drawn on the slots that can receive what is being placed */
    component TargetOutline: Rectangle
    {
        id: outline
        property bool show: false
        property bool hot: false
        anchors.fill: parent
        anchors.margins: -1
        radius: 5
        color: hot ? Qt.rgba(UISettings.consoleAccent.r, UISettings.consoleAccent.g, UISettings.consoleAccent.b, 0.18) : "transparent"
        border.width: hot ? 2 : 1
        border.color: UISettings.consoleAccent
        visible: show
        opacity: hot ? 1 : pulse.value

        QtObject { id: pulse; property real value: 0.9 }
        SequentialAnimation
        {
            running: outline.visible && !outline.hot
            loops: Animation.Infinite
            NumberAnimation { target: pulse; property: "value"; to: 0.25; duration: 650; easing.type: Easing.InOutSine }
            NumberAnimation { target: pulse; property: "value"; to: 0.9; duration: 650; easing.type: Easing.InOutSine }
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
            Layout.preferredHeight: pbRoot.unit * 1.35
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
                    delegate: Rectangle
                    {
                        id: pageKey
                        readonly property var info: index < playbackManager.pages.length ? playbackManager.pages[index] : ({})
                        readonly property bool current: playbackManager.page === index
                        readonly property string pageName: info.name !== undefined ? info.name : ""

                        Layout.fillHeight: true
                        Layout.preferredWidth: pageName !== "" ? Math.max(pbRoot.unit * 2.2, pageNameText.implicitWidth + pbRoot.unit * 1.3)
                                                               : pbRoot.unit * 1.6
                        radius: Math.min(8, height * 0.2)
                        color: current ? UISettings.consoleAccent
                                       : (pageArea.containsMouse ? UISettings.bgControl : UISettings.bgMedium)
                        border.color: current ? Qt.lighter(UISettings.consoleAccent, 1.3) : UISettings.borderColorDark

                        Row
                        {
                            anchors.centerIn: parent
                            spacing: 6
                            Text
                            {
                                anchors.verticalCenter: parent.verticalCenter
                                text: index + 1
                                color: pageKey.current ? UISettings.bgStronger : UISettings.fgMain
                                font.family: UISettings.titleFontName
                                font.pixelSize: UISettings.textSizeDefault * 0.85
                            }
                            Text
                            {
                                id: pageNameText
                                visible: pageKey.pageName !== ""
                                anchors.verticalCenter: parent.verticalCenter
                                text: pageKey.pageName
                                color: pageKey.current ? UISettings.bgStronger : UISettings.fgLight
                                font.family: UISettings.robotoFontName
                                font.pixelSize: UISettings.textSizeDefault * 0.75
                            }
                        }

                        // something is running on that page
                        Rectangle
                        {
                            visible: pageKey.info.running === true
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
                            visible: pageKey.info.used === true && !pageKey.current
                            width: parent.width * 0.5
                            height: 2
                            color: UISettings.fgMedium
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottomMargin: 3
                        }

                        MouseArea
                        {
                            id: pageArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) =>
                            {
                                pbRoot.forceActiveFocus()
                                if (mouse.button === Qt.RightButton)
                                    slotMenu.openFor("page", index, pageKey.pageName, "", "", false, pageKey)
                                else
                                    playbackManager.page = index
                            }
                            onDoubleClicked: slotMenu.openFor("page", index, pageKey.pageName, "", "", false, pageKey)
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // mode hint / shortcuts
                Text
                {
                    Layout.maximumWidth: pbRoot.width * 0.38
                    text: pbRoot.assigning ? qsTr("Clique sur un playback ou un bouton pour y placer la fonction · Échap pour annuler")
                          : pbRoot.moving ? qsTr("Clique sur l'emplacement de destination · Échap pour annuler")
                          : qsTr("1-8 GO · Ctrl+1-8 REL · Alt+1-8 FLASH · Pg↑/Pg↓ pages · clic droit = options")
                    color: (pbRoot.assigning || pbRoot.moving) ? UISettings.consoleAccent : UISettings.bgLighter
                    font.family: UISettings.robotoFontName
                    font.pixelSize: UISettings.textSizeDefault * 0.75
                    elide: Text.ElideRight
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

                        readonly property bool assigned: modelData.funcID !== pbRoot.noFunction
                        readonly property color tColor: pbRoot.slotColor(modelData)
                        readonly property bool big: height > pbRoot.unit * 1.5

                        radius: 4
                        color: modelData.running ? tColor
                               : (assigned ? (execArea.containsMouse ? UISettings.bgMedium : UISettings.bgStrong)
                                           : Qt.darker(UISettings.bgStrong, 1.25))
                        border.width: 1
                        border.color: modelData.running ? Qt.lighter(tColor, 1.25)
                                      : (pbRoot.moving && pbRoot.moveKind === "exec" && pbRoot.moveFrom === index ? UISettings.consoleAccent
                                                                                                                     : UISettings.borderColorDark)

                        Behavior on color { ColorAnimation { duration: 90 } }

                        // glow around a running button
                        Rectangle
                        {
                            visible: modelData.running
                            anchors.fill: parent
                            anchors.margins: -3
                            z: -1
                            radius: 6
                            color: "transparent"
                            border.width: 3
                            border.color: execCell.tColor
                            opacity: 0.35
                        }

                        // color stripe
                        Rectangle
                        {
                            visible: execCell.assigned && !modelData.running
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
                            anchors.bottomMargin: execCell.big ? parent.height * 0.2 : 2
                            text: modelData.label
                            color: modelData.running ? UISettings.bgStronger : UISettings.fgLight
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

                        // flash mode badge
                        Rectangle
                        {
                            visible: execCell.assigned && modelData.flashMode === true && execCell.big
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.margins: 3
                            width: flashBadge.implicitWidth + 6
                            height: flashBadge.implicitHeight + 2
                            radius: 2
                            color: modelData.running ? Qt.darker(execCell.tColor, 1.6) : UISettings.bgControl
                            Text
                            {
                                id: flashBadge
                                anchors.centerIn: parent
                                text: qsTr("FLASH")
                                color: modelData.running ? "white" : UISettings.consoleAccent
                                font.family: UISettings.robotoFontName
                                font.pixelSize: UISettings.textSizeDefault * 0.5
                                font.bold: true
                            }
                        }

                        Text
                        {
                            visible: execCell.assigned && execCell.big
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.margins: 3
                            text: modelData.step !== "" ? modelData.step : pbRoot.typeLabel(modelData.type)
                            color: modelData.running ? Qt.darker(execCell.tColor, 2.2) : execCell.tColor
                            font.family: UISettings.robotoFontName
                            font.pixelSize: UISettings.textSizeDefault * 0.6
                        }

                        Text
                        {
                            visible: !execCell.assigned
                            anchors.centerIn: parent
                            readonly property bool plus: pbRoot.targeting || pbRoot.moveKind === "exec"
                            text: plus ? "+" : index + 1
                            color: plus ? UISettings.consoleAccent : UISettings.bgControl
                            font.family: UISettings.robotoFontName
                            font.pixelSize: UISettings.textSizeDefault * (plus ? 1.1 : 0.7)
                        }

                        TargetOutline
                        {
                            show: (pbRoot.targeting && (execArea.containsMouse || execDrop.containsDrag))
                                  || (pbRoot.moving && pbRoot.moveKind === "exec" && pbRoot.moveFrom !== index && execArea.containsMouse)
                            hot: execDrop.containsDrag || (execArea.containsMouse && (pbRoot.assigning || pbRoot.moving))
                        }

                        DropArea
                        {
                            id: execDrop
                            anchors.fill: parent
                            keys: [ "kaho-function" ]
                            onDropped: (drop) =>
                            {
                                playbackManager.assignExec(index, drop.source.funcID)
                                drop.accept()
                            }
                        }

                        MouseArea
                        {
                            id: execArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onPressed: (mouse) =>
                            {
                                pbRoot.forceActiveFocus()
                                if (mouse.button === Qt.RightButton)
                                {
                                    if (execCell.assigned)
                                        slotMenu.openFor("exec", index, modelData.label, modelData.name,
                                                         modelData.color, modelData.flashMode === true, execCell)
                                    return
                                }
                                if (pbRoot.slotModeClick("exec", index))
                                    return
                                playbackManager.execPress(index, true)
                            }
                            onReleased: (mouse) =>
                            {
                                if (mouse.button === Qt.LeftButton)
                                    playbackManager.execPress(index, false)
                            }
                            onCanceled: playbackManager.execPress(index, false)
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

                property string filterType: ""

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
                    Text
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        text: fnList.count + (fnList.count === playbackManager.functionsList.length ? "" : " / " + playbackManager.functionsList.length)
                        color: UISettings.fgMedium
                        font.family: UISettings.robotoFontName
                        font.pixelSize: UISettings.textSizeDefault * 0.65
                    }
                }

                // search
                Rectangle
                {
                    id: searchBox
                    anchors.top: fnHeader.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 4
                    height: pbRoot.unit * 0.85
                    radius: height / 2
                    color: UISettings.bgStronger
                    border.color: searchInput.activeFocus ? UISettings.consoleAccent : UISettings.bgControl

                    TextInput
                    {
                        id: searchInput
                        anchors.fill: parent
                        anchors.leftMargin: parent.height * 0.5
                        anchors.rightMargin: parent.height * 0.9
                        verticalAlignment: TextInput.AlignVCenter
                        color: UISettings.fgMain
                        selectionColor: UISettings.kahoMauveDeep
                        font.family: UISettings.robotoFontName
                        font.pixelSize: UISettings.textSizeDefault * 0.8
                        clip: true
                        Keys.onEscapePressed: { text = ""; pbRoot.forceActiveFocus() }
                        Keys.onReturnPressed:
                        {
                            if (fnList.count > 0)
                                playbackManager.armedFunction = fnList.itemAtIndex(0) ? fnList.itemAtIndex(0).funcID : pbRoot.noFunction
                            pbRoot.forceActiveFocus()
                        }

                        Text
                        {
                            visible: searchInput.text === "" && !searchInput.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Rechercher…")
                            color: UISettings.bgLighter
                            font: searchInput.font
                        }
                    }
                    Text
                    {
                        visible: searchInput.text !== ""
                        anchors.right: parent.right
                        anchors.rightMargin: parent.height * 0.35
                        anchors.verticalCenter: parent.verticalCenter
                        text: "×"
                        color: UISettings.fgMedium
                        font.pixelSize: parent.height * 0.6
                        MouseArea
                        {
                            anchors.fill: parent
                            anchors.margins: -4
                            onClicked: { searchInput.text = ""; pbRoot.forceActiveFocus() }
                        }
                    }
                }

                // type filter
                Flow
                {
                    id: typeChips
                    anchors.top: searchBox.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 4
                    spacing: 4

                    Repeater
                    {
                        model: [ { t: "", l: qsTr("TOUT") }, { t: "Scene", l: qsTr("SCÈNE") }, { t: "Chaser", l: qsTr("CHASER") },
                                 { t: "EFX", l: qsTr("EFX") }, { t: "RGBMatrix", l: qsTr("MATRIX") } ]
                        delegate: Rectangle
                        {
                            readonly property bool on: typeChips.parent.filterType === modelData.t
                            width: chipText.implicitWidth + 12
                            height: pbRoot.unit * 0.6
                            radius: height / 2
                            color: on ? (modelData.t === "" ? UISettings.consoleAccent : pbRoot.typeColor(modelData.t)) : "transparent"
                            border.color: modelData.t === "" ? UISettings.consoleAccent : pbRoot.typeColor(modelData.t)
                            opacity: on ? 1 : 0.75
                            Text
                            {
                                id: chipText
                                anchors.centerIn: parent
                                text: modelData.l
                                color: parent.on ? UISettings.bgStronger
                                                 : (modelData.t === "" ? UISettings.consoleAccent : pbRoot.typeColor(modelData.t))
                                font.family: UISettings.robotoFontName
                                font.pixelSize: UISettings.textSizeDefault * 0.55
                                font.bold: true
                            }
                            MouseArea
                            {
                                anchors.fill: parent
                                onClicked: typeChips.parent.filterType = modelData.t
                            }
                        }
                    }
                }

                ListView
                {
                    id: fnList
                    anchors.top: typeChips.bottom
                    anchors.topMargin: 4
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 2
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { }

                    model:
                    {
                        var all = playbackManager.functionsList
                        var q = searchInput.text.toLowerCase()
                        var t = parent.filterType
                        var out = []
                        for (var i = 0; i < all.length; i++)
                        {
                            var f = all[i]
                            if (t !== "" && f.type !== t && !(t === "Chaser" && f.type === "Sequence"))
                                continue
                            if (q !== "" && f.label.toLowerCase().indexOf(q) < 0)
                                continue
                            out.push(f)
                        }
                        return out
                    }

                    delegate: Item
                    {
                        id: fnItem
                        width: fnList.width
                        height: pbRoot.unit * 0.9

                        readonly property int funcID: modelData.funcID
                        readonly property bool armed: playbackManager.armedFunction === modelData.funcID

                        Rectangle
                        {
                            id: fnRow
                            anchors.fill: parent
                            color: fnItem.armed ? Qt.darker(UISettings.consoleAccent, 1.8) : (fnArea.containsMouse ? UISettings.bgMedium : "transparent")
                            border.color: fnItem.armed ? UISettings.consoleAccent : "transparent"
                            radius: 2

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
                        }

                        MouseArea
                        {
                            id: fnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: true
                            drag.target: fnDragProxy
                            drag.threshold: 8
                            onPressed: (mouse) =>
                            {
                                var p = fnItem.mapToItem(pbRoot, mouse.x, mouse.y)
                                fnDragProxy.funcID = modelData.funcID
                                fnDragProxy.label = modelData.label
                                fnDragProxy.x = p.x - fnDragProxy.width / 2
                                fnDragProxy.y = p.y - fnDragProxy.height / 2
                            }
                            onClicked: { pbRoot.forceActiveFocus(); playbackManager.armedFunction = fnItem.armed ? pbRoot.noFunction : modelData.funcID }
                            onDoubleClicked:
                            {
                                playbackManager.armedFunction = pbRoot.noFunction
                                playbackManager.assignToFree(modelData.funcID)
                            }
                            onReleased:
                            {
                                if (pbRoot.dragging)
                                    fnDragProxy.Drag.drop()
                                pbRoot.dragging = false
                            }
                            onCanceled: pbRoot.dragging = false
                            drag.onActiveChanged: if (drag.active) pbRoot.dragging = true
                        }
                    }

                    Text
                    {
                        visible: fnList.count === 0
                        anchors.centerIn: parent
                        width: parent.width - 20
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        text: playbackManager.functionsList.length === 0
                              ? qsTr("Aucune fonction. Crée des scènes et des chasers dans « Patch & prog ».")
                              : qsTr("Aucun résultat")
                        color: UISettings.fgMedium
                        font.family: UISettings.robotoFontName
                        font.pixelSize: UISettings.textSizeDefault * 0.8
                    }
                }

                Text
                {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: 4
                    visible: fnList.count > 0 && fnList.contentHeight + pbRoot.unit < fnList.height
                    width: parent.width - 16
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Glisse une fonction sur un playback ou un bouton · double-clic = premier emplacement libre")
                    color: UISettings.bgLighter
                    font.family: UISettings.robotoFontName
                    font.pixelSize: UISettings.textSizeDefault * 0.6
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

                    readonly property bool assigned: modelData.funcID !== pbRoot.noFunction
                    readonly property color tColor: pbRoot.slotColor(modelData)

                    radius: 4
                    color: modelData.running ? Qt.rgba(tColor.r, tColor.g, tColor.b, 0.07) : UISettings.bgStrong
                    border.width: modelData.running ? 2 : 1
                    border.color: modelData.running ? strip.tColor
                                  : (pbRoot.moving && pbRoot.moveKind === "fader" && pbRoot.moveFrom === index ? UISettings.consoleAccent
                                                                                                                 : UISettings.borderColorDark)

                    TargetOutline
                    {
                        show: (pbRoot.targeting && (!strip.assigned || stripHeaderArea.containsMouse || stripDrop.containsDrag))
                              || (pbRoot.moving && pbRoot.moveKind === "fader" && pbRoot.moveFrom !== index)
                        hot: stripDrop.containsDrag || (stripHeaderArea.containsMouse && (pbRoot.assigning || pbRoot.moving))
                    }

                    DropArea
                    {
                        id: stripDrop
                        anchors.fill: parent
                        keys: [ "kaho-function" ]
                        onDropped: (drop) =>
                        {
                            playbackManager.assignFader(index, drop.source.funcID)
                            drop.accept()
                        }
                    }

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
                            color: modelData.running ? strip.tColor
                                   : (stripHeaderArea.containsMouse ? UISettings.bgControl : UISettings.bgMedium)

                            Rectangle
                            {
                                visible: strip.assigned && !modelData.running
                                width: parent.width
                                height: 3
                                color: strip.tColor
                            }
                            Text
                            {
                                x: 5; y: 5
                                text: "PB " + (index + 1)
                                color: modelData.running ? Qt.darker(strip.tColor, 2.4) : UISettings.fgMedium
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
                                color: modelData.running ? Qt.darker(strip.tColor, 2.4) : strip.tColor
                                font.family: UISettings.robotoFontName
                                font.pixelSize: UISettings.textSizeDefault * 0.6
                                font.bold: modelData.step !== ""
                            }
                            Text
                            {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 5
                                text: strip.assigned ? modelData.label : (pbRoot.targeting ? qsTr("+ déposer ici") : qsTr("— vide —"))
                                color: modelData.running ? UISettings.bgStronger
                                       : (strip.assigned ? UISettings.fgMain : (pbRoot.targeting ? UISettings.consoleAccent : UISettings.bgLight))
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
                                    pbRoot.forceActiveFocus()
                                    if (mouse.button === Qt.RightButton)
                                    {
                                        if (strip.assigned)
                                            slotMenu.openFor("fader", index, modelData.label, modelData.name,
                                                             modelData.color, false, strip)
                                        return
                                    }
                                    pbRoot.slotModeClick("fader", index)
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
                                   : (modelData.level > 0 || modelData.running ? UISettings.fgMain : UISettings.fgMedium)
                            font.family: UISettings.titleFontName
                            font.pixelSize: UISettings.textSizeDefault * 0.95
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
                            hint: index + 1
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
                border.color: playbackManager.grandMaster < 0.995 ? UISettings.consoleRelease : UISettings.borderColorDark

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
                        color: playbackManager.grandMaster < 0.995 ? UISettings.consoleRelease : UISettings.fgMain
                        font.family: UISettings.titleFontName
                        font.pixelSize: UISettings.textSizeDefault * 0.95
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

    /* what follows the mouse while a function is dragged from the list */
    Rectangle
    {
        id: fnDragProxy
        property int funcID: -1
        property string label: ""
        visible: pbRoot.dragging
        z: 100
        width: pbRoot.unit * 6
        height: pbRoot.unit * 0.9
        radius: 4
        color: UISettings.kahoMauveDeep
        border.color: UISettings.consoleAccent
        opacity: 0.92

        Drag.active: pbRoot.dragging
        Drag.keys: [ "kaho-function" ]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        Text
        {
            anchors.centerIn: parent
            width: parent.width - 12
            text: fnDragProxy.label
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            color: UISettings.fgMain
            font.family: UISettings.robotoFontName
            font.pixelSize: UISettings.textSizeDefault * 0.85
            font.bold: true
        }
    }

    /* ---------------------------------------------------------------- slot / page options */
    Popup
    {
        id: slotMenu
        parent: pbRoot
        modal: true
        dim: false
        padding: pbRoot.unit * 0.4
        width: pbRoot.unit * 11
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property string kind: ""       // "fader", "exec", "page"
        property int index: -1
        property string funcName: ""
        property string curColor: ""
        property bool flashMode: false

        function openFor(k, i, label, name, color, flash, anchorItem)
        {
            kind = k
            index = i
            funcName = name
            curColor = color
            flashMode = flash
            nameField.text = (k !== "page" && label === name) ? "" : label
            var p = anchorItem.mapToItem(pbRoot, anchorItem.width / 2, anchorItem.height / 2)
            x = Math.max(4, Math.min(pbRoot.width - width - 4, p.x - width / 2))
            y = Math.max(4, Math.min(pbRoot.height - implicitHeight - 4, p.y - implicitHeight / 2))
            open()
            nameField.forceActiveFocus()
            nameField.selectAll()
        }

        function applyName()
        {
            if (kind === "fader")
                playbackManager.setFaderLabel(index, nameField.text)
            else if (kind === "exec")
                playbackManager.setExecLabel(index, nameField.text)
            else if (kind === "page")
                playbackManager.setPageName(index, nameField.text)
        }

        function applyColor(c)
        {
            curColor = c
            if (kind === "fader")
                playbackManager.setFaderColor(index, c)
            else if (kind === "exec")
                playbackManager.setExecColor(index, c)
        }

        onClosed: pbRoot.forceActiveFocus()

        background: Rectangle
        {
            color: UISettings.bgMedium
            radius: 8
            border.color: UISettings.consoleAccent
            border.width: 1
        }

        contentItem: ColumnLayout
        {
            spacing: pbRoot.unit * 0.3

            Text
            {
                Layout.fillWidth: true
                text: slotMenu.kind === "page" ? qsTr("PAGE %1").arg(slotMenu.index + 1)
                      : (slotMenu.kind === "fader" ? qsTr("PLAYBACK %1").arg(slotMenu.index + 1) : qsTr("BOUTON %1").arg(slotMenu.index + 1))
                color: UISettings.consoleAccent
                font.family: UISettings.titleFontName
                font.pixelSize: UISettings.textSizeDefault * 0.8
                font.letterSpacing: 1
            }
            Text
            {
                visible: slotMenu.kind !== "page"
                Layout.fillWidth: true
                text: qsTr("Fonction : %1").arg(slotMenu.funcName)
                elide: Text.ElideRight
                color: UISettings.fgMedium
                font.family: UISettings.robotoFontName
                font.pixelSize: UISettings.textSizeDefault * 0.7
            }

            // name
            Rectangle
            {
                Layout.fillWidth: true
                Layout.preferredHeight: pbRoot.unit * 0.95
                radius: 4
                color: UISettings.bgStronger
                border.color: nameField.activeFocus ? UISettings.consoleAccent : UISettings.bgControl

                TextInput
                {
                    id: nameField
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    color: UISettings.fgMain
                    selectionColor: UISettings.kahoMauveDeep
                    font.family: UISettings.robotoFontName
                    font.pixelSize: UISettings.textSizeDefault * 0.85
                    clip: true
                    maximumLength: 40
                    onAccepted: { slotMenu.applyName(); slotMenu.close() }

                    Text
                    {
                        visible: nameField.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: slotMenu.kind === "page" ? qsTr("Nom de la page (ex. Lasers)") : qsTr("Nom affiché (vide = nom de la fonction)")
                        color: UISettings.bgLighter
                        font: nameField.font
                    }
                }
            }

            // colors
            Flow
            {
                visible: slotMenu.kind !== "page"
                Layout.fillWidth: true
                spacing: 5

                Rectangle
                {
                    width: pbRoot.unit * 0.75
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: slotMenu.curColor === "" ? 2 : 1
                    border.color: slotMenu.curColor === "" ? UISettings.fgMain : UISettings.bgLighter
                    Text
                    {
                        anchors.centerIn: parent
                        text: "A"
                        color: UISettings.fgLight
                        font.family: UISettings.titleFontName
                        font.pixelSize: parent.height * 0.45
                    }
                    MouseArea { anchors.fill: parent; onClicked: slotMenu.applyColor("") }
                }
                Repeater
                {
                    model: pbRoot.swatchColors
                    Rectangle
                    {
                        width: pbRoot.unit * 0.75
                        height: width
                        radius: width / 2
                        color: modelData
                        border.width: slotMenu.curColor === modelData ? 3 : 0
                        border.color: UISettings.fgMain
                        MouseArea { anchors.fill: parent; onClicked: slotMenu.applyColor(modelData) }
                    }
                }
            }

            // execute mode
            Rectangle
            {
                visible: slotMenu.kind === "exec"
                Layout.fillWidth: true
                Layout.preferredHeight: pbRoot.unit * 0.95
                radius: 4
                color: UISettings.bgStrong
                Row
                {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 3
                    Repeater
                    {
                        model: [ { f: false, l: qsTr("BASCULE") }, { f: true, l: qsTr("FLASH (maintenu)") } ]
                        Rectangle
                        {
                            width: (parent.width - 3) / 2
                            height: parent.height
                            radius: 3
                            readonly property bool on: slotMenu.flashMode === modelData.f
                            color: on ? UISettings.consoleAccent : "transparent"
                            Text
                            {
                                anchors.centerIn: parent
                                text: modelData.l
                                color: parent.on ? UISettings.bgStronger : UISettings.fgLight
                                font.family: UISettings.robotoFontName
                                font.pixelSize: UISettings.textSizeDefault * 0.7
                                font.bold: parent.on
                            }
                            MouseArea
                            {
                                anchors.fill: parent
                                onClicked:
                                {
                                    slotMenu.flashMode = modelData.f
                                    playbackManager.setExecFlashMode(slotMenu.index, modelData.f)
                                }
                            }
                        }
                    }
                }
            }

            RowLayout
            {
                Layout.fillWidth: true
                spacing: 4

                ConsoleKey
                {
                    visible: slotMenu.kind !== "page"
                    Layout.fillWidth: true
                    Layout.preferredHeight: pbRoot.unit * 0.95
                    text: qsTr("DÉPLACER")
                    fontSize: UISettings.textSizeDefault * 0.7
                    onClicked:
                    {
                        slotMenu.applyName()
                        pbRoot.moveKind = slotMenu.kind
                        pbRoot.moveFrom = slotMenu.index
                        slotMenu.close()
                    }
                }
                ConsoleKey
                {
                    visible: slotMenu.kind !== "page"
                    Layout.fillWidth: true
                    Layout.preferredHeight: pbRoot.unit * 0.95
                    text: qsTr("RETIRER")
                    textColor: UISettings.consoleRelease
                    fontSize: UISettings.textSizeDefault * 0.7
                    onClicked:
                    {
                        if (slotMenu.kind === "fader")
                            playbackManager.assignFader(slotMenu.index, pbRoot.noFunction)
                        else
                            playbackManager.assignExec(slotMenu.index, pbRoot.noFunction)
                        slotMenu.close()
                    }
                }
                ConsoleKey
                {
                    Layout.fillWidth: true
                    Layout.preferredHeight: pbRoot.unit * 0.95
                    text: qsTr("OK")
                    lit: true
                    keyColor: UISettings.consoleAccent
                    fontSize: UISettings.textSizeDefault * 0.7
                    onClicked: { slotMenu.applyName(); slotMenu.close() }
                }
            }
        }
    }
}
