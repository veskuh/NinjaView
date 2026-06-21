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
            videoPlayer.stop()
        } else if (isCurrentVideo) {
            videoPlayer.play()
        }
    }

    onCurrentIndexChanged: {
        videoPlayer.stop()
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

    // Reusable Video Player Panel
    VideoPlayerPanel {
        id: videoPlayer
        anchors.fill: parent
        visible: root.isCurrentVideo && root.currentImagePath !== ""
        path: root.currentImagePath
        active: root.visible
        autoplay: true
        autoplayDelay: 0
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
