/*
  Q Light Controller Plus
  SimpleDesk.qml

  Copyright (c) Massimo Callegari

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
    id: sDeskContainer
    anchors.fill: parent
    color: "transparent"

    property string contextName: "SDESK"
    property bool dmxValues: true
    property real maxValue: 255

    /* KAHO flat key */
    component DeskKey: Rectangle
    {
        id: dk
        property string text: ""
        property color textColor: UISettings.fgMain
        property bool lit: false
        property bool radiusLeft: false
        signal clicked()
        radius: 5
        color: lit ? UISettings.kahoMauve : (dkArea.pressed ? UISettings.bgLight : (dkArea.containsMouse ? UISettings.bgControl : UISettings.bgMedium))
        border.color: lit ? UISettings.kahoMauveSoft : UISettings.borderColorDark
        opacity: enabled ? 1 : 0.4
        Text
        {
            anchors.centerIn: parent
            text: dk.text
            color: dk.lit ? UISettings.bgStronger : dk.textColor
            font.family: UISettings.titleFontName
            font.pixelSize: UISettings.textSizeDefault * 0.65
            font.letterSpacing: 0.5
        }
        MouseArea { id: dkArea; anchors.fill: parent; hoverEnabled: true; onClicked: dk.clicked() }
    }

    ChannelToolLoader
    {
        id: channelToolLoader
        z: 2

        onValueChanged:
            function (fixtureID, channelIndex, value)
            {
                simpleDesk.setValue(fixtureID, channelIndex, value)
            }
    }

    SplitView
    {
        anchors.fill: parent
        orientation: Qt.Vertical
        z: 1

        handle: Rectangle
        {
            implicitHeight: screenPixelDensity * UISettings.scalingFactor * 0.9
            color: SplitHandle.hovered || SplitHandle.pressed ? UISettings.highlight : UISettings.bgControl
        }

        // Top view (faders)
        Rectangle
        {
            SplitView.minimumHeight: sDeskContainer.height * 0.2
            SplitView.preferredHeight: sDeskContainer.height * 0.66
            SplitView.maximumHeight: sDeskContainer.height * 0.85

            color: UISettings.bgStronger

            Rectangle
            {
                id: viewToolbar
                width: parent.width
                height: UISettings.iconSizeDefault * 0.95
                z: 10
                color: UISettings.bgStrong

                Rectangle { width: parent.width; height: 1; anchors.bottom: parent.bottom; color: UISettings.borderColorDark }

                RowLayout
                {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    anchors.topMargin: 5
                    anchors.bottomMargin: 5
                    spacing: 8

                    Text
                    {
                        text: qsTr("UNIVERS")
                        color: UISettings.consoleAccent
                        font.family: UISettings.titleFontName
                        font.pixelSize: UISettings.textSizeDefault * 0.75
                        font.letterSpacing: 1
                    }

                    CustomComboBox
                    {
                        id: viewUniverseCombo
                        Layout.fillHeight: true
                        implicitWidth: UISettings.bigItemHeight * 2
                        padding: 0
                        model: simpleDesk.universesListModel
                        currValue: simpleDesk.universeFilter
                        onValueChanged: (value) => simpleDesk.universeFilter = value
                    }

                    Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: UISettings.bgControl }

                    // channels held by the desk
                    Rectangle
                    {
                        Layout.fillHeight: true
                        Layout.preferredWidth: heldRow.implicitWidth + 20
                        radius: height / 2
                        color: simpleDesk.overrideCount > 0
                               ? Qt.rgba(UISettings.consoleRelease.r, UISettings.consoleRelease.g, UISettings.consoleRelease.b, 0.15)
                               : "transparent"
                        border.color: simpleDesk.overrideCount > 0 ? UISettings.consoleRelease : UISettings.bgControl

                        Row
                        {
                            id: heldRow
                            anchors.centerIn: parent
                            spacing: 6
                            Rectangle
                            {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 8; height: 8; radius: 4
                                color: simpleDesk.overrideCount > 0 ? UISettings.consoleRelease : UISettings.bgLight
                            }
                            Text
                            {
                                text: simpleDesk.overrideCount > 0
                                      ? simpleDesk.overrideCount + (simpleDesk.overrideCount > 1 ? qsTr(" canaux tenus") : qsTr(" canal tenu"))
                                      : qsTr("aucun canal tenu")
                                color: simpleDesk.overrideCount > 0 ? UISettings.consoleRelease : UISettings.fgMedium
                                font.family: UISettings.robotoFontName
                                font.pixelSize: UISettings.textSizeDefault * 0.7
                            }
                        }
                    }

                    DeskKey
                    {
                        Layout.fillHeight: true
                        Layout.preferredWidth: UISettings.bigItemHeight * 1.5
                        text: qsTr("LIBÉRER L'UNIVERS")
                        textColor: UISettings.consoleRelease
                        enabled: simpleDesk.overrideCount > 0
                        onClicked: simpleDesk.resetUniverse(viewUniverseCombo.currentIndex)
                    }

                    Item { Layout.fillWidth: true }

                    Text
                    {
                        text: qsTr("Clic sur l'icône d'un canal : ses réglages · molette sur un fader : réglage fin")
                        color: UISettings.bgLighter
                        font.family: UISettings.robotoFontName
                        font.pixelSize: UISettings.textSizeDefault * 0.6
                        elide: Text.ElideRight
                        Layout.maximumWidth: parent.width * 0.3
                    }

                    // DMX / percentage
                    Row
                    {
                        Layout.fillHeight: true
                        spacing: 0
                        DeskKey
                        {
                            height: parent.height
                            width: UISettings.bigItemHeight * 0.55
                            text: "0-255"
                            lit: dmxValues
                            radiusLeft: true
                            onClicked: { maxValue = 255; dmxValues = true }
                        }
                        DeskKey
                        {
                            height: parent.height
                            width: UISettings.bigItemHeight * 0.45
                            text: "%"
                            lit: !dmxValues
                            onClicked: { dmxValues = false; maxValue = 100 }
                        }
                    }
                }
            }

            // The actual channel list view
            ListView
            {
                id: channelView
                y: viewToolbar.height
                height: parent.height - y
                width: parent.width
                orientation: ListView.Horizontal
                model: simpleDesk.channelList
                boundsBehavior: Flickable.StopAtBounds
                highlightFollowsCurrentItem: false
                currentIndex: -1

                // Set once the saved scroll position has been restored, so that
                // scrolling caused by the restore itself is not saved back
                property bool scrollRestored: false

                // Restore the channel the view was scrolled to before the last
                // context change. Positioning by index is reliable even while the
                // ListView is still laying out its delegates (unlike setting
                // contentX, which gets clamped when contentWidth isn't known yet).
                Component.onCompleted:
                {
                    if (UISettings.simpleDeskScrollIndex > 0)
                        positionViewAtIndex(UISettings.simpleDeskScrollIndex, ListView.Beginning)
                    scrollRestored = true
                }

                // Persist the first visible channel so it can be restored when
                // coming back to the Simple Desk context
                onContentXChanged:
                {
                    if (scrollRestored)
                    {
                        let firstIdx = indexAt(contentX, 0)
                        if (firstIdx >= 0)
                            UISettings.simpleDeskScrollIndex = firstIdx
                    }
                }

                function scrollToItem(chIdx)
                {
                    console.log("[scrollToItem] chIdx: " + chIdx)
                    positionViewAtIndex(chIdx, ListView.Beginning)
                    currentIndex = chIdx
                }

                delegate:
                    Item
                    {
                        id: chRoot
                        implicitWidth: UISettings.iconSizeDefault * 1.05
                        height: channelView.height - sbar.height
                        // the first channel of a fixture draws the fixture name over its neighbours
                        z: isFirst ? 3 : 1

                        property Fixture fixtureObj: model.cRef
                        property int chDisplay: model.chDisplay
                        property bool isOverride: model.isOverride
                        readonly property bool isFirst: fixtureObj !== null && model.chIndex === 0
                        readonly property color chColor: fixtureObj ? simpleDesk.channelColor(fixtureObj.id, model.chIndex) : UISettings.kahoMauve
                        readonly property color bandColor: chDisplay === SimpleDesk.Odd ? UISettings.kahoMauveDeep
                                                         : (chDisplay === SimpleDesk.Even ? "#2a2440" : UISettings.bgMedium)

                        Rectangle
                        {
                            id: card
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: 5
                            color: chRoot.isOverride ? Qt.rgba(UISettings.consoleRelease.r, UISettings.consoleRelease.g, UISettings.consoleRelease.b, 0.12)
                                                     : (chDisplay === SimpleDesk.Odd ? UISettings.bgFixtureOdd
                                                        : (chDisplay === SimpleDesk.Even ? UISettings.bgFixtureEven : UISettings.bgStrong))
                            border.color: chRoot.isOverride ? Qt.rgba(UISettings.consoleRelease.r, UISettings.consoleRelease.g, UISettings.consoleRelease.b, 0.6)
                                                            : UISettings.borderColorDark
                        }

                        ColumnLayout
                        {
                            anchors.fill: parent
                            anchors.margins: 1
                            spacing: 3

                            // fixture band (name on the first channel)
                            Rectangle
                            {
                                Layout.fillWidth: true
                                Layout.preferredHeight: UISettings.listItemHeight * 0.7
                                radius: 5
                                color: chRoot.isOverride ? UISettings.consoleRelease : chRoot.bandColor

                                // square the bottom corners
                                Rectangle { width: parent.width; height: parent.radius; anchors.bottom: parent.bottom; color: parent.color }

                                Text
                                {
                                    visible: chRoot.isFirst
                                    x: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: chRoot.fixtureObj ? chRoot.fixtureObj.channels * chRoot.width - 12 : 0
                                    text: chRoot.fixtureObj ? chRoot.fixtureObj.name : ""
                                    elide: Text.ElideRight
                                    color: chRoot.isOverride ? UISettings.bgStronger : UISettings.kahoMauveSoft
                                    font.family: UISettings.titleFontName
                                    font.pixelSize: UISettings.textSizeDefault * 0.62
                                    font.letterSpacing: 0.5
                                }
                            }

                            // channel type (opens the channel tool)
                            Rectangle
                            {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: chRoot.width * 0.72
                                Layout.preferredHeight: width * 0.8
                                radius: 5
                                visible: chRoot.fixtureObj ? true : false
                                color: iconArea.containsMouse ? UISettings.bgLight : UISettings.bgControl
                                border.color: Qt.darker(chRoot.chColor, 1.4)

                                Image
                                {
                                    anchors.centerIn: parent
                                    width: parent.height * 0.75
                                    height: width
                                    sourceSize: Qt.size(width, height)
                                    source: chRoot.fixtureObj ? fixtureManager.channelIcon(chRoot.fixtureObj.id, model.chIndex) : ""
                                }
                                Rectangle
                                {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottomMargin: 2
                                    width: parent.width * 0.5
                                    height: 2
                                    radius: 1
                                    color: chRoot.chColor
                                }
                                MouseArea
                                {
                                    id: iconArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked:
                                    {
                                        if (chRoot.fixtureObj)
                                            channelToolLoader.loadChannelTool(parent, chRoot.fixtureObj.id, model.chIndex, model.chValue)
                                    }
                                    ToolTip.visible: containsMouse && chRoot.fixtureObj
                                    ToolTip.delay: 400
                                    ToolTip.text: chRoot.fixtureObj ? chRoot.fixtureObj.name + " · " + simpleDesk.channelShortName(chRoot.fixtureObj.id, model.chIndex) : ""
                                }
                            }

                            // channel fader
                            QLCPlusFader
                            {
                                padding: 0
                                Layout.preferredWidth: chRoot.width * 0.9
                                Layout.alignment: Qt.AlignHCenter
                                Layout.fillHeight: true
                                focusPolicy: Qt.NoFocus
                                from: 0
                                to: 255
                                value: model.chValue
                                trackColor: chRoot.chColor
                                onMoved:
                                {
                                    model.isOverride = true
                                    model.chValue = valueAt(position)
                                    simpleDesk.setValue(chRoot.fixtureObj ? chRoot.fixtureObj.id : -1, chRoot.fixtureObj ? model.chIndex : index, model.chValue)
                                }
                            }

                            // channel value
                            CustomSpinBox
                            {
                                id: chValueSpin
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: chRoot.width - 6
                                height: UISettings.listItemHeight * 0.75
                                from: 0
                                to: maxValue
                                suffix: dmxValues ? "" : "%"
                                showControls: false
                                padding: 0
                                horizontalAlignment: Qt.AlignHCenter
                                value: dmxValues ? model.chValue : (model.chValue / 255.0) * 100.0
                                onValueModified:
                                {
                                    model.isOverride = true
                                    model.chValue = value * (dmxValues ? 1.0 : 2.55)
                                    simpleDesk.setValue(chRoot.fixtureObj ? chRoot.fixtureObj.id : -1, chRoot.fixtureObj ? model.chIndex : index, model.chValue)
                                }
                            }

                            // DMX address
                            Text
                            {
                                Layout.alignment: Qt.AlignHCenter
                                text: index + 1
                                color: chRoot.isOverride ? UISettings.consoleRelease : UISettings.fgMedium
                                font.family: UISettings.titleFontName
                                font.pixelSize: UISettings.textSizeDefault * 0.7
                            }

                            // release the channel (only when the desk holds it)
                            Rectangle
                            {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.bottomMargin: 4
                                Layout.preferredWidth: chRoot.width * 0.62
                                Layout.preferredHeight: UISettings.listItemHeight * 0.62
                                radius: height / 2
                                opacity: chRoot.isOverride ? 1 : 0
                                color: relArea.containsMouse ? UISettings.consoleRelease : "transparent"
                                border.color: UISettings.consoleRelease
                                Text
                                {
                                    anchors.centerIn: parent
                                    text: "×"
                                    color: relArea.containsMouse ? UISettings.bgStronger : UISettings.consoleRelease
                                    font.pixelSize: parent.height * 0.8
                                    font.bold: true
                                }
                                MouseArea
                                {
                                    id: relArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: chRoot.isOverride
                                    onClicked:
                                    {
                                        var channel = index - (chRoot.fixtureObj ? chRoot.fixtureObj.address : 0)
                                        simpleDesk.unsetDumpValue(chRoot.fixtureObj ? chRoot.fixtureObj.id : -1, channel)
                                        simpleDesk.resetChannel(index)
                                    }
                                    ToolTip.visible: containsMouse
                                    ToolTip.delay: 400
                                    ToolTip.text: qsTr("Relâcher ce canal")
                                }
                            }
                        }
                    }

                ScrollBar.horizontal:
                    CustomScrollBar {
                        id: sbar
                        orientation: Qt.Horizontal
                    }
            }
        } // Rectangle

        // Bottom view (fixture list, keypad history, keypad)
        Rectangle
        {
            color: "transparent"
            SplitView.fillHeight: true

            Column
            {
                width: parent.width / 2
                height: parent.height

                Rectangle
                {
                    id: fixtureHeader
                    z: 2
                    width: parent.width
                    height: UISettings.listItemHeight * 0.85
                    color: UISettings.bgStrong
                    Text
                    {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Machines").toUpperCase()
                        color: UISettings.consoleAccent
                        font.family: UISettings.titleFontName
                        font.pixelSize: UISettings.textSizeDefault * 0.7
                        font.letterSpacing: 1
                    }
                    Rectangle { width: parent.width; height: 1; anchors.bottom: parent.bottom; color: UISettings.borderColorDark }
                }

                ListView
                {
                    id: fixtureList
                    z: 1
                    height: parent.height - fixtureHeader.height
                    width: parent.width
                    boundsBehavior: Flickable.StopAtBounds
                    model: simpleDesk.fixtureList
                    currentIndex: -1

                    delegate:
                        Rectangle
                        {
                            id: fixtureDelegate
                            width: fixtureList.width
                            height: UISettings.listItemHeight
                            color: fixtureList.currentIndex == index ? UISettings.highlight : "transparent"

                            property Fixture fixtureObj: modelData

                            IconTextEntry
                            {
                                width: parent.width
                                height: UISettings.listItemHeight

                                tLabel: fixtureObj.name
                                iSrc: fixtureObj.iconResource(true)

                                MouseArea
                                {
                                    id: fxiMa
                                    anchors.fill: parent

                                    onClicked:
                                    {
                                        fixtureList.currentIndex = index
                                        channelView.scrollToItem(fixtureObj.address)
                                    }
                                }
                            }

                            RobotoText
                            {
                                x: parent.width - width
                                height: UISettings.listItemHeight
                                rightMargin: 5
                                label: (fixtureObj.address + 1) + " - " + (fixtureObj.address + fixtureObj.channels)
                            }
                        }
                }
            }

            Column
            {
                x: parent.width / 2
                width: parent.width / 2
                height: parent.height

                Rectangle
                {
                    id: historyHeader
                    z: 2
                    width: parent.width - keypad.width
                    height: UISettings.listItemHeight * 0.85
                    color: UISettings.bgStrong
                    Text
                    {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Historique des commandes").toUpperCase()
                        color: UISettings.consoleAccent
                        font.family: UISettings.titleFontName
                        font.pixelSize: UISettings.textSizeDefault * 0.7
                        font.letterSpacing: 1
                    }
                    Rectangle { width: parent.width; height: 1; anchors.bottom: parent.bottom; color: UISettings.borderColorDark }
                }

                ListView
                {
                    id: keypadHistory
                    z: 1
                    height: parent.height - historyHeader.height
                    width: parent.width - keypad.width
                    boundsBehavior: Flickable.StopAtBounds
                    model: simpleDesk.commandHistory

                    delegate:
                        RobotoText
                        {
                            label: modelData
                            width: keypadHistory.width

                            Rectangle
                            {
                                y: parent.height - 1
                                width: parent.width
                                height: 1
                                color: UISettings.bgLight
                            }

                            MouseArea
                            {
                                anchors.fill: parent
                                onDoubleClicked: keypad.commandString = modelData
                            }
                        }

                    Rectangle
                    {
                        width: 2
                        height: parent.height
                        color: UISettings.bgLight
                    }
                }
            }

            KeyPad
            {
                id: keypad
                x: parent.width - width
                height: parent.height

                onExecuteCommand: (cmd) =>
                {
                    simpleDesk.sendKeypadCommand(cmd)
                    keypad.commandString = ""
                }
            }
        }
    }
}
