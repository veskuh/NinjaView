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
        }
        function onNotesChanged(filePath) {
            if (filePath === panel.currentPath || filePath === "") {
                panel.updateExifData()
            }
        }
        function onTagsChanged() {
            panel.updateExifData()
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
            }
        }
    }
}
