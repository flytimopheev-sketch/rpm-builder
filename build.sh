#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  RPM Builder — скрипт сборки проекта одной командой
#
#  Использование:
#      ./build.sh                # конфигурация + компиляция
#      ./build.sh --clean        # полная пересборка с нуля
#      QT_DIR=/path/to/Qt/6.9.3/linux_gcc_64 ./build.sh   # свой Qt
# ---------------------------------------------------------------------------
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"

if [[ "${1:-}" == "--clean" ]]; then
    echo "==> Очистка каталога сборки: ${BUILD_DIR}"
    rm -rf "${BUILD_DIR}"
fi

# ------------------------------ CMake --------------------------------------
CMAKE_BIN="$(command -v cmake || true)"
if [[ -z "${CMAKE_BIN}" ]] && [[ -x "${HOME}/.venv/bin/cmake" ]]; then
    CMAKE_BIN="${HOME}/.venv/bin/cmake"
fi
if [[ -z "${CMAKE_BIN}" ]]; then
    echo "ОШИБКА: cmake не найден. Установите его:" >&2
    echo "  Debian/Ubuntu : sudo apt install cmake" >&2
    echo "  Fedora        : sudo dnf install cmake" >&2
    exit 1
fi

GENERATOR="Unix Makefiles"
NINJA_BIN="$(command -v ninja || true)"
if [[ -n "${NINJA_BIN}" ]] || [[ -x "${HOME}/.venv/bin/ninja" ]]; then
    GENERATOR="Ninja"
    export PATH="${PATH}:${HOME}/.venv/bin"
fi

# ------------------------------- Qt6 ---------------------------------------
QT_DIR_DEFAULT_CANDIDATES=(
    "$(echo ${QT_DIR:-})"                       # явно заданный через окружение
    "${HOME}/Qt/"*/linux_gcc_64                 # aqtinstall (linux)
    "${HOME}/Qt/"*/gcc_64                       # старый aqtlayout
    "/usr/lib/qt6"                              # системный qt6 (Arch, SUSE)
)
QT_DETECTED=""
for candidate in "${QT_DIR_DEFAULT_CANDIDATES[@]}"; do
    if [[ -d "${candidate}" && -e "${candidate}/lib/cmake/Qt6" ]]; then
        QT_DETECTED="${candidate}"
        break
    fi
done

if [[ -n "${QT_DETECTED:-}" ]]; then
    echo "==> Qt6 найден: ${QT_DETECTED}"
    QT_ARGS=(-DCMAKE_PREFIX_PATH="${QT_DETECTED}")
else
    echo "==> Явный путь к Qt не задан — используется системный Qt6."
    QT_ARGS=()
fi

# ---------------------------- Конфигурация ---------------------------------
# Дополнительные флаги CMake можно передать переменной CMAKE_EXTRA_ARGS,
# например: CMAKE_EXTRA_ARGS="-DOPENGL_ROOT=/opt/glx" ./build.sh
EXTRA_ARGS=()
if [[ -n "${CMAKE_EXTRA_ARGS:-}" ]]; then
    read -r -a EXTRA_ARGS <<< "${CMAKE_EXTRA_ARGS}"
fi

echo "==> Конфигурация (${GENERATOR})"
"${CMAKE_BIN}" -B "${BUILD_DIR}" -G "${GENERATOR}" \
    -DCMAKE_BUILD_TYPE=Release \
    "${QT_ARGS[@]}" \
    "${EXTRA_ARGS[@]}" \
    "${PROJECT_DIR}"

# ----------------------------- Сборка --------------------------------------
echo "==> Компиляция"
"${CMAKE_BIN}" --build "${BUILD_DIR}" -j"$(nproc)"

BINARY="${BUILD_DIR}/rpm-builder"
if [[ -x "${BINARY}" ]]; then
    echo ""
    echo "Готово! Бинарник: ${BINARY}"
    echo "Запуск          : ${BINARY}"
fi
