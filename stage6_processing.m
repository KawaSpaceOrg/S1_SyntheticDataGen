function [iq_baseband, fs_out, t_out] = stage6_processing(adc_sig, fs, f_if, decim, ntaps, fcut_scale)
    % STAGE 6: Digital Down-Conversion (DDC) -- the SDR's stored product
    %
    % A real IF-sampling SDR does NOT write the raw IF samples to disk. Inside
    % the FPGA it mixes the real ADC stream with a numerically-controlled
    % oscillator (NCO, i.e. a complex cos + sin), low-pass filters, and
    % decimates. The result is COMPLEX BASEBAND I/Q at a reduced rate -- exactly
    % what lands in a .iq / .dat recording.
    %
    % This stage is also where the quadrature (Q) channel comes back to life:
    % the real ADC stream alone has Q = 0; the complex NCO mix regenerates it.

    [N, ~] = size(adc_sig);
    t = (0:N-1)' / fs;

    % 1) NCO mix-down from the IF to baseband. Multiplying the real ADC stream
    %    by a complex exponential produces a complex (I + jQ) signal:
    %      - the wanted band at +f_if  -> moves to 0 Hz (baseband)
    %      - the mirror band at -f_if  -> moves to a higher "image" frequency
    nco   = exp(-1j * 2 * pi * f_if * t);
    mixed = adc_sig .* nco;                 % [N x nch], implicit expansion

    % 2) Anti-image / anti-alias low-pass filter, applied BEFORE decimation.
    %    The wanted chirp sits near baseband; the mixing image sits well above
    %    it, so a cutoff a little below the new (post-decimation) Nyquist keeps
    %    the signal and rejects the image.
    fcut  = (fs / decim) / 2 * fcut_scale;         % cutoff just under the new Nyquist
    b     = fir1(ntaps, fcut / (fs/2));
    % Zero-phase filter I and Q separately so the I/Q timing stays aligned.
    mixed = filtfilt(b, 1, real(mixed)) + 1j * filtfilt(b, 1, imag(mixed));

    % 3) Decimate (keep every decim-th sample) -> realistic reduced storage rate.
    iq_baseband = mixed(1:decim:end, :);
    fs_out      = fs / decim;
    t_out       = (0:size(iq_baseband, 1) - 1)' / fs_out;

    fprintf(['Stage 6: DDC. Mixed IF->baseband, LPF (%.0f MHz), decimated x%d ', ...
             '-> Fs_out = %.0f MHz. Complex I/Q recovered (%d samples x %d ch).\n'], ...
        fcut/1e6, decim, fs_out/1e6, size(iq_baseband, 1), size(iq_baseband, 2));
end
