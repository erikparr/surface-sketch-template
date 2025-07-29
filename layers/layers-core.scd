/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                         DEPENDENT LAYERS - CORE                               ║
║                    Data structures and initialization                         ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         CORE DATA STRUCTURES                               │
// └─────────────────────────────────────────────────────────────────────────────┘

// Main container for the dependent layer system
~layers = (
    parentProc: nil,              // Parent ProcMod instance
    configs: Dictionary.new,      // Layer configurations
    layerProcs: Dictionary.new,   // Child ProcMod instances for each layer
    timingData: Dictionary.new,   // Pre-calculated timing info
    windowTasks: Dictionary.new,  // Active window tasks for each layer
    state: (
        totalDuration: 0,
        startTime: nil,
        loopingMode: false,       // Single source of truth for looping
        manualControl: false,     // Enable MIDI knob control for duration and velocity
        liveMelodyMode: false,    // Enable live melody updates via OSC
        pendingUpdates: Dictionary.new,  // Store pending melody updates per layer
        backupProcessNote: nil,   // Backup of sketch system's processNote function
        noteDurationScalar: 1.0,  // Note duration scalar (1.0-1.5) from Row 1 Knob 2
        singleNoteCCMode: false   // Toggle for per-note CC envelopes
    )
);

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         INITIALIZATION                                     │
// └─────────────────────────────────────────────────────────────────────────────┘

~initializeLayers = {
    "Initializing dependent layer system...".postln;
    
    // Create exactly 3 layers with default VST groups from vstplugin-setup.scd
    ~layers.configs[\layer1] = (
        melodyList: [],
        vstGroup: 'Layer1',      // Default group from vstplugin-setup
        enabled: true,
        duration: 0,
        noteDurationScalar: 1.0,  // Individual layer note duration scalar
        ccControl: (
            enabled: true,
            expressionCC: 11,
            expressionMin: 10,
            expressionMax: 120,
            expressionShape: \sin,
            expressionPeakPos: 0.5,
            expressionDurationScalar: 1.0
        ),
        windowing: (
            enabled: false,
            windowSize: 5,
            overlapTriggerIndex: 2,  // Trigger on 3rd note (0-based)
            stepSize: 1
        )
    );
    
    ~layers.configs[\layer2] = (
        melodyList: [],
        vstGroup: 'Layer2',      // Default group from vstplugin-setup
        enabled: true,
        duration: 0,
        noteDurationScalar: 1.0,  // Individual layer note duration scalar
        ccControl: (
            enabled: true,
            expressionCC: 12,
            expressionMin: 10,
            expressionMax: 120,
            expressionShape: \sin,
            expressionPeakPos: 0.5,
            expressionDurationScalar: 1.0
        ),
        windowing: (
            enabled: false,
            windowSize: 5,
            overlapTriggerIndex: 2,  // Trigger on 3rd note (0-based)
            stepSize: 1
        )
    );
    
    ~layers.configs[\layer3] = (
        melodyList: [],
        vstGroup: 'Layer3',      // Default group from vstplugin-setup
        enabled: true,
        duration: 0,
        noteDurationScalar: 1.0,  // Individual layer note duration scalar
        ccControl: (
            enabled: true,
            expressionCC: 13,
            expressionMin: 10,
            expressionMax: 120,
            expressionShape: \sin,
            expressionPeakPos: 0.5,
            expressionDurationScalar: 1.0
        ),
        windowing: (
            enabled: false,
            windowSize: 5,
            overlapTriggerIndex: 2,  // Trigger on 3rd note (0-based)
            stepSize: 1
        )
    );
    
    "Dependent layers initialized with default VST groups".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         DURATION CALCULATIONS                              │
// └─────────────────────────────────────────────────────────────────────────────┘

// Calculate duration for a single melody
~calculateMelodyDuration = { |melodyKey|
    var pattern, noteCount, noteDuration, noteRestTime;
    
    // Safety check for melody existence
    if (~melodyDict.isNil or: { ~melodyDict[melodyKey].isNil }) {
        "Warning: Melody % not found in ~melodyDict".format(melodyKey).postln;
        ^0;
    };
    
    pattern = ~melodyDict[melodyKey].patterns[0];
    noteCount = pattern.size;
    
    // Use sketch system timing if available, otherwise use defaults
    noteDuration = if (~ccControl.notNil and: { ~ccControl.noteDuration.notNil }) {
        ~ccControl.noteDuration
    } {
        0.2  // Default note duration
    };
    
    noteRestTime = if (~ccControl.notNil and: { ~ccControl.noteRestTime.notNil }) {
        ~ccControl.noteRestTime
    } {
        0.2  // Default rest time
    };
    
    // Total time = notes * (duration + rest)
    (noteCount * (noteDuration + noteRestTime))
};

// Calculate total duration for a layer (sum of all melodies)
~calculateLayerDuration = { |config|
    var totalDuration = 0;
    
    config.melodyList.do { |melodyKey|
        totalDuration = totalDuration + ~calculateMelodyDuration.(melodyKey);
    };
    
    config.duration = totalDuration;  // Store in config
    totalDuration
};

// Find maximum duration across all enabled layers
~calculateMaxDuration = {
    var maxDuration = 0;
    
    ~layers.configs.keysValuesDo { |layerName, config|
        if (config.enabled and: { config.melodyList.size > 0 }) {
            var layerDuration = ~calculateLayerDuration.(config);
            maxDuration = max(maxDuration, layerDuration);
        };
    };
    
    ~layers.state.totalDuration = maxDuration;
    "Maximum duration across layers: % seconds".format(maxDuration).postln;
    maxDuration
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         UTILITY FUNCTIONS                                  │
// └─────────────────────────────────────────────────────────────────────────────┘

// Get active layer count
~getActiveLayerCount = {
    var count = 0;
    ~layers.configs.do { |config|
        if (config.enabled and: { config.melodyList.size > 0 }) {
            count = count + 1;
        };
    };
    count
};

// Get layer status string
~getLayerStatus = { |layerName|
    var config = ~layers.configs[layerName];
    var status = "Layer %: ".format(layerName);
    
    if (config.enabled) {
        if (config.melodyList.size > 0) {
            status = status ++ "% → %".format(
                config.melodyList[0], 
                config.vstGroup
            );
        } {
            status = status ++ "No melody assigned";
        };
    } {
        status = status ++ "Disabled";
    };
    
    status
};

// Print current layer configuration
~printLayerStatus = {
    "\n=== Layer Status ===".postln;
    ~layers.configs.keysValuesDo { |name, config|
        ~getLayerStatus.(name).postln;
    };
    "Active layers: %".format(~getActiveLayerCount.()).postln;
    "Total duration: % seconds".format(~layers.state.totalDuration).postln;
    "Playing: %".format(
        ~layers.parentProc.notNil and: { ~layers.parentProc.isRunning }
    ).postln;
    "==================\n".postln;
};