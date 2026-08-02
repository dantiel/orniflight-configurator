# MSP Interface Changelog

> *Track what changed at the protocol boundary between OrniFlight firmware and configurator — so both repos stay in lockstep.*

---

## How to Use

Every MSP payload change that affects the configurator must be recorded here. Firmware devs: document new fields before cutting a release. Configurator devs: read this before implementing MSP handlers.

**Format**: API version → command affected → what was added/changed, with byte offsets and types.

---

## OrniFlight v1.0.0 (API 1.46)

### MSP_PID_ADVANCED (94/95) — Phase 6: Ornithopter Profile + Aeroelastic

*Gate: `semver.gte(apiVersion, '1.46.0')`*

Appended 5 bytes to PID_ADVANCED payload:

| Offset | Type | Field | Range |
|--------|------|-------|-------|
| +0 | u8 | `ornithopter_profile_index` | 0–N |
| +1 | u8 | `ferocity_downstroke` | 0–100 |
| +2 | u8 | `ferocity_upstroke` | 0–100 |
| +3 | u8 | `aeroelastic_glide_coefficient` | signed (wire = val+128) |
| +4 | u8 | `aeroelastic_flap_coefficient` | signed (wire = val+128) |

---

## OrniFlight v0.5.x (API 1.45)

### MSP_PID_ADVANCED (94/95) — Phase 5: Independent Flight Mode

*Gate: `semver.gte(apiVersion, '1.45.0')`*

Appended 3 bytes to PID_ADVANCED payload:

| Offset | Type | Field | Range |
|--------|------|-------|-------|
| +0 | u8 | `ornithopter_freq_channel` | 0–18 (AUX channel) |
| +1 | u8 | `ornithopter_freq_min` | Hz |
| +2 | u8 | `ornithopter_freq_max` | Hz |

---

## OrniFlight v0.4.x (API 1.44)

### MSP_PID_ADVANCED (94/95) — Phase 4: GralhaAzul — Servo Physics + Wing Trim

*Gate: `semver.gte(apiVersion, '1.44.0')`*

Appended 8 bytes to PID_ADVANCED payload:

| Offset | Type | Field | Range |
|--------|------|-------|-------|
| +0 | u16 | `servo_speed_deg_s` | 0–4000 (°/s) |
| +2 | u8 | `servo_max_amplitude` | 0–100 |
| +3 | u8 | `flap_magnitude` | 0–100 |
| +4 | u8 | `wing_origin_offset_0` | signed (wire = val+128) |
| +5 | u8 | `wing_origin_offset_1` | signed |
| +6 | u8 | `wing_origin_offset_2` | signed |
| +7 | u8 | `wing_origin_offset_3` | signed |

---

## OrniFlight v0.3.x (API 1.43)

### MSP_PID_ADVANCED (94/95) — Phase 3: Wing Pair Geometry + Advanced Gains

*Gate: `semver.gte(apiVersion, '1.43.0')`*

Appended 12 bytes to PID_ADVANCED payload:

| Offset | Type | Field | Range |
|--------|------|-------|-------|
| +0 | u8 | `servo_mount_angle_0` | signed (wire = val+128) |
| +1 | u8 | `servo_mount_angle_1` | signed |
| +2 | u8 | `servo_mount_angle_2` | signed |
| +3 | u8 | `servo_mount_angle_3` | signed |
| +4 | u8 | `flapping_phase_shift_0` | signed (wire = val+128) |
| +5 | u8 | `flapping_phase_shift_1` | signed |
| +6 | u8 | `flapping_phase_shift_2` | signed |
| +7 | u8 | `flapping_phase_shift_3` | signed |
| +8 | u8 | `prescience_gain` | 0–100 |
| +9 | u8 | `espelho_gain` | 0–100 |
| +10 | u8 | `saudade_gain` | 0–100 |
| +11 | u8 | `ssff_gain` | 0–100 |

---

## OrniFlight v0.2.x (API 1.42)

### MSP_PID_ADVANCED (94/95) — Phase 2: Core ONDAS Parameters

*Gate: `semver.gte(apiVersion, '1.42.0')`*

Appended 12 bytes to PID_ADVANCED payload:

