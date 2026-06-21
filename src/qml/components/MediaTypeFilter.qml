import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic
import Kaakao
import NinjaView

Rectangle {
    id: filterContainer
    
    property var galleryModelSource
    
    width: segmentRow.implicitWidth + 4
    height: 18
    radius: 4
    color: Theme.isDarkMode ? "#262626" : "#E1E1E1"
    border.color: Theme.isDarkMode ? "#3F3F3F" : "#D0D0D0"
    border.width: 1

    property int activeIndex: {
        if (typeof galleryModelSource === "undefined" || !galleryModelSource) return 0;
        if (galleryModelSource.mediaTypeFilter === "Photos") return 1;
        if (galleryModelSource.mediaTypeFilter === "Videos") return 2;
        return 0; // Default or "All"
    }

    Row {
        id: segmentRow
        anchors.centerIn: parent
        spacing: 1

        Repeater {
            model: [qsTr("All"), qsTr("Photos"), qsTr("Videos")]
            delegate: Basic.Button {
                id: segButton
                required property string modelData
                required property int index

                implicitHeight: 14
                implicitWidth: segText.implicitWidth + 12
                padding: 0

                Gradient {
                    id: selectionGradient
                    GradientStop { position: 0.0; color: Theme.segmentedSelectionGradTop }
                    GradientStop { position: 1.0; color: Theme.segmentedSelectionGradBottom }
                }

                background: Rectangle {
                    radius: 3
                    gradient: filterContainer.activeIndex === index ? selectionGradient : null
                    color: {
                        if (filterContainer.activeIndex === index) {
                            return "transparent"
                        }
                        if (segButton.hovered) {
                            return Theme.isDarkMode ? "#3D3D3D" : "#E5E5E5"
                        }
                        return "transparent"
                    }
                    border.color: filterContainer.activeIndex === index ? Theme.buttonBorder : "transparent"
                    border.width: filterContainer.activeIndex === index ? 1 : 0
                }

                contentItem: Text {
                    id: segText
                    text: modelData
                    font.family: Theme.defaultFont.family
                    font.pixelSize: 10
                    font.weight: filterContainer.activeIndex === index ? Font.Bold : Font.Normal
                    color: Theme.primaryText
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    renderType: Text.NativeRendering
                }

                onClicked: {
                    if (!galleryModelSource) return;
                    if (index === 0) {
                        galleryModelSource.mediaTypeFilter = "All"
                    } else if (index === 1) {
                        galleryModelSource.mediaTypeFilter = "Photos"
                    } else if (index === 2) {
                        galleryModelSource.mediaTypeFilter = "Videos"
                    }
                }
            }
        }
    }
}
