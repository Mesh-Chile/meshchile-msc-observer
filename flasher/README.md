# Flasheador web MeshChile

Página estática que replica la función de `flasher.meshcore.io` pero sirviendo el
**firmware observer de MeshChile** (preset LoRa Chile 927.875/62.5/SF8 + packet-logging).
Flashea ESP32 directo desde el navegador con **Web Serial** (Chrome/Edge de escritorio),
vía [ESP Web Tools](https://esphome.github.io/esp-web-tools/) (vendoreado, sin CDNs).

## Flujo

0. **Versión** del firmware (selector arriba a la derecha): `v1.17.0` (última, por defecto)
   o `v1.16.0` (anterior, la que corre buena parte de la red). Deep-link: `?v=v1.16.0`.
1. Modelo: **A** (con Raspberry Pi / meshcoretomqtt) o **B** (WiFi nativo, sin Pi).
2. Equipo: Heltec V3, Heltec V4, Xiao S3 WIO, T-Beam SX1262 (ESP32, flasheables por web) o RAK4631 (solo Modelo A, `.uf2` por arrastre).
3. Rol: repeater / room server.
4. Flashear (Web Serial) o descargar el binario, + instrucciones de configuración post-flasheo.

## Estructura

```
flasher/
├── index.html · style.css · app.js       # la página
├── firmwares.json                        # metadata que arma la UI (versiones, equipos, roles, archivos)
├── gen-firmwares-json.py                 # regenera firmwares.json escaneando firmware/
├── firmware/                             # binarios (merged .bin ESP32 + .uf2 RAK) + SHA256SUMS
└── vendor/esp-web-tools/                 # ESP Web Tools vendoreado (self-contained, sin CDN)
```

Es **autónomo**: no hace requests a hosts externos (CSP-friendly). El JS de flasheo va
vendoreado en `vendor/`. Los **binarios NO se versionan** en git (se distribuyen por
**GitHub Releases**); bájalos a `firmware/` antes de hostear:

```bash
./fetch-firmware.sh            # gh release download -> firmware/  (+ verifica SHA256)
```

Los `firmware/SHA256SUMS.txt` sí están versionados (documentan el contenido del release).

## Hostear

Es estático — cualquier servidor de archivos sirve. Necesita **HTTPS** (Web Serial exige
secure context; `localhost` también vale para pruebas).

- **GitHub Pages** (como flasher.meshcore.io): publica esta carpeta.
- **Pangolin/Traefik** (nodo4): un contenedor nginx/caddy sirviendo `flasher/` en, p.ej.,
  `flasher-msc.meshchile.cl`.
- **Prueba local:** `cd flasher && python3 -m http.server 8899` → http://127.0.0.1:8899

## Agregar una versión nueva de firmware

Las versiones **conviven**: el selector las ofrece todas y nunca se borra la anterior.

```bash
# 1. compilar las dos variantes (Docker + PlatformIO)
cd ../repeater/firmware
REF=repeater-v1.18.0 FW_VERSION=v1.18.0-meshchile ./build-chile-firmware.sh
FW_VERSION=v1.18.0-meshchile ./build-chile-firmware.sh --observer   # fork observer

# 2. copiar los flasheables al flasher y regenerar checksums
cp prebuilt/*v1.18.0*-merged.bin prebuilt/*v1.18.0*.uf2 \
   prebuilt-observer/*v1.18.0*-merged.bin ../../flasher/firmware/
(cd ../../flasher/firmware && sha256sum $(ls *.bin *.uf2 | sort) > SHA256SUMS.txt)

# 3. agregar la versión a VERSIONS en gen-firmwares-json.py y regenerar
cd ../../flasher && ./gen-firmwares-json.py

# 4. publicar el release con los binarios y desplegar
gh release create firmware-v1.18.0 -R Mesh-Chile/meshchile-msc-observer \
  ../repeater/firmware/prebuilt/*v1.18.0* ../repeater/firmware/prebuilt-observer/*v1.18.0*
```

`gen-firmwares-json.py --check` falla si el JSON quedó desincronizado de `firmware/`.

## Notas

- **Solo Chrome/Edge de escritorio** soportan Web Serial. La página detecta y avisa si no.
- ESP32 se flashea el `-merged.bin` a `0x0` (wipe completo). El RAK4631 (nRF52) no usa
  Web Serial: se arrastra el `.uf2` al bootloader USB.
- Versiones publicadas:

  | Versión | Modelo A (upstream MeshCore) | Modelo B (fork observer) |
  |---|---|---|
  | **v1.17.0** (última) | tag `repeater-v1.17.0` · `727fc05` | rama `observer-firmware` · `bb066870` |
  | v1.16.0 | tag `repeater-v1.16.0` · `07a3ca9` | rama `observer-firmware` · `df07083` |
