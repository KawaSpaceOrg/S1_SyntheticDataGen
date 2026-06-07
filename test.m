% test.m
% Run this script in the command window AFTER running main_pipeline.m

disp('Running test.m to analyze the IF signal...');

% Extract the last 501 samples of Antenna 1's IF signal (the exact window you plotted)
idx = (size(bb_sig, 1) - 500) : size(bb_sig, 1);
sig_if = bb_sig(idx, 1);

figure('Name', 'Visual Envelope vs True Frequency', 'Color', 'w', 'Position', [200 200 900 700]);

% ---------------------------------------------------------
% Plot 1: Time Domain (The Optical Illusion)
% ---------------------------------------------------------
subplot(2,1,1);
plot(sig_if, 'Color', [0.85 0.33 0.10], 'LineWidth', 1.5);
title('\textbf{1. Time Domain: Visually looks like a Down-Chirp (Optical Illusion)}', 'Interpreter', 'latex', 'FontSize', 14);
xlabel('Sample Index', 'Interpreter', 'latex');
ylabel('Amplitude', 'Interpreter', 'latex');
grid on;

% ---------------------------------------------------------
% Plot 2: Frequency Domain (The True Physics)
% ---------------------------------------------------------
subplot(2,1,2);
% We use a very small window (64 samples) because we only have 500 samples total to analyze
spectrogram(sig_if, hamming(64), 60, 512, fs, 'yaxis');
title('\textbf{2. Spectrogram: The actual frequency is sweeping UP (180 MHz to 200 MHz)!}', 'Interpreter', 'latex', 'FontSize', 14);

disp('Look at the spectrogram! The yellow energy line clearly slopes UPWARDS.');
