# Configurator ↔ OrniFlight MSP Interface

> *The bridge between mind and wing — what the configurator expects, what the firmware must provide.*
> *Phase 1 & 2 complete — firmware and configurator now agree on all 71 bytes at apiVersion ≥ 1.43.*

## Cross-Reference

Firmware-side authoritative spec: **`../orniflight/docs/MSP_FIRMWARE_INTERFACE.md`**

| What | Firmware File | Key Lines |
|------|--------------|-----------|
| `MSP_PID_ADVANCED` send | `msp.c` | ~1506–1516 |
| `MSP_PID_ADVANCED` receive | `msp.c` | ~2231–2243 |
| `MSP_SERVO_CONFIGURATIONS` send | `msp.c` | ~924–926 |
| `MSP_SERVO_CONFIGURATIONS` receive | `msp.c` | ~1954–1983 |
| `MSP_FILTER_CONFIG` cadence_gain | `msp.c` | ~1427 |
| API version define | `msp_protocol.h` | 72–74 |
| ONDAS param storage | `servos.h` / `servoConfig_t` | 140–167 |

---

## 1. MSP Framing

Every message is framed:

```
$ M <dir> <len> <code> [payload...] <checksum>
```

| Byte | Value | Meaning |
|------|-------|---------|
| 0 | `$` (0x24) | Sync 1 |
| 1 | `M` (0x4D) | Sync 2 |
| 2 | `>` / `<` / `!` | Direction: FC→GUI / GUI→FC / unsupported |
| 3 | `len` | Payload length (if 255 = jumbo, followed by 2 more len bytes) |
| 4 | `code` | MSP command code |
| 5..n | — | Payload |
| n+1 | `checksum` | XOR of len ⊕ code ⊕ payload bytes |

---

## 2. Flight Controller Identification

**MSP_FC_VARIANT (2)** — 4 ASCII bytes, polled at connect.

The configurator does **not** currently gate on `flightControllerIdentifier === 'ORNI'` — instead, all ornithopter features are gated on **API version** (`semver.gte(CONFIG.apiVersion, "1.41")` / `"1.42"`). This means any firmware that reports the right API version and responds to the MSP commands below will work. The identifier is informational only.

---

## 3. API Version Thresholds

| Version | What unlocks |
|---------|-------------|
| `1.33.0` | Servo config v2 (`ornithopter_glide_deg` + ONDAS v1 in `MSP_SERVO_CONFIGURATIONS`) |
| `1.41.0` | `flapBaseFrequency`, `flapBaseAmplitude`, ONDAS v1 (`cadence_gain`, `ferocity_d_gain`, `balance_gain` in `MSP_PID_ADVANCED`) |
| `1.42.0` | **ONDAS v2 — full 10-param set** + `itermRelaxCutoff` |
| `1.43.0` | **Phase 2 — Wing Pair Geometry + Advanced ONDAS Gains (12 new values)** |

**Firmware now reports `1.43.0`.** → ONDAS v2 + Phase 2 UI active when connected to OrniFlight firmware. ✅

---

## 4. MSP Command Map (Ornithopter-Relevant)

| Code | Name | Direction | Carries |
|------|------|-----------|---------|
| 1 | `MSP_API_VERSION` | FC→GUI | Protocol version (`1.42.0`) |
| 2 | `MSP_FC_VARIANT` | FC→GUI | 4-char identifier — now `"ORNI"` ✅ |
| 42/43 | `MSP_MIXER_CONFIG` | R/W | `mixer` (u8) — mixer enum (ornithopter=27, not in configurator list) |
| 92/93 | `MSP_FILTER_CONFIG` | R/W | Filter settings + legacy `cadence_gain` |
| **94/95** | **`MSP_PID_ADVANCED`** | **R/W** | **ALL ONDAS v2 (10 params) + flapBase + itermRelaxCutoff + Phase 2 (12 params) = 71 bytes** |
| 120/212 | `MSP_SERVO_CONFIGURATIONS` | R/W | Per-servo config + `ornithopter_glide_deg` + ONDAS v1 triplet |
| 244 | `MSP_SET_ORNITHOPTER_GLIDE_DEGREE` | GUI→FC | ⛔ **NO-OP** in firmware (use SERVO_CONFIGURATIONS instead) |

