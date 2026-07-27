#!/usr/bin/env bash
# MeshChile · compila firmware MeshCore con el preset de Chile horneado
# (LoRa 927.875/62.5/SF8/CR5) + packet-logging, para repeater/room-server.
# Reproducible: usa Docker + PlatformIO, clona meshcore-dev/MeshCore en el tag
# v1.16.0 (commit 07a3ca9, la version que corre la red chilena, con route-hash
# de 2 bytes). Los .bin/.uf2 quedan en ./prebuilt/.
#
# Uso:
#   ./build-chile-firmware.sh                # compila el set por defecto (4 equipos x 2 roles)
#   ./build-chile-firmware.sh Heltec_v3_repeater Xiao_S3_WIO_room_server   # targets a medida
#
# Requiere Docker. Ver la lista completa de targets con:
#   docker run --rm python:3.12-bookworm bash -c 'pip -q install platformio; \
#     git clone --depth 1 -b repeater-v1.16.0 https://github.com/meshcore-dev/MeshCore m; \
#     cd m; pio project config | grep env: | sed s/env://'
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/prebuilt"
WORK="${WORK:-$HERE/.build}"
TAG="repeater-v1.16.0"            # commit 07a3ca9
FW_VERSION="v1.16.0-meshchile"

# Packet logging via build flag. La frecuencia de Chile se aplica editando el valor
# base en platformio.ini (BW=62.5 y SF=8 ya son los defaults base). No usar -U/-D
# duplicados: PlatformIO reordena -U/-D y deja el macro sin definir (rompe el build).
CHILE_FLAGS="-DMESH_PACKET_LOGGING=1"

DEFAULT_TARGETS="Heltec_v3_repeater Heltec_v3_room_server \
Xiao_S3_WIO_repeater Xiao_S3_WIO_room_server \
RAK_4631_repeater RAK_4631_room_server \
Tbeam_SX1262_repeater Tbeam_SX1262_room_server"

TARGETS="${*:-$DEFAULT_TARGETS}"

mkdir -p "$WORK" "$OUT"

docker run --rm \
  -e TAG="$TAG" -e FW_VERSION="$FW_VERSION" -e CHILE_FLAGS="$CHILE_FLAGS" -e TARGETS="$TARGETS" \
  -v "$WORK":/work -v "$OUT":/out -w /work python:3.12-bookworm bash -c '
set -euo pipefail
export PLATFORMIO_CORE_DIR=/work/.pio-core
apt-get update -qq >/dev/null 2>&1 && apt-get install -y -qq git >/dev/null 2>&1
pip install -q platformio >/dev/null 2>&1
[ -d MeshCore ] || git clone --depth 1 --branch "$TAG" https://github.com/meshcore-dev/MeshCore MeshCore
cd MeshCore && mkdir -p out
# Frecuencia de Chile: edita el valor base (idempotente).
sed -i "s/-D LORA_FREQ=869\.618/-D LORA_FREQ=927.875/" platformio.ini
export FIRMWARE_VERSION="$FW_VERSION"
export PLATFORMIO_BUILD_FLAGS="$CHILE_FLAGS"
for t in $TARGETS; do
  echo ">>> $t"
  bash ./build.sh build-firmware "$t"
done
cp -v out/* /out/ 2>/dev/null || true
'
echo
echo "Firmwares en: $OUT"
ls -la "$OUT"
