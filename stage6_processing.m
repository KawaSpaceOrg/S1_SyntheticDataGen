function processed_sig = stage6_processing(adc_sig)
    % STAGE 6: Processing
    % Highlight: Signal Conditioning (DC removal)
    
    % --- DC Removal (disabled) ---
    % This step was needed for the direct-conversion architecture, which injects
    % an LO-leakage DC offset. With the superheterodyne front-end (Stage 4) the
    % signal sits at a non-zero IF and carries no DC offset, so DC removal is not
    % required here. Left commented for reference / easy re-enabling.
    %
    % dc_estimate = mean(adc_sig);
    % processed_sig = adc_sig - dc_estimate;
    % fprintf('Stage 6: Processing. DC Removal applied. Estimated DC = %f + %fi.\n', ...
    %     real(dc_estimate), imag(dc_estimate));

    % Pass-through (no conditioning applied)
    processed_sig = adc_sig;

    fprintf('Stage 6: Processing. DC removal disabled (superheterodyne, no DC offset).\n');
end
