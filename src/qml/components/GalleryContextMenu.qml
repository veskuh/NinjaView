import QtQuick
import QtQuick.Controls
import Kaakao
import NinjaView

KaakaoMenu {
    id: menu

    property int targetIndex: -1
    property string targetPath: ""
    property var galleryPanel

    readonly property bool isTargetInMultiSelect: {
        galleryPanel && galleryPanel.selectedCount > 1 && galleryPanel.selectedPaths[menu.targetPath] === true
    }

    readonly property bool isTargetFolder: {
        (targetIndex >= 0 && typeof galleryModel !== "undefined" && galleryModel) ? galleryModel.isFolder(targetIndex) : false
    }

    readonly property bool canRotate: {
        if (isTargetInMultiSelect) {
            let paths = galleryPanel.getSelectedPathsList();
            for (let i = 0; i < paths.length; ++i) {
                let p = paths[i].toLowerCase();
                if (p.endsWith(".jpg") || p.endsWith(".jpeg")) return true;
            }
            return false;
        }
        if (!menu.targetPath) return false;
        let p = menu.targetPath.toLowerCase();
        return p.endsWith(".jpg") || p.endsWith(".jpeg");
    }

    function triggerRotate(angle) {
        if (isTargetInMultiSelect) {
            root.rotateSelection(angle);
        } else {
            root.rotatePath(menu.targetPath, angle);
        }
    }

    KaakaoMenuItem {
        text: Qt.platform.os === "osx" ? qsTr("Reveal in Finder") : qsTr("Show in File Manager")
        enabled: !menu.isTargetInMultiSelect
        onTriggered: fileActionService.showInFolder(menu.targetPath)
    }
    KaakaoMenuItem {
        text: qsTr("Open with Default Application")
        enabled: !menu.isTargetInMultiSelect && !menu.isTargetFolder
        onTriggered: fileActionService.openExternally(menu.targetPath)
    }
    KaakaoMenuItem {
        objectName: "contextMenuRenameItem"
        text: qsTr("Rename…")
        enabled: !menu.isTargetInMultiSelect && menu.targetPath !== "" && !menu.isTargetFolder
        onTriggered: root.openRenameDialog(menu.targetPath)
    }
    KaakaoMenuItem {
        text: qsTr("Import to Photos app")
        visible: Qt.platform.os === "osx"
        onTriggered: {
            if (!galleryPanel) return
            let paths = []
            if (menu.isTargetInMultiSelect) {
                paths = galleryPanel.getSelectedPathsList()
            } else {
                paths = [menu.targetPath]
            }
            fileActionService.importToApplePhotos(paths)
        }
    }
    MenuSeparator {}
    KaakaoMenuItem {
        text: qsTr("Rotate Left")
        enabled: menu.canRotate
        onTriggered: menu.triggerRotate(270)
    }
    KaakaoMenuItem {
        text: qsTr("Rotate Right")
        enabled: menu.canRotate
        onTriggered: menu.triggerRotate(90)
    }
    MenuSeparator {}
    KaakaoMenuItem {
        text: menu.isTargetInMultiSelect
              ? qsTr("Move %1 Items to Trash").arg(galleryPanel ? galleryPanel.selectedCount : 0)
              : qsTr("Move to Trash")
        onTriggered: {
            if (!galleryPanel) return
            if (menu.isTargetInMultiSelect) {
                let paths = galleryPanel.getSelectedPathsList();
                if (galleryPanel.confirmDeletions) {
                    galleryPanel.triggerDeleteBatch(paths)
                } else {
                    galleryPanel.performDeleteBatch(paths)
                }
            } else {
                let index = menu.targetIndex
                let path = menu.targetPath
                let name = galleryModel.getFileName(index)
                if (galleryPanel.confirmDeletions) {
                    galleryPanel.triggerDelete(index, path, name)
                } else {
                    galleryPanel.performDeleteSingle(index, path)
                }
            }
        }
    }
}
