/*
  Q Light Controller Plus
  UISettings.qml

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

pragma Singleton

import QtQuick

QtObject
{
    property string robotoFontName: "Roboto Condensed"
    property string fontAwesomeFontName: "Font Awesome 7 Free"

    property real scalingFactor: 1.0

    /* Colors - KAHO console theme: charcoal surfaces, amber accent */
    property color bgStronger:      "#0d0e10"
    property color bgStrong:        "#16181b"
    property color bgMedium:        "#202327"
    property color bgControl:       "#353a41"
    property color bgLight:         "#5b616a"
    property color bgLighter:       "#7d838c"
    property color bgFixtureOdd:    "#2a2f2a"
    property color bgFixtureEven:   "#2a2c33"

    property color fgMain:          "#ececec"
    property color fgMedium:        "#80868f"
    property color fgLight:         "#b4b9c0"

    property color sectionHeader:     "#2b3038"
    property color sectionHeaderDiv:  "#1b1e23"
    property color highlight:         "#ffa31a"
    property color highlightPressed:  "#a86500"
    property color hover:             "#8a8f96"
    property color selection:         "#ffd166"
    property color activeDropArea:    "#9DFF52"
    property color borderColorDark:   "#050506"

    property color toolbarStartMain:  "#1b1d21"
    property color toolbarStartSub:   "#202327"
    property color toolbarEnd:        "#0d0e10"
    property color toolbarHoverStart: "#2b2f35"
    property color toolbarHoverEnd:   "#121316"

    property color toolbarSelectionMain: "#ffa31a"
    property color toolbarSelectionSub:  "#ffd166"

    /* Console keys and playbacks */
    property color consoleAccent:   "#ffa31a"
    property color consoleGo:       "#3fd07a"
    property color consoleRelease:  "#ff5a5f"

    /* Function type colors (playback stripes, execute buttons) */
    property color typeScene:       "#ffb43a"
    property color typeChaser:      "#35c8f0"
    property color typeEfx:         "#d46cff"
    property color typeMatrix:      "#56e39f"
    property color typeCollection:  "#8f8cff"
    property color typeOther:       "#9aa0a8"

    /* Sizes */
    property int  textSizeDefault:  screenPixelDensity * scalingFactor * 4.5
    property real iconSizeDefault:  screenPixelDensity * scalingFactor * 10 // more or less the size of a finger
    property real iconSizeMedium:   screenPixelDensity * scalingFactor * 8
    property real listItemHeight:   screenPixelDensity * scalingFactor * 7
    property real mediumItemHeight: screenPixelDensity * scalingFactor * 15
    property real bigItemHeight:    screenPixelDensity * scalingFactor * 25
    property real scrollBarWidth:   screenPixelDensity * scalingFactor * 6
    property real sidePanelWidth:   screenPixelDensity * scalingFactor * 50

    /* Persisted Simple Desk channel view scroll position, as the index of the
       first visible channel (survives context changes) */
    property int simpleDeskScrollIndex: 0

    /* True while an in-app QML drag (channels, functions, fixtures, VC
       widgets...) is in progress anywhere in the UI. MainView's full-window
       fileDropArea (used for OS file drag & drop) watches this to get out of
       the way: being a high z, full-window overlay, it would otherwise
       always win Qt's drag hit test over any nested DropArea underneath it
       and starve it of position updates, regardless of "keys" filtering. */
    property bool internalDragActive: false

    /* Channel properties column widths */
    property real chPropsModesWidth: bigItemHeight * 1.2
    property real chPropsFlagsWidth: bigItemHeight * 1.3
    property real chPropsCanFadeWidth: bigItemHeight * 0.7
    property real chPropsPrecedenceWidth: bigItemHeight * 1.2
    property real chPropsModifierWidth: bigItemHeight
}
