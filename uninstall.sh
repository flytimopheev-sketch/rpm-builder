#!/usr/bin/env bash
# RPM Builder — удаление из системы
set -euo pipefail

PREFIX="${PREFIX:-/usr/local}"

rm -fv "${PREFIX}/bin/rpm-builder" \
       "${PREFIX}/share/icons/hicolor/scalable/apps/rpm-builder.svg" \
       "${PREFIX}/share/applications/rpm-builder.desktop"

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -qtf "${PREFIX}/share/icons/hicolor" 2>/dev/null || true
fi

echo "RPM Builder удалён."
