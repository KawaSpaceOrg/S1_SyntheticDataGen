# S1 — Synthetic RF Data Generation Pipeline (MATLAB)

A modular MATLAB pipeline that synthesizes the baseband I/Q data a phased-array
receiver would record from a single distant emitter. It models the full chain:
**geometry → waveform → propagation → downconversion → ADC → processing**, then
plots the results and exports the data to CSV.

Requires the **Phased Array System Toolbox** (`phased.ULA`, `phased.FreeSpace`,
`physconst`, `fspl`).

---

## How to run

1. Open MATLAB in this folder (`S1_SyntheticDataGen`).
2. Run the orchestrator:
   ```matlab
   main_pipeline
   ```
3. You get **3 figures** and a **`pipeline_output.csv`** file (see below).

---

## Pipeline stages & files

| Stage | File | What it does |
|-------|------|--------------|
| Orchestrator | [`main_pipeline.m`](main_pipeline.m) | Defines all parameters, runs every stage in order, exports CSV, draws the figures. |
| 0 — Geometry | [`stage0_geometry.m`](stage0_geometry.m) | Places the ground **emitter** and the airborne **receiver array**, and builds a Uniform Linear Array (ULA). |
| 1 — Waveform | [`stage1_waveform.m`](stage1_waveform.m) | Generates the transmitted signal: a **pulsed Linear-FM (LFM) chirp** with a duty cycle. (A CW-tone option is included but commented out.) |
| 2 — Channel | [`stage2_channel.m`](stage2_channel.m) | Applies **free-space propagation**: path loss + per-element delay/phase, via `phased.FreeSpace`. One emitter → N array elements. |
| 4 — Downconversion | [`stage4_downconversion.m`](stage4_downconversion.m) | **Superheterodyne** receiver: mixes the signal to a non-zero **Intermediate Frequency (IF)** and adds a residual **image** component (set by the image-rejection ratio). |
| 5 — ADC | [`stage5_adc.m`](stage5_adc.m) | Models an **N-bit ADC**: clips to full scale and quantizes the I and Q channels. |
| 6 — Processing | [`stage6_processing.m`](stage6_processing.m) | Signal conditioning. DC removal is **disabled** here (superhet has no DC offset); currently a pass-through. |

> There is intentionally **no Stage 3** — the original architecture numbered the
> stages with a gap, and it has been kept for traceability.

### Data flow
```
stage0 ──► tx_pos, rx_array
stage1 ──► tx_sig (LFM chirp)
stage2 ──► rx_sig   [num_samples x num_elements]   (propagated, attenuated, phase-shifted)
stage4 ──► bb_sig   (signal at the IF + image)
stage5 ──► adc_sig  (quantized I/Q)
stage6 ──► processed_sig  (final output → CSV + plots)
```

---

## Parameters you can change to play around

### In `main_pipeline.m` (global)
| Parameter | Default | Meaning / try this |
|-----------|---------|--------------------|
| `fc` | `2.4e9` | Carrier frequency (Hz). Sets the wavelength and array spacing. |
| `fs` | `10e6` | Sample rate (Hz). Also sets the chirp bandwidth (`B = fs/2`). |
| `num_samples` | `1024` | Length of the simulation (total time = `num_samples/fs`). |
| `f_tone` | `1e6` | Baseband tone frequency — only used by the commented-out CW option in Stage 1. |
| `num_elements` | `4` | Number of antenna elements in the ULA. |
| `f_if` | `1e6` | Intermediate Frequency for the superheterodyne stage. Keep `< fs/2` to avoid aliasing. |
| `image_reject_db` | `30` | Image-rejection ratio (dB). **Lower** = a stronger, more visible image artifact. |
| `num_bits` | `14` | ADC resolution. **Drop to 4–6** to see the quantization "staircase" clearly. |
| `full_scale_volts` | `rx_voltage_peak*1.2` | ADC full-scale voltage. Reduce the `1.2` margin to force clipping. |

### In `stage0_geometry.m` (scene)
| Parameter | Default | Meaning / try this |
|-----------|---------|--------------------|
| `tx_pos` | `[5000; 0; 0]` | Emitter location [X;Y;Z] in metres. |
| `rx_pos` | `[0; 0; 20000]` | Receiver array center [X;Y;Z] in metres (20 km altitude). |
| `ElementSpacing` | `lambda/2` | Distance between elements. |
| `ArrayAxis` | `'x'` | Orientation of the array. **Important:** a non-zero projection of the line-of-sight onto the array axis is what creates the inter-element phase shift. With `'y'` (and this geometry) the source is broadside → **no phase shift**. Try `'z'` for a much larger shift. |

### In `stage1_waveform.m` (waveform)
| Parameter | Default | Meaning / try this |
|-----------|---------|--------------------|
| `B` | `fs/2` | Chirp sweep bandwidth (Hz). |
| `duty_cycle` | `0.5` | Fraction of each pulse interval the chirp is active. |
| `pri_samples` | `256` | Pulse Repetition Interval (samples). Controls how many pulses fit in the buffer. |
| (Option A) | commented | Uncomment the CW-tone block and comment out the LFM block to switch waveform. |

---

## Output: `pipeline_output.csv`

The final signal (`processed_sig`) is written one row per time sample:

| Column | Description |
|--------|-------------|
| `Sample` | Sample index (1…`num_samples`) |
| `Time_us` | Time in microseconds |
| `Ant1_I`, `Ant1_Q` | In-phase / quadrature for antenna 1 |
| `Ant2_I`, `Ant2_Q` | … antenna 2 |
| … | … one I/Q pair per antenna element |

So with 4 elements the file has `2 + 2*4 = 10` columns.

---

## Figures

1. **Geometry (3D)** — true-scale scene (emitter on the ground, receiver array at
   altitude) plus a **zoomed inset** showing the individual array elements at λ/2 spacing.
2. **Signal chain** — the received chirp, after superheterodyne downconversion, and
   after ADC quantization, each with its magnitude envelope shaded.
3. **Inter-element phase shift** — all antenna signals overlaid to visualize the
   phase progression caused by the angle of arrival.

> The plotting sets the LaTeX text interpreter as a session-wide default
> (`set(groot, ...)`); it persists until you restart MATLAB.

---

## Notes / archive

Earlier planning and debugging notes have been moved to the `archive/` folder,
which is git-ignored (see [`.gitignore`](.gitignore)).
