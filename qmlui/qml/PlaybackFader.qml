/*
  Q Light Controller Plus
  PlaybackFader.qml

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

import "."

/** Console style vertical fader: a slot, a level bar and a flat cap. */
Item
{
    id: fader

    /** 0.0 - 1.0 */
    property real value: 0
    property color levelColor: UISettings.consoleAccent
    property bool ghost: false          // waiting for the hardware fader to pick up
    property bool active: false

    signal moved(real newValue)

    readonly property real capWidth: Math.min(width * 0.8, UISettings.iconSizeDefault * 1.4)
    readonly property real capHeight: Math.max(12, capWidth * 0.45)
    readonly property real travel: height - capHeight

    Rectangle
    {
        id: slot
        anchors.horizontalCenter: parent.horizontalCenter
        y: fader.capHeight / 2
        width: Math.max(6, Math.min(10, fader.width * 0.16))
        height: fader.travel
        radius: width / 2
        color: UISettings.bgStronger
        border.color: UISettings.borderColorDark

        Rectangle
        {
            anchors.bottom: parent.bottom
            width: parent.width
            height: parent.height * fader.value
            radius: parent.radius
            color: fader.active ? fader.levelColor : Qt.darker(fader.levelColor, 2.2)
        }
    }

    // scale marks
    Repeater
    {
        model: 11
        Rectangle
        {
            x: slot.x + slot.width + 3
            y: slot.y + slot.height * (index / 10)
            width: index % 5 === 0 ? 8 : 4
            height: 1
            color: UISettings.fgMedium
            opacity: 0.6
        }
    }

    Rectangle
    {
        id: cap
        anchors.horizontalCenter: parent.horizontalCenter
        width: fader.capWidth
        height: fader.capHeight
        y: fader.travel * (1 - fader.value)
        radius: 3
        opacity: fader.ghost ? 0.45 : 1.0
        gradient: Gradient
        {
            GradientStop { position: 0.0; color: dragArea.pressed ? "#f2f2f2" : "#d0d0d0" }
            GradientStop { position: 0.48; color: "#7a7a7a" }
            GradientStop { position: 0.5; color: fader.active ? fader.levelColor : "#1a1a1a" }
            GradientStop { position: 0.52; color: "#7a7a7a" }
            GradientStop { position: 1.0; color: "#9a9a9a" }
        }
        border.color: "#111"
    }

    MouseArea
    {
        id: dragArea
        anchors.fill: parent
        preventStealing: true

        function setFromY(y)
        {
            var v = 1.0 - (y - fader.capHeight / 2) / fader.travel
            fader.moved(Math.max(0, Math.min(1, v)))
        }

        onPressed: (mouse) => setFromY(mouse.y)
        onPositionChanged: (mouse) => { if (pressed) setFromY(mouse.y) }
        onDoubleClicked: fader.moved(fader.value > 0 ? 0 : 1)
        onWheel: (wheel) => fader.moved(Math.max(0, Math.min(1, fader.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
