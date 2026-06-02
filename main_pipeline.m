% V1 Synthetic Data Generation Pipeline - Main Orchestrator
clear; clc; close all;

%% Global Simulation Parameters
fc = 2.4e9;           % Carrier Frequency (2.4 GHz)
fs = 10e6;            % Sample Rate (10 MSps)
num_samples = 1024;   % Number of samples to simulate
f_tone = 1e6;         % Baseband CW tone frequency (1 MHz)
num_elements = 4;     % Number of antenna array elements

%% Pipeline Execution

% Stage 0: Geometry
[tx_pos, rx_pos_center, rx_array] = stage0_geometry(fc, num_elements);

% Extract the actual 3D coordinates for all N array elements
rx_elem_pos = getElementPosition(rx_array);
rx_pos_all = rx_pos_center + rx_elem_pos;

% Stage 1: Waveform (Pulsed LFM Chirp)
[tx_sig, t] = stage1_waveform(f_tone, fs, num_samples);

% Stage 2: Propagation Channel (Free Space Path Loss)
rx_sig = stage2_channel(tx_sig, tx_pos, rx_pos_all, fc, fs);

    % Estimate received power to set a reasonable DC offset and ADC full scale
    % Using (:) ensures we calculate the mean across all samples and all antenna elements, returning a scalar
    rx_power = mean(abs(rx_sig(:)).^2);
rx_voltage_peak = sqrt(rx_power) * sqrt(2);

% Stage 4: Down Conversion (Superheterodyne to a non-zero IF)
f_if = 1e6;            % Intermediate Frequency (1 MHz)
image_reject_db = 30;  % Image-rejection ratio of the IF filter (dB)
bb_sig = stage4_downconversion(rx_sig, fs, f_if, image_reject_db);

% Stage 5: ADC Modeling (14-bit Quantization)
num_bits = 14;
% Set ADC full scale slightly above the signal peak (no DC offset in superhet)
full_scale_volts = rx_voltage_peak * 1.2;
adc_sig = stage5_adc(bb_sig, num_bits, full_scale_volts);

% Stage 6: Processing (DC Removal)
processed_sig = stage6_processing(adc_sig);

%% Export generated data to CSV
% Columns: Sample, Time (us), then I/Q (real/imag) for each antenna element.
num_cols  = 2 + 2*num_elements;
out_mat   = zeros(num_samples, num_cols);
var_names = cell(1, num_cols);
out_mat(:,1) = (1:num_samples)';   var_names{1} = 'Sample';
out_mat(:,2) = t*1e6;              var_names{2} = 'Time_us';
for el = 1:num_elements
    iCol = 2 + 2*el - 1;   qCol = 2 + 2*el;
    out_mat(:,iCol) = real(processed_sig(:,el));   var_names{iCol} = sprintf('Ant%d_I', el);
    out_mat(:,qCol) = imag(processed_sig(:,el));   var_names{qCol} = sprintf('Ant%d_Q', el);
end
csv_name = 'pipeline_output.csv';
writetable(array2table(out_mat, 'VariableNames', var_names), csv_name);
fprintf('Saved final signal (%d samples x %d antennas, I/Q) to %s\n', ...
    num_samples, num_elements, csv_name);

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

% ---- Figure 1: Scene Geometry in 3D (Emitter + Receiver array together) ----
f1 = figure('Name', 'Pipeline Geometry (3D)', 'Color', fig_gray, 'Position', [100 100 860 660]);
ax = axes('Parent', f1, 'Color', ax_gray, 'FontSize', ax_fs); hold(ax, 'on');

% drop-line from the receiver down to the ground plane (visual anchor)
plot3([rx_center(1) rx_center(1)], [rx_center(2) rx_center(2)], [0 rx_center(3)], ...
    ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5);
% line of sight
plot3([tx_pos(1) rx_center(1)], [tx_pos(2) rx_center(2)], [tx_pos(3) rx_center(3)], ...
    '--', 'Color', [0.85 0.33 0.10], 'LineWidth', 2.2);
% emitter and receiver array
h_tx = plot3(tx_pos(1), tx_pos(2), tx_pos(3), '^', 'MarkerSize', 16, ...
    'MarkerFaceColor', [0.85 0.10 0.10], 'MarkerEdgeColor', 'k', 'LineWidth', 1.2);