---

## 5. MSP_PID_ADVANCED (94/95) — Full Packet Layout

This is the **primary bearer** of stabilization parameters. The firmware must serialize/deserialize in exactly this order. All integers are **little-endian**.

### 5.1 Fields (apiVersion ≥ 1.43) — Phase 1 & 2 Verified ✅

| Offset | Wire | JS Read | FW Send (`msp.c`) | Field | Range | Default |
|--------|------|---------|-------------------|-------|-------|---------|
| 0 | u16 | `readU16()` | `sbufWriteU16` | `rollPitchItermIgnoreRate` | 0–65535 | 0 |
| 2 | u16 | `readU16()` | `sbufWriteU16` | `yawItermIgnoreRate` | 0–65535 | 0 |
| 4 | u16 | `readU16()` | `sbufWriteU16` | `yaw_p_limit` | 0–65535 | 0 |
| 6 | u8 | `readU8()` | `0` (reserved) | `deltaMethod` | 0–1 | 0 |
| 7 | u8 | `readU8()` | `vbatPidCompensation` | `vbatPidCompensation` | 0–1 | 0 |
| 8 | u8 | `readU8()` | `feedForwardTransition` | `feedforwardTransition` | 0–255 | 0 |
| 9 | u8 | `readU8()` | `0` (deprecated) | `dtermSetpointWeight` (u8) | 0–254 | 0 |
| 10 | u8 | `readU8()` | `0` (deprecated) | `toleranceBand` | 0–255 | 0 |
| 11 | u8 | `readU8()` | `0` (deprecated) | `toleranceBandReduction` | 0–255 | 0 |
| 12 | u8 | `readU8()` | `0` (deprecated) | `itermThrottleGain` | 0–255 | 0 |
| 13 | u16 | `readU16()` | `rateAccelLimit` | `pidMaxVelocity` | 0–65535 | 0 |
| 15 | u16 | `readU16()` | `yawRateAccelLimit` | `pidMaxVelocityYaw` | 0–65535 | 0 |
| 17 | u8 | `readU8()` | `levelAngleLimit` | `levelAngleLimit` | 0–255 | 0 |
| 18 | u8 | `readU8()` | `0` (deprecated) | `levelSensitivity` | 0–255 | 0 |
| 19 | u16 | `readU16()` | `itermThrottleThreshold` | `itermThrottleThreshold` | 0–65535 | 0 |
| 21 | u16 | `readU16()` | `itermAcceleratorGain` | `itermAcceleratorGain` | 0–65535 | 0 |
| 23 | u16 | `readU16()` | `0` (deprecated) | `dtermSetpointWeight` (u16) | 0–65535 | 0 |
| 25 | u8 | `readU8()` | `iterm_rotation` | `itermRotation` | 0–1 | 0 |
| 26 | u8 | `readU8()` | `smart_feedforward` | `smartFeedforward` | 0–1 | 0 |
| 27 | u8 | `readU8()` | `iterm_relax` | `itermRelax` | 0–255 | 0 |
| 28 | u8 | `readU8()` | `iterm_relax_type` | `itermRelaxType` | 0–255 | 0 |
| 29 | u8 | `readU8()` | `abs_control_gain` | `absoluteControlGain` | 0–255 | 0 |
| 30 | u8 | `readU8()` | `throttle_boost` | `throttleBoost` | 0–255 | 0 |
| 31 | u8 | `readU8()` | `acro_trainer_angle_limit` | `acroTrainerAngleLimit` | 0–255 | 0 |
| 32 | u16 | `readU16()` | `pid[ROLL].F` | `feedforwardRoll` | 0–65535 | 0 |
| 34 | u16 | `readU16()` | `pid[PITCH].F` | `feedforwardPitch` | 0–65535 | 0 |
| 36 | u16 | `readU16()` | `pid[YAW].F` | `feedforwardYaw` | 0–65535 | 0 |
| 38 | u8 | `readU8()` | `antiGravityMode` | `antiGravityMode` | 0–255 | 0 |
| 39 | u8 | `readU8()` | `d_min[ROLL]` | `dMinRoll` | 0–255 | 0 |
| 40 | u8 | `readU8()` | `d_min[PITCH]` | `dMinPitch` | 0–255 | 0 |
| 41 | u8 | `readU8()` | `d_min[YAW]` | `dMinYaw` | 0–255 | 0 |
| 42 | u8 | `readU8()` | `d_min_gain` | `dMinGain` | 0–255 | 0 |
| 43 | u8 | `readU8()` | `d_min_advance` | `dMinAdvance` | 0–255 | 0 |
| 44 | u8 | `readU8()` | `use_integrated_yaw` | `useIntegratedYaw` | 0–1 | 0 |
| 45 | u8 | `readU8()` | `integrated_yaw_relax` | `integratedYawRelax` | 0–255 | 0 |
| 46 | u8 | `readU8()` | `flap_base_frequency` | `flapBaseFrequency` | 1–1000 | 0 |
| 47 | u8 | `readU8() - 128` | `flap_base_amplitude + 128` | `flapBaseAmplitude` | –100..100 | 0 |
| 48 | u8 | `readU8()` | `iterm_relax_cutoff` | `itermRelaxCutoff` | 0–255 | 0 |
| **49** | **u8** | **`readU8() - 128`** | **`cadence_gain + 128`** | **`cadence_gain`** | **–100..100** | **20** |
| **50** | **u8** | **`readU8() - 128`** | **`ferocity_d_gain + 128`** | **`ferocity_d_gain`** | **–100..100** | **20** |
| **51** | **u8** | **`readU8() - 128`** | **`balance_gain + 128`** | **`balance_gain`** | **–100..100** | **10** |
| **52** | **u8** | **`readU8()`** | **`ferocity_p_gain`** | **`ferocity_p_gain`** | **0..100** | **10** |
| **53** | **u8** | **`readU8()`** | **`ferocity_roll_gain`** | **`ferocity_roll_gain`** | **0..100** | **0** |
| **54** | **u8** | **`readU8()`** | **`ferocity_yaw_gain`** | **`ferocity_yaw_gain`** | **0..100** | **0** |
| **55** | **u8** | **`readU8() - 128`** | **`warp_gain + 128`** | **`warp_gain`** | **–100..100** | **0** |
| **56** | **u8** | **`readU8() - 128`** | **`warp_yaw_gain + 128`** | **`warp_yaw_gain`** | **–100..100** | **0** |
| **57** | **u8** | **`readU8()`** | **`anchor_gain`** | **`anchor_gain`** | **0..100** | **0** |
| **58** | **u8** | **`readU8()`** | **`resonance_gain`** | **`resonance_gain`** | **0..100** | **0** |

