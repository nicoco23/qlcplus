/*
  Q Light Controller Plus
  ExecutorBar.qml

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

import "."

/** The playbacks of the current page, always at hand under every window. */
Rectangle
{
    id: exRoot
    color: UISettings.bgStronger

    readonly property real noFunction: 4294967295

    Rectangle { width: parent.width; height: 1; color: UISettings.borderColorDark }

    // plain Row: the playbacks model is replaced at every refresh, which a Layout does not like
    Row
    {
        id: exRow
        anchors.fill: parent
        anchors.margins: 4
        spacing: 4
        readonly property real pageW: UISettings.listItemHeight * 1.9
        readonly property real gmW: UISettings.listItemHeight * 2.4
        readonly property real tileW: (width - pageW - gmW - spacing * 9) / 8

        // page
        Rectangle
        {
            height: parent.height
            width: exRow.pageW
            radius: 5
            color: UISettings.bgStrong
            border.color: UISettings.borderColorDark

            Column
            {
                anchors.centerIn: parent
                spacing: 1
                Text
                {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("PAGE")
                    color: UISettings.fgMedium
                    font.family: UISettings.titleFontName
                    font.pixelSize: UISettings.textSizeDefault * 0.5
                    font.letterSpacing: 1
                }
                Row
                {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    Text
                    {
                        text: "‹"
                        color: pgDown.containsMouse ? UISettings.consoleAccent : UISettings.fgLight
                        font.pixelSize: UISettings.textSizeDefault * 1.1
                        MouseArea { id: pgDown; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: playbackManager.page = playbackManager.page - 1 }
                    }
                    Text
                    {
                        text: playbackManager.page + 1
                        color: UISettings.consoleAccent
                        font.family: UISettings.titleFontName
                        font.pixelSize: UISettings.textSizeDefault * 1.0
                    }
                    Text
                    {
                        text: "›"
                        color: pgUp.containsMouse ? UISettings.consoleAccent : UISettings.fgLight
                        font.pixelSize: UISettings.textSizeDefault * 1.1
                        MouseArea { id: pgUp; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: playbackManager.page = playbackManager.page + 1 }
                    }
                }
            }
        }

        Repeater
        {
            model: playbackManager.faders

            Rectangle
            {
                id: tile
                width: exRow.tileW
                height: exRow.height
                radius: 5

                readonly property bool assigned: modelData.funcID !== exRoot.noFunction
                readonly property color tColor: modelData.color !== undefined && modelData.color !== "" ? modelData.color
                                                : (assigned ? UISettings.kahoMauve : UISettings.bgLight)

                color: modelData.running ? Qt.rgba(tColor.r, tColor.g, tColor.b, 0.16) : UISettings.bgStrong
                border.color: modelData.running ? tColor : UISettings.borderColorDark
                border.width: modelData.running ? 2 : 1
                opacity: assigned ? 1 : 0.55

                // level, drawn as a fill behind the label: drag left/right to set it
                Rectangle
                {
                    visible: tile.assigned
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 2
                    width: (parent.width - 4 - goKey.width - 4) * modelData.level
                    height: 4
                    radius: 2
                    color: tile.tColor
                }

                Text
                {
                    x: 7; y: 4
                    text: index + 1
                    color: modelData.running ? tile.tColor : UISettings.fgMedium
                    font.family: UISettings.titleFontName
                    font.pixelSize: UISettings.textSizeDefault * 0.6
                }
                Text
                {
                    anchors.right: goKey.left
                    anchors.rightMargin: 6
                    y: 4
                    text: modelData.step !== "" ? modelData.step : (tile.assigned ? Math.round(modelData.level * 100) + "%" : "")
                    color: modelData.running ? tile.tColor : UISettings.fgMedium
                    font.family: UISettings.robotoFontName
                    font.pixelSize: UISettings.textSizeDefault * 0.6
                }
                Text
                {
                    anchors.left: parent.left
                    anchors.leftMargin: 7
                    anchors.right: goKey.left
                    anchors.rightMargin: 4
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10
                    text: tile.assigned ? modelData.label : qsTr("vide")
                    color: tile.assigned ? UISettings.fgMain : UISettings.bgLighter
                    elide: Text.ElideRight
                    font.family: UISettings.robotoFontName
                    font.pixelSize: UISettings.textSizeDefault * 0.75
                    font.bold: modelData.running
                }

                MouseArea
                {
                    anchors.left: parent.left
                    anchors.right: goKey.left
                    height: parent.height
                    enabled: tile.assigned
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    preventStealing: true
                    property real startX: 0
                    property bool dragged: false
                    onPressed: (mouse) => { startX = mouse.x; dragged = false }
                    onPositionChanged: (mouse) =>
                    {
                        if (!(mouse.buttons & Qt.LeftButton))
                            return
                        if (Math.abs(mouse.x - startX) > 6)
                            dragged = true
                        if (dragged)
                            playbackManager.setFaderLevel(index, Math.max(0, Math.min(1, mouse.x / width)))
                    }
                    onClicked: (mouse) =>
                    {
                        if (mouse.button === Qt.RightButton)
                            playbackManager.release(index)
                    }
                    ToolTip.visible: false
                }

                Rectangle
                {
                    id: goKey
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 4
                    width: Math.min(parent.width * 0.3, UISettings.listItemHeight * 1.3)
                    radius: 4
                    color: modelData.running ? UISettings.consoleGo : (goArea.containsMouse && tile.assigned ? UISettings.bgControl : UISettings.bgMedium)
                    border.color: modelData.running ? Qt.lighter(UISettings.consoleGo, 1.3) : UISettings.borderColorDark
                    Text
                    {
                        anchors.centerIn: parent
                        text: "GO"
                        color: modelData.running ? UISettings.bgStronger : UISettings.consoleGo
                        font.family: UISettings.titleFontName
                        font.pixelSize: UISettings.textSizeDefault * 0.7
                    }
                    MouseArea
                    {
                        id: goArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: tile.assigned
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (mouse) =>
                        {
                            if (mouse.button === Qt.RightButton)
                                playbackManager.release(index)
                            else
                                playbackManager.go(index)
                        }
                    }
                }
            }
        }

        // grand master
        Rectangle
        {
            height: parent.height
            width: exRow.gmW
            radius: 5
            color: UISettings.bgStrong
            border.color: playbackManager.grandMaster < 0.995 ? UISettings.consoleRelease : UISettings.borderColorDark

            Rectangle
            {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 2
                width: (parent.width - 4) * playbackManager.grandMaster
                height: 4
                radius: 2
                color: UISettings.consoleRelease
            }
            Text
            {
                x: 7; y: 4
                text: "GM"
                color: UISettings.consoleRelease
                font.family: UISettings.titleFontName
                font.pixelSize: UISettings.textSizeDefault * 0.6
            }
            Text
            {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 5
                text: Math.round(playbackManager.grandMaster * 100) + "%"
                color: playbackManager.grandMaster < 0.995 ? UISettings.consoleRelease : UISettings.fgMain
                font.family: UISettings.titleFontName
                font.pixelSize: UISettings.textSizeDefault * 0.85
            }
            MouseArea
            {
                anchors.fill: parent
                preventStealing: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                property bool dragged: false
                property real startX: 0
                onPressed: (mouse) => { startX = mouse.x; dragged = false }
                onPositionChanged: (mouse) =>
                {
                    if (Math.abs(mouse.x - startX) > 6)
                        dragged = true
                    if (dragged)
                        playbackManager.grandMaster = Math.max(0, Math.min(1, mouse.x / width))
                }
                onClicked: (mouse) => { if (mouse.button === Qt.RightButton) playbackManager.grandMaster = 1 }
            }
        }
    }
}
