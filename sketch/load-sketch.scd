/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                          SURFACING CORE LOADER                               ║
║                        Load all modular components                           ║
║                         and initialize the system                            ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/



// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         INITIALIZE DEPENDENCIES                            │
// └─────────────────────────────────────────────────────────────────────────────┘

// Load setup loader first - go up one directory since we're in surfacing-core/
"Loading setup...".postln;
 (thisProcess.nowExecutingPath.dirname +/+ "../setup/_setup-loader.scd").load;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         INITIALIZE GLOBAL STATE                            │
// └─────────────────────────────────────────────────────────────────────────────┘

// Control parameters
~bpm = 298;
~noteDuration = 0.2;
~noteRest = 0.2;
~melodyRestTime = 0.025;
~noteOffset = -12;
~repetitions = 1;
~currentMelodySetIndex = 0;
~currentCycle = 0;

// Collections to track active states
~activeCCSynths = Dictionary.new;
~activeNotes = Dictionary.new;
~lastFermataNote = nil;
~lastFermataChord = nil;  // For chord mode fermata tracking
~sequenceTask = nil;
~loopingCCEnvelopes = false;
~activeVSTGroup = nil;

// Initialize modes dictionary - CRITICAL: This must come before loading modules
~modes = (
    noteOffset: false,
    fermata: false,
    melodyRestMode: false,
    pauseNotesMode: false,
    removeLast: false,
    velocityMultiply: false,
    manualLooping: true,    // false = progressive (auto-advance), true = manual (stay on current)
    chordProgression: false,  // false = melody mode, true = chord mode
    sustainMode: false,      // true = disable noteOff messages, false = normal noteOff behavior
    keyboardMode: false     // true = keyboard triggering with bend envelopes, false = sequence playback
);

// CC control parameters
~ccControl = (
    enabled: true,
    expressionCC: 16,
    expressionMin: 10,
    expressionMax: 120,
    expressionShape: \sin,
    expressionPeakPos: 0.5,
    expressionDurationScalar: 1.0,
    noteDuration: 0.2,
    noteRestTime: 0.2,
    velocity: 100
);

// Continuous loop variables
~currentLoopIndex = 0;
~currentLoopIteration = 0;
~continuousLoopTask = nil;
~continuousLoopRunning = false;
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                          LOAD CORE MODULES                                 │
// └─────────────────────────────────────────────────────────────────────────────┘

"Loading Core Functions...".postln;
(thisProcess.nowExecutingPath.dirname +/+ "core-functions.scd").load;

"Loading VST Group Targeting...".postln;
(thisProcess.nowExecutingPath.dirname +/+ "vst-targeting.scd").load;

"Loading Control Systems...".postln;
(thisProcess.nowExecutingPath.dirname +/+ "control-systems.scd").load;

"Loading Musical Implementation...".postln;
(thisProcess.nowExecutingPath.dirname +/+ "musical-implementation.scd").load;

"Loading Chord Progressions...".postln;
(thisProcess.nowExecutingPath.dirname +/+ "chord-progressions.scd").load;

"Loading Initialization & Startup...".postln;
(thisProcess.nowExecutingPath.dirname +/+ "initialization-startup.scd").load;

"Loading Keyboard Mode Manager...".postln;
(thisProcess.nowExecutingPath.dirname +/+ "keyboard-mode-manager-v2.scd").load;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                      POST-INITIALIZATION SETUP                             │
// └─────────────────────────────────────────────────────────────────────────────┘
"Loading Sketch GUI...".postln;
(thisProcess.nowExecutingPath.dirname +/+ "sketch-gui.scd").load;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                           SUCCESS MESSAGE                                  │
// └─────────────────────────────────────────────────────────────────────────────┘
/*
~setActiveVSTGroup.('Tuba');
~startContinuousLoopSequence.value;
~stopContinuousLoopSequence.value;
~listVSTGroups.value;
~showVSTTargeting.value;
~createMelodyManagerUI.value;
~createMIDIControlMappingGUI.();  // Open MIDI Control Mapping GUI

// GUI Controls (automatically loaded after 3 seconds)
~createSketchGUI.();              // Manual GUI creation (if needed)
~closeSketchGUI.();               // Close GUI and cleanup
*/