function adc_sig = stage5_adc(bb_sig, num_bits, full_scale_volts)
    % STAGE 5: Analog to Digital Converter Modeling
    % Highlight: 8-bit
    
    num_levels = 2^num_bits;
    step_size = (2 * full_scale_volts) / num_levels;
    
    % Clip values to full scale range (physical voltage limits of the ADC)
    clipped_sig = bb_sig;
    clipped_sig(clipped_sig > full_scale_volts) = full_scale_volts;
    clipped_sig(clipped_sig < -full_scale_volts) = -full_scale_volts;
    
    % Quantize: divide by voltage step size, round to nearest digital bin, multiply back
    adc_sig = round(clipped_sig / step_size) * step_size;
    
    fprintf('Stage 5: ADC Modeling. Quantized to %d bits (%d levels).\n', num_bits, num_levels);
end
