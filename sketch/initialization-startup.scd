/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                         INITIALIZATION & STARTUP                             ║
║                         Default settings and                                 ║
║                         usage instructions                                   ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         PROCMOD INITIALIZATION                             │
// └─────────────────────────────────────────────────────────────────────────────┘

// Load active melodies first
"Loading active melodies...".postln;
~loadActiveMelodies.value;

// Initialize ProcMods for each melody in the current sequence (only if sequence is loaded)
if (~currentSequence.notNil) {
    if (~currentSequence.size > 0) {
        ~currentSequence.do { |melodyKey|
            if(~melodyProcs[melodyKey].isNil) {
                ~melodyProcs[melodyKey] = ~createMelodyProc.value(melodyKey);
            };
        };
        "Initialized ProcMods for % melodies".format(~currentSequence.size).postln;
    } {
        "No melody sequence available - empty sequence".postln;
    };
} {
    "No melody sequence available - ProcMods will be created as needed".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         USAGE INSTRUCTIONS                                 │
// └─────────────────────────────────────────────────────────────────────────────┘

"
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                        SURFACING - PERFORMANCE CONTROLS                      ║
║                             Live Electronic Tuba                             ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝

┌─────────────────────────────────────────────────────────────────────────────┐
│                         PRIMARY CONTROLS                                   │
└─────────────────────────────────────────────────────────────────────────────┘

Main Functions:
  ~startContinuousLoopSequence.value;  // Start the continuous sequence
  ~stopContinuousLoopSequence.value;   // Stop the sequence
  ~stopAllNotes.value;                 // Emergency stop all notes

┌─────────────────────────────────────────────────────────────────────────────┐
│                           MIDI CONTROLS                                    │
└─────────────────────────────────────────────────────────────────────────────┘

Button Controls:
  CC 25: Toggle Pause Notes mode
  CC 45: Toggle Melody Rest mode
  Note 22: Previous Melody
  Note 23: Toggle Chord Progression mode
  Note 26: Next Chord (when in chord mode)
  Note 27: Next Melody
  Note 28: Previous Chord (when in chord mode)
  Note 29: Toggle Sustain mode (disable noteOff messages)

Slider Controls:
  1: Note Duration           (0.1 - 10.0 seconds)
  2: Note Rest Time          (0.0001 - 0.4 seconds)
  3: Velocity                (1 - 127)
  4: Melody Rest Time        (0.0 - 1.0 seconds)
  5: Temporal Accent         (0 - 8x multiplier)

Knob Controls:
  1 (0): Expression Min      (CC value minimum)
  2 (1): Expression Max      (CC value maximum)
  4 (3): Expression Duration (10% - 100% of melody duration)
  7 (6): First Note Rest     (1.0 - 2.0x multiplier)

┌─────────────────────────────────────────────────────────────────────────────┐
│                       VST GROUP TARGETING                                  │
└─────────────────────────────────────────────────────────────────────────────┘

Direct Group Control (use regular quotes):
  ~setActiveVSTGroup.(groupName);      // Target specific group by name
  ~setActiveVSTGroup.(\"All\");           // Target all VST instances (clean syntax)
  ~useAllVSTs.value;                   // Convenience function for all instances

Index-Based Control (Dynamic):
  ~listVSTGroups.value;                // Show all groups with indices
  ~useVSTGroup.(0);                    // Target first group
  ~useVSTGroup.(1);                    // Target second group
  ~useVSTGroup.(nil);                  // Target all instances (legacy)

Live Performance Cycling:
  ~nextVSTGroup.value;                 // Cycle to next group
  ~prevVSTGroup.value;                 // Cycle to previous group

Information & Status:
  ~showVSTTargeting.value;             // Show current targeting status
  ~listVSTGroups.value;                // List all available groups

┌─────────────────────────────────────────────────────────────────────────────┐
│                       CHORD PROGRESSION MODE                               │
└─────────────────────────────────────────────────────────────────────────────┘

Chord Functions:
  ~listChordProgressions.();           // List available progressions
  ~loadChordProgression.(key);         // Load a specific progression
  ~showChordStatus.();                 // Show current chord info
  ~nextChord.();                       // Navigate to next chord
  ~previousChord.();                   // Navigate to previous chord

Chord Mode:
  - Enable with MIDI Note 23 or ~modes.chordProgression = true
  - Each VST plays a different note of the chord
  - Number of chord notes should match number of VSTs
  - Bend envelopes work per-note on each chord voice
".postln;

"
// Example usage:
// ~setActiveVSTGroup.(\"Tuba\");
// ~setActiveVSTGroup.(\"Trumpet\");
// ~setActiveVSTGroup.(\"All\");
".postln;

"
┌─────────────────────────────────────────────────────────────────────────────┐
│                          KEYBOARD MODE                                     │
└─────────────────────────────────────────────────────────────────────────────┘

Real-time keyboard triggering with ProcMod and per-note bend envelopes:

Control:
  ~enableKeyboardMode.()               // Enable keyboard mode
  ~disableKeyboardMode.()              // Disable keyboard mode  
  ~toggleKeyboardMode.()               // Toggle keyboard mode
  MIDI Note 30                         // Toggle via MIDI button

Behavior:
  - First note triggers 10-second ProcMod
  - Each note gets independent bend envelope
  - Notes sustain for ProcMod duration (ignore note-off)
  - CC envelope triggers once per ProcMod
  - Stops sequence playback when enabled
".postln; 