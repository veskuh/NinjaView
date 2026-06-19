pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Kaakao

Item {
    id: panel

    property string currentPath: ""
    property string fileName: ""

    property var exifData: ({})
    property string notesEditingPath: ""
    property string tagsEditingPath: ""

    property int cacheInvalidator: 0

    property var selectedPathsList: []
    readonly property int selectedCount: selectedPathsList.length
    property bool appendTags: true
    property bool appendNotes: true
    property bool batchTagsDirty: false
    property string initialCommonTags: ""

    function parseSizeString(str) {
        if (!str) return 0;
        let parts = str.split(' ');
        if (parts.length < 2) return 0;
        let val = parseFloat(parts[0]);
        let unit = parts[1].toUpperCase();
        if (unit === "MB") return val * 1024 * 1024;
        if (unit === "KB") return val * 1024;
        return val;
    }

    function formatBytes(bytes) {
        if (bytes >= 1024 * 1024) {
            return (bytes / (1024.0 * 1024.0)).toFixed(2) + " MB";
        } else if (bytes >= 1024) {
            return (bytes / 1024.0).toFixed(1) + " KB";
        } else {
            return bytes + " B";
        }
    }

    function getCombinedSize() {
        let dummy = cacheInvalidator;
        let total = 0;
        selectedPathsList.forEach(function(path) {
            let data = exifReader.getExifData(path);
            if (data && data.FileSize) {
                total += parseSizeString(data.FileSize);
            }
        });
        return formatBytes(total);
    }

    function getCommonTags() {
        let dummy = cacheInvalidator;
        if (selectedPathsList.length === 0) return "";
        let common = null;
        selectedPathsList.forEach(function(path) {
            let data = exifReader.getExifData(path);
            let tags = data && data.Tags ? data.Tags.split(",").map(function(t) { return t.trim(); }).filter(function(t) { return t.length > 0; }) : [];
            if (common === null) {
                common = tags;
            } else {
                common = common.filter(function(t) { return tags.indexOf(t) !== -1; });
            }
        });
        return common ? common.join(", ") : "";
    }

    function isAllFavorite() {
        let dummy = cacheInvalidator;
        if (selectedPathsList.length === 0) return false;
        for (let i = 0; i < selectedPathsList.length; ++i) {
            let data = exifReader.getExifData(selectedPathsList[i]);
            if (!data || !data.Favorite) return false;
        }
        return true;
    }

    function toggleBatchFavorite() {
        let target = !isAllFavorite();
        if (typeof exifDatabase !== "undefined" && exifDatabase) {
            exifDatabase.setFavoriteBatch(selectedPathsList, target);
        }
    }

    function savePendingBatchEdits() {
        if (selectedCount > 1 && typeof exifDatabase !== "undefined" && exifDatabase) {
            if (batchTagsField.activeFocus) {
                exifDatabase.updateCommonTagsBatch(selectedPathsList, batchTagsField.text, initialCommonTags);
                batchTagsDirty = false;
            }
            if (batchNotesField.activeFocus) {
                exifDatabase.setNotesBatch(selectedPathsList, batchNotesField.text, appendNotes);
            }
        }
    }

    function updateExifData() {
        if (currentPath && typeof exifReader !== 'undefined' && exifReader) {
            exifData = exifReader.getExifData(currentPath)
        } else {
            exifData = ({})
        }
    }

    function savePendingEdits() {
        if (typeof exifDatabase !== 'undefined' && exifDatabase) {
            if (notesEditingPath !== "") {
                exifDatabase.setNotes(notesEditingPath, notesField.text)
                notesEditingPath = ""
            }
            if (tagsEditingPath !== "") {
                exifDatabase.setTags(tagsEditingPath, tagsField.text)
                tagsEditingPath = ""
            }
        }
    }

    onSelectedPathsListChanged: {
        savePendingEdits()
        savePendingBatchEdits()
        updateExifData()
        if (selectedPathsList.length > 1) {
            let common = getCommonTags()
            batchTagsField.text = common
            initialCommonTags = common
            batchNotesField.text = ""
        }
    }

    onCurrentPathChanged: {
        savePendingEdits()
        updateExifData()
    }

    Component.onDestruction: {
        savePendingEdits()
    }

    onExifDataChanged: {
        if (!tagsField.activeFocus) {
            tagsField.text = exifData.Tags || ""
        }
        if (!notesField.activeFocus) {
            notesField.text = exifData.Notes || ""
        }
    }

    Connections {
        target: typeof exifDatabase !== 'undefined' ? exifDatabase : null
        function onFavoritesChanged() {
            panel.updateExifData()
            panel.cacheInvalidator++
        }
        function onNotesChanged(filePath) {
            if (filePath === panel.currentPath || filePath === "") {
                panel.updateExifData()
            }
            panel.cacheInvalidator++
        }
        function onTagsChanged() {
            panel.updateExifData()
            panel.cacheInvalidator++
            if (panel.selectedPathsList.length > 1 && !batchTagsField.activeFocus) {
                let common = panel.getCommonTags()
                batchTagsField.text = common
                panel.initialCommonTags = common
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.windowBackground
        
        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: 1
            color: Theme.isDarkMode ? "#33FFFFFF" : "#33000000"
        }

        ScrollView {
            anchors.fill: parent
            contentWidth: parent.width
            contentHeight: infoContentColumn.implicitHeight + 30
            clip: true

            Column {
                id: infoContentColumn
                width: parent.width - 30
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 15
                spacing: 15

                KaakaoLabel {
                    text: qsTr("Information")
                    role: KaakaoLabel.Header
                    visible: panel.selectedCount <= 1
                }

                Rectangle {
                    width: parent.width
                    height: 150
                    color: Theme.isDarkMode ? "#2D2D2D" : "#F0F0F0"
                    radius: 4
                    visible: panel.currentPath !== ""
                    
                    Image {
                        anchors {
                            fill: parent
                            margins: 5
                        }
                        source: panel.currentPath ? root.getImageUrl(panel.currentPath) : ""
                        sourceSize: Qt.size(300, 300)
                        fillMode: Image.PreserveAspectFit
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: 8
                    visible: panel.currentPath !== ""

                    KaakaoLabel {
                        text: panel.fileName
                        Layout.fillWidth: true
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        font.weight: Font.Bold
                        font.pixelSize: 13
                    }

                    Text {
                        id: favStar
                        objectName: "favStar"
                        text: panel.exifData.Favorite ? "★" : "☆"
                        font.pixelSize: 22
                        color: panel.exifData.Favorite ? "#FFC107" : (Theme.isDarkMode ? "#66FFFFFF" : "#66000000")
                        Layout.alignment: Qt.AlignTop
                        
                        MouseArea {
                            id: favStarMouseArea
                            objectName: "favStarMouseArea"
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (typeof exifDatabase !== 'undefined' && exifDatabase) {
                                    exifDatabase.setFavorite(panel.currentPath, !panel.exifData.Favorite)
                                }
                            }
                        }
                    }
                }

                // Read-only Metadata List
                Repeater {
                    model: [
                        { label: "Format", value: panel.exifData.IsVideo ? panel.exifData.Model : "" },
                        { label: "Make", value: panel.exifData.IsVideo ? "" : panel.exifData.Make },
                        { label: "Model", value: panel.exifData.IsVideo ? "" : panel.exifData.Model },
                        { label: "Lens", value: panel.exifData.IsVideo ? "" : panel.exifData.Lens },
                        { label: "Dimensions", value: panel.exifData.Dimensions },
                        { label: "Size", value: panel.exifData.FileSize },
                        { label: "Duration", value: panel.exifData.Duration },
                        { label: "Exposure", value: panel.exifData.Exposure },
                        { label: "Aperture", value: panel.exifData.Aperture },
                        { label: "Focal Length", value: panel.exifData.FocalLength },
                        { label: "ISO", value: panel.exifData.ISO },
                        { label: "Date", value: panel.exifData.DateTime }
                    ]
                    delegate: Column {
                        required property var modelData
                        width: parent.width
                        spacing: 2
                        visible: modelData.value !== undefined && modelData.value !== "" && modelData.value !== 0
                        
                        KaakaoLabel { 
                            text: modelData.label
                            color: "#888"
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                        KaakaoLabel { 
                            text: String(modelData.value)
                            width: parent.width
                            elide: Text.ElideRight
                            font.pixelSize: 12
                        }
                    }
                }

                // Separator
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.isDarkMode ? "#33FFFFFF" : "#33000000"
                    visible: panel.currentPath !== ""
                }

                // Tags Field
                Column {
                    width: parent.width
                    spacing: 4
                    visible: panel.currentPath !== ""

                    KaakaoLabel {
                        text: qsTr("Tags (comma separated)")
                        color: "#888"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }

                    KaakaoTextField {
                        id: tagsField
                        objectName: "tagsField"
                        width: parent.width
                        placeholderText: qsTr("Add tags...")
                        
                        onActiveFocusChanged: {
                            if (activeFocus) {
                                panel.tagsEditingPath = panel.currentPath
                            } else {
                                if (panel.tagsEditingPath !== "" && typeof exifDatabase !== 'undefined' && exifDatabase) {
                                    exifDatabase.setTags(panel.tagsEditingPath, text)
                                    panel.tagsEditingPath = ""
                                }
                                text = panel.exifData.Tags || ""
                            }
                        }
                        
                        onEditingFinished: {
                            if (panel.tagsEditingPath !== "" && typeof exifDatabase !== 'undefined' && exifDatabase) {
                                exifDatabase.setTags(panel.tagsEditingPath, text)
                                panel.tagsEditingPath = ""
                            }
                            if (typeof galleryPanel !== 'undefined' && galleryPanel && galleryPanel.gridView) {
                                galleryPanel.gridView.forceActiveFocus()
                            }
                        }
                    }
                }

                // Notes Field
                Column {
                    width: parent.width
                    spacing: 4
                    visible: panel.currentPath !== ""

                    KaakaoLabel {
                        text: qsTr("Notes")
                        color: "#888"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }

                    KaakaoTextArea {
                        id: notesField
                        objectName: "notesField"
                        width: parent.width
                        implicitHeight: 80
                        placeholderText: qsTr("Add notes...")
                        
                        onActiveFocusChanged: {
                            if (activeFocus) {
                                panel.notesEditingPath = panel.currentPath
                            } else {
                                if (panel.notesEditingPath !== "" && typeof exifDatabase !== 'undefined' && exifDatabase) {
                                    exifDatabase.setNotes(panel.notesEditingPath, text)
                                    panel.notesEditingPath = ""
                                }
                                text = panel.exifData.Notes || ""
                            }
                        }
                    }
                }

                // 1. Empty Selection Placeholder
                Column {
                    width: parent.width
                    spacing: 15
                    visible: panel.selectedCount === 0

                    Rectangle {
                        width: parent.width
                        height: 50
                        color: "transparent"
                    }

                    KaakaoLabel {
                        text: qsTr("No Selection")
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                        color: Theme.isDarkMode ? "#66FFFFFF" : "#66000000"
                    }

                    KaakaoLabel {
                        text: qsTr("Select one or more items to view and edit details.")
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        width: parent.width
                        color: Theme.isDarkMode ? "#44FFFFFF" : "#44000000"
                    }
                }

                // 2. Batch Selection View
                Column {
                    width: parent.width
                    spacing: 15
                    visible: panel.selectedCount > 1

                    RowLayout {
                        width: parent.width
                        spacing: 8

                        KaakaoLabel {
                            text: qsTr("%1 items selected").arg(panel.selectedCount)
                            Layout.fillWidth: true
                            font.weight: Font.Bold
                            font.pixelSize: 14
                        }

                        Text {
                            id: batchFavStar
                            text: panel.isAllFavorite() ? "★" : "☆"
                            font.pixelSize: 22
                            color: panel.isAllFavorite() ? "#FFC107" : (Theme.isDarkMode ? "#66FFFFFF" : "#66000000")
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    panel.toggleBatchFavorite()
                                }
                            }
                        }
                    }

                    // Combined Size details
                    Column {
                        width: parent.width
                        spacing: 2
                        
                        KaakaoLabel { 
                            text: qsTr("Combined Size")
                            color: "#888"
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                        KaakaoLabel { 
                            text: panel.getCombinedSize()
                            width: parent.width
                            font.pixelSize: 12
                        }
                    }

                    // Separator
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.isDarkMode ? "#33FFFFFF" : "#33000000"
                    }

                    // Batch Tags
                    Column {
                        width: parent.width
                        spacing: 4

                        RowLayout {
                            width: parent.width
                            
                            KaakaoLabel {
                                text: qsTr("Tags (intersection)")
                                color: "#888"
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                            }
                        }

                        KaakaoTextField {
                            id: batchTagsField
                            objectName: "batchTagsField"
                            width: parent.width
                            placeholderText: qsTr("Add tags to selected...")
                            
                            onActiveFocusChanged: {
                                if (activeFocus) {
                                    panel.batchTagsDirty = true
                                    panel.initialCommonTags = panel.getCommonTags()
                                } else {
                                    if (panel.batchTagsDirty) {
                                        if (typeof exifDatabase !== 'undefined' && exifDatabase) {
                                            exifDatabase.updateCommonTagsBatch(panel.selectedPathsList, text, panel.initialCommonTags)
                                        }
                                        panel.batchTagsDirty = false
                                    }
                                    text = panel.getCommonTags()
                                    panel.initialCommonTags = text
                                }
                            }
                            
                            onEditingFinished: {
                                if (panel.batchTagsDirty) {
                                    if (typeof exifDatabase !== 'undefined' && exifDatabase) {
                                        exifDatabase.updateCommonTagsBatch(panel.selectedPathsList, text, panel.initialCommonTags)
                                    }
                                    panel.batchTagsDirty = false
                                }
                                if (typeof galleryPanel !== 'undefined' && galleryPanel && galleryPanel.gridView) {
                                    galleryPanel.gridView.forceActiveFocus()
                                }
                            }
                        }
                    }

                    // Batch Notes
                    Column {
                        width: parent.width
                        spacing: 4

                        RowLayout {
                            width: parent.width
                            
                            KaakaoLabel {
                                text: qsTr("Notes")
                                color: "#888"
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                            }

                            CheckBox {
                                id: appendNotesCheck
                                text: qsTr("Append")
                                checked: panel.appendNotes
                                font.pixelSize: 9
                                Layout.alignment: Qt.AlignVCenter
                                onCheckedChanged: {
                                    panel.appendNotes = checked
                                }
                            }
                        }

                        KaakaoTextArea {
                            id: batchNotesField
                            width: parent.width
                            implicitHeight: 80
                            placeholderText: qsTr("Add notes to selected...")
                            
                            onActiveFocusChanged: {
                                if (!activeFocus) {
                                    if (typeof exifDatabase !== 'undefined' && exifDatabase) {
                                        exifDatabase.setNotesBatch(panel.selectedPathsList, text, panel.appendNotes)
                                        text = "" // Clear notes field after batch application
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
