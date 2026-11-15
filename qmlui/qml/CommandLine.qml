/*
  Q Light Controller Plus
  CommandLine.qml

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

/** Console command line, always visible: "Group 1 At 50", "Store Exec 2", "Go 3"... */
Rectangle
{
    id: cmdRoot
    color: UISettings.bgStrong

    property var history: []
    property int historyPos: -1

    function focusInput() { input.forceActiveFocus() }

    function run(text)
    {
        if (text.trim() === "")
            return
        programmer.executeCommand(text)
        history.push(text)
        if (history.length > 40)
            history.shift()
        historyPos = -1
        input.text = ""
    }

    function typeWord(word)
    {
        var t = input.text
        if (t !== "" && t.charAt(t.length - 1) !== " ")
            t += " "
        input.text = t + word + " "
        input.forceActiveFocus()
        input.cursorPosition = input.text.length
    }

    Rectangle { width: parent.width; height: 1; color: UISettings.borderColorDark }

    RowLayout
    {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 6
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        spacing: 6

        // input
        Rectangle
        {
            Layout.fillHeight: true
            Layout.preferredWidth: cmdRoot.width * 0.3
            radius: 5
            color: UISettings.bgStronger
            border.color: input.activeFocus ? UISettings.consoleAccent : UISettings.bgControl

            Text
            {
                id: prompt
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("CMD ›")
                color: UISettings.consoleAccent
                font.family: UISettings.titleFontName
                font.pixelSize: UISettings.textSizeDefault * 0.7
            }
            TextInput
            {
                id: input
                anchors.left: prompt.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 8
                height: parent.height
                verticalAlignment: TextInput.AlignVCenter
                color: UISettings.fgMain
                selectionColor: UISettings.kahoMauveDeep
                font.family: UISettings.robotoFontName
                font.pixelSize: UISettings.textSizeDefault * 0.85
                clip: true
                onAccepted: cmdRoot.run(text)
                Keys.onEscapePressed: { text = ""; focus = false }
                Keys.onUpPressed:
                {
                    if (cmdRoot.history.length === 0)
                        return
                    cmdRoot.historyPos = cmdRoot.historyPos < 0 ? cmdRoot.history.length - 1 : Math.max(0, cmdRoot.historyPos - 1)
                    text = cmdRoot.history[cmdRoot.historyPos]
                }
                Keys.onDownPressed:
                {
                    if (cmdRoot.historyPos < 0)
                        return
                    cmdRoot.historyPos++
                    if (cmdRoot.historyPos >= cmdRoot.history.length) { cmdRoot.historyPos = -1; text = "" }
                    else text = cmdRoot.history[cmdRoot.historyPos]
                }

                Text
                {
                    visible: input.text === "" && !input.activeFocus
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Group 1 At 50 · Store Exec 2 · Help   (F9)")
                    color: UISettings.bgLighter
                    font: input.font
                }
            }
        }

        // feedback of the last command
        Text
        {
            Layout.fillWidth: true
            text: programmer.commandFeedback
            color: programmer.commandFailed ? UISettings.consoleRelease : UISettings.consoleGo
            elide: Text.ElideRight
            font.family: UISettings.robotoFontName
            font.pixelSize: UISettings.textSizeDefault * 0.72

            MouseArea
            {
                anchors.fill: parent
                hoverEnabled: true
                ToolTip.visible: containsMouse && programmer.commandLog.length > 0
                ToolTip.text: programmer.commandLog.slice(-8).join("\n")
            }
        }

        // soft keys
        Row
        {
            Layout.fillHeight: true
            spacing: 3
            Repeater
            {
                model: [ { t: "Group", w: 1.5 }, { t: "Fixture", w: 1.6 }, { t: "Thru", w: 1.3 }, { t: "+", w: 0.9 }, { t: "At", w: 1 },
                         { t: "Full", w: 1.2 }, { t: "Store", w: 1.4 }, { t: "Update", w: 1.6 }, { t: "Go", w: 1 }, { t: "Off", w: 1.1 },
                         { t: "Oops", w: 1.3, always: true }, { t: "Clear", w: 1.4, run: true }, { t: "↵", w: 1, enter: true } ]
                Rectangle
                {
                    width: skText.implicitWidth + UISettings.listItemHeight * 0.7
                    height: parent.height
                    radius: 5
                    readonly property bool danger: modelData.t === "Clear" || modelData.t === "Oops"
                    readonly property bool main: modelData.t === "Store" || modelData.enter === true
                    color: skArea.pressed ? UISettings.bgLight : (skArea.containsMouse ? UISettings.bgControl : UISettings.bgMedium)
                    border.color: main ? UISettings.consoleAccent : UISettings.borderColorDark
                    Text
                    {
                        id: skText
                        anchors.centerIn: parent
                        text: modelData.t.toUpperCase()
                        opacity: modelData.t === "Oops" && programmer.undoText === "" ? 0.35 : 1
                        color: parent.danger ? UISettings.consoleRelease : (parent.main ? UISettings.consoleAccent : UISettings.fgMain)
                        font.family: UISettings.titleFontName
                        font.pixelSize: UISettings.textSizeDefault * 0.62
                        font.letterSpacing: 0.5
                    }
                    MouseArea
                    {
                        id: skArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked:
                        {
                            if (modelData.enter === true)
                                cmdRoot.run(input.text)
                            else if (modelData.always === true)
                                programmer.executeCommand(modelData.t)
                            else if (modelData.run === true && input.text.trim() === "")
                                cmdRoot.run(modelData.t)
                            else
                                cmdRoot.typeWord(modelData.t)
                        }
                    }
                }
            }
        }
    }
}
