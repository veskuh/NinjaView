import QtQuick
import QtTest
import NinjaView
import Kaakao

TestCase {
    name: "MainTests"
    width: 900
    height: 600
    visible: true

    NinjaWindow {
        id: mainApp
    }

    function test_initialization() {
        verify(mainApp.visible, "Main window should be visible")
        compare(mainApp.title, "NinjaView", "Title should be correct")
        verify(mainApp.fullScreenEnabled === false, "Fullscreen should be disabled by context property")
    }

    function test_fullscreen_logic() {
        var overlay = findChild(mainApp, "previewOverlay")
        verify(overlay !== null, "Overlay should be found")
        
        overlay.visible = false
        compare(mainApp.requestedVisibility, Window.Windowed, "Requested visibility should be Windowed when overlay is hidden")
        compare(mainApp.visibility, Window.Windowed, "Actual visibility should be Windowed")

        overlay.visible = true
        compare(mainApp.requestedVisibility, Window.FullScreen, "Requested visibility should be FullScreen when overlay is visible")
        compare(mainApp.visibility, Window.Windowed, "Actual visibility should remain Windowed because fullScreenEnabled is false")
        
        overlay.visible = false
    }

    function test_sidebar_model() {
        // sidebar has id 'sidebar'
        verify(mainApp.showMainInfo === false, "Info panel should be hidden initially")
    }

    function test_toggle_info_panel() {
        mainApp.showMainInfo = true
        verify(mainApp.showMainInfo, "Info panel should be visible after toggle")
        
        mainApp.showMainInfo = false
        verify(!mainApp.showMainInfo, "Info panel should be hidden after second toggle")
    }

    function test_space_opens_preview() {
        // Need to find the grid and overlay
        var grid = findChild(mainApp, "galleryGrid")
        var overlay = findChild(mainApp, "previewOverlay")
        var shortcut = findChild(mainApp, "galleryShortcut")
        
        verify(grid !== null, "Grid should be found")
        verify(overlay !== null, "Overlay should be found")
        verify(shortcut !== null, "Shortcut should be found")
        
        overlay.visible = false
        
        // Mock a current index and focus the internal gridView
        grid.currentIndex = 0
        grid.gridView.forceActiveFocus()
        
        shortcut.activated()
        tryVerify(function() { return overlay.visible }, 2000, "Shortcut should open overlay")
    }

    function test_breadcrumb_logic() {
        var pathControl = findChild(mainApp, "pathControl")
        verify(pathControl !== null, "Path control should be found")

        var home = String(StandardPaths.writableLocation(StandardPaths.HomeLocation)).replace("file://", "")
        var deepPath = home + "/Pictures/2024"
        
        mainApp.currentFolderDescription = deepPath
        
        // Verify root label is extracted username
        var username = home.substring(home.lastIndexOf("/") + 1)
        compare(pathControl.rootLabel, username, "Root label should be the username")
        
        // Verify path is relative to home
        compare(pathControl.path, "Pictures/2024", "Breadcrumb path should be relative to home")
        
        // Test external path
        mainApp.currentFolderDescription = "/Volumes/SDCARD/DCIM"
        compare(pathControl.rootLabel, "Root", "Root label should be 'Root' for external paths")
        compare(pathControl.path, "Volumes/SDCARD/DCIM", "Full path should be shown for external paths")
    }

    function test_sidebar_menu_logic() {
        var sidebar = findChild(mainApp, "sidebar")
        var menu = findChild(mainApp, "sidebarContextMenu")
        
        verify(sidebar !== null, "Sidebar should be found")
        verify(menu !== null, "Sidebar menu should be found")
        
        var removeItem = findChild(menu, "removeItem")
        verify(removeItem !== null, "Remove menu item should be found")

        // Test Pictures (system folder, index 0, category 'Library')
        menu.targetIndex = 0
        verify(!removeItem.enabled, "Remove Folder should be disabled for Pictures")
        
        // Test user folder (category 'Folders')
        // Mock a user folder in the model
        mainApp.sidebarModel.append({ name: "Test", category: qsTr("Folders"), path: "/tmp" })
        var lastIndex = mainApp.sidebarModel.count - 1
        menu.targetIndex = lastIndex
        verify(removeItem.enabled, "Remove Folder should be enabled for user folders")
        
        // Cleanup
        mainApp.sidebarModel.remove(lastIndex)
    }

    function test_sidebar_statusbar_buttons() {
        var sidebar = findChild(mainApp, "sidebar")
        var plusButton = findChild(mainApp, "plusButton")
        var minusButton = findChild(mainApp, "minusButton")

        verify(sidebar !== null, "Sidebar should be found")
        verify(plusButton !== null, "Plus button should be found")
        verify(minusButton !== null, "Minus button should be found")

        // Initially index is probably 0 (Pictures, category Library)
        sidebar.currentIndex = 0
        verify(!minusButton.isActive, "Minus button should be disabled for Pictures")

        // Add a mock user folder and select it
        mainApp.sidebarModel.append({ name: "MockUserFolder", category: qsTr("Folders"), path: "/tmp/mock" })
        var userFolderIndex = mainApp.sidebarModel.count - 1

        sidebar.currentIndex = userFolderIndex
        verify(minusButton.isActive, "Minus button should be active for user-added folders")

        // Cleanup
        mainApp.sidebarModel.remove(userFolderIndex)
        sidebar.currentIndex = 0
        verify(!minusButton.isActive, "Minus button should be disabled again after removing folder")
    }
}
