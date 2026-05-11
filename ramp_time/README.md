# Ramp Time — EPRI 3002008217

LV-network Simulink-ready ramp signal generator.

## Files
- `ramp_time_sim.m` — main demo. Builds multi-segment ramped setpoint, exports `ramp_setpoint.mat`.
- `ramp_apply.m`   — reusable helper. Drop into a Simulink MATLAB Function block.

## EPRI parameters covered (Section 4 + 6/7/8)
| Symbol | Meaning | Unit |
|---|---|---|
| `WGra` | default real-power ramp rate | %WMax/s |
| `Tr`   | ramp time (full transition) | s |
| Output Inc/Dec, Input Inc/Dec | four directional variants | — |

Relationship: `Tr = |P_new − P_old| / WGra`.

## Simulink integration
1. Run `ramp_time_sim.m` → produces `ramp_setpoint.mat` with `P_signal` struct.
2. In Simulink LV-network model add **From Workspace** block, variable = `P_signal`.
3. Feed output to active-power reference of inverter (e.g. `Pref` input of `Three-Phase Dynamic Load` or controlled current source).
4. For online computation (no precomputed signal), use **MATLAB Function** block:
   ```matlab
   function P = setpoint(t)
       P = ramp_apply(t, 5, 0, 5000, 2);
   end
   ```

## Sign convention
- `+P` = export to grid (PV / discharge)
- `−P` = import from grid (storage charge)
