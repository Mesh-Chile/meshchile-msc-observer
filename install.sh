#!/usr/bin/env bash
# MeshChile · Observer MSC — instalador.
# Deja un observer publicando al broker nacional desde tu nodo MeshCore.
# Uso:  ./install.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PC_DIR="${PC_DIR:-$HOME/meshcore-packet-capture}"
USER_NAME="$(whoami)"

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$*"; }

say "Dependencias del sistema"
sudo apt-get update -y
sudo apt-get install -y python3 python3-venv git

say "Programa de captura (meshcore-packet-capture)"
# Usa la versión actual de 'main'. Las viejas publican /status pero NO /packets,
# así que el observer sale "online" pero el mapa no recibe adverts.
if [ ! -d "$PC_DIR" ]; then
  git clone https://github.com/agessaman/meshcore-packet-capture "$PC_DIR"
else
  echo "Ya existe en $PC_DIR (actualizo a la última de main)"
  git -C "$PC_DIR" fetch --quiet origin main && \
    git -C "$PC_DIR" checkout --quiet main && \
    git -C "$PC_DIR" pull --quiet || \
    echo "  (no pude actualizar automáticamente; revisa 'git -C $PC_DIR status')"
fi

say "Entorno Python (venv + dependencias)"
cd "$PC_DIR"
python3 -m venv .venv
# shellcheck disable=SC1091
. .venv/bin/activate
pip install -U pip >/dev/null
pip install -r requirements.txt

say "Puerto del nodo"
echo "Puertos serial detectados (usa la ruta by-id, es estable):"
ls -l /dev/serial/by-id/ 2>/dev/null || warn "No veo /dev/serial/by-id (¿está conectado el nodo?)"
read -rp "Ruta del puerto: " PORT
read -rp "Código IATA de tu zona (ej: SCL): " IATA

if ! id -nG | grep -qw dialout; then
  say "Agregando tu usuario al grupo dialout (acceso al serial)"
  sudo usermod -aG dialout "$USER_NAME"
  warn "Te agregué a 'dialout'. Tras este script, reinicia el equipo (el servicio de sistema ya lo maneja con SupplementaryGroups, pero conviene)."
fi

say "Escribiendo configuración (.env.local)"
sed -e "s#CAMBIA_TU_PUERTO#${PORT}#" -e "s#CAMBIA_IATA#${IATA}#" \
  "$HERE/.env.example" > "$PC_DIR/.env.local"
chmod 600 "$PC_DIR/.env.local"
echo "Escrito: $PC_DIR/.env.local"

say "Servicio de systemd"
sed -e "s#__USER__#${USER_NAME}#g" -e "s#__DIR__#${PC_DIR}#g" \
  "$HERE/meshcore-observer.service" | sudo tee /etc/systemd/system/meshcore-observer.service >/dev/null
sudo systemctl daemon-reload
sudo systemctl enable --now meshcore-observer

sleep 6
say "Estado"
systemctl is-active meshcore-observer && echo "El observer está corriendo."
echo
echo "Logs en vivo:   sudo journalctl -u meshcore-observer -f"
echo "Mapa:           https://mapa-msc.meshchile.cl"
echo "En minutos deberías aparecer (cuando se escuche un advert)."
