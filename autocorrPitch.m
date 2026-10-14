%% Autocorrelation FUNCTION
% Simply receives audio samples and estimates fundamental frequency -- does
% not care about when the note starts and ends
% The principle behind autocorrelation for pitch detection is that if a
% signal is periodic with period T0, shifting it by T0 should make it line
% up with itself again
function f0 = autocorrPitch(ySeg, Fs, fMin, fMax)
    % ySeg = audio samples corresponding to the portion of a note being
    % analyzed
    % Fs = Sampling frequency
    % fMin = minimum fundamental frequency to consider
    % fMax = maximum fundamental frequency to consider

    % f0 = the estimated fundamental frequency in Hz

    % Remove DC offset (center waveform around zero and apply Hann window
    ySeg = double(ySeg(:)) - mean(ySeg);
    ySeg = ySeg .* hann(length(ySeg));

    % Asking how well does this signal match a delayed version of itself
    % Calculate normalized autocorrelation
    r = xcorr(ySeg, 'coeff');

    % Keep only nonnegative lags; discard redundant information
    r = r(ceil(length(r)/2):end);

    % Allowed lag range based on allowed frequency range
    lagMin = max(2, round(Fs/fMax));
    lagMax = min(length(r)-1, round(Fs/fMin));

    if lagMax <= lagMin
        f0 = NaN;
        return;
    end

    % Only examine allowed lag range
    % rSearch extracts the autocorr values corresponding to the acceptable
    % frequency range
    rSearch = r(lagMin:lagMax);

    % Find all local maxima
    % peakVals = autoCorr values at the maxima peak
    % peakLocs = store indices within rSearch
    [peakVals, peakLocs] = findpeaks(rSearch);

    % If no peaks exist, pitch cannot be estimated
    if isempty(peakLocs)
        f0 = NaN;
        return;
    end

    % Find strength of largest autocorrelation peak
    strongestPeak = max(peakVals);

    % Keep peaks at least 70% as strong as largest peak
    relativeThreshold = 0.70;

    % Keep only peaks that meet the threshold
    significant = peakVals >= relativeThreshold * strongestPeak;

    sigLocs = peakLocs(significant);

    % If none survive, pitch cannot be estimated
    if isempty(sigLocs)
        f0 = NaN;
        return;
    end

    % Convert significant peak locations into lag values
    sigLags = lagMin + sigLocs - 1;

    % Estimate the period using the SPACING between peaks rather than
    % grabbing the first significant peak because it helps us determine the
    % period of the note more accurately
    if length(sigLags) >= 2
        chosenLag = mean(diff(sigLags));
    else
        chosenLag = sigLags(1);
    end

    % Convert lag to fundamental frequency
    f0 = Fs / chosenLag;

end
