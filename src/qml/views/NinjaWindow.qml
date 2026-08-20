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

    function getImageUrl(filePath, timestamp) {
        if (!filePath) return "";
        let t = timestamp !== undefined ? timestamp : rotationTimestamps[filePath];
        return "image://gallery/" + filePath + (t ? ("?t=" + t) : "");
    }

    function forceRefreshImage(filePath) {
        let t = Date.now();
        let copy = Object.assign({}, rotationTimestamps);
        copy[filePath] = t;
        rotationTimestamps = copy;
    }

    function forceRefreshImagesBatch(filePaths) {
        let t = Date.now();
        let copy = Object.assign({}, rotationTimestamps);
        for (let i = 0; i < filePaths.length; ++i) {
            copy[filePaths[i]] = t + i;
        }
        rotationTimestamps = copy;
    }

    function canRotatePath(filePath) {
        if (!filePath) return false;
        let p = String(filePath).toLowerCase();
        return p.endsWith(".jpg") || p.endsWith(".jpeg");
    }

    function rotatePath(path, angle) {
        if (!path || !canRotatePath(path)) return;
        let result = fileActionService.rotateImage(path, angle);
        if (result === 0) {
            forceRefreshImage(path);
        } else if (result === 1) {
            forceRefreshImage(path);
            rotationWarningDialog.open();
        }
    }

    function rotateImage(angle) {
        let index = previewOverlay.visible ? previewOverlay.currentIndex : galleryPanel.currentIndex;
        if (index < 0 || galleryModel.isFolder(index)) {
            return;
        }
        let path = galleryModel.getRawPath(index);
        rotatePath(path, angle);
    }

    function isJpegFile(idx) {
        if (idx < 0 || !galleryModel || idx >= galleryModel.count || galleryModel.isFolder(idx)) {
            return false;
        }
        return canRotatePath(galleryModel.getRawPath(idx));
    }

    function canRotateSelection() {
        if (previewOverlay.visible) {
            return canRotatePath(previewOverlay.currentImagePath);
        }
        if (galleryPanel.selectedCount > 0) {
            let paths = galleryPanel.getSelectedPathsList();
            for (let i = 0; i < paths.length; ++i) {
                if (canRotatePath(paths[i])) return true;
            }
            return false;
        }
        let idx = galleryPanel.currentIndex;
        return root.isJpegFile(idx);
    }

    function rotateSelection(angle) {
        if (previewOverlay.visible) {
            rotateImage(angle);
            return;
        }
        if (galleryPanel.selectedCount > 0) {
            let paths = galleryPanel.getSelectedPathsList();
            let jpegs = [];
            for (let i = 0; i < paths.length; ++i) {
                if (canRotatePath(paths[i])) {
                    jpegs.push(paths[i]);
                }
            }
            if (jpegs.length === 1) {
                rotatePath(jpegs[0], angle);
            } else if (jpegs.length > 1) {
                let result = fileActionService.rotateImagesBatch(jpegs, angle);
                root.forceRefreshImagesBatch(jpegs);
                if (result === 1) {
                    rotationWarningDialog.open();
                }
            }
        } else {
            root.rotateImage(angle);
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
        function onFileRenamed(oldPath, newPath) {
            galleryModel.updateItemPath(oldPath, newPath)
            if (galleryPanel.selectedPaths[oldPath]) {
                let copy = Object.assign({}, galleryPanel.selectedPaths)
                delete copy[oldPath]
                copy[newPath] = true
                galleryPanel.selectedPaths = copy
            }
            if (root.rotationTimestamps[oldPath] !== undefined) {
                let copy = Object.assign({}, root.rotationTimestamps)
                copy[newPath] = copy[oldPath]
                delete copy[oldPath]
                root.rotationTimestamps = copy
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

    RenameDialog {
        id: renameDialog
        objectName: "renameDialog"
    }

    function openRenameDialog(path) {
        if (!path) return
        renameDialog.openForPath(path)
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
        property string viewMode: "grid"
        property int listRowHeight: 28
        property int nameColumnWidth: 300
        property int dimsColumnWidth: 90
        property int dateColumnWidth: 150
        property int sizeColumnWidth: 70
    }

    function navigateToFolder(path, name) {
        root.currentTitle = name
        root.currentFolderDescription = path
        sidebarPanel.sidebar.currentIndex = -1
        galleryModel.clear()
        root.loading = true
        discoveryService.scanDirectory(path, false)
    }

    function getCurrentFolderPath() {        if (root.currentFolderDescription.startsWith("smart://")) {
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
                    listRowHeight: appSettings.listRowHeight
                    viewMode: appSettings.viewMode
                    canRotate: root.canRotateSelection()

                    onRotateImage: (angle) => root.rotateSelection(angle)
                    onToggleShowMainInfo: root.showMainInfo = !root.showMainInfo
                    onViewModeRequested: (mode) => {
                        appSettings.viewMode = mode
                    }
                    onListRowHeightChanged: {
                        appSettings.listRowHeight = listRowHeight
                    }
                    onPathClicked: (fullPath, name) => {
                        root.navigateToFolder(fullPath, name)
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
                    viewMode: appSettings.viewMode
                    listRowHeight: appSettings.listRowHeight
                    rotationTimestamps: root.rotationTimestamps

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
                        root.navigateToFolder(localPath, name)
                    }

                    onParentFolderRequested: {
                        let folderKey = root.getCurrentFolderPath()
                        if (folderKey === "" || folderKey.startsWith("smart://") || folderKey === "sd_card_device") {
                            return
                        }
                        let current = folderKey
                        if (current.endsWith("/") && current.length > 1) {
                            current = current.substring(0, current.length - 1)
                        }
                        let idx = current.lastIndexOf("/")
                        if (idx <= 0) {
                            return // already at filesystem root
                        }
                        let parentPath = current.substring(0, idx)
                        let name = parentPath.substring(parentPath.lastIndexOf("/") + 1)
                        root.navigateToFolder(parentPath, name)
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
                    rotationTimestamps: root.rotationTimestamps

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
        rotationTimestamps: root.rotationTimestamps
        z: 100
    }
}
