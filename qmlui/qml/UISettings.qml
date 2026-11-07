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
    /** Rounded display face for titles and console keys (KAHO charter) */
    property string titleFontName: "Nunito Rounded"

    property real scalingFactor: 1.0

    /* Colors - KAHO charter: dark background, black / white / grey,
       soft mauve as the only accent */
    property color bgStronger:      "#09080c"
    property color bgStrong:        "#121117"
    property color bgMedium:        "#1b1a21"
    property color bgControl:       "#2c2a34"
    property color bgLight:         "#4d4a57"
    property color bgLighter:       "#75717f"
    property color bgFixtureOdd:    "#211f29"
    property color bgFixtureEven:   "#1d1c24"

    property color fgMain:          "#f3f2f6"
    property color fgMedium:        "#8a8794"
    property color fgLight:         "#bebbc7"

    property color sectionHeader:     "#25232d"
    property color sectionHeaderDiv:  "#16151b"
    property color highlight:         "#a98bff"
    property color highlightPressed:  "#6b54c4"
    property color hover:             "#8a8794"
    property color selection:         "#cfc0ff"
    property color activeDropArea:    "#a98bff"
    property color borderColorDark:   "#050407"

    property color toolbarStartMain:  "#121117"
    property color toolbarStartSub:   "#1b1a21"
    property color toolbarEnd:        "#09080c"
    property color toolbarHoverStart: "#26242e"
    property color toolbarHoverEnd:   "#121117"

    property color toolbarSelectionMain: "#a98bff"
    property color toolbarSelectionSub:  "#cfc0ff"

    /* KAHO accent */
    property color kahoMauve:       "#a98bff"
    property color kahoMauveSoft:   "#cfc0ff"
    property color kahoMauveDeep:   "#3a2f5c"

    /* Console keys and playbacks (functional colors stay readable at a glance) */
    property color consoleAccent:   "#a98bff"
    property color consoleGo:       "#5fd39a"
    property color consoleRelease:  "#ff6b7a"

    /* Function type colors: pastel, so that mauve stays the main accent */
    property color typeScene:       "#cfc0ff"
    property color typeChaser:      "#8fd6e8"
    property color typeEfx:         "#f2a9cf"
    property color typeMatrix:      "#9ee3b9"
    property color typeCollection:  "#ecc993"
    property color typeOther:       "#a29fac"

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
