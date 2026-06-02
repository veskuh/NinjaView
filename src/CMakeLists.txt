# Move QML and core logic to a library
qt_add_library(NinjaViewLib STATIC
    core/FileDiscoveryService.cpp
    core/VolumeMonitor.cpp
    core/ExifReader.cpp
    core/ExifDatabase.cpp
    core/FileActionService.cpp
    core/Logger.cpp
    ../3rdparty/easyexif/exif.cpp
    ui/GalleryListModel.cpp
    ui/GalleryFilterProxyModel.cpp
    ui/AsyncImageProvider.cpp
)

# Move QML and core logic to a library

qt_add_qml_module(NinjaViewLib
    URI NinjaView
    VERSION 1.0
    NO_CACHEGEN
    RESOURCE_PREFIX "/qt/qml"
    QML_FILES
        qml/views/NinjaWindow.qml
        qml/views/PreviewOverlay.qml
        qml/components/ZoomableImage.qml
        qml/components/SidebarPanel.qml
        qml/components/GalleryPanel.qml
        qml/components/ImageInfoPanel.qml
        qml/components/ExifOverlay.qml
        qml/dialogs/SettingsWindow.qml
        qml/dialogs/AboutDialog.qml
    RESOURCES
        ../assets/ninja-icon.png
    DEPENDENCIES
        Kaakao
)

target_link_libraries(NinjaViewLib PUBLIC
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::QuickDialogs2
    Qt6::Core5Compat
    Qt6::ShaderTools
    Qt6::Concurrent
    Qt6::Sql
    Kaakao
)

target_include_directories(NinjaViewLib PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/core
    ${CMAKE_CURRENT_SOURCE_DIR}/ui
    ${CMAKE_CURRENT_SOURCE_DIR}/../3rdparty/easyexif
)

# Application executable
set(MACOSX_BUNDLE_ICON_FILE ninja-icon.icns)
set(icon_files "${CMAKE_CURRENT_SOURCE_DIR}/../assets/ninja-icon.icns")
set_source_files_properties(${icon_files} PROPERTIES MACOSX_PACKAGE_LOCATION "Resources")

qt_add_executable(NinjaViewApp
    MACOSX_BUNDLE
    NinjaMain.cpp
    ${icon_files}
)

set_target_properties(NinjaViewApp PROPERTIES
    OUTPUT_NAME "NinjaView"
    MACOSX_BUNDLE_BUNDLE_NAME "NinjaView"
    MACOSX_BUNDLE_GUI_IDENTIFIER "net.veskuh.ninjaview"
)

if(UNIX AND NOT APPLE)
    set_target_properties(NinjaViewApp PROPERTIES
        OUTPUT_NAME "ninjaview"
    )
endif()

target_link_libraries(NinjaViewApp PRIVATE
    NinjaViewLib
    NinjaViewLibplugin
)

if(APPLE)
    set(APP_INSTALL_DESTINATION ".")
else()
    set(APP_INSTALL_DESTINATION ".")
endif()

if(UNIX AND NOT APPLE)
    set_target_properties(NinjaViewApp PROPERTIES
        INSTALL_RPATH "\$ORIGIN/../${CMAKE_INSTALL_LIBDIR}/ninjaview"
    )
endif()

install(TARGETS NinjaViewApp
    BUNDLE DESTINATION ${APP_INSTALL_DESTINATION}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

if(APPLE)
    # Copy Kaakao into the bundle before Qt deployment resolves dependencies
    install(CODE "
        set(_bundle \"\${CMAKE_INSTALL_PREFIX}/NinjaView.app\")
        set(_frameworks_dir \"\${_bundle}/Contents/Frameworks\")
        file(MAKE_DIRECTORY \"\${_frameworks_dir}\")
        file(INSTALL \"$<TARGET_FILE:Kaakao>\" DESTINATION \"\${_frameworks_dir}\")
        execute_process(
            COMMAND install_name_tool -id
                @rpath/libKaakao.dylib
                \"\${_frameworks_dir}/libKaakao.dylib\"
        )
    ")
endif()

# Use Qt's deploy script without QML import scanning to prevent it from pulling in 
# huge unnecessary dependencies like VirtualKeyboard or WebEngine.

# Prevent CMake from stripping the absolute RPATH during install so macdeployqt can find the Qt libraries
if(APPLE)
    set_target_properties(NinjaViewApp PROPERTIES
        INSTALL_RPATH_USE_LINK_PATH TRUE
    )

    # Custom minimal deploy:
    # 1. We run macdeployqt manually. Qt's built-in qt_generate_deploy_qml_app_script 
    #    silently injects '-appstore-compliant' which causes the 5-minute build time.
    #    By calling it directly with just -no-strip, it completes in ~15 seconds.
    # 2. We prune the unused frameworks (VirtualKeyboard, etc) to achieve the 50-60MB size.
    install(CODE "
        message(STATUS \"Running macdeployqt on \${CMAKE_INSTALL_PREFIX}/NinjaView.app\")
        execute_process(
            COMMAND \"$<TARGET_FILE:Qt6::macdeployqt>\" \"\${CMAKE_INSTALL_PREFIX}/NinjaView.app\" -no-strip -always-overwrite -qmldir=${CMAKE_SOURCE_DIR}
            RESULT_VARIABLE _macdeployqt_res
        )
        if(NOT _macdeployqt_res EQUAL 0)
            message(FATAL_ERROR \"macdeployqt failed\")
        endif()

        message(STATUS \"Pruning unused Qt frameworks to minimize bundle size...\")
        set(APP_CONTENTS \"\${CMAKE_INSTALL_PREFIX}/NinjaView.app/Contents\")
        
        # List of massive frameworks we know NinjaView explicitly does not need
        set(UNUSED_FRAMEWORKS
            QtVirtualKeyboard.framework
            Qt3DCore.framework
            Qt3DQuick.framework
            Qt3DQuickScene2D.framework
            Qt3DQuickScene3D.framework
            Qt3DRender.framework
            Qt3DLogic.framework
            Qt3DInput.framework
            Qt3DAnimation.framework
            Qt3DExtras.framework
            QtMultimedia.framework
            QtMultimediaQuick.framework
        )
        
        foreach(fw IN LISTS UNUSED_FRAMEWORKS)
            file(REMOVE_RECURSE \"\${APP_CONTENTS}/Frameworks/\${fw}\")
        endforeach()

        # Remove VirtualKeyboard and Multimedia plugins
        file(REMOVE_RECURSE \"\${APP_CONTENTS}/PlugIns/platforminputcontexts/libqtvirtualkeyboardplugin.dylib\")
        file(REMOVE_RECURSE \"\${APP_CONTENTS}/PlugIns/multimedia\")
        
        # Remove FFMPEG libraries
        file(GLOB FFMPEG_LIBS \"\${APP_CONTENTS}/Frameworks/libav*.dylib\" \"\${APP_CONTENTS}/Frameworks/libsw*.dylib\")
        foreach(lib IN LISTS FFMPEG_LIBS)
            file(REMOVE \"\${lib}\")
        endforeach()
        
        # Ad-hoc codesign the final pruned bundle (required on Apple Silicon)
        message(STATUS \"Signing \${CMAKE_INSTALL_PREFIX}/NinjaView.app...\")
        execute_process(
            COMMAND codesign --force --deep --sign - \"\${CMAKE_INSTALL_PREFIX}/NinjaView.app\"
            OUTPUT_QUIET ERROR_QUIET
        )
    ")
endif()
