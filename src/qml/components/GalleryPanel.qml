pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore
import Kaakao
import NinjaView

Item {
    id: panel

    // Inputs/Configurations
    property bool confirmDeletions: true
    property bool loading: false
    property string currentFolderPath: ""
    property var folderSelections: ({})
    property int thumbnailSize: 200
    property string viewMode: "grid"
    property int listRowHeight: 28
    property var rotationTimestamps: ({})

    // Sort state for list mode ("name" / "date" / "size")
    property string lastSortKey: ""

    function toggleSort(key) {
        if (panel.lastSortKey === key) {
            galleryModel.sortOrder = (galleryModel.sortOrder === Qt.AscendingOrder) ? Qt.DescendingOrder : Qt.AscendingOrder;
        } else {
            galleryModel.sortOrder = (key === "name") ? Qt.AscendingOrder : Qt.DescendingOrder;
        }
        galleryModel.sortBy = key;
        panel.lastSortKey = key;
    }

    // Multi-selection state
    property var selectedPaths: ({})
    property int lastClickedIndex: -1
    readonly property var selectedPathsList: Object.keys(selectedPaths).filter(function(k) { return selectedPaths[k] === true; })
    readonly property int selectedCount: selectedPathsList.length

    function getSelectedPathsList() {
        return selectedPathsList;
    }

    function toggleSelection(path, index) {
        let newSelections = Object.assign({}, selectedPaths);
        newSelections[path] = !newSelections[path];
        selectedPaths = newSelections;
        lastClickedIndex = index;
    }

    function handleItemClick(path, index, modifiers) {
        if (modifiers & Qt.ControlModifier || modifiers & Qt.MetaModifier) {
            toggleSelection(path, index);
        } else if (modifiers & Qt.ShiftModifier) {
            if (lastClickedIndex !== -1) {
                let start = Math.min(lastClickedIndex, index);
                let end = Math.max(lastClickedIndex, index);
                let newSelections = Object.assign({}, selectedPaths);
                for (let i = start; i <= end; ++i) {
                    let p = galleryModel.getRawPath(i);
                    newSelections[p] = true;
                }
                selectedPaths = newSelections;
            } else {
                toggleSelection(path, index);
            }
        } else {
            let newSelections = {};
            newSelections[path] = true;
            selectedPaths = newSelections;
            lastClickedIndex = index;
            activeView.currentIndex = index; // Keep standard index in sync
        }
    }

    function selectAll() {
        let newSelections = {};
        for (let i = 0; i < galleryModel.count; ++i) {
            newSelections[galleryModel.getRawPath(i)] = true;
        }
        selectedPaths = newSelections;
    }

    function clearSelection() {
        selectedPaths = {};
        lastClickedIndex = -1;
    }

    function performDeleteSingle(index, path) {
        if (index >= 0 && path !== "") {
            if (fileActionService.moveToTrash(path)) {
                galleryModel.removeImage(index)
                let newSelections = Object.assign({}, panel.selectedPaths);
                delete newSelections[path];
                panel.selectedPaths = newSelections;
            }
        }
    }

    function performDeleteBatch(paths) {
        if (fileActionService.moveFilesToTrashBatch(paths)) {
            let indices = [];
            for (let i = 0; i < galleryModel.count; ++i) {
                if (paths.indexOf(galleryModel.getRawPath(i)) !== -1) {
                    indices.push(i);
                }
            }
            indices.sort(function(a, b) { return b - a; });
            indices.forEach(function(idx) {
                galleryModel.removeImage(idx);
            });
            panel.clearSelection();
        }
    }

    // Real path resolver
    readonly property string realFolderPath: {
        if (currentFolderPath === "sd_card_device") {
            return volumeMonitor.sdCardPath ? (volumeMonitor.sdCardPath + "/DCIM") : "";
        } else {
            return currentFolderPath;
        }
    }

    onRealFolderPathChanged: {
        filterScopeBar.currentIndex = 0;
        galleryModel.filterType = "All";
        galleryModel.cameraFilter = "";
        galleryModel.mediaTypeFilter = "All";
        galleryModel.showNewOnly = false;
        panel.clearSelection();
        panel.updateFilters();
    }

    function updateFilters() {
        let baseFilters = [qsTr("All")];
        if (realFolderPath !== "" && typeof exifDatabase !== "undefined" && exifDatabase !== null) {
            let filterData = exifDatabase.getAvailableFiltersForFolder(realFolderPath);
            if (filterData.hasToday) {
                baseFilters.push(qsTr("Today"));
            }
            if (filterData.hasThisWeek) {
                baseFilters.push(qsTr("This Week"));
            }
            if (filterData.hasThisMonth) {
                baseFilters.push(qsTr("This Month"));
            }
            if (filterData.years) {
                for (let i = 0; i < filterData.years.length; i++) {
                    baseFilters.push(filterData.years[i]);
                }
            }
            if (filterData.imageTypes) {
                for (let i = 0; i < filterData.imageTypes.length; i++) {
                    baseFilters.push(filterData.imageTypes[i]);
                }
            }
            let cameras = exifDatabase.getUniqueCamerasForFolder(realFolderPath);
            filterScopeBar.model = baseFilters.concat(cameras);
        } else {
            filterScopeBar.model = baseFilters;
        }
    }

    Connections {
        target: typeof discoveryService !== "undefined" ? discoveryService : null
        function onIndexingFinished() {
            panel.updateFilters();
            galleryModel.invalidateFilter();
        }
    }

    // Signals
    signal folderSelectionsUpdated(var selections)
    signal doubleClicked(int index)
    signal folderDoubleClicked(string path, string name)
    signal parentFolderRequested()

    // Expose internal items.
    // currentIndex is mirrored here so external callers can read/write it regardless
    // of which view mode is active; gridView routes to the active view's inner view.
    property int currentIndex: -1
    readonly property var activeView: viewMode === "list" ? galleryList : galleryGrid.gridView
    readonly property var gridView: activeView

    onCurrentIndexChanged: {
        if (activeView.currentIndex !== currentIndex) {
            activeView.currentIndex = currentIndex
        }
    }

    onViewModeChanged: {
        // Carry selection and focus over to the newly activated view.
        // Note: resolve the target view directly from viewMode instead of the
        // activeView binding, which may not have re-evaluated yet at this point.
        let target = viewMode === "list" ? galleryList : galleryGrid.gridView
        target.currentIndex = panel.currentIndex
        target.forceActiveFocus()
        if (panel.currentIndex >= 0) {
            if (viewMode === "list") {
                galleryList.positionViewAtIndex(panel.currentIndex, ListView.Contain)
            } else {
                galleryGrid.gridView.positionViewAtIndex(panel.currentIndex, GridView.Contain)
            }
        }
    }

    function triggerDelete(index, path, name) {
        deleteConfirmationDialog.isBatch = false
        deleteConfirmationDialog.targetIndex = index
        deleteConfirmationDialog.targetPath = path
        deleteConfirmationDialog.fileName = name
        deleteConfirmationDialog.open()
    }

    function triggerDeleteBatch(paths) {
        deleteConfirmationDialog.isBatch = true
        deleteConfirmationDialog.targetPaths = paths
        deleteConfirmationDialog.fileName = qsTr("%1 items").arg(paths.length)
        deleteConfirmationDialog.open()
    }

    DeleteConfirmationDialog {
        id: deleteConfirmationDialog
        objectName: "deleteConfirmationDialog"
        onAccepted: {
            if (isBatch) {
                panel.performDeleteBatch(targetPaths)
            } else {
                panel.performDeleteSingle(targetIndex, targetPath)
            }
        }
    }

    GalleryContextMenu {
        id: galleryContextMenu
        objectName: "galleryContextMenu"
        galleryPanel: panel
    }

    KaakaoMenu {
        id: folderContextMenu
        property int targetIndex: -1
        property string targetPath: ""
        KaakaoMenuItem {
            text: Qt.platform.os === "osx" ? qsTr("Reveal in Finder") : qsTr("Show in File Manager")
            onTriggered: fileActionService.showInFolder(folderContextMenu.targetPath)
        }
    }

    // Background extension for the scope bar area on the right to ensure a continuous bar
    Rectangle {
        id: scopeBarExtension
        anchors {
            top: parent.top
            left: filterScopeBar.right
            right: parent.right
        }
        height: 24
        color: Theme.isDarkMode ? "#262626" : "#E1E1E1"
        visible: currentFolderPath !== ""

        // 1px solid bottom border to match the scope bar
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.isDarkMode ? "#121212" : "#B0B0B0"
        }
    }

    MediaTypeFilter {
        id: mediaTypeFilter
        anchors {
            right: parent.right
            top: parent.top
            rightMargin: 8
            topMargin: 3
        }
        visible: currentFolderPath !== ""
        galleryModelSource: galleryModel
    }

    KaakaoScopeBar {
        id: filterScopeBar
        objectName: "filterScopeBar"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: mediaTypeFilter.left
        anchors.rightMargin: 10
        height: visible ? 24 : 0
        visible: currentFolderPath !== ""
        label: qsTr("Filter:")
        model: [qsTr("All")]
        currentIndex: 0

        onFilterSelected: (index, name) => {
            if (name === qsTr("All")) {
                galleryModel.filterType = "All"
                galleryModel.cameraFilter = ""
            } else if (name === qsTr("Today")) {
                galleryModel.filterType = "Today"
                galleryModel.cameraFilter = ""
            } else if (name === qsTr("This Week")) {
                galleryModel.filterType = "This Week"
                galleryModel.cameraFilter = ""
            } else if (name === qsTr("This Month")) {
                galleryModel.filterType = "This Month"
                galleryModel.cameraFilter = ""
            } else if (!isNaN(parseInt(name)) && name.length === 4) {
                galleryModel.filterType = name
                galleryModel.cameraFilter = ""
            } else if (name === "JPG" || name === "PNG" || name === "WEBP" || name === "BMP" || name === "MP4" || name === "MOV") {
                galleryModel.filterType = name
                galleryModel.cameraFilter = ""
            } else {
                galleryModel.filterType = "Camera"
                galleryModel.cameraFilter = name
            }
        }
    }

    // Sortable column header is now handled internally by KaakaoTableView.

    KaakaoGridView {
        id: galleryGrid
        objectName: "galleryGrid"
        anchors.top: filterScopeBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: panel.viewMode === "grid"

        model: galleryModel
        cellWidth: panel.thumbnailSize
        cellHeight: panel.thumbnailSize + 30

        WheelHandler {
            id: wheelZoomHandler
            acceptedModifiers: Qt.ControlModifier
            onWheel: (event) => {
                let current = panel.thumbnailSize;
                let target = current;
                if (event.angleDelta.y > 0) {
                    target = Math.min(600, current + 50);
                } else if (event.angleDelta.y < 0) {
                    target = Math.max(200, current - 50);
                }
                if (target !== current) {
                    if (typeof appSettings !== "undefined") {
                        appSettings.thumbnailSize = target;
                    } else {
                        panel.thumbnailSize = target;
                    }
                }
            }
        }
        
        
        gridView.onCurrentIndexChanged: {
            if (panel.loading && gridView.currentIndex !== -1) {
                gridView.currentIndex = -1;
            } else if (!panel.loading) {
                if (panel.currentIndex !== gridView.currentIndex) {
                    panel.currentIndex = gridView.currentIndex;
                }
                if (panel.currentFolderPath) {
                    let selections = panel.folderSelections;
                    selections[panel.currentFolderPath] = gridView.currentIndex;
                    panel.folderSelectionsUpdated(selections);
                }
            }
        }

        gridView.onActiveFocusChanged: {
            if (gridView.activeFocus && gridView.currentIndex === -1 && galleryModel.count > 0) {
                gridView.currentIndex = 0;
            }
        }

        delegate: GalleryGridDelegate {
            selectedPaths: panel.selectedPaths
            selectedCount: panel.selectedCount
            lastClickedIndex: panel.lastClickedIndex
            rotationTimestamps: panel.rotationTimestamps
            galleryModelSource: galleryModel
            exifDatabaseSource: typeof exifDatabase !== "undefined" ? exifDatabase : null
            getImageUrlHelper: root.getImageUrl
            onItemClicked: (rawPath, idx, modifiers) => {
                panel.handleItemClick(rawPath, idx, modifiers)
                galleryGrid.gridView.forceActiveFocus()
            }
            onItemDoubleClicked: (rawPath, idx, isFolder, fileName) => {
                if (isFolder) {
                    panel.folderDoubleClicked(rawPath, fileName)
                } else {
                    panel.doubleClicked(idx)
                }
            }
            onItemRightClicked: (rawPath, idx, isFolder, mouse) => {
                if (isFolder) {
                    folderContextMenu.targetIndex = idx
                    folderContextMenu.targetPath = rawPath
                    folderContextMenu.popup()
                } else {
                    galleryContextMenu.targetIndex = idx
                    galleryContextMenu.targetPath = rawPath
                    galleryContextMenu.popup()
                }
            }
            onSelectionToggled: (rawPath, idx) => {
                panel.toggleSelection(rawPath, idx)
                galleryGrid.gridView.forceActiveFocus()
            }
            onUpdateSelectedPaths: (newSelections) => {
                panel.selectedPaths = newSelections
            }
            onUpdateLastClickedIndex: (newIndex) => {
                panel.lastClickedIndex = newIndex
            }
        }
    }

    KaakaoTableView {
        id: galleryList
        objectName: "galleryList"
        anchors.top: filterScopeBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: panel.viewMode === "list"
        focus: panel.viewMode === "list"

        model: galleryModel

        columns: [
            KaakaoTableColumn {
                title: qsTr("Name")
                role: "name"
                defaultSortOrder: Qt.AscendingOrder
                width: typeof appSettings !== "undefined" ? appSettings.nameColumnWidth : 300
                minWidth: 100
                onWidthChanged: {
                    if (typeof appSettings !== "undefined") {
                        appSettings.nameColumnWidth = width;
                    }
                }
            },
            KaakaoTableColumn {
                title: qsTr("Dimensions")
                role: "dimensions"
                defaultSortOrder: Qt.DescendingOrder
                width: typeof appSettings !== "undefined" ? appSettings.dimsColumnWidth : 90
                minWidth: 60
                onWidthChanged: {
                    if (typeof appSettings !== "undefined") {
                        appSettings.dimsColumnWidth = width;
                    }
                }
            },
            KaakaoTableColumn {
                title: qsTr("Date")
                role: "date"
                defaultSortOrder: Qt.DescendingOrder
                width: typeof appSettings !== "undefined" ? appSettings.dateColumnWidth : 150
                minWidth: 80
                onWidthChanged: {
                    if (typeof appSettings !== "undefined") {
                        appSettings.dateColumnWidth = width;
                    }
                }
            },
            KaakaoTableColumn {
                title: qsTr("Size")
                role: "size"
                defaultSortOrder: Qt.DescendingOrder
                width: typeof appSettings !== "undefined" ? appSettings.sizeColumnWidth : 70
                minWidth: 50
                onWidthChanged: {
                    if (typeof appSettings !== "undefined") {
                        appSettings.sizeColumnWidth = width;
                    }
                }
            }
        ]

        onSortRequested: (role, order) => {
            galleryModel.sortBy = role
            galleryModel.sortOrder = order
        }

        WheelHandler {
            id: listWheelZoomHandler
            acceptedModifiers: Qt.ControlModifier
            onWheel: (event) => {
                let current = panel.listRowHeight;
                let target = current;
                if (event.angleDelta.y > 0) {
                    target = Math.min(48, current + 4);
                } else if (event.angleDelta.y < 0) {
                    target = Math.max(24, current - 4);
                }
                if (target !== current) {
                    if (typeof appSettings !== "undefined") {
                        appSettings.listRowHeight = target;
                    } else {
                        panel.listRowHeight = target;
                    }
                }
            }
        }

        onCurrentIndexChanged: {
            if (panel.loading && galleryList.currentIndex !== -1) {
                galleryList.currentIndex = -1;
            } else if (!panel.loading) {
                if (panel.currentIndex !== galleryList.currentIndex) {
                    panel.currentIndex = galleryList.currentIndex;
                }
                if (panel.currentFolderPath) {
                    let selections = panel.folderSelections;
                    selections[panel.currentFolderPath] = galleryList.currentIndex;
                    panel.folderSelectionsUpdated(selections);
                }
            }
        }

        onActiveFocusChanged: {
            if (galleryList.activeFocus && galleryList.currentIndex === -1 && galleryModel.count > 0) {
                galleryList.currentIndex = 0;
            }
        }

        delegate: GalleryListDelegate {
            selectedPaths: panel.selectedPaths
            selectedCount: panel.selectedCount
            lastClickedIndex: panel.lastClickedIndex
            rotationTimestamps: panel.rotationTimestamps
            rowHeight: panel.listRowHeight
            galleryModelSource: galleryModel
            exifDatabaseSource: typeof exifDatabase !== "undefined" ? exifDatabase : null
            getImageUrlHelper: root.getImageUrl
            columnsList: galleryList.columns
            onItemClicked: (rawPath, idx, modifiers) => {
                panel.handleItemClick(rawPath, idx, modifiers)
                galleryList.forceActiveFocus()
            }
            onItemDoubleClicked: (rawPath, idx, isFolder, fileName) => {
                if (isFolder) {
                    panel.folderDoubleClicked(rawPath, fileName)
                } else {
                    panel.doubleClicked(idx)
                }
            }
            onItemRightClicked: (rawPath, idx, isFolder, mouse) => {
                if (isFolder) {
                    folderContextMenu.targetIndex = idx
                    folderContextMenu.targetPath = rawPath
                    folderContextMenu.popup()
                } else {
                    galleryContextMenu.targetIndex = idx
                    galleryContextMenu.targetPath = rawPath
                    galleryContextMenu.popup()
                }
            }
            onSelectionToggled: (rawPath, idx) => {
                panel.toggleSelection(rawPath, idx)
                galleryList.forceActiveFocus()
            }
            onUpdateSelectedPaths: (newSelections) => {
                panel.selectedPaths = newSelections
            }
            onUpdateLastClickedIndex: (newIndex) => {
                panel.lastClickedIndex = newIndex
            }
            onFolderOpenRequested: (rawPath, fileName) => {
                panel.folderDoubleClicked(rawPath, fileName)
            }
            onParentFolderRequested: {
                panel.parentFolderRequested()
            }
        }
    }

    // Empty state overlay — shown when grid has no items
    GalleryEmptyState {
        anchors {
            top: filterScopeBar.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        galleryModelSource: galleryModel
        loading: panel.loading
        currentFolderPath: panel.currentFolderPath
    }

    // Scanning status indicator
    KaakaoActivityOverlay {
        anchors {
            top: filterScopeBar.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        active: panel.loading
        text: qsTr("Scanning directory...")
    }
}
