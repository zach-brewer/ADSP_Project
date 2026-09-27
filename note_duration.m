[y, Fs] = audioread("4_notes.mp3");
% sound(y,Fs);



if size(y, 2) > 1
    y = mean(y, 2);
end

cutoffFreq = 400; 

% Apply the low-pass filter
y = lowpass(y, cutoffFreq, Fs);

windowLength = 512;
overlap_percent = .8;
overlap = round(overlap_percent*windowLength);
nfft = 8124;

window = hann(windowLength);

%% Calculate STFT
[S, F, T] = stft(y, Fs, 'Window', window, 'OverlapLength', overlap,'FFTLength', nfft);

P = abs(S);
P_dB = 20*log10(P + eps);

%% Plot spectrogram
figure;

imagesc(T, F, P_dB);
axis xy;

xlabel('Time (s)');
ylabel('Frequency (Hz)');
title('STFT');

colorbar;
ylabel(colorbar, 'Magnitude (dB)');

colormap jet;

% ylim([0 4186]); % actual piano frequencies
ylim([0 1000]);
clim([max(P_dB(:))-60 max(P_dB(:))]);

freqMask = (F >= 50 & F <= 4200);

% Calculate energy in each STFT time frame
%frameEnergy = sum(P(freqMask,:).^2, 1);
frameEnergy = sum(P.^2, 1);

% Convert to dB
energy_dB = 10*log10(frameEnergy + eps);

% Smooth the energy slightly
energy_smooth = movmean(energy_dB, 5);

%% Plot energy vs time

figure;

plot(T, energy_smooth, 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Energy (dB)');
title('STFT Energy vs Time');
grid on;