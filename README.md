# MeshChile · Observer MSC

Suma tu zona a la red **MeshCore de Chile**. Un *observer* es un host Linux pequeño
con un nodo MeshCore conectado que **escucha el tráfico de la malla por RF y lo
republica** al broker nacional. Así los nodos de tu región aparecen en el mapa en
vivo: **https://mapa-msc.meshchile.cl**

```
malla RF ──advert──► tu nodo MeshCore (USB/BLE) ──► host Linux: meshcore-packet-capture
                                                          │ firma un token con la llave del nodo
                                                          ▼
                                  wss://mqtt-msc.meshchile.cl:443 (broker nacional) ──► mapa
```

> **No necesitas que te demos una cuenta.** La autenticación es auto-soberana: tu
> nodo firma un token con su propia llave y el broker verifica la firma. Tu nodo
> *es* tu identidad.

El "programa" que captura y publica es
[`agessaman/meshcore-packet-capture`](https://github.com/agessaman/meshcore-packet-capture)
(Python). Este repo **no lo redistribuye**: aporta la **configuración lista para el
broker MeshChile**, un instalador, el servicio de systemd y los detalles no obvios
que ya dejamos resueltos.

---

## Lo que necesitas

1. **Un nodo MeshCore** operativo (Companion, Repeater o Room Server) que haga de
   antena/interfaz. Lo más común: un **Companion** (ej. Seeed Xiao ESP32-S3, Heltec,
   T-Beam, T1000-e) conectado por **USB** (también sirve BLE o TCP).
2. **Un host Linux** siempre encendido cerca del nodo: Raspberry Pi, mini-PC,
   LattePanda, un contenedor… cualquier cosa con Python 3.
3. Salida a internet (el observer hace conexión saliente; no abre puertos).

No necesitas IP fija ni abrir nada en tu router.

---

## Instalación rápida (con el script)

```bash
git clone https://github.com/Mesh-Chile/meshchile-msc-observer
cd meshchile-msc-observer
./install.sh
```

El script instala las dependencias, clona `meshcore-packet-capture`, crea el venv,
detecta tu puerto serial, te pregunta tu **IATA** (zona), escribe la configuración y
deja el servicio de systemd corriendo. Si prefieres hacerlo a mano, sigue la guía de
abajo.

---

## Instalación manual

### 1. Dependencias + programa

```bash
sudo apt update && sudo apt install -y python3 python3-venv git
git clone https://github.com/agessaman/meshcore-packet-capture
cd meshcore-packet-capture
python3 -m venv .venv && . .venv/bin/activate
pip install -U pip && pip install -r requirements.txt
```

> **Versión mínima:** `f9733b1` (rama `main`) o posterior. Versiones más antiguas
> se conectan y publican `/status` pero **no publican `/packets`**, así que tu
> observer aparece "online" pero el mapa nunca recibe los adverts que oyes por
> RF. Verifica con `git log -1 --oneline`. Si el commit es viejo,
> `git fetch && git checkout main && git pull`. El `install.sh` de este repo ya
> deja la versión correcta.

### 2. Conecta tu nodo y encuentra su puerto

Usa la **ruta estable** por `by-id` (no `ttyACM0`/`ttyUSB0` directo: cambian de
número al reconectar):

```bash
ls -l /dev/serial/by-id/
# Seeed Xiao ESP32-S3 → "...Espressif_USB_JTAG_serial_debug_unit_<MAC>-if00"
# Otros (CP2102/CH340) → "...CP2102..." / "...CH340..."
```

Tu usuario debe estar en el grupo `dialout`:

```bash
id -nG | grep -q dialout || { sudo usermod -aG dialout "$USER"; echo "Vuelve a iniciar sesión"; }
```

### 3. Configuración

Copia `.env.example` de este repo como `.env.local` **dentro de la carpeta de
meshcore-packet-capture** y edita tu puerto y tu IATA:

```bash
cp /ruta/a/meshchile-msc-observer/.env.example ./.env.local
chmod 600 .env.local
$EDITOR .env.local      # PACKETCAPTURE_SERIAL_PORTS y PACKETCAPTURE_IATA
```

Los valores del broker ya vienen puestos. **No tienes que poner ninguna llave**: si
tu firmware Companion permite exportar la llave por USB (la mayoría hoy lo hace),
packet-capture la usa en runtime y firma *on-device*, sin guardar nada en disco.

### 4. Probar

```bash
. .venv/bin/activate
timeout 45 python packet_capture.py
```

Busca en los logs:

- `Connected to: {... 'public_key': ..., 'name': ...}` → leyó tu nodo
- `JWT authentication: Will use on-device signing`
- `Connected to MQTT1 at mqtt-msc.meshchile.cl:443 (transport=websockets, tls=True)` → **auth aceptada**
- `📦 Captured packet #N ... type 4 ... (MQTT: 1/1)` → escuchó un advert y lo publicó

Abre https://mapa-msc.meshchile.cl — en minutos deberías aparecer.

### 5. Dejarlo permanente (systemd)

Copia `meshcore-observer.service` de este repo, ajusta las rutas/usuario y:

```bash
sudo cp meshcore-observer.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now meshcore-observer
systemctl is-active meshcore-observer            # active
sudo journalctl -u meshcore-observer -f
```

> ⚠️ **Gotcha conocido:** si usas un servicio **de usuario** (`systemctl --user`) y
> da `Permission denied` en el serial, es porque el *user-manager* (lingering) tiene
> un set de grupos viejo sin `dialout`. La solución limpia es el servicio **de
> sistema** con `SupplementaryGroups=dialout` (ya viene en el unit de este repo).

---

## Datos del broker (ya en `.env.example`)

| Parámetro | Valor |
|---|---|
| Host | `mqtt-msc.meshchile.cl` |
| Puerto | `443` |
| Transporte | WebSockets |
| TLS | sí |
| Audiencia del token (`aud`) | `mqtt-msc.meshchile.cl` |
| Topics | `meshcore/<IATA>/<TU_PUBKEY>/{packets,status}` |

## Código IATA por zona

Elige el del aeropuerto más cercano a tu zona:

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

---

## Si tu firmware NO permite exportar la llave

Algunos firmwares Companion antiguos no exportan la llave por USB. En ese caso
generas una **identidad de software** para el observer (par Ed25519) y la pones en
`PACKETCAPTURE_PRIVATE_KEY`:

- Genérala en https://gessaman.com/mc-keygen/ (te da privada 128-hex + pública 64-hex).
- El topic y el username saldrán de esa pública. El nodo igual aparece por sus
  adverts; el observer solo usa esta identidad para autenticar al MQTT.

---

## Privacidad

- Lo que publicas en `/packets` y `/status` es **público** (es el feed del mapa de la
  comunidad). No publiques nada sensible por esa vía.
- El observer solo **escucha** la malla; no transmite ni interfiere.

---

## Validar desde afuera (opcional)

Si tienes una cuenta read-only del broker, puedes suscribirte y ver tu feed:

```bash
npm i mqtt
BROKER_URL=wss://mqtt-msc.meshchile.cl SUB_USER=<usuario> SUB_PASS=<pass> node test-broker.js
```

---

## Troubleshooting

### Mi observer dice "MQTT: 1/1" pero no aparece en el mapa

Síntoma: los logs muestran `📦 Captured packet #N ... type 4 ... (MQTT: 1/1)`
pero ni tu observer ni los nodos que oyes salen en https://mapa-msc.meshchile.cl.

Causa típica: estás corriendo una versión vieja de `meshcore-packet-capture` que
**publica `/status` pero no `/packets`**. Se detecta porque el broker te ve
"online" indefinidamente pero el mapa solo recibe pings de presencia y nunca
adverts RF tuyos. El `(MQTT: 1/1)` del log es del lado cliente y no garantiza
que el broker recibió un PUBLISH a `/packets`.

Verifica la versión:

```bash
cd ~/meshcore-packet-capture
git log -1 --oneline
```

Si el commit es anterior a `f9733b1` (rama `main`), actualiza:

```bash
git fetch && git checkout main && git pull
. .venv/bin/activate && pip install -r requirements.txt
sudo systemctl restart meshcore-observer
```

En 1-2 minutos los adverts capturados deberían empezar a llegar al mapa.

### Cómo confirmar desde afuera si tu observer publica packets

Si tienes acceso al panel del broker o a un sub read-only, busca PUBLISH a:

```
meshcore/<TU_IATA>/<TU_PUBKEY>/packets
```

Si solo ves `/status` y nunca `/packets`, es el caso de arriba.

---

¿Dudas, quieres sumar tu región o una cuenta read-only? Escríbenos en la comunidad
**MeshChile**.
