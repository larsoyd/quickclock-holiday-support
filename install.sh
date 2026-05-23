#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="${ROOT}/package"
METADATA="${SRC}/metadata.json"
PATCH_FILE="${ROOT}/quickclock-holiday-support.patch"

GLOBAL=0
RESTART=0
PATCH_RESTART=0

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install quickclock to ~/.local/share/plasma/plasmoids/ (default).

Options:
  -g, --global    Install system-wide (requires write access to /usr/share/plasma/plasmoids)
  -r, --restart   Restart plasmashell after install (patched installs restart automatically)
  -h, --help      Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -g|--global) GLOBAL=1 ;;
        -r|--restart) RESTART=1 ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

if [[ ! -f "${METADATA}" ]]; then
    echo "error: missing ${METADATA}" >&2
    exit 1
fi

ID="$(
    grep -m1 '"Id"' "${METADATA}" \
        | sed -n 's/.*"Id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
)"
if [[ -z "${ID}" ]]; then
    echo "error: could not read plasmoid Id from metadata.json" >&2
    exit 1
fi

INSTALL_SRC="${SRC}"
STAGING_DIR=""
if [[ -f "${PATCH_FILE}" ]]; then
    STAGING_DIR="$(mktemp -d)"
    trap '[[ -n "${STAGING_DIR}" ]] && rm -rf "${STAGING_DIR}"' EXIT
    echo "Preparing patched package…"
    cp -a "${SRC}" "${STAGING_DIR}/package"
    INSTALL_SRC="${STAGING_DIR}/package"

    if patch --batch --forward --dry-run -d "${INSTALL_SRC}" -p2 < "${PATCH_FILE}" >/dev/null 2>&1; then
        echo "Applying $(basename "${PATCH_FILE}")…"
        patch --batch --forward -d "${INSTALL_SRC}" -p2 < "${PATCH_FILE}" >/dev/null
        PATCH_RESTART=1
    elif patch --batch --reverse --dry-run -d "${INSTALL_SRC}" -p2 < "${PATCH_FILE}" >/dev/null 2>&1; then
        echo "$(basename "${PATCH_FILE}") already present in package; installing patched package"
        PATCH_RESTART=1
    else
        echo "error: $(basename "${PATCH_FILE}") does not apply to ${SRC}" >&2
        exit 1
    fi
fi

if [[ "${GLOBAL}" -eq 1 ]]; then
    DEST="/usr/share/plasma/plasmoids/${ID}"
    if [[ ! -w "$(dirname "${DEST}")" ]]; then
        echo "Installing system-wide (sudo required)…"
        sudo mkdir -p "$(dirname "${DEST}")"
        sudo rm -rf "${DEST}"
        sudo cp -a "${INSTALL_SRC}" "${DEST}"
    else
        rm -rf "${DEST}"
        mkdir -p "$(dirname "${DEST}")"
        cp -a "${INSTALL_SRC}" "${DEST}"
    fi
else
    DEST="${HOME}/.local/share/plasma/plasmoids/${ID}"
    rm -rf "${DEST}"
    mkdir -p "$(dirname "${DEST}")"
    cp -a "${INSTALL_SRC}" "${DEST}"
fi

if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 --noincremental 2>/dev/null || true
fi

echo "Installed ${ID} to ${DEST}"

if [[ "${PATCH_RESTART}" -eq 1 && "${RESTART}" -eq 0 ]]; then
    echo "Patched calendar support requires a Plasma shell restart."
fi

if [[ "${RESTART}" -eq 1 || "${PATCH_RESTART}" -eq 1 ]]; then
    echo "Restarting plasmashell…"
    if [[ "${QUICKCLOCK_SKIP_RESTART:-0}" -eq 1 ]]; then
        echo "Skipping plasmashell restart because QUICKCLOCK_SKIP_RESTART=1"
    else
        if command -v systemctl >/dev/null 2>&1 \
            && systemctl --user restart plasma-plasmashell.service; then
            :
        else
            killall plasmashell 2>/dev/null || true
            if command -v kstart >/dev/null 2>&1; then
                kstart plasmashell >/dev/null 2>&1 || true
            fi
        fi
    fi
fi

cat <<EOF

Add or refresh the widget:
  Panel → Add Widgets → ${ID}
  (or search for "quickclock")

If the widget does not appear, log out and back in, or run:
  $(basename "$0") --restart
EOF