**Total payload**: 59 bytes. ✅ Firmware version 1.42.0.

### 5.2 Wire Type Convention — Verified & Fixed

| C Type | Wire Encoding | JS Read | JS Write |
|--------|--------------|---------|----------|
| `int8_t` (–100..100) | `uint8_t = val + 128` | `readU8() - 128` | `push8(val + 128)` |
| `uint8_t` (0..100) | `uint8_t` direct | `readU8()` | `push8(val)` |

**Signed params** (cadence_gain, ferocity_d_gain, balance_gain, warp_gain, warp_yaw_gain): JS now uses `readU8() - 128` on read and `push8(val + 128)` on write — matching firmware's `sbufWriteU8(val + 128)` / `(int8_t)(sbufReadU8(src) - 128)`.

**Unsigned params** (ferocity_p, ferocity_roll, ferocity_yaw, anchor, resonance): direct wire pass-through, 0–100.

### 5.3 Backward Compatibility

Send handler (`MSP_SET_PID_ADVANCED`) now sends **59 bytes** when `apiVersion >= 1.42.0`, **48 bytes** otherwise. The firmware handles both — gated with `sbufBytesRemaining(src) >= 11`.

### 5.4 Form → ADVANCED_TUNING Mapping (Configurator Internal)

The PID Tuning tab reads/writes these JS fields:

| HTML input `name` | JS field | Type |
|-------------------|----------|------|
| `cadenceGain` | `ADVANCED_TUNING.cadence_gain` | int |
| `ferocityDGain` | `ADVANCED_TUNING.ferocity_d_gain` | int |
| `balanceGain` | `ADVANCED_TUNING.balance_gain` | int |
| `ferocityPGain` | `ADVANCED_TUNING.ferocity_p_gain` | int |
| `ferocityRollGain` | `ADVANCED_TUNING.ferocity_roll_gain` | int |
| `ferocityYawGain` | `ADVANCED_TUNING.ferocity_yaw_gain` | int |
| `warpGain` | `ADVANCED_TUNING.warp_gain` | int |
| `warpYawGain` | `ADVANCED_TUNING.warp_yaw_gain` | int |
| `anchorGain` | `ADVANCED_TUNING.anchor_gain` | int |
| `resonanceGain` | `ADVANCED_TUNING.resonance_gain` | int |
| `flapBaseFrequency-number` | `ADVANCED_TUNING.flapBaseFrequency` | int |
| `flapBaseAmplitude-number` | `ADVANCED_TUNING.flapBaseAmplitude` | int |

### 5.5 Locale Keys for UI Labels

| HTML `i18n` key | ONDAS Param |
|-----------------|-------------|
| `pidTuningOndasGroup` | Section header |
| `pidTuningOndasHelp` | ONDAS overview tooltip |
| `pidTuningCadenceGain` | Cadence |
| `pidTuningFerocityDGain` | Ferocity D |
| `pidTuningBalanceGain` | Balance |
| `pidTuningFerocityPGain` | Ferocity P |
| `pidTuningFerocityRollGain` | Ferocity Roll |
| `pidTuningFerocityYawGain` | Ferocity Yaw |
| `pidTuningWarpGain` | Warp |
| `pidTuningWarpYawGain` | Warp Yaw |
| `pidTuningAnchorGain` | Anchor |
| `pidTuningResonanceGain` | Resonance |

---

## 6. FILTER_CONFIG (92/93) — Legacy cadence_gain

The `MSP_FILTER_CONFIG` packet also carries `cadence_gain` as the **last byte** when `apiVersion >= 1.41`:

| Condition | Extra byte |
|-----------|-----------|
| `apiVersion >= 1.41` and `< 1.42` | `cadence_gain` (u8) appended at end |
| `apiVersion >= 1.42` | `cadence_gain` (u8) still appended, after dyn_notch fields |

⚠️ This is a **legacy path** — ONDAS v2 moved everything to `MSP_PID_ADVANCED`. For OrniFlight firmware ≥ 1.42, the `FILTER_CONFIG.cadence_gain` should match `ADVANCED_TUNING.cadence_gain` but the **authoritative source is MSP_PID_ADVANCED**.

---

## 7. SERVO_CONFIGURATIONS (120/212) — ONDAS v1 + Glide ✅

The `MSP_SERVO_CONFIGURATIONS` packet appends 4 trailing bytes after per-servo records when `apiVersion >= 1.33`:

| Offset (after servos) | Wire | JS Read | FW Send (`msp.c:924`) | Field | Range |
|------------------------|------|---------|----------------------|-------|-------|
| +0 | u8 | `readU8() - 128` | `glide_deg + 128` | `ornithopter_glide_deg` | –128..127 |
| +1 | u8 | `readU8() - 128` | `cadence_gain + 128` | `cadence_gain` | –100..100 |
| +2 | u8 | `readU8() - 128` | `ferocity_d_gain + 128` | `ferocity_d_gain` | –100..100 |
| +3 | u8 | `readU8() - 128` | `balance_gain + 128` | `balance_gain` | –100..100 |

All 4 are signed → wire = val+128. JS uses `readU8() - 128` / `push8(val + 128)`. ✅ Fixed.

