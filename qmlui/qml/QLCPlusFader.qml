/*
  Q Light Controller Plus
  QLCPlusFader.qml

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
import QtQuick.Controls.Basic

import "."

Slider
{
    id: slider
    width: 32
    height: 100
    orientation: Qt.Vertical
    from: 0
    to: 255
    stepSize: 1.0
    wheelEnabled: true

    property Gradient handleGradient: defaultGradient
    property Gradient handleGradientHover: defaultGradientHover
    property color trackColor: defaultTrackColor
    property real scaleFactor: 1.0

    property color defaultTrackColor: UISettings.kahoMauve
    /* kept for compatibility (Virtual Console sliders set them): the KAHO cap ignores the gradients */
    property Gradient defaultGradient:
        Gradient
        {
            GradientStop { position: 0; color: UISettings.bgControl }
            GradientStop { position: 1; color: UISettings.bgControl }
        }

    property Gradient defaultGradientHover:
        Gradient
        {
            GradientStop { position: 0; color: UISettings.bgLight }
            GradientStop { position: 1; color: UISettings.bgLight }
        }

    /* KAHO console fader: dark slot, level filled from the bottom, flat cap with a lit line */
    background:
        Rectangle
        {
            y: slider.topPadding
            x: slider.leftPadding + slider.availableWidth / 2 - width / 2
            implicitHeight: slider.height
            width: Math.max(5, Math.min(9, slider.availableWidth * 0.18))
            height: slider.availableHeight
            radius: width / 2
            color: UISettings.bgStronger
            border.color: UISettings.borderColorDark

            Rectangle
            {
                anchors.bottom: parent.bottom
                width: parent.width
                height: (1.0 - slider.visualPosition) * parent.height
                radius: parent.radius
                color: slider.trackColor
                opacity: slider.enabled ? 1 : 0.4
            }
        }

    handle:
        Rectangle
        {
            y: slider.topPadding + slider.visualPosition * (slider.availableHeight - height)
            x: slider.leftPadding + slider.availableWidth / 2 - width / 2
            // shrink to fit the available width, up to the default size
            implicitWidth: Math.min(UISettings.iconSizeDefault * slider.scaleFactor, slider.width)
            implicitHeight: implicitWidth * 0.5
            radius: 4
            color: slider.pressed ? UISettings.bgLight : (slider.hovered ? UISettings.bgLight : UISettings.bgControl)
            border.color: slider.pressed ? UISettings.kahoMauve : UISettings.bgLighter
            border.width: 1

            Rectangle
            {
                anchors.centerIn: parent
                width: parent.width * 0.7
                height: Math.max(2, parent.height * 0.12)
                radius: height / 2
                color: slider.pressed ? UISettings.kahoMauve : UISettings.fgLight
            }
        }
}
