# SPEC-файл самодостаточной сборки RPM Builder в RPM-пакет.
#
# Использование (РЕД ОС / Fedora / RHEL):
#   1. положить архив исходников в ~/rpmbuild/SOURCES/:
#      tar -czf ~/rpmbuild/SOURCES/rpm-builder-1.4.1.tar.gz \
#          --exclude=build --exclude=.git rpm-builder-1.4.1
#   2. rpmbuild -ba rpm-builder.spec
#   3. sudo dnf install ~/rpmbuild/RPMS/x86_64/rpm-builder-1.4.1-1.*.rpm
#
# После установки приложение доступно в меню («Разработка») и командой
# rpm-builder. Кстати, сам RPM Builder умеет готовить такие spec-файлы
# автоматически — это его работа.

Name:           rpm-builder
Version:        1.4.1
Release:        1%{?dist}
Summary:        Визуальный конструктор RPM-пакетов (GUI)

License:        MIT
URL:            https://example.org/rpm-builder
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  cmake
BuildRequires:  ninja-build
BuildRequires:  gcc-c++
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel
Requires:       hicolor-icon-theme

%description
RPM Builder — визуальный конструктор RPM-пакетов для Linux: нативное
безрамочное приложение на C++/Qt6 (QML).

Заполните карточку пакета, перетащите файлы, нажмите «Собрать» — rpmbuild
запускается с автоматически сгенерированным SPEC-файлом, а готовый .rpm
появляется в выбранном каталоге.

Возможности: метаданные с живой валидацией, файлы через drag&drop с
автоопределением каталога установки, зависимости (Requires/BuildRequires/
Provides), скрипты %pre/%post/%preun/%postun, живое превью SPEC, журнал
сборки в реальном времени, история проектов, статистика, JSON-шаблоны
проектов (*.rpmb.json), тёмная и светлая темы.

%prep
%autosetup

%build
%set_build_flags
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=%{_prefix}
cmake --build build %{?_smp_mflags}

%install
DESTDIR=%{buildroot} cmake --install build

%check
# оффлайн-самопроверка без дисплея (наличие rpmbuild в chroot не требуется,
# валидатор лишь предупредит); при желании можно включить:
# QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software ./build/rpm-builder --selftest

%files
%{_bindir}/rpm-builder
%{_datadir}/applications/rpm-builder.desktop
%{_datadir}/icons/hicolor/scalable/apps/rpm-builder.svg
%doc README.md LICENSE

%changelog
* Wed Oct 15 2025 RPM Builder <builder@localhost> 1.4.1-1
- примеры (docs/examples) больше не требуют ручного копирования файлов
  в домашний каталог: при открытии *.rpmb.json файлы автоматически
  подхватываются из папки самого шаблона
- если rpmbuild не установлен — большая карточка с командой установки
  (dnf install rpm-build) и кнопкой «Проверить снова» на странице «Сборка»
- обработка неудачного запуска rpmbuild: больше нет «вечной» сборки с
  неработающей отменой — сразу понятное объяснение в журнале
- на странице «Сборка» виден полный список причин блокировки (валидация)
- тост с результатом открытия/сохранения шаблона проекта

* Wed Oct 15 2025 RPM Builder <builder@localhost> 1.4.0-1
- все диалоги выбора файлов/папок и «Сохранить как» заменены на
  встроенный пикер в окне приложения: кнопки «Добавить папку…»,
  «Добавить файлы…», «Сохранить как…», «Изменить…», «Открыть/Сохранить
  шаблон» теперь работают в любой среде (Wayland, xdg-порталы, редкие
  темы), где системные диалоги молча не открывались
- кнопка «Отменить» на странице «Сборка» завершает rpmbuild надёжно:
  SIGTERM с последующим SIGKILL через 2,5 с
- после отмены/ошибки появляется карточка разбора: конкретные строки
  ошибок из журнала и подсказка, что именно проверить
- отдельное уведомление «Сборка отменена» вместо ложной «ошибки сборки»
- скрытый --selftest дополнен проверкой LISTDIR (данные встроенного пикера)

* Tue Oct 14 2025 RPM Builder <builder@localhost> 1.3.1-1
- исправлена навигация: клик по разделам сайдбара больше не может
  уводить на «Обзор» (устранено затенение индекса кнопки;
  привязка currentPage больше не ломается при переходах)
- новая кнопка «Далее: файлы пакета» на странице «Метаданные» —
  переход к следующему шагу без сайдбара
- конфиг пишется атомарно (QSaveFile): сбой больше не портит черновик
- битый конфиг-файл больше не обнуляет проект при старте
- повторное открытие проекта из истории больше не дублирует файлы

* Sun Oct 05 2025 RPM Builder <builder@localhost> 1.3.0-1
- сборка из исходников: новые секции %build, %install и %files
  на странице «Скрипты и сборка» (Rust, Go, C/C++, make, cmake…)
- если %install/%files заданы пользователем, автогенерация отключается
- каталог установки в списке файлов не обязателен при своём %install
- новые секции сохраняются в JSON-шаблонах (*.rpmb.json)
- пример examples/hello-c: компиляция C-программы gcc прямо в RPM

* Sat Sep 06 2025 RPM Builder <builder@localhost> 1.2.0-1
- исправлено: значение полей «Имя пакета»/«Версия» и др. не сохранялось
  и сбрасывалось при любом изменении модели (сигнал edited не подавался)
- кнопки окна (свернуть/развернуть/закрыть) жёстко прижаты к правому
  верхнему углу; добавлена кнопка и окно «О программе»
- combobox «Архитектура»/«Лицензия»: привязка восстанавливается после
  ввода, значения обновляются при загрузке шаблона

* Mon Sep 01 2025 RPM Builder <builder@localhost> 1.1.0-1
- JSON-шаблоны проектов (*.rpmb.json): сохранение и загрузка
- статическая линковка libstdc++/libgcc: работа на более старых glibc
- правила установки desktop-файла и иконки в CMakeLists