Write path: 4 trailing bytes sent once (not per-servo), flagged by `ornithopter_glide_deg_sent`.

Firmware receive: if `dataSize <= 4` reads glide + triplet; if `dataSize == 1` (legacy) reads only glide.

---

## 8. MIXER_CONFIG (42/43)

| Field | Type | Values |
|-------|------|--------|
| `mixer` | u8 | 1–26 (Betaflight enum) + **27 = `MIXER_SERVO_ORNITHOPTER`** |
| `reverseMotorDir` | u8 | 0/1 (only if `apiVersion >= 1.16`) |

The configurator's `mixerList` array (in `model.js`) only has entries 1–26. Ornithopter mixer type 27 has no 3D model — **configurator feature gap** 🔵. Cosmetic only, no protocol impact.

---

## 9. Configurator State Initialization

When connecting, the configurator polls this sequence:

1. `MSP_API_VERSION` → `CONFIG.apiVersion`
2. `MSP_FC_VARIANT` → `CONFIG.flightControllerIdentifier`
3. `MSP_FC_VERSION` → `CONFIG.flightControllerVersion`
4. `MSP_BUILD_INFO` → `CONFIG.buildInfo`
5. `MSP_BOARD_INFO` → `CONFIG.boardIdentifier` etc.
6. `MSP_UID` → `CONFIG.uid`
7. `MSP_STATUS` / `MSP_STATUS_EX` → cycleTime, activeSensors, profile
8. `MSP_PID_ADVANCED` → populates `ADVANCED_TUNING` **including all ONDAS params**
9. `MSP_FILTER_CONFIG` → populates `FILTER_CONFIG`
10. `MSP_SERVO_CONFIGURATIONS` → populates `SERVO_CONFIG` + ONDAS v1

### On "Save" click:
1. `MSP_SET_PID_ADVANCED` — sends full ADVANCED_TUNING back
2. `MSP_EEPROM_WRITE` — persists to flash

---

## 10. Param Name Correspondence (Configurator JS ↔ Firmware C)

| Configurator (`ADVANCED_TUNING.*`) | Firmware C (`servoConfig_t`) | `servos.h` Line |
|-------------------------------------|------------------------------|-----------------|
| `cadence_gain` | `cadence_gain` | ~148 |
| `ferocity_d_gain` | `ferocity_d_gain` | ~149 |
| `balance_gain` | `balance_gain` | ~150 |
| `ferocity_p_gain` | `ferocity_p_gain` | ~151 |
| `ferocity_roll_gain` | `ferocity_roll_gain` | ~152 |
| `ferocity_yaw_gain` | `ferocity_yaw_gain` | ~153 |
| `warp_gain` | `warp_gain` | ~154 |
| `warp_yaw_gain` | `warp_yaw_gain` | ~155 |
| `anchor_gain` | `anchor_gain` | ~156 |
| `resonance_gain` | `resonance_gain` | ~157 |
| `flapBaseFrequency` | `flap_base_frequency` | — |
| `flapBaseAmplitude` | `flap_base_amplitude` | — |

All ONDAS params are stored in `servoConfig_t` (not `pidProfile_t`). The legacy `cadence_gain` also appears in `MSP_FILTER_CONFIG` and `MSP_SERVO_CONFIGURATIONS`. Authoritative source for ONDAS v2: **`MSP_PID_ADVANCED`**.

---

## 11. Phase 1 Status Matrix ✅