h_rx = plot3(rx_pos_all(1,:), rx_pos_all(2,:), rx_pos_all(3,:), 'o', 'MarkerSize', 9, ...
    'MarkerFaceColor', [0.10 0.30 0.85], 'MarkerEdgeColor', 'k', 'LineWidth', 1.2);

text(tx_pos(1), tx_pos(2), tx_pos(3)+1500, '\textbf{Emitter}', 'FontSize', ax_fs, ...
    'HorizontalAlignment', 'center');
text(rx_center(1), rx_center(2), rx_center(3)+1500, '\textbf{Rx array}', 'FontSize', ax_fs, ...
    'HorizontalAlignment', 'center');
text(mean([tx_pos(1) rx_center(1)]), mean([tx_pos(2) rx_center(2)]), mean([tx_pos(3) rx_center(3)]), ...
    sprintf('$R = %.1f$ km', R/1e3), 'FontSize', ax_fs, 'Color', [0.85 0.33 0.10], ...
    'BackgroundColor', 'w', 'EdgeColor', [0.7 0.7 0.7]);

title('\textbf{Scene Geometry:} Emitter $\rightarrow$ Receiver Array', 'FontSize', ti_fs);
xlabel('$X$ (m)', 'FontSize', ax_fs); ylabel('$Y$ (m)', 'FontSize', ax_fs);
zlabel('$Z$ (m)', 'FontSize', ax_fs);
legend([h_tx h_rx], {'Emitter (Tx)', 'Receiver array (Rx)'}, 'Location', 'northwest', 'FontSize', ax_fs);
grid on; box on; view(40, 22); axis tight;

% Inset: zoom on the receive array so the 4 elements are individually visible.
% At 20 km range they collapse to a point in the main (true-scale) view, so we
% show them here in the array's own local frame, in centimetres.
axin = axes('Parent', f1, 'Position', [0.58 0.60 0.32 0.26], 'Color', 'w', 'FontSize', ax_fs-4);
hold(axin, 'on');
elem_x_cm = (rx_pos_all(1,:) - rx_center(1)) * 100;   % element offset along array axis (cm)
plot(axin, elem_x_cm, zeros(1,num_elements), '-', 'Color', [0.10 0.30 0.85], 'LineWidth', 1.2);
plot(axin, elem_x_cm, zeros(1,num_elements), 'o', 'MarkerSize', 11, ...
    'MarkerFaceColor', [0.10 0.30 0.85], 'MarkerEdgeColor', 'k', 'LineWidth', 1.2);
for k = 1:num_elements
    text(axin, elem_x_cm(k), 0.28, sprintf('%d', k), 'FontSize', ax_fs-4, ...
        'HorizontalAlignment', 'center');
end
lambda_cm = c / fc * 100;
title(axin, sprintf('\\textbf{Rx Array Zoom}: %d elems, $d=\\lambda/2=%.2f$ cm', ...
    num_elements, lambda_cm/2), 'FontSize', ax_fs-3);
xlabel(axin, 'Position along array axis (cm)', 'FontSize', ax_fs-4);
set(axin, 'YTick', []); ylim(axin, [-1 1]);
grid(axin, 'on'); box(axin, 'on');

% ---- Figure 2: Signal through the pipeline ----
f2 = figure('Name', 'Signal Through Pipeline', 'Color', fig_gray, 'Position', [150 120 1000 820]);
win = prop_delay_samples + (1:133);     % one received chirp pulse, after the propagation delay
tw  = t(win) * 1e6;

sigs   = {real(rx_sig(win,1)), real(bb_sig(win,1)), real(adc_sig(win,1))};
envs   = {abs(rx_sig(win,1)),  abs(bb_sig(win,1)),  abs(adc_sig(win,1))};
cols   = {[0.00 0.45 0.74], [0.49 0.18 0.56], [0.85 0.20 0.20]};
titles = {'\textbf{Stage 2:} Clean Received LFM Chirp (Antenna 1)', ...
          sprintf('\\textbf{Stage 4:} After Superheterodyne Downconversion ($f_{\\mathrm{IF}} = %.1f$ MHz)', f_if/1e6), ...
          sprintf('\\textbf{Stage 5:} After %d-bit ADC Quantization', num_bits)};

