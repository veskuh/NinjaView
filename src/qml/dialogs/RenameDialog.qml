import QtQuick
import QtQuick.Controls
import Kaakao
import NinjaView

KaakaoSheet {
    id: root

    width: 420
    implicitHeight: contentCol.implicitHeight + 32

    property string targetPath: ""
    property string originalName: ""
    property string errorMessage: ""

    function openForPath(path) {
        targetPath = path
        let slashIdx = path.lastIndexOf("/")
        originalName = (slashIdx >= 0) ? path.substring(slashIdx + 1) : path
        nameInput.text = originalName
        errorMessage = ""
        root.open()

        // Pre-select stem without extension
        let dotIdx = originalName.lastIndexOf(".")
        if (dotIdx > 0) {
            nameInput.select(0, dotIdx)
        } else {
            nameInput.selectAll()
        }
        nameInput.forceActiveFocus()
    }

    function attemptRename() {
        let trimmed = nameInput.text.trim()
        if (trimmed.length === 0) {
            errorMessage = qsTr("File name cannot be empty.")
            return
        }
        if (trimmed === "." || trimmed === ".." || trimmed.indexOf("/") !== -1 || trimmed.indexOf("\\") !== -1) {
            errorMessage = qsTr("File name contains invalid characters.")
            return
        }
        if (trimmed === originalName) {
            root.close()
            return
        }

        let res = fileActionService.renameFile(targetPath, trimmed)
        if (res === 0) {
            root.close()
        } else if (res === 1) {
            errorMessage = qsTr("Invalid file name.")
        } else if (res === 2) {
            errorMessage = qsTr("A file with this name already exists.")
        } else if (res === 3) {
            errorMessage = qsTr("Source file no longer exists.")
        } else {
            errorMessage = qsTr("Could not rename file (permission or disk error).")
        }
    }

    contentItem: Column {
        id: contentCol
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        KaakaoLabel {
            text: qsTr("Rename")
            font.weight: Font.Bold
            font.pixelSize: 14
            width: parent.width
        }

        KaakaoLabel {
            text: qsTr("Enter a new name for \"%1\":").arg(root.originalName)
            width: parent.width
            elide: Text.ElideMiddle
        }

        KaakaoTextField {
            id: nameInput
            objectName: "renameTextField"
            width: parent.width
            onAccepted: root.attemptRename()
            onTextChanged: {
                if (root.errorMessage !== "") {
                    root.errorMessage = ""
                }
            }
            Keys.onEscapePressed: root.close()
        }

        KaakaoLabel {
            text: root.errorMessage
            color: "#D32F2F"
            font.pixelSize: 11
            visible: root.errorMessage !== ""
            width: parent.width
            wrapMode: Text.WordWrap
        }

        Item {
            width: 1
            height: 4
        }

        Row {
            anchors.right: parent.right
            spacing: 8

            KaakaoButton {
                text: qsTr("Cancel")
                onClicked: root.close()
            }
            KaakaoButton {
                text: qsTr("Rename")
                highlighted: true
                enabled: nameInput.text.trim().length > 0
                onClicked: root.attemptRename()
            }
        }
    }
}
