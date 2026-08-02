# OrniFlight Configurator

![OrniFlight](of_logo.png)

> *The bridge between mind and wing — a complete flapping-wing flight suite for scientific laboratories, ornithopter builders, makers, and pilots shaping the future of avian aviation.*

---

## What Is OrniFlight?

OrniFlight Configurator is the desktop application for configuring, tuning, and updating **ornithopter flight controllers** running OrniFlight firmware. Born from the Betaflight Configurator lineage, it provides a complete ground-station interface: setup wizard, PID tuning, servo configuration, VTX control, OSD layout editor, CLI terminal, and firmware flashing — all through a unified graphical interface.

| Audience | Use Case |
|----------|----------|
| Scientific laboratories | Research-grade parameter control, waveform analysis |
| Ornithopter builders | Servo mixing, multi-wing geometry, custom profiles |
| Makers & hobbyists | Plug in, tune, and fly |
| Pilots | In-field parameter adjustment, VTX setup, OSD configuration |
| Future racers | FPV flapter racing profiles, rapid pit tuning |

---

## Installation

### Standalone (Recommended)

Download the latest installer for your platform from [Releases](https://github.com/dantiel/orniflight-configurator/releases).

**macOS**: If you see a security warning on Mojave/Catalina or later, run:
```
sudo spctl --master-disable
```
Install OrniFlight Configurator, verify it works, then:
```
sudo spctl --master-enable
```

---

## Architecture

```
┌──────────────────────────────────────────┐
│            NW.js Shell (Chromium)         │
│  ┌────────────────────────────────────┐  │
│  │        jQuery + Web Workers        │  │
│  │  ┌──────────┐  ┌────────────────┐  │  │
│  │  │   GUI     │  │  MSP Backend   │  │  │
│  │  │ Tab Mgmt  │  │  Serial + MSP  │  │  │
│  │  └──────────┘  └───────┬────────┘  │  │
│  │         │              │ Serial/   │  │
│  │    ┌────┴────┐    ┌───┴────────┐  │  │
│  │    │  HAML    │    │  USB/UART   │  │  │
│  │    │  Sass    │    │  (FC link)  │  │  │
│  │    │CoffeeScript  └────────────┘  │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
```

| Layer | Technology | Source | Build Output |
|-------|-----------|--------|-------------|
| Structure | **HAML** (33 files) | `src/tabs/*.haml` | `dist/tabs/*.html` |
| Style | **Sass** (54 files) | `src/css/**/*.sass` | `dist/css/**/*.css` |
| Logic | **CoffeeScript** (65 files) | `src/js/**/*.coffee` | `dist/js/**/*.js` |
| Build | **Gulp** | `gulpfile.js` | `dist/` |
| Runtime | **NW.js** v0.100.0 ARM64 | — | Standalone app |

### Build Pipeline

```
src/**/*.haml    →  ruby haml_compile.rb  →  dist/**/*.html
src/**/*.sass    →  sass --compressed     →  dist/**/*.css
src/**/*.coffee  →  Babel ES6→ES5        →  dist/**/*.js
                    js2coffee
```

Run: `npx gulp dist` — produces a complete `dist/` directory ready for NW.js.

---

## Development Setup

### Prerequisites
- Node.js 10+
- Yarn: `npm install yarn -g`

### Setup
```bash
yarn install
yarn start
```

### Tests
```bash
yarn test
```

### Building
```bash
yarn gulp dist          # Gather JS/CSS → ./dist
yarn gulp apps          # Build standalone apps → ./apps
yarn gulp release       # Package archives → ./release
```

Platform-specific builds:
```bash
yarn gulp <task> --osx64
yarn gulp <task> --linux64
yarn gulp <task> --win32
yarn gulp <task> --chromeos
```

> Building Windows apps on macOS/Linux requires Wine (for icon embedding).

---

## Performance Notes

- **WebGL**: Ensure Chrome's "Use hardware acceleration when available" is enabled under Settings → System.
- **Linux**: Add your user to the `dialout` group: `sudo usermod -aG dialout $USER`
- **3D rendering issues**: Enable `chrome://flags/#ignore-gpu-blacklist` → "Override software rendering list"

---

## Tab Reference

The configurator presents 27 functional tabs. Six are always available; the remaining 21 require a connected flight controller.

### Always Available (no FC required)

| Tab | Description |
|-----|-------------|
| **Landing** | Welcome page with logo, project introduction, community links, and sponsors. |
| **Setup** | 3D ornithopter model + waveform plotter. Runs in **demo mode** without FC — simulated gyro data animates wing pairs, waveform plotter shows synthetic servo curves. Switches to **live mode** when FC delivers real servo data via MSP. |
| **Changelog** | Release history from the project changelog. |
| **Firmware Flasher** | Flash firmware via local `.hex` file or online firmware browser. Uses native `<input type="file">` for file selection. Supports DFU and serial bootloader protocols. |
| **Privacy Policy** | Data usage disclosure. |
| **Help** | Documentation links, firmware information, community channels, and support resources. |

### Requires Connected Flight Controller

| Tab | Description |
|-----|-------------|
| **PID Tuning** | Adjust P/I/D rates and ornithopter-specific stabilization parameters. Sub-tabs for PID, Rates, and Filter configuration. |
| **Receiver** | Channel mapping, endpoints, RSSI monitoring, and RC link quality. |
| **Modes** | Assign flight modes (Angle, Horizon, Acro, etc.) to AUX switch positions. |
| **Servos** | Per-servo configuration: limits, midpoint, rate, and ornithopter-specific parameters. |
| **Motors** | Motor test interface, protocol selection, and ESC configuration. |
| **Configuration** | System settings: mixer type, ESC/motor protocol, feature toggles, loop time. |
| **Failsafe** | Stage 1 and stage 2 failsafe behavior, channel fallback values. |
| **OSD** | Drag-and-drop on-screen display layout editor. Upload custom fonts, position telemetry elements on a video canvas. |
| **VTX** | Video transmitter table editor. Configure frequency bands, channels, power levels. Supports SmartAudio (TBS) and IRC Tramp protocols. Import/export VTX tables as JSON. |
| **LED Strip** | Programmable LED layout: wire color-coded strips, assign effects, position LEDs on a grid. |
| **GPS** | GPS configuration, rescue mode settings, live coordinate display. |
| **Sensors** | Real-time gyro, accelerometer, barometer, and magnetometer readout. |
| **Ports** | UART assignment: MSP, SerialRx, Telemetry, and peripheral mapping per port. |
| **Power** | Battery voltage calibration, current sensor scaling, ADC configuration. |
| **CLI** | Full command-line interface to firmware. Tab-completion, command history, save/restore via `diff`/`dump`. |
| **Logging** | Sensor data logging export to file. |
| **Onboard Logging** | Blackbox log download and erase from onboard flash. |
| **Transponder** | IR transponder code configuration for lap timing systems. |
| **Setup OSD** | Quick OSD setup: voltage display, callsign, and basic element configuration. |

---

## MSP Protocol Interface

Every message between configurator and flight controller follows MSP (MultiWii Serial Protocol):

```
$ M <dir> <len> <code> [payload...] <checksum>
```

| Byte | Value | Meaning |
|------|-------|---------|
| 0 | `$` (0x24) | Sync 1 |
| 1 | `M` (0x4D) | Sync 2 |
| 2 | `>` / `<` / `!` | Direction: FC→GUI / GUI→FC / unsupported |
| 3 | `len` | Payload length (255 = jumbo: 2 more len bytes) |
| 4 | `code` | MSP command code |
| 5..n | — | Payload (little-endian) |
| n+1 | `checksum` | XOR of len ⊕ code ⊕ payload bytes |

The configurator implements this protocol in `src/js/msp/`:

| File | Responsibility |
|------|---------------|
| `MSPCodes.coffee` | Command code constants |
| `MSPHelper.coffee` | Payload read/write handlers per command |
| `MSP.coffee` | Message assembly and parsing |
| `serial_backend.coffee` | Timed request/response loop, queue management |

For the complete history of MSP protocol changes between firmware and configurator versions, see **[INTERFACE_CHANGELOG.md](INTERFACE_CHANGELOG.md)**.

---

## 3D Model & Waveform Plotter

The **Setup tab** features a real-time 3D ornithopter model with dynamic wing pairs and a waveform plotter showing servo angles.

### Demo Mode (no FC connected)

When no flight controller is connected, the model animates with simulated data:
- Synthetic gyro signals (sinusoidal pitch/roll oscillation)
- Auto-generated waveform patterns
- Wing pair count defaults to 2 (adjustable based on detected servo configuration)
- Waveform plotter displays `SIM` indicator

### Live Mode (FC connected)

When `MSP_SERVO` delivers real servo PWM values:
- PWM values are converted to wing angles
- 3D wing pivots follow actual servo output in real time (30 fps)
- Waveform plotter shows live servo angles with `LIVE` indicator
- Falls back to simulation after 150ms data timeout

This dual-mode design allows visual debugging: gyro perturbation → servo response → visual confirmation on the 3D model.

---

## VTX — Video Transmitter

The VTX tab configures video transmitter settings via **SmartAudio** (TBS) or **IRC Tramp** protocols.

### Features

- **VTX Table**: Define band, channel, frequency, and power level mappings
- **Power Levels**: Configure multiple power levels per band
- **Channel Selection**: Direct frequency or band/channel selection
- **Pit Mode**: Low-power output for race pits
- **Import/Export**: VTX table JSON import/export for sharing configurations

### Future: FPV Flapter Racing

OrniFlight's VTX infrastructure is ready for the emerging **FPV flapter racing** scene — where pilots fly ornithopters through gates with live video feeds. The configurator's OSD editor, VTX control, and PID tuning tabs form the complete ground station for competitive flapping flight.

---

## Development

### Source Tree

```
orniflight-configurator/
├── src/
│   ├── tabs/*.haml          # 33 HAML templates (→ dist HTML)
│   ├── css/**/*.sass        # 54 Sass stylesheets (→ dist CSS)
│   ├── js/**/*.coffee       # 65 CoffeeScript sources (→ dist JS)
│   ├── js/tabs/             # Tab controllers
│   ├── js/msp/              # MSP protocol layer
│   ├── js/protocols/        # Serial/USB protocol drivers
│   └── images/              # Assets (logos, icons)
├── locales/                 # 16 language JSON files
├── tools/                   # Build helpers
│   ├── haml_compile.rb      # HAML → HTML
│   ├── scss2sass.js         # SCSS → Sass converter
│   ├── babel_coffee.js      # ES6→ES5 preprocessor for CoffeeScript
│   └── html2haml.js         # HTML → HAML converter
├── gulpfile.js              # Gulp build pipeline
└── dist/                    # Compiled output (NW.js runtime)
```

### Adding a New Tab

1. **Create** the HAML template in `src/tabs/` with appropriate `tab-*` class
2. **Create** the CoffeeScript controller in `src/js/tabs/` following the tab lifecycle pattern (`initialize`, `refresh`, `cleanup`)
3. **Create** the Sass stylesheet in `src/css/tabs/` (and `src/css/tabs-dark/` for dark theme)
4. **Register** the tab in `src/js/tabs/` by adding the tab loading code
5. **Gate** on FC connection if needed: use `CONFIG.connected` or `semver.gte(CONFIG.apiVersion, ...)` for firmware-version-dependent features

### Adding a New MSP Command

1. **Define** the command code in `src/js/msp/MSPCodes.coffee`
2. **Add read handler** in `src/js/msp/MSPHelper.coffee` (find the data processing `case` block)
3. **Add write handler** if the command is bidirectional
4. **Use** in tab controller via `MSP.send_message(MSPCodes.MSP_YOUR_CMD, ...)`
5. **Gate** on API version with `semver.gte(CONFIG.apiVersion, "X.YZ.0")`
6. **Document** the change in `INTERFACE_CHANGELOG.md`

### NW.js File I/O Pattern

Since Chromium 130+, `chrome.fileSystem` is deprecated. Use native `<input type="file">`:

**Read file:**
```javascript
var input = $('<input type="file" accept=".hex,.config" style="display:none">');
$('body').append(input);
input.on('change', function(e) {
    var file = e.target.files[0];
    if (!file) { input.remove(); return; }
    var reader = new FileReader();
    reader.onloadend = function() {
        if (!reader.error) { /* process reader.result */ }
        input.remove();
    };
    reader.readAsText(file);
});
input.trigger('click');
```

**Save file (NW.js `nwsaveas`):**
```javascript
var input = $('<input type="file" nwsaveas="firmware.hex" accept=".hex" style="display:none">');
$('body').append(input);
input.on('change', function(e) {
    var savePath = e.target.value;
    if (!savePath) { input.remove(); return; }
    var reader = new FileReader();
    reader.onloadend = function() {
        if (!reader.error && reader.result) {
            require('fs').writeFile(savePath, Buffer.from(new Uint8Array(reader.result)), function(err) {
                if (err) { /* handle */ }
            });
        }
        input.remove();
    };
    reader.readAsArrayBuffer(new Blob([content]));
});
input.trigger('click');
```

---

## Migration from Betaflight Configurator

OrniFlight Configurator was forked from **Betaflight Configurator 10.6.0**. Key divergences:

| Area | Betaflight | OrniFlight |
|------|-----------|------------|
| **Firmware target** | Quadcopters (BF) | Ornithopters (OF) |
| **Mixer type** | 1–26 (quad, hex, etc.) | Ornithopter mixer mode |
| **Wing configuration** | N/A | 1–4 wing pairs, phase shifts, mount angles |
| **3D Model** | Quadcopter wireframe | Dynamic ornithopter with wing animation |
| **Stabilization UI** | Standard PID sliders | Extended PID with ornithopter-specific parameters |
| **Demo mode** | N/A | Full simulation without FC connected |
| **Languages** | HAML + Sass + CoffeeScript | ✅ Same stack (cleaned of BF references) |
| **Hardware** | All STM32 targets | F3/F4/F7 (F3 backward compatibility maintained) |

---

## Support

| Resource | Link |
|----------|------|
| **Discussions** | [github.com/dantiel/orniflight/discussions](https://github.com/dantiel/orniflight/discussions) |
| **Wiki** | [github.com/dantiel/orniflight/wiki](https://github.com/dantiel/orniflight/wiki) |
| **Firmware Issues** | [github.com/dantiel/orniflight/issues](https://github.com/dantiel/orniflight/issues) |
| **Configurator Issues** | [github.com/dantiel/orniflight-configurator/issues](https://github.com/dantiel/orniflight-configurator/issues) |

## Contributing

We welcome clean, focused patches. OrniFlight spans firmware (C, embedded) and configurator (HAML, Sass, CoffeeScript) — both repos are open to contributions.

## Credits

- **Betaflight team** — original Betaflight Configurator 10.6.0, the foundation this project was forked from
- **ctn** — primary author of Baseflight Configurator
- **Hydra** — author of Cleanflight Configurator
- **dantiel & OrniFlight contributors** — transforming the platform for flapping-wing flight

---

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).

---

*The future of cutting-edge flapping flight is OrniFlight.*
