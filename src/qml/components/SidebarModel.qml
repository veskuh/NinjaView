pragma ComponentBehavior: Bound

import QtQuick
import QtCore

ListModel {
    id: model

    required property var settings

    function addFolder(path) {
        // Deduplication
        for (let i = 0; i < model.count; ++i) {
            if (model.get(i).path === path) {
                return i
            }
        }

        let decodedPath = decodeURIComponent(path)
        let parts = decodedPath.split("/")
        let name = parts[parts.length - 1] || parts[parts.length - 2] || decodedPath
        if (name.endsWith("/")) name = name.substring(0, name.length - 1)

        model.append({ 
            name: name, 
            icon: "📁", 
            category: qsTr("Folders"), 
            path: path 
        })
        
        // Save to settings
        let folders = JSON.parse(model.settings.savedFolders)
        folders.push(path)
        model.settings.savedFolders = JSON.stringify(folders)
        
        return model.count - 1
    }

    function removeFolder(index) {
        let item = model.get(index)
        if (item.path === undefined) return
        
        let path = item.path
        model.remove(index)
        
        let folders = JSON.parse(model.settings.savedFolders)
        let newFolders = folders.filter(f => f !== path)
        model.settings.savedFolders = JSON.stringify(newFolders)
    }

    function loadSidebar() {
        model.clear()
        model.append({ name: qsTr("Pictures"), icon: "🖼️", category: qsTr("Library") })
        model.append({ name: qsTr("Favorites"), icon: "★", iconColor: "#FFC107", category: qsTr("Library"), path: "smart://favorites" })
        model.append({ name: qsTr("SD Card"), icon: "💾", category: qsTr("Devices") })
        
        let folders = JSON.parse(model.settings.savedFolders)
        for (let i = 0; i < folders.length; ++i) {
            let path = folders[i]
            let parts = path.split("/")
            let name = parts[parts.length - 1] || parts[parts.length - 2] || path
            model.append({ 
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
                model.append({
                    name: tag,
                    icon: "🏷️",
                    category: qsTr("Tags"),
                    path: "smart://tag/" + tag
                })
            }
        }
    }
}
