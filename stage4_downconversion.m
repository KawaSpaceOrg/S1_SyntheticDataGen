function [if_sig, t] = stage4_downconversion(rx_sig, fs, f_if)
    % STAGE 4: Down conversion (Baseband Equivalent to IF)
    % Physically, the 10 GHz RF is mixed with a 9.82 GHz LO.
    % The F_rf + F_lo (19.82 GHz) sum is removed by the analog low-pass filter.
    % The F_rf - F_lo (180 MHz) difference is the Intermediate Frequency (IF).
    % Since our Fs is 400 MHz, we mathematically shift the baseband signal
    % directly to 180 MHz to reproduce the final filtered IF output that the
    % ADC actually sees.
    %
    % NOTE: the output is REAL (it is a physical voltage). A real signal has no
    % quadrature component, so Q = 0 at this point -- that is correct for a real
    % IF-sampling ADC. The complex I/Q is reconstructed later by the digital
    % down-converter (DDC) in Stage 6, which is what a real SDR stores.

    N = size(rx_sig, 1);
    t = (0:N-1)' / fs;

    % Shift every antenna's baseband signal up to the 180 MHz IF and take the
    % real part (the physical voltage entering the ADC). Processing all columns
    % (instead of duplicating antenna 1) preserves the inter-element phase shift
    % so the saved I/Q remains usable for AoA / beamforming.
    % exp(...) is [N x 1] and broadcasts across the antenna columns of rx_sig.
    if_sig = real(rx_sig .* exp(1j * 2 * pi * f_if * t));

    fprintf('Stage 4: Downconversion. Mixer + LPF output at IF = %.1f MHz (%d channels, real).\n', ...
        f_if/1e6, size(rx_sig, 2));
end
