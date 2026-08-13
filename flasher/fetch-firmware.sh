#!/usr/bin/env bash
# Descarga los firmwares del GitHub Release a flasher/firmware/, para hostear el
# flasher. Los binarios NO se versionan en el repo (van por Releases); la página y
# firmwares.json sí. Verifica contra los SHA256SUMS.txt versionados.
#
# El flasher ofrece VARIAS versiones a la vez (ver firmwares.json), asi que baja
# todos los releases listados en TAGS.
#
# Uso:  ./fetch-firmware.sh                        (todas las versiones publicadas)
#       TAGS=firmware-v1.17.0 ./fetch-firmware.sh  (solo una)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="${REPO:-Mesh-Chile/meshchile-msc-observer}"
TAGS="${TAGS:-${TAG:-firmware-v1.16.0 firmware-v1.17.0}}"
DEST="$HERE/firmware"
mkdir -p "$DEST"

for tag in $TAGS; do
  echo "==> Descargando firmwares del release $tag ($REPO) a firmware/"
  # El flasher usa los merged (.bin ESP32) y los .uf2 (RAK).
  gh release download "$tag" -R "$REPO" -D "$DEST" -p '*-merged.bin' -p '*.uf2' --clobber
done

echo "==> Verificando checksums"
if [ -f "$DEST/SHA256SUMS.txt" ]; then
  ( cd "$DEST" && grep -E -- '-merged\.bin|\.uf2' SHA256SUMS.txt | sha256sum -c - ) || echo "! Revisa los checksums."
fi
echo "Listo. Archivos en $DEST"
ls -1 "$DEST" | grep -E 'merged\.bin|\.uf2' || true
