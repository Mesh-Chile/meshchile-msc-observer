#!/usr/bin/env bash
# MeshChile · compila firmware MeshCore con el preset de Chile horneado
# (LoRa 927.875/62.5/SF8/CR5) + packet-logging, para repeater/room-server.
# Reproducible: usa Docker + PlatformIO.
#
# Dos modos (los dos modelos de deployment del observer Chile):
#   MODO A (default) — upstream meshcore-dev/MeshCore en el tag repeater-vX.Y.Z.
#                      El nodo va por USB a un Raspberry Pi con meshcoretomqtt.
#                      Salida en ./prebuilt/
#   MODO B (--observer) — fork agessaman/MeshCore rama observer-firmware, envs
#                      *_observer_mqtt: el nodo publica solo por su WiFi.
#                      Salida en ./prebuilt-observer/
#
# Uso:
#   ./build-chile-firmware.sh                       # modo A, set por defecto (5 equipos x 2 roles)
#   ./build-chile-firmware.sh --observer            # modo B, set por defecto (4 equipos x 2 roles)
#   ./build-chile-firmware.sh Heltec_v3_repeater    # targets a medida
#   REF=repeater-v1.16.0 FW_VERSION=v1.16.0-meshchile ./build-chile-firmware.sh   # otra version
#
# Variables: REF (tag/rama/commit), FW_VERSION (va en el nombre del archivo),
#            REPO_URL, OUT, WORK, TARGETS.
#
# Requiere Docker. Ver la lista completa de targets con:
#   docker run --rm python:3.12-bookworm bash -c 'pip -q install platformio; \
#     git clone --depth 1 -b repeater-v1.17.1 https://github.com/meshcore-dev/MeshCore m; \
#     cd m; pio project config | grep env: | sed s/env://'
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

MODE="${MODE:-A}"
if [ "${1:-}" = "--observer" ] || [ "${1:-}" = "-B" ]; then MODE=B; shift; fi

if [ "$MODE" = "B" ]; then
  # Modelo B — uplink WiFi nativo (fork observer). Solo ESP32 (el RAK4631 no lleva WiFi).
  REPO_URL="${REPO_URL:-https://github.com/agessaman/MeshCore}"
  REF="${REF:-observer-firmware}"
  FW_VERSION="${FW_VERSION:-v1.17.1-meshchile}"
  OUT="${OUT:-$HERE/prebuilt-observer}"
  WORK="${WORK:-$HERE/.build-observer}"
  DEFAULT_TARGETS="Heltec_v3_repeater_observer_mqtt Heltec_v3_room_server_observer_mqtt \
heltec_v4_repeater_observer_mqtt heltec_v4_room_server_observer_mqtt \
Xiao_S3_WIO_repeater_observer_mqtt Xiao_S3_WIO_room_server_observer_mqtt \
Tbeam_SX1262_repeater_observer_mqtt Tbeam_SX1262_room_server_observer_mqtt"
else
  # Modelo A — nodo + Raspberry Pi (meshcoretomqtt). Incluye el RAK4631 (.uf2).
  REPO_URL="${REPO_URL:-https://github.com/meshcore-dev/MeshCore}"
  REF="${REF:-repeater-v1.17.1}"          # commit d929643
  FW_VERSION="${FW_VERSION:-v1.17.1-meshchile}"
  OUT="${OUT:-$HERE/prebuilt}"
  WORK="${WORK:-$HERE/.build}"
  DEFAULT_TARGETS="Heltec_v3_repeater Heltec_v3_room_server \
heltec_v4_repeater heltec_v4_room_server \
Xiao_S3_WIO_repeater Xiao_S3_WIO_room_server \
RAK_4631_repeater RAK_4631_room_server \
Tbeam_SX1262_repeater Tbeam_SX1262_room_server"
fi

# Packet logging via build flag. La frecuencia de Chile se aplica editando el valor
# base en platformio.ini (BW=62.5 y SF=8 ya son los defaults base). No usar -U/-D
# duplicados: PlatformIO reordena -U/-D y deja el macro sin definir (rompe el build).
CHILE_FLAGS="${CHILE_FLAGS:--DMESH_PACKET_LOGGING=1}"

TARGETS="${*:-$DEFAULT_TARGETS}"

mkdir -p "$WORK" "$OUT"

echo "==> Modelo $MODE · $REPO_URL @ $REF · $FW_VERSION"
echo "==> Targets: $TARGETS"

docker run --rm \
  -e REPO_URL="$REPO_URL" -e REF="$REF" -e FW_VERSION="$FW_VERSION" \
  -e CHILE_FLAGS="$CHILE_FLAGS" -e TARGETS="$TARGETS" \
  -v "$WORK":/work -v "$OUT":/out -w /work python:3.12-bookworm bash -c '
set -euo pipefail
export PLATFORMIO_CORE_DIR=/work/.pio-core
apt-get update -qq >/dev/null 2>&1 && apt-get install -y -qq git >/dev/null 2>&1
pip install -q platformio >/dev/null 2>&1
# Clon fresco por REF (el .build se cachea entre corridas; si el clon existente no
# sirve para este REF se rehace, mas barato que pelear con un shallow clone).
if [ -d MeshCore ]; then
  cd MeshCore
  if ! { git fetch -q --depth 50 origin "$REF" && git checkout -q -f FETCH_HEAD; }; then
    cd /work && rm -rf MeshCore
  fi
fi
[ -d /work/MeshCore ] || { cd /work && git clone -q --depth 50 --branch "$REF" "$REPO_URL" MeshCore; }
cd /work/MeshCore
mkdir -p out
# Frecuencia de Chile: edita el valor base (idempotente).
sed -i "s/-D LORA_FREQ=869\.618/-D LORA_FREQ=927.875/" platformio.ini
grep -q "LORA_FREQ=927.875" platformio.ini || { echo "!! no se aplico LORA_FREQ de Chile"; exit 1; }
export FIRMWARE_VERSION="$FW_VERSION"
export PLATFORMIO_BUILD_FLAGS="$CHILE_FLAGS"
for t in $TARGETS; do
  echo ">>> $t"
  bash ./build.sh build-firmware "$t"
  # OJO: build.sh hace rm -rf out en cada invocacion -> copiar despues de CADA target.
  cp -v out/* /out/ 2>/dev/null || true
done
'
echo
echo "Firmwares en: $OUT"
ls -la "$OUT"
