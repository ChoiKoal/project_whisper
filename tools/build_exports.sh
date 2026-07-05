#!/usr/bin/env bash
# Build Project Whisper desktop exports and package release zips.
#
# Produces (in export/):
#   ProjectWhisper-win64-v<VER>.zip     — Windows x86_64 (ProjectWhisper.exe + run README)
#   ProjectWhisper-macos-v<VER>.zip     — macOS universal, POST-PROCESSED so the bundle has
#                                         NO space: ProjectWhisper.app / MacOS/ProjectWhisper /
#                                         Resources/ProjectWhisper.pck (see postprocess_macos_zip.py).
#
# The macOS post-process is a MANDATORY build step: the raw Godot export ships
# "Project Whisper.app" whose space breaks `xattr -dr com.apple.quarantine` one-liners
# and tab-completion. Every future build runs it here so the rename never regresses.
#
# Usage:  tools/build_exports.sh
# Requires: the Godot headless binary + installed 4.5.stable export templates.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME="$REPO/game"
EXPORT="$REPO/export"
GODOT="${GODOT_BIN:-$REPO/../tools/Godot_v4.5-stable_linux.arm64}"
POSTPROC="$REPO/../tools/postprocess_macos_zip.py"

VER="$(grep -oE 'config/version="[^"]+"' "$GAME/project.godot" | cut -d'"' -f2)"
echo "Building Project Whisper v$VER"

mkdir -p "$EXPORT/windows" "$EXPORT/macos"

# --- Windows -----------------------------------------------------------------
echo "== Windows =="
"$GODOT" --headless --path "$GAME" --export-release "Windows Desktop"
python3 - "$EXPORT" "$VER" <<'PY'
import os, sys, zipfile
export, ver = sys.argv[1], sys.argv[2]
out = os.path.join(export, f"ProjectWhisper-win64-v{ver}.zip")
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    z.write(os.path.join(export, "windows", "ProjectWhisper.exe"), "ProjectWhisper.exe")
    readme = os.path.join(export, "README-실행방법.md")
    if os.path.isfile(readme):
        z.write(readme, "README-실행방법.md")
print("wrote", out)
PY

# --- macOS (export + MANDATORY rename post-process) --------------------------
echo "== macOS =="
"$GODOT" --headless --path "$GAME" --export-release "macOS"
python3 "$POSTPROC" "$EXPORT/macos/ProjectWhisper.zip" \
        "$EXPORT/ProjectWhisper-macos-v$VER.zip"

echo "Done:"
ls -la "$EXPORT"/ProjectWhisper-win64-v"$VER".zip "$EXPORT"/ProjectWhisper-macos-v"$VER".zip