for s = 1:3
    ax = subplot(3,1,s); set(ax, 'Color', ax_gray, 'FontSize', ax_fs); hold(ax, 'on');
    % shaded magnitude envelope (the pulse shape)
    fill([tw; flipud(tw)], [envs{s}; -flipud(envs{s})], cols{s}, ...
        'FaceAlpha', 0.12, 'EdgeColor', 'none');
    % real part of the signal
    plot(tw, sigs{s}, '-', 'Color', cols{s}, 'LineWidth', 1.8);
    title(titles{s}, 'FontSize', ti_fs);
    ylabel('Amplitude (V)', 'FontSize', ax_fs);
    grid on; box on; axis tight;
    if s == 3, xlabel('Time ($\mu$s)', 'FontSize', ax_fs); end
end

% ---- Figure 3: Inter-element phase shift (all 4 antennas overlaid) ----
f3 = figure('Name', 'Inter-element Phase Shift', 'Color', fig_gray, 'Position', [200 140 1000 560]);
ax = axes('Parent', f3, 'Color', ax_gray, 'FontSize', ax_fs); hold(ax, 'on');
win_ph = prop_delay_samples + (85:120);   % short window in a moderate-frequency part of the chirp
twp  = t(win_ph) * 1e6;
cmap = lines(num_elements);
h = gobjects(num_elements, 1);
for el = 1:num_elements
    h(el) = plot(twp, real(rx_sig(win_ph, el)), '-o', 'Color', cmap(el,:), ...
        'MarkerFaceColor', cmap(el,:), 'MarkerSize', 4, 'LineWidth', 1.8);
end
title('\textbf{Inter-element Phase Shift} Across the 4 Antennas', 'FontSize', ti_fs);
xlabel('Time ($\mu$s)', 'FontSize', ax_fs); ylabel('Amplitude (V)', 'FontSize', ax_fs);
legend(h, arrayfun(@(k) sprintf('Antenna %d', k), 1:num_elements, 'UniformOutput', false), ...
    'Location', 'eastoutside', 'FontSize', ax_fs);
grid on; box on; axis tight;

% ---- Figure 4: Spectrograms (time-frequency view through the chain) ----
figure('Name', 'Spectrogram Analysis', 'Color', fig_gray, 'Position', [220 150 1000 820]);

% STFT settings: short window + high overlap to resolve the fast LFM sweep
win_len  = 48;                 % samples per STFT window
noverlap = 44;                 % overlap (samples)
nfft     = 256;                % FFT length (frequency bins)
dyn_range = 60;                % dB displayed below the global peak

spec_sigs   = {rx_sig(:,1), bb_sig(:,1), adc_sig(:,1)};
spec_titles = {'\textbf{Stage 2:} Received LFM Chirp (baseband)', ...
               sprintf('\\textbf{Stage 4:} After Superheterodyne ($f_{\\mathrm{IF}} = %.1f$ MHz)', f_if/1e6), ...
               sprintf('\\textbf{Stage 5:} After %d-bit ADC', num_bits)};

% Pre-compute every spectrogram first so all three share one color scale.
% 'centered' gives a two-sided spectrum (-fs/2..fs/2) for the complex I/Q signals.
S_all = cell(1,3); g_max = -Inf;
for s = 1:3
    [S, F, Tsec] = spectrogram(spec_sigs{s}, hamming(win_len), noverlap, nfft, fs, 'centered');
    S_all{s} = 20*log10(abs(S) + eps);     % +eps keeps the silent gaps finite (no -Inf)
    g_max = max(g_max, max(S_all{s}(:)));
end

try                              % use the turbo colormap if available
    cmap_spec = turbo(256);
catch
    cmap_spec = jet(256);
end

for s = 1:3
    ax = subplot(3,1,s); set(ax, 'Color', ax_gray, 'FontSize', ax_fs);
    imagesc(ax, Tsec*1e6, F/1e6, S_all{s});
    axis(ax, 'xy');
    clim(ax, [g_max - dyn_range, g_max]);    % shared scale across stages
    colormap(ax, cmap_spec);
    cb = colorbar(ax); cb.Label.String = 'Power (dB)'; cb.Label.FontSize = ax_fs-2;
    title(spec_titles{s}, 'FontSize', ti_fs);
    ylabel('Frequency (MHz)', 'FontSize', ax_fs);
    if s == 3, xlabel('Time ($\mu$s)', 'FontSize', ax_fs); end
end

disp('Pipeline execution complete. Review Figure 1 (Geometry), Figure 2 (Time Domain), Figure 3 (Inter-element phase), and Figure 4 (Spectrograms).');
