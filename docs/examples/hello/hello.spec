# Эталонный SPEC для примера hello — ровно то, что RPM Builder генерирует
# из шаблона hello.rpmb.json. Пригодится, если захотите собирать вручную:
#   cp hello.sh ~/rpmbuild/SOURCES/
#   rpmbuild -ba hello.spec

Name:           hello
Version:        1.0
Release:        1%{?dist}
Summary:        Моя первая программа — пример упаковки в RPM

License:        MIT
Source0:        hello.sh
BuildArch:      noarch

Requires:       bash

%description
Пример: программа-скрипт hello.sh, упакованная в RPM при помощи RPM Builder.
После установки команда доступна всем пользователям как hello.sh (файл в /usr/bin).
Проверка установки:  rpm -qi hello
Удаление:            sudo dnf remove hello

# Простая упаковка готовых файлов без пересборки исходников
%prep

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}%{_bindir}
cp -r %{_sourcedir}/hello.sh %{buildroot}%{_bindir}/hello.sh

%clean
rm -rf %{buildroot}

%post
echo "Готово! Проверьте: выполните в терминале команду hello.sh"

%files
%{_bindir}/hello.sh

%changelog
* Mon Sep 01 2025 RPM Builder <builder@localhost> hello-1.0-1
- Пакет собран в визуальном конструкторе RPM Builder.
