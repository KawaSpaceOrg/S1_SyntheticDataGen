% V1 Synthetic Data Generation Pipeline - Main Orchestrator
clear; clc; close all;

%% Read Parameters from parameters.txt
fileID = fopen('parameters.txt', 'r');
if fileID == -1
    error('Cannot open parameters.txt');
end
params = struct();
while ~feof(fileID)
    line = strtrim(fgetl(fileID));
    if isempty(line) || startsWith(line, '%')
        continue; % Skip empty lines and comments
    end
    parts = strsplit(line, '=');
    if length(parts) >= 2
        key = strtrim(parts{1});
        valStr = strtrim(parts{2});
        commentIdx = strfind(valStr, '%');
        if ~isempty(commentIdx)
            valStr = strtrim(valStr(1:commentIdx(1)-1));
        end
        params.(key) = str2double(valStr);
    end
end
fclose(fileID);

%% Global Simulation Parameters (Mapped from params)
fc = params.fc;
fs = params.fs;
num_samples = params.num_samples;
num_elements = params.num_elements;
f_tone = 1e6;         % Baseband CW tone frequency (1 MHz) - specific to Option A

%% Pipeline Execution

% Stage 0: Geometry
tx_pos = [params.tx_pos_x; params.tx_pos_y; params.tx_pos_z];
rx_pos = [params.rx_pos_x; params.rx_pos_y; params.rx_pos_z];
[tx_pos, rx_pos_center, rx_array] = stage0_geometry(fc, num_elements, tx_pos, rx_pos);

% Extract the actual 3D coordinates for all N array elements
rx_elem_pos = getElementPosition(rx_array);
rx_pos_all = rx_pos_center + rx_elem_pos;

% Stage 1: Waveform (Pulsed LFM Chirp)
[tx_sig, t] = stage1_waveform(f_tone, fs, num_samples, params.B, params.duty_cycle, params.pri_samples);

% Stage 2: Propagation Channel (Free Space Path Loss)
rx_sig = stage2_channel(tx_sig, tx_pos, rx_pos_all, fc, fs);

% Estimate received power to set a reasonable DC offset and ADC full scale
% Using (:) ensures we calculate the mean across all samples and all antenna elements, returning a scalar
rx_voltage_peak = max(abs(rx_sig(:)));


% Stage 4: Down Conversion (Baseband Equivalent to REAL 180 MHz IF)
[bb_sig, ~] = stage4_downconversion(rx_sig, fs, params.f_if);
f_if = params.f_if; % Map locally for subsequent functions

% Stage 5: ADC Modeling (14-bit Quantization of the real IF)
num_bits = params.num_bits;
% Set ADC full scale slightly above the signal peak (no DC offset in superhet)
full_scale_volts = rx_voltage_peak * 1.2;
adc_sig = stage5_adc(bb_sig, num_bits, full_scale_volts);

% Stage 6: Digital Down-Conversion (DDC) -> complex baseband I/Q (SDR product)
decim = params.decim;                                  % decimation factor (400 MHz -> 50 MHz)
[iq_sig, fs_iq, t_iq] = stage6_processing(adc_sig, fs, f_if, decim, params.ntaps, params.fcut_scale);

%% Export generated data to CSV (the SDR product: complex baseband I/Q)
% This is the decimated DDC output (Stage 6), sampled at fs_iq, NOT the raw IF.
% Columns: Sample, Time (us), then I/Q (real/imag) for each antenna element.
num_iq_samples = size(iq_sig, 1);
num_cols  = 2 + 2*num_elements;
out_mat   = zeros(num_iq_samples, num_cols);
var_names = cell(1, num_cols);
out_mat(:,1) = (1:num_iq_samples)';   var_names{1} = 'Sample';
out_mat(:,2) = t_iq*1e6;              var_names{2} = 'Time_us';
for el = 1:num_elements
    iCol = 2 + 2*el - 1;   qCol = 2 + 2*el;
    out_mat(:,iCol) = real(iq_sig(:,el));   var_names{iCol} = sprintf('Ant%d_I', el);
    out_mat(:,qCol) = imag(iq_sig(:,el));   var_names{qCol} = sprintf('Ant%d_Q', el);
end
csv_name = 'pipeline_output.csv';
writetable(array2table(out_mat, 'VariableNames', var_names), csv_name);
fprintf('Saved complex baseband I/Q (%d samples x %d antennas @ %.0f MHz) to %s\n', ...
    num_iq_samples, num_elements, fs_iq/1e6, csv_name);

%% Visualization

% ---- Global styling: LaTeX everywhere, large fonts, gray figure background ----
set(groot, 'defaultAxesTickLabelInterpreter', 'latex');
set(groot, 'defaultLegendInterpreter', 'latex');
set(groot, 'defaultTextInterpreter', 'latex');
ax_fs    = 15;                  % axis label / tick font size
ti_fs    = 17;                  % title font size
fig_gray = [0.88 0.88 0.90];    % light-gray figure background
ax_gray  = [0.97 0.97 0.97];    % near-white axes background

c = physconst('LightSpeed');
rx_center = mean(rx_pos_all, 2);
R = norm(tx_pos - rx_center);                 % Tx-Rx range (m)
prop_delay_samples = round(R / c * fs);       % bulk propagation delay (samples)

% ---- Figure 1: Scene Geometry with 3D Callout Zoom ----
f1 = figure('Name', 'Pipeline Geometry', 'Color', fig_gray, 'Position', [100 100 1000 700]);
ax1 = axes('Parent', f1, 'Color', ax_gray, 'FontSize', ax_fs); hold(ax1, 'on');

% drop-line from the receiver down to the ground plane (visual anchor)
plot3(ax1, [rx_center(1) rx_center(1)], [rx_center(2) rx_center(2)], [0 rx_center(3)], ...
    ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5);
% line of sight
plot3(ax1, [tx_pos(1) rx_center(1)], [tx_pos(2) rx_center(2)], [tx_pos(3) rx_center(3)], ...
    '--', 'Color', [0.85 0.33 0.10], 'LineWidth', 2.2);
% emitter
h_tx = plot3(ax1, tx_pos(1), tx_pos(2), tx_pos(3), '^', 'MarkerSize', 16, ...
    'MarkerFaceColor', [0.85 0.10 0.10], 'MarkerEdgeColor', 'k', 'LineWidth', 1.2);
% true receiver array (looks like one dot at this scale)
h_rx = plot3(ax1, rx_pos_all(1,:), rx_pos_all(2,:), rx_pos_all(3,:), 'o', 'MarkerSize', 6, ...
    'MarkerFaceColor', [0.10 0.30 0.85], 'MarkerEdgeColor', 'k', 'LineWidth', 1);

text(ax1, tx_pos(1), tx_pos(2), tx_pos(3)+500, '\textbf{Emitter}', 'FontSize', ax_fs, ...
    'HorizontalAlignment', 'center', 'Interpreter', 'latex');
text(ax1, rx_center(1), rx_center(2), rx_center(3)-400, '\textbf{Rx array (True Scale)}', 'FontSize', ax_fs, ...
    'HorizontalAlignment', 'center', 'Interpreter', 'latex');

% === 3D Callout (Magnifying Glass) for the Antenna Array ===
% We manually enlarge the array spacing so it is visible on the km scale.
zoom_scale = 100000; % Exaggerate spacing 100,000x for the callout
callout_z  = rx_center(3) + 2000; % Float it 2 km above the actual array
callout_x  = rx_center(1) + (rx_pos_all(1,:) - rx_center(1)) * zoom_scale;
callout_y  = zeros(1, num_elements);
callout_z_arr = ones(1, num_elements) * callout_z;

% Draw the callout connecting lines (magnifying effect)
plot3(ax1, [rx_center(1) callout_x(1)], [rx_center(2) callout_y(1)], [rx_center(3) callout_z_arr(1)], ...
    '-.', 'Color', [0.6 0.6 0.6], 'LineWidth', 1);
plot3(ax1, [rx_center(1) callout_x(end)], [rx_center(2) callout_y(end)], [rx_center(3) callout_z_arr(end)], ...
    '-.', 'Color', [0.6 0.6 0.6], 'LineWidth', 1);

% Draw the enlarged array axis
plot3(ax1, [callout_x(1) callout_x(end)], [callout_y(1) callout_y(end)], [callout_z callout_z], ...
    '-', 'Color', [0.10 0.30 0.85], 'LineWidth', 2);

% Draw the enlarged antenna elements
for k = 1:num_elements
    plot3(ax1, callout_x(k), callout_y(k), callout_z_arr(k), 'o', 'MarkerSize', 14, ...
        'MarkerFaceColor', [0.10 0.30 0.85], 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

    if k == 4
        % Ant 4 text below the dot to avoid collision with connecting lines
        text(ax1, callout_x(k), callout_y(k), callout_z_arr(k)-800, sprintf('Ant %d', k), ...
            'FontSize', ax_fs-2, 'HorizontalAlignment', 'center', 'Interpreter', 'latex');
    else
        % Ant 1, 2, 3 text above the dot
        text(ax1, callout_x(k), callout_y(k), callout_z_arr(k)+800, sprintf('Ant %d', k), ...
            'FontSize', ax_fs-2, 'HorizontalAlignment', 'center', 'Interpreter', 'latex');
    end
end

% Show physical distance between Ant 1 and Ant 2
lambda_cm = (c / fc) * 100;
dist_cm = lambda_cm / 2;
x_mid = (callout_x(1) + callout_x(2)) / 2;
% Draw a small visual indicator for the distance
plot3(ax1, [callout_x(1) callout_x(2)], [0 0], [callout_z-400 callout_z-400], '-', 'Color', [0.4 0.4 0.4]);
text(ax1, x_mid, 0, callout_z - 700, sprintf('$d = %.1f$ cm', dist_cm), ...
    'FontSize', ax_fs-2, 'HorizontalAlignment', 'center', 'Color', [0.2 0.2 0.2], 'Interpreter', 'latex');

% Place text near Ant 1 on the left, as shown in the user's uploaded image layout
text(ax1, callout_x(1) - 3000, 0, callout_z - 500, '\textbf{Enlarged Array Layout}', ...
    'FontSize', ax_fs+2, 'HorizontalAlignment', 'center', 'Interpreter', 'latex', 'Color', [0.10 0.30 0.85]);

title(ax1, '\textbf{3D Scene Geometry \& Array Orientation}', 'FontSize', ti_fs, 'Interpreter', 'latex');
xlabel(ax1, '$X$ (m)', 'FontSize', ax_fs, 'Interpreter', 'latex');
ylabel(ax1, '$Y$ (m)', 'FontSize', ax_fs, 'Interpreter', 'latex');
zlabel(ax1, '$Z$ (m)', 'FontSize', ax_fs, 'Interpreter', 'latex');
legend(ax1, [h_tx h_rx], {'Emitter (Tx)', 'Receiver array (Rx)'}, 'Location', 'west', 'FontSize', ax_fs, 'Interpreter', 'latex');
grid(ax1, 'on'); box(ax1, 'on'); view(ax1, -30, 20); axis(ax1, 'tight');
%%
% ---- Figure 2: Signal Evolution (Tx -> RF -> Rx Channel) ----
f2 = figure('Name', 'Signal Evolution', 'Color', fig_gray, 'Position', [140 40 1200 900]);

%% Subplot 1: Baseband Chirp & 10 GHz Carrier (Dual X-Axes)
ax1_bottom = subplot(3,1,1, 'Parent', f2, 'Color', ax_gray, 'FontSize', ax_fs); hold(ax1_bottom, 'on');
zoom_len = min(round(2e-6 * fs), length(tx_sig));
t_zoom = t(1:zoom_len)*1e6;
color_chirp = [0.1 0.4 0.8];
color_carrier = [0.85 0.33 0.10 0.4]; % Faded carrier line using alpha

% Plot Baseband Chirp on Bottom X-Axis
plot(ax1_bottom, t_zoom, real(tx_sig(1:zoom_len)), 'Color', color_chirp, 'LineWidth', 1.5); % Original line width
xlabel(ax1_bottom, 'Time ($\mu$s) - Baseband Chirp', 'FontSize', ax_fs, 'Interpreter', 'latex', 'Color', color_chirp);
ylabel(ax1_bottom, 'Amplitude', 'FontSize', ax_fs, 'Interpreter', 'latex');
set(ax1_bottom, 'XColor', color_chirp, 'YColor', [0.15 0.15 0.15], 'ActivePositionProperty', 'position');
ylim(ax1_bottom, [-1.2 1.2]);
grid(ax1_bottom, 'on'); box(ax1_bottom, 'off');

% Force the bottom axis to explicitly lock its position, shrinking it slightly
% to guarantee the top title doesn't clip off the window
drawnow;
pos = ax1_bottom.Position;
pos(2) = pos(2) - 0.03;  % Move down slightly
pos(4) = pos(4) - 0.05;  % Shrink height slightly
ax1_bottom.Position = pos;

% Create Top X-Axis identically locked over the bottom axis
ax1_top = axes('Position', pos, 'XAxisLocation', 'top', ...
    'YAxisLocation', 'right', 'Color', 'none', 'FontSize', ax_fs);
hold(ax1_top, 'on');
% Generate 0.01 microseconds of 10 GHz carrier mathematically
t_carrier = linspace(0, 0.01e-6, 1000);
plot(ax1_top, t_carrier*1e9, cos(2*pi*fc*t_carrier), 'Color', color_carrier, 'LineWidth', 1.0); % Thinner/faded line
xlabel(ax1_top, 'Time (ns) - 10 GHz Carrier', 'FontSize', ax_fs, 'Interpreter', 'latex', 'Color', color_carrier(1:3));
% Use YColor to draw the right side of the box, but without ticks
set(ax1_top, 'XColor', color_carrier(1:3), 'YColor', [0.15 0.15 0.15], 'YTick', [], 'ActivePositionProperty', 'position');
ylim(ax1_top, [-1.2 1.2]);

% Add empty strings BELOW the title to push the main text UP, away from the top X-axis labels
title(ax1_top, {'\textbf{1. Transmitter: Baseband Chirp (Bottom Axis) vs 10 GHz Carrier (Top Axis)}', '', ''}, ...
    'FontSize', ti_fs, 'Interpreter', 'latex');

%% Subplot 2: Combined Signal (High-Frequency Visualization)
ax2 = subplot(3,1,2, 'Parent', f2, 'Color', ax_gray, 'FontSize', ax_fs); hold(ax2, 'on');
% To visually show the carrier combining with the chirp, we must use a very high
% mathematical sample rate (e.g. 40 GHz) so the 10 GHz carrier isn't aliased.
fs_high = 40e9;
t_high = (0:round(2e-6 * fs_high))' / fs_high;
k_chirp = params.B / (params.duty_cycle * params.pri_samples / fs);
% True complex baseband envelope:
baseband_high = exp(1j*2*pi*(0.5 * k_chirp * t_high.^2));
% The RF passband signal (envelope * carrier):
rf_high = real(baseband_high .* exp(1j*2*pi*fc*t_high));

plot(ax2, t_high*1e6, rf_high, 'Color', [0.85 0.33 0.10], 'LineWidth', 0.5);
% Overlay the pure In-Phase baseband component to show the underlying low-frequency chirp.
% (Note: A chirp is Frequency Modulated, so its physical amplitude envelope is a flat line at 1.0. 
% The RF signal breaks outside the In-Phase curve whenever the Quadrature (Q) component carries energy).
plot(ax2, t_high*1e6, real(baseband_high), '-', 'Color', [0.1 0.4 0.8], 'LineWidth', 1.5);
% Add an empty string ABOVE the title to push it DOWN, away from Plot 1's X-axis label
title(ax2, {'', '\textbf{2. Passband: Upconverted to 10 GHz Carrier (Zoomed to 0.3 $\mu$s)}'}, 'FontSize', ti_fs, 'Interpreter', 'latex');
xlabel(ax2, 'Time ($\mu$s)', 'FontSize', ax_fs, 'Interpreter', 'latex');
ylabel(ax2, 'Amplitude', 'FontSize', ax_fs, 'Interpreter', 'latex');
xlim(ax2, [0, 0.3]); % Set requested x-limit
grid(ax2, 'on'); box(ax2, 'on');

%% Subplot 3: Delayed & Attenuated Rx Signal (Post-Stage 2)
ax3 = subplot(3,1,3, 'Parent', f2, 'Color', ax_gray, 'FontSize', ax_fs); hold(ax3, 'on');
arrival_idx = prop_delay_samples;
plot_idx = arrival_idx : min(arrival_idx + round(2e-6 * fs), num_samples);
colors = lines(num_elements);
for el = 1:num_elements
    plot(ax3, t(plot_idx)*1e6, real(rx_sig(plot_idx, el)), 'Color', colors(el,:), 'LineWidth', 1.5, ...
        'DisplayName', sprintf('Antenna %d', el));
end
fspl_db = fspl(R, physconst('LightSpeed')/fc);
% Add an empty string ABOVE the title to push it DOWN, away from Plot 2's X-axis label
title(ax3, {'', sprintf('\\textbf{3. Receiver: Array Output (Delayed by %.1f $\\mu$s, FSPL = %.1f dB)}', ...
    (arrival_idx/fs)*1e6, fspl_db)}, 'FontSize', ti_fs, 'Interpreter', 'latex');
xlabel(ax3, 'Time ($\mu$s)', 'FontSize', ax_fs, 'Interpreter', 'latex');
ylabel(ax3, 'Amplitude (V)', 'FontSize', ax_fs, 'Interpreter', 'latex');
xlim(ax3, [23.5, 24.6]); % Set requested x-limit
legend(ax3, 'Location', 'northeast', 'FontSize', ax_fs-2, 'Interpreter', 'latex');
grid(ax3, 'on'); box(ax3, 'on');

% ---- Figure 3: Inter-element phase shift in the ACQUIRED signal ----
f3 = figure('Name', 'Inter-element Phase (Phasor)', 'Color', fig_gray, 'Position', [200 120 750 650]);
ax3 = polaraxes('Parent', f3, 'Color', ax_gray, 'FontSize', ax_fs); hold(ax3, 'on');

% The complex baseband equivalent (rx_sig) strictly generated by Stage 2 natively holds the array's phase state!
idx_ph = prop_delay_samples + 10; % Pick a sample where the pulse has arrived and amplitude is non-zero
raw_phasors = rx_sig(idx_ph, :);

% Rotate all phasors so that Antenna 1 is the 0-degree reference, making the massive phase shifts easily visible!
ref_angle = angle(raw_phasors(1));
phasors = raw_phasors .* exp(-1j * ref_angle);

% The center reference phasor is physically and mathematically the mean of the symmetrically spaced elements
center_phasor = mean(phasors);

cmap = lines(num_elements);
h_ph = gobjects(num_elements + 1, 1);

% Draw Phasors as vectors in polar coordinates
for el = 1:num_elements
    ang = angle(phasors(el));
    mag = abs(phasors(el));
    h_ph(el) = polarplot(ax3, [0, ang], [0, mag], '-o', 'Color', cmap(el,:), 'LineWidth', 2, 'MarkerFaceColor', cmap(el,:), 'MarkerSize', 8, 'DisplayName', sprintf('Antenna %d', el));

    % Add a floating text label showing the exact angle in degrees
    ang_deg = rad2deg(ang);
    text(ax3, ang, mag * 1.15, sprintf('%.0f^{\\circ}', ang_deg), 'FontSize', ax_fs+2, 'Color', cmap(el,:), 'Interpreter', 'tex', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
end

% Draw Center Reference
h_ph(end) = polarplot(ax3, [0, angle(center_phasor)], [0, abs(center_phasor)], '--d', 'Color', 'k', 'LineWidth', 2.5, 'MarkerFaceColor', 'k', 'MarkerSize', 10, 'DisplayName', 'Array Center (Ref)');
% Add text label for the center reference
text(ax3, angle(center_phasor), abs(center_phasor) * 1.5, sprintf('%.0f^{\\circ}', rad2deg(angle(center_phasor))), 'FontSize', ax_fs+2, 'Color', 'k', 'Interpreter', 'tex', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');

% Expand the radial limits slightly so the text doesn't hit the edge of the plot
rlim(ax3, [0, max(abs(phasors)) * 1.3]);

title(ax3, '\textbf{Phasor Representation of Array Signals} (Relative to Ant 1)', 'FontSize', ti_fs, 'Interpreter', 'latex');
legend(ax3, h_ph, 'Location', 'northeastoutside', 'FontSize', ax_fs, 'Interpreter', 'latex');
grid(ax3, 'on');

% ---- Figure 4: Visual Envelope vs True Frequency (IF Verification) ----
f4 = figure('Name', 'IF Signal Verification', 'Color', fig_gray, 'Position', [200 150 900 700]);

% Extract the last 501 samples of Antenna 1's IF and ADC signals
idx_tail = (size(bb_sig, 1) - 500) : size(bb_sig, 1);
sig_if = bb_sig(idx_tail, 1);
sig_adc = adc_sig(idx_tail, 1);

% Plot 1: Time Domain (Analog vs Digital)
ax4_1 = subplot(2,1,1, 'Parent', f4, 'Color', ax_gray, 'FontSize', ax_fs); hold(ax4_1, 'on');

% Plot Analog signal very thick so it acts as a highly visible background path
plot(ax4_1, t(idx_tail)*1e6, sig_if, 'Color', [0.85 0.33 0.10], 'LineWidth', 4, 'DisplayName', 'Analog IF (\texttt{bb\_sig})');

% Plot Digital signal thin on top so we can see it perfectly hugging the analog path
plot(ax4_1, t(idx_tail)*1e6, sig_adc, 'Color', [0 0.45 0.74], 'LineWidth', 1.2, 'DisplayName', '14-bit ADC (\texttt{adc\_sig})');

title(ax4_1, sprintf('\\textbf{1. Time Domain: Downconverted from %.1f GHz to %.0f MHz}', fc/1e9, f_if/1e6), 'Interpreter', 'latex', 'FontSize', ti_fs);
xlabel(ax4_1, 'Time ($\mu$s)', 'Interpreter', 'latex', 'FontSize', ax_fs);
ylabel(ax4_1, 'Amplitude (V)', 'Interpreter', 'latex', 'FontSize', ax_fs);
legend(ax4_1, 'Location', 'best', 'Interpreter', 'latex', 'FontSize', ax_fs-2);
grid(ax4_1, 'on'); box(ax4_1, 'on');

% Plot 2: Frequency Domain (The True Physics)
ax4_2 = subplot(2,1,2, 'Parent', f4, 'Color', ax_gray, 'FontSize', ax_fs);
spectrogram(sig_if, hamming(64), 60, 512, fs, 'yaxis');
title(ax4_2, '\textbf{2. Spectrogram: True Frequency sweeps UPWARDS}', 'Interpreter', 'latex', 'FontSize', ti_fs);

% ---- Figure 5: Spectrograms (emitted -> downconverted -> acquired) ----
% Time-frequency view of how the energy moves DOWN in frequency through the
% chain. Panel 1's frequency axis is offset by the carrier (fc + baseband), so
% the emission shows around 10 GHz; panels 2-3 show the 180 MHz IF.
figure('Name', 'Spectrogram Analysis', 'Color', fig_gray, 'Position', [220 80 1050 920]);

win_len   = 48;                % samples per STFT window
noverlap  = 44;                % overlap (samples)
nfft      = 256;               % FFT length (frequency bins)
dyn_range = 60;                % dB displayed below the global peak

win_tx    = 1:1024; % 1024 samples of the emitted pulse starting at t=0
win_rx    = prop_delay_samples + (1:1024); % window where pulse has arrived at the receiver
spec_sigs = {tx_sig(win_tx,1), bb_sig(win_rx,1), adc_sig(win_rx,1)};
t_offsets = [0, t(win_rx(1)), t(win_rx(1))]; % Physical start time of the window
f_off     = [fc, 0, 0];          % frequency-axis offset per panel (carrier for panel 1)
f_scl     = [1e9, 1e6, 1e6];     % display unit scale (GHz, MHz, MHz)
f_unit    = {'GHz', 'MHz', 'MHz'};
spec_titles = {'\textbf{1. Emitted RF Pulse} (Upconverted to 10 GHz)', ...
    sprintf('\\textbf{2. Downconverted IF} (%.0f MHz, Received after %.1f $\\mu$s delay)', f_if/1e6, t(win_rx(1))*1e6), ...
    sprintf('\\textbf{3. Acquired Digital Data} (%d-bit ADC)', num_bits)};

% Compute spectrograms
S_all = cell(1,3); F_all = cell(1,3); T_all = cell(1,3);
for s = 1:3
    [S, F, Tsec] = spectrogram(spec_sigs{s}, hamming(win_len), noverlap, nfft, fs, 'centered');
    T_all{s} = Tsec + t_offsets(s);        % shift to physical arrival time
    S_all{s} = 20*log10(abs(S) + eps);     % +eps keeps the silent gaps finite
    F_all{s} = F;
end

try                              % use the turbo colormap if available
    cmap_spec = turbo(256);
catch
    cmap_spec = jet(256);
end

for s = 1:3
    ax = subplot(3,1,s); set(ax, 'Color', ax_gray, 'FontSize', ax_fs);
    imagesc(ax, T_all{s}*1e6, (f_off(s) + F_all{s})/f_scl(s), S_all{s});
    axis(ax, 'xy');

    % Use independent clim for each plot since the Tx signal is ~130 dB stronger than the Rx signal
    s_max = max(S_all{s}(:));
    clim(ax, [s_max - dyn_range, s_max]);

    colormap(ax, cmap_spec);
    cb = colorbar(ax); cb.Label.String = 'Power (dB)'; cb.Label.FontSize = ax_fs-2;
    title(ax, spec_titles{s}, 'FontSize', ti_fs, 'Interpreter', 'latex');
    ylabel(ax, sprintf('Frequency (%s)', f_unit{s}), 'FontSize', ax_fs, 'Interpreter', 'latex');

    if s == 1
        yline(ax, fc/1e9, '--w', sprintf('%.0f GHz', fc/1e9), 'LineWidth', 1.2);
    else
        ylim(ax, [0, (fs/2)/1e6]); % Only display positive frequencies for real signals
        yline(ax, f_if/1e6, '--w', sprintf('IF %.0f MHz', f_if/1e6), ...
            'LineWidth', 1.2, 'LabelHorizontalAlignment', 'left');
        yline(ax,  fs/2e6, ':w', 'Nyquist', 'LineWidth', 1.0);
    end
    if s == 3
        xlabel(ax, 'Time ($\mu$s)', 'FontSize', ax_fs, 'Interpreter', 'latex');
    end
end

disp('Pipeline execution complete. Review Figures 1-5 + pipeline_output.csv.');
