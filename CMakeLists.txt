cmake_minimum_required(VERSION 3.21)

project(rpm-builder VERSION 1.4.1 LANGUAGES C CXX
        DESCRIPTION "RPM Builder — визуальный конструктор RPM-пакетов")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick QuickControls2 Test)
qt_standard_project_setup(REQUIRES 6.5)

# ---------------------------------------------------------------------------
# C++ исходники (движок регистрируется в QML через контекстное свойство Engine)
# ---------------------------------------------------------------------------
# Локальный обход для окружений без системного EGL/GL (песочница CI).
# На обычных машинах переменная не задана и файл не добавляется.
set(RPM_GL_STUB_SRC "")
if(DEFINED ENV{RPM_BUILDER_GL_STUB})
    set(RPM_GL_STUB_SRC "$ENV{RPM_BUILDER_GL_STUB}")
    message(STATUS "GL-заглушка включена в сборку: ${RPM_GL_STUB_SRC}")
endif()

qt_add_executable(rpm-builder
    ${RPM_GL_STUB_SRC}
    src/main.cpp
    src/rpmbuildengine.h   src/rpmbuildengine.cpp
                           src/rpmproject.cpp
                           src/rpmbuild.cpp
                           src/projectio.cpp
                           src/glibc_compat.c
    src/engine_p.h
)

# ---------------------------------------------------------------------------
# QML-модуль: физически файлы лежат в подкаталогах, но все они публикуются
# в КОРНЕЙ модуля через QT_RESOURCE_ALIAS — получается единый неймспейс и
# неявный импорт «одного каталога», никаких лишних import-ов.
# ---------------------------------------------------------------------------
set(RPM_QML_ROOT
    qml/Main.qml
    qml/Theme.qml
    qml/AppIcon.qml
)

set(RPM_RES_ASSETS
    assets/fonts/InterVariable.ttf
    assets/fonts/JetBrainsMono-Regular.ttf
    assets/fonts/JetBrainsMono-SemiBold.ttf
    assets/rpm-builder.svg
)
set(RPM_QML_REST
    qml/components/TitleBar.qml
    qml/components/AboutDialog.qml
    qml/components/SideBar.qml
    qml/components/NavButton.qml
    qml/components/SectionCard.qml
    qml/components/StatCard.qml
    qml/components/GradientButton.qml
    qml/components/FlatButton.qml
    qml/components/AppTextField.qml
    qml/components/FilePicker.qml
    qml/components/AppTextArea.qml
    qml/components/AppComboBox.qml
    qml/components/ChipInput.qml
    qml/components/DropFilesArea.qml
    qml/components/FileRow.qml
    qml/components/Toast.qml
    qml/pages/DashboardPage.qml
    qml/pages/MetaPage.qml
    qml/pages/FilesPage.qml
    qml/pages/DepsPage.qml
    qml/pages/ScriptsPage.qml
    qml/pages/SpecPage.qml
    qml/pages/BuildPage.qml
)

set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

foreach(_f IN LISTS RPM_QML_ROOT RPM_QML_REST)
    get_filename_component(_alias "${_f}" NAME)
    if(NOT _f STREQUAL "qml/Main.qml")
        set_source_files_properties(${_f} PROPERTIES QT_RESOURCE_ALIAS ${_alias})
    endif()
endforeach()

foreach(_f IN LISTS RPM_RES_ASSETS)
    get_filename_component(_alias "${_f}" NAME)
    set_source_files_properties(${_f} PROPERTIES QT_RESOURCE_ALIAS assets/${_alias})
endforeach()

qt_add_qml_module(rpm-builder
    URI RpmBuilder
    VERSION 1.0
    QML_FILES
        ${RPM_QML_ROOT}
        ${RPM_QML_REST}
    RESOURCES
        ${RPM_RES_ASSETS}
)

set_target_properties(rpm-builder PROPERTIES
    MACOSX_BUNDLE FALSE
    WIN32_EXECUTABLE FALSE
)

target_link_libraries(rpm-builder PRIVATE Qt6::Quick Qt6::QuickControls2 Qt6::Test)

# Статическая линковка libstdc++/libgcc: бинарник запускается на более
# старых дистрибутивах (РЕД ОС и др.) без зависимости от свежих GLIBCXX.
if(UNIX AND NOT APPLE)
    target_link_options(rpm-builder PRIVATE -static-libstdc++ -static-libgcc)
endif()

include(GNUInstallDirs)
install(TARGETS rpm-builder RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES assets/rpm-builder.desktop
        DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
install(FILES assets/rpm-builder.svg
        DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps)
