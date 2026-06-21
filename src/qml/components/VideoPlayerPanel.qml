pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia
import QtQuick.Controls
import QtQuick.Layouts
import Kaakao

Item {
    id: root

    required property string path
    required property bool active
    property bool autoplay: true
    property int autoplayDelay: 0

    // Public API
    readonly property alias mouseActive: mouseTracker.mouseActive
    readonly property bool isPlaying: mediaPlayer.playbackState === MediaPlayer.PlayingState
    readonly property alias errorString: mediaPlayer.errorString
    readonly property bool hasError: mediaPlayer.error !== MediaPlayer.NoError

    function play() {
        autoplayDelayTimer.stop()
        mediaPlayer.play()
    }

    function pause() {
        autoplayDelayTimer.stop()
        mediaPlayer.pause()
    }

    function stop() {
        autoplayDelayTimer.stop()
        mediaPlayer.stop()
    }

    function togglePlayback() {
        if (mediaPlayer.playbackState === MediaPlayer.PlayingState) {
            mediaPlayer.pause()
        } else {
            mediaPlayer.play()
        }
    }

    function formatTime(ms) {
        if (isNaN(ms) || ms < 0) return "0:00"
        let totalSecs = Math.floor(ms / 1000)
        let mins = Math.floor(totalSecs / 60)
        let secs = totalSecs % 60
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }

    Timer {
        id: autoplayDelayTimer
        interval: root.autoplayDelay
        repeat: false
        onTriggered: {
            if (root.active && root.path !== "") {
                mediaPlayer.play()
            }
        }
    }

    MediaPlayer {
        id: mediaPlayer
        objectName: "mediaPlayer"
        audioOutput: AudioOutput {}
        videoOutput: videoOutput
        source: (root.active && root.path !== "") ? "file://" + root.path : ""
        loops: MediaPlayer.Infinite

        onSourceChanged: {
            if (root.active && source != "") {
                if (root.autoplay) {
                    if (root.autoplayDelay > 0) {
                        autoplayDelayTimer.start()
                    } else {
                        mediaPlayer.play()
                    }
                }
            } else {
                autoplayDelayTimer.stop()
            }
        }
    }

    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit
    }

    // Glassmorphic Player Controls Overlay
    Rectangle {
        id: controlsPanel
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: mouseTracker.mouseActive ? 32 : 16
        width: Math.min(parent.width - 64, 480)
        height: 48
        radius: 24
        color: "#CC1C1C1C"
        border.color: "#20FFFFFF"
        z: 10
        
        opacity: mouseTracker.mouseActive ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 250 } }
        Behavior on anchors.bottomMargin { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
        
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
                
                // Hover scale effect
                scale: playPauseMouse.containsMouse ? 1.1 : 1.0
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                
                // Smooth Play morphing icon
                Text {
                    anchors.centerIn: parent
                    text: "▶"
                    color: "white"
                    font.pixelSize: 12
                    anchors.horizontalCenterOffset: 1
                    opacity: mediaPlayer.playbackState !== MediaPlayer.PlayingState ? 1.0 : 0.0
                    scale: mediaPlayer.playbackState !== MediaPlayer.PlayingState ? 1.0 : 0.5
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                }
                
                // Smooth Pause morphing icon
                Text {
                    anchors.centerIn: parent
                    text: "⏸"
                    color: "white"
                    font.pixelSize: 12
                    opacity: mediaPlayer.playbackState === MediaPlayer.PlayingState ? 1.0 : 0.0
                    scale: mediaPlayer.playbackState === MediaPlayer.PlayingState ? 1.0 : 0.5
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                }
                
                MouseArea {
                    id: playPauseMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        root.forceActiveFocus()
                        root.togglePlayback()
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
                    when: !seekBar.pressed
                }
            }
            
            KaakaoLabel {
                text: root.formatTime(mediaPlayer.position) + " / " + root.formatTime(mediaPlayer.duration)
                color: "white"
                font.pixelSize: 11
            }
        }
    }

    MouseArea {
        id: mouseTracker
        anchors.fill: parent
        hoverEnabled: true
        property bool mouseActive: true
        property real lastMoveTime: 0
        
        onPositionChanged: {
            mouseActive = true
            lastMoveTime = Date.now()
        }
        
        onClicked: {
            root.forceActiveFocus()
            root.togglePlayback()
        }
        
        Timer {
            interval: 2000
            running: root.visible && mediaPlayer.playbackState === MediaPlayer.PlayingState
            repeat: true
            onTriggered: {
                if (Date.now() - mouseTracker.lastMoveTime > 2000) {
                    mouseTracker.mouseActive = false
                }
            }
        }
    }
}
