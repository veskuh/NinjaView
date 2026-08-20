pragma ComponentBehavior: Bound

import QtQuick
import Kaakao
import NinjaView
import QtMultimedia
import QtQuick.Controls
import QtQuick.Layouts

import "ModelResolver.js" as ModelResolver

Item {
    id: root
    anchors.fill: parent
    visible: false

    required property var model
    property int currentIndex: -1
    property var getImageUrl: null
    property var rotateImage: null
    property var rotationTimestamps: ({})

    function resolveImageUrl(path, timestamp) {
        if (!path) return ""
        if (typeof getImageUrl === "function") {
            return getImageUrl(path, timestamp)
        }
        return "image://gallery/" + path + (timestamp ? ("?t=" + timestamp) : "")
    }
    
    readonly property int modelCount: ModelResolver.getModelCount(root.model)

    function getPath(idx) {
        return ModelResolver.getPath(root.model, idx, logger.loggingEnabled, logger)
    }

    function isFolder(idx) {
        return ModelResolver.isFolder(root.model, idx)
    }

    function isVideo(idx) {
        return ModelResolver.isVideo(root.model, idx)
    }

    function getNextImageIndex(idx) {
        return ModelResolver.getNextImageIndex(root.model, idx)
    }

    function getPrevImageIndex(idx) {
        return ModelResolver.getPrevImageIndex(root.model, idx)
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
        } else {
            videoPlayer.stop()
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
        videoPlayer.stop()
        zoomableImage.reset()
        updateImageCounts()
    }

    onModelChanged: {
        updateImageCounts()
    }

    Connections {
        target: root.model
        ignoreUnknownSignals: true
        function onCountChanged() {
            root.updateImageCounts()
        }
    }

    function updateImageCounts() {
        let m = root.model
        let currIdx = root.currentIndex
        let count = root.modelCount
        
        if (!m || currIdx < 0 || count <= 0) {
            root.imagePosition = 0
            root.imageTotal = 0
            return
        }

        let pos = 0
        let total = 0
        for (let i = 0; i < count; i++) {
            if (!root.isFolder(i)) {
                total++
                if (i <= currIdx) {
                    pos = total
                }
            }
        }
        root.imagePosition = pos
        root.imageTotal = total
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
        readonly property var rotationTimestamp: (root.rotationTimestamps && root.currentImagePath) ? root.rotationTimestamps[root.currentImagePath] : undefined
        source: (root.currentImagePath && !root.isCurrentVideo) ? resolveImageUrl(root.currentImagePath, rotationTimestamp) : ""
    }

    // Native Video Player
    // Reusable Video Player Panel
    VideoPlayerPanel {
        id: videoPlayer
        anchors.fill: parent
        visible: root.isCurrentVideo && root.currentImagePath !== ""
        path: root.currentImagePath
        active: root.visible && !root._isFadingOut
        autoplay: true
        autoplayDelay: 350
    }

    // Hidden cursor Area during fullscreen (Mac OS X viewer aesthetic)
    MouseArea {
        id: cursorMouseArea
        objectName: "cursorMouseArea"
        anchors.fill: parent
        cursorShape: {
            if (!root.visible) return Qt.ArrowCursor;
            if (!root.isCurrentVideo) return Qt.BlankCursor;
            return videoPlayer.mouseActive ? Qt.ArrowCursor : Qt.BlankCursor;
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
    property int imagePosition: 0
    property int imageTotal: 0

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
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
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
                videoPlayer.togglePlayback()
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