| # | Item | Firmware | Configurator |
|---|------|----------|-------------|
| 1 | `API_VERSION_MINOR` = 42 | ✅ | ✅ gates on `1.42.0` |
| 2 | `MSP_FC_VARIANT` = `"ORNI"` | ✅ | ✅ read, informational |
| 3 | `MSP_PID_ADVANCED` 59 bytes | ✅ offsets 48–58 | ✅ read/write verified |
| 4 | Signed wire conversion (val+128) | ✅ `sbufWriteU8`/`sbufReadU8` | ✅ `readU8()-128`/`push8(val+128)` |
| 5 | Unsigned wire conversion (direct) | ✅ | ✅ `readU8()`/`push8(val)` |
| 6 | `SERVO_CONFIGURATIONS` 4 trailing bytes | ✅ | ✅ read/write fixed |
| 7 | Backward compat: FW accepts 48 or 59 bytes | ✅ `sbufBytesRemaining >= 11` | ✅ sends 59 when v≥1.42 |
| 8 | `MSP_SET_ORNITHOPTER_GLIDE_DEGREE` (244) | ⛔ no-op | N/A (unused) |
| 9 | Mixer type 27 (`MIXER_SERVO_ORNITHOPTER`) | ✅ | 🔲 no 3D model |
| 10 | `SERVO_CONFIG` truthiness fix (glide_deg=0) | ✅ | ✅ `!= null` gate |

---

## 12. Phase 2 Preview — 12 New Values (apiVersion ≥ 1.43.0)

These fields exist in `servoConfig_t` but are **not yet on the MSP wire** (CLI-only in firmware):

### 12.1 Wing Pair Geometry (8 values)

| Proposed Offset | C Field | Type | Wire | Range | Meaning |
|-----------------|---------|------|------|-------|---------|
| 59 | `servo_mount_angle[0]` | int8 | u8=val+128 | –30..+30° | Wing pair 1 incidence angle |
| 60 | `servo_mount_angle[1]` | int8 | u8=val+128 | –30..+30° | Wing pair 2 incidence angle |
| 61 | `servo_mount_angle[2]` | int8 | u8=val+128 | –30..+30° | Wing pair 3 incidence angle |
| 62 | `servo_mount_angle[3]` | int8 | u8=val+128 | –30..+30° | Wing pair 4 incidence angle |
| 63 | `flapping_phase_shift[0]` | int8 | u8=val+128 | –180..+180° | Wing pair 1 phase offset |
| 64 | `flapping_phase_shift[1]` | int8 | u8=val+128 | –180..+180° | Wing pair 2 phase offset |
| 65 | `flapping_phase_shift[2]` | int8 | u8=val+128 | –180..+180° | Wing pair 3 phase offset |
| 66 | `flapping_phase_shift[3]` | int8 | u8=val+128 | –180..+180° | Wing pair 4 phase offset |

### 12.2 Advanced ONDAS Gains (4 values)

| Proposed Offset | C Field | Type | Wire | Range | Meaning |
|-----------------|---------|------|------|-------|---------|
| 67 | `prescience_gain` | int8 | u8 direct | 0–100 | Stroke-ahead prediction |
| 68 | `espelho_gain` | int8 | u8 direct | 0–100 | Wing-self-noise cancellation |
| 69 | `saudade_gain` | int8 | u8 direct | 0–100 | Per-stroke learning rate |
| 70 | `ssff_gain` | int8 | u8 direct | 0–100 | Feed-forward trim authority |

Adding all 12 values grows `MSP_PID_ADVANCED` from 59 → **71 bytes** at `apiVersion >= 1.43.0`.

**UI placement**: Extend the existing ONDAS section in PID Tuning tab with two new subsections:
- "Wing Pair Setup" (4 incidence + 4 phase sliders) — gated on multi-wing mixer
- "Advanced ONDAS" (4 gain sliders) — gated on `apiVersion >= 1.43.0`

### 12.3 Phase 2 TODO

**Firmware-side:**
- [ ] Add 12 values to `MSP_PID_ADVANCED` send/receive at offsets 59–70
- [ ] Bump `API_VERSION_MINOR` to 43
- [ ] Gate on `sbufBytesRemaining(src) >= 16` for backward compat

**Configurator-side:**
- [ ] JS read/write for offsets 59–70 (8 signed + 4 unsigned)
- [ ] HTML: 4 "Wing Pair N Incidence" sliders (–30..+30°, val+128 wire)
- [ ] HTML: 4 "Wing Pair N Phase Offset" sliders (–180..+180°, val+128 wire)
- [ ] HTML: 4 advanced gain sliders (0–100, direct wire)
- [ ] Locale entries for all 12 new labels
- [ ] Gate UI on `apiVersion >= "1.43.0"`