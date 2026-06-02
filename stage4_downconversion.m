function if_sig = stage4_downconversion(rx_sig, fs, f_if, image_reject_db)
    % STAGE 4: Down conversion
    % Highlight: Superheterodyne (translate RF to a non-zero Intermediate Freq.)

    % Defaults so the stage can be called with just (rx_sig, fs)
    if nargin < 3 || isempty(f_if),           f_if = 1e6;           end  % 1 MHz IF
    if nargin < 4 || isempty(image_reject_db), image_reject_db = 30; end  % 30 dB IRR

    N = size(rx_sig, 1);
    t = (0:N-1)' / fs;

    % A superheterodyne receiver mixes the incoming signal down to a FIXED,
    % non-zero Intermediate Frequency (IF) instead of all the way to 0 Hz.
    % Because the signal never sits at DC, this architecture does NOT suffer
    % the LO-leakage / DC-offset problem of a direct-conversion receiver.
    lo = exp(1j * 2 * pi * f_if * t);     % complex LO placing the signal at +f_if
    if_sig = rx_sig .* lo;

    % The classic impairment of the superheterodyne architecture is the IMAGE
    % frequency: any energy on the opposite side of the LO folds on top of the
    % wanted signal. A real RF/IF filter only partially suppresses it, set by the
    % Image-Rejection Ratio (IRR). We model the residual image as a weak,
    % spectrally-mirrored (conjugated) copy of the signal at -f_if.
    irr = 10^(-image_reject_db / 20);
    image_sig = irr * conj(rx_sig) .* exp(-1j * 2 * pi * f_if * t);
    if_sig = if_sig + image_sig;

    fprintf('Stage 4: Superheterodyne down conversion. IF = %.2f MHz, Image rejection = %.0f dB.\n', ...
        f_if/1e6, image_reject_db);
end
