function [tx_pos, rx_pos, rx_array] = stage0_geometry(fc, num_elements)
% STAGE 0: Spatial and Geometric Configuration
% Highlights: Coordinate System, Antenna Array Geometry

% Define coordinate system, [X; Y; Z] in meters.
tx_pos = [5000; 0; 0];     % Ground emitter, 5 km downrange on the X-axis
rx_pos = [0; 0; 20000];    % Receiver array phase center at 20 km altitude (Z)

% Define Antenna Array Geometry using Phased Array System Toolbox
lambda = physconst('LightSpeed') / fc; % Wavelength

% Uniform Linear Array (ULA) with half-wavelength spacing.
% The array axis is set to X so it is NOT perpendicular to the line of sight:
% the emitter's X-offset relative to the overhead (Z) receiver makes the wavefront
% arrive at an angle, producing a visible inter-element phase shift. (With the
% default Y axis the source direction has no Y-component -> broadside -> no shift.)
rx_array = phased.ULA('NumElements', num_elements, 'ElementSpacing', lambda/2, ...
                      'ArrayAxis', 'x');

fprintf('Stage 0: Geometry defined. Tx at [%.0f, %.0f, %.0f] m, Rx Array (%d elems) at [%.0f, %.0f, %.0f] m.\n', ...
    tx_pos(1), tx_pos(2), tx_pos(3), num_elements, rx_pos(1), rx_pos(2), rx_pos(3));
end
