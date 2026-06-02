pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
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

    // Real path resolver
    readonly property string realFolderPath: {
        if (currentFolderPath === "pictures_library") {
            return StandardPaths.writableLocation(StandardPaths.PicturesLocation);
        } else if (currentFolderPath === "sd_card_device") {
            return volumeMonitor.sdCardPath ? (volumeMonitor.sdCardPath + "/DCIM") : "";
        } else {
            return currentFolderPath;
        }
    }

    onRealFolderPathChanged: {
        filterScopeBar.currentIndex = 0;
        galleryModel.filterType = "All";
        galleryModel.cameraFilter = "";
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
            text: qsTr("Reveal in Finder")
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
            text: qsTr("Reveal in Finder")
            onTriggered: fileActionService.showInFolder(folderContextMenu.targetPath)
        }
    }

    KaakaoScopeBar {
        id: filterScopeBar
        objectName: "filterScopeBar"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
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
            } else if (name === "JPG" || name === "PNG" || name === "WEBP" || name === "BMP") {
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
        cellWidth: 110
        cellHeight: 140
        
        
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
                    width: parent.width
                    height: width
                    
                    Rectangle {
                        anchors.fill: parent
                        color: Theme.isDarkMode ? "#2D2D2D" : "#F0F0F0"
                        radius: 4
                        visible: model.isFolder || thumbnail.status !== Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "📁"
                        font.pixelSize: 48
                        visible: model.isFolder
                    }

                    Image {
                        id: thumbnail
                        anchors {
                            fill: parent
                        }
                        visible: !model.isFolder
                        source: model.isFolder ? "" : root.getImageUrl(model.rawPath)
                        sourceSize: Qt.size(200, 200)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        onStatusChanged: {
                            if (status === Image.Error && !model.isFolder) {
                                console.error("Failed to load thumbnail for:", model.rawPath)
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
}
