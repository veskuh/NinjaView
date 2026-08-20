import QtQuick
import QtQuick.Controls
import Kaakao
import NinjaView

KaakaoGridDelegate {
    id: gridDelegate
    
    required property var model
    required property int index

    // Configuration / state passed from parent
    property var selectedPaths: ({})
    property int selectedCount: 0
    property int lastClickedIndex: -1
    property var rotationTimestamps: ({})
    property var galleryModelSource
    property var exifDatabaseSource
    property var getImageUrlHelper

    readonly property bool isMultiSelected: selectedPaths && selectedPaths[model.rawPath] === true

    // Attached properties alias for grid cell metrics
    width: GridView.view ? GridView.view.cellWidth : 200
    height: GridView.view ? GridView.view.cellHeight : 200

    // Signals to notify the parent container of interactions
    signal itemClicked(string rawPath, int idx, int modifiers)
    signal itemDoubleClicked(string rawPath, int idx, bool isFolder, string fileName)
    signal itemRightClicked(string rawPath, int idx, bool isFolder, var mouse)
    signal selectionToggled(string rawPath, int idx)
    signal updateSelectedPaths(var newSelections)
    signal updateLastClickedIndex(int newIndex)

    Keys.onPressed: (event) => {
        if (!GridView.view || !galleryModelSource) return
        
        let cols  = Math.max(1, Math.floor(GridView.view.width / GridView.view.cellWidth))
        let total = galleryModelSource.count
        let cur   = GridView.view.currentIndex  // focused item in grid
        let isShift = (event.modifiers & Qt.ShiftModifier) !== 0

        // Compute where a plain arrow/home/end would move currentIndex.
        let target = -1
        switch (event.key) {
            case Qt.Key_Right: target = Math.min(cur + 1,    total - 1); break
            case Qt.Key_Left:  target = Math.max(cur - 1,    0);         break
            case Qt.Key_Down:  target = Math.min(cur + cols, total - 1); break
            case Qt.Key_Up:    target = Math.max(cur - cols, 0);         break
            case Qt.Key_Home:  target = 0;                               break
            case Qt.Key_End:   target = total - 1;                       break
            default: break
        }

        if (event.key === Qt.Key_Space && gridDelegate.selectedCount > 1) {
            // Block Space in multi-select (would trigger Quick Look)
            event.accepted = true
        } else if (target >= 0 && isShift) {
            let anchor = gridDelegate.lastClickedIndex >= 0 ? gridDelegate.lastClickedIndex : cur
            let start  = Math.min(anchor, target)
            let end    = Math.max(anchor, target)
            let newSelections = {}
            for (let i = start; i <= end; ++i) {
                newSelections[galleryModelSource.getRawPath(i)] = true
            }
            gridDelegate.updateSelectedPaths(newSelections)
        } else if (target >= 0) {
            let newSelections = {}
            newSelections[galleryModelSource.getRawPath(target)] = true
            gridDelegate.updateSelectedPaths(newSelections)
            gridDelegate.updateLastClickedIndex(target)
        }
    }

    Keys.onReleased: (event) => {
        if (event.key === Qt.Key_Space && gridDelegate.selectedCount > 1) {
            event.accepted = true;
        }
    }

    onClicked: {
        gridDelegate.itemClicked(model.rawPath, index, Qt.keyboardModifiers)
    }

    background: Rectangle {
        anchors.fill: parent
        
        color: {
            if (gridDelegate.isMultiSelected) {
                if (gridDelegate.GridView.view && gridDelegate.GridView.view.activeFocus)
                    return Theme.selectionBackgroundActive;
                return Theme.selectionBackgroundInactive;
            }
            return "transparent"
        }
    }

    onDoubleClicked: {
        gridDelegate.itemDoubleClicked(model.rawPath, index, model.isFolder, model.fileName)
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                if (GridView.view) {
                    GridView.view.currentIndex = index
                    GridView.view.forceActiveFocus()
                }

                if (gridDelegate.selectedPaths[model.rawPath] !== true) {
                    let newSelections = {}
                    newSelections[model.rawPath] = true
                    gridDelegate.updateSelectedPaths(newSelections)
                    gridDelegate.updateLastClickedIndex(index)
                }

                gridDelegate.itemRightClicked(model.rawPath, index, model.isFolder, mouse)
            }
        }
    }

    Column {
        anchors {
            fill: parent
            margins: 4
        }
        spacing: Theme.paddingSmall

        Item {
            id: previewContainer
            width: parent.width
            height: width
            scale: gridDelegate.hovered ? 1.03 : 1.0
            opacity: gridDelegate.hovered ? 1.0 : 0.95
            
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Rectangle {
                id: selectionCheckbox
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 6
                width: 20
                height: 20
                radius: 10
                color: gridDelegate.isMultiSelected ? Theme.selectionBackgroundActive : "#B0000000"
                border.color: "white"
                border.width: 1.5
                visible: !model.isFolder && (gridDelegate.isMultiSelected || gridDelegate.hovered)
                z: 10

                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    color: "white"
                    font.pixelSize: 11
                    font.bold: true
                    visible: gridDelegate.isMultiSelected
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: (mouse) => {
                        gridDelegate.selectionToggled(model.rawPath, index)
                    }
                }
            }
            
            Rectangle {
                anchors.fill: parent
                color: Theme.isDarkMode ? "#2D2D2D" : "#F0F0F0"
                radius: 4
                visible: model.isFolder || thumbnail.status !== Image.Ready
            }

            Rectangle {
                id: skeletonOverlay
                anchors.fill: parent
                color: Theme.isDarkMode ? "#3D3D3D" : "#E0E0E0"
                radius: 4
                visible: !model.isFolder && thumbnail.status === Image.Loading

                SequentialAnimation {
                    running: skeletonOverlay.visible
                    loops: Animation.Infinite
                    NumberAnimation {
                        target: skeletonOverlay
                        property: "opacity"
                        from: 0.3
                        to: 0.8
                        duration: 800
                        easing.type: Easing.InOutQuad
                    }
                    NumberAnimation {
                        target: skeletonOverlay
                        property: "opacity"
                        from: 0.8
                        to: 0.3
                        duration: 800
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: "📁"
                font.pixelSize: GridView.view ? Math.max(48, Math.min(128, GridView.view.cellWidth * 0.35)) : 64
                visible: model.isFolder
            }

            Image {
                id: thumbnail
                anchors {
                    fill: parent
                }
                visible: !model.isFolder
                readonly property var rotationTimestamp: (gridDelegate.rotationTimestamps && model && model.rawPath) ? gridDelegate.rotationTimestamps[model.rawPath] : undefined
                source: (model.isFolder || !getImageUrlHelper) ? "" : getImageUrlHelper(model.rawPath, rotationTimestamp)
                sourceSize: Qt.size(600, 600)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                opacity: (status === Image.Ready) ? 1.0 : 0.0
                Behavior on opacity {
                    enabled: thumbnail.status === Image.Ready
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutQuad
                    }
                }
                onStatusChanged: {
                    if (status === Image.Error && !model.isFolder) {
                        console.error("Failed to load thumbnail for:", model.rawPath)
                    }
                }
            }

            Rectangle {
                id: videoBadge
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: 6
                height: 18
                radius: 9
                color: "#CC1C1C1C"
                border.color: "#20FFFFFF"
                visible: !model.isFolder && model.isVideo
                
                // Query EXIF database cache for duration
                readonly property var exif: visible && typeof exifDatabaseSource !== "undefined" && exifDatabaseSource ? exifDatabaseSource.getExifData(model.rawPath) : null
                readonly property string durationText: (exif && exif.Duration) ? exif.Duration : ""
                readonly property string formatText: {
                    if (model.isFolder) return ""
                    let parts = model.rawPath.split('.')
                    return parts.length > 1 ? parts.pop().toUpperCase() : "VIDEO"
                }
                readonly property string displayLabel: durationText !== "" ? durationText : formatText

                // Make width dynamic based on row content
                width: badgeRow.implicitWidth + 12

                Row {
                    id: badgeRow
                    anchors.centerIn: parent
                    spacing: 3
                    
                    Text {
                        text: "▶"
                        color: "white"
                        font.pixelSize: 7
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Text {
                        text: videoBadge.displayLabel
                        color: "white"
                        font.pixelSize: 9
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        KaakaoLabel {
            width: parent.width
            text: model.fileName
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
            font.pixelSize: 11
            color: gridDelegate.isMultiSelected && (GridView.view && GridView.view.activeFocus) ? "#FFFFFF" : Theme.primaryText
        }
    }
}
