import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Kaakao

pragma ComponentBehavior: Bound

KaakaoWindow {
    id: root
    
    width: 750
    height: 550
    minimumWidth: width
    maximumWidth: width
    minimumHeight: height
    maximumHeight: height
    
    title: qsTr("User Guide")
    
    ColumnLayout {
        anchors {
            fill: parent
            margins: 20
        }
        spacing: 15

        KaakaoLabel {
            text: qsTr("NinjaView User Guide")
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
                id: contentColumn
                width: scrollView.availableWidth - 10
                spacing: 12

                KaakaoLabel {
                    text: qsTr("Getting Started")
                    font.bold: true
                    role: KaakaoLabel.Primary
                    Layout.fillWidth: true
                }

                KaakaoLabel {
                    text: qsTr("NinjaView is a fast, lightweight tool designed for rapid photo triage. To begin, add a folder containing images (such as from a digital camera's SD card) using the <b>Add Folder</b> (+) button in the sidebar.")
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    role: KaakaoLabel.Secondary
                    textFormat: Text.RichText
                }

                KaakaoLabel {
                    text: qsTr("Triage Workflow")
                    font.bold: true
                    role: KaakaoLabel.Primary
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                }

                KaakaoLabel {
                    text: qsTr("1. <b>Browse</b>: Use the arrow keys to navigate the grid of thumbnails.<br>"
                               + "2. <b>Quick Look</b>: Press <b>Space</b> to instantly show or hide a high-resolution preview of the selected image.<br>"
                               + "3. <b>Fullscreen</b>: Press <b>Return</b> (or double-click) to open the image in immersive fullscreen view. Press <b>Escape</b> to exit.<br>"
                               + "4. <b>Copy</b>: Press <b>" + (Qt.platform.os === "osx" ? "Cmd+C" : "Ctrl+C") + "</b> to copy the image data directly to your clipboard, allowing you to paste it into other applications (like Finder, Slack, or Photoshop).<br>"
                               + "5. <b>Trash</b>: Press <b>Delete</b> (or Backspace) to move unwanted files directly to the trash folder.")
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    role: KaakaoLabel.Secondary
                    textFormat: Text.RichText
                }

                KaakaoLabel {
                    text: qsTr("Metadata & Favorites")
                    font.bold: true
                    role: KaakaoLabel.Primary
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                }

                KaakaoLabel {
                    text: qsTr("Press <b>" + (Qt.platform.os === "osx" ? "Cmd+I" : "Ctrl+I") + "</b> to toggle the Info Panel on the right. Here you can view camera EXIF tags, write local notes, assign custom tags, and mark images as Favorites by clicking the star (★). Notes and tags are saved locally and persist across sessions.")
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    role: KaakaoLabel.Secondary
                    textFormat: Text.RichText
                }

                KaakaoLabel {
                    text: qsTr("Video Playback & Media Types")
                    font.bold: true
                    role: KaakaoLabel.Primary
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                }

                KaakaoLabel {
                    text: qsTr("NinjaView natively supports both images and video formats (MP4 and MOV). In fullscreen preview, video files will autoplay. To keep the playback experience immersive, the mouse cursor and player overlay auto-hide after a brief period of inactivity; simply move the mouse to reveal them again.")
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    role: KaakaoLabel.Secondary
                    textFormat: Text.RichText
                }

                KaakaoLabel {
                    text: qsTr("SD Card Auto-Detection")
                    font.bold: true
                    role: KaakaoLabel.Primary
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                }

                KaakaoLabel {
                    text: qsTr("Triage newly captured photos directly from your digital camera using NinjaView's plug-and-play volume monitoring. When a camera's SD card is inserted, the application detects the device and automatically refreshes your workspace, making manual directory navigation unnecessary.")
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    role: KaakaoLabel.Secondary
                    textFormat: Text.RichText
                }

                KaakaoLabel {
                    text: qsTr("Smart Date & Camera Filtering")
                    font.bold: true
                    role: KaakaoLabel.Primary
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                }

                KaakaoLabel {
                    text: qsTr("Isolate specific photos using the smart filter bar. NinjaView extracts and indexes camera metadata, allowing you to filter your active directory by date range (<b>Today</b>, <b>This Week</b>, <b>This Month</b>, or specific years) or target only photos taken by a particular camera model.")
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    role: KaakaoLabel.Secondary
                    textFormat: Text.RichText
                }

                KaakaoLabel {
                    text: qsTr("Lossless Rotation & Read-Only Fallbacks")
                    font.bold: true
                    role: KaakaoLabel.Primary
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                }

                KaakaoLabel {
                    text: qsTr("Correct the orientation of vertical shots quickly using <b>" + (Qt.platform.os === "osx" ? "Cmd+[" : "Ctrl+[") + "</b> or <b>" + (Qt.platform.os === "osx" ? "Cmd+]" : "Ctrl+]") + "</b>. NinjaView losslessly updates the orientation tag in the JPEG EXIF header directly on disk. If the image is stored on a write-protected card, the app falls back to in-memory rotation so you can view it correctly for the active session without error.")
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    role: KaakaoLabel.Secondary
                    textFormat: Text.RichText
                }

                KaakaoLabel {
                    text: qsTr("Performance & Customization")
                    font.bold: true
                    role: KaakaoLabel.Primary
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                }

                KaakaoLabel {
                    text: qsTr("Adjust settings such as delete confirmation dialogs and the maximum memory cache size in <b>Preferences</b> (<b>" + (Qt.platform.os === "osx" ? "Cmd+," : "Ctrl+,") + "</b>). Increasing the memory cache limit allows more high-resolution images to remain decoded in memory for smoother browsing.")
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    role: KaakaoLabel.Secondary
                    textFormat: Text.RichText
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
