function [tx_sig, t] = stage1_waveform(f_tone, fs, num_samples, B, duty_cycle, pri_samples)
    % STAGE 1: Waveform to use
    % Highlight: Continuous Wave Tone
    
    % Create time vector
    t = (0:num_samples-1)' / fs;

    % --- Option A: Continuous Wave (CW) Tone ---
    % We generate it at a specific baseband frequency (f_tone)
    % so it is distinguishable from DC (0 Hz).
    % Real signal: tx_sig = cos(2 * pi * f_tone * t);
    % (I/Q decomposition happens at the output/CSV export stage, not here)
    %
    % fprintf('Stage 1: CW Tone generated at %.2f MHz.\n', f_tone/1e6);

    % --- Option B: Pulsed Linear Frequency Modulated (LFM) Chirp ---
    % A pulsed LFM waveform that is "on" for a fraction (duty cycle) of each
    % Pulse Repetition Interval (PRI) and "off" (zero) for the remainder.
    %
    % Bandwidth is chosen for the fixed RF/LO/Fs inputs: the signal later
    % occupies [IF, IF + B] MHz after upconversion to the 180 MHz IF
    % (10 GHz - 9.82 GHz), so the band is [180, 200] MHz — just inside the
    % Nyquist limit of 200 MHz for Fs = 400 MHz.
    pw_samples  = round(duty_cycle * pri_samples); % Pulse width (active samples)

    % Build one baseband LFM pulse sweeping from 0 Hz up to B.
    % Baseband equivalent chirp MUST be an analytic (complex) signal so that 
    % the phase shift in the channel model correctly delays the envelope rather 
    % than just scaling the real part!
    tp = (0:pw_samples-1)' / fs;            % Time within a single pulse (s)
    k  = B / (pw_samples / fs);             % Chirp rate (Hz/s)
    pulse = exp(1j * 2 * pi * (0.5 * k * tp.^2));  % f sweeps: 0 → B

    % Tile the pulse across the buffer at the chosen PRI (zeros fill the gaps)
    tx_sig = zeros(num_samples, 1);
    for start_idx = 1:pri_samples:num_samples
        idx = start_idx:min(start_idx + pw_samples - 1, num_samples);
        tx_sig(idx) = pulse(1:numel(idx));
    end

    fprintf('Stage 1: Pulsed LFM Chirp generated. BW = %.2f MHz, Duty Cycle = %.0f%%, PRI = %d samples.\n', ...
        B/1e6, duty_cycle*100, pri_samples);
end
