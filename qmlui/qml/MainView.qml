/*
  Q Light Controller Plus
  MainView.qml

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
    id: mainView
    visible: true
    width: 800
    height: 600
    anchors.fill: parent
    color: UISettings.bgMedium

    property string currentContext: ""

    // Window edges overlaid by system UI (e.g. Android status/navigation bars
    // drawn edge-to-edge). Interactive items must stay inside these margins.
    readonly property bool isAndroid: Qt.platform.os === "android"
    readonly property real safeTop: isAndroid ? SafeArea.margins.top : 0
    readonly property real safeBottom: isAndroid ? SafeArea.margins.bottom : 0
    readonly property real safeLeft: isAndroid ? SafeArea.margins.left : 0
    readonly property real safeRight: isAndroid ? SafeArea.margins.right : 0

    Component.onCompleted: UISettings.sidePanelWidth = Math.min(width / 3, UISettings.bigItemHeight * 5)
    onWidthChanged: UISettings.sidePanelWidth = Math.min(width / 3, UISettings.bigItemHeight * 5)

    property bool showWizardVisible: false
    function openShowWizard() { mainView.showWizardVisible = true }

    function enableContext(ctx, setChecked)
    {
        var item = null

        if (ctx === "FIXANDFUNC")
            item = fnfEntry
        else if (ctx === "VC")
            item = vcEntry
        else if (ctx === "SDESK")
            item = sdEntry
        else if (ctx === "SHOWMGR")
            item = smEntry
        else if (ctx === "IOMGR")
            item = ioEntry
        else if (ctx === "PLAYBACKS")
            item = pbEntry

        if (item)
        {
            item.visible = true
            if (setChecked)
                item.checked = true
            return true
        }
        return false
    }

    function switchToContext(ctx, qmlRes)
    {
        if (currentContext === ctx)
            return

        if (enableContext(ctx, true) === true)
        {
            currentContext = ctx
            // show toolbar only if not in kiosk mode
            if (qlcplus.accessMask !== App.AC_VCControl)
                mainToolbar.visible = true
        }
        else
        {
            mainToolbar.visible = false
            currentContext = ""
        }

        if (qmlRes)
            mainViewLoader.source = qmlRes
    }

    function setDimScreen(enable)
    {
        dimScreen.visible = enable
    }

    function openAccessRequest(sessionId, clientName, peerAddress, peerPort)
    {
        clientAccessPopup.deciding = false
        clientAccessPopup.sessionId = sessionId
        clientAccessPopup.clientName = clientName
        clientAccessPopup.peerAddress = peerAddress
        clientAccessPopup.peerPort = peerPort
        clientAccessPopup.open()
    }

    function closeAccessRequest(sessionId)
    {
        if (clientAccessPopup.sessionId === sessionId)
            clientAccessPopup.close()
    }

    function saveProject()
    {
        actionsMenu.handleSaveAction()
    }

    function saveBeforeExit()
    {
        //actionsMenu.open()
        actionsMenu.saveBeforeExit()
    }

    function loadResource(qmlRes)
    {
        mainViewLoader.source = qmlRes
    }

    function showScalingInfo()
    {
        scalingInfoPopup.open()
    }

    FontLoader
    {
        source: "qrc:/RobotoCondensed-Regular.ttf"
    }

    // Load the "FontAwesome" font for the monochrome icons
    FontLoader
    {
        id: faFontLoader
        source: "qrc:/FontAwesome7-Free-Solid-900.otf"
        onStatusChanged:
        {
            if (status === FontLoader.Ready)
                UISettings.fontAwesomeFontName = faFontLoader.name
        }
    }

    Rectangle
    {
        id: mainToolbar
        visible: qlcplus.accessMask & App.AC_VCControl ? false : true // this is kiosk mode
        x: mainView.safeLeft
        y: mainView.safeTop
        width: parent.width - mainView.safeLeft - mainView.safeRight
        height: UISettings.iconSizeDefault * 0.8
        z: 50
        gradient: Gradient
        {
            GradientStop { position: 0; color: UISettings.toolbarStartMain }
            GradientStop { position: 1; color: UISettings.toolbarEnd }
        }

        RowLayout
        {
            spacing: 5
            anchors.fill: parent

            ButtonGroup { id: menuBarGroup }

            Rectangle
            {
                id: actEntry
                Layout.fillHeight: true
                Layout.preferredWidth: wordmarkRow.width + UISettings.textSizeDefault * 1.6
                color: actArea.pressed ? UISettings.bgControl : (actArea.containsMouse ? UISettings.bgMedium : "transparent")

                Row
                {
                    id: wordmarkRow
                    anchors.centerIn: parent
                    spacing: UISettings.textSizeDefault * 0.45

                    Text
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "KAHO"
                        color: UISettings.kahoMauve
                        font.family: UISettings.titleFontName
                        font.pixelSize: mainToolbar.height * 0.48
                        font.letterSpacing: 1
                    }
                    Text
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "CONSOLE"
                        color: UISettings.fgMedium
                        font.family: UISettings.titleFontName
                        font.pixelSize: mainToolbar.height * 0.26
                        font.letterSpacing: 2
                    }
                    Text
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "▾"
                        color: UISettings.fgMedium
                        font.pixelSize: mainToolbar.height * 0.3
                    }
                }

                // unsaved changes
                Rectangle
                {
                    visible: qlcplus.docModified
                    width: mainToolbar.height * 0.16
                    height: width
                    radius: width / 2
                    color: UISettings.kahoMauveSoft
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: mainToolbar.height * 0.15
                }

                MouseArea
                {
                    id: actArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onPressed: actionsMenu.open()
                }
            }

            // window name, like a console status line
            Text
            {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: UISettings.textSizeDefault
                text: {
                    switch (currentContext)
                    {
                        case "FIXANDFUNC": return qsTr("Patch & programmation")
                        case "VC": return qsTr("Console virtuelle")
                        case "PLAYBACKS": return qsTr("Playbacks")
                        case "SDESK": return qsTr("Pupitre simple")
                        case "SHOWMGR": return qsTr("Show")
                        case "IOMGR": return qsTr("Entrées / sorties")
                        default: return ""
                    }
                }
                color: UISettings.fgLight
                font.family: UISettings.titleFontName
                font.pixelSize: mainToolbar.height * 0.4
            }

            Rectangle
            {
                // acts like an horizontal spacer
                Layout.fillWidth: true
                implicitHeight: parent.height
                color: "transparent"
            }

            // ################## GRAND MASTER WARNING ##################
            Rectangle
            {
                id: gmWarning
                visible: playbackManager.grandMaster < 0.995
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: UISettings.textSizeDefault * 0.5
                implicitHeight: mainToolbar.height * 0.7
                implicitWidth: gmText.implicitWidth + implicitHeight
                radius: implicitHeight / 2
                readonly property bool blackout: playbackManager.grandMaster < 0.005
                color: blackout ? UISettings.consoleRelease : "transparent"
                border.width: 1
                border.color: UISettings.consoleRelease

                SequentialAnimation on opacity
                {
                    running: gmWarning.visible && gmWarning.blackout
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) gmWarning.opacity = 1
                    NumberAnimation { to: 0.35; duration: 450 }
                    NumberAnimation { to: 1; duration: 450 }
                }

                Text
                {
                    id: gmText
                    anchors.centerIn: parent
                    text: gmWarning.blackout ? qsTr("BLACKOUT") : "GM " + Math.round(playbackManager.grandMaster * 100) + "%"
                    color: gmWarning.blackout ? UISettings.bgStronger : UISettings.consoleRelease
                    font.family: UISettings.titleFontName
                    font.pixelSize: mainToolbar.height * 0.32
                    font.letterSpacing: 1
                }
                MouseArea
                {
                    anchors.fill: parent
                    onClicked: playbackManager.grandMaster = 1
                    ToolTip.visible: containsMouse
                    ToolTip.text: qsTr("Grand Master baissé · clic pour remettre à 100 %")
                    hoverEnabled: true
                }
            }

            // ################## CLEAR (programmer) ##################
            Rectangle
            {
                id: clearKey
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: UISettings.textSizeDefault
                implicitHeight: mainToolbar.height * 0.7
                implicitWidth: clearRow.implicitWidth + implicitHeight * 0.9
                radius: implicitHeight * 0.25
                readonly property int held: simpleDesk ? simpleDesk.overrideCount : 0
                color: held > 0 ? (clearArea.pressed ? Qt.lighter(UISettings.consoleRelease, 1.2) : UISettings.consoleRelease)
                                : "transparent"
                border.width: 1
                border.color: held > 0 ? UISettings.consoleRelease : UISettings.bgControl
                opacity: held > 0 ? 1 : 0.55

                Row
                {
                    id: clearRow
                    anchors.centerIn: parent
                    spacing: clearKey.implicitHeight * 0.25
                    Text
                    {
                        text: qsTr("CLEAR")
                        color: clearKey.held > 0 ? UISettings.bgStronger : UISettings.fgMedium
                        font.family: UISettings.titleFontName
                        font.pixelSize: mainToolbar.height * 0.32
                        font.letterSpacing: 1
                    }
                    Rectangle
                    {
                        visible: clearKey.held > 0
                        anchors.verticalCenter: parent.verticalCenter
                        height: clearKey.implicitHeight * 0.62
                        width: Math.max(height, countText.implicitWidth + height * 0.5)
                        radius: height / 2
                        color: UISettings.bgStronger
                        Text
                        {
                            id: countText
                            anchors.centerIn: parent
                            text: clearKey.held
                            color: UISettings.consoleRelease
                            font.family: UISettings.robotoFontName
                            font.pixelSize: parent.height * 0.62
                            font.bold: true
                        }
                    }
                }
                MouseArea
                {
                    id: clearArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: clearKey.held > 0
                    onClicked: simpleDesk.resetAll()
                    ToolTip.visible: containsMouse
                    ToolTip.delay: 400
                    ToolTip.text: qsTr("%1 canaux tenus par le pupitre simple (en rouge) passent avant les scènes. CLEAR les relâche.").arg(clearKey.held)
                }
            }

            // ################## CLOCK ##################
            Text
            {
                id: consoleClock
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: UISettings.textSizeDefault
                color: UISettings.fgLight
                font.family: UISettings.robotoFontName
                font.pixelSize: mainToolbar.height * 0.38
                text: Qt.formatTime(new Date(), "HH:mm:ss")

                Timer
                {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: consoleClock.text = Qt.formatTime(new Date(), "HH:mm:ss")
                }
            }

            // ################## DMX DUMP ##################
            IconButton
            {
                id: sceneDump
                z: 2
                implicitWidth: UISettings.iconSizeDefault
                implicitHeight: UISettings.iconSizeDefault
                Layout.alignment: Qt.AlignTop
                bgColor: "transparent"
                imgSource: "qrc:/dmxdump.svg"
                imgMargins: 10
                tooltip: qsTr("Dump DMX values on a Scene")
                counter: (qlcplus.accessMask & App.AC_FunctionEditing)

                property string bubbleLabel: {
                    if (currentContext === sdEntry.ctxName)
                        return simpleDesk ? simpleDesk.dumpValuesCount : ""
                    else
                        return contextManager ? contextManager.dumpValuesCount : ""
                }

                function updateDumpVariables()
                {
                    if (currentContext === sdEntry.ctxName)
                    {
                        dmxDumpDialog.capabilityMask = simpleDesk ? simpleDesk.dumpChannelMask : 0
                        dmxDumpDialog.channelSetMask = simpleDesk ? simpleDesk.dumpChannelMask : 0
                    }
                    else
                    {
                        dmxDumpDialog.capabilityMask = fixtureManager ? fixtureManager.capabilityMask : 0
                        dmxDumpDialog.channelSetMask = contextManager ? contextManager.dumpChannelMask : 0
                    }
                }

                // channel count bubble
                Rectangle
                {
                    x: -3
                    y: parent.height - height + 3
                    width: sceneDump.width * 0.4
                    height: width
                    color: "red"
                    border.width: 1
                    border.color: UISettings.fgMain
                    radius: 3
                    clip: true
                    visible: sceneDump.bubbleLabel !== "0" ? true : false

                    RobotoText
                    {
                        anchors.centerIn: parent
                        height: parent.height * 0.7
                        label: sceneDump.bubbleLabel
                        fontSize: height
                    }
                }

                MouseArea
                {
                    id: dumpDragArea
                    anchors.fill: parent
                    drag.target: dumpDragItem
                    drag.threshold: 10

                    onClicked: (mouse) =>
                    {
                        sceneDump.updateDumpVariables()
                        dmxDumpDialog.open()
                        dmxDumpDialog.focusEditItem()
                    }

                    property bool dragActive: drag.active

                    onDragActiveChanged:
                    {
                        console.log("Drag active changed: " + dragActive)
                        if (dragActive == false)
                        {
                            dumpDragItem.Drag.drop()
                            dumpDragItem.parent = sceneDump
                            dumpDragItem.x = 0
                            dumpDragItem.y = 0
                        }
                        else
                        {
                            dumpDragItem.parent = mainView
                        }

                        dumpDragItem.Drag.active = dragActive
                    }
                }

                Item
                {
                    id: dumpDragItem
                    z: 99
                    visible: dumpDragArea.drag.active

                    Drag.source: dumpDragItem
                    Drag.keys: [ "dumpValues" ]

                    function itemDropped(id, name)
                    {
                        console.log("Dump values dropped on " + id)
                        functionManager.selectFunctionID(id, false)
                        sceneDump.updateDumpVariables()
                        dmxDumpDialog.sceneName = name
                        dmxDumpDialog.existingScene = true
                        dmxDumpDialog.open()
                        dmxDumpDialog.focusEditItem()
                    }

                    Rectangle
                    {
                        width: UISettings.iconSizeMedium
                        height: width
                        radius: width / 4
                        color: "red"

                        RobotoText
                        {
                            anchors.centerIn: parent
                            label: sceneDump.bubbleLabel
                        }
                    }
                }

                PopupDMXDump
                {
                    id: dmxDumpDialog
                    implicitWidth: Math.min(UISettings.bigItemHeight * 4, mainView.width / 3)

                    onAccepted:
                    {
                        if (currentContext === sdEntry.ctxName)
                        {
                            simpleDesk.dumpDmxChannels(sceneName, getChannelsMask(), existingScene && func ? func.id : -1, nonZeroOnly)
                        }
                        else
                        {
                            contextManager.dumpDmxChannels(getChannelsMask(), sceneName, existingScene && func ? func.id : -1,
                                                           allChannels, nonZeroOnly);
                        }
                    }
                }
            }

            // spacer
            Rectangle
            {
                width: UISettings.iconSizeDefault / 2
                color: "transparent"
            }

            // ################## BEATS ##################
            RobotoText
            {
                label: "BPM: " + (ioManager.bpmNumber > 0 ? ioManager.bpmNumber : qsTr("Off"))
                color: gsMouseArea.containsMouse ? UISettings.bgLight : "transparent"
                fontSize: UISettings.textSizeDefault
                Layout.alignment: Qt.AlignTop
                implicitWidth: width
                implicitHeight: parent.height

                MouseArea
                {
                    id: gsMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: beatSelectionPanel.visible = !beatSelectionPanel.visible
                }
                BeatGeneratorsPanel
                {
                    id: beatSelectionPanel
                    parent: mainView
                    y: mainToolbar.y + mainToolbar.height
                    x: mainToolbar.x + beatIndicator.x - width
                    z: 51
                    visible: false
                }
            }
            Rectangle
            {
                id: beatIndicator
                implicitWidth: height
                implicitHeight: parent.height * 0.5
                Layout.alignment: Qt.AlignVCenter
                radius: height / 2
                border.width: 2
                border.color: UISettings.bgMedium
                color: UISettings.fgMedium

                ColorAnimation on color
                {
                    id: cAnim
                    from: "#00FF00"
                    to: UISettings.fgMedium
                    // half the duration of the current BPM
                    duration: ioManager.bpmNumber ? 30000 / ioManager.bpmNumber : 200
                    running: false
                }

                Connections
                {
                    id: beatSignal
                    target: ioManager
                    function onBeat()
                    {
                        cAnim.restart()
                    }
                }
            }

            // spacer
            Rectangle
            {
                width: UISettings.iconSizeDefault / 2
                color: "transparent"
            }

            // ################## STOP ALL FUNCTIONS ##################
            IconButton
            {
                id: stopAllButton
                implicitWidth: UISettings.iconSizeDefault
                implicitHeight: UISettings.iconSizeDefault
                Layout.alignment: Qt.AlignTop
                enabled: runningCount ? true : false
                bgColor: "transparent"
                faSource: FontAwesome.fa_octagon
                faColor: "red"
                tooltip: qsTr("Stop all the running functions")

                onClicked: qlcplus.stopAllFunctions()

                property int runningCount: qlcplus.runningFunctionsCount

                onRunningCountChanged: console.log("Functions running: " + runningCount)

                RobotoText
                {
                    anchors.centerIn: parent
                    height: parent.height * 0.2
                    fontSize: height
                    label: "STOP"
                }

                Rectangle
                {
                    x: parent.width / 2
                    y: parent.height / 2
                    width: parent.width * 0.4
                    height: width
                    color: UISettings.highlight
                    border.width: 1
                    border.color: UISettings.fgMain
                    radius: 3
                    clip: true
                    visible: stopAllButton.runningCount

                    RobotoText
                    {
                        anchors.centerIn: parent
                        height: parent.height * 0.7
                        label: stopAllButton.runningCount
                        fontSize: height
                    }
                }
            }

        } // end of RowLayout
    } // end of mainToolbar

    /* Console window keys */
    Rectangle
    {
        id: windowKeysBar
        visible: mainToolbar.visible
        x: mainView.safeLeft
        y: parent.height - height - mainView.safeBottom
        width: parent.width - mainView.safeLeft - mainView.safeRight
        height: UISettings.iconSizeDefault * 1.05
        z: 50
        color: UISettings.bgStronger

        Rectangle
        {
            width: parent.width
            height: 1
            color: UISettings.bgControl
        }

        RowLayout
        {
            anchors.fill: parent
            anchors.margins: Math.max(3, height * 0.08)
            spacing: Math.max(3, height * 0.08)

            ConsoleWindowKey
            {
                id: fnfEntry
                property string ctxName: "FIXANDFUNC"
                property string ctxRes: "qrc:/FixturesAndFunctions.qml"
                Layout.fillWidth: true
                Layout.fillHeight: true
                entryText: qsTr("Patch & prog")
                keyHint: "F1"
                ButtonGroup.group: menuBarGroup
                onCheckedChanged:
                {
                    if (checked === true)
                        switchToContext(fnfEntry.ctxName, fnfEntry.ctxRes)
                }
            }
            ConsoleWindowKey
            {
                id: vcEntry
                property string ctxName: "VC"
                property string ctxRes: "qrc:/VirtualConsole.qml"
                Layout.fillWidth: true
                Layout.fillHeight: true
                entryText: qsTr("Console")
                keyHint: "F2"
                ButtonGroup.group: menuBarGroup
                visible: qlcplus.accessMask & App.AC_VCControl
                onCheckedChanged:
                {
                    if (checked === true)
                        switchToContext(vcEntry.ctxName, vcEntry.ctxRes)
                }
                onRightClicked:
                {
                    vcEntry.visible = false
                    contextManager.detachContext("VC")
                }
            }
            ConsoleWindowKey
            {
                id: pbEntry
                property string ctxName: "PLAYBACKS"
                property string ctxRes: "qrc:/Playbacks.qml"
                Layout.fillWidth: true
                Layout.fillHeight: true
                entryText: qsTr("Playbacks")
                keyHint: "F3"
                ButtonGroup.group: menuBarGroup
                visible: qlcplus.accessMask & App.AC_VCControl
                onCheckedChanged:
                {
                    if (checked === true)
                        switchToContext(pbEntry.ctxName, pbEntry.ctxRes)
                }
                onRightClicked:
                {
                    pbEntry.visible = false
                    contextManager.detachContext("PLAYBACKS")
                }
            }
            ConsoleWindowKey
            {
                id: sdEntry
                property string ctxName: "SDESK"
                property string ctxRes: "qrc:/SimpleDesk.qml"
                Layout.fillWidth: true
                Layout.fillHeight: true
                entryText: qsTr("Pupitre")
                keyHint: "F4"
                ButtonGroup.group: menuBarGroup
                visible: qlcplus.accessMask & App.AC_SimpleDesk
                onCheckedChanged:
                {
                    if (checked === true)
                        switchToContext(sdEntry.ctxName, sdEntry.ctxRes)
                }
                onRightClicked:
                {
                    sdEntry.visible = false
                    contextManager.detachContext("SDESK")
                }
            }
            ConsoleWindowKey
            {
                id: smEntry
                property string ctxName: "SHOWMGR"
                property string ctxRes: "qrc:/ShowManager.qml"
                Layout.fillWidth: true
                Layout.fillHeight: true
                entryText: qsTr("Show")
                keyHint: "F5"
                ButtonGroup.group: menuBarGroup
                visible: qlcplus.accessMask & App.AC_ShowManager
                onCheckedChanged:
                {
                    if (checked === true)
                        switchToContext(smEntry.ctxName, smEntry.ctxRes)
                }
                onRightClicked:
                {
                    smEntry.visible = false
                    contextManager.detachContext("SHOWMGR")
                }
            }
            ConsoleWindowKey
            {
                id: ioEntry
                property string ctxName: "IOMGR"
                property string ctxRes: "qrc:/InputOutputManager.qml"
                Layout.fillWidth: true
                Layout.fillHeight: true
                entryText: qsTr("Entrées / sorties")
                keyHint: "F6"
                ButtonGroup.group: menuBarGroup
                visible: qlcplus.accessMask & App.AC_InputOutput
                onCheckedChanged:
                {
                    if (checked === true)
                        switchToContext(ioEntry.ctxName, ioEntry.ctxRes)
                }
                onRightClicked:
                {
                    ioEntry.visible = false
                    contextManager.detachContext("IOMGR")
                }
            }
        }

        Shortcut { sequence: "F1"; onActivated: fnfEntry.checked = true }
        Shortcut { sequence: "F2"; enabled: vcEntry.visible; onActivated: vcEntry.checked = true }
        Shortcut { sequence: "F3"; enabled: pbEntry.visible; onActivated: pbEntry.checked = true }
        Shortcut { sequence: "F4"; enabled: sdEntry.visible; onActivated: sdEntry.checked = true }
        Shortcut { sequence: "F5"; enabled: smEntry.visible; onActivated: smEntry.checked = true }
        Shortcut { sequence: "F6"; enabled: ioEntry.visible; onActivated: ioEntry.checked = true }
    }

    Loader
    {
        id: showWizardOverlay
        width: parent.width
        height: parent.height
        source: parent.showWizardVisible ? "qrc:/ShowWizard.qml" : ""
        z: 100
        onLoaded: if (item) { item.closeRequested.connect(function() { mainView.showWizardVisible = false }); item.open() }
    }

    Loader
    {
        id: mainViewLoader
        x: mainView.safeLeft
        y: mainView.safeTop + (mainToolbar.visible ? mainToolbar.height : 0)
        width: parent.width - mainView.safeLeft - mainView.safeRight
        height: parent.height - y - mainView.safeBottom - (windowKeysBar.visible ? windowKeysBar.height : 0)

        Component.onCompleted:
        {
            var ctx = "FIXANDFUNC"
            // handle Kiosk mode on startup
            if (qlcplus.accessMask === App.AC_VCControl)
                ctx = "VC"
            enableContext(ctx, true)
        }
    }

    PopupNetworkConnect { id: clientAccessPopup }

    CustomPopupDialog
    {
        id: scalingInfoPopup
        width: mainView.width / 2
        title: qsTr("Small screen detected")
        message: qsTr("The UI scaling factor has been automatically set to %1x to fit this screen.\n" +
                      "It can be adjusted in the UI Settings panel, from the Actions menu.")
                 .arg(UISettings.scalingFactor.toFixed(2))
        standardButtons: Dialog.Ok
    }

    /** Menu to open/load/save a project */
    ActionsMenu
    {
        id: actionsMenu
        x: mainToolbar.x + 1
        y: mainToolbar.y + actEntry.height + 1
        visible: false
        z: visible ? 99 : 0
    }

    /** Allow a project (.qxw/.qxw.gz) or fixture (.qxf/.d4) file to be opened
      * by dragging it from the OS file manager and dropping it on the window.
      * Qt Quick delivers drag hover/position events to only the topmost
      * DropArea under the pointer - "keys" only gates acceptance
      * (containsDrag/onDropped), not hit testing. Being a full-window
      * overlay, this would otherwise always win that hit test and starve any
      * nested DropArea underneath it (e.g. the fixture editor's channel
      * reordering) of position updates. So it drops below the main view's
      * content (z < 0) for as long as UISettings.internalDragActive says an
      * in-app drag is going on anywhere, and only then. */
    DropArea
    {
        id: fileDropArea
        anchors.fill: parent
        z: UISettings.internalDragActive ? -1 : 100
        keys: [ "text/uri-list" ]

        onDropped: function(drop)
        {
            if (drop.urls.length)
                actionsMenu.openFile(drop.urls[0])
        }
    }

    Rectangle
    {
        anchors.fill: parent
        z: 100
        visible: fileDropArea.containsDrag
        color: Qt.rgba(0, 0, 0, 0.6)
        border.width: 3
        border.color: UISettings.activeDropArea

        Text
        {
            anchors.centerIn: parent
            text: qsTr("Drop a project or fixture file to open it")
            font.pixelSize: UISettings.textSizeDefault * 1.4
            color: "white"
        }
    }

    /* Rectangle covering the whole window to
     * have a dimmered background for popups */
    Rectangle
    {
        id: dimScreen
        anchors.fill: parent
        visible: false
        z: 99
        color: Qt.rgba(0, 0, 0, 0.5)
    }

    //PopupDisclaimer { }
}
