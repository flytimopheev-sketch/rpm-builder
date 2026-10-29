# Spec, который генерирует RPM Builder для шаблона hello-c.rpmb.json.
# Показан для наглядности — руками его писать не нужно.

Name:           hello-c
Version:        1.0
Release:        1%{?dist}
Summary:        Пример: компиляция C-кода при сборке RPM

License:        MIT
Source0:        main.c

BuildRequires:  gcc
BuildRequires:  make
Requires:       glibc

%description
Пример: программа на C компилируется gcc прямо во время сборки RPM (секция %build).
Исходник main.c кладётся в ~/hello-c/main.c, шаблон подхватывает его автоматически.
После установки команда доступна как hello-c (файл в /usr/bin).
Проверка:  hello-c
Удаление:  sudo dnf remove hello-c

# Сборка из исходников: команды заданы на странице «Скрипты и сборка»
# Источники добавленных файлов лежат в %{_sourcedir}
%prep

%build
# Исходники лежат в %{_sourcedir}, рабочий каталог пуст.
cd %{_sourcedir}
gcc -O2 %{_sourcedir}/main.c -o hello-c

%install
rm -rf %{buildroot}
install -Dm755 %{_sourcedir}/hello-c %{buildroot}%{_bindir}/hello-c

%clean
rm -rf %{buildroot}

%post
echo "Готово! Проверьте: выполните в терминале команду hello-c"

%files
%{_bindir}/hello-c

%changelog
* Sun Oct 05 2025 RPM Builder <builder@localhost> 1.0-1
- Пакет собран в визуальном конструкторе RPM Builder.
