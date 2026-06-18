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

    // Backwards-compatibility alias for testing
    property alias sidebarModel: sidebarPanel.sidebarModel

    onRequestedVisibilityChanged: {
        if (fullScreenEnabled && visibility !== requestedVisibility) {
            root.visibility = requestedVisibility
        }
    }

    // Actions
    Action {
        id: addFolderAction
        text: qsTr("Add Folder...")
        onTriggered: sidebarPanel.triggerFolderDialog()
    }

    Action {
        id: removeFolderAction
        text: qsTr("Remove Folder")
        enabled: {
            if (sidebarPanel.currentIndex < 0 || sidebarPanel.currentIndex >= sidebarPanel.sidebarModel.count) return false;
            let item = sidebarPanel.sidebarModel.get(sidebarPanel.currentIndex);
            return item.category === qsTr("Folders") && item.path !== undefined;
        }
        onTriggered: sidebarPanel.triggerRemove(sidebarPanel.currentIndex)
    }

    Action {
        id: refreshAction
        text: qsTr("&Refresh")
        shortcut: "F5"
        onTriggered: {
            galleryModel.clear()
            root.loading = true
            let item = sidebarPanel.currentIndex >= 0 ? sidebarPanel.sidebarModel.get(sidebarPanel.currentIndex) : null
            if (item) {
                if (item.name === qsTr("Pictures") || item.name === "Pictures") {
                    discoveryService.scanDirectory("smart://pictures")
                } else if (item.name === qsTr("Videos") || item.name === "Videos") {
                    discoveryService.scanDirectory("smart://videos")
                } else if (item.name === qsTr("SD Card") || item.name === "SD Card") {
                    if (volumeMonitor.sdCardPath !== "") {
                        discoveryService.scanDirectory(volumeMonitor.sdCardPath + "/DCIM", true)
                    }
                } else if (item.path !== undefined && item.path !== "") {
                    discoveryService.scanDirectory(item.path, false)
                }
            }
        }
    }

    Action {
        id: settingsAction
        text: qsTr("&Settings...")
        shortcut: "Ctrl+,"
        onTriggered: settingsWindow.show()
    }

    Action {
        id: aboutAction
        text: qsTr("&About")
        onTriggered: aboutDialog.show()
    }

    Action {
        id: quitAction
        text: qsTr("&Quit")
        shortcut: "Ctrl+Q"
        onTriggered: Qt.quit()
    }

    Action {
        id: zoomInAction
        text: qsTr("Zoom In")
        shortcut: "Ctrl+="
        enabled: !previewOverlay.visible
        onTriggered: appSettings.thumbnailSize = Math.min(600, appSettings.thumbnailSize + 50)
    }

    Action {
        id: zoomOutAction
        text: qsTr("Zoom Out")
        shortcut: "Ctrl+-"
        enabled: !previewOverlay.visible
        onTriggered: appSettings.thumbnailSize = Math.max(200, appSettings.thumbnailSize - 50)
    }

    Action {
        id: actualSizeAction
        text: qsTr("Default Size")
        shortcut: "Ctrl+0"
        enabled: !previewOverlay.visible
        onTriggered: appSettings.thumbnailSize = 200
    }

    Action {
        id: toggleInfoAction
        text: root.showMainInfo ? qsTr("Hide &Info") : qsTr("Show &Info")
        shortcut: "Ctrl+I"
        enabled: galleryPanel.currentIndex >= 0 && galleryModel.count > 0
        onTriggered: root.showMainInfo = !root.showMainInfo
    }

    Action {
        id: quickLookAction
        text: root.inlinePreviewActive ? qsTr("Close Preview") : qsTr("Quick Look")
        shortcut: "Space"
        enabled: !previewOverlay.visible && galleryPanel.currentIndex >= 0 && !galleryModel.isFolder(galleryPanel.currentIndex)
        onTriggered: {
            if (root.inlinePreviewActive) {
                root.inlinePreviewActive = false
                galleryPanel.gridView.forceActiveFocus()
            } else {
                root.inlinePreviewActive = true
                inlinePreviewPanel.forceActiveFocus()
            }
        }
    }

    Action {
        id: rotateLeftAction
        text: qsTr("Rotate Counterclockwise")
        shortcut: "Ctrl+["
        enabled: {
            let idx = previewOverlay.visible ? previewOverlay.currentIndex : galleryPanel.currentIndex
            return root.isJpegFile(idx)
        }
        onTriggered: root.rotateImage(270)
    }

    Action {
        id: rotateRightAction
        text: qsTr("Rotate Clockwise")
        shortcut: "Ctrl+]"
        enabled: {
            let idx = previewOverlay.visible ? previewOverlay.currentIndex : galleryPanel.currentIndex
            return root.isJpegFile(idx)
        }
        onTriggered: root.rotateImage(90)
    }

    Action {
        id: showInFolderAction
        text: qsTr("Show in Finder")
        shortcut: "Ctrl+R"
        enabled: !previewOverlay.visible && galleryPanel.currentIndex >= 0
        onTriggered: {
            let path = galleryModel.getRawPath(galleryPanel.currentIndex)
            fileActionService.showInFolder(path)
        }
    }

    Action {
        id: deleteAction
        text: qsTr("Move to Trash")
        shortcut: "Delete"
        enabled: !previewOverlay.visible && galleryPanel.currentIndex >= 0 && !galleryModel.isFolder(galleryPanel.currentIndex)
        onTriggered: {
            let index = galleryPanel.currentIndex
            let path = galleryModel.getRawPath(index)
            let name = galleryModel.getFileName(index)
            if (appSettings.confirmDeletions) {
                galleryPanel.triggerDelete(index, path, name)
            } else {
                if (fileActionService.moveToTrash(path)) {
                    galleryModel.removeImage(index)
                }
            }
        }
    }

    Action {
        id: fullscreenPreviewAction
        text: qsTr("Show Fullscreen")
        shortcut: "Return"
        enabled: !previewOverlay.visible && galleryPanel.currentIndex >= 0 && !galleryModel.isFolder(galleryPanel.currentIndex)
        onTriggered: {
            previewOverlay.currentIndex = galleryPanel.currentIndex
            previewOverlay.visible = true
        }
    }

    Action {
        id: openExternallyAction
        text: qsTr("Open with Default Application")
        shortcut: "Ctrl+O"
        enabled: !previewOverlay.visible && galleryPanel.currentIndex >= 0 && !galleryModel.isFolder(galleryPanel.currentIndex)
        onTriggered: {
            let path = galleryModel.getRawPath(galleryPanel.currentIndex)
            fileActionService.openExternally(path)
        }
    }

    Action {
        id: copyAction
        text: qsTr("Copy")
        shortcut: "Ctrl+C"
        enabled: {
            let idx = previewOverlay.visible ? previewOverlay.currentIndex : galleryPanel.currentIndex
            return idx >= 0 && !galleryModel.isFolder(idx)
        }
        onTriggered: {
            let idx = previewOverlay.visible ? previewOverlay.currentIndex : galleryPanel.currentIndex
            let path = galleryModel.getRawPath(idx)
            fileActionService.copyToClipboard(path)
        }
    }

    Action {
        id: userGuideAction
        text: qsTr("User Guide")
        onTriggered: userGuideDialog.show()
    }

    Action {
        id: keyboardShortcutsAction
        text: qsTr("Keyboard Shortcuts")
        onTriggered: keyboardShortcutsDialog.show()
    }


    // Global helper shortcuts (bridged for alternative key sequences & compatibility)
    Shortcut {
        id: galleryShortcut
        objectName: "galleryShortcut"
        onActivated: quickLookAction.triggered(quickLookAction)
    }

    Shortcut {
        id: deleteShortcut
        objectName: "deleteShortcut"
        onActivated: deleteAction.triggered(deleteAction)
    }

    Shortcut {
        sequence: "Backspace"
        enabled: deleteAction.enabled && galleryPanel.gridView.activeFocus
        onActivated: deleteAction.trigger()
    }

    Shortcut {
        sequence: "Ctrl++"
        enabled: zoomInAction.enabled
        onActivated: zoomInAction.trigger()
    }

    Shortcut {
        sequence: "Enter"
        enabled: fullscreenPreviewAction.enabled && galleryPanel.gridView.activeFocus
        onActivated: fullscreenPreviewAction.trigger()
    }

    // Menu Bar
    menuBar: MenuBar {
        Menu {
            title: qsTr("&File")
            MenuItem { action: addFolderAction }
            MenuItem { action: removeFolderAction }
            MenuSeparator {}
            MenuItem { action: settingsAction }
            MenuSeparator {}
            MenuItem { action: quitAction }
        }
        Menu {
            title: qsTr("&Edit")
            MenuItem { action: copyAction }
        }
        Menu {
            title: qsTr("&View")
            MenuItem { action: refreshAction }
            MenuSeparator {}
            MenuItem { action: zoomInAction }
            MenuItem { action: zoomOutAction }
            MenuItem { action: actualSizeAction }
            MenuSeparator {}
            Menu {
                title: qsTr("Media Type")
                MenuItem {
                    text: qsTr("Show All")
                    checkable: true
                    checked: (typeof galleryModel !== "undefined" && galleryModel) ? galleryModel.mediaTypeFilter === "All" : true
                    onTriggered: galleryModel.mediaTypeFilter = "All"
                }
                MenuItem {
                    text: qsTr("Images")
                    checkable: true
                    checked: (typeof galleryModel !== "undefined" && galleryModel) ? galleryModel.mediaTypeFilter === "Photos" : false
                    onTriggered: galleryModel.mediaTypeFilter = "Photos"
                }
                MenuItem {
                    text: qsTr("Videos")
                    checkable: true
                    checked: (typeof galleryModel !== "undefined" && galleryModel) ? galleryModel.mediaTypeFilter === "Videos" : false
                    onTriggered: galleryModel.mediaTypeFilter = "Videos"
                }
            }
            MenuSeparator {}
            MenuItem { action: toggleInfoAction }
        }
        Menu {
            title: qsTr("&Image")
            MenuItem { action: quickLookAction }
            MenuItem { action: fullscreenPreviewAction }
            MenuItem { action: openExternallyAction }
            MenuSeparator {}
            MenuItem { action: rotateRightAction }
            MenuItem { action: rotateLeftAction }
            MenuSeparator {}
            MenuItem { action: showInFolderAction }
            MenuItem { action: deleteAction }
        }
        Menu {
            title: qsTr("&Help")
            MenuItem { action: userGuideAction }
            MenuItem { action: keyboardShortcutsAction }
            MenuSeparator {}
            MenuItem { action: aboutAction }
        }
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
            visible: root.showMainInfo && galleryPanel.currentIndex >= 0 && galleryModel.count > 0 && !galleryModel.isFolder(galleryPanel.currentIndex)
            
            currentPath: (galleryPanel.currentIndex >= 0 && !galleryModel.isFolder(galleryPanel.currentIndex)) ? galleryModel.getRawPath(galleryPanel.currentIndex) : ""
            fileName: (galleryPanel.currentIndex >= 0) ? galleryModel.getFileName(galleryPanel.currentIndex) : ""
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
