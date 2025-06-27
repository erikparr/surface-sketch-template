// Initialization and Startup - Looping Envelope System
// Initializes the system and provides startup functions

(
// System initialization
~initLoopingEnvelopeSystem = {
    var melodyPath, presetDir;
    
    "=== Initializing Looping Envelope System ===".postln;
    
    // Define ~bpm for clip system compatibility
    if(~bpm.isNil) {
        ~bpm = 120; // Default BPM
    };
    
    // Ensure VSTManager is available
    if(~vstManager.isNil) {
        "Waiting for VSTManager...".postln;
        ~vstManager = VSTManager.current;
    };
    
    // Load melody data if not already loaded
    if(~melodyData.isNil) {
        melodyPath = PathName(thisProcess.nowExecutingPath).pathOnly +/+ "../data/melody/melody-data.json";
        if(File.exists(melodyPath)) {
            ~melodyData = melodyPath.parseJSONFile;
            "Melody data loaded".postln;
        } {
            "Warning: melody-data.json not found".warn;
            // Create default melody data
            ~melodyData = (
                melodies: (
                    development1: (
                        loopCount: 1,
                        melodies: [
                            (notes: [60, 64, 67, 72], velocities: [80, 85, 90, 85], durations: [1, 1, 1, 1])
                        ]
                    )
                )
            );
        };
    };
    
    // Initialize system state
    ~currentDevelopment = 0;
    ~currentCycle = 0;
    ~isPlaying = false;
    ~currentTarget = \All;
    
    // Start envelope update routine (but don't play)
    if(~envelopeUpdateRoutine.notNil && ~envelopeUpdateRoutine.isPlaying.not) {
        ~envelopeUpdateRoutine.reset;
    };
    
    // Create preset directory if needed
    presetDir = Platform.userAppSupportDir +/+ "SuperCollider/EnvelopePresets";
    if(File.exists(presetDir).not) {
        File.mkdir(presetDir);
        "Created envelope preset directory".postln;
    };
    
    "=== Looping Envelope System Initialized ===".postln;
    
    // Print available controls
    "".postln;
    "=== MIDI Slider Mappings ===".postln;
    "Slider 1-2: Strings (bend %, duration)".postln;
    "Slider 3-4: Winds (bend %, duration)".postln;
    "Slider 5-6: Brass (bend %, duration)".postln;
    "Slider 7: Global expression level".postln;
    "Slider 8: Global expression duration".postln;
    "".postln;
    "=== Quick Start Functions ===".postln;
    "~startPerformance.value()  - Start playback".postln;
    "~stopPerformance.value()   - Stop playback".postln;
    "~testEnvelopePlayback.value(\\Strings)  - Test a group".postln;
    "~printEnvelopeStates.value()  - Show envelope status".postln;
    "".postln;
};

// Quick test function
~quickTest = { |groupName = \Strings|
    "Running quick envelope test...".postln;
    
    // Set some test parameters
    ~groupEnvelopeParams[groupName].bendPercent = 25;
    ~groupEnvelopeParams[groupName].bendDuration = 3.0;
    ~groupEnvelopeParams[groupName].exprLevel = 100;
    ~groupEnvelopeParams[groupName].exprDuration = 1.5;
    
    // Play test chord
    ~testEnvelopePlayback.value(groupName);
};

// Demo patterns
~runDemo = {
    "Running envelope demo patterns...".postln;
    
    Task({
        // Pattern 1: Slow strings
        "Demo: Sustained strings with slow bend".postln;
        ~musicalPatterns.sustainedChord.value();
        6.wait;
        
        // Pattern 2: Fast winds
        "Demo: Wind arpeggios with quick bends".postln;
        ~musicalPatterns.arpeggioPattern.value();
        4.wait;
        
        // Pattern 3: Brass fanfare
        "Demo: Brass fanfare with expression swells".postln;
        ~musicalPatterns.brassFanfare.value();
        5.wait;
        
        "Demo complete".postln;
    }).play;
};

// Emergency reset
~emergencyReset = {
    "=== EMERGENCY RESET ===".postln;
    
    // Stop everything
    ~stopAllEnvelopes.value();
    ~stopPerformance.value();
    
    // Clear all synths
    s.freeAll;
    
    // Reset all VSTs
    ~vstManager.getInstances.keysValuesDo { |name, controller|
        16.do { |chan|
            controller.midi.allNotesOff(chan);
            controller.midi.bend(chan, 8192);
            controller.midi.control(chan, 11, 0);
            controller.midi.control(chan, 17, 0);
        };
    };
    
    // Reset state
    ~currentDevelopment = 0;
    ~currentCycle = 0;
    ~isPlaying = false;
    
    "System reset complete".postln;
};

// Run initialization
~initLoopingEnvelopeSystem.value();

// Auto-start envelope monitoring
~envelopeMonitor = Task({
    inf.do {
        if(~isPlaying) {
            // Monitor and update active envelopes
            [\Strings, \Winds, \Brass].do { |groupName|
                if(~groupHasActiveEnvelopes.value(groupName)) {
                    // Envelopes are active for this group
                    // Could add monitoring logic here
                };
            };
        };
        1.0.wait;
    };
}).play;

"Initialization complete - System ready".postln;
)