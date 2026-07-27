# Flasheador web MeshChile

Página estática que replica la función de `flasher.meshcore.io` pero sirviendo el
**firmware observer de MeshChile** (preset LoRa Chile 927.875/62.5/SF8 + packet-logging).
Flashea ESP32 directo desde el navegador con **Web Serial** (Chrome/Edge de escritorio),
vía [ESP Web Tools](https://esphome.github.io/esp-web-tools/) (vendoreado, sin CDNs).

## Flujo

1. Modelo: **A** (con Raspberry Pi / meshcoretomqtt) o **B** (WiFi nativo, sin Pi).
2. Equipo: Heltec V3, Xiao S3 WIO, T-Beam SX1262 (ESP32, flasheables por web) o RAK4631 (solo Modelo A, `.uf2` por arrastre).
3. Rol: repeater / room server.
4. Flashear (Web Serial) o descargar el binario, + instrucciones de configuración post-flasheo.

## Estructura

```
flasher/
├── index.html · style.css · app.js       # la página
├── firmwares.json                        # metadata que arma la UI (equipos, roles, archivos)
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

## Regenerar los binarios

Los `.bin`/`.uf2` se generan con los scripts del repo:
- Modelo A: `repeater/firmware/build-chile-firmware.sh`
- Modelo B (observer WiFi): fork `agessaman/MeshCore` branch `observer-firmware`, envs
  `*_observer_mqtt`, con la frecuencia Chile horneada (sed `LORA_FREQ=927.875`).

Tras compilar, copia los `-merged.bin` (ESP32) y `.uf2` (RAK) a `flasher/firmware/` y
actualiza `firmwares.json` (nombres de archivo y `chipFamily`). Regenera `SHA256SUMS.txt`
con `sha256sum * > SHA256SUMS.txt`.

## Notas

- **Solo Chrome/Edge de escritorio** soportan Web Serial. La página detecta y avisa si no.
- ESP32 se flashea el `-merged.bin` a `0x0` (wipe completo). El RAK4631 (nRF52) no usa
  Web Serial: se arrastra el `.uf2` al bootloader USB.
- Versiones: Modelo A = MeshCore `v1.16.0-07a3ca9`; Modelo B = fork observer `df07083`.
