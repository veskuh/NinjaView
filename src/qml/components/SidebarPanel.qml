pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore
import Kaakao

Item {
    id: panel

    required property var settings

    signal directorySelected(string name, string path, bool isPictures, bool isSdCard)

    property bool blockNavigation: false

    readonly property alias currentIndex: sidebar.currentIndex
    readonly property alias sidebarModel: sidebarModel
    readonly property alias sidebar: sidebar

    function addFolder(path) {
        // Deduplication
        for (let i = 0; i < sidebarModel.count; ++i) {
            if (sidebarModel.get(i).path === path) {
                sidebar.currentIndex = i
                return
            }
        }

        let decodedPath = decodeURIComponent(path)
        let parts = decodedPath.split("/")
        let name = parts[parts.length - 1] || parts[parts.length - 2] || decodedPath
        if (name.endsWith("/")) name = name.substring(0, name.length - 1)

        sidebarModel.append({ 
            name: name, 
            icon: "📁", 
            category: qsTr("Folders"), 
            path: path 
        })
        
        // Save to settings
        let folders = JSON.parse(panel.settings.savedFolders)
        folders.push(path)
        panel.settings.savedFolders = JSON.stringify(folders)
        
        sidebar.currentIndex = sidebarModel.count - 1
    }

    function removeFolder(index) {
        let item = sidebarModel.get(index)
        if (item.path === undefined) return
        
        let path = item.path
        sidebarModel.remove(index)
        
        let folders = JSON.parse(panel.settings.savedFolders)
        let newFolders = folders.filter(f => f !== path)
        panel.settings.savedFolders = JSON.stringify(newFolders)
        
        if (sidebar.currentIndex === index) {
            sidebar.currentIndex = 0
        }
    }

    function triggerFolderDialog() {
        folderDialog.open()
    }

    function triggerRemove(index) {
        if (index >= 0 && index < sidebarModel.count) {
            let item = sidebarModel.get(index)
            removeConfirmationDialog.targetIndex = index
            removeConfirmationDialog.folderName = item.name
            removeConfirmationDialog.open()
        }
    }

    function loadSidebar() {
        sidebarModel.clear()
        sidebarModel.append({ name: qsTr("Pictures"), icon: "🖼️", category: qsTr("Library") })
        sidebarModel.append({ name: qsTr("Favorites"), icon: "★", iconColor: "#FFC107", category: qsTr("Library"), path: "smart://favorites" })
        sidebarModel.append({ name: qsTr("SD Card"), icon: "💾", category: qsTr("Devices") })
        
        let folders = JSON.parse(panel.settings.savedFolders)
        for (let i = 0; i < folders.length; ++i) {
            let path = folders[i]
            let parts = path.split("/")
            let name = parts[parts.length - 1] || parts[parts.length - 2] || path
            sidebarModel.append({ 
                name: name, 
                icon: "📁", 
                category: qsTr("Folders"), 
                path: path 
            })
        }

        // Load dynamic tags from database
        if (typeof exifDatabase !== 'undefined' && exifDatabase) {
            let tags = exifDatabase.getAllTags()
            for (let i = 0; i < tags.length; ++i) {
                let tag = tags[i]
                sidebarModel.append({
                    name: tag,
                    icon: "🏷️",
                    category: qsTr("Tags"),
                    path: "smart://tag/" + tag
                })
            }
        }
    }

    function refreshSidebar() {
        panel.blockNavigation = true
        // Save current selection state
        let activePath = ""
        let activeName = ""
        let activeCategory = ""
        if (sidebar.currentIndex >= 0 && sidebar.currentIndex < sidebarModel.count) {
            let activeItem = sidebarModel.get(sidebar.currentIndex)
            activePath = activeItem.path || ""
            activeName = activeItem.name
            activeCategory = activeItem.category
        }

        // Reload
        loadSidebar()

        // Restore selection index
        let newIndex = -1
        for (let i = 0; i < sidebarModel.count; ++i) {
            let item = sidebarModel.get(i)
            if (item.category === activeCategory && item.name === activeName && (item.path || "") === activePath) {
                newIndex = i
                break
            }
        }
        
        // Temporarily block current index change handler to prevent navigation triggers
        sidebar.currentIndex = newIndex
        panel.blockNavigation = false
    }

    Component.onCompleted: {
        loadSidebar()
    }

    ListModel {
        id: sidebarModel
    }

    FolderDialog {
        id: folderDialog
        title: qsTr("Choose a folder to add to NinjaView")
        onAccepted: {
            panel.addFolder(selectedFolder.toString())
        }
    }

    KaakaoSheet {
        id: removeConfirmationDialog
        width: 400
        height: 170
        property int targetIndex: -1
        property string folderName: ""

        contentItem: Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            KaakaoLabel {
                text: qsTr("Remove Folder")
                font.weight: Font.Bold
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
            }

            Row {
                width: parent.width
                spacing: 16
                
                Text {
                    text: "📁"
                    font.pixelSize: 36
                    verticalAlignment: Text.AlignTop
                }

                KaakaoLabel {
                    text: qsTr("Are you sure you want to remove \"%1\" from the sidebar?").arg(removeConfirmationDialog.folderName)
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
                    onClicked: removeConfirmationDialog.close()
                }
                KaakaoButton {
                    text: qsTr("Remove")
                    highlighted: true
                    onClicked: {
                        if (removeConfirmationDialog.targetIndex >= 0) {
                            panel.removeFolder(removeConfirmationDialog.targetIndex)
                        }
                        removeConfirmationDialog.close()
                    }
                }
            }
        }
    }

    KaakaoMenu {
        id: sidebarContextMenu
        objectName: "sidebarContextMenu"
        property int targetIndex: -1
        
        KaakaoMenuItem {
            id: revealItem
            objectName: "revealItem"
            text: qsTr("Reveal in Finder")
            enabled: {
                if (sidebarContextMenu.targetIndex === 1) {
                    return volumeMonitor.sdCardPath !== ""
                }
                return true
            }
            onTriggered: {
                let index = sidebarContextMenu.targetIndex
                let item = sidebarModel.get(index)
                let path = ""
                if (index === 0) path = StandardPaths.writableLocation(StandardPaths.PicturesLocation)
                else if (index === 1) path = volumeMonitor.sdCardPath
                else path = item.path
                
                if (path !== "") fileActionService.showInFolder(path)
            }
        }
        
        MenuSeparator { }
        
        KaakaoMenuItem {
            id: removeItem
            objectName: "removeItem"
            text: qsTr("Remove Folder")
            enabled: {
                if (sidebarContextMenu.targetIndex < 0 || sidebarContextMenu.targetIndex >= sidebarModel.count) return false;
                let item = sidebarModel.get(sidebarContextMenu.targetIndex);
                return item.category === qsTr("Folders");
            }
            onTriggered: {
                let index = sidebarContextMenu.targetIndex
                panel.triggerRemove(index)
            }
        }
    }

    function handleDrop(url) {
        let path = url.toString()
        if (path.startsWith("file://")) {
            let extensions = [".jpg", ".jpeg", ".png", ".bmp", ".webp"]
            let lowerPath = path.toLowerCase()
            let isImage = false
            for (let ext of extensions) {
                if (lowerPath.endsWith(ext)) {
                    isImage = true
                    break
                }
            }

            if (isImage) {
                let parts = path.split("/")
                parts.pop() // remove filename
                path = parts.join("/")
            }
            
            panel.addFolder(path)
        }
    }

    KaakaoSidebar {
        id: sidebar
        objectName: "sidebar"
        anchors.fill: parent

        model: sidebarModel

        DropArea {
            anchors.fill: parent
            onDropped: (drop) => {
                if (drop.hasUrls) {
                    for (let url of drop.urls) {
                        panel.handleDrop(url)
                    }
                }
            }
        }

        onContextMenu: (index, pos) => {
            sidebarContextMenu.targetIndex = index
            sidebarContextMenu.popup(pos.x, pos.y)
        }

        onCurrentIndexChanged: {
            if (panel.blockNavigation) return
            if (currentIndex < 0 || currentIndex >= sidebarModel.count) return
            
            let item = sidebarModel.get(currentIndex)
            let name = item.name
            let path = item.path || ""
            let isPictures = (name === qsTr("Pictures") || name === "Pictures")
            let isSdCard = (name === qsTr("SD Card") || name === "SD Card")
            
            panel.directorySelected(name, path, isPictures, isSdCard)
        }
    }

    Connections {
        target: typeof exifDatabase !== 'undefined' ? exifDatabase : null
        function onTagsChanged() {
            panel.refreshSidebar()
        }
    }
}
