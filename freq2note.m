function [name, cents] = freq2note(f, noteNames)
% Convert to the nearest MIDI
% Check that the detected frequency is valid
if isnan(f) || f <= 0
    name = 'N/A';
    cents = NaN;
    return;
end

% Convert the detected frequency to its corresponding MIDI value
midiExact = 69 + 12*log2(f/440);
% Round to the nearest MIDI note and determine its name and octave
midi = round(midiExact);

% Note: mod(midi, 12) determines the note's position within 12 note
% chromatic scale
noteIndex = mod(midi, 12);
octave = floor(midi/12) - 1;

% Reject notes outside of the standard 88-key piano range
% Note: these values could be modified in the future to accommodate for
% other instruments, as valid midi ranges vary by instrument
% be valid for, as varies by instrument
if midi < 0 || midi > 127
    name = 'Not a valid note.';
    cents = NaN;
    return;
end

% Combine the musical note name with its octave
name = sprintf('%s%d', noteNames{noteIndex+1}, octave);

% Calculate the frequency deviation from the nearest note in cents
% + cents means detected frequency is sharper/higher than the nearest note
% - cents means detected frequency is flatter/lower than the nearest note
% 0 cents means detected frequency perfectly matches note's ideal frequency
cents = 100*(midiExact - midi);
end
