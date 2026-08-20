import QtQuick
import QtQuick.Controls
import NinjaView

MenuBar {
    id: menuBar

    required property var actions

    Menu {
        title: qsTr("&File")
        MenuItem { action: actions.addFolderAction }
        MenuItem { action: actions.removeFolderAction }
        MenuItem {
            objectName: "importToPhotosMenuItem"
            action: actions.importToPhotosAction
            visible: Qt.platform.os === "osx"
        }
        MenuSeparator {}
        MenuItem { action: actions.settingsAction }
        MenuSeparator {}
        MenuItem { action: actions.quitAction }
    }
    Menu {
        title: qsTr("&Edit")
        MenuItem { action: actions.copyAction }
        MenuItem { action: actions.renameAction }
        MenuItem { action: actions.rotateLeftAction }
        MenuItem { action: actions.rotateRightAction }
        MenuSeparator {}
        MenuItem { action: actions.deleteAction }
    }
    Menu {
        title: qsTr("&View")
        MenuItem { action: actions.refreshAction }
        MenuSeparator {}
        MenuItem { action: actions.zoomInAction }
        MenuItem { action: actions.zoomOutAction }
        MenuItem { action: actions.actualSizeAction }
        MenuSeparator {}
        MenuItem { action: actions.gridViewAction }
        MenuItem { action: actions.listViewAction }
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
        MenuItem { action: actions.showNewOnlyAction }
        MenuSeparator {}
        MenuItem { action: actions.toggleInfoAction }
    }
    Menu {
        title: qsTr("&Image")
        MenuItem { action: actions.quickLookAction }
        MenuItem { action: actions.fullscreenPreviewAction }
        MenuItem { action: actions.openExternallyAction }
        MenuSeparator {}
        MenuItem { action: actions.rotateRightAction }
        MenuItem { action: actions.rotateLeftAction }
        MenuSeparator {}
        MenuItem { action: actions.showInFolderAction }
        MenuItem { action: actions.deleteAction }
    }
    Menu {
        title: qsTr("&Help")
        MenuItem { action: actions.userGuideAction }
        MenuItem { action: actions.keyboardShortcutsAction }
        MenuSeparator {}
        MenuItem { action: actions.aboutAction }
    }
}
