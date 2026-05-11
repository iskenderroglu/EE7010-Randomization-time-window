# Randomization Time Window — Flowchart

Based on EPRI 3002008217 *Common Functions for Smart Inverters*, 4th Ed.
Reference sections: §5 (Connect/Disconnect), §7–9 (Charge/Discharge), §16 (Reconnect).

## 1. Single DER — apply new setting

```mermaid
flowchart TD
    A([Start]) --> B[Receive new setting at t_broadcast<br/>P_old --> P_new]
    B --> C[Read Tw = Randomization Time Window<br/>Read Tr = Ramp Time]
    C --> D["delay = randi 0..Tw"]
    D --> E[t_apply = t_broadcast + delay]
    F{t >= t_apply?} -- No --> G[Hold P_old]
    G --> F
    F -- Yes --> H{t < t_apply + Tr?}
    H -- Yes --> I["P = P_old + t-t_apply / Tr * P_new-P_old"]
    I --> H
    H -- No --> J[P = P_new]
    J --> K([Done])
```

## 2. Fleet broadcast — N DERs receive same command

```mermaid
flowchart TD
    A([Broadcast at t_broadcast]) --> B[For each DER i = 1..N]
    B --> C["delay_i = randi 0..Tw"]
    C --> D[t_apply_i = t_broadcast + delay_i]
    D --> E[Each DER independently runs<br/>single-DER state machine]
    E --> F[Fleet response = mean of all DERs]
    F --> G([Aggregated ramp spread over Tw + Tr])
```

Effect: uniform delays in `[0, Tw]` desynchronize responses, avoiding
simultaneous step on feeder.

## 3. Reconnect after voltage/frequency disturbance — EPRI §16

```mermaid
flowchart TD
    A([Disturbance ends<br/>V back in band at t_clear]) --> B[Read TDelay, TWindow, TRamp]
    B --> C["wait_total = TDelay + rand * TWindow"]
    C --> D[t_reconnect = t_clear + wait_total]
    E{t >= t_reconnect?} -- No --> F[P = 0, stay disconnected]
    F --> E
    E -- Yes --> G{t < t_reconnect + TRamp?}
    G -- Yes --> H["P = t-t_reconnect / TRamp * P_full"]
    H --> G
    G -- No --> I[P = P_full]
    I --> J([Reconnected])
```

## Parameter map

| Symbol | EPRI name | Section |
|---|---|---|
| `Tw` | Randomization Time Window / Time Window | §5, §7, §8, §9 |
| `Tr` | Ramp Time (Output/Input Inc/Dec) | §7, §8 |
| `TDelay` | TDelayShortReconnect / TDelayLongReconnect | §16 |
| `TWindow` | TWindowShortReconnect / TWindowLongReconnect | §16 |
| `TRamp` | TRampShortReconnect / TRampLongDisconnect | §16 |
