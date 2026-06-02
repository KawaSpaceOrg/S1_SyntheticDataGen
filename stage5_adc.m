function adc_sig = stage5_adc(bb_sig, num_bits, full_scale_volts)
    % STAGE 5: Analog to Digital Converter Modeling
    % Highlight: 8-bit
    
    num_levels = 2^num_bits;
    step_size = (2 * full_scale_volts) / num_levels;
    
    % Separate into In-Phase (Real) and Quadrature (Imaginary)
    I = real(bb_sig);
    Q = imag(bb_sig);
    
    % Clip values to full scale range (optional but realistic)
    I(I > full_scale_volts) = full_scale_volts;
    I(I < -full_scale_volts) = -full_scale_volts;
    Q(Q > full_scale_volts) = full_scale_volts;
    Q(Q < -full_scale_volts) = -full_scale_volts;
    
    % Quantize: divide by step size, round to nearest integer, multiply back
    I_quant = round(I / step_size) * step_size;
    Q_quant = round(Q / step_size) * step_size;
    
    % Recombine complex signal
    adc_sig = I_quant + 1j * Q_quant;
    
    fprintf('Stage 5: ADC Modeling. Quantized to %d bits (%d levels).\n', num_bits, num_levels);
end
