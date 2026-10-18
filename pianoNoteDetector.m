
%% ============================================================
%  File Name:    pianoNoteDetector.m
%
%  Author:       Zach Brewer, 
%                Mackenzie Campbell, 
%                Zurin Trzaska, 
%                Tyler Ware
%
%  Date:         10/18/26
%  Course:       EENG510
%
%  Description: 
%      Detects fundamental frequency of each note in input file
%
%
%% ============================================================

clear; clc; close all;

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

% Length of the window we are using; Hanning window here
windowLength = 4096;

% Overlap the windows 80%
overlap = round(0.8*windowLength);

% Zero pad the 4096-sample window before taking the FFT for more closely
% spaced FFT frequency samples to make the spectrum smoother
nfft = 8124;
window = hann(windowLength);


%% Calculate STFT
% S = STFT coeffs
% F = frequencies associated with each row of the STFT
% T = time associated with each STFT column where each column is a
% frequency spectrum at one moment in time
% Calculating the STFT using the Hanning window established above, the
% overlap of 80%, and for a length of nfft
% 'FrequencyRange','onesided' since we only want positive

[S, F, T] = stft(y, Fs, ...
    'Window', window, ...
    'OverlapLength', overlap, ...
    'FFTLength', nfft, ...
    'FrequencyRange','onesided');

% Turn the complex STFT coefficients into magnitudes so that we can see how
% much of frequency f exists at time t
P = abs(S);

% Converts these magnitudes into dB so that the extensive range of 
% magnitudes is easier to visualize
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


%% Note Boundary Detection

% Calculate energy envelope from the STFT
energy_dB = 10*log10(sum(P.^2, 1) + eps);

% Smooth the energy envelope to reduce fluctuations
% Uses length 3 moving average filter to reduce noise
energy_smooth = movmean(energy_dB, 3);

% Determine when audio is active
activeThreshold = max(energy_smooth) - 20;
isActive = energy_smooth > activeThreshold;

% Normalize each STFT frame
Pnorm = P ./ (sum(P, 1) + eps);

% Calculate positive spectral flux
% Saves positive energy differences
spectralDiff = diff(Pnorm, 1, 2);
spectralDiff(spectralDiff < 0) = 0;
spectralFlux = [0, sum(spectralDiff.^2, 1)];

% Smooth spectral flux
% length 3 moving average filter to reduce noise
spectralFlux_smooth = movmean(spectralFlux, 3);

% Detect candidate note onsets and set the threshold at one standard 
% deviation above median of flux
fluxThreshold = median(spectralFlux_smooth) + ...
                std(spectralFlux_smooth);


framePeriod = mean(diff(T));

% Minimum spacing between note starts (seconds)
minOnsetGap = 0.15;  

% find index of peaks in the spectral flux
[~, fluxOnsets] = findpeaks(spectralFlux_smooth, ...
    'MinPeakHeight', fluxThreshold, ...
    'MinPeakDistance', max(1, round(minOnsetGap/framePeriod)));


% Validate candidate onsets using energy change
validOnsets = [];
energyChangeThreshold = 1;  % Minimum energy increase (dB)
% Establish frames to check around the peak
checkFrames = max(1, round(0.05/framePeriod)); 

for i = 1:length(fluxOnsets)
    idx = fluxOnsets(i);
    % Only check indexes inside a certain range
    beforeIdx = max(1, idx - checkFrames);
    afterIdx = min(length(energy_smooth), idx + checkFrames);

    energyChange = energy_smooth(afterIdx) - energy_smooth(beforeIdx);
    % Only save indices where energy change is above the set threshold
    if energyChange >= energyChangeThreshold
        validOnsets(end+1) = idx;
    end
end

%% Graph of saved fluxes and initial calculations
% Debugging print out to see rejected not boundaries
fprintf('Number of candidates: %d\n', length(fluxOnsets));
fprintf('Accepted note starts: %d\n', length(validOnsets));

figure;
plot(T, energy_smooth, 'b');
hold on;

% Plot initial onsets
plot(T(fluxOnsets), energy_smooth(fluxOnsets), ...
    'ro', 'MarkerSize', 8);

