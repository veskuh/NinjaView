import QtQuick
import QtQuick.Controls
import Kaakao
import NinjaView

/*!
    \qmltype GalleryListDelegate
    \inqmlmodule NinjaView
    \brief A desktop list row for the gallery's list view mode.

    GalleryListDelegate presents a file or folder as a compact row with a small
    thumbnail, filename, and EXIF metadata columns (dimensions/duration, date,
    file size). It mirrors the interaction contract of GalleryGridDelegate so
    both views can share the selection and navigation logic in GalleryPanel.
*/
ItemDelegate {
    id: listDelegate
    focus: true

    required property var model
    required property int index

    // Configuration / state passed from parent
    property var selectedPaths: ({})
    property int selectedCount: 0
    property int lastClickedIndex: -1
    property var rotationTimestamps: ({})
    property int rowHeight: 28
    property var galleryModelSource
    property var exifDatabaseSource
    property var getImageUrlHelper
    property var columnsList: []

    readonly property bool isMultiSelected: selectedPaths && selectedPaths[model.rawPath] === true
    readonly property bool isEvenRow: index % 2 === 0
    readonly property bool selectedFocused: isMultiSelected && ListView.view && ListView.view.activeFocus

    // EXIF metadata for the row's columns (single cached query per row)
    readonly property var exif: (!model.isFolder && typeof exifDatabaseSource !== "undefined" && exifDatabaseSource) ? exifDatabaseSource.getExifData(model.rawPath) : null
    readonly property string sizeText: (exif && exif.FileSize) ? exif.FileSize : ""
    readonly property string dateText: (exif && exif.DateTime) ? exif.DateTime : ""
    readonly property string dimsText: {
        if (model.isFolder) return ""
        if (model.isVideo && exif && exif.Duration) return exif.Duration
        return (exif && exif.Dimensions) ? exif.Dimensions : ""
    }

    width: ListView.view ? ListView.view.width : 200
    height: rowHeight
    padding: 0
    hoverEnabled: true

    // Signals to notify the parent container of interactions
    signal itemClicked(string rawPath, int idx, int modifiers)
    signal itemDoubleClicked(string rawPath, int idx, bool isFolder, string fileName)
    signal itemRightClicked(string rawPath, int idx, bool isFolder, var mouse)
    signal selectionToggled(string rawPath, int idx)
    signal updateSelectedPaths(var newSelections)
    signal updateLastClickedIndex(int newIndex)
    signal folderOpenRequested(string rawPath, string fileName)
    signal parentFolderRequested()

    Keys.onPressed: (event) => {
        if (!ListView.view || !galleryModelSource) return

        let total = galleryModelSource.count
        let cur   = ListView.view.currentIndex  // focused item in list
        let isShift = (event.modifiers & Qt.ShiftModifier) !== 0

        // Compute where a plain arrow/home/end would move currentIndex.
        let target = -1
        switch (event.key) {
            case Qt.Key_Down:  target = Math.min(cur + 1, total - 1); break
            case Qt.Key_Up:    target = Math.max(cur - 1, 0);         break
            case Qt.Key_Home:  target = 0;                            break
            case Qt.Key_End:   target = total - 1;                    break
            default: break
        }

        if (event.key === Qt.Key_Space && listDelegate.selectedCount > 1) {
            // Block Space in multi-select (would trigger Quick Look)
            event.accepted = true
        } else if (event.key === Qt.Key_Right && model.isFolder) {
            // Finder-style: Right enters a folder
            listDelegate.folderOpenRequested(model.rawPath, model.fileName)
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            // Finder-style: Left navigates to the parent folder
            listDelegate.parentFolderRequested()
            event.accepted = true
        } else if (target >= 0 && isShift) {
            let anchor = listDelegate.lastClickedIndex >= 0 ? listDelegate.lastClickedIndex : cur
            let start  = Math.min(anchor, target)
            let end    = Math.max(anchor, target)
            let newSelections = {}
            for (let i = start; i <= end; ++i) {
                newSelections[galleryModelSource.getRawPath(i)] = true
            }
            listDelegate.updateSelectedPaths(newSelections)
        } else if (target >= 0) {
            let newSelections = {}
            newSelections[galleryModelSource.getRawPath(target)] = true
            listDelegate.updateSelectedPaths(newSelections)
            listDelegate.updateLastClickedIndex(target)
        }
    }

    Keys.onReleased: (event) => {
        if (event.key === Qt.Key_Space && listDelegate.selectedCount > 1) {
            event.accepted = true;
        }
    }

    onClicked: {
        listDelegate.itemClicked(model.rawPath, index, Qt.keyboardModifiers)
    }

    onDoubleClicked: {
        listDelegate.itemDoubleClicked(model.rawPath, index, model.isFolder, model.fileName)
    }

    background: Rectangle {
        anchors.fill: parent

        color: {
            if (listDelegate.isMultiSelected) {
                // If the list has focus, use Active Selection BG. Otherwise, use Inactive Selection BG.
                if (listDelegate.ListView.view && listDelegate.ListView.view.activeFocus)
                    return Theme.selectionBackgroundActive;
                return Theme.selectionBackgroundInactive;
            }

            // Zebra striping for unselected rows
            return listDelegate.isEvenRow ? Theme.alternatingRowBackgroundEven : Theme.alternatingRowBackgroundOdd;
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                if (listDelegate.ListView.view) {
                    listDelegate.ListView.view.currentIndex = index
                    listDelegate.ListView.view.forceActiveFocus()
                }

                if (listDelegate.selectedPaths[model.rawPath] !== true) {
                    let newSelections = {}
                    newSelections[model.rawPath] = true
                    listDelegate.updateSelectedPaths(newSelections)
                    listDelegate.updateLastClickedIndex(index)
                }

                listDelegate.itemRightClicked(model.rawPath, index, model.isFolder, mouse)
            }
        }
    }

    contentItem: Row {
        id: delegateRow
        anchors.fill: parent
        spacing: 0

        // Column 0: Name (contains checkbox, thumbnail, and filename)
        Item {
            width: (listDelegate.columnsList && listDelegate.columnsList[0]) ? listDelegate.columnsList[0].width : 300
            height: parent.height
            clip: true

            Row {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 6

                // Selection checkbox column (fixed width so hovering never shifts content)
                Item {
                    width: 18
                    height: 18
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        radius: 7
                        color: listDelegate.isMultiSelected ? Theme.selectionBackgroundActive : "#B0000000"
                        border.color: "white"
                        border.width: 1
                        visible: !model.isFolder && (listDelegate.isMultiSelected || listDelegate.hovered)

                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: "white"
                            font.pixelSize: 9
                            font.bold: true
                            visible: listDelegate.isMultiSelected
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: (mouse) => {
                                listDelegate.selectionToggled(model.rawPath, index)
                            }
                        }
                    }
                }

                // Thumbnail / folder icon
                Item {
                    id: thumbContainer
                    width: listDelegate.rowHeight - 6
                    height: listDelegate.rowHeight - 6
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.isDarkMode ? "#2D2D2D" : "#F0F0F0"
                        radius: 3
                        visible: model.isFolder || thumbnail.status !== Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "📁"
                        font.pixelSize: Math.max(12, Math.round((listDelegate.rowHeight - 6) * 0.64))
                        visible: model.isFolder
                    }

                    Image {
                        id: thumbnail
                        anchors.fill: parent
                        visible: !model.isFolder
                        readonly property var rotationTimestamp: (listDelegate.rotationTimestamps && model && model.rawPath) ? listDelegate.rotationTimestamps[model.rawPath] : undefined
                        source: (model.isFolder || !getImageUrlHelper) ? "" : getImageUrlHelper(model.rawPath, rotationTimestamp)
                        sourceSize: Qt.size(64, 64)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: (status === Image.Ready) ? 1.0 : 0.0
                        Behavior on opacity {
                            enabled: thumbnail.status === Image.Ready
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutQuad
                            }
                        }
                        onStatusChanged: {
                            if (status === Image.Error && !model.isFolder) {
                                console.error("Failed to load thumbnail for:", model.rawPath)
                            }
                        }
                    }

                    Text {
                        anchors {
                            right: parent.right
                            bottom: parent.bottom
                            margins: 1
                        }
                        text: "▶"
                        color: "white"
                        style: Text.Outline
                        styleColor: "#80000000"
                        font.pixelSize: 8
                        visible: !model.isFolder && model.isVideo
                    }
                }

                // Filename
                KaakaoLabel {
                    width: Math.max(20, parent.width - 18 - (listDelegate.rowHeight - 6) - 18) // 18 is 6 * 3 for spacings
                    text: model.fileName
                    elide: Text.ElideMiddle
                    anchors.verticalCenter: parent.verticalCenter
                    color: listDelegate.selectedFocused ? Theme.selectionTextActive : Theme.primaryText
                }
            }
        }

        // Column 1: Dimensions
        Item {
            width: (listDelegate.columnsList && listDelegate.columnsList[1]) ? listDelegate.columnsList[1].width : 90
            height: parent.height
            clip: true

            KaakaoLabel {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                text: listDelegate.dimsText
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
                color: listDelegate.selectedFocused ? Qt.rgba(1, 1, 1, 0.7) : Theme.secondaryText
            }
        }

        // Column 2: Date
        Item {
            width: (listDelegate.columnsList && listDelegate.columnsList[2]) ? listDelegate.columnsList[2].width : 150
            height: parent.height
            clip: true

            KaakaoLabel {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                text: listDelegate.dateText
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
                color: listDelegate.selectedFocused ? Qt.rgba(1, 1, 1, 0.7) : Theme.secondaryText
            }
        }

        // Column 3: Size
        Item {
            width: (listDelegate.columnsList && listDelegate.columnsList[3]) ? listDelegate.columnsList[3].width : 70
            height: parent.height
            clip: true

            KaakaoLabel {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                text: listDelegate.sizeText
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
                color: listDelegate.selectedFocused ? Qt.rgba(1, 1, 1, 0.7) : Theme.secondaryText
            }
        }
    }
}
