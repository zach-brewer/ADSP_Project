clear all; close all; clc;

%% Zach's Code

% Read the audio
% y = raw audio samples
% Fs = sampling frequency
[y, Fs] = audioread("10_notes.mp3");
sound(y,Fs);

% IF the MP3 is stereo, average the left and right channels into one mono
% signal (make it into a 1D array)
if size(y, 2) > 1
    y = mean(y, 2);   
end 

% Zurin: Increased window length from 512 to 4096 samples to improve
% frequency resolution
% Length of the window we are using; Hanning window here
windowLength = 4096;

% Overlap the windows 80%
overlap = round(0.8*windowLength);

% Zero pad the 4096-sample window before taking the FFT for more closely
% spaced FFT frequency samples to make the spectrum smoother
nfft = 8124;
window = hann(windowLength);


%% Calculate STFT

% Zurin: Added 'FrequencyRange','onesided' since we only want positive
% S = STFT coeffs
% F = frequencies associated with each row of the STFT
% T = time associated with each STFT column where each column is a
% frequency spectrum at one moment in time

[S, F, T] = stft(y, Fs, ...
    'Window', window, ...
    'OverlapLength', overlap, ...
    'FFTLength', nfft, ...
    'FrequencyRange','onesided');

% Turn the complex STFT coefficients into magnitudes so that we can see how
% much of frequency f exists at time t
P = abs(S);

% Converts these magnitudes into dB so that the huge range of magnitudes is
% easier to visualize
P_dB = 20*log10(P + eps);


%% Plot spectrogram
figure;
imagesc(T, F, P_dB); axis xy;
xlabel('Time (s)');
ylabel('Frequency (Hz)');
title('STFT Spectrogram');
colorbar;
ylabel(colorbar, 'Magnitude (dB)');
colormap jet;
ylim([0 1000]);
clim([max(P_dB(:))-60 max(P_dB(:))]);


% Calculate energy in each STFT time frame
% How much signal energy is present in each STFT time frame?
% Signal squared to get energy 
energy_dB = 20*log10(sum(P.^2, 1) + eps);
energy_smooth = movmean(energy_dB, 3);

minEnergyPeakGap = 0.10;  % seconds

minPeakDistance = round(minEnergyPeakGap / (T(2)-T(1)));

[energyMax, maxIdx] = findpeaks( ...
    energy_smooth, ...
    'MinPeakDistance', minPeakDistance);

[minNeg, minIdx] = findpeaks( ...
    -energy_smooth, ...
    'MinPeakDistance', minPeakDistance);

energyMin = -minNeg;

figure;
plot(T, energy_smooth, 'LineWidth', 1.5);
hold on;

plot(T(maxIdx), energyMax, 'ro');
plot(T(minIdx), energyMin, 'bo');

grid on;
xlabel('Time (s)');
ylabel('Energy (dB)');
title('Energy with Local Maxima and Minima');
legend('Energy', 'Local maxima', 'Local minima');
%% I believe everything above here is what Zach's updated code is doing in
% terms of finding peaks and duration of notes


%% Computes the Harmonic Product Spectrum
% function f1 = hpsPitch(ySeg, Fs, fMin, fMax)
% ySeg = Audio samples from a detected note
% Fs = Sampling frequency 
% fMin = Minimum frequency to consider
% fMax = Maximum frequency to consider

% Initialize the HPS 
% STFT magnitude spectrum in dB
Pmag_dB = P_dB;
% Use info up to the 2nd harmonic; when used from higher harmonics, code
% was less accurate at picking up fundamental frequencies
R = 2;
% Create array where the HPS result will be stored
HPS_dB = Pmag_dB;

% Work on one STFT frame at a time
for t = 1:size(Pmag_dB,2)
    % Grab the spectrum at just that instant
    h = Pmag_dB(:,t);

    % Compress the frequency axis by r to make all of the harmonics pile up
    % at the fundamental
    for r = 2:R
        decimated = Pmag_dB(1:r:end, t);
        % Add the compressed spectra together
        h(1:length(decimated)) = ...
            h(1:length(decimated)) + decimated;
    end

    % Store the finished HPS for this time frame
    HPS_dB(:,t) = h;
end

% Only search reasonable frequencies (80 Hz to 1000 Hz)
% Find the strongest HPS candidate
fMask = F >= 80 & F <= 1000;
[~, idx] = max(HPS_dB(fMask,:), [], 1);
Fsub = F(fMask);

% Estimated fundamental frequency at each STFT frame
f0_raw = Fsub(idx);


%% Calculates the loudest and tests against active threshold set

% Zurin: Threshold changed from max - 30 dB to max - 60 dB.
% Now spectral flux detects the note attacks, so this energy threshold only
% needs to distinguish meaningful sound from silence.
activeThreshold = max(energy_dB) - 60;

% Seeing if a new note is happening; if energy is above the threshold a new
% note is being played
isActive = energy_dB > activeThreshold;
f0_raw(~isActive) = NaN;


