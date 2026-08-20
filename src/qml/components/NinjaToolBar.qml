import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import Kaakao

KaakaoToolBar {
    id: toolbar

    required property string currentFolderDescription
    required property string currentTitle
    required property int previewOverlayCurrentIndex
    required property int galleryPanelCurrentIndex
    required property bool previewOverlayVisible
    required property bool showMainInfo
    property int thumbnailSize: 200
    property int listRowHeight: 28
    property string viewMode: "grid"
    property bool canRotate: false

    signal rotateImage(int angle)
    signal toggleShowMainInfo()
    signal pathClicked(string fullPath, string name)
    signal viewModeRequested(string mode)

    function isJpegFile(idx) {
        if (idx < 0 || !galleryModel || idx >= galleryModel.count || galleryModel.isFolder(idx)) {
            return false;
        }
        let path = String(galleryModel.getRawPath(idx)).toLowerCase();
        return path.endsWith(".jpg") || path.endsWith(".jpeg");
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 10
            rightMargin: 10
        }
        
        Column {
            spacing: 0
            KaakaoLabel {
                text: toolbar.currentTitle
                role: KaakaoLabel.Header
                visible: toolbar.currentFolderDescription === "" || toolbar.currentFolderDescription.startsWith("smart://")
            }
            KaakaoPathControl {
                id: pathControl
                objectName: "pathControl"
                
                readonly property string homePath: String(StandardPaths.writableLocation(StandardPaths.HomeLocation)).replace("file://", "")
                readonly property string displayBasePath: {
                    let p = String(toolbar.currentFolderDescription).replace("file://", "")
                    if (p.startsWith(homePath)) return homePath
                    return "/"
                }
                
                rootLabel: {
                    if (displayBasePath === "/") return qsTr("Root")
                    return displayBasePath.substring(displayBasePath.lastIndexOf("/") + 1)
                }
                
                path: {
                    let p = String(toolbar.currentFolderDescription).replace("file://", "")
                    if (p.startsWith(displayBasePath)) {
                        let rel = p.substring(displayBasePath.length)
                        if (rel.startsWith("/")) rel = rel.substring(1)
                        return rel
                    }
                    return p
                }
                
                visible: toolbar.currentFolderDescription !== "" && !toolbar.currentFolderDescription.startsWith("smart://")
               
                onPathClicked: (targetPath) => {
                    // Reconstruct absolute path
                    let fullPath = displayBasePath
                    if (targetPath !== "") {
                        if (fullPath !== "/") {
                            fullPath += "/" + targetPath
                        } else {
                            fullPath += targetPath
                        }
                    }
                    
                    // Extract folder name for title
                    let parts = targetPath.split("/")
                    let name = parts[parts.length - 1] || toolbar.currentTitle
                    if (targetPath === "") {
                        if (displayBasePath === "/") name = qsTr("Root")
                        else name = displayBasePath.substring(displayBasePath.lastIndexOf("/") + 1)
                    }
                    
                    toolbar.pathClicked(fullPath, name)
                }
            }
        }
        
        Item { Layout.fillWidth: true }

        KaakaoToolButton {
            iconEmoji: "↺"
            text: qsTr("Rotate Left")
            enabled: toolbar.canRotate
            onClicked: toolbar.rotateImage(270)
            KaakaoToolTip { visible: parent.hovered; text: qsTr("Rotate Left (JPEG only)") }
        }

        KaakaoToolButton {
            iconEmoji: "↻"
            text: qsTr("Rotate Right")
            enabled: toolbar.canRotate
            onClicked: toolbar.rotateImage(90)
            KaakaoToolTip { visible: parent.hovered; text: qsTr("Rotate Right (JPEG only)") }
        }

        KaakaoToolButton {
            id: showInfoButton
            objectName: "showInfoButton"
            iconEmoji: "ℹ"
            text: toolbar.showMainInfo ? qsTr("Hide Info") : qsTr("Show Info")
            enabled: toolbar.galleryPanelCurrentIndex >= 0 && galleryModel.count > 0
            onClicked: toolbar.toggleShowMainInfo()
            KaakaoToolTip { visible: parent.hovered; text: qsTr("Show or hide the image info panel") }
        }

        KaakaoSegmentedControl {
            id: viewModeControl
            objectName: "viewModeControl"
            model: [qsTr("Grid"), qsTr("List")]
            visible: !toolbar.previewOverlayVisible
            Layout.alignment: Qt.AlignVCenter
            onCurrentIndexChanged: {
                toolbar.viewModeRequested(currentIndex === 1 ? "list" : "grid")
            }

            Binding {
                target: viewModeControl
                property: "currentIndex"
                value: toolbar.viewMode === "list" ? 1 : 0
            }

            KaakaoToolTip { visible: parent.hovered; text: qsTr("Switch between grid and list view") }
        }

        RowLayout {
            spacing: 2
            Layout.alignment: Qt.AlignVCenter
            visible: !toolbar.previewOverlayVisible

            Text {
                text: "−"
                font.pixelSize: 14
                font.bold: true
                color: Theme.secondaryText
                verticalAlignment: Text.AlignVCenter
            }

            KaakaoSlider {
                id: zoomSlider
                from: 200
                to: 600
                implicitWidth: 100
                leftPadding: 4
                rightPadding: 4
                visible: toolbar.viewMode === "grid"
                onMoved: toolbar.thumbnailSize = value

                Binding {
                    target: zoomSlider
                    property: "value"
                    value: toolbar.thumbnailSize
                }
            }

            KaakaoSlider {
                id: rowHeightSlider
                objectName: "rowHeightSlider"
                from: 24
                to: 48
                implicitWidth: 100
                leftPadding: 4
                rightPadding: 4
                visible: toolbar.viewMode === "list"
                onMoved: toolbar.listRowHeight = value

                Binding {
                    target: rowHeightSlider
                    property: "value"
                    value: toolbar.listRowHeight
                }
            }

            Text {
                text: "+"
                font.pixelSize: 14
                font.bold: true
                color: Theme.secondaryText
                verticalAlignment: Text.AlignVCenter
            }
        }

        KaakaoSearchField {
            id: searchField
            objectName: "searchField"
            placeholderText: qsTr("Search...")
            implicitWidth: 150
            onTextChanged: galleryModel.searchQuery = text
        }
    }
}
