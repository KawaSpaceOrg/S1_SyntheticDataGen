# S1 — Synthetic RF Data Generation Pipeline (MATLAB)

A modular, highly accurate MATLAB pipeline that synthesizes the baseband I/Q data a phased-array receiver would record from a single distant emitter. It physically models the full electromagnetic and hardware chain:
**Geometry → Waveform → Free-Space Propagation → Downconversion (Mixer) → ADC Quantization → Digital Down Conversion (DDC)**.

Requires the **Phased Array System Toolbox** (`phased.ULA`, `phased.FreeSpace`, `physconst`, `fspl`).

---

## How to run

1. Open MATLAB in this folder (`S1_SyntheticDataGen`).
2. Run the orchestrator script:
   ```matlab
   main_pipeline
   ```
3. The pipeline generates **5 detailed verification figures** and exports the final SDR data to **`pipeline_output.csv`**.

---

## Pipeline Stages & Files

Every function is modular and models a specific piece of physical radar hardware or real-world physics.

| Stage | File | Role & Parameters |
|-------|------|--------------|
| **Orchestrator** | [`main_pipeline.m`](main_pipeline.m) | Defines all global parameters (e.g., `fc`, `fs`, `num_samples`), calls every stage in order, mathematically generates the verification plots, and exports the final CSV. |
| **0 — Geometry** | [`stage0_geometry.m`](stage0_geometry.m) | Places the ground **emitter** and the airborne **receiver array**, and builds a Uniform Linear Array (ULA). |
| **1 — Waveform** | [`stage1_waveform.m`](stage1_waveform.m) | Generates the transmitted signal. Currently configured as a **pulsed Linear-FM (LFM) chirp** with a 50% duty cycle. The output is an **Analytic (Complex) Baseband** signal, which is required for the propagation phase math to work correctly. |
| **2 — Channel** | [`stage2_channel.m`](stage2_channel.m) | Applies **Free-Space Propagation** using `phased.FreeSpace`. It physically delays the pulse by the Time-of-Flight (R/c), attenuates the amplitude perfectly matching the Free Space Path Loss (FSPL) equation, and applies the microscopic inter-element Angle-of-Arrival phase shifts across the array. Output is Complex Baseband. |
| **4 — Downconversion** | [`stage4_downconversion.m`](stage4_downconversion.m) | Models the analog hardware mixer. It mathematically shifts the complex baseband signal up to the **150 MHz Intermediate Frequency (IF)**. Crucially, it takes the `real()` part of the signal, because a physical antenna and copper wire can only carry a single, real voltage. |
| **5 — ADC** | [`stage5_adc.m`](stage5_adc.m) | Models an **IF-Sampling ADC**. It takes the pure Real analog IF voltage, strictly clips it to the physical full-scale input bounds of the chip, and quantizes it into `num_bits` (14-bit) discrete steps. |
| **6 — DDC** | [`stage6_processing.m`](stage6_processing.m) | Models the **Digital Down-Converter** FPGA chip. It multiplies the real digital IF stream by a Complex Numerically Controlled Oscillator (NCO) to drop the signal down to 0 Hz (Baseband) and resurrect the invisible Quadrature (Q) component. It then applies an anti-image low-pass filter and decimates (downsamples) the signal by 8x (to 50 MHz) to save storage space. |

> Note: There is intentionally no Stage 3 to preserve legacy numbering architecture.

---

## Output: `pipeline_output.csv`

The saved signal is the **DDC output** — complex baseband I/Q at the decimated rate (`50 MHz`), which is exactly what a real SDR writes to a `.iq` recording file. 

| Column | Description |
|--------|-------------|
| `Sample` | Sample index (1…`num_iq_samples`) |
| `Time_us` | Time in microseconds (on the decimated grid) |
| `Ant1_I`, `Ant1_Q` | In-Phase / Quadrature for antenna 1 |
| `Ant2_I`, `Ant2_Q` | … antenna 2 |
| … | … one I/Q pair per antenna element |

With 4 elements, the file has 10 columns. Because the mixer and ADC process all array channels simultaneously, the microscopic Angle-of-Arrival phase shifts survive perfectly into the saved I/Q data, making it ready for beamforming.

---

## Global Parameters (`parameters.txt`)

You can edit these directly to change the pipeline's behavior:
* `fc = 10e9`: 10 GHz Carrier frequency.
* `fs = 400e6`: 400 MHz ADC Sample Rate.
* `f_if = 150e6`: 150 MHz Intermediate Frequency. (Kept safely away from the 200 MHz Nyquist limit to prevent extreme optical aliasing).
* `num_bits = 14`: ADC resolution. **(Tip: Drop this to 4 to see massive blocky quantization staircases in Figure 4!)**
* `decim = 8`: The DDC downsampling factor.

---

## Verification Figures

The pipeline plots 5 figures to mathematically prove the signal physics at every stage:

1. **Geometry (3D)**: True-scale scene of the emitter (ground) and receiver array (20km altitude), plus a zoomed inset showing the individual array elements at λ/2 spacing.
2. **Signal Evolution (Time Domain)**: 
   - *Panel 1*: Baseband Chirp vs the 10 GHz Carrier.
   - *Panel 2*: Passband Upconverted to 10 GHz, with an In-Phase baseband overlay. Because a chirp is Frequency Modulated (FM), its amplitude is constant, and the RF physically breaks outside the In-Phase curve when the Q component carries energy.
   - *Panel 3*: Receiver Array Output. Proves the pulse is delayed exactly by the Time-of-Flight and mathematically attenuated perfectly matching the FSPL (129.4 dB drop).
3. **Phasor Representation**: A Polar plot that rotates Antenna 1 to exactly 0°. This dramatically exposes the massive inter-element Angle-of-Arrival phase shifts caused by the λ/2 spacing at a 45-degree incidence angle.
4. **IF Signal Verification (Analog vs Digital)**: 
   - *Panel 1*: Overlays the 14-bit digital ADC signal on top of the bold analog IF signal. Also demonstrates the famous DSP "Optical Illusion" where the digital points beating against the Nyquist frequency visually creates an envelope that looks like a time-reversed down-chirp.
   - *Panel 2*: A mathematical Spectrogram of the exact same signal, unequivocally proving that the true physical frequency is sloping UPWARDS (150 MHz up to 170 MHz), dismantling the visual illusion.
5. **Spectrogram Analysis**: Three panels tracing the signal's energy stepping down the chain: Emitted (10 GHz) → Downconverted IF (150 MHz) → Acquired Post-ADC.
