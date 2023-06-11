/*
Copyright (C) 2023- Paolo Angelelli <paoletto@gmail.com>

This work is licensed under the terms of the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/4.0/ or send a letter to Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.

In addition to the above,
- The use of this work for training artificial intelligence is prohibited for both commercial and non-commercial use.
- Any and all donation options in derivative work must be the same as in the original work.
- All use of this work outside of the above terms must be explicitly agreed upon in advance with the exclusive copyright owner(s).
- Any derivative work must retain the above copyright and acknowledge that any and all use of the derivative work outside the above terms
  must be explicitly agreed upon in advance with the exclusive copyright owner(s) of the original work.

*/

import QtQuick 2.14
import QtQuick.Window 2.14
import QtQuick.Controls 2.14
import QtQuick.Shapes 1.14
import Qt.labs.settings 1.1
import QtQuick.Dialogs 1.3
import QtQuick.Layouts 1.14

ApplicationWindow {
    id: win
    width: 641
    height: 481
    minimumHeight: 89
    visible: true
    title: qsTr("Tiny (N)Urbs Editor")

    Timer {
        id: loadingTimer
        interval: 200
        repeat: false
        running: false
        property url fileUrl
        onTriggered: {
            NURBS.load(fileUrl)
            populatePoints(NURBS.controlPoints())
        }
    }
    FileDialog {
        id: fileDialogOpen
        nameFilters: [ "All files (*)" ]
        title: "Please choose a file"
        property url lastOpened: (NURBS) ? NURBS.fileName : ""
        onAccepted: {
            console.log("You chose: " + fileDialogOpen.fileUrls)
            fileDialogOpen.close()
            label.text = fileDialogOpen.fileUrl

            loadingTimer.fileUrl = fileDialogOpen.fileUrl
            lastOpened = fileDialogOpen.fileUrl
            loadingTimer.start()
        }
        onRejected: { }
    }
    FileDialog {
        id: fileDialogOpenBackground
        nameFilters: [ "All files (*)" ]
        title: "Please choose a file"
        onAccepted: {
            console.log("You chose: " + fileDialogOpenBackground.fileUrls)
            fileDialogOpenBackground.close()
            backgroundImage.source = fileDialogOpenBackground.fileUrl
        }
        onRejected: { }
    }

    FileDialog {
        id: fileDialogAddScript
        nameFilters: [ "Python scripts (*.py)" ]
        title: "Please choose a script file"
        onAccepted: {
            console.log("You chose: " + fileDialogAddScript.fileUrls)
            fileDialogAddScript.close()

            settings.addScript(fileDialogAddScript.fileUrl)
        }
        onRejected: { }
    }

    header: ToolBar {
        id: toolbar
        contentHeight: 48

        Label {
            id: label
            text: (fileDialogOpen.lastOpened == "") ? "<unnamed>" : fileDialogOpen.lastOpened
            anchors.centerIn: parent
            anchors.left: parent.left
            anchors.right: fileRow.left
        }

        Row {
            id: settingsRow
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }
            visible: true

            ToolButton {
                id: settingsButton
                text: qsTr("Settings")
                width: 90
                font.pixelSize: Qt.application.font.pixelSize
                onClicked: {
                    settingsMenu.open()
                }
                Menu {
                    id: settingsMenu
                    MenuItem {
                        text: qsTr("Reset camera")
                        onTriggered: {
                            item.offset = Qt.point(0,0)
                            item.scale = 1.0
                            relayout()
                        }
                    }
                    CheckBox {
                        id: showNormalsCheckbox
                        text: "Normals"
                    }
                    CheckBox {
                        id: modifyBackgroundCheckbox
                        text: "Change Background"
                    }
                    Rectangle {
                        width: parent.width
                        height: 48
                        color: "transparent"
                        Column {
                            anchors.fill: parent
                            Label {
                                text: "  Degree"
                            }
                            Slider {
                                id: degreeSlider
                                from: 1
                                value: (NURBS) ? NURBS.degree : 4
                                to: 12
                                stepSize: 1
                                live: true
                                onValueChanged: NURBS.degree = degreeSlider.value
                                ToolTip {
                                    opacity: 0.5
                                    parent: degreeSlider.handle
                                    visible: degreeSlider.pressed
                                    text: ~~degreeSlider.value
                                }
                            }
                        }
                    }
                    Rectangle {
                        width: parent.width
                        height: 48
                        color: "transparent"
                        Column {
                            anchors.fill: parent
                            Label {
                                text: "  Evaluation steps"
                            }
                            Slider {
                                id: steppingSlider
                                from: 14
                                value: (NURBS) ? NURBS.steps : 20
                                to: 200
                                stepSize: 1
                                live: true
                                onValueChanged: {
                                    if (NURBS)
                                        NURBS.steps = value
                                }
                                ToolTip {
                                    opacity: 0.5
                                    parent: steppingSlider.handle
                                    visible: steppingSlider.pressed
                                    text: ~~steppingSlider.value
                                }
                            }
                        }
                    }
                } // settingsMenu
            } // settingsButton
            ToolButton {
                id: scriptingButton
                text: qsTr("Scripting")
                width: 90
                font.pixelSize: Qt.application.font.pixelSize
                onClicked: {
                    scriptingMenu.open()
                }
                Menu {
                    id: scriptingMenu
                    MenuItem {
                        text: qsTr("Add script")
                        onTriggered: {
                            // File Selector
                            fileDialogAddScript.visible = true
                        }
                    }
                    MenuSeparator { }

                    Column {
                        id: scriptsCol
                        Repeater {
                            model: settings.scripts
                            RowLayout {
                                property string fname: modelData
                                property int idx: index
                                Button {
                                    Layout.preferredWidth:  scriptsCol.width -32
                                    text: (NURBS) ? NURBS.filePathToName(fname) : ""
                                    enabled: (NURBS) ? NURBS.fileExists(fname) : false
                                    onClicked: {
                                        // File Selector
                                        if (NURBS) {
                                            NURBS.runScript(fname)
                                        }
                                    }

                                }
                                Button {
                                    text: "x"
                                    Layout.preferredWidth: 32
                                    onClicked: {
                                        console.log("Remove", fname)
                                        settings.removeScript(fname)
                                    }
                                }
                            }


                        }
                    }

                } // scriptingMenu
            } // scriptingButton
            ToolButton {
                id: scaleButton
                text: qsTr("Scale")
                width: 90
                font.pixelSize: Qt.application.font.pixelSize
                onClicked: {
                    scaleMenu.open()
                }
                Menu {
                    id: scaleMenu
                    width: 640
                    MenuSeparator { }
                    Label {
                        text: "  Scaling"
                    }
                    Column {
                        id: scaleCol
                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            Slider {
                                id: scaleXSlider
                                from: 0.5
                                value: 1
                                to: 2
                                live: true
                                width: parent.width * 0.8
                                ToolTip {
                                    opacity: 0.5
                                    parent: scaleXSlider.handle
                                    visible: scaleXSlider.pressed
                                    text: scaleXSlider.value.toFixed(2)
                                }
                            }
                            Button {
                                text: "X"
                                width: 32
                                onClicked: {
                                    console.log("Apply scale X", scaleXSlider.value)
                                    scalePoints(scaleXSlider.value, 1)

                                }
                            }
                        }
                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            Slider {
                                id: scaleYSlider
                                from: 0.5
                                value: 1
                                to: 2
                                live: true
                                width: parent.width * 0.8
                                ToolTip {
                                    opacity: 0.5
                                    parent: scaleYSlider.handle
                                    visible: scaleYSlider.pressed
                                    text: scaleYSlider.value.toFixed(2)
                                }
                            }
                            Button {
                                text: "Y"
                                width: 32
                                onClicked: {
                                    console.log("Apply scale Y", scaleYSlider.value)
                                    scalePoints(1, scaleXSlider.value)
                                }
                            }
                        }
                    }
                    MenuSeparator { }
                    Label {
                        text: "  Shifting"
                    }

                    Column {
                        id: shiftCol
                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            Slider {
                                id: shiftXSlider
                                from: -1
                                value: 0
                                to: 1
                                live: true
                                width: parent.width * 0.8
                                ToolTip {
                                    opacity: 0.5
                                    parent: shiftXSlider.handle
                                    visible: shiftXSlider.pressed
                                    text: shiftXSlider.value.toFixed(3)
                                }
                            }
                            Button {
                                text: "X"
                                width: 32
                                onClicked: {
                                    console.log("Apply shift X", shiftXSlider.value)
                                    shiftPointsCm(Qt.point(shiftXSlider.value, 0))

                                }
                            }
                        }
                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            Slider {
                                id: shiftYSlider
                                from: -1
                                value: 0
                                to: 1
                                live: true
                                width: parent.width * 0.8
                                ToolTip {
                                    opacity: 0.5
                                    parent: shiftYSlider.handle
                                    visible: shiftYSlider.pressed
                                    text: shiftYSlider.value.toFixed(3)
                                }
                            }
                            Button {
                                text: "Y"
                                width: 32
                                onClicked: {
                                    console.log("Apply scale Y", shiftYSlider.value)
                                    shiftPointsCm(Qt.point(0, shiftYSlider.value))
                                }
                            }
                        }
                    }
                } // scaleMenu
            } // scaleButton
        } // settingsRow

        Row {
            id: fileRow
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }
            visible: true


            ToolButton {
                id: openBgButton
                text: qsTr("Open Bg")
                font.pixelSize: Qt.application.font.pixelSize

                onClicked: {
                    fileDialogOpenBackground.visible = true
                }
            }
            ToolButton {
                id: openButton
                text: qsTr("Open")
                font.pixelSize: Qt.application.font.pixelSize

                onClicked: {
                    fileDialogOpen.visible = true
                }
            }
            ToolButton {
                id: saveButton
                text: "Save" + ( ((fileDialogOpen.lastOpened != "") && dirty) ?  " *" : "" )
                font.pixelSize: Qt.application.font.pixelSize
                onClicked: {
                    NURBS.save(fileDialogOpen.lastOpened)
                    markClean()
                }
                property bool dirty: false
                function markDirty() {
                    dirty = true
                }
                function markClean() {
                    dirty = false
                }
            }
            ToolButton {
                id: exportButton
                text: qsTr("Save as")
                width: 100
                font.pixelSize: Qt.application.font.pixelSize
                onClicked: {
                    NURBS.requestWrite()
                }
            }
        }
    }

    property int halfWidth: item.width / 2 + 1
    property int halfHeight: item.height / 2 + 1

    onWidthChanged: {
        if (!(width % 2))
            width += 1
        relayout()
    }
    onHeightChanged: {
        if (!(height % 2))
            height += 1
        relayout()
    }

    function relayout() {
        for (var i = 0; i < pts.length; i++) {
            pts[i].reposition()
        }
        polyline.path = getShapePoly()
    }

    Settings {
        id: settings
        property alias winWidth: win.width
        property alias winHeight: win.height
        property alias winX: win.x
        property alias winY: win.y

        property var scripts: []
        onScriptsChanged: {
            console.log(scripts)
            for (var i = 0; i < scripts.length; i++) {
                console.log(scripts[i], NURBS.fileExists(scripts[i]))
            }
        }

        function addScript(s)
        {
            var scripts_ = scripts
            for (var i = 0; i < scripts_.length; i++)
            {
                if (scripts_[i] === s)
                    return;
            }
            scripts_.push(s)
            scripts = scripts_;
        }
        function removeScript(s)
        {
            var scripts_ = scripts
            for (var i = 0; i < scripts_.length; i++)
            {
                if (scripts_[i] == s) {
                    scripts_.splice(i, 1)
                    break
                }
            }
            scripts = scripts_;
        }
    }

    property real pixelDensity: Screen.pixelDensity
    property real dprScale : Math.max(1.0, pixelDensity / 3.7)  // 3.7 = 96 ppi
    property real ppm : pixelDensity * 1000 // pixels per meter
    property real ppcm : pixelDensity * 10 // pixels per centimeter
    property real pixelSize : 1.0 / ppm // also in meters
    property real pixelSizeCm : pixelSize * 100.0 / item.scale
    property real cmSizePixels : 1.0 / pixelSizeCm

    property var pts : []

    function getShapePoly() {
        var res = []
        for (var i = 0; i < pts.length; i++) {
            res.push(Qt.point(
                          (pts[i].x + 9)
                         ,(pts[i].y + 9)))
        }
        return res
    }

    function updateShape() {
        polyline.path = getShapePoly()
        var ctrlMeters = pixelsToMeters(getShapePoly())
        NURBS.update(ctrlMeters)
        saveButton.markDirty()
    }

    function removePoint(pt) {
        const index = pts.indexOf(pt);
        if (index > -1) {
            pts.splice(index, 1);
        }
    }

    function clearPoints() {
        for (var i = pts.length - 1; i >= 0; i--) {
            pts[i].destroy()
            pts.splice(i, 1);
        }
        pts = []
    }

    function populatePoints(metricPoints) {
        clearPoints()
        for (var i = 0; i < metricPoints.length; i++) {
            var itm = comp.createObject(item, {x: 0, y: 0})
            pts.push(itm)
            itm.setMetric(metricPoints[i][0], metricPoints[i][1])
        }
        updateShape()
    }

    function shiftPoints(shift) {
        for (var i = 0; i < pts.length; i++) {
            pts[i].x += shift.x
            pts[i].y += shift.y
            pts[i].updateMetricPosition()
        }
        updateShape()
    }

    function shiftPointsCm(shift) {
        var xMt = win.cmSizePixels * shift.x;
        var yMt = win.cmSizePixels * shift.y;
        shiftPoints(Qt.point(xMt, yMt))
    }

    function scalePoints(scaleX, scaleY) {
        var centerFactorX = win.halfWidth + item.offset.x;
        var centerFactorY = win.halfHeight + item.offset.y;
        for (var i = 0; i < pts.length; i++) {
            pts[i].setCenterX((pts[i].centerX() - centerFactorX) * scaleX + centerFactorX)
            pts[i].setCenterY((pts[i].centerY() - centerFactorY) * scaleY + centerFactorY)
            pts[i].updateMetricPosition()
        }
        updateShape()
    }

    // This goes to center and from center. to that dst to top left corner needs to be subtracted
    function metric2Pixel(pos) {
        return Qt.point((pos.x / win.pixelSizeCm) + win.halfWidth + item.offset.x,
                        win.halfHeight - (pos.y / win.pixelSizeCm) + item.offset.y)
    }

    // This goes to center and from center. to that dst to top left corner needs to be added
    function pixel2Metric(px) {
        return Qt.point(((px.x - item.offset.x) - win.halfWidth) * win.pixelSizeCm,
                        (item.height - win.halfHeight + 1 -(px.y - item.offset.y)) * win.pixelSizeCm )
    }

    function metersToPixels(points) {
        var res = []
        for (var i = 0; i < points.length; i++) {
            res.push(metric2Pixel(points[i]))
        }
        return res
    }

    function metersToPixelsOff(points, offset) { // for triggering on offset or scale change
        return metersToPixels(points)
    }

    function pixelsToMeters(points) {
        var res = []
        for (var i = 0; i < points.length; i++) {
            res.push(pixel2Metric(points[i]))
        }
        return res
    }

    Item {
        id: item
        property point offset: Qt.point(0,0)
        property real scale: 1.0

        onOffsetChanged: {
        }

        anchors {
            top: toolbar.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }

        Rectangle {
            x: (((NURBS) ? NURBS.bgPos.x : 0) * item.scale) + item.width / 2 + item.offset.x
            y: (((NURBS) ? NURBS.bgPos.y : 0) * item.scale) + item.height / 2 + item.offset.y
            width: (NURBS) ? NURBS.bgSize.width * item.scale: 0
            height: (NURBS) ? NURBS.bgSize.height * item.scale: 0
            color: "transparent"
            border.color: imageMA.enabled ? "red" : "transparent"
            Image {
                id: backgroundImage
                anchors.fill: parent
                mipmap: true
                smooth: true

                onImplicitHeightChanged: {
                    if (NURBS.bgSize.height === 0)
                        NURBS.bgSize = Qt.size(implicitWidth, implicitHeight)
                }
            }
            MouseArea {
                id: imageMA
                anchors.fill: parent
                enabled: !mainMA.enabled

                property point lastPos
                acceptedButtons: Qt.LeftButton

                onWheel: {
                    if (wheel.modifiers & Qt.ControlModifier) {
                        var scaling = (1.0 + (wheel.angleDelta.y / 12000.0))
                        NURBS.bgSize = Qt.size(NURBS.bgSize.width * scaling, NURBS.bgSize.height * scaling)
                        relayout()
                    }
                }
                onPressed: {
                    if(mouse.button == Qt.LeftButton) {
                        imageMA.lastPos = Qt.point(mouse.x, mouse.y)
                    }
                }
                onPositionChanged: {
                    if(pressedButtons & Qt.LeftButton) {
                        var curPos = NURBS.bgPos
                        NURBS.bgPos = Qt.point(curPos.x + (mouse.x - lastPos.x) * item.scale,
                                               curPos.y + (mouse.y - lastPos.y) * item.scale)
                        lastPos = Qt.point(mouse.x, mouse.y)
                        relayout()
                    }
                }
                onReleased: {
                    if(mouse.button == Qt.MiddleButton) {
                    }
                }
            }
        }

        // Axes
        Rectangle { // y axis
            z: 8
            x: item.width / 2 + item.offset.x
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: "black"
        }

        Rectangle { // x axis
            z: 8
            y: item.height / 2 + item.offset.y
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: "black"
        }

        Repeater {
            id: yTicks
            model: numElements
            readonly property int numElements: 21
            readonly property int halfElements: ~~(numElements / 2)
            Rectangle {
                z: 8
                visible: (index !== yTicks.halfElements)
                x: item.width / 2 + item.offset.x - 2
                y: item.height / 2 + item.offset.y + (index - yTicks.halfElements) * win.ppcm * item.scale
                width: 5
                height: 1
                color: "firebrick"
            }
        }

        Repeater {
            id: xTicks
            model: yTicks.numElements
            Rectangle {
                z: 8
                visible: (index !== yTicks.halfElements)
                property real scaleFactor: (index )
                property real indexOffset: (index - yTicks.halfElements)
                x: item.width / 2 + item.offset.x + indexOffset * win.ppcm * item.scale
                y: item.height / 2 + item.offset.y - 2
                width: 1
                height: 5
                color: "firebrick"
            }
        }

        Shape {
            z : 10
            vendorExtensionsEnabled: false
            objectName: "shape"
            id: shape
            anchors.fill: parent

            ShapePath {
                strokeWidth: 1
                strokeColor: "red"
                fillColor: "transparent"
                PathPolyline {
                    id: polyline
                }
            }
        }

        Shape {
            z : 10
            vendorExtensionsEnabled: false
            objectName: "curveShape"
            id: curveShape
            anchors.fill: parent

            ShapePath {
                strokeWidth: 1
                strokeColor: "firebrick"
                fillColor: "transparent"

                PathPolyline {
                    id: nurbsPolyline
                    path: (NURBS) ? metersToPixelsOff(NURBS.curve, item.offset, item.scale) : undefined
                }
            }
        }

        Repeater {
            id: repeaterTangents
            delegate: Rectangle {
                color: "green"
                width: 64
                height: 1
                z: 10
                antialiasing: true
                property var pos: modelData
                x: pos.x
                y: pos.y
                rotation: (NURBS) ? NURBS.tangents[index] : 0
                transformOrigin: Item.TopLeft
            }
            model: (showNormalsCheckbox.checkState == Qt.Checked)  // (NURBS) ? NURBS.tangents : undefined
                        ? nurbsPolyline.path
                        : []
        }

        Component {
            id: comp
            Rectangle {
                id: rect
                color: "firebrick"
                width: 17
                property int centerOffset: width / 2 + 1
                height: width
                radius: width * 0.5
                property point center: Qt.point(x + centerOffset, y + centerOffset)

                function centerX() {
                    return x + centerOffset
                }
                function centerY() {
                    return y + centerOffset
                }

                function setCenterX(newCenterX) {
                    x = newCenterX - centerOffset
                }

                function setCenterY(newCenterY) {
                    y = newCenterY - centerOffset
                }

                Component.onCompleted: {}

                onXChanged: {
                    if (dragging) {
                        updateMetricPosition()
                        updateShape()
                    }
                }
                onYChanged: {
                    if (dragging) {
                        updateMetricPosition()
                        updateShape()
                    }
                }

                function updateMetricPosition() {
                    var mtr = pixel2Metric(center)
                    metricX = mtr.x
                    metricY = mtr.y
                }

                function reposition() {
                    var px = metric2Pixel(meticPosition)
                    x = px.x - centerOffset
                    y = px.y - centerOffset
                }

                function setMetric(mx, my) {
                    metricX = mx
                    metricY = my
                    reposition()
                }

                property alias dragging: maPoint.drag.active

                property real metricX
                property real metricY
                property point meticPosition: Qt.point(metricX, metricY)

                Text {
                    anchors.bottom: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "" + rect.metricX.toFixed(2) + ", "+rect.metricY.toFixed(2)

                    visible: rect.dragging || maPoint.pressed
                }

                MouseArea {
                    id: maPoint
                    anchors.fill: rect
                    drag.target: rect
                    drag.threshold: 2

                    onDoubleClicked: {
                        // remove from list
                        removePoint(rect)
                        rect.destroy()
                        // repaint
                        updateShape()
                    }
                }
            }
        }

        MouseArea {
            id: mainMA
            enabled: !modifyBackgroundCheckbox.checked
            anchors.fill: parent
            property point lastPos
            property point anchorPoint
            property point initialOffset
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton

            onDoubleClicked: {
                if(mouse.button == Qt.LeftButton) {
                    var itm = comp.createObject(item, {x: mouseX, y: mouseY})
                    itm.x -= itm.centerOffset
                    itm.y -= itm.centerOffset
                    itm.updateMetricPosition()
                    pts.push(itm)
                    updateShape()
                }
            }
            onWheel: {
                if (wheel.modifiers & Qt.ControlModifier) {
                    item.scale = Math.max(item.scale + (wheel.angleDelta.y / 1200.0), 0.1)
                    relayout()
                } else if (wheel.modifiers & Qt.ShiftModifier) {
                    var scale = 1.0 + (wheel.angleDelta.y / 24000.0)
                    scalePoints(scale, scale)
                }
            }
            onPressAndHold: {

            }
            onPressed: {
                lastPos = Qt.point(mouse.x, mouse.y)
                if(mouse.button == Qt.MiddleButton) {
                    anchorPoint = Qt.point(mouse.x, mouse.y)
                    initialOffset = item.offset
                } else if (pressedButtons & Qt.LeftButton) {
                    if (mouse.modifiers & Qt.ShiftModifier) {

                    } else {
                        measuringCrossHair.pos = Qt.point(mouse.x, mouse.y)
                        measuringCrossHair.visible = true
                    }
                }
            }
            onPositionChanged: {
                if (pressedButtons & Qt.MiddleButton) {
                    item.offset = Qt.point(initialOffset.x + mouse.x - anchorPoint.x, initialOffset.y + mouse.y - anchorPoint.y)
                    relayout()
                } else if (pressedButtons & Qt.LeftButton) {
                    if (mouse.modifiers & Qt.ShiftModifier) {
                        var posDiff = Qt.point(mouse.x - lastPos.x, mouse.y - lastPos.y)
                        console.log("shifting ", posDiff)
                        shiftPoints(posDiff)
                        lastPos = Qt.point(mouse.x, mouse.y)
                    } else {
                        measuringCrossHair.pos = Qt.point(mouse.x, mouse.y)
                    }
                }
            }
            onReleased: {
                if(mouse.button == Qt.MiddleButton) {
                }
                if (mouse.button == Qt.LeftButton) {
                    measuringCrossHair.visible = false
                }
            }
        }
    } // item

    Item {
        id: measuringCrossHair
        anchors.fill: parent
        visible: false
        enabled: visible
        property point pos: Qt.point(0,0)
        property point metric: pixel2Metric(pos)

        Label {
            anchors.left: parent.left
            anchors.leftMargin: 2
            y: measuringCrossHair.pos.y - 16
            text: measuringCrossHair.metric.y.toFixed(3)
        }

        Label {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            transformOrigin: Item.BottomLeft
            rotation: -90
            x: measuringCrossHair.pos.x - 1
            text: measuringCrossHair.metric.x.toFixed(3)
        }

        Rectangle {
            anchors {
                top: parent.top
                bottom: parent.bottom
            }
            width: 1
            x: measuringCrossHair.pos.x
            color: "green"
        }
        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
            }
            height: 1
            y: measuringCrossHair.pos.y
            color: "green"
        }
    }

    // The label showing the zoom
    Label {
        z: 10
        anchors {
            left: parent.left
            top: parent.top
            leftMargin: 2
            topMargin: 2
        }
        text: "zoom " + item.scale.toFixed(1)
    }
}