| Offset | Type | Field | Range |
|--------|------|-------|-------|
| +0 | u8 | `itermRelaxCutoff` | 0–50 (Hz) |
| +1 | u8 | `cadence_gain` | signed (wire = val+128) |
| +2 | u8 | `ferocity_d_gain` | signed (wire = val+128) |
| +3 | u8 | `balance_gain` | signed (wire = val+128) |
| +4 | u8 | `ferocity_p_gain` | 0–100 |
| +5 | u8 | `ferocity_roll_gain` | 0–100 |
| +6 | u8 | `ferocity_yaw_gain` | 0–100 |
| +7 | u8 | `warp_gain` | signed (wire = val+128) |
| +8 | u8 | `warp_yaw_gain` | signed (wire = val+128) |
| +9 | u8 | `anchor_gain` | 0–100 |
| +10 | u8 | `resonance_gain` | 0–100 |

### MSP_FILTER_CONFIG (92/93)

*Gate: `semver.gte(apiVersion, '1.42.0')`*

Appended 1 byte + 5 new bytes after cadence_gain (which was added unconditionally at 1.41):

| Offset | Type | Field |
|--------|------|-------|
| +0 | u8 | `cadence_gain` |
| +1 | u8 | `dyn_notch_range` |
| +2 | u8 | `dyn_notch_width_percent` |
| +3 | u16 | `dyn_notch_q` |
| +5 | u16 | `dyn_notch_min_hz` |
| +7 | u8 | `gyro_rpm_notch_harmonics` |
| +8 | u8 | `gyro_rpm_notch_min_hz` |

### MSP_VTX_CONFIG (88/89)

*Gate: `semver.gte(apiVersion, '1.42.0')`*

Added `vtx_pit_mode_frequency` (u16) field.

---

## OrniFlight v0.1.x (API 1.41) — Initial OrniFlight Fork

### MSP_PID_ADVANCED (94/95)

*Gate: `semver.gte(apiVersion, '1.41.0')`*

Appended 2 bytes to PID_ADVANCED payload:

| Offset | Type | Field | Range |
|--------|------|-------|-------|
| +0 | u8 | `flapBaseFrequency` | 0–100 (Hz) |
| +1 | u8 | `flapBaseAmplitude` | signed (wire = val+128) |

### MSP_SERVO_CONFIGURATIONS (120/212)

*Gate: `semver.gte(apiVersion, '1.33.0')`*

Appended 4 bytes after servo array:

| Offset | Type | Field | Range |
|--------|------|-------|-------|
| +0 | u8 | `ornithopter_glide_deg` | signed (wire = val+128) |
| +1 | u8 | `cadence_gain` | signed (wire = val+128) |
| +2 | u8 | `ferocity_d_gain` | signed (wire = val+128) |
| +3 | u8 | `balance_gain` | signed (wire = val+128) |

---

## Pre-OrniFlight (Betaflight 10.6.0 base)

All standard Betaflight MSP commands (API 1.0–1.40) remain unchanged. See [Betaflight MSP documentation](https://github.com/betaflight/betaflight/tree/master/docs) for the baseline protocol. OrniFlight extends MSP_PID_ADVANCED and MSP_SERVO_CONFIGURATIONS — all other commands are wire-compatible.

---

## Signed Value Convention

OrniFlight uses the same wire encoding as Betaflight for signed 8-bit values:

| Wire byte | Interpreted value | Conversion |
|-----------|-------------------|------------|
| 0 | −128 | `val = wire − 128` |
| 128 | 0 | |
| 255 | +127 | |

---

## Gate Map Summary

```
API 1.41  →  flapBaseFrequency, flapBaseAmplitude (MSP_PID_ADVANCED)
API 1.42  →  Core stabilization params (MSP_PID_ADVANCED +12B)
           →  cadence_gain + dyn notch (MSP_FILTER_CONFIG +9B)
           →  pit mode freq (MSP_VTX_CONFIG)
API 1.43  →  Wing pair geometry + advanced gains (MSP_PID_ADVANCED +12B)
API 1.44  →  Servo physics + wing trim (MSP_PID_ADVANCED +8B)
API 1.45  →  Independent freq channel (MSP_PID_ADVANCED +3B)
API 1.46  →  Profile + aeroelastic (MSP_PID_ADVANCED +5B)
```