% Zurin: Removed the 3-frame moving median from f0_raw to debug, we can
% switch back
% f0_clean = movmedian(f0_raw, 3, 'omitnan');
f0_clean = f0_raw;


%% Zurin: Spectral Flux Note-Onset Detection
% The original code detected note starts and stops using changes in the
% energy threshold. That did not work well when one note decayed into the
% next because the energy might never fall below the threshold.
%
% Spectral flux instead detects sudden changes in the frequency spectrum,
% which usually occur when a new note is attacked.


% Zurin: Normalize each STFT frame
Pnorm = P ./ (sum(P,1) + eps);


% Zurin: Find the change in normalized spectral magnitude
spectralDiff = diff(Pnorm, 1, 2);


% Zurin: Only keep increases in frequency magnitude.
spectralDiff(spectralDiff < 0) = 0;
spectralFlux = [0 sum(spectralDiff.^2, 1)];
% Zurin: Smooth the flux to reduce noise
spectralFlux_smooth = movmean(spectralFlux, 3);

fluxThreshold = median(spectralFlux_smooth) + ...
                1*std(spectralFlux_smooth);

% Zurin: Find the peaks

% Zurin: Minimum time allowed between detected notes
% Two detected onsets only have to be 0.2 seconds apart to both be accepted
minOnsetGap = 0.2;

[~, fluxOnsets] = findpeaks( ...
    spectralFlux_smooth, ...
    'MinPeakHeight', fluxThreshold, ...
    'MinPeakDistance', round(minOnsetGap/(T(2)-T(1))));

% Problem coming from only basing new notes around whether there is a high
% spectral flux, not factoring in if there is also a sudden increase in
% energy 
% Noticed in observing the spectral flux plot and the energy vs time plot
% that the false note detections were coming from small fluctuations in the
% energy vs time plot rather than big bumps in energy_smooth
% Need to consider if there is a spectral flux peak AND significant energy
% increase to determine if there's actually a new note being played
% fluxOnsets contains the STFT-frame indices where findpeaks thinks new
% notes are starting
% energy_smooth has one energy value for each STFT frame

% Look at the energy change at every detected flux onset and see how much
% of a dB change we're dealing with to make sure that the false note
% detection truly corresponds to small energy changes that are much less
% significant than the energy changes of true peaks

% For each onset index, find the change in energy
validOnsets = [];
energyChangeThreshold = 5.0; % dB, prelim value

for i = 1:length(fluxOnsets)
    idx = fluxOnsets(i);

    % idx - 1 could become 0 if an onset occurs at the very first time
    % frame and MATLAB cannot index at 0 so safeguard against this
    beforeIdx = max(1, idx - 1);
    afterIdx = min(length(energy_smooth), idx + 1);

    energyChange = energy_smooth(afterIdx) - energy_smooth(beforeIdx);

    if energyChange > energyChangeThreshold
        validOnsets(end+1) = idx;
    end
end

%% Zurin: Plot spectral flux to verify detected note playing

figure;
plot(T, spectralFlux_smooth, 'LineWidth', 1.5);
hold on;

yline(fluxThreshold, '--', 'Threshold');

plot(T(fluxOnsets), ...
    spectralFlux_smooth(fluxOnsets), ...
    'ro', ...
    'MarkerSize', 8);

xlabel('Time (s)');
ylabel('Spectral Flux');
title('Spectral Flux Note Onset Detection');
grid on;


%% On or off set calculation
% I set this up arbitrarily not sure what value we should actually use
lastActive = find(energy_dB > -100, 1, 'last');


% Zurin: Every spectral-flux onset is looked at as a new note
mergedOnsets = validOnsets;

% Zurin: Each note ends right before the next note starts.
% Three STFT frames are also removed before the next onset to reduce leakage 
mergedOffsets = [mergedOnsets(2:end) - 3, lastActive];


%% Actual fundamental frequency calculation code

noteStart = T(mergedOnsets);
noteEnd   = T(mergedOffsets);

autocFmin = 80;
autocFmax = 1200;


%% Fundamental Frequency Calculation

noteStart = T(mergedOnsets);
noteEnd   = T(mergedOffsets);

noteFreq_autoc = nan(1, length(mergedOnsets));

autocFmin = 80;
autocFmax = 1200;

for i = 1:length(mergedOnsets)

    % Analyze the stable portion of each note
    analysisStart = noteStart(i) + 0.100;
    analysisEnd = min(noteStart(i) + 0.500, noteEnd(i));

    % Convert times to sample indices
    sIdx = max(1, round(analysisStart * Fs));
    eIdx = min(length(y), round(analysisEnd * Fs));

    if eIdx > sIdx

        noteFreq_autoc(i) = autocorrPitch( ...
            y(sIdx:eIdx), ...
            Fs, ...
            autocFmin, ...
            autocFmax);

    end

end

%% Print Note Table

printNoteTable(noteStart, noteEnd, noteFreq_autoc);

plotDetectedNotes(noteStart, noteEnd, noteFreq_autoc);
