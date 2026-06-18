pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import Kaakao
import NinjaView

Item {
    id: root

    required property var model
    required property int currentIndex
    required property var getImageUrl

    signal closeRequested()
    signal requestIndexChange(int index)

    onVisibleChanged: {
        if (!visible) {
            mediaPlayer.stop()
        } else if (isCurrentVideo) {
            mediaPlayer.play()
        }
    }

    onCurrentIndexChanged: {
        mediaPlayer.stop()
    }

    function resolveImageUrl(path) {
        if (!path) return ""
        if (typeof getImageUrl === "function") {
            return getImageUrl(path)
        }
        return "image://gallery/" + path
    }

    readonly property int modelCount: {
        let m = root.model
        if (!m) return 0
        if (m.count !== undefined) return m.count
        if (typeof m.rowCount === 'function') return m.rowCount()
        return 0
    }

    function getPath(idx) {
        let m = root.model
        if (!m || idx < 0 || idx >= root.modelCount) return ""
        if (typeof m.getRawPath === 'function') return m.getRawPath(idx)
        return ""
    }

    function isFolder(idx) {
        let m = root.model
        if (!m || idx < 0 || idx >= root.modelCount) return false
        if (typeof m.isFolder === 'function') return m.isFolder(idx)
        return false
    }

    function isVideo(idx) {
        let m = root.model
        if (!m || idx < 0 || idx >= root.modelCount) return false
        if (typeof m.isVideo === 'function') return m.isVideo(idx)
        return false
    }

    function getNextImageIndex(idx) {
        let next = idx + 1
        while (next < root.modelCount && root.isFolder(next)) {
            next++
        }
        return next < root.modelCount ? next : -1
    }

    function getPrevImageIndex(idx) {
        let prev = idx - 1
        while (prev >= 0 && root.isFolder(prev)) {
            prev--
        }
        return prev >= 0 ? prev : -1
    }

    readonly property string currentImagePath: root.getPath(root.currentIndex)
    readonly property bool isCurrentVideo: root.isVideo(root.currentIndex)

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    ZoomableImage {
        id: zoomableImage
        anchors.fill: parent
        visible: !root.isCurrentVideo
        source: (root.currentImagePath && !root.isCurrentVideo) ? root.resolveImageUrl(root.currentImagePath) : ""
    }

    Item {
        id: videoPlayerContainer
        anchors.fill: parent
        visible: root.isCurrentVideo && root.currentImagePath !== ""

        MediaPlayer {
            id: mediaPlayer
            objectName: "mediaPlayer"
            audioOutput: AudioOutput {}
            videoOutput: videoOutput
            source: (root.visible && root.currentImagePath && root.isCurrentVideo) ? "file://" + root.currentImagePath : ""
            loops: MediaPlayer.Infinite
            Component.onCompleted: {
                if (root.visible && root.isCurrentVideo) play()
            }
            onSourceChanged: {
                if (root.visible && root.isCurrentVideo && source != "") play()
            }
        }

        VideoOutput {
            id: videoOutput
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectFit
        }

        Rectangle {
            id: controlsPanel
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 16
            width: Math.min(parent.width - 64, 480)
            height: 48
            radius: 24
            color: "#CC1C1C1C"
            border.color: "#20FFFFFF"
            z: 10

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                Rectangle {
                    id: playPauseButton
                    width: 28
                    height: 28
                    radius: 14
                    color: playPauseMouse.pressed ? "#30FFFFFF" : (playPauseMouse.containsMouse ? "#15FFFFFF" : "transparent")

                    Text {
                        anchors.centerIn: parent
                        text: mediaPlayer.playbackState !== MediaPlayer.PlayingState ? "▶" : "⏸"
                        color: "white"
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: playPauseMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (mediaPlayer.playbackState === MediaPlayer.PlayingState) {
                                mediaPlayer.pause()
                            } else {
                                mediaPlayer.play()
                            }
                        }
                    }
                }

                Slider {
                    id: seekBar
                    Layout.fillWidth: true
                    from: 0
                    to: mediaPlayer.duration
                    focusPolicy: Qt.NoFocus
                    onMoved: mediaPlayer.position = value

                    Binding {
                        target: seekBar
                        property: "value"
                        value: mediaPlayer.position
                    }
                }

                KaakaoLabel {
                    text: root.formatTime(mediaPlayer.position) + " / " + root.formatTime(mediaPlayer.duration)
                    color: "white"
                    font.pixelSize: 11
                }
            }
        }
    }

    function formatTime(ms) {
        if (isNaN(ms) || ms < 0) return "0:00"
        let totalSecs = Math.floor(ms / 1000)
        let mins = Math.floor(totalSecs / 60)
        let secs = totalSecs % 60
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }

    focus: true
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Space || event.key === Qt.Key_Return) {
            root.closeRequested()
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            let nextIdx = root.getNextImageIndex(root.currentIndex)
            if (nextIdx !== -1) root.requestIndexChange(nextIdx)
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            let prevIdx = root.getPrevImageIndex(root.currentIndex)
            if (prevIdx !== -1) root.requestIndexChange(prevIdx)
            event.accepted = true
        }
    }
}
