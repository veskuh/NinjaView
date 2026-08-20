import QtQuick
import QtQuick.Controls
import QtCore
import NinjaView

Item {
    id: actionsProvider

    required property var rootWindow
    required property var galleryPanel
    required property var sidebarPanel
    required property var previewOverlay
    required property var settingsWindow
    required property var aboutDialog
    required property var keyboardShortcutsDialog
    required property var userGuideDialog
    required property var appSettings
    required property var inlinePreviewPanel

    // Action Aliases
    property alias addFolderAction: addFolderAction
    property alias removeFolderAction: removeFolderAction
    property alias refreshAction: refreshAction
    property alias settingsAction: settingsAction
    property alias aboutAction: aboutAction
    property alias quitAction: quitAction
    property alias zoomInAction: zoomInAction
    property alias zoomOutAction: zoomOutAction
    property alias actualSizeAction: actualSizeAction
    property alias gridViewAction: gridViewAction
    property alias listViewAction: listViewAction
    property alias toggleInfoAction: toggleInfoAction
    property alias showNewOnlyAction: showNewOnlyAction
    property alias importToPhotosAction: importToPhotosAction
    property alias quickLookAction: quickLookAction
    property alias rotateLeftAction: rotateLeftAction
    property alias rotateRightAction: rotateRightAction
    property alias showInFolderAction: showInFolderAction
    property alias deleteAction: deleteAction
    property alias fullscreenPreviewAction: fullscreenPreviewAction
    property alias openExternallyAction: openExternallyAction
    property alias copyAction: copyAction
    property alias userGuideAction: userGuideAction
    property alias keyboardShortcutsAction: keyboardShortcutsAction

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
            rootWindow.loading = true
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
        objectName: "zoomInAction"
        text: qsTr("Zoom In")
        shortcut: "Ctrl+="
        enabled: !previewOverlay.visible
        onTriggered: {
            if (appSettings.viewMode === "list") {
                appSettings.listRowHeight = Math.min(48, appSettings.listRowHeight + 4)
            } else {
                appSettings.thumbnailSize = Math.min(600, appSettings.thumbnailSize + 50)
            }
        }
    }

    Action {
        id: zoomOutAction
        objectName: "zoomOutAction"
        text: qsTr("Zoom Out")
        shortcut: "Ctrl+-"
        enabled: !previewOverlay.visible
        onTriggered: {
            if (appSettings.viewMode === "list") {
                appSettings.listRowHeight = Math.max(24, appSettings.listRowHeight - 4)
            } else {
                appSettings.thumbnailSize = Math.max(200, appSettings.thumbnailSize - 50)
            }
        }
    }

    Action {
        id: actualSizeAction
        objectName: "actualSizeAction"
        text: qsTr("Default Size")
        shortcut: "Ctrl+0"
        enabled: !previewOverlay.visible
        onTriggered: {
            if (appSettings.viewMode === "list") {
                appSettings.listRowHeight = 28
            } else {
                appSettings.thumbnailSize = 200
            }
        }
    }

    ActionGroup {
        id: viewModeActionGroup
        exclusive: true
    }

    Action {
        id: gridViewAction
        objectName: "gridViewAction"
        ActionGroup.group: viewModeActionGroup
        text: qsTr("As Grid")
        shortcut: "Ctrl+Shift+1"
        checkable: true
        onTriggered: appSettings.viewMode = "grid"

        Binding on checked { value: appSettings.viewMode === "grid" }
    }

    Action {
        id: listViewAction
        objectName: "listViewAction"
        ActionGroup.group: viewModeActionGroup
        text: qsTr("As List")
        shortcut: "Ctrl+Shift+2"
        checkable: true
        onTriggered: appSettings.viewMode = "list"

        Binding on checked { value: appSettings.viewMode === "list" }
    }

    Action {
        id: toggleInfoAction
        text: rootWindow.showMainInfo ? qsTr("Hide &Info") : qsTr("Show &Info")
        shortcut: "Ctrl+I"
        enabled: galleryPanel.currentIndex >= 0 && galleryModel.count > 0
        onTriggered: rootWindow.showMainInfo = !rootWindow.showMainInfo
    }

    Action {
        id: showNewOnlyAction
        objectName: "showNewOnlyAction"
        text: qsTr("Show Only New")
        checkable: true
        checked: (typeof galleryModel !== "undefined" && galleryModel) ? galleryModel.showNewOnly : false
        enabled: galleryPanel.currentFolderPath === "sd_card_device"
        onTriggered: galleryModel.showNewOnly = checked
    }

    Action {
        id: importToPhotosAction
        objectName: "importToPhotosAction"
        text: qsTr("Import to Photos app...")
        enabled: galleryPanel.currentIndex >= 0 && galleryModel.count > 0
        onTriggered: {
            let paths = []
            if (galleryPanel.selectedCount > 0) {
                paths = galleryPanel.getSelectedPathsList()
            } else {
                for (let i = 0; i < galleryModel.count; ++i) {
                    if (!galleryModel.isFolder(i)) {
                        paths.push(galleryModel.getRawPath(i))
                    }
                }
            }
            if (paths.length > 0) {
                fileActionService.importToApplePhotos(paths)
            }
        }
    }

    Action {
        id: quickLookAction
        text: rootWindow.inlinePreviewActive ? qsTr("Close Preview") : qsTr("Quick Look")
        shortcut: "Space"
        enabled: !previewOverlay.visible && galleryPanel.selectedCount <= 1 && galleryPanel.currentIndex >= 0 && !galleryModel.isFolder(galleryPanel.currentIndex)
        onTriggered: {
            if (rootWindow.inlinePreviewActive) {
                rootWindow.inlinePreviewActive = false
                galleryPanel.gridView.forceActiveFocus()
            } else {
                rootWindow.inlinePreviewActive = true
                inlinePreviewPanel.forceActiveFocus()
            }
        }
    }

    Action {
        id: rotateLeftAction
        objectName: "rotateLeftAction"
        text: qsTr("Rotate Counterclockwise")
        shortcut: "Ctrl+["
        enabled: rootWindow.canRotateSelection()
        onTriggered: rootWindow.rotateSelection(270)
    }

    Action {
        id: rotateRightAction
        objectName: "rotateRightAction"
        text: qsTr("Rotate Clockwise")
        shortcut: "Ctrl+]"
        enabled: rootWindow.canRotateSelection()
        onTriggered: rootWindow.rotateSelection(90)
    }

    Action {
        id: showInFolderAction
        text: Qt.platform.os === "osx" ? qsTr("Reveal in Finder") : qsTr("Show in File Manager")
        shortcut: "Ctrl+R"
        enabled: !previewOverlay.visible && galleryPanel.currentIndex >= 0 && galleryPanel.selectedCount <= 1
        onTriggered: {
            let path = galleryModel.getRawPath(galleryPanel.currentIndex)
            fileActionService.showInFolder(path)
        }
    }

    Action {
        id: deleteAction
        text: qsTr("Move to Trash")
        shortcut: "Delete"
        enabled: {
            if (galleryPanel.selectedCount > 0) return true
            return !previewOverlay.visible && galleryPanel.currentIndex >= 0 && !galleryModel.isFolder(galleryPanel.currentIndex)
        }
        onTriggered: {
            if (galleryPanel.selectedCount > 0) {
                let paths = galleryPanel.getSelectedPathsList();
                if (appSettings.confirmDeletions) {
                    galleryPanel.triggerDeleteBatch(paths);
                } else {
                    galleryPanel.performDeleteBatch(paths);
                }
            } else {
                let index = galleryPanel.currentIndex
                let path = galleryModel.getRawPath(index)
                let name = galleryModel.getFileName(index)
                if (appSettings.confirmDeletions) {
                    galleryPanel.triggerDelete(index, path, name)
                } else {
                    galleryPanel.performDeleteSingle(index, path)
                }
            }
        }
    }

    Action {
        id: fullscreenPreviewAction
        text: qsTr("Show Fullscreen")
        shortcut: "Return"
        enabled: !previewOverlay.visible && galleryPanel.selectedCount <= 1 && galleryPanel.currentIndex >= 0 && !galleryModel.isFolder(galleryPanel.currentIndex)
        onTriggered: {
            previewOverlay.currentIndex = galleryPanel.currentIndex
            previewOverlay.visible = true
        }
    }

    Action {
        id: openExternallyAction
        text: qsTr("Open with Default Application")
        shortcut: "Ctrl+O"
        enabled: !previewOverlay.visible && galleryPanel.currentIndex >= 0 && !galleryModel.isFolder(galleryPanel.currentIndex) && galleryPanel.selectedCount <= 1
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
            if (galleryPanel.selectedCount > 0) return true
            let idx = previewOverlay.visible ? previewOverlay.currentIndex : galleryPanel.currentIndex
            return idx >= 0 && !galleryModel.isFolder(idx)
        }
        onTriggered: {
            if (galleryPanel.selectedCount > 0) {
                fileActionService.copyToClipboardBatch(galleryPanel.getSelectedPathsList())
            } else {
                let idx = previewOverlay.visible ? previewOverlay.currentIndex : galleryPanel.currentIndex
                let path = galleryModel.getRawPath(idx)
                fileActionService.copyToClipboard(path)
            }
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

    // Shortcuts
    Shortcut {
        id: galleryShortcut
        objectName: "galleryShortcut"
        sequence: "Space"
        enabled: quickLookAction.enabled && galleryPanel.gridView.activeFocus
        onActivated: quickLookAction.triggered(quickLookAction)
    }

    Shortcut {
        id: deleteShortcut
        objectName: "deleteShortcut"
        sequence: "Delete"
        enabled: deleteAction.enabled && galleryPanel.gridView.activeFocus
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

    Shortcut {
        sequence: "Ctrl+A"
        context: Qt.WindowShortcut
        onActivated: {
            if (galleryPanel.gridView.activeFocus) {
                galleryPanel.selectAll()
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: !previewOverlay.visible && !rootWindow.inlinePreviewActive && galleryPanel.selectedCount > 0
        onActivated: {
            if (galleryPanel.selectedCount > 0) {
                galleryPanel.clearSelection()
            }
        }
    }
}
