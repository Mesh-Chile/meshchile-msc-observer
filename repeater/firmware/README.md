# Firmware MeshChile — Repeater / Room Server (con packet-logging)

Firmware **MeshCore v1.16.0** (commit `07a3ca9`, la versión que corre la red chilena)
compilado con el **preset LoRa de Chile horneado** y **packet-logging activado**, para
que el nodo publique a MQTT lo que oye. Un flash y listo: no hay que tocar la radio por
CLI.

## Preset horneado

| Parámetro | Valor |
|---|---|
| Frecuencia | **927.875 MHz** |
| Bandwidth | **62.5 kHz** |
| Spreading Factor | **SF 8** |
| Coding Rate | **CR 5** (default del firmware) |
| Route hash | 2 bytes (viene en v1.16) |
| Build flags | `-DMESH_PACKET_LOGGING=1 -DLORA_FREQ=927.875 -DLORA_BW=62.5 -DLORA_SF=8` |

## Binarios listos

> Los `.bin`/`.uf2` **no se versionan en git**: se distribuyen por **GitHub Releases**
> (tag `firmware-v1.16.0`). Descárgalos del release, o compílalos con
> `build-chile-firmware.sh`. Los `SHA256SUMS.txt` versionados documentan su contenido.

Compilados para 4 equipos × 2 roles (repeater / room server):

- **Heltec V3** (ESP32-S3) → `.bin` + `-merged.bin`
- **Seeed Xiao S3 WIO** (ESP32-S3 + Wio-SX1262) → `.bin` + `-merged.bin`
- **RAK4631** (nRF52840) → `.uf2`
- **LilyGo T-Beam SX1262** (ESP32) → `.bin` + `-merged.bin`

> ¿Falta tu equipo? Compílalo con `./build-chile-firmware.sh <target>` (ver abajo).

## Cómo flashear

Usa el **web flasher** de MeshCore (https://flasher.meshcore.co.uk / config.meshcore.io)
y elige **Custom**, o `esptool` / arrastrar-`.uf2`:

- **ESP32 (Heltec V3, Xiao S3, T-Beam):**
  - Web flasher "Custom": sube el `*-merged.bin` (imagen completa, se flashea a 0x0).
  - o por consola:
    ```bash
    esptool.py --chip auto --baud 921600 write_flash 0x0 <archivo>-merged.bin
    ```
  - (El `.bin` sin `-merged` es solo la app, para actualizar sobre un firmware ya instalado, va a 0x10000.)
- **nRF52 (RAK4631):** entra al bootloader (doble reset → aparece disco `RAK4631` / `FTHR840BOOT`)
  y **copia el `.uf2`** a esa unidad. Se reinicia solo.

Tras flashear, define nombre y clave admin por CLI/BLE:
```
set name <tu-nodo>
password <tu-clave>
```

## Compilar tú mismo

```bash
./build-chile-firmware.sh                      # set por defecto (8 firmwares)
./build-chile-firmware.sh Heltec_v3_repeater   # un target puntual
```
Requiere Docker (usa PlatformIO en un contenedor, clona MeshCore en `v1.16.0` y
hornea los flags de Chile). Salida en `prebuilt/`.

## Alternativa: firmware genérico + config por CLI

Si prefieres usar el firmware packet-logging **genérico** (p.ej. del flasher
`observer.gessaman.com`), déjalo en Chile aplicando `config-radio-chile.txt`
(`set radio 927.875,62.5,8,5` + `reboot`).
