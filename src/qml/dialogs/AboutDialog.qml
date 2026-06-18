import QtQuick
import QtQuick.Layouts
import Kaakao

pragma ComponentBehavior: Bound

KaakaoWindow {
    id: root
    
    width: 320
    height: 440
    minimumWidth: width
    maximumWidth: width
    minimumHeight: height
    maximumHeight: height
    
    title: qsTr("About NinjaView")
    
    Column {
        anchors {
            fill: parent
            margins: 24
        }
        spacing: Theme.layoutSpacing

        // App Icon
        Image {
            source: "qrc:/qt/qml/NinjaView/assets/ninja-icon.png"
            width: 120
            height: 120
            fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Column {
            width: parent.width
            spacing: 4
            
            KaakaoLabel {
                text: "NinjaView"
                role: KaakaoLabel.Header
                anchors.horizontalCenter: parent.horizontalCenter
            }

            KaakaoLabel {
                text: qsTr("Version %1 (Build %2)").arg(appVersion).arg(appBuild)
                role: KaakaoLabel.Secondary
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        KaakaoLabel {
            text: qsTr("A high-performance image viewer for rapid photo triage.")
            width: parent.width
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 12
        }

        Column {
            width: parent.width
            spacing: 8
            KaakaoLabel {
                text: qsTr("Credits & Dependencies:")
                role: KaakaoLabel.Small
                font.weight: Font.Bold
            }
            KaakaoLabel {
                text: qsTr("• <b><a href=\"https://www.qt.io\">Qt</a></b> %1 (LGPL v3)<br>• <b><a href=\"https://github.com/veskuh/Kaakao\">Kaakao UI Components</a></b> (BSD 3-Clause)<br>• <b><a href=\"https://github.com/mayanklahiri/easyexif\">easyexif</a></b> (BSD 2-Clause, Copyright © 2010-2015 Mayank Lahiri)").arg(qtVersion)
                role: KaakaoLabel.Small
                width: parent.width
                wrapMode: Text.WordWrap
                textFormat: Text.RichText
                onLinkActivated: (link) => Qt.openUrlExternally(link)
            }
        }

        Item { Layout.fillHeight: true; width: 1 } // Spacer

        KaakaoLabel {
            text: "Copyright © 2026 Vesa-Matti Hartikainen"
            role: KaakaoLabel.Small
            anchors.horizontalCenter: parent.horizontalCenter
        }

        KaakaoButton {
            text: qsTr("Close")
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: root.close()
        }
    }
}
