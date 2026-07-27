(() => {
  "use strict";
  const $ = (s) => document.querySelector(s);
  const el = (t, c, h) => { const e = document.createElement(t); if (c) e.className = c; if (h != null) e.innerHTML = h; return e; };
  const ROLES = { repeater: "Repeater", room_server: "Room Server" };

  const supported = "serial" in navigator;
  $("#supported").classList.toggle("hide", !supported);
  $("#unsupported").style.display = supported ? "none" : "block";

  let DATA, state = { model: null, device: null, role: "repeater" };
  let lastBlob = null;

  fetch("firmwares.json").then((r) => r.json()).then((d) => {
    DATA = d;
    $("#ver").textContent = d.version.split("-")[0];
    renderModels();
    // seleccion inicial: primer modelo disponible
    const first = d.models.find((m) => m.available) || d.models[0];
    selectModel(first.id);
  }).catch((e) => {
    $("#action").innerHTML = '<p class="sel">No pude cargar firmwares.json (' + e.message + ").</p>";
  });

  function renderModels() {
    const seg = $("#model-seg"); seg.innerHTML = "";
    DATA.models.forEach((m) => {
      const b = el("button", null, m.name + (m.available ? "" : " ·"));
      b.setAttribute("role", "tab");
      b.onclick = () => selectModel(m.id);
      b.dataset.model = m.id;
      seg.appendChild(b);
    });
  }

  function selectModel(id) {
    state.model = id;
    const m = model();
    document.querySelectorAll("#model-seg button").forEach((b) =>
      b.setAttribute("aria-selected", b.dataset.model === id));
    $("#model-desc").textContent = m.desc;
    // rol por defecto
    renderRoles();
    renderDevices();
  }

  function model() { return DATA.models.find((m) => m.id === state.model); }

  function renderDevices() {
    const g = $("#dev-grid"); g.innerHTML = "";
    const m = model();
    if (!m.available || !m.devices.length) {
      g.appendChild(el("p", "sel", m.desc.includes("compilación") ? "🛠️ En compilación — disponible pronto." : "Sin equipos disponibles."));
      state.device = null; renderAction(); return;
    }
    m.devices.forEach((dev, i) => {
      const c = el("button", "dev" + (dev.flashable ? "" : ""));
      c.setAttribute("aria-selected", "false");
      c.dataset.dev = dev.id;
      c.innerHTML = '<div class="nm">' + dev.name + '</div><div class="ch">' + dev.chip + "</div>" +
        '<span class="tag">' + (dev.flashable ? "USB / Web" : ".uf2") + "</span>";
      c.onclick = () => selectDevice(dev.id);
      g.appendChild(c);
    });
    // mantener seleccion si existe en este modelo, si no primer equipo
    const keep = m.devices.find((d) => d.id === state.device);
    selectDevice(keep ? keep.id : m.devices[0].id);
  }

  function selectDevice(id) {
    state.device = id;
    document.querySelectorAll("#dev-grid .dev").forEach((c) =>
      c.setAttribute("aria-selected", c.dataset.dev === id));
    renderAction();
  }

  function renderRoles() {
    const seg = $("#role-seg"); seg.innerHTML = "";
    Object.entries(ROLES).forEach(([k, label]) => {
      const b = el("button", null, label);
      b.setAttribute("role", "tab");
      b.setAttribute("aria-selected", state.role === k);
      b.dataset.role = k;
      b.onclick = () => { state.role = k; renderRoles(); renderAction(); };
      seg.appendChild(b);
    });
  }

  function device() { const m = model(); return m.devices.find((d) => d.id === state.device); }

  function renderAction() {
    const a = $("#action"); a.innerHTML = "";
    const m = model(), dev = device();
    if (!dev) { a.innerHTML = '<p class="sel">Elige un modelo con equipos disponibles.</p>'; $("#config-slot").innerHTML = ""; return; }
    const roleLabel = ROLES[state.role];
    const file = dev.roles[state.role].file;

    a.appendChild(el("p", "sel", "Vas a flashear <b>" + dev.name + "</b> · <b>" + roleLabel +
      "</b> · <b>" + m.name + "</b>"));

    if (dev.flashable) {
      if (!supported) {
        a.appendChild(dlBtn(file, "Descargar .bin (flashea con esptool)"));
        a.appendChild(el("p", "hint", "Web Serial no disponible. Flashea el <code>-merged.bin</code> a <code>0x0</code> con esptool."));
      } else {
        if (lastBlob) { URL.revokeObjectURL(lastBlob); lastBlob = null; }
        const abs = new URL(file, location.href).href;
        const manifest = {
          name: "MeshChile " + dev.name + " " + roleLabel,
          version: DATA.version,
          new_install_prompt_erase: true,
          builds: [{ chipFamily: dev.chipFamily, parts: [{ path: abs, offset: 0 }] }]
        };
        lastBlob = URL.createObjectURL(new Blob([JSON.stringify(manifest)], { type: "application/json" }));
        const ib = document.createElement("esp-web-install-button");
        ib.manifest = lastBlob;
        const btn = el("button", "btn btn-primary", "⚡ Conectar y flashear");
        btn.slot = "activate";
        ib.appendChild(btn);
        const unsup = el("span", null, "");
        unsup.slot = "unsupported"; ib.appendChild(unsup);
        a.appendChild(ib);
        a.appendChild(dlBtn(file, "o descargar .bin"));
        a.appendChild(el("p", "hint", "Conecta el equipo por USB, presiona <b>Conectar y flashear</b> y elige el puerto. El firmware trae el preset LoRa de Chile horneado."));
      }
    } else {
      // nRF52 (RAK): no Web Serial, se arrastra el .uf2
      a.appendChild(dlBtn(file, "⬇ Descargar .uf2"));
      a.appendChild(el("p", "hint", "El RAK4631 (nRF52) se flashea por <b>arrastre</b>: doble-reset para entrar al bootloader (aparece una unidad USB tipo <code>RAK4631</code>/<code>FTHR840BOOT</code>) y <b>copia el .uf2</b> ahí. Se reinicia solo."));
    }
    renderConfig(m, dev, roleLabel);
  }

  function dlBtn(file, label) {
    const b = el("a", "btn btn-ghost", label);
    b.href = file; b.setAttribute("download", "");
    b.style.marginLeft = "10px";
    return b;
  }

  function renderConfig(m, dev, roleLabel) {
    const slot = $("#config-slot"); slot.innerHTML = "";
    const d = el("details", "cfg");
    d.appendChild(el("summary", null, "Configuración después de flashear"));
    const body = el("div", "body");

    if (m.id === "A") {
      body.appendChild(el("p", null,
        "En el <b>host Linux</b> junto al nodo (Raspberry Pi/mini-PC), instala la capa MQTT que lee el nodo por USB y publica al broker nacional:"));
      body.appendChild(cli(
        "# clona el repo del observer MeshChile y corre:\n" +
        "sudo ./repeater/install-mctomqtt.sh\n" +
        "# te pregunta tu IATA (ej: SCL) y el puerto serial (/dev/ttyACM0)"));
      body.appendChild(el("p", "hint",
        "La auth es auto-soberana: meshcoretomqtt lee la llave del nodo por serial y firma el token. No necesitas cuenta."));
    } else {
      body.appendChild(el("p", null,
        "El nodo publica solo por su WiFi. Configúralo por <b>consola serial</b> (terminal serie o la app MeshCore) pegando:"));
      body.appendChild(cli(
        "set name <TU-NODO>\n" +
        "set wifi.ssid <TuWiFi>\n" +
        "set wifi.pwd <TuClave>\n" +
        "<span class=c># radio Chile (ya viene horneada; opcional):</span>\n" +
        "set radio 927.875,62.5,8,5\n" +
        "set mqtt.iata SCL\n" +
        "set mqtt1.preset custom\n" +
        "set mqtt1.server wss://mqtt-msc.meshchile.cl:443/mqtt\n" +
        "set mqtt1.audience mqtt-msc.meshchile.cl\n" +
        "set mqtt.rx on\n" +
        "set mqtt.packets on\n" +
        "set mqtt.status on\n" +
        "set timezone America/Santiago\n" +
        "reboot"));
      body.appendChild(el("p", "hint",
        "El <code>audience</code> activa la firma Ed25519 (usuario <code>v1_&lt;PUBKEY&gt;</code>), justo lo que espera el broker nacional. Publica a <code>meshcore/&lt;IATA&gt;/&lt;PUBKEY&gt;/{packets,status}</code>."));
    }
    d.appendChild(body); slot.appendChild(d);
  }

  function cli(text) {
    const wrap = el("div"); wrap.style.position = "relative";
    const pre = el("pre", "cli", text);
    const btn = el("button", "copy", "copiar");
    btn.onclick = () => {
      const plain = text.replace(/<[^>]+>/g, "");
      navigator.clipboard.writeText(plain).then(() => { btn.textContent = "✓ copiado"; setTimeout(() => btn.textContent = "copiar", 1500); });
    };
    pre.appendChild(btn); wrap.appendChild(pre);
    return wrap;
  }
})();
