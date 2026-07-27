# Propuesta: agregar "Chile" a los presets de región de MeshCore (upstream)

> **Estado:** publicado el 2026-07-26 → https://github.com/meshcore-dev/MeshCore/issues/3041

Borrador de issue para pedirle al proyecto oficial **MeshCore** que agregue **Chile**
como región seleccionable, con la configuración LoRa que usa MeshChile.

**Dónde publicarlo:** `meshcore-dev/MeshCore` → Issues → New issue
(https://github.com/meshcore-dev/MeshCore/issues/new). Alternativa: el repo de la
herramienta que muestra las regiones, `meshcore-dev/config.meshcore.io`. Conviene además
mencionarlo en el Discord de MeshCore con el link al issue.

**Contexto técnico:** la lista de regiones que ven las herramientas oficiales
(`config.meshcore.io`, flasher, `map.meshcore.io`) NO está versionada en un repo: se
sirve desde la API `https://api.meshcore.nz/api/v1/config`
(`config.suggested_radio_settings.entries`). Hoy hay 20 entradas y en Latinoamérica solo
está Brasil. Nuestro preset (927.875 / BW62.5 / SF8 / CR5) calza exacto con su esquema.

---

## Título del issue

    Add "Chile" to suggested radio settings (region presets)

## Cuerpo del issue

(El bloque de abajo, entre las líneas `~~~`, es el cuerpo listo para copiar/pegar.)

~~~markdown
### Request
Please add **Chile** to the suggested radio settings / region presets served at
`https://api.meshcore.nz/api/v1/config` (`config.suggested_radio_settings.entries`),
which power the region dropdown in config.meshcore.io, the web flasher and map.meshcore.io.

Latin America currently only has **Brazil**; there is no Chile entry, even though there's
an active MeshCore network here (MeshChile) that has standardized on a single radio config.

### Proposed entry (matches the existing schema)
```json
{
  "title": "Chile",
  "description": "MeshChile · 915–928 MHz ISM band",
  "frequency": 927.875,
  "spreading_factor": 8,
  "bandwidth": 62.5,
  "coding_rate": 5
}
```

Equivalent to `set radio 927.875,62.5,8,5`.

### Why these values
This is the de-facto standard already in use across the Chilean mesh (confirmed on live
repeaters/room servers reporting `radio: "927.875,62.5,8,5"`). It's a narrow config
(BW 62.5 / SF 8), consistent with the other "Narrow" presets, and sits in Chile's
915–928 MHz ISM allocation.

### Context
- Community: **MeshChile** — https://meshchile.cl
- National broker: `mqtt-msc.meshchile.cl` · live map: `mapa-msc.meshchile.cl`

Note: since the preset list appears to be served from `api.meshcore.nz` rather than from
a file in this repo, this may need a config/API update rather than a code change — happy
to open the PR wherever the data actually lives if you can point me to it. Thanks!
~~~
