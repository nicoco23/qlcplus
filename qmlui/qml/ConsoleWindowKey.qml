/*
  Q Light Controller Plus
  ConsoleWindowKey.qml

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
import QtQuick.Controls.Basic

import "."

/** Big window key of the bottom console bar (one per context). */
Button
{
    id: control

    checkable: true
    hoverEnabled: true
    focusPolicy: Qt.NoFocus     // keep the keyboard on the window (Playbacks shortcuts)
    padding: 0

    property string entryText: ""
    property string keyHint: ""         // keyboard shortcut shown in the corner

    signal rightClicked

    contentItem: Item
    {
        Text
        {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -control.height * 0.04
            width: parent.width - control.height * 0.7
            height: control.height * 0.5
            text: control.entryText.toUpperCase()
            color: control.checked ? UISettings.kahoMauveSoft : UISettings.fgLight
            font.family: UISettings.titleFontName
            font.pixelSize: Math.min(UISettings.textSizeDefault * 0.95, control.height * 0.36)
            font.letterSpacing: 1
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 8
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        Text
        {
            visible: control.keyHint !== ""
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: control.height * 0.14
            anchors.topMargin: control.height * 0.08
            text: control.keyHint
            color: control.checked ? UISettings.kahoMauve : UISettings.bgLighter
            font.family: UISettings.robotoFontName
            font.pixelSize: UISettings.textSizeDefault * 0.55
        }
    }

    background: Rectangle
    {
        radius: height * 0.18
        color: control.checked ? UISettings.kahoMauveDeep
               : (control.pressed ? UISettings.bgControl : (control.hovered ? UISettings.bgMedium : UISettings.bgStrong))
        border.width: control.checked ? 2 : 1
        border.color: control.checked ? UISettings.kahoMauve : UISettings.bgControl

        // lit strip, like a console key LED
        Rectangle
        {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.12
            width: parent.width * 0.3
            height: Math.max(2, parent.height * 0.06)
            radius: height / 2
            color: control.checked ? UISettings.kahoMauve : UISettings.bgControl
        }
    }

    MouseArea
    {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: control.rightClicked()
    }
}
