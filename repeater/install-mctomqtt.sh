#!/usr/bin/env bash
# MeshChile · Observer MSC (Repeater / Room Server) — instalador de la capa MQTT.
# Instala Cisien/meshcoretomqtt y deja el preset del broker nacional MeshChile,
# pidiendo tu IATA y puerto serial. El nodo (repeater/room-server) debe tener
# firmware con packet-logging (ver firmware/README o build-chile-firmware.sh).
#
# Uso:  sudo ./install-mctomqtt.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CONF_D="/etc/mctomqtt/config.d"

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$*"; }

[ "$(id -u)" -eq 0 ] || { warn "Corre con sudo (necesita /etc y systemd)."; exit 1; }

say "Instalando meshcoretomqtt (Cisien)"
# El instalador upstream crea /opt/mctomqtt, /etc/mctomqtt y el servicio systemd.
# Respondé 'n' al preguntar por LetsMesh (usamos el broker nacional); podés
# habilitar LetsMesh igual si quieres doble publicacion (ver README).
curl -fsSL https://raw.githubusercontent.com/Cisien/meshcoretomqtt/main/install.sh | bash

say "Instalando preset del broker nacional MeshChile"
mkdir -p "$CONF_D"
install -m 644 "$HERE/config.d/10-meshchile.toml" "$CONF_D/10-meshchile.toml"
echo "Escrito: $CONF_D/10-meshchile.toml"

say "Tu zona y puerto"
read -rp "Codigo IATA de tu zona (ej: SCL). Ver tabla en README: " IATA
read -rp "Puerto serial del nodo [/dev/ttyACM0]: " PORT
PORT="${PORT:-/dev/ttyACM0}"

say "Escribiendo overrides locales (99-user.toml)"
cat > "$CONF_D/99-user.toml" <<EOF
# Overrides locales de este observer (se conserva entre updates).
[general]
iata = "${IATA}"
log_level = "INFO"

[serial]
ports = ["${PORT}"]
EOF
chmod 644 "$CONF_D/99-user.toml"
echo "Escrito: $CONF_D/99-user.toml"

say "Reiniciando el servicio"
systemctl restart mctomqtt 2>/dev/null || systemctl restart meshcoretomqtt 2>/dev/null || \
  warn "No pude reiniciar el servicio automaticamente; revisa 'systemctl status mctomqtt'."

say "Listo"
echo "Logs:  journalctl -u mctomqtt -f"
echo "Mapa:  https://mapa-msc.meshchile.cl  (apareces cuando se oiga un advert tuyo)"
echo
echo "Recorda: el nodo necesita firmware con packet-logging y el preset LoRa de Chile."
echo "Ver ./firmware/  (build-chile-firmware.sh o config-radio-chile.txt)."
