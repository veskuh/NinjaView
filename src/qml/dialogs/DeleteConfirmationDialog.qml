import QtQuick
import QtQuick.Controls
import Kaakao

KaakaoSheet {
    id: root
    
    width: 400
    height: 170
    
    property bool isBatch: false
    property var targetPaths: []
    property int targetIndex: -1
    property string targetPath: ""
    property string fileName: ""
    
    signal accepted()
    
    contentItem: Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        KaakaoLabel {
            text: qsTr("Move to Trash")
            font.weight: Font.Bold
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
        }

        Row {
            width: parent.width
            spacing: 16
            
            Text {
                text: "🗑️"
                font.pixelSize: 36
                verticalAlignment: Text.AlignTop
            }

            KaakaoLabel {
                text: qsTr("Are you sure you want to move \"%1\" to the Trash?").arg(root.fileName)
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
                onClicked: root.close()
            }
            KaakaoButton {
                text: qsTr("Move to Trash")
                highlighted: true
                onClicked: {
                    root.accepted()
                    root.close()
                }
            }
        }
    }
}
