function plotDetectedNotes(noteStart, noteEnd, noteFreq_autoc)

figure;
hold on;

for i = 1:length(noteStart)

    % Skip notes without valid frequency estimates
    if isnan(noteFreq_autoc(i))
        continue;
    end

    % Plot each note as a horizontal line
    plot( ...
        [noteStart(i) noteEnd(i)], ...
        [noteFreq_autoc(i) noteFreq_autoc(i)], ...
        'LineWidth', 3);
end

xlabel('Time (s)');
ylabel('Fundamental Frequency (Hz)');
title('Detected Fundamental Frequency per Note');
grid on;

hold off;

end
