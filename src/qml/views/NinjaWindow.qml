pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore
import Kaakao
import NinjaView

KaakaoWindow {
    id: root
    visible: true
    visibility: Window.Windowed
    width: 900
    height: 600
    title: qsTr("NinjaView")

    // Properties / Aliases
    readonly property bool fullScreenEnabled: allowFullScreen
    readonly property int requestedVisibility: previewOverlay.visible ? Window.FullScreen : Window.Windowed
    property bool showMainInfo: false
    property string currentTitle: qsTr("Pictures")
    property string currentFolderDescription: ""
    property bool loading: false
    property var folderSelections: ({})
    property var rotationTimestamps: ({})
    property bool inlinePreviewActive: false
    property alias galleryPanel: galleryPanel

    function getImageUrl(filePath) {
        if (!filePath) return "";
        let t = rotationTimestamps[filePath];
        return "image://gallery/" + filePath + (t ? ("?t=" + t) : "");
    }

    function forceRefreshImage(filePath) {
        let t = Date.now();
        let copy = Object.assign({}, rotationTimestamps);
        copy[filePath] = t;
        rotationTimestamps = copy;
    }

    function rotateImage(angle) {
        let index = previewOverlay.visible ? previewOverlay.currentIndex : galleryPanel.currentIndex;
        if (index < 0 || galleryModel.isFolder(index)) {
            return;
        }
        let path = galleryModel.getRawPath(index);
        let result = fileActionService.rotateImage(path, angle);
        if (result === 0) {
            forceRefreshImage(path);
        } else if (result === 1) {
            forceRefreshImage(path);
            rotationWarningDialog.open();
        }
    }

    function isJpegFile(idx) {
        if (idx < 0 || !galleryModel || idx >= galleryModel.count || galleryModel.isFolder(idx)) {
            return false;
        }
        let path = String(galleryModel.getRawPath(idx)).toLowerCase();
        return path.endsWith(".jpg") || path.endsWith(".jpeg");
    }

    function canRotateSelection() {
        if (galleryPanel.selectedCount > 0) {
            let paths = galleryPanel.getSelectedPathsList();
            for (let i = 0; i < paths.length; ++i) {
                let p = paths[i].toLowerCase();
                if (p.endsWith(".jpg") || p.endsWith(".jpeg")) return true;
            }
            return false;
        }
        let idx = previewOverlay.visible ? previewOverlay.currentIndex : galleryPanel.currentIndex;
        return root.isJpegFile(idx);
    }

    function rotateSelection(angle) {
        if (galleryPanel.selectedCount > 0) {
            let paths = galleryPanel.getSelectedPathsList();
            let jpegs = [];
            for (let i = 0; i < paths.length; ++i) {
                let p = paths[i].toLowerCase();
                if (p.endsWith(".jpg") || p.endsWith(".jpeg")) {
                    jpegs.push(paths[i]);
                }
            }
            if (jpegs.length > 0) {
                fileActionService.rotateImagesBatch(jpegs, angle)
                for (let i = 0; i < jpegs.length; ++i) {
                    root.forceRefreshImage(jpegs[i]);
                }
            }
        } else {
            root.rotateImage(angle)
        }
    }

    // Backwards-compatibility alias for testing
    property alias sidebarModel: sidebarPanel.sidebarModel

    onRequestedVisibilityChanged: {
        if (fullScreenEnabled && visibility !== requestedVisibility) {
            root.visibility = requestedVisibility
        }
    }

    NinjaActions {
        id: actions
        rootWindow: root
        galleryPanel: galleryPanel
        sidebarPanel: sidebarPanel
        previewOverlay: previewOverlay
        settingsWindow: settingsWindow
        aboutDialog: aboutDialog
        keyboardShortcutsDialog: keyboardShortcutsDialog
        userGuideDialog: userGuideDialog
        appSettings: appSettings
        inlinePreviewPanel: inlinePreviewPanel
    }

    menuBar: NinjaMenuBar {
        actions: actions
    }

    SettingsWindow {
        id: settingsWindow
    }

    AboutDialog {
        id: aboutDialog
    }

    KeyboardShortcutsDialog {
        id: keyboardShortcutsDialog
    }

    UserGuideDialog {
        id: userGuideDialog
    }

    MessageDialog {
        id: importResultDialog
        title: qsTr("Import to Photos")
        buttons: MessageDialog.Ok
    }

    Connections {
        target: fileActionService
        function onImportFinished(success, errorMessage) {
            if (success) {
                importResultDialog.text = qsTr("Import Completed")
                importResultDialog.informativeText = qsTr("Media files have been successfully imported to Apple Photos.")
                importResultDialog.open()
            } else {
                importResultDialog.text = qsTr("Import Failed")
                importResultDialog.informativeText = errorMessage
                importResultDialog.open()
            }
        }
    }

    MessageDialog {
        id: rotationWarningDialog
        title: qsTr("Read-Only Image")
        text: qsTr("This image file is not writable.")
        informativeText: qsTr("NinjaView will display the rotated image for this session, but the changes cannot be saved back to the file.")
        buttons: MessageDialog.Ok
    }

    Settings {
        id: appSettings
        property alias x: root.x
        property alias y: root.y
        property alias width: root.width
        property alias height: root.height
        property string savedFolders: "[]"
        property int maxMemoryCacheSizeMB: 2048
        property bool confirmDeletions: true
        property int thumbnailSize: 200
    }

    function getCurrentFolderPath() {
        if (root.currentFolderDescription.startsWith("smart://")) {
            return root.currentFolderDescription;
        }
        if (typeof sidebarPanel !== "undefined" && sidebarPanel && sidebarPanel.blockNavigation) {
            return (typeof galleryModel !== "undefined" && galleryModel) ? galleryModel.currentFolderPath : root.currentFolderDescription;
        }
        if (sidebarPanel.currentIndex < 0 || sidebarPanel.currentIndex >= sidebarPanel.sidebarModel.count) {
            return root.currentFolderDescription;
        }
        let item = sidebarPanel.sidebarModel.get(sidebarPanel.currentIndex);
        if (!item) return root.currentFolderDescription;
        
        if (item.name === qsTr("Pictures") || item.name === "Pictures") {
            return "smart://pictures";
        } else if (item.name === qsTr("Videos") || item.name === "Videos") {
            return "smart://videos";
        } else if (item.name === qsTr("SD Card") || item.name === "SD Card") {
            return "sd_card_device";
        } else if (item.path !== undefined && item.path !== "") {
            return item.path;
        }
        return root.currentFolderDescription;
    }

    Component.onCompleted: {
        // Sync cache size setting with C++ provider
        if (typeof imageProvider !== "undefined" && imageProvider) {
            imageProvider.maxMemoryCacheSize = appSettings.maxMemoryCacheSizeMB * 1024 * 1024
        }
        
        if (typeof isSelfTest !== "undefined" && isSelfTest) {
            console.log("Self-test mode: keeping dummy data in gallery model")
            return
        }
        console.log("Starting initial scan of Pictures library")
        galleryModel.clear()
        root.loading = true
        discoveryService.scanDirectory("smart://pictures")
    }

    Connections {
        target: volumeMonitor
        function onSdCardPathChanged() {
            let item = sidebarPanel.currentIndex >= 0 ? sidebarPanel.sidebarModel.get(sidebarPanel.currentIndex) : null
            if (item && (item.name === qsTr("SD Card") || item.name === "SD Card") && volumeMonitor.sdCardPath !== "") {
                console.log("SD Card detected, scanning:", volumeMonitor.sdCardPath)
                galleryModel.clear()
                discoveryService.scanDirectory(volumeMonitor.sdCardPath + "/DCIM", true)
            }
        }
    }

    Binding {
        target: galleryModel
        property: "currentFolderPath"
        value: root.getCurrentFolderPath()
    }

    Connections {
        target: discoveryService
        function onScanFinished() {
            root.loading = false
            let pathKey = root.getCurrentFolderPath()
            let savedIndex = root.folderSelections[pathKey]
            if (savedIndex !== undefined && savedIndex >= 0 && savedIndex < galleryModel.count) {
                galleryPanel.currentIndex = savedIndex
            } else {
                galleryPanel.currentIndex = -1
            }
        }
    }

    KaakaoSplitView {
        anchors.fill: parent
        orientation: Qt.Horizontal

        SidebarPanel {
            id: sidebarPanel
            settings: appSettings
            SplitView.preferredWidth: 200
            SplitView.minimumWidth: 150
            SplitView.maximumWidth: 300

            onDirectorySelected: (name, path, isPictures, isVideos, isSdCard) => {
                root.currentTitle = name
                root.currentFolderDescription = ""
                
                if (isPictures) {
                    galleryModel.clear()
                    root.loading = true
                    discoveryService.scanDirectory("smart://pictures")
                } else if (isVideos) {
                    galleryModel.clear()
                    root.loading = true
                    discoveryService.scanDirectory("smart://videos")
                } else if (isSdCard) {
                    if (volumeMonitor.sdCardPath !== "") {
                        galleryModel.clear()
                        root.loading = true
                        discoveryService.scanDirectory(volumeMonitor.sdCardPath + "/DCIM", true)
                    } else {
                        galleryModel.clear()
                        console.log("No SD Card detected")
                    }
                } else if (path !== "") {
                    root.currentFolderDescription = path
                    galleryModel.clear()
                    root.loading = true
                    discoveryService.scanDirectory(path, false)
                }
            }
        }

        Item {
            SplitView.fillWidth: true
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                NinjaToolBar {
                    id: mainToolBar
                    objectName: "mainToolBar"
                    Layout.fillWidth: true
                    
                    currentFolderDescription: root.currentFolderDescription
                    currentTitle: root.currentTitle
                    previewOverlayCurrentIndex: root.inlinePreviewActive ? galleryPanel.currentIndex : previewOverlay.currentIndex
                    galleryPanelCurrentIndex: galleryPanel.currentIndex
                    previewOverlayVisible: previewOverlay.visible || root.inlinePreviewActive
                    showMainInfo: root.showMainInfo
                    thumbnailSize: appSettings.thumbnailSize
                    
                    onRotateImage: (angle) => root.rotateImage(angle)
                    onToggleShowMainInfo: root.showMainInfo = !root.showMainInfo
                    onPathClicked: (fullPath, name) => {
                        root.currentTitle = name
                        root.currentFolderDescription = fullPath
                        sidebarPanel.sidebar.currentIndex = -1
                        galleryModel.clear()
                        root.loading = true
                        discoveryService.scanDirectory(fullPath, false)
                    }
                    onThumbnailSizeChanged: {
                        appSettings.thumbnailSize = thumbnailSize
                    }
                }

                GalleryPanel {
                    id: galleryPanel
                    objectName: "galleryPanel"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: !root.inlinePreviewActive

                    confirmDeletions: appSettings.confirmDeletions
                    loading: root.loading
                    currentFolderPath: root.getCurrentFolderPath()
                    folderSelections: root.folderSelections
                    thumbnailSize: appSettings.thumbnailSize

                    onFolderSelectionsUpdated: (selections) => {
                        root.folderSelections = selections
                    }

                    onDoubleClicked: (index) => {
                        previewOverlay.currentIndex = index
                        previewOverlay.visible = true
                    }

                    onFolderDoubleClicked: (path, name) => {
                        let localPath = path
                        if (path.startsWith("file://")) {
                            localPath = path.substring(7)
                        }
                        root.currentTitle = name
                        root.currentFolderDescription = localPath
                        sidebarPanel.sidebar.currentIndex = -1
                        galleryModel.clear()
                        root.loading = true
                        discoveryService.scanDirectory(localPath, false)
                    }
                }

                InlinePreviewPanel {
                    id: inlinePreviewPanel
                    objectName: "inlinePreviewPanel"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.inlinePreviewActive

                    model: galleryModel
                    currentIndex: galleryPanel.currentIndex
                    getImageUrl: root.getImageUrl

                    onCloseRequested: {
                        root.inlinePreviewActive = false
                        galleryPanel.gridView.forceActiveFocus()
                    }
                    onRequestIndexChange: (index) => {
                        galleryPanel.currentIndex = index
                    }
                }
            }
        }

        ImageInfoPanel {
            id: mainInfoPanel
            objectName: "mainInfoPanel"
            SplitView.preferredWidth: 250
            SplitView.minimumWidth: 200
            visible: root.showMainInfo && galleryPanel.currentFolderPath !== ""
            
            selectedPathsList: galleryPanel.selectedPathsList
            currentPath: (galleryPanel.selectedCount === 1) ? galleryPanel.selectedPathsList[0] : ""
            fileName: (galleryPanel.selectedCount === 1) ? galleryModel.getFileName(galleryPanel.lastClickedIndex) : ""
        }
    }

    PreviewOverlay {
        id: previewOverlay
        objectName: "previewOverlay"
        model: galleryModel
        getImageUrl: root.getImageUrl
        rotateImage: root.rotateImage
        z: 100
    }
}
