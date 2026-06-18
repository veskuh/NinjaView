import QtQuick
import QtTest
import NinjaView
import Kaakao

TestCase {
    name: "PreviewOverlayTests"
    width: 800
    height: 600
    visible: true

    // Mock logger for tests
    QtObject {
        id: logger
        property bool loggingEnabled: false
        property string logFilePath: ""
        function log(message, category) {}
    }

    property var mockModel: ListModel {
        ListElement { rawPath: "/tmp/test1.jpg" }
        ListElement { rawPath: "/tmp/test2.jpg" }
        ListElement { rawPath: "/tmp/test3.jpg" }
        function isVideo(idx) { return idx === 1 }
        function isFolder(idx) { return false }
    }

    PreviewOverlay {
        id: overlay
        anchors.fill: parent
        model: mockModel
        currentIndex: 0
        visible: false
    }

    function test_visibility_and_cursor() {
        var cursorMouseArea = findChild(overlay, "cursorMouseArea")
        verify(cursorMouseArea !== null, "Cursor MouseArea should be found")

        overlay.visible = true
        verify(overlay.visible, "Overlay should be visible")
        compare(cursorMouseArea.cursorShape, Qt.BlankCursor, "Cursor should be blank when overlay is visible")
        
        overlay.visible = false
        tryVerify(function() { return !overlay.visible }, 1000, "Overlay should be hidden")
        compare(cursorMouseArea.cursorShape, Qt.ArrowCursor, "Cursor should be arrow when overlay is hidden")
    }

    function test_navigation() {
        overlay.visible = true
        overlay.currentIndex = 0
        overlay.forceActiveFocus()
        
        compare(overlay.currentIndex, 0, "Initial index should be 0")
        
        keyClick(Qt.Key_Right)
        compare(overlay.currentIndex, 1, "Index should increment on Right arrow")
        
        keyClick(Qt.Key_Right)
        compare(overlay.currentIndex, 2, "Index should increment again on Right arrow")
        
        keyClick(Qt.Key_Right)
        compare(overlay.currentIndex, 2, "Index should not increment past bounds")
        
        keyClick(Qt.Key_Left)
        compare(overlay.currentIndex, 1, "Index should decrement on Left arrow")
        
        keyClick(Qt.Key_Escape)
        tryVerify(function() { return !overlay.visible }, 1000, "Overlay should hide on Escape")
    }

    function test_zoom() {
        overlay.visible = true
        overlay.fitToScreen = true
        overlay.forceActiveFocus()
        compare(overlay.fitToScreen, true, "Should start in fit-to-screen mode")
        
        keyClick(Qt.Key_Space)
        compare(overlay.fitToScreen, false, "Should zoom in on Space")
        compare(overlay.zoomLevel, 1.0, "Should zoom to 100% (1.0)")
        
        keyClick(Qt.Key_Space)
        compare(overlay.fitToScreen, true, "Should zoom back out on Space")
    }

    function test_video_stop_on_close() {
        // Navigate to the video item (index 1)
        overlay.currentIndex = 1
        overlay.visible = true
        overlay.forceActiveFocus()

        // Verify it is recognized as video and source is loaded
        var mediaPlayer = findChild(overlay, "mediaPlayer")
        console.log("--- DEBUG VIDEO STOP ON CLOSE ---")
        console.log("mockModel count:", mockModel.count)
        console.log("mockModel get(1):", mockModel.get(1))
        console.log("mockModel get(1) rawPath:", mockModel.get(1) ? mockModel.get(1).rawPath : "null")
        console.log("visible:", overlay.visible)
        console.log("_isFadingOut:", overlay._isFadingOut)
        console.log("currentImagePath:", overlay.currentImagePath)
        console.log("isCurrentVideo:", overlay.isCurrentVideo)
        console.log("mediaPlayer:", mediaPlayer)
        console.log("mediaPlayer source:", mediaPlayer ? mediaPlayer.source : "null")
        console.log("---------------------------------")
        verify(mediaPlayer !== null, "MediaPlayer should be found")
        verify(overlay.isCurrentVideo, "Should be recognized as a video")
        verify(mediaPlayer.source.toString() !== "", "MediaPlayer source should be populated when visible")

        // Close the overlay using Escape
        keyClick(Qt.Key_Escape)
        
        // The fade-out animation takes 200ms, let's verify visibility becomes false
        tryVerify(function() { return !overlay.visible }, 1000, "Overlay should hide on Escape")

        // The source should be cleared
        compare(mediaPlayer.source.toString(), "", "MediaPlayer source should be cleared when overlay is hidden")

        // Reset state for subsequent tests
        overlay.currentIndex = 0
        overlay.visible = false
    }
}
