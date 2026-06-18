pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore
import Kaakao

Item {
    id: panel

    // Inputs/Configurations
    property bool confirmDeletions: true
    property bool loading: false
    property string currentFolderPath: ""
    property var folderSelections: ({})
    property int thumbnailSize: 200

    // Real path resolver
    readonly property string realFolderPath: {
        if (currentFolderPath === "sd_card_device") {
            return volumeMonitor.sdCardPath ? (volumeMonitor.sdCardPath + "/DCIM") : "";
        } else {
            return currentFolderPath;
        }
    }

    onRealFolderPathChanged: {
        filterScopeBar.currentIndex = 0;
        galleryModel.filterType = "All";
        galleryModel.cameraFilter = "";
        if (typeof mediaTypeFilter !== "undefined" && mediaTypeFilter) {
            mediaTypeFilter.activeIndex = 0;
        }
        galleryModel.mediaTypeFilter = "All";
        panel.updateFilters();
    }

    function updateFilters() {
        let baseFilters = [qsTr("All")];
        if (realFolderPath !== "" && typeof exifDatabase !== "undefined" && exifDatabase !== null) {
            let filterData = exifDatabase.getAvailableFiltersForFolder(realFolderPath);
            if (filterData.hasToday) {
                baseFilters.push(qsTr("Today"));
            }
            if (filterData.hasThisWeek) {
                baseFilters.push(qsTr("This Week"));
            }
            if (filterData.hasThisMonth) {
                baseFilters.push(qsTr("This Month"));
            }
            if (filterData.years) {
                for (let i = 0; i < filterData.years.length; i++) {
                    baseFilters.push(filterData.years[i]);
                }
            }
            if (filterData.imageTypes) {
                for (let i = 0; i < filterData.imageTypes.length; i++) {
                    baseFilters.push(filterData.imageTypes[i]);
                }
            }
            let cameras = exifDatabase.getUniqueCamerasForFolder(realFolderPath);
            filterScopeBar.model = baseFilters.concat(cameras);
        } else {
            filterScopeBar.model = baseFilters;
        }
    }

    Connections {
        target: typeof discoveryService !== "undefined" ? discoveryService : null
        function onIndexingFinished() {
            panel.updateFilters();
        }
    }

    // Signals
    signal folderSelectionsUpdated(var selections)
    signal doubleClicked(int index)
    signal folderDoubleClicked(string path, string name)

    // Expose internal items
    property alias currentIndex: galleryGrid.currentIndex
    readonly property alias gridView: galleryGrid.gridView

    function triggerDelete(index, path, name) {
        deleteConfirmationDialog.targetIndex = index
        deleteConfirmationDialog.targetPath = path
        deleteConfirmationDialog.fileName = name
        deleteConfirmationDialog.open()
    }

    KaakaoSheet {
        id: deleteConfirmationDialog
        objectName: "deleteConfirmationDialog"
        width: 400
        height: 170
        property int targetIndex: -1
        property string targetPath: ""
        property string fileName: ""

        contentItem: Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            KaakaoLabel {
                text: qsTr("Move to Trash")
                font.weight: Font.Bold
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
            }

            Row {
                width: parent.width
                spacing: 16
                
                Text {
                    text: "🗑️"
                    font.pixelSize: 36
                    verticalAlignment: Text.AlignTop
                }

                KaakaoLabel {
                    text: qsTr("Are you sure you want to move \"%1\" to the Trash?").arg(deleteConfirmationDialog.fileName)
                    width: parent.width - 36 - 16
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignTop
                    lineHeight: 1.15
                }
            }

            Item {
                width: 1
                height: 8
            }

            Row {
                anchors.right: parent.right
                spacing: 8
                
                KaakaoButton {
                    text: qsTr("Cancel")
                    onClicked: deleteConfirmationDialog.close()
                }
                KaakaoButton {
                    text: qsTr("Move to Trash")
                    highlighted: true
                    onClicked: {
                        if (deleteConfirmationDialog.targetIndex >= 0 && deleteConfirmationDialog.targetPath !== "") {
                            if (fileActionService.moveToTrash(deleteConfirmationDialog.targetPath)) {
                                galleryModel.removeImage(deleteConfirmationDialog.targetIndex)
                            }
                        }
                        deleteConfirmationDialog.close()
                    }
                }
            }
        }
    }

    KaakaoMenu {
        id: galleryContextMenu
        property int targetIndex: -1
        property string targetPath: ""
        KaakaoMenuItem {
            text: Qt.platform.os === "osx" ? qsTr("Reveal in Finder") : qsTr("Show in File Manager")
            onTriggered: fileActionService.showInFolder(galleryContextMenu.targetPath)
        }
        KaakaoMenuItem {
            text: qsTr("Open with Default Application")
            onTriggered: fileActionService.openExternally(galleryContextMenu.targetPath)
        }
        MenuSeparator {}
        KaakaoMenuItem {
            text: qsTr("Rotate Left")
            enabled: root.isJpegFile(galleryContextMenu.targetIndex)
            onTriggered: root.rotateImage(270)
        }
        KaakaoMenuItem {
            text: qsTr("Rotate Right")
            enabled: root.isJpegFile(galleryContextMenu.targetIndex)
            onTriggered: root.rotateImage(90)
        }
        MenuSeparator {}
        KaakaoMenuItem {
            text: qsTr("Move to Trash")
            onTriggered: {
                let index = galleryContextMenu.targetIndex
                let path = galleryContextMenu.targetPath
                let name = galleryModel.getFileName(index)
                if (panel.confirmDeletions) {
                    deleteConfirmationDialog.targetIndex = index
                    deleteConfirmationDialog.targetPath = path
                    deleteConfirmationDialog.fileName = name
                    deleteConfirmationDialog.open()
                } else {
                    if (fileActionService.moveToTrash(path)) {
                        galleryModel.removeImage(index)
                    }
                }
            }
        }
    }

    KaakaoMenu {
        id: folderContextMenu
        property int targetIndex: -1
        property string targetPath: ""
        KaakaoMenuItem {
            text: Qt.platform.os === "osx" ? qsTr("Reveal in Finder") : qsTr("Show in File Manager")
            onTriggered: fileActionService.showInFolder(folderContextMenu.targetPath)
        }
    }

    // Background extension for the scope bar area on the right to ensure a continuous bar
    Rectangle {
        id: scopeBarExtension
        anchors {
            top: parent.top
            left: filterScopeBar.right
            right: parent.right
        }
        height: 24
        color: Theme.isDarkMode ? "#262626" : "#E1E1E1"
        visible: currentFolderPath !== ""

        // 1px solid bottom border to match the scope bar
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.isDarkMode ? "#121212" : "#B0B0B0"
        }
    }

    // Segmented Media Type Control on the right side of the scope bar
    Rectangle {
        id: mediaTypeFilter
        anchors {
            right: parent.right
            top: parent.top
            rightMargin: 8
            topMargin: 3
        }
        width: segmentRow.implicitWidth + 4
        height: 18
        radius: 4
        color: Theme.isDarkMode ? "#262626" : "#E1E1E1"
        border.color: Theme.isDarkMode ? "#3F3F3F" : "#D0D0D0"
        border.width: 1
        visible: currentFolderPath !== ""

        property int activeIndex: 0 // 0: All, 1: Photos, 2: Videos

        Row {
            id: segmentRow
            anchors.centerIn: parent
            spacing: 1

            Repeater {
                model: [qsTr("All"), qsTr("Photos"), qsTr("Videos")]
                delegate: Basic.Button {
                    id: segButton
                    required property string modelData
                    required property int index

                    implicitHeight: 14
                    implicitWidth: segText.implicitWidth + 12
                    padding: 0

                    Gradient {
                        id: selectionGradient
                        GradientStop { position: 0.0; color: Theme.segmentedSelectionGradTop }
                        GradientStop { position: 1.0; color: Theme.segmentedSelectionGradBottom }
                    }

                    background: Rectangle {
                        radius: 3
                        gradient: mediaTypeFilter.activeIndex === index ? selectionGradient : null
                        color: {
                            if (mediaTypeFilter.activeIndex === index) {
                                return "transparent"
                            }
                            if (segButton.hovered) {
                                return Theme.isDarkMode ? "#3D3D3D" : "#E5E5E5"
                            }
                            return "transparent"
                        }
                        border.color: mediaTypeFilter.activeIndex === index ? Theme.buttonBorder : "transparent"
                        border.width: mediaTypeFilter.activeIndex === index ? 1 : 0
                    }

                    contentItem: Text {
                        id: segText
                        text: modelData
                        font.family: Theme.defaultFont.family
                        font.pixelSize: 10
                        font.weight: mediaTypeFilter.activeIndex === index ? Font.Bold : Font.Normal
                        color: Theme.primaryText
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        renderType: Text.NativeRendering
                    }

                    onClicked: {
                        mediaTypeFilter.activeIndex = index
                        if (index === 0) {
                            galleryModel.mediaTypeFilter = "All"
                        } else if (index === 1) {
                            galleryModel.mediaTypeFilter = "Photos"
                        } else if (index === 2) {
                            galleryModel.mediaTypeFilter = "Videos"
                        }
                    }
                }
            }
        }
    }

    KaakaoScopeBar {
        id: filterScopeBar
        objectName: "filterScopeBar"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: mediaTypeFilter.left
        anchors.rightMargin: 10
        height: visible ? 24 : 0
        visible: currentFolderPath !== ""
        label: qsTr("Filter:")
        model: [qsTr("All")]
        currentIndex: 0

        onFilterSelected: (index, name) => {
            if (name === qsTr("All")) {
                galleryModel.filterType = "All"
                galleryModel.cameraFilter = ""
            } else if (name === qsTr("Today")) {
                galleryModel.filterType = "Today"
                galleryModel.cameraFilter = ""
            } else if (name === qsTr("This Week")) {
                galleryModel.filterType = "This Week"
                galleryModel.cameraFilter = ""
            } else if (name === qsTr("This Month")) {
                galleryModel.filterType = "This Month"
                galleryModel.cameraFilter = ""
            } else if (!isNaN(parseInt(name)) && name.length === 4) {
                galleryModel.filterType = name
                galleryModel.cameraFilter = ""
            } else if (name === "JPG" || name === "PNG" || name === "WEBP" || name === "BMP" || name === "MP4" || name === "MOV") {
                galleryModel.filterType = name
                galleryModel.cameraFilter = ""
            } else {
                galleryModel.filterType = "Camera"
                galleryModel.cameraFilter = name
            }
        }
    }

    KaakaoGridView {
        id: galleryGrid
        objectName: "galleryGrid"
        anchors.top: filterScopeBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        
        model: galleryModel
        cellWidth: panel.thumbnailSize
        cellHeight: panel.thumbnailSize + 30

        WheelHandler {
            id: wheelZoomHandler
            acceptedModifiers: Qt.ControlModifier
            onWheel: (event) => {
                let current = panel.thumbnailSize;
                let target = current;
                if (event.angleDelta.y > 0) {
                    target = Math.min(600, current + 50);
                } else if (event.angleDelta.y < 0) {
                    target = Math.max(200, current - 50);
                }
                if (target !== current) {
                    if (typeof appSettings !== "undefined") {
                        appSettings.thumbnailSize = target;
                    } else {
                        panel.thumbnailSize = target;
                    }
                }
            }
        }
        
        
        gridView.onCurrentIndexChanged: {
            if (panel.loading && gridView.currentIndex !== -1) {
                gridView.currentIndex = -1;
            } else if (!panel.loading) {
                if (panel.currentFolderPath) {
                    let selections = panel.folderSelections;
                    selections[panel.currentFolderPath] = gridView.currentIndex;
                    panel.folderSelectionsUpdated(selections);
                }
            }
        }

        gridView.onActiveFocusChanged: {
            if (gridView.activeFocus && gridView.currentIndex === -1 && galleryModel.count > 0) {
                gridView.currentIndex = 0;
            }
        }

        delegate: KaakaoGridDelegate {
            id: gridDelegate
            required property var model
            required property int index

            width: galleryGrid.cellWidth
            height: galleryGrid.cellHeight
            background: Rectangle {
                anchors.fill: parent
                
                color: {
                    if (gridDelegate.isSelected) {
                        // If the grid has focus, use Active Selection BG. Otherwise, use Inactive Selection BG.
                        if (gridDelegate.GridView.view && gridDelegate.GridView.view.activeFocus)
                            return Theme.selectionBackgroundActive;
                        return Theme.selectionBackgroundInactive;
                    }
                    return "transparent"
                }
            }


            onDoubleClicked: {
                if (model.isFolder) {
                    panel.folderDoubleClicked(model.rawPath, model.fileName)
                } else {
                    panel.doubleClicked(index)
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        galleryGrid.gridView.currentIndex = index
                        galleryGrid.gridView.forceActiveFocus()
                        if (model.isFolder) {
                            folderContextMenu.targetIndex = index
                            folderContextMenu.targetPath = model.rawPath
                            folderContextMenu.popup()
                        } else {
                            galleryContextMenu.targetIndex = index
                            galleryContextMenu.targetPath = model.rawPath
                            galleryContextMenu.popup()
                        }
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
                        font.pixelSize: Math.max(48, Math.min(128, galleryGrid.cellWidth * 0.35))
                        visible: model.isFolder
                    }

                    Image {
                        id: thumbnail
                        anchors {
                            fill: parent
                        }
                        visible: !model.isFolder
                        source: model.isFolder ? "" : root.getImageUrl(model.rawPath)
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
                        readonly property var exif: visible && typeof exifDatabase !== "undefined" && exifDatabase ? exifDatabase.getExifData(model.rawPath) : null
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
                    color: isSelected && galleryGrid.gridView.activeFocus ? "#FFFFFF" : Theme.primaryText
                }
            }
        }
    }

    // Empty state overlay — shown when grid has no items
    Item {
        anchors {
            top: filterScopeBar.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        visible: galleryModel.count === 0 && !panel.loading && panel.currentFolderPath !== ""

        Column {
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (galleryModel.searchQuery !== "" || galleryModel.filterType !== "All") ? "🔍" : "📂"
                font.pixelSize: 40
            }
            KaakaoLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (galleryModel.searchQuery !== "" || galleryModel.filterType !== "All")
                      ? qsTr("No matching images")
                      : qsTr("No images found")
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            KaakaoLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (galleryModel.searchQuery !== "" || galleryModel.filterType !== "All")
                      ? qsTr("Try a different search or filter")
                      : qsTr("This folder contains no supported images")
                color: Theme.secondaryText
                font.pixelSize: 11
            }
        }
    }

    // Scanning status indicator
    KaakaoActivityOverlay {
        anchors {
            top: filterScopeBar.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        active: panel.loading
        text: qsTr("Scanning directory...")
    }
}
