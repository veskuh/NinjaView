import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Kaakao

pragma ComponentBehavior: Bound

KaakaoWindow {
    id: root
    
    width: 450
    height: 500
    minimumWidth: width
    maximumWidth: width
    minimumHeight: height
    maximumHeight: height
    
    title: qsTr("Keyboard Shortcuts")
    
    readonly property string cmdKey: Qt.platform.os === "osx" ? "Cmd" : "Ctrl"
    
    ColumnLayout {
        anchors {
            fill: parent
            margins: 20
        }
        spacing: 15

        KaakaoLabel {
            text: qsTr("Keyboard Shortcuts")
            role: KaakaoLabel.Header
            Layout.alignment: Qt.AlignHCenter
        }

        ScrollView {
            id: scrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                width: scrollView.availableWidth - 10
                spacing: 15

                // Section: Navigation & Viewing
                KaakaoLabel {
                    text: qsTr("Navigation & Viewing")
                    font.bold: true
                    role: KaakaoLabel.Primary
                }

                GridLayout {
                    columns: 2
                    columnSpacing: 20
                    rowSpacing: 6
                    Layout.fillWidth: true

                    KaakaoLabel { text: qsTr("Quick Look / Close"); role: KaakaoLabel.Secondary }
                    KaakaoLabel { text: "Space"; font.weight: Font.Bold }

                    KaakaoLabel { text: qsTr("Show Fullscreen"); role: KaakaoLabel.Secondary }
                    KaakaoLabel { text: "Return / Double-click"; font.weight: Font.Bold }

                    KaakaoLabel { text: qsTr("Zoom In / Out"); role: KaakaoLabel.Secondary }
                    KaakaoLabel { text: cmdKey + " + / " + cmdKey + " -"; font.weight: Font.Bold }

                    KaakaoLabel { text: qsTr("Default Size"); role: KaakaoLabel.Secondary }
                    KaakaoLabel { text: cmdKey + " 0"; font.weight: Font.Bold }

                    KaakaoLabel { text: qsTr("Show / Hide Info"); role: KaakaoLabel.Secondary }
                    KaakaoLabel { text: cmdKey + " I"; font.weight: Font.Bold }
                }

                // Section: Image Actions
                KaakaoLabel {
                    text: qsTr("Image Actions")
                    font.bold: true
                    role: KaakaoLabel.Primary
                    Layout.topMargin: 10
                }

                GridLayout {
                    columns: 2
                    columnSpacing: 20
                    rowSpacing: 6
                    Layout.fillWidth: true

                    KaakaoLabel { text: qsTr("Copy Image"); role: KaakaoLabel.Secondary }
                    KaakaoLabel { text: cmdKey + " C"; font.weight: Font.Bold }

                    KaakaoLabel { text: qsTr("Rotate Clockwise"); role: KaakaoLabel.Secondary }
                    KaakaoLabel { text: cmdKey + " ]"; font.weight: Font.Bold }

                    KaakaoLabel { text: qsTr("Rotate Counterclockwise"); role: KaakaoLabel.Secondary }
                    KaakaoLabel { text: cmdKey + " ["; font.weight: Font.Bold }

                    KaakaoLabel { text: qsTr("Show in Finder / File Manager"); role: KaakaoLabel.Secondary }
                    KaakaoLabel { text: cmdKey + " R"; font.weight: Font.Bold }

                    KaakaoLabel { text: qsTr("Open with Default Application"); role: KaakaoLabel.Secondary }
                    KaakaoLabel { text: cmdKey + " O"; font.weight: Font.Bold }

                    KaakaoLabel { text: qsTr("Move to Trash"); role: KaakaoLabel.Secondary }
                    KaakaoLabel { text: "Delete / Backspace"; font.weight: Font.Bold }
                }

                // Section: Application
                KaakaoLabel {
                    text: qsTr("Application")
                    font.bold: true
                    role: KaakaoLabel.Primary
                    Layout.topMargin: 10
                }

                GridLayout {
                    columns: 2
                    columnSpacing: 20
                    rowSpacing: 6
                    Layout.fillWidth: true

                    KaakaoLabel { text: qsTr("Refresh Library"); role: KaakaoLabel.Secondary }
                    KaakaoLabel { text: "F5"; font.weight: Font.Bold }

                    KaakaoLabel { text: qsTr("Preferences"); role: KaakaoLabel.Secondary }
                    KaakaoLabel { text: cmdKey + " ,"; font.weight: Font.Bold }

                    KaakaoLabel { text: qsTr("Quit"); role: KaakaoLabel.Secondary }
                    KaakaoLabel { text: cmdKey + " Q"; font.weight: Font.Bold }
                }
            }
        }

        KaakaoButton {
            text: qsTr("Close")
            Layout.alignment: Qt.AlignHCenter
            onClicked: root.close()
        }
    }
}
