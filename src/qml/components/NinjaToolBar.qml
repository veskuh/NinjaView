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

    signal rotateImage(int angle)
    signal toggleShowMainInfo()
    signal pathClicked(string fullPath, string name)

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
            enabled: {
                let idx = toolbar.previewOverlayVisible ? toolbar.previewOverlayCurrentIndex : toolbar.galleryPanelCurrentIndex
                return toolbar.isJpegFile(idx)
            }
            onClicked: toolbar.rotateImage(270)
        }

        KaakaoToolButton {
            iconEmoji: "↻"
            text: qsTr("Rotate Right")
            enabled: {
                let idx = toolbar.previewOverlayVisible ? toolbar.previewOverlayCurrentIndex : toolbar.galleryPanelCurrentIndex
                return toolbar.isJpegFile(idx)
            }
            onClicked: toolbar.rotateImage(90)
        }

        KaakaoToolButton {
            iconEmoji: "🔍"
            text: toolbar.showMainInfo ? qsTr("Hide Info") : qsTr("Show Info")
            enabled: toolbar.galleryPanelCurrentIndex >= 0 && galleryModel.count > 0
            onClicked: toolbar.toggleShowMainInfo()
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
