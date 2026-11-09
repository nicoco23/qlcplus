/*
  Q Light Controller Plus
  IconButton.qml

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

Button
{
    id: control
    visible: counter ? true : false
    height: UISettings.iconSizeDefault
    width: UISettings.iconSizeDefault
    hoverEnabled: true
    padding: 0
    topPadding: 0
    bottomPadding: 0
    leftPadding: 0
    rightPadding: 0

    property int counter: 1
    property color bgColor: UISettings.bgControl
    property color hoverColor: UISettings.bgLight
    property color pressColor: UISettings.highlightPressed
    property color checkedColor: UISettings.highlight

    property alias border: contentBody.border
    property alias radius: contentBody.radius
    property string imgSource: ""
    property int imgMargins: 6
    property string faSource: ""
    property color faColor: UISettings.fgLight

    property string tooltip: ""

    onCounterChanged:
    {
        if (counter == 0 && checkable && checked)
        {
            control.toggle()
            control.toggled()
        }
    }

    Rectangle
    {
        anchors.fill: parent
        color: "black"
        opacity: 0.6
        visible: !parent.enabled
    }

    ToolTip
    {
        visible: tooltip && hovered
        text: tooltip
        delay: 1000
        timeout: 5000
        background:
            Rectangle
            {
                color: UISettings.bgMedium
                border.width: 1
                border.color: UISettings.bgLight
            }
        contentItem:
            Text
            {
              text: tooltip
              color: "white"
          }
    }

    contentItem:
        Rectangle
        {
            color: "transparent"
            Image
            {
                id: btnIcon
                visible: imgSource ? true : false
                anchors.centerIn: parent
                width: Math.min(control.width - imgMargins, control.height - imgMargins)
                height: width
                source: imgSource
                sourceSize: Qt.size(width, height)
            }

            Text
            {
                id: faIcon
                visible: faSource ? true : false
                anchors.centerIn: parent
                // KAHO: a dark glyph on the dark keys would vanish
                color: control.checked ? UISettings.bgStronger
                       : (faColor.hslLightness < 0.3 ? UISettings.fgLight : faColor)
                font.family: UISettings.fontAwesomeFontName
                font.pixelSize: control.height * 0.70
                text: faSource
            }
        }

    background:
        Rectangle
        {
            id: contentBody
            color: bgColor
            radius: 6
            border.color: control.checked ? Qt.lighter(checkedColor, 1.3) : UISettings.borderColorDark
            border.width: 1

            states: [
                State
                {
                    when: checked
                    PropertyChanges
                    {
                        target: contentBody
                        color: checkedColor
                    }
                },
                State
                {
                    when: control.pressed
                    PropertyChanges
                    {
                        target: contentBody
                        color: pressColor
                    }
                },
                State
                {
                    when: hovered
                    PropertyChanges
                    {
                        target: contentBody
                        color: hoverColor
                    }
                }
            ]
        }
}

