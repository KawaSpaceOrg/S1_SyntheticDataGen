function rx_sig = stage2_channel(tx_sig, tx_pos, rx_pos, fc, fs)
    % STAGE 2: The Propagation Channel
    % Highlight: Free Space Path Loss
    
    % Use Phased Array System Toolbox for Free Space environment
    env = phased.FreeSpace('OperatingFrequency', fc, ...
                           'SampleRate', fs, ...
                           'TwoWayPropagation', false);
                       
    tx_vel = [0; 0; 0]; % Stationary transmitter
    
    % Ensure rx_vel matches the number of receivers (columns in rx_pos)
    num_rx = size(rx_pos, 2);
    rx_vel = zeros(3, num_rx); % Stationary receiver array
    
    % Replicate tx signal to match the number of paths (one for each receiver)
    tx_sig_rep = repmat(tx_sig, 1, num_rx);
    
    % Apply propagation effects (primarily FSPL and phase delay)
    % phased.FreeSpace expects at least one of Pos1/Pos2 to be 3x1 when
    % simulating 1-to-N or N-to-1 paths.
    rx_sig = env(tx_sig_rep, tx_pos, rx_pos, tx_vel, rx_vel);
    
    % Calculate theoretical path loss for logging (using the first antenna element)
    dist = norm(tx_pos - rx_pos(:, 1));
    loss_db = fspl(dist, physconst('LightSpeed')/fc);
    
    fprintf('Stage 2: Channel applied. Distance = %.1f m. FSPL = %.2f dB.\n', dist, loss_db);
end
