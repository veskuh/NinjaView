import QtQuick
import Kaakao
import NinjaView

Item {
    id: emptyState
    
    property var galleryModelSource
    property bool loading: false
    property string currentFolderPath: ""

    visible: galleryModelSource && galleryModelSource.count === 0 && !loading && currentFolderPath !== ""

    Column {
        anchors.centerIn: parent
        spacing: 8

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (galleryModelSource && (galleryModelSource.searchQuery !== "" || galleryModelSource.filterType !== "All")) ? "🔍" : "📂"
            font.pixelSize: 40
        }
        KaakaoLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (galleryModelSource && (galleryModelSource.searchQuery !== "" || galleryModelSource.filterType !== "All"))
                  ? qsTr("No matching images")
                  : qsTr("No images found")
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        KaakaoLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (galleryModelSource && (galleryModelSource.searchQuery !== "" || galleryModelSource.filterType !== "All"))
                  ? qsTr("Try a different search or filter")
                  : qsTr("This folder contains no supported images")
            color: Theme.secondaryText
            font.pixelSize: 11
        }
    }
}
