import QtQuick
import QtQuick.Controls
import Kaakao
import NinjaView

KaakaoMenu {
    id: menu

    property int targetIndex: -1
    property string targetPath: ""
    property var galleryPanel

    readonly property bool isMultiSelect: {
        galleryPanel && galleryPanel.selectedCount > 1 && galleryPanel.selectedPaths[menu.targetPath] === true
    }

    KaakaoMenuItem {
        text: Qt.platform.os === "osx" ? qsTr("Reveal in Finder") : qsTr("Show in File Manager")
        enabled: !menu.isMultiSelect
        onTriggered: fileActionService.showInFolder(menu.targetPath)
    }
    KaakaoMenuItem {
        text: qsTr("Open with Default Application")
        enabled: !menu.isMultiSelect
        onTriggered: fileActionService.openExternally(menu.targetPath)
    }
    KaakaoMenuItem {
        text: qsTr("Import to Photos app")
        visible: Qt.platform.os === "osx"
        onTriggered: {
            if (!galleryPanel) return
            let paths = []
            if (menu.isMultiSelect) {
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
        enabled: galleryPanel && galleryPanel.canRotateSelection(menu.isMultiSelect, menu.targetIndex)
        onTriggered: galleryPanel && galleryPanel.rotateSelection(270, menu.isMultiSelect)
    }
    KaakaoMenuItem {
        text: qsTr("Rotate Right")
        enabled: galleryPanel && galleryPanel.canRotateSelection(menu.isMultiSelect, menu.targetIndex)
        onTriggered: galleryPanel && galleryPanel.rotateSelection(90, menu.isMultiSelect)
    }
    MenuSeparator {}
    KaakaoMenuItem {
        text: menu.isMultiSelect
              ? qsTr("Move %1 Items to Trash").arg(galleryPanel ? galleryPanel.selectedCount : 0)
              : qsTr("Move to Trash")
        onTriggered: {
            if (!galleryPanel) return
            if (menu.isMultiSelect) {
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
