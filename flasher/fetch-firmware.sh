#!/usr/bin/env bash
# Descarga los firmwares del GitHub Release a flasher/firmware/, para hostear el
# flasher. Los binarios NO se versionan en el repo (van por Releases); la página y
# firmwares.json sí. Verifica contra los SHA256SUMS.txt versionados.
#
# Uso:  ./fetch-firmware.sh            (usa el tag por defecto)
#       TAG=firmware-v1.16.0 ./fetch-firmware.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="${REPO:-Mesh-Chile/meshchile-msc-observer}"
TAG="${TAG:-firmware-v1.16.0}"
DEST="$HERE/firmware"
mkdir -p "$DEST"

echo "==> Descargando firmwares del release $TAG ($REPO) a firmware/"
# El flasher usa los merged (.bin ESP32) y los .uf2 (RAK).
gh release download "$TAG" -R "$REPO" -D "$DEST" -p '*-merged.bin' -p '*.uf2' --clobber

echo "==> Verificando checksums"
if [ -f "$DEST/SHA256SUMS.txt" ]; then
  ( cd "$DEST" && grep -E -- '-merged\.bin|\.uf2' SHA256SUMS.txt | sha256sum -c - ) || echo "! Revisa los checksums."
fi
echo "Listo. Archivos en $DEST"
ls -1 "$DEST" | grep -E 'merged\.bin|\.uf2' || true
