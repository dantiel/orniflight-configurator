# OrniFlight Configurator

![OrniFlight](of_logo.png)

> **The complete flapping-wing flight suite.** For scientific laboratories, ornithopter builders, makers, and pilots shaping the future of avian aviation.

---

OrniFlight Configurator is the official desktop configuration tool for the [OrniFlight](https://github.com/dantiel/orniflight) flight control system — the cutting-edge open-source platform for flapping-wing aircraft.

Whether you're in a university lab researching avian aerodynamics, building a high-performance racing ornithopter, or crafting a biologically-inspired multi-wing flapper, the Configurator gives you full-spectrum control: tune aerodynamic profiles, visualize servo waveforms in real time, configure multi-wing geometries, and push the boundaries of what flapping flight can achieve.

### What Makes OrniFlight Different

- **Purpose-built for flapping flight** — not a quadcopter firmware with wings bolted on. Aerodynamic parameters, glide coefficients, ferocity curves, and waveform tuning are first-class citizens.
- **Real-time 3D visualization** — see your ornithopter's wings move exactly as they will in flight, with live servo waveform plotting and dynamic wing-pair rendering (1–4 pairs).
- **Scientific-grade configurability** — per-slot ornithopter profiles, aeroelastic coefficients, downstroke/upstroke ferocity, cadence gain, amplitude, frequency, and more.
- **Multi-wing architecture** — twin flapters, quad flapters, experimental multi-wing platforms. The configurator adapts its 3D model and waveform display to your servo count.
- **F3 to H7** — backward-compatible with STM32F3 hardware. Cutting-edge features run on cutting-edge chips; proven stability runs on proven hardware.

### Target Audience

| Audience | Use Case |
|----------|----------|
| **Research Labs** | Avian flight dynamics, aeroelasticity studies, biomimetic drone research |
| **Ornithopter Builders** | Full configuration, tuning, and visualization for custom flapping-wing craft |
| **Makers & Hobbyists** | Bring your ornithopter to life with an intuitive, powerful configurator |
| **Pilots** | Tune flight characteristics, switch ornithopter profiles mid-air, optimize for speed or grace |
| **Future Racers** | OrniFlight is built for the day flapping-wing racing takes off — and that day is coming |

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

## Development

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

## Performance Notes

- **WebGL**: Ensure Chrome's "Use hardware acceleration when available" is enabled under Settings → System.
- **Linux**: Add your user to the `dialout` group: `sudo usermod -aG dialout $USER`
- **3D rendering issues**: Enable `chrome://flags/#ignore-gpu-blacklist` → "Override software rendering list"

## Support

| Resource | Link |
|----------|------|
| **Discussions** | [github.com/dantiel/orniflight/discussions](https://github.com/dantiel/orniflight/discussions) |
| **Wiki** | [github.com/dantiel/orniflight/wiki](https://github.com/dantiel/orniflight/wiki) |
| **Firmware Issues** | [github.com/dantiel/orniflight/issues](https://github.com/dantiel/orniflight/issues) |
| **Configurator Issues** | [github.com/dantiel/orniflight-configurator/issues](https://github.com/dantiel/orniflight-configurator/issues) |

## Technical Details

The Configurator uses the **MSP** (MultiWii Serial Protocol) over serial/USB to communicate with the flight controller. The UI is built with jQuery and NW.js, forked from Betaflight Configurator 10.6.0 and evolved into a standalone ornithopter-focused tool.

## Contributing

We welcome clean, focused patches. OrniFlight spans firmware (C, embedded) and configurator (JavaScript, HTML, CSS) — both repos are open to contributions.

## Credits

- **Betaflight team** — original Betaflight Configurator 10.6.0, the foundation this project was forked from
- **ctn** — primary author of Baseflight Configurator
- **Hydra** — author of Cleanflight Configurator
- **dantiel & OrniFlight contributors** — transforming the platform for flapping-wing flight

---

*The future of cutting-edge flapping flight is OrniFlight.*
