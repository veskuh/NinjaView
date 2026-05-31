import QtQuick
import Kaakao

Rectangle {
    id: root

    color: Qt.rgba(0, 0, 0, 0.7)
    radius: Theme.radiusLarge
    property var exifData
    property string name

    width: 250
    height: infoColumn.height + Theme.standardPadding

    Column {
        id: infoColumn
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Theme.paddingMedium
        }
        spacing: 5

        Row {
            spacing: 5
            
            Text {
                text: "★"
                color: "#FFC107"
                font.pixelSize: 14
                font.bold: true
                visible: !!root.exifData.Favorite
                y: -1
            }
            
            KaakaoLabel {
                text: qsTr("Information")
                role: KaakaoLabel.Header
                color: "white"
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(1, 1, 1, 0.3)
        }

        Repeater {
            model: [
                {
                    label: "Filename",
                    value: root.name
                },
                {
                    label: "Make",
                    value: root.exifData.Make
                },
                {
                    label: "Model",
                    value: root.exifData.Model
                },
                {
                    label: "Lens",
                    value: root.exifData.Lens
                },
                {
                    label: "Exposure",
                    value: root.exifData.Exposure
                },
                {
                    label: "Aperture",
                    value: root.exifData.Aperture
                },
                {
                    label: "ISO",
                    value: root.exifData.ISO
                },
                {
                    label: "Focal Length",
                    value: root.exifData.FocalLength
                },
                {
                    label: "Date",
                    value: root.exifData.DateTime
                },
                {
                    label: "Tags",
                    value: root.exifData.Tags
                }
            ]
            delegate: Row {
                required property var modelData
                width: parent.width
                spacing: 10
                visible: modelData.value !== undefined && modelData.value !== "" && modelData.value !== 0
                KaakaoLabel {
                    text: modelData.label + ":"
                    width: 80
                    color: "#AAA"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignRight
                }
                KaakaoLabel {
                    text: String(modelData.value)
                    width: parent.width - 90 // 80 (label) + 10 (spacing)
                    elide: modelData.label === "Filename" ? Text.ElideLeft : Text.ElideRight
                    color: "white"
                    font.pixelSize: 11
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(1, 1, 1, 0.3)
            visible: root.exifData.Notes !== undefined && root.exifData.Notes !== ""
        }

        KaakaoLabel {
            text: qsTr("Notes:")
            color: "#AAA"
            font.pixelSize: 11
            visible: root.exifData.Notes !== undefined && root.exifData.Notes !== ""
        }

        KaakaoLabel {
            text: String(root.exifData.Notes)
            width: parent.width
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            color: "white"
            font.pixelSize: 11
            visible: root.exifData.Notes !== undefined && root.exifData.Notes !== ""
        }
    }
}
