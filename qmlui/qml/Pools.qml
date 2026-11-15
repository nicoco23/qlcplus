/*
  Q Light Controller Plus
  Pools.qml

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

/** Pools screen: groups, presets, effects and sequences as grids of cells, with the fixture and sequence sheets. */
Rectangle
{
    id: plRoot
    anchors.fill: parent
    color: UISettings.bgStronger

    property string contextName: "POOLS"

    readonly property real unit: UISettings.listItemHeight
    readonly property real gap: Math.max(3, unit * 0.1)
    readonly property real cellW: unit * 2.7
    readonly property real cellH: unit * 2.05

    /* "", "store" or "delete": what the next click on a preset cell does */
    property string mode: ""
    property int sheetExec: 0

    readonly property color cGroup: "#5ad1e6"
    readonly property color cColor: "#ff7ad9"
    readonly property color cPosition: "#ffb86b"
    readonly property color cEffect: UISettings.typeEfx
    readonly property color cSequence: UISettings.consoleGo
    readonly property color cMacro: "#9be36b"

    /* Small editor: one line (a name, a time) or a macro (name + commands) */
    function askText(title, value, callback)
    {
        editPopup.title = title
        editPopup.macro = false
        editPopup.callback = callback
        editField.text = value
        editPopup.open()
        editField.forceActiveFocus()
        editField.selectAll()
    }
    function askMacro(index)
    {
        var m = programmer.macros[index]
        editPopup.title = qsTr("Macro %1").arg(index + 1)
        editPopup.macro = true
        editPopup.callback = function(name, commands) { programmer.macroStore(index, name, commands) }
        editField.text = m.used ? m.name : ""
        editField2.text = m.used ? m.commands : ""
        editPopup.open()
        editField.forceActiveFocus()
    }
    function seconds(text)
    {
        var v = parseFloat(String(text).replace(",", "."))
        return isNaN(v) ? -1 : v
    }

    Popup
    {
        id: editPopup
        property string title: ""
        property bool macro: false
        property var callback: null
        parent: plRoot
        anchors.centerIn: parent
        width: plRoot.unit * 14
        modal: true
        focus: true
        padding: 12
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle { color: UISettings.bgMedium; radius: 6; border.color: UISettings.kahoMauve }

        function accept()
        {
            var cb = callback
            close()
            if (cb)
                cb(editField.text, editField2.text)
            plRoot.forceActiveFocus()
        }

        contentItem: Column
        {
            spacing: 8
            Text
            {
                text: editPopup.title
                color: UISettings.kahoMauveSoft
                font.family: UISettings.titleFontName
                font.pixelSize: UISettings.textSizeDefault * 0.8
            }
            Rectangle
            {
                width: parent.width
                height: plRoot.unit
                radius: 4
                color: UISettings.bgStronger
                border.color: editField.activeFocus ? UISettings.consoleAccent : UISettings.bgControl
                TextInput
                {
                    id: editField
                    anchors.fill: parent
                    anchors.margins: 8
                    verticalAlignment: TextInput.AlignVCenter
                    color: UISettings.fgMain
                    selectionColor: UISettings.kahoMauveDeep
                    font.family: UISettings.robotoFontName
                    font.pixelSize: UISettings.textSizeDefault * 0.85
                    clip: true
                    onAccepted: editPopup.macro ? editField2.forceActiveFocus() : editPopup.accept()
                    Text
                    {
                        visible: editPopup.macro && editField.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Nom")
                        color: UISettings.bgLighter
                        font: editField.font
                    }
                }
            }
            Rectangle
            {
                visible: editPopup.macro
                width: parent.width
                height: plRoot.unit
                radius: 4
                color: UISettings.bgStronger
                border.color: editField2.activeFocus ? UISettings.consoleAccent : UISettings.bgControl
                TextInput
                {
                    id: editField2
                    anchors.fill: parent
                    anchors.margins: 8
                    verticalAlignment: TextInput.AlignVCenter
                    color: UISettings.fgMain
                    selectionColor: UISettings.kahoMauveDeep
                    font.family: UISettings.robotoFontName
                    font.pixelSize: UISettings.textSizeDefault * 0.85
                    clip: true
                    onAccepted: editPopup.accept()
                    Text
                    {
                        visible: editField2.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Group 1 At 100; Preset 4.1; Go 2")
                        color: UISettings.bgLighter
                        font: editField2.font
                    }
                }
            }
            Text
            {
                width: parent.width
                wrapMode: Text.WordWrap
                text: editPopup.macro ? qsTr("Commandes de la ligne de commande, séparées par « ; ». Entrée pour valider, Échap pour annuler. Vide = effacer la macro.")
                                      : qsTr("Entrée pour valider · Échap pour annuler")
                color: UISettings.fgMedium
                font.family: UISettings.robotoFontName
                font.pixelSize: UISettings.textSizeDefault * 0.62
            }
        }
    }

    Component.onCompleted: programmer.sheetActive = true
    Component.onDestruction: programmer.sheetActive = false

    focus: true
    Keys.onEscapePressed: mode = ""

    function presetClick(kind, index, used)
    {
        if (mode === "store")
        {
            programmer.memoryStore(kind, index)
            mode = ""
        }
        else if (mode === "delete")
        {
            programmer.memoryClear(kind, index)
            mode = ""
        }
        else if (used)
            programmer.memoryPress(kind, index)
    }

    /* ---------------------------------------------------------------- building blocks */

    /** Title cell of a pool */
    component PoolTitle: Rectangle
    {
        property string text: ""
        property color tint: UISettings.kahoMauve
        width: plRoot.cellW
        height: plRoot.cellH
        radius: 4
        color: Qt.rgba(tint.r, tint.g, tint.b, 0.16)
        border.color: Qt.rgba(tint.r, tint.g, tint.b, 0.55)
        Text
        {
            anchors.fill: parent
            anchors.margins: 5
            text: parent.text
            color: parent.tint
            wrapMode: Text.WordWrap
            fontSizeMode: Text.Fit
            minimumPixelSize: 7
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            font.family: UISettings.titleFontName
            font.pixelSize: UISettings.textSizeDefault * 0.62
        }
    }

    /** One cell of a pool */
    component PoolCell: Rectangle
    {
        id: cell
        property int number: 0
        property string label: ""
        property string sub: ""
        property color tint: UISettings.kahoMauve
        property bool used: true
        property bool active: false
        property bool partial: false
        property color swatch: "transparent"
        property bool armed: false          // a store / delete click is expected here
        signal clicked(var mouse)

        width: plRoot.cellW
        height: plRoot.cellH
        radius: 4
        color: active ? Qt.rgba(tint.r, tint.g, tint.b, 0.3)
                      : (cellArea.containsMouse ? UISettings.bgMedium : (used ? UISettings.bgStrong : Qt.darker(UISettings.bgStrong, 1.25)))
        border.width: active || armed ? 2 : 1
        border.color: armed ? UISettings.consoleRelease
                            : (active ? tint : (partial ? Qt.rgba(tint.r, tint.g, tint.b, 0.6) : UISettings.borderColorDark))

        Rectangle
        {
            visible: cell.used
            width: parent.width - 2
            x: 1; y: 1
            height: 3
            radius: 2
            color: cell.tint
            opacity: cell.active ? 1 : 0.55
        }
        Text
        {
            x: 5; y: 6
            text: cell.number
            color: cell.used ? (cell.active ? cell.tint : UISettings.fgMedium) : UISettings.bgControl
            font.family: UISettings.titleFontName
            font.pixelSize: UISettings.textSizeDefault * 0.55
        }
        Text
        {
            anchors.right: parent.right
            anchors.rightMargin: 5
            y: 6
            text: cell.sub
            color: UISettings.fgMedium
            font.family: UISettings.robotoFontName
            font.pixelSize: UISettings.textSizeDefault * 0.5
        }
        Rectangle
        {
            visible: cell.swatch.a > 0
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.3
            width: parent.width * 0.5
            height: parent.height * 0.3
            radius: 3
            color: cell.swatch
            border.color: Qt.darker(cell.swatch, 1.5)
        }
        Text
        {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 4
            text: cell.label
            color: cell.active ? UISettings.fgMain : UISettings.fgLight
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            font.family: UISettings.robotoFontName
            font.pixelSize: UISettings.textSizeDefault * 0.66
            font.bold: cell.active
        }
        MouseArea
        {
            id: cellArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => { plRoot.forceActiveFocus(); cell.clicked(mouse) }
        }
    }

    component ModeKey: Rectangle
    {
        id: mk
        property string text: ""
        property bool lit: false
        property color keyColor: UISettings.consoleAccent
        signal clicked()
        Layout.fillHeight: true
        Layout.preferredWidth: plRoot.unit * 2.6
        radius: 5
        color: lit ? keyColor : (mkArea.containsMouse ? UISettings.bgControl : UISettings.bgMedium)
        border.color: lit ? Qt.lighter(keyColor, 1.3) : UISettings.borderColorDark
        Text
        {
            anchors.centerIn: parent
            text: mk.text
            color: mk.lit ? UISettings.bgStronger : mk.keyColor
            font.family: UISettings.titleFontName
            font.pixelSize: UISettings.textSizeDefault * 0.68
            font.letterSpacing: 0.5
        }
        MouseArea { id: mkArea; anchors.fill: parent; hoverEnabled: true; onClicked: { plRoot.forceActiveFocus(); mk.clicked() } }
    }

    component SheetHeader: Rectangle
    {
        property string title: ""
        property string hint: ""
        Layout.fillWidth: true
        Layout.preferredHeight: plRoot.unit * 0.8
        color: UISettings.bgStrong
        radius: 4
        Text
        {
            x: 8
            anchors.verticalCenter: parent.verticalCenter
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
            anchors.verticalCenter: parent.verticalCenter
            text: parent.hint
            color: UISettings.fgMedium
            font.family: UISettings.robotoFontName
            font.pixelSize: UISettings.textSizeDefault * 0.6
        }
    }

    /* ---------------------------------------------------------------- layout */

    RowLayout
    {
        anchors.fill: parent
        anchors.margins: plRoot.gap
        spacing: plRoot.gap * 2

        /* ============ pools ============ */
        ColumnLayout
        {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: plRoot.gap

            // mode keys
            RowLayout
            {
                Layout.fillWidth: true
                Layout.preferredHeight: plRoot.unit * 0.95
                Layout.maximumHeight: plRoot.unit * 0.95
                spacing: plRoot.gap

                ModeKey
                {
                    text: qsTr("STORE")
                    keyColor: UISettings.consoleRelease
                    lit: plRoot.mode === "store"
                    onClicked: plRoot.mode = plRoot.mode === "store" ? "" : "store"
                }
                ModeKey
                {
                    text: qsTr("DELETE")
                    keyColor: UISettings.fgLight
                    lit: plRoot.mode === "delete"
                    onClicked: plRoot.mode = plRoot.mode === "delete" ? "" : "delete"
                }
                ModeKey
                {
                    text: qsTr("CLEAR")
                    keyColor: UISettings.consoleRelease
                    onClicked: programmer.executeCommand("Clear")
                }
                ModeKey
                {
                    text: qsTr("LOCATE")
                    keyColor: UISettings.fgLight
                    onClicked: programmer.executeCommand("Locate")
                }
                ModeKey
                {
                    Layout.preferredWidth: plRoot.unit * 2.2
                    text: qsTr("OOPS")
                    keyColor: UISettings.consoleRelease
                    opacity: programmer.undoText === "" ? 0.4 : 1
                    onClicked: programmer.executeCommand("Oops")
                    ToolTip.visible: oopsHover.hovered && programmer.undoText !== ""
                    ToolTip.text: qsTr("Annuler : %1").arg(programmer.undoText)
                    HoverHandler { id: oopsHover }
                }
                ModeKey
                {
                    visible: playbackManager.controllerName !== ""
                    Layout.preferredWidth: plRoot.unit * 3.2
                    text: playbackManager.apcMode === "prog" ? qsTr("APC : PRESETS") : qsTr("APC : EXEC")
                    keyColor: UISettings.consoleGo
                    lit: playbackManager.apcMode === "prog"
                    onClicked: playbackManager.apcMode = playbackManager.apcMode === "prog" ? "exec" : "prog"
                    ToolTip.visible: apcHover.hovered
                    ToolTip.text: qsTr("Pads de l'APC mini : boutons d'exécution, ou groupes (2 rangées), couleurs (2), positions (2) et touches. SHIFT + 1er bouton de scène sur l'APC.")
                    HoverHandler { id: apcHover }
                }
                // show tempo: click to change the source, TAP to beat it in
                ModeKey
                {
                    Layout.preferredWidth: plRoot.unit * 5.2
                    readonly property var order: programmer.linkAvailable ? [ "manual", "console", "link" ] : [ "manual", "console" ]
                    text: Math.round(programmer.effectBpm) + " BPM · "
                          + (programmer.tempoSource === "link" ? qsTr("LINK (%1)").arg(programmer.linkPeers)
                             : (programmer.tempoSource === "console" ? qsTr("CONSOLE") : qsTr("MANUEL")))
                    keyColor: programmer.tempoSource === "manual" ? UISettings.fgLight
                              : (programmer.tempoSource === "link" && programmer.linkPeers === 0 ? UISettings.consoleRelease : UISettings.consoleGo)
                    onClicked: programmer.tempoSource = order[(order.indexOf(programmer.tempoSource) + 1) % order.length]
                }
                ModeKey
                {
                    Layout.preferredWidth: plRoot.unit * 1.8
                    text: qsTr("TAP")
                    onClicked: programmer.tap()
                }
                Text
                {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    elide: Text.ElideRight
                    text: plRoot.mode === "store" ? qsTr("STORE : clique sur une case Couleur, Position ou Macro · Échap pour annuler")
                          : plRoot.mode === "delete" ? qsTr("DELETE : clique sur le preset ou la macro à effacer · Échap pour annuler")
                          : programmer.selectionText
                    color: plRoot.mode !== "" ? UISettings.consoleRelease : UISettings.fgMedium
                    font.family: UISettings.robotoFontName
                    font.pixelSize: UISettings.textSizeDefault * 0.7
                }
            }

            Flickable
            {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: poolColumn.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { }

                Column
                {
                    id: poolColumn
                    width: parent.width
                    spacing: plRoot.gap * 2

                    // ---- groups
                    Flow
                    {
                        width: parent.width
                        spacing: plRoot.gap
                        PoolTitle { text: qsTr("GROUPES"); tint: plRoot.cGroup }
                        Repeater
                        {
                            model: programmer.groups
                            PoolCell
                            {
                                number: index + 1
                                label: modelData.name
                                sub: modelData.count
                                tint: plRoot.cGroup
                                active: modelData.selected
                                partial: modelData.partial
                                onClicked: (mouse) =>
                                {
                                    if (mouse.button === Qt.RightButton)
                                        plRoot.askText(qsTr("Nom du groupe %1").arg(index + 1), modelData.name,
                                                       function(t) { programmer.renameGroup(modelData.id, t) })
                                    else
                                        programmer.selectGroup(modelData.id, (mouse.modifiers & Qt.ShiftModifier) || (mouse.modifiers & Qt.ControlModifier))
                                }
                            }
                        }
                    }

                    // ---- colour presets
                    Flow
                    {
                        width: parent.width
                        spacing: plRoot.gap
                        PoolTitle { text: qsTr("COULEUR\nPreset 4"); tint: plRoot.cColor }
                        Repeater
                        {
                            model: programmer.colorMemories
                            PoolCell
                            {
                                number: index + 1
                                label: modelData.used ? modelData.name : ""
                                tint: plRoot.cColor
                                used: modelData.used
                                sub: modelData.cues > 0 ? qsTr("%1 cue").arg(modelData.cues) : ""
                                swatch: modelData.used ? modelData.color : "transparent"
                                armed: plRoot.mode === "store" || (plRoot.mode === "delete" && modelData.used)
                                onClicked: (mouse) =>
                                {
                                    if (mouse.button === Qt.RightButton)
                                    {
                                        if (modelData.used)
                                            plRoot.askText(qsTr("Nom du preset couleur %1").arg(index + 1), modelData.name,
                                                           function(t) { programmer.memoryRename("color", index, t) })
                                    }
                                    else
                                        plRoot.presetClick("color", index, modelData.used)
                                }
                            }
                        }
                    }

                    // ---- position presets
                    Flow
                    {
                        width: parent.width
                        spacing: plRoot.gap
                        PoolTitle { text: qsTr("POSITION\nPreset 2"); tint: plRoot.cPosition }
                        Repeater
                        {
                            model: programmer.positionMemories
                            PoolCell
                            {
                                number: index + 1
                                label: modelData.used ? modelData.name : ""
                                tint: plRoot.cPosition
                                used: modelData.used
                                sub: modelData.cues > 0 ? qsTr("%1 cue").arg(modelData.cues) : ""
                                armed: plRoot.mode === "store" || (plRoot.mode === "delete" && modelData.used)
                                onClicked: (mouse) =>
                                {
                                    if (mouse.button === Qt.RightButton)
                                    {
                                        if (modelData.used)
                                            plRoot.askText(qsTr("Nom du preset position %1").arg(index + 1), modelData.name,
                                                           function(t) { programmer.memoryRename("position", index, t) })
                                    }
                                    else
                                        plRoot.presetClick("position", index, modelData.used)
                                }
                            }
                        }
                    }

                    // ---- effects
                    Flow
                    {
                        width: parent.width
                        spacing: plRoot.gap
                        PoolTitle { text: qsTr("EFFETS"); tint: plRoot.cEffect }
                        Repeater
                        {
                            model: programmer.effects
                            PoolCell
                            {
                                number: index + 1
                                label: modelData.label
                                sub: modelData.kind === "move" ? qsTr("mvt") : (modelData.kind === "colour" ? qsTr("coul") : qsTr("dim"))
                                tint: modelData.kind === "move" ? UISettings.typeEfx : (modelData.kind === "colour" ? UISettings.typeMatrix : UISettings.typeScene)
                                active: modelData.running
                                partial: modelData.elsewhere
                                onClicked: programmer.toggleEffect(modelData.key)
                            }
                        }
                    }

                    // ---- macros
                    Flow
                    {
                        width: parent.width
                        spacing: plRoot.gap
                        PoolTitle { text: qsTr("MACROS"); tint: plRoot.cMacro }
                        Repeater
                        {
                            model: programmer.macros
                            PoolCell
                            {
                                number: index + 1
                                label: modelData.used ? modelData.name : ""
                                tint: plRoot.cMacro
                                used: modelData.used
                                armed: plRoot.mode === "store" || (plRoot.mode === "delete" && modelData.used)
                                onClicked: (mouse) =>
                                {
                                    if (plRoot.mode === "delete")
                                    {
                                        programmer.macroClear(index)
                                        plRoot.mode = ""
                                    }
                                    else if (mouse.button === Qt.RightButton || plRoot.mode === "store" || !modelData.used)
                                    {
                                        plRoot.mode = ""
                                        plRoot.askMacro(index)
                                    }
                                    else
                                        programmer.macroRun(index)
                                }
                            }
                        }
                    }

                    // ---- sequences (every cue, chaser... of the project)
                    Flow
                    {
                        width: parent.width
                        spacing: plRoot.gap
                        PoolTitle { text: qsTr("SÉQUENCES"); tint: plRoot.cSequence }
                        Repeater
                        {
                            model: playbackManager.functionsList
                            PoolCell
                            {
                                number: index + 1
                                label: modelData.label
                                sub: modelData.type === "Chaser" ? qsTr("pile") : (modelData.type === "Collection" ? qsTr("coll") : modelData.type.toLowerCase())
                                tint: plRoot.cSequence
                                active: playbackManager.runningIds.indexOf(modelData.funcID) >= 0
                                onClicked: (mouse) =>
                                {
                                    if (mouse.button === Qt.RightButton)
                                        plRoot.askText(qsTr("Nom de la séquence"), modelData.label,
                                                       function(t) { playbackManager.renameFunction(modelData.funcID, t) })
                                    else
                                        playbackManager.toggleFunction(modelData.funcID)
                                }
                            }
                        }
                        Text
                        {
                            visible: playbackManager.functionsList.length === 0
                            height: plRoot.cellH
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 8
                            text: qsTr("Aucun cue pour l'instant : règle des machines puis tape « Store Exec 1 ».")
                            color: UISettings.fgMedium
                            font.family: UISettings.robotoFontName
                            font.pixelSize: UISettings.textSizeDefault * 0.7
                        }
                    }
                }
            }
        }

        /* ============ sheets ============ */
        ColumnLayout
        {
            Layout.fillHeight: true
            Layout.fillWidth: false
            Layout.preferredWidth: Math.max(plRoot.unit * 13, plRoot.width * 0.36)
            spacing: plRoot.gap

            SheetHeader
            {
                title: qsTr("FEUILLE DES MACHINES")
                hint: qsTr("rouge = dans le programmeur · Maj+clic pour ajouter")
            }

            // column titles
            Row
            {
                id: fsHead
                Layout.fillWidth: true
                readonly property var cols: [ 0.09, 0.27, 0.2, 0.1, 0.1, 0.1, 0.14 ]
                Repeater
                {
                    model: [ qsTr("N°"), qsTr("Nom"), qsTr("Dim"), qsTr("Coul."), qsTr("Pan"), qsTr("Tilt"), qsTr("Beam") ]
                    Text
                    {
                        width: fsHead.width * fsHead.cols[index]
                        leftPadding: 6
                        text: modelData
                        color: UISettings.fgMedium
                        font.family: UISettings.titleFontName
                        font.pixelSize: UISettings.textSizeDefault * 0.55
                    }
                }
            }

            ListView
            {
                id: fixtureSheet
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: programmer.fixtureSheet
                ScrollBar.vertical: ScrollBar { }

                delegate: Rectangle
                {
                    id: fsRow
                    width: fixtureSheet.width
                    height: plRoot.unit * 0.72
                    color: modelData.selected ? Qt.rgba(UISettings.kahoMauve.r, UISettings.kahoMauve.g, UISettings.kahoMauve.b, 0.22)
                                              : (index % 2 ? UISettings.bgStrong : "transparent")
                    readonly property var cols: fsHead.cols
                    readonly property color progColor: UISettings.consoleRelease

                    Rectangle { visible: modelData.selected; width: 3; height: parent.height; color: UISettings.kahoMauve }

                    Row
                    {
                        anchors.fill: parent
                        Text
                        {
                            width: fsRow.width * fsRow.cols[0]; height: parent.height
                            leftPadding: 8; verticalAlignment: Text.AlignVCenter
                            text: modelData.id + 1
                            color: modelData.selected ? UISettings.kahoMauveSoft : UISettings.fgMedium
                            font.family: UISettings.titleFontName
                            font.pixelSize: UISettings.textSizeDefault * 0.65
                        }
                        Text
                        {
                            width: fsRow.width * fsRow.cols[1]; height: parent.height
                            leftPadding: 6; verticalAlignment: Text.AlignVCenter
                            text: modelData.name
                            elide: Text.ElideRight
                            color: UISettings.fgMain
                            font.family: UISettings.robotoFontName
                            font.pixelSize: UISettings.textSizeDefault * 0.7
                        }
                        Item
                        {
                            width: fsRow.width * fsRow.cols[2]; height: parent.height
                            Rectangle
                            {
                                visible: modelData.dim >= 0
                                x: 6
                                anchors.verticalCenter: parent.verticalCenter
                                width: (parent.width - 12) * 0.5
                                height: 5
                                radius: 2.5
                                color: UISettings.bgControl
                                Rectangle
                                {
                                    width: parent.width * Math.max(0, modelData.dim) / 100
                                    height: parent.height
                                    radius: parent.radius
                                    color: modelData.dimProg ? fsRow.progColor : UISettings.fgLight
                                }
                            }
                            Text
                            {
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.dim >= 0 ? modelData.dim : "–"
                                color: modelData.dimProg ? fsRow.progColor : UISettings.fgLight
                                font.family: UISettings.robotoFontName
                                font.pixelSize: UISettings.textSizeDefault * 0.68
                            }
                        }
                        Item
                        {
                            width: fsRow.width * fsRow.cols[3]; height: parent.height
                            Rectangle
                            {
                                visible: modelData.color !== ""
                                anchors.centerIn: parent
                                width: parent.width * 0.6
                                height: parent.height * 0.55
                                radius: 3
                                color: modelData.color !== "" ? modelData.color : "transparent"
                                border.width: modelData.colorProg ? 2 : 1
                                border.color: modelData.colorProg ? fsRow.progColor : UISettings.bgLight
                            }
                        }
                        Text
                        {
                            width: fsRow.width * fsRow.cols[4]; height: parent.height
                            leftPadding: 6; verticalAlignment: Text.AlignVCenter
                            text: modelData.pan !== "" ? modelData.pan : "–"
                            color: modelData.posProg ? fsRow.progColor : UISettings.fgLight
                            font.family: UISettings.robotoFontName
                            font.pixelSize: UISettings.textSizeDefault * 0.68
                        }
                        Text
                        {
                            width: fsRow.width * fsRow.cols[5]; height: parent.height
                            leftPadding: 6; verticalAlignment: Text.AlignVCenter
                            text: modelData.tilt !== "" ? modelData.tilt : "–"
                            color: modelData.posProg ? fsRow.progColor : UISettings.fgLight
                            font.family: UISettings.robotoFontName
                            font.pixelSize: UISettings.textSizeDefault * 0.68
                        }
                        Text
                        {
                            width: fsRow.width * fsRow.cols[6]; height: parent.height
                            leftPadding: 6; verticalAlignment: Text.AlignVCenter
                            text: modelData.beam !== "" ? modelData.beam : "–"
                            elide: Text.ElideRight
                            color: modelData.beamProg ? fsRow.progColor : UISettings.fgLight
                            font.family: UISettings.robotoFontName
                            font.pixelSize: UISettings.textSizeDefault * 0.68
                        }
                    }
                    MouseArea
                    {
                        anchors.fill: parent
                        onClicked: (mouse) =>
                        {
                            plRoot.forceActiveFocus()
                            programmer.selectFixture(modelData.id, (mouse.modifiers & Qt.ShiftModifier) || (mouse.modifiers & Qt.ControlModifier))
                        }
                    }
                }
            }

            // ---- sequence sheet
            SheetHeader
            {
                title: qsTr("FEUILLE DE SÉQUENCE")
                hint: qsTr("exécuteur %1 · clic sur un temps pour le changer · clic droit : renommer").arg(plRoot.sheetExec + 1)
            }
            Row
            {
                Layout.fillWidth: true
                spacing: 3
                Repeater
                {
                    model: playbackManager.faders
                    Rectangle
                    {
                        width: (parent.width - 3 * 7) / 8
                        height: plRoot.unit * 0.7
                        radius: 4
                        readonly property bool on: plRoot.sheetExec === index
                        color: on ? UISettings.kahoMauve : (modelData.running ? Qt.rgba(UISettings.consoleGo.r, UISettings.consoleGo.g, UISettings.consoleGo.b, 0.2) : UISettings.bgMedium)
                        border.color: modelData.running ? UISettings.consoleGo : UISettings.borderColorDark
                        Text
                        {
                            anchors.centerIn: parent
                            text: index + 1
                            color: parent.on ? UISettings.bgStronger : UISettings.fgLight
                            font.family: UISettings.titleFontName
                            font.pixelSize: UISettings.textSizeDefault * 0.65
                        }
                        MouseArea { anchors.fill: parent; onClicked: plRoot.sheetExec = index }
                    }
                }
            }
            ListView
            {
                id: seqSheet
                Layout.fillWidth: true
                Layout.preferredHeight: plRoot.unit * 4.6
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                // refreshed with the playbacks (running state, current cue)
                model: { playbackManager.faders; playbackManager.cueRevision; return playbackManager.cueList(plRoot.sheetExec) }

                delegate: Rectangle
                {
                    id: cueRow
                    readonly property var cue: modelData
                    readonly property int cueIndex: index
                    width: seqSheet.width
                    height: plRoot.unit * 0.75
                    color: modelData.current ? Qt.rgba(UISettings.consoleGo.r, UISettings.consoleGo.g, UISettings.consoleGo.b, 0.2)
                                             : (index % 2 ? UISettings.bgStrong : "transparent")
                    Rectangle { visible: modelData.current; width: 3; height: parent.height; color: UISettings.consoleGo }
                    Text
                    {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.number
                        color: modelData.current ? UISettings.consoleGo : UISettings.fgMedium
                        font.family: UISettings.titleFontName
                        font.pixelSize: UISettings.textSizeDefault * 0.7
                    }
                    Text
                    {
                        x: plRoot.unit * 1.2
                        width: parent.width - x - plRoot.unit * 6.4
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        elide: Text.ElideRight
                        color: UISettings.fgMain
                        font.family: UISettings.robotoFontName
                        font.pixelSize: UISettings.textSizeDefault * 0.72
                        font.bold: modelData.current
                    }
                    MouseArea
                    {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        onClicked: plRoot.askText(qsTr("Nom du cue %1").arg(modelData.number), modelData.name,
                                                  function(t) { playbackManager.renameCue(plRoot.sheetExec, index, t) })
                    }
                    // fade in, fade out, follow: click to edit
                    Row
                    {
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        height: parent.height
                        spacing: 3
                        Repeater
                        {
                            model: [ { what: "fade", title: qsTr("Fondu d'entrée du cue %1 (secondes)") },
                                     { what: "out", title: qsTr("Fondu de sortie du cue %1 (secondes)") },
                                     { what: "follow", title: qsTr("Cue %1 : secondes avant le cue suivant (vide = attendre GO)") } ]
                            Rectangle
                            {
                                id: tCell
                                readonly property real value: modelData.what === "fade" ? cueRow.cue.fade
                                                              : (modelData.what === "out" ? cueRow.cue.out : cueRow.cue.follow)
                                readonly property bool follows: modelData.what === "follow"
                                visible: !follows || cueRow.cue.stack
                                width: plRoot.unit * 1.9
                                height: parent.height - 6
                                anchors.verticalCenter: parent.verticalCenter
                                radius: 3
                                color: tArea.containsMouse ? UISettings.bgControl : "transparent"
                                border.color: tArea.containsMouse ? UISettings.consoleAccent : UISettings.bgControl
                                Text
                                {
                                    anchors.centerIn: parent
                                    text: tCell.follows ? (tCell.value < 0 ? qsTr("GO") : qsTr("→ %1 s").arg(tCell.value.toFixed(1)))
                                                        : (modelData.what === "fade" ? "↑ " : "↓ ") + tCell.value.toFixed(1)
                                    color: tCell.follows && tCell.value >= 0 ? UISettings.consoleGo
                                           : (tCell.value > 0 ? UISettings.fgMain : UISettings.fgMedium)
                                    font.family: UISettings.robotoFontName
                                    font.pixelSize: UISettings.textSizeDefault * 0.62
                                }
                                MouseArea
                                {
                                    id: tArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: plRoot.askText(modelData.title.arg(cueRow.cue.number),
                                                              tCell.value < 0 ? "" : tCell.value.toFixed(1),
                                                              function(t)
                                                              {
                                                                  var v = plRoot.seconds(t)
                                                                  if (v < 0 && !tCell.follows)
                                                                      return
                                                                  playbackManager.setCueTiming(plRoot.sheetExec, cueRow.cueIndex, modelData.what, v)
                                                              })
                                }
                            }
                        }
                    }
                }

                Text
                {
                    visible: seqSheet.count === 0
                    anchors.centerIn: parent
                    text: qsTr("Exécuteur vide · « Store Exec %1 » y enregistre le programmeur").arg(plRoot.sheetExec + 1)
                    color: UISettings.fgMedium
                    font.family: UISettings.robotoFontName
                    font.pixelSize: UISettings.textSizeDefault * 0.68
                }
            }
        }
    }
}
