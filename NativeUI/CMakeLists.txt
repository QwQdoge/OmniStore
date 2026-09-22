cmake_minimum_required(VERSION 3.21)
project(OmniStoreNative VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(QT_QML_GENERATE_QMLLS_INI ON)

find_package(Qt6 6.6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2)
qt_standard_project_setup(REQUIRES 6.6)

# Development builds can point at a MeoUI checkout. Production MeoArch builds
# normally consume the separately installed MeoUI QML module from /usr/lib/qt6/qml.
set(MEOUI_SOURCE_DIR "" CACHE PATH "Optional MeoUI source checkout for development builds")
if(MEOUI_SOURCE_DIR AND EXISTS "${MEOUI_SOURCE_DIR}/CMakeLists.txt")
    set(MEOUI_BUILD_SHOWCASE OFF CACHE BOOL "Build MeoUI showcase" FORCE)
    add_subdirectory("${MEOUI_SOURCE_DIR}" "${CMAKE_BINARY_DIR}/meoui" EXCLUDE_FROM_ALL)
endif()

qt_add_executable(omnistore-native
    app/main.cpp
    app/backendbridge.cpp
    app/backendbridge.h
)

qt_add_qml_module(omnistore-native
    URI OmniStore.Native
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/components/AppRow.qml
        qml/components/UpdateRow.qml
        qml/components/PageHeading.qml
        qml/pages/HomePage.qml
        qml/pages/SearchPage.qml
        qml/pages/UpdatesPage.qml
        qml/pages/InstalledPage.qml
        qml/pages/TasksPage.qml
        qml/pages/SettingsPage.qml
)

target_link_libraries(omnistore-native PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
)

target_compile_definitions(omnistore-native PRIVATE
    OMNISTORE_SOURCE_ROOT="${CMAKE_CURRENT_SOURCE_DIR}/.."
)

if(TARGET meoui_module)
    add_dependencies(omnistore-native meoui_module)
    target_compile_definitions(omnistore-native PRIVATE
        OMNISTORE_MEOUI_BUILD_IMPORT_PATH="${CMAKE_BINARY_DIR}/meoui"
    )
endif()

set_target_properties(omnistore-native PROPERTIES
    WIN32_EXECUTABLE FALSE
    MACOSX_BUNDLE FALSE
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
)

install(TARGETS omnistore-native RUNTIME DESTINATION bin)
