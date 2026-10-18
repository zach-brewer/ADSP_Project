function plotDetectedNotes(noteStart, noteEnd, noteFreq_autoc)

figure;
hold on;

% Plot each detected note as a horizontal line representing
% its duration (x-axis) and estimated fundamental frequency (y-axis)
for i = 1:length(noteStart)

    % Skip any notes where the fundamental frequency could not be estimated
    if isnan(noteFreq_autoc(i))
        continue;
    end

    % Plot a horizontal line from the note's start time to its end time at
    % the estimated fundamental frequency
    plot( ...
        [noteStart(i) noteEnd(i)], ...
        [noteFreq_autoc(i) noteFreq_autoc(i)], ...
        'LineWidth', 3);
end

xlabel('Time (s)');
ylabel('Fundamental Frequency (Hz)');
title('Detected Fundamental Frequency per Note');
grid on;
end
