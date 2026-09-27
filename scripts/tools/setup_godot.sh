#!/usr/bin/env bash
# Installs a headless-capable Godot binary on Linux (used by cloud sessions).
# Safe to run repeatedly: skips the download when the pinned version is present.
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.5.1-stable}"
INSTALL_DIR="${HOME}/.local/bin"
GODOT_BIN="${INSTALL_DIR}/godot"

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
	echo "export PATH=\"${INSTALL_DIR}:\$PATH\"" >> "${CLAUDE_ENV_FILE}"
fi

if [ -x "${GODOT_BIN}" ] && "${GODOT_BIN}" --version 2>/dev/null | grep -q "^${GODOT_VERSION%-stable}\."; then
	exit 0
fi

archive_name="Godot_v${GODOT_VERSION}_linux.x86_64"
url="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${archive_name}.zip"
work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

echo "Downloading Godot ${GODOT_VERSION}..."
curl -fsSL "${url}" -o "${work_dir}/godot.zip"

if command -v unzip >/dev/null 2>&1; then
	unzip -q "${work_dir}/godot.zip" -d "${work_dir}"
else
	python3 -m zipfile -e "${work_dir}/godot.zip" "${work_dir}"
fi

mkdir -p "${INSTALL_DIR}"
mv "${work_dir}/${archive_name}" "${GODOT_BIN}"
chmod +x "${GODOT_BIN}"
"${GODOT_BIN}" --version
