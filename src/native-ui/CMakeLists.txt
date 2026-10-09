cmake_minimum_required(VERSION 3.21)
project(OmniStoreNative LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(QT_QML_GENERATE_QMLLS_INI ON)

# Release/package builds should pass the exact package version here. Development
# builds deliberately report "development" rather than a stale product version.
set(OMNISTORE_RELEASE_VERSION "development" CACHE STRING "OmniStore release version shown by the native client")

find_package(Qt6 6.6 REQUIRED COMPONENTS Core Gui LinguistTools Network Qml Quick QuickControls2)
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
    app/externalinstallrequest.cpp app/externalinstallrequest.h
    app/backendbridge.cpp
    app/backendbridge.h
    app/repositorybridge.cpp
    app/repositorybridge.h
    app/systembridge.cpp
    app/systembridge.h
    app/transactionclient.cpp
    app/transactionclient.h
)

qt_add_qml_module(omnistore-native
    URI OmniStore.Native
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/components/AppDetailsPane.qml
        qml/components/AppRow.qml
        qml/components/InstallPlanReview.qml
        qml/components/StoreAppCard.qml
        qml/components/RepositoryManager.qml
        qml/components/SystemStatusPanel.qml
        qml/components/UpdateRow.qml
        qml/components/PageHeading.qml
        qml/pages/HomePage.qml
        qml/pages/ExplorePage.qml
        qml/pages/SearchPage.qml
        qml/pages/UpdatesPage.qml
        qml/pages/InstalledPage.qml
        qml/pages/TasksPage.qml
        qml/pages/SettingsPage.qml
)

# Translation catalogs are compiled into the binary under :/i18n. Runtime
# selection is locale-driven in main.cpp; an unavailable locale falls back to
# the English source strings naturally.
qt_add_translations(omnistore-native
    TS_FILES
        i18n/omnistore_zh_CN.ts
    RESOURCE_PREFIX "/i18n"
)

target_link_libraries(omnistore-native PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Network
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
)

target_compile_definitions(omnistore-native PRIVATE
    OMNISTORE_SOURCE_ROOT="${CMAKE_CURRENT_SOURCE_DIR}/.."
    OMNISTORE_RELEASE_VERSION="${OMNISTORE_RELEASE_VERSION}"
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

include(CTest)
if(BUILD_TESTING)
    find_package(Qt6 REQUIRED COMPONENTS Test)
    qt_add_executable(backend-usage-test
        tests/backend_usage_test.cpp
        app/backendbridge.cpp app/backendbridge.h
    )
    target_include_directories(backend-usage-test PRIVATE app)
    target_link_libraries(backend-usage-test PRIVATE Qt6::Core Qt6::Test)
    qt_add_executable(external-install-request-test
        tests/external_install_request_test.cpp
        app/externalinstallrequest.cpp app/externalinstallrequest.h
    )
    target_include_directories(external-install-request-test PRIVATE app)
    target_link_libraries(external-install-request-test PRIVATE Qt6::Core Qt6::Test)
    add_test(NAME external-install-request COMMAND external-install-request-test)
    set_tests_properties(external-install-request PROPERTIES TIMEOUT 10)
    add_test(NAME backend-installed-usage COMMAND backend-usage-test)
    set_tests_properties(backend-installed-usage PROPERTIES TIMEOUT 45)
endif()
