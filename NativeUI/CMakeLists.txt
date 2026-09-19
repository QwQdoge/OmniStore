cmake_minimum_required(VERSION 3.21)
project(OmniStoreNativePreview VERSION 0.1.0 LANGUAGES CXX)

include(CTest)
include(GNUInstallDirs)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Test LinguistTools)
qt_standard_project_setup(REQUIRES 6.8)

# MeoUI remains the one shared QML design-system dependency. This preview
# deliberately consumes the installed module rather than copying components
# from the source repository or the Flutter client.
find_program(OMNISTORE_QTPATHS_EXECUTABLE
    NAMES qtpaths6 qtpaths
    HINTS "/usr/lib/qt6/bin"
    REQUIRED
)
execute_process(
    COMMAND "${OMNISTORE_QTPATHS_EXECUTABLE}" --query QT_INSTALL_QML
    OUTPUT_VARIABLE _qt_qml_root
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
execute_process(
    COMMAND "${OMNISTORE_QTPATHS_EXECUTABLE}" --query QT_INSTALL_BINS
    OUTPUT_VARIABLE _qt_bin_root
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
set(MEOUI_IMPORT_ROOT "${_qt_qml_root}" CACHE PATH
    "QML import root containing the installed MeoUI module")
if(NOT EXISTS "${MEOUI_IMPORT_ROOT}/MeoUI/qmldir")
    message(FATAL_ERROR
        "MEOUI_IMPORT_ROOT must contain MeoUI/qmldir; got '${MEOUI_IMPORT_ROOT}'")
endif()

qt_add_executable(OmniStoreNativePreview
    src/main.cpp
    src/installedusageadapter.cpp
    src/installedusagemodel.cpp
)

qt_add_qml_module(OmniStoreNativePreview
    URI org.meo.omnistore.native
    VERSION 1.0
    NO_IMPORT_SCAN
    QML_FILES
        qml/Main.qml
        qml/pages/LibraryPage.qml
        qml/pages/DiscoverUnavailablePage.qml
)

# This preview deliberately has no Account connection or persistent app
# settings. Its display language therefore follows the system locale. The
# command-line override in main.cpp is validation-only and never writes a
# system or account preference.
set(OMNISTORE_NATIVE_TRANSLATIONS_BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/translations")
set(MEOUI_TRANSLATIONS_DEVELOPMENT_DIR "${MEOUI_IMPORT_ROOT}/translations")
qt_add_lupdate(
    SOURCE_TARGETS OmniStoreNativePreview
    TS_FILES translations/omnistore_native_zh_CN.ts
    LUPDATE_TARGET omnistore_native_update_translations
)
qt_add_lrelease(
    LRELEASE_TARGET omnistore_native_lrelease
    TS_FILES translations/omnistore_native_zh_CN.ts
    QM_OUTPUT_DIRECTORY "${OMNISTORE_NATIVE_TRANSLATIONS_BUILD_DIR}"
    QM_FILES_OUTPUT_VARIABLE OMNISTORE_NATIVE_TRANSLATION_QM_FILES
)
add_dependencies(OmniStoreNativePreview omnistore_native_lrelease)

target_include_directories(OmniStoreNativePreview PRIVATE src)
target_link_libraries(OmniStoreNativePreview PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
)
target_compile_definitions(OmniStoreNativePreview PRIVATE
    OMNISTORE_NATIVE_TRANSLATIONS_BUILD_DIR="${OMNISTORE_NATIVE_TRANSLATIONS_BUILD_DIR}"
    OMNISTORE_NATIVE_TRANSLATIONS_INSTALL_DIR="${CMAKE_INSTALL_FULL_DATADIR}/omnistore-native/translations"
    MEOUI_TRANSLATIONS_DEVELOPMENT_DIR="${MEOUI_TRANSLATIONS_DEVELOPMENT_DIR}"
    MEOUI_TRANSLATIONS_INSTALL_DIR="${CMAKE_INSTALL_FULL_DATADIR}/meoui-qml/translations"
)
set_property(TARGET OmniStoreNativePreview APPEND PROPERTY
    QT_QML_IMPORT_PATH "${MEOUI_IMPORT_ROOT}")

if(BUILD_TESTING)
    qt_add_executable(tst_installedusageadapter
        tests/tst_installedusageadapter.cpp
        src/installedusageadapter.cpp
    )
    target_include_directories(tst_installedusageadapter PRIVATE src)
    target_link_libraries(tst_installedusageadapter PRIVATE Qt6::Core Qt6::Test)
    target_compile_definitions(tst_installedusageadapter PRIVATE
        OMNISTORE_NATIVE_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}")

    add_test(NAME omnistore_native.installed_usage_adapter
        COMMAND tst_installedusageadapter)

    find_program(OMNISTORE_QMLTESTRUNNER
        NAMES qmltestrunner
        HINTS "${_qt_bin_root}"
        REQUIRED
    )
    add_test(NAME omnistore_native.shell
        COMMAND "${OMNISTORE_QMLTESTRUNNER}"
                -input "${CMAKE_CURRENT_SOURCE_DIR}/tests/tst_shell.qml"
                -import "${MEOUI_IMPORT_ROOT}"
                -o -,txt)
    set_tests_properties(omnistore_native.shell PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software")
endif()
