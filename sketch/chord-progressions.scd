/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                            CHORD PROGRESSIONS                                ║
║                       Chord definitions and utilities                        ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         GLOBAL VARIABLES                                   │
// └─────────────────────────────────────────────────────────────────────────────┘

// Chord dictionary and state variables
~chords = Dictionary.new;
~currentChordProgressionKey = nil;
~currentChordIndex = 0;
~currentChordProgression = nil;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         CHORD DEFINITIONS                                  │
// └─────────────────────────────────────────────────────────────────────────────┘

// Simple triads progression - the default and only progression
~chords[\simpleTriads] = (
    name: "Simple Triads",
    chords: [
        [60, 64, 67],        // C major
        [57, 60, 64],        // A minor
        [65, 69, 72],        // F major
        [67, 71, 74]         // G major
    ],
    velocityMultipliers: [1.0, 0.9, 0.95, 1.1]
);

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         CHORD UTILITIES                                    │
// └─────────────────────────────────────────────────────────────────────────────┘

// Function to load a chord progression
~loadChordProgression = { |progressionKey|
    if (~chords.includesKey(progressionKey)) {
        ~currentChordProgressionKey = progressionKey;
        ~currentChordProgression = ~chords[progressionKey];
        ~currentChordIndex = 0;
        ["Loaded chord progression:", ~currentChordProgression.name].postln;
        ["Chords:", ~currentChordProgression.chords.size, "chords"].postln;
        ^true;
    } {
        ["Chord progression not found:", progressionKey].postln;
        ["Available progressions:", ~chords.keys.asArray.sort].postln;
        ^false;
    };
};

// Function to get current chord
~getCurrentChord = {
    if (~currentChordProgression.notNil) {
        ~currentChordProgression.chords[~currentChordIndex];
    } {
        nil;
    };
};

// Function to navigate to next chord
~nextChord = {
    if (~currentChordProgression.notNil) {
        ~currentChordIndex = (~currentChordIndex + 1) % ~currentChordProgression.chords.size;
        ["Chord index:", ~currentChordIndex, "- Chord:", ~getCurrentChord.()].postln;
    } {
        "No chord progression loaded".postln;
    };
};

// Function to navigate to previous chord
~previousChord = {
    if (~currentChordProgression.notNil) {
        ~currentChordIndex = (~currentChordIndex - 1).wrap(0, ~currentChordProgression.chords.size - 1);
        ["Chord index:", ~currentChordIndex, "- Chord:", ~getCurrentChord.()].postln;
    } {
        "No chord progression loaded".postln;
    };
};

// Function to validate chord against VST count
~validateChordVSTCount = { |chord|
    var instances = ~vstManager.getTargetInstances(~activeVSTGroup);
    var vstCount = instances.size;
    var chordSize = chord.size;
    
    if (chordSize != vstCount) {
        ["WARNING: Chord size (%) doesn't match VST count (%)".format(chordSize, vstCount)].postln;
        if (chordSize > vstCount) {
            ["Only first % notes of chord will be played".format(vstCount)].postln;
        } {
            ["Only % VSTs will play (chord has % notes)".format(chordSize, chordSize)].postln;
        };
    } {
        ["✓ Chord size matches VST count: %".format(vstCount)].postln;
    };
    
    ^true; // Always return true to allow playback
};

// Function to list all chord progressions
~listChordProgressions = {
    "\n=== Available Chord Progressions ===".postln;
    ~chords.keysValuesDo { |key, progression|
        "  % - % (% chords)".format(
            key.asString.padRight(20),
            progression.name,
            progression.chords.size
        ).postln;
    };
    "==================================\n".postln;
};

// Function to show current chord status
~showChordStatus = {
    if (~currentChordProgression.notNil) {
        ["\nCurrent progression: %".format(~currentChordProgression.name)].postln;
        ["Chord % of %: %".format(
            ~currentChordIndex + 1,
            ~currentChordProgression.chords.size,
            ~getCurrentChord.()
        )].postln;
    } {
        ["No chord progression loaded"].postln;
    };
};

// Convenience function to enable chord mode
~enableChordMode = {
    ~loadChordProgression.(\simpleTriads);
    ~modes.chordProgression = true;
    "Chord mode enabled with Simple Triads progression".postln;
    ~showChordStatus.();
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         INITIALIZATION                                     │
// └─────────────────────────────────────────────────────────────────────────────┘

// Initialize without loading to avoid startup conflicts
"Chord progression system initialized".postln;
"To enable chord mode: ~enableChordMode.()".postln;