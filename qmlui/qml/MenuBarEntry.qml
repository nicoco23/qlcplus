/*
  Q Light Controller Plus
  MenuBarEntry.qml

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
import QtQuick.Controls.Basic

import "."

Button
{
    id: control
    //implicitWidth: contentItem.width + 10
    implicitHeight: parent.height

    hoverEnabled: true
    checkable: true
    padding: 0
    topPadding: 0
    bottomPadding: 0

    property string imgSource: ""
    property string faSource: ""
    property color faColor: UISettings.bgStrong
    property string entryText: ""
    property real mFontSize: UISettings.textSizeDefault * 0.70
    /** false = flat console tab: no icon, upper case label, accent color when checked */
    property bool showIcon: true
    property int iconSize: (imgSource && showIcon) ? height - 4 - topPadding - bottomPadding : 0
    property int iconRotation: 0

    property Gradient bgGradient: defBgGradient
    property Gradient selGradient: defSelectionGradient
    property Gradient pressedGradient: defPressedGradient
    property color checkedColor: UISettings.toolbarSelectionMain

    signal rightClicked

    Gradient
    {
        id: defBgGradient
        GradientStop { position: 0; color: "transparent" }
    }
    Gradient
    {
        id: defSelectionGradient
        GradientStop { position: 0; color: UISettings.toolbarHoverStart }
        GradientStop { position: 1; color: UISettings.toolbarHoverEnd }
    }
    Gradient
    {
        id: defPressedGradient
        GradientStop { position: 0; color: UISettings.bgLight }
        GradientStop { position: 1; color: UISettings.bgMedium }
    }

    contentItem:
        Row
        {
            id: entryContents
            width: btnIcon.width + btnLabel.width
            spacing: 4

            Image
            {
                id: btnIcon
                visible: control.imgSource && control.showIcon
                x: 2
                anchors.verticalCenter: parent.verticalCenter
                height: control.iconSize
                width: control.iconSize
                rotation: iconRotation
                source: control.imgSource
                sourceSize: Qt.size(control.iconSize, control.iconSize)
            }

            Text
            {
                id: faIcon
                visible: faSource ? true : false
                anchors.verticalCenter: parent.verticalCenter
                color: faColor
                font.family: UISettings.fontAwesomeFontName
                font.pixelSize: control.height * 0.80
                text: faSource
            }

            RobotoText
            {
                id: btnLabel
                height: control.height
                label: control.showIcon ? control.entryText : control.entryText.toUpperCase()
                fontSize: control.mFontSize
                fontBold: true
                labelColor: !control.showIcon && control.checked ? control.checkedColor : UISettings.fgMain
                leftMargin: control.showIcon ? 0 : UISettings.textSizeDefault * 0.8
                rightMargin: control.showIcon ? 0 : UISettings.textSizeDefault * 0.8

                Rectangle
                {
                    id: selRect
                    y: parent.height - height - 2
                    height: UISettings.listItemHeight * 0.1
                    width: parent.width
                    radius: height / 2
                    color: checked ? checkedColor : "transparent"

                }
            }
        }

    background:
        Rectangle
        {
            gradient: pressed ? pressedGradient : ((checked || hovered) ? selGradient : bgGradient)
            opacity: enabled ? 1 : 0.3
        }


    MouseArea
    {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton

        onClicked: (mouse) =>
        {
            if (mouse.button === Qt.RightButton)
                control.rightClicked()
        }
    }
}

