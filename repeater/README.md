# MeshChile · Observer MSC — Repeater / Room Server

Suma tu **repeater** o **room server** MeshCore como *observer* de la red chilena:
el nodo publica por MQTT los paquetes que oye por RF al **broker nacional**
(`mqtt-msc.meshchile.cl`) y aparece en el mapa en vivo: **https://mapa-msc.meshchile.cl**

```
malla RF ──► tu repeater/room-server (firmware con packet-logging)
                    │ USB serial (log de paquetes)
                    ▼
             Linux (Raspberry Pi, mini-PC): meshcoretomqtt
                    │ firma un token con la llave del nodo (aud=mqtt-msc.meshchile.cl)
                    ▼
        wss://mqtt-msc.meshchile.cl:443 (broker nacional) ──► mapa
```

> **¿Companion (USB/BLE) en vez de repeater/room-server?** Usa la guía principal del
> repo (raíz): `meshcore-packet-capture`. Esta carpeta es para **Repeater / Room Server**,
> que usan firmware con packet-logging + `meshcoretomqtt`.

## Qué necesitas

1. Un **repeater o room server** MeshCore con **firmware que tenga packet-logging**.
   Los binarios de Chile ya compilados (preset LoRa 927.875/62.5/SF8 + logging) están en
   [`firmware/prebuilt/`](firmware/) — un flash y listo. Si tu equipo no está, compílalo
   con `firmware/build-chile-firmware.sh`.
2. Un **host Linux** siempre encendido junto al nodo (Raspberry Pi, mini-PC…), conectado
   por **USB** al nodo, con salida a internet.

## Pasos

### 1. Firmware (una vez)

Flashea el firmware de Chile de tu equipo (ver [`firmware/README.md`](firmware/README.md)).
Ya trae la radio de Chile y el packet-logging horneados. Define nombre y clave:

```
set name <tu-nodo>
password <tu-clave>
```

### 2. Capa MQTT (en el host Linux)

```bash
sudo ./install-mctomqtt.sh
```

El script instala [`Cisien/meshcoretomqtt`](https://github.com/Cisien/meshcoretomqtt),
deja el **preset del broker nacional** (`config.d/10-meshchile.toml`) y te pregunta tu
**IATA** y tu **puerto serial**. La autenticación es **auto-soberana**: `meshcoretomqtt`
lee la llave del nodo por serial y firma un token JWT — no hay que crear cuenta ni
password.

### 3. Verificar

```bash
journalctl -u mctomqtt -f
```

Busca la conexión al broker y publicaciones a `meshcore/<IATA>/<PUBKEY>/packets`.
En minutos deberías aparecer en https://mapa-msc.meshchile.cl (cuando se oiga un advert).

## Datos del broker (ya en el preset)

| Parámetro | Valor |
|---|---|
| Host | `mqtt-msc.meshchile.cl` |
| Puerto | `443` (WebSockets, TLS) |
| Auth | token MeshCore (Ed25519, firmado on-device) |
| Audiencia (`aud`) | `mqtt-msc.meshchile.cl` |
| Topics | `meshcore/<IATA>/<PUBKEY>/{packets,status}` |

## Código IATA por zona

| Zona | IATA | | Zona | IATA |
|---|---|---|---|---|
| Santiago / RM | `SCL` | | Temuco / Araucanía | `ZCO` |
| Valparaíso (usa Santiago) | `SCL` | | Puerto Montt / Los Lagos | `PMC` |
| La Serena / Coquimbo | `LSC` | | Punta Arenas / Magallanes | `PUQ` |
| Concepción / Biobío | `CCP` | | Coyhaique / Aysén | `GXQ` |
| Antofagasta | `ANF` | | Valdivia / Los Ríos | `ZAL` |
| Iquique | `IQQ` | | Chillán / Ñuble | `YAI` |
| Arica | `ARI` | | Rapa Nui | `IPC` |
| Calama | `CJC` | | | |

## Preset LoRa de Chile

Frecuencia **927.875 MHz** · BW **62.5 kHz** · SF **8** · CR **5** · route hash **2 bytes**.
Ya viene horneado en el firmware de `firmware/prebuilt/`. Para firmware genérico, aplica
`firmware/config-radio-chile.txt` por CLI.

## (Opcional) publicar también a LetsMesh

`meshcoretomqtt` soporta varios brokers a la vez. Para además enviar al analyzer oficial,
agrega el preset `presets/letsmesh.toml` de meshcoretomqtt (responde `y` a LetsMesh en el
instalador). Publicará con la misma llave del nodo a `mqtt-us-v1.letsmesh.net`.
