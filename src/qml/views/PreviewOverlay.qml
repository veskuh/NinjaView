pragma ComponentBehavior: Bound

import QtQuick
import Kaakao
import NinjaView
import QtMultimedia
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    anchors.fill: parent
    visible: false

    required property var model
    property int currentIndex: -1
    property var getImageUrl: null
    property var rotateImage: null

    function resolveImageUrl(path) {
        if (!path) return ""
        if (typeof getImageUrl === "function") {
            return getImageUrl(path)
        }
        return "image://gallery/" + path
    }
    
    // Helper to get total count from different model types
    readonly property int modelCount: {
        let m = root.model
        if (!m) return 0
        if (m.count !== undefined) return m.count
        if (typeof m.rowCount === 'function') return m.rowCount()
        return 0
    }

    // Helper to get path from different model types
    function getPath(idx) {
        let m = root.model
        if (!m) {
            if (logger.loggingEnabled) logger.log("getPath(" + idx + ") FAILED: model is null", "Model")
            return ""
        }
        if (idx < 0) return ""
        
        let rowCount = 0
        try {
            if (typeof m.rowCount === 'function') rowCount = m.rowCount()
            else if (m.count !== undefined) rowCount = m.count
        } catch (e) {
            if (logger.loggingEnabled) logger.log("getPath(" + idx + ") EXCEPTION reading count: " + e, "Model")
            return ""
        }
        
        if (idx >= rowCount) {
            if (logger.loggingEnabled) logger.log("getPath(" + idx + ") FAILED: out of bounds (count=" + rowCount + ")", "Model")
            return ""
        }
        
        let path = ""
        try {
            // Try C++ model helper first
            if (typeof m.getRawPath === 'function') {
                path = m.getRawPath(idx)
            } else if (typeof m.get === 'function') {
                // Fallback for QML ListModel
                let item = m.get(idx)
                if (item && item.rawPath !== undefined && item.rawPath !== null) {
                    path = item.rawPath.toString()
                }
            } else if (typeof m.index === 'function' && typeof m.data === 'function') {
                // Fallback for standard QAbstractItemModel
                let qidx = m.index(idx, 0)
                if (qidx) {
                    let data = m.data(qidx, 259) // RawPathRole
                    if (data !== undefined && data !== null) {
                        path = data.toString()
                    }
                }
            }
        } catch (e) {
            if (logger.loggingEnabled) logger.log("getPath(" + idx + ") EXCEPTION resolving path: " + e, "Model")
        }
        
        return path
    }

    function isFolder(idx) {
        let m = root.model
        if (!m || idx < 0) return false
        
        let rowCount = 0
        try {
            if (typeof m.rowCount === 'function') rowCount = m.rowCount()
            else if (m.count !== undefined) rowCount = m.count
        } catch (e) {
            return false
        }
        if (idx >= rowCount) return false

        try {
            if (typeof m.isFolder === 'function') {
                return m.isFolder(idx)
            }
            if (typeof m.index === 'function' && typeof m.data === 'function') {
                let qidx = m.index(idx, 0)
                if (qidx) {
                    let data = m.data(qidx, Qt.UserRole + 4) // IsFolderRole
                    if (data !== undefined && data !== null) {
                        return data
                    }
                }
            }
        } catch (e) {
            // ignore
        }
        return false
    }

    function isVideo(idx) {
        let m = root.model
        if (!m || idx < 0) return false
        
        let rowCount = 0
        try {
            if (typeof m.rowCount === 'function') rowCount = m.rowCount()
            else if (m.count !== undefined) rowCount = m.count
        } catch (e) {
            return false
        }
        if (idx >= rowCount) return false

        try {
            if (typeof m.isVideo === 'function') {
                return m.isVideo(idx)
            }
            if (typeof m.index === 'function' && typeof m.data === 'function') {
                let qidx = m.index(idx, 0)
                if (qidx) {
                    let data = m.data(qidx, Qt.UserRole + 5) // IsVideoRole
                    if (data !== undefined && data !== null) {
                        return data
                    }
                }
            }
        } catch (e) {
            // ignore
        }
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

    function formatTime(ms) {
        if (isNaN(ms) || ms < 0) return "0:00"
        let totalSecs = Math.floor(ms / 1000)
        let mins = Math.floor(totalSecs / 60)
        let secs = totalSecs % 60
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }
    readonly property string nextImagePath: {
        let idx = root.getNextImageIndex(root.currentIndex)
        return idx !== -1 ? root.getPath(idx) : ""
    }
    readonly property string prevImagePath: {
        let idx = root.getPrevImageIndex(root.currentIndex)
        return idx !== -1 ? root.getPath(idx) : ""
    }

    onCurrentImagePathChanged: {
        if (logger.loggingEnabled) {
            logger.log("currentImagePath changed to: '" + currentImagePath + "' (index=" + root.currentIndex + ")", "UI")
        }
    }

    onNextImagePathChanged: {
        if (logger.loggingEnabled && nextImagePath !== "") {
            logger.log("Prefetching next image: " + nextImagePath, "UI")
        }
    }

    onPrevImagePathChanged: {
        if (logger.loggingEnabled && prevImagePath !== "") {
            logger.log("Prefetching previous image: " + prevImagePath, "UI")
        }
    }

    property bool showInfo: false

    // Zoom and Navigation state aliases mapped to ZoomableImage
    property alias fitToScreen: zoomableImage.fitToScreen
    property alias zoomLevel: zoomableImage.zoomLevel
    readonly property alias currentZoom: zoomableImage.currentZoom
    readonly property alias fitZoomLevel: zoomableImage.fitZoomLevel

    opacity: 0.0
    property bool _isFadingOut: false
    property bool _restoringVisible: false

    NumberAnimation {
        id: fadeInAnimation
        target: root
        property: "opacity"
        to: 1.0
        duration: 200
        easing.type: Easing.OutQuad
    }

    NumberAnimation {
        id: fadeOutAnimation
        target: root
        property: "opacity"
        to: 0.0
        duration: 200
        easing.type: Easing.OutQuad
        onFinished: {
            _isFadingOut = false
            root.visible = false
        }
    }

    Timer {
        id: autoplayDelayTimer
        interval: 350 // slight delay to allow transition to fullscreen to complete
        repeat: false
        onTriggered: {
            if (root.visible && root.isCurrentVideo) {
                mediaPlayer.play()
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            if (_restoringVisible) {
                return
            }
            if (_isFadingOut) {
                _isFadingOut = false
                fadeOutAnimation.stop()
            }
            fadeInAnimation.start()
            root.forceActiveFocus()
            if (root.isCurrentVideo) {
                autoplayDelayTimer.start()
            }
        } else {
            autoplayDelayTimer.stop()
            mediaPlayer.stop()
            if (opacity > 0.0 && !_isFadingOut) {
                _isFadingOut = true
                _restoringVisible = true
                root.visible = true
                _restoringVisible = false
                fadeOutAnimation.start()
            } else if (!_isFadingOut) {
                root.showInfo = false
                zoomableImage.reset()
            }
        }
    }

    onCurrentIndexChanged: {
        autoplayDelayTimer.stop()
        mediaPlayer.stop()
        zoomableImage.reset()
    }

    // Hidden pre-fetchers to cache adjacent images asynchronously
    readonly property size prefetchSize: Qt.size(4096, 4096)

    Image { 
        id: nextPrefetchImage
        source: root.nextImagePath ? resolveImageUrl(root.nextImagePath) : ""
        visible: false
        asynchronous: true
        cache: true
        sourceSize: root.prefetchSize
        onStatusChanged: {
            if (logger.loggingEnabled && status === Image.Ready) {
                logger.log("Pre-fetch READY: next image " + source, "Performance")
            }
        }
    }
    Image { 
        id: prevPrefetchImage
        source: root.prevImagePath ? resolveImageUrl(root.prevImagePath) : ""
        visible: false
        asynchronous: true
        cache: true
        sourceSize: root.prefetchSize
        onStatusChanged: {
            if (logger.loggingEnabled && status === Image.Ready) {
                logger.log("Pre-fetch READY: previous image " + source, "Performance")
            }
        }
    }

    // Viewport background
    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    // Modular Zoomable Image viewport
    ZoomableImage {
        id: zoomableImage
        anchors.fill: parent
        visible: !root.isCurrentVideo
        source: (root.currentImagePath && !root.isCurrentVideo) ? resolveImageUrl(root.currentImagePath) : ""
    }

    // Native Video Player
    Item {
        id: videoPlayerContainer
        anchors.fill: parent
        visible: root.isCurrentVideo && root.currentImagePath !== ""

        MediaPlayer {
            id: mediaPlayer
            objectName: "mediaPlayer"
            audioOutput: AudioOutput {}
            videoOutput: videoOutput
            source: (root.visible && !root._isFadingOut && root.currentImagePath && root.isCurrentVideo) ? "file://" + root.currentImagePath : ""
            loops: MediaPlayer.Infinite

            onSourceChanged: {
                if (root.visible && root.isCurrentVideo && source != "") {
                    if (fadeInAnimation.running) {
                        autoplayDelayTimer.start()
                    } else {
                        mediaPlayer.play()
                    }
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
                if (mediaPlayer.playbackState === MediaPlayer.PlayingState) {
                    mediaPlayer.pause()
                } else {
                    mediaPlayer.play()
                }
            }
            
            Timer {
                interval: 2000
                running: videoPlayerContainer.visible && mediaPlayer.playbackState === MediaPlayer.PlayingState
                repeat: true
                onTriggered: {
                    if (Date.now() - mouseTracker.lastMoveTime > 2000) {
                        mouseTracker.mouseActive = false
                    }
                }
            }
        }

        // Error Feedback overlay
        Rectangle {
            anchors.fill: parent
            color: "#CC000000"
            visible: mediaPlayer.error !== MediaPlayer.NoError && root.isCurrentVideo
            z: 15

            Column {
                anchors.centerIn: parent
                spacing: 12
                width: Math.min(parent.width - 64, 320)

                Text {
                    text: "⚠️"
                    font.pixelSize: 32
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Playback Error"
                    color: "white"
                    font.bold: true
                    font.pixelSize: 16
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: mediaPlayer.errorString || "The video format is not supported or the file is corrupted."
                    color: "#A0A0A0"
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    // Hidden cursor Area during fullscreen (Mac OS X viewer aesthetic)
    MouseArea {
        id: cursorMouseArea
        objectName: "cursorMouseArea"
        anchors.fill: parent
        cursorShape: {
            if (!root.visible) return Qt.ArrowCursor;
            if (!root.isCurrentVideo) return Qt.BlankCursor;
            return (typeof mouseTracker !== "undefined" && mouseTracker && mouseTracker.mouseActive) ? Qt.ArrowCursor : Qt.BlankCursor;
        }
        enabled: false // Don't block clicks
        z: 1 
    }

    ExifOverlay {
        id: infoPanel
        anchors {
            left: parent.left
            top: parent.top
            margins: 20
        }
        exifData: (root.currentImagePath && typeof exifReader !== 'undefined' && exifReader) ? exifReader.getExifData(root.currentImagePath) : ({})
        visible: root.showInfo && root.currentImagePath !== ""
        name: currentImagePath
    }

    Column {
        id: errorOverlay
        anchors.centerIn: parent
        spacing: 16
        visible: zoomableImage.isError && root.currentImagePath !== ""

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "⚠️"
            font.pixelSize: 64
        }

        KaakaoLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Failed to load image")
            font.weight: Font.Bold
            font.pixelSize: 16
            color: "white"
        }

        KaakaoLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.currentImagePath
            font.pixelSize: 12
            color: "#888888"
            elide: Text.ElideMiddle
            width: Math.min(root.width - 80, 400)
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // Image counter — "3 / 42" shown at the bottom center
    readonly property int imagePosition: {
        if (root.currentIndex < 0 || root.modelCount === 0) return 0
        let pos = 0
        for (let i = 0; i <= root.currentIndex && i < root.modelCount; i++) {
            if (!root.isFolder(i)) pos++
        }
        return pos
    }
    readonly property int imageTotal: {
        let total = 0
        for (let i = 0; i < root.modelCount; i++) {
            if (!root.isFolder(i)) total++
        }
        return total
    }

    KaakaoLabel {
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 16
        }
        text: root.imagePosition + " / " + root.imageTotal
        color: "#AAFFFFFF"
        font.pixelSize: 12
        visible: root.imageTotal > 1
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            root.visible = false
            event.accepted = true
        } else if (event.key === Qt.Key_I) {
            root.showInfo = !root.showInfo
            event.accepted = true
        } else if (event.key === Qt.Key_L) {
            if (typeof rotateImage === "function") rotateImage(270)
            event.accepted = true
        } else if (event.key === Qt.Key_R) {
            if (typeof rotateImage === "function") rotateImage(90)
            event.accepted = true
        } else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
            zoomableImage.applyZoom(Math.min(zoomableImage.currentZoom * 1.1, 20.0), zoomableImage.width / 2, zoomableImage.height / 2)
            event.accepted = true
        } else if (event.key === Qt.Key_Minus || event.key === Qt.Key_Hyphen) {
            zoomableImage.applyZoom(Math.max(zoomableImage.currentZoom * 0.9, 0.01), zoomableImage.width / 2, zoomableImage.height / 2)
            event.accepted = true
        } else if (event.key === Qt.Key_Space) {
            if (root.isCurrentVideo) {
                if (mediaPlayer.playbackState === MediaPlayer.PlayingState) {
                    mediaPlayer.pause()
                } else {
                    mediaPlayer.play()
                }
            } else {
                if (zoomableImage.fitToScreen) {
                    zoomableImage.applyZoom(1.0, zoomableImage.width / 2, zoomableImage.height / 2)
                } else {
                    zoomableImage.fitToScreen = true
                }
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            let nextIdx = root.getNextImageIndex(root.currentIndex)
            if (nextIdx !== -1) {
                if (logger.loggingEnabled) logger.log("Navigating Forward from index " + root.currentIndex + " to " + nextIdx, "UI")
                root.currentIndex = nextIdx
            } else {
                if (logger.loggingEnabled) logger.log("Navigating Forward BLOCKED (at end of images)", "UI")
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            let prevIdx = root.getPrevImageIndex(root.currentIndex)
            if (prevIdx !== -1) {
                if (logger.loggingEnabled) logger.log("Navigating Backward from index " + root.currentIndex + " to " + prevIdx, "UI")
                root.currentIndex = prevIdx
            } else {
                if (logger.loggingEnabled) logger.log("Navigating Backward BLOCKED (at start of images)", "UI")
            }
            event.accepted = true
        }
    }
}
