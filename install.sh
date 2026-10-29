#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  RPM Builder — установка в систему (требуются права root или sudo)
#
#  Использование:
#      sudo ./install.sh              # установка в /usr/local
#      sudo PREFIX=/usr ./install.sh  # другой префикс
# ---------------------------------------------------------------------------
set -euo pipefail

PREFIX="${PREFIX:-/usr/local}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY="${PROJECT_DIR}/build/rpm-builder"

if [[ ! -x "${BINARY}" ]]; then
    echo "ОШИБКА: сначала соберите проект — ${BINARY} не найден." >&2
    echo "        Выполните: ./build.sh" >&2
    exit 1
fi

if [[ "$(id -u)" -ne 0 ]]; then
    echo "ОШИБКА: запустите через sudo:  sudo ./install.sh" >&2
    exit 1
fi

echo "==> Копирование бинарника:   ${PREFIX}/bin/rpm-builder"
install -Dm755 "${BINARY}" "${PREFIX}/bin/rpm-builder"

echo "==> Иконка:                  ${PREFIX}/share/icons/hicolor/scalable/apps/rpm-builder.svg"
install -Dm644 "${PROJECT_DIR}/assets/rpm-builder.svg" \
    "${PREFIX}/share/icons/hicolor/scalable/apps/rpm-builder.svg"

echo "==> Ярлык меню приложений:   ${PREFIX}/share/applications/rpm-builder.desktop"
sed "s|Exec=rpm-builder|Exec=${PREFIX}/bin/rpm-builder|" \
    "${PROJECT_DIR}/assets/rpm-builder.desktop" \
    > "${PREFIX}/share/applications/rpm-builder.desktop"
chmod 644 "${PREFIX}/share/applications/rpm-builder.desktop"

# Обновление кэшей рабочего стола (не критично при ошибке)
update-desktop-database "${PREFIX}/share/applications" 2>/dev/null || true
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -qtf "${PREFIX}/share/icons/hicolor" 2>/dev/null || true
fi

echo ""
echo "Установка завершена. Запуск:  rpm-builder"
echo "Удаление:                     sudo ./uninstall.sh"
