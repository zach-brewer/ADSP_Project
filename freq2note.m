function [name, cents] = freq2note(f, noteNames)
% Convert to the nearest Midi
% Make sure that the frequency coming in has a value
if isnan(f) || f <= 0
    name = 'N/A';
    cents = NaN;
    return;
end
% Look at where the detected frequency actually lies
midiExact = 69 + 12*log2(f/440);
% Find the nearest musical note
midi = round(midiExact);

noteIndex = mod(midi, 12);
octave = floor(midi/12) - 1;

% Validate the Midi range for piano
% Can modify these values based on what instruments we want our project to
% be valid for, as varies by instrument
if midi < 0 || midi > 127
    name = 'Not a valid note.';
    cents = NaN;
    return;
end

name = sprintf('%s%d', noteNames{noteIndex+1}, octave);
% Figure out how far the measured frequency of the exact frequency is from
% the nearest musical note
cents = 100*(midiExact - midi);
end
