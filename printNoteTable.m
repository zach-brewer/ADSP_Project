function printNoteTable(noteStart, noteEnd, noteFreq_autoc)
% Define the 12 musical notes in the chromatic scale
noteNames = {'C','C#','D','D#','E','F','F#','G','G#','A','A#','B'};

% Print table header
fprintf('\n=== Notes of Mapped Frequencies ===\n');

% Format table columns and specify their width and alignment for easy
% result readability
fprintf('| %-3s | %8s | %8s | %11s | %12s | %-13s | %-7s |\n', ...
    '#', 'Start(s)', 'End(s)', 'Duration(s)', 'Autocorr(Hz)', 'Autocorr Note', 'Cents');

% For each detected note, convert its estimated fundamental frequency 
% into the corresponding musical note name and octave
% and octave
for i = 1:length(noteStart)
    
    % Convert frequency to musical note and calculate the deviation in
    % cents
    [nameA, centsA] = freq2note(noteFreq_autoc(i), noteNames);

    % Print the note's start and end time, duration, estimated fundamental
    % frequency, musical note name, and deviation in cents
    fprintf('| %-3d | %8.2f | %8.2f | %11.2f | %12.2f | %-13s | %+7.1f |\n', ...
        i, ...
        noteStart(i), ...
        noteEnd(i), ...
        noteEnd(i)-noteStart(i), ...
        noteFreq_autoc(i), ...
        nameA, ...
        centsA);
end
end

