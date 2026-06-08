
macro(add_ninjaview_test name)
    add_executable(${name} ${ARGN})
    target_link_libraries(${name} PRIVATE
        Qt6::Test
        Qt6::Core
        Qt6::Gui
        Qt6::Quick
        Qt6::Concurrent
        NinjaViewLib
    )
    add_test(NAME ${name} COMMAND ${name})
endmacro()

add_ninjaview_test(tst_gallerylistmodel tst_gallerylistmodel.cpp)
add_ninjaview_test(tst_filediscoveryservice tst_filediscoveryservice.cpp)
add_ninjaview_test(tst_asyncimageprovider tst_asyncimageprovider.cpp)
add_ninjaview_test(tst_logger tst_logger.cpp)
add_ninjaview_test(tst_exifreader tst_exifreader.cpp)
add_ninjaview_test(tst_volumemonitor tst_volumemonitor.cpp)
add_ninjaview_test(tst_fileactionservice tst_fileactionservice.cpp)
add_ninjaview_test(tst_exifdatabase tst_exifdatabase.cpp)
add_ninjaview_test(tst_galleryfilterproxymodel tst_galleryfilterproxymodel.cpp)

# Copy test data to build directory
file(COPY data DESTINATION "${CMAKE_CURRENT_BINARY_DIR}")

# QML UI Tests
macro(add_qml_test name qml_file)
    add_executable(${name} qml_test_launcher.cpp)
    target_link_libraries(${name} PRIVATE 
        Qt6::Core 
        Qt6::Gui 
        Qt6::Qml 
        Qt6::Quick 
        Qt6::Test 
        Qt6::QuickTest 
        Qt6::Sql
        Kaakao
        NinjaViewLibplugin
    )
    target_include_directories(${name} PRIVATE 
        ../src 
        ../src/core 
        ../src/ui 
        ../3rdparty/easyexif
    )
    # Copy at configure time (fresh builds / reconfigure)
    configure_file(${qml_file} ${CMAKE_CURRENT_BINARY_DIR}/${qml_file} COPYONLY)
    # Also copy at build time (incremental builds where QML changed but C++ didn't)
    add_custom_command(
        TARGET ${name} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
                ${CMAKE_CURRENT_SOURCE_DIR}/${qml_file}
                ${CMAKE_CURRENT_BINARY_DIR}/${qml_file}
        COMMENT "Copying QML test file ${qml_file}"
    )
    target_compile_definitions(${name} PRIVATE QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_BINARY_DIR}")
    add_test(NAME ${name} COMMAND ${name} -input ${qml_file})
    set_tests_properties(${name} PROPERTIES ENVIRONMENT "QML_IMPORT_PATH=${CMAKE_BINARY_DIR}/qml")
endmacro()

add_qml_test(tst_previewoverlay tst_previewoverlay.qml)
add_qml_test(tst_aboutdialog tst_aboutdialog.qml)
add_qml_test(tst_exifoverlay tst_exifoverlay.qml)
add_qml_test(tst_main tst_main.qml)
add_qml_test(tst_settingswindow tst_settingswindow.qml)
