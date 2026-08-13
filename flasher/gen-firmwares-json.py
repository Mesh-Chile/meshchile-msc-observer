#!/usr/bin/env python3
"""Regenera flasher/firmwares.json a partir de los binarios en flasher/firmware/.

La página se arma sola desde ese JSON: versiones, modelos (A = con Raspberry Pi,
B = WiFi nativo), equipos y roles. Este script evita mantenerlo a mano cuando se
agrega una versión nueva de firmware.

Convención de nombres (la que producen los build.sh):
  Modelo A:  <Target>-<vX.Y.Z>-meshchile-<sha>-merged.bin   (ESP32)
             <Target>-<vX.Y.Z>-meshchile-<sha>.uf2          (RAK4631/nRF52)
  Modelo B:  <Target>_observer_mqtt-<vX.Y.Z>-meshchile-<sha>-merged.bin

Uso:  ./gen-firmwares-json.py            # escribe firmwares.json
      ./gen-firmwares-json.py --check    # solo verifica que esté al día
"""
import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
FW = HERE / "firmware"
OUT = HERE / "firmwares.json"

# Equipos conocidos: prefijo de archivo -> metadata para la UI.
DEVICES = [
    ("Heltec_v3",    {"id": "heltec_v3", "name": "Heltec V3",           "chip": "ESP32-S3",  "chipFamily": "ESP32-S3", "flashable": True}),
    ("heltec_v4",    {"id": "heltec_v4", "name": "Heltec V4",           "chip": "ESP32-S3",  "chipFamily": "ESP32-S3", "flashable": True}),
    ("Xiao_S3_WIO",  {"id": "xiao_s3",   "name": "Seeed Xiao S3 WIO",   "chip": "ESP32-S3",  "chipFamily": "ESP32-S3", "flashable": True}),
    ("Tbeam_SX1262", {"id": "tbeam",     "name": "LilyGo T-Beam SX1262", "chip": "ESP32",     "chipFamily": "ESP32",    "flashable": True}),
    ("RAK_4631",     {"id": "rak4631",   "name": "RAK4631",             "chip": "nRF52840",                            "flashable": False}),
]

ROLES = ["repeater", "room_server"]

MODELS = {
    "A": {
        "name": "Con Raspberry Pi",
        "tag": "meshcoretomqtt",
        "desc": "El nodo se conecta por USB a un Raspberry Pi (o mini-PC Linux) que tiene internet y publica al broker con meshcoretomqtt. Sirve cualquier equipo, incluido el RAK4631. El nodo no necesita WiFi.",
        "suffix": "",
    },
    "B": {
        "name": "WiFi nativo (sin Pi)",
        "tag": "observer-mqtt",
        "desc": "El nodo publica él mismo a MQTT por su propio WiFi, sin Raspberry Pi. Solo ESP32 (Heltec V3, Heltec V4, Xiao S3, T-Beam). Tras flashear, se configura WiFi + broker por consola serial.",
        "suffix": "_observer_mqtt",
    },
}

# Versión -> notas para la UI. La primera de la lista es la recomendada (latest).
VERSIONS = [
    {"id": "v1.17.0", "label": "v1.17.0", "latest": True,
     "note": "Última versión de MeshCore. Recomendada para nodos nuevos."},
    {"id": "v1.16.0", "label": "v1.16.0", "latest": False,
     "note": "Versión anterior, la que corre buena parte de la red chilena. Sigue disponible por si prefieres no actualizar."},
]

NAME_RE = re.compile(
    r"^(?P<target>.+?)-(?P<ver>v\d+\.\d+\.\d+)-meshchile-(?P<sha>[0-9a-f]{7,10})(?P<merged>-merged)?\.(?P<ext>bin|uf2)$"
)


def index_files():
    """{(version, target): (filename, sha)} para los archivos flasheables."""
    found = {}
    for p in sorted(FW.iterdir()):
        m = NAME_RE.match(p.name)
        if not m:
            continue  # 1.16 del modelo B no lleva versión en el nombre: se resuelve aparte
        # Solo interesan los merged (ESP32) y los .uf2 (RAK).
        if m["ext"] == "bin" and not m["merged"]:
            continue
        found[(m["ver"], m["target"])] = (p.name, m["sha"])
    return found


# Archivos legacy sin versión en el nombre (modelo B v1.16): <target>-meshchile-<sha>-merged.bin
LEGACY_RE = re.compile(r"^(?P<target>.+?)-meshchile-(?P<sha>[0-9a-f]{7,10})-merged\.bin$")
LEGACY_VERSION = {"df07083": "v1.16.0"}


def index_legacy():
    found = {}
    for p in sorted(FW.iterdir()):
        m = LEGACY_RE.match(p.name)
        if not m:
            continue
        ver = LEGACY_VERSION.get(m["sha"])
        if ver:
            found[(ver, m["target"])] = (p.name, m["sha"])
    return found


def build():
    files = index_legacy()
    files.update(index_files())

    versions = []
    for v in VERSIONS:
        models = []
        for mid, meta in MODELS.items():
            devices, shas = [], set()
            for prefix, dev in DEVICES:
                if mid == "B" and not dev["flashable"]:
                    continue  # el RAK4631 no lleva WiFi: no existe en el modelo B
                roles, missing = {}, False
                for role in ROLES:
                    target = f"{prefix}_{role}{meta['suffix']}"
                    hit = files.get((v["id"], target))
                    if not hit:
                        missing = True
                        break
                    roles[role] = {"file": f"firmware/{hit[0]}"}
                    shas.add(hit[1])
                if missing:
                    print(f"  · falta {v['id']} modelo {mid}: {prefix} — equipo omitido", file=sys.stderr)
                    continue
                devices.append({**dev, "roles": roles})
            models.append({
                "id": mid,
                "name": meta["name"],
                "tag": meta["tag"],
                "available": bool(devices),
                "desc": meta["desc"],
                "commit": sorted(shas)[0] if len(shas) == 1 else None,
                "devices": devices,
            })
        versions.append({**v, "models": models})

    return {
        "default_version": next(v["id"] for v in VERSIONS if v["latest"]),
        "lora": {"freq": "927.875 MHz", "bw": "62.5 kHz", "sf": "8", "cr": "5"},
        "broker": "mqtt-msc.meshchile.cl",
        "versions": versions,
    }


if __name__ == "__main__":
    data = json.dumps(build(), indent=2, ensure_ascii=False) + "\n"
    if "--check" in sys.argv:
        cur = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
        if cur != data:
            print("firmwares.json está desactualizado (corre ./gen-firmwares-json.py)")
            sys.exit(1)
        print("firmwares.json al día")
    else:
        OUT.write_text(data, encoding="utf-8")
        print(f"escrito {OUT}")