% Plot saved onsets
plot(T(validOnsets), energy_smooth(validOnsets), ...
    'gx', 'MarkerSize', 10, 'LineWidth', 2);

legend('Energy', 'Flux candidates', 'Accepted starts');
xlabel('Time (s)');
ylabel('Energy (dB)');
title('Debugging Rejected Note Starts');

% Include the first active frame if no onset was detected near it
firstActive = find(isActive, 1, 'first');

if ~isempty(firstActive)
    if isempty(validOnsets) || ...
            validOnsets(1) > firstActive + checkFrames
        validOnsets = [firstActive, validOnsets];
    end
end

% Sort and remove duplicate onset indices
validOnsets = unique(validOnsets, 'sorted');

% Convert onset frame indices to respective points in time
noteStart = T(validOnsets);

% Find the final frame containing audio
lastActive = find(isActive, 1, 'last');

% End each note at the next onset
% Alternatively, this could be changed to find note ends using a similar
% method as used for note starts
if isempty(lastActive) || isempty(noteStart)
    noteStart = [];
    noteEnd = [];
else
    noteStart = noteStart(:)';  % make noteStart into row vector
    % Save ends from start of second note to end of active energy
    noteEnd = [noteStart(2:end), T(lastActive)];

    % Remove any invalid or zero-duration intervals
    validNotes = noteEnd > noteStart;
    noteStart = noteStart(validNotes);
    noteEnd = noteEnd(validNotes);
end

%% Debug Plot Detected Note Boundaries

figure;
energy_smooth(energy_smooth < 0) = 0;
plot(T, energy_smooth, 'LineWidth', 1.5);
hold on;

yline(activeThreshold, '--', 'Activity Threshold');

for i = 1:length(noteStart)
    xline(noteStart(i), 'g');
    xline(noteEnd(i), 'r');
end

xlabel('Time (s)');
ylabel('Energy (dB)');
title('Detected Note Starts and Ends');

%% On or off set calculation
% Since there is no subsequent onset to indicate the end of the final note,
% use the last frame with energy above 0 dB as its offset.
lastActive = find(energy_dB > 0, 1, 'last');


% Every spectral-flux onset is looked at as a new note
mergedOnsets = validOnsets;

% Each note ends right before the next note starts.
% Three STFT frames are also removed before the next onset to reduce leakage 
mergedOffsets = [mergedOnsets(2:end) - 3, lastActive];

%% Fundamental Frequency Calculation

% Establish the times when given note starts and ends
noteStart = T(mergedOnsets);
noteEnd   = T(mergedOffsets);

% Initialize array to store the estimated fundamental frequency of each
% note
noteFreq_autoc = nan(1, length(mergedOnsets));

% Limit fundamental frequency estimation to 80-1200 Hz range
autocFmin = 80;
autocFmax = 1200;

for i = 1:length(mergedOnsets)

    % Analyze the stable portion of each note
    % Analyzing from 100 ms to 500 ms after its onset, or until note ends
    % (whichever condition is met first)
    % Waiting in order to avoid initial transient attack that could
    % potentially interfere with our fundamental frequency estimation
    analysisStart = noteStart(i) + 0.100;
    analysisEnd = min(noteStart(i) + 0.500, noteEnd(i));

    % Convert analysis start and end times to sample indices
    sIdx = max(1, round(analysisStart * Fs));
    eIdx = min(length(y), round(analysisEnd * Fs));

    % Estimate the fundamental frequency of each note using autocorrelation,
    % as long as the analysis window contains at least two samples
    % Note that autocorrelation is being applied to a selected portion of
    % the original time domain signal
    if eIdx > sIdx

        noteFreq_autoc(i) = autocorrPitch( ...
            y(sIdx:eIdx), ...
            Fs, ...
            autocFmin, ...
            autocFmax);
    end

end

%% Output the detected notes in a tabular and graph format
printNoteTable(noteStart, noteEnd, noteFreq_autoc);

plotDetectedNotes(noteStart, noteEnd, noteFreq_autoc);
