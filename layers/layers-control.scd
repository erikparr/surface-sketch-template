/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                       DEPENDENT LAYERS - CONTROL                              ║
║                         API functions for control                             ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         PLAYBACK CONTROL                                   │
// └─────────────────────────────────────────────────────────────────────────────┘

// Start all layers
~startLayers = {
    if (~layers.state.isPlaying) {
        "Layers already playing".warn;
    } {
        var activeCount = ~getActiveLayerCount.();
        
        if (activeCount > 0) {
            "Starting % active layers...".format(activeCount).postln;
            
            // Create and play parent ProcMod
            ~layers.parentProc = ~createLayersParentProc.();
            ~layers.parentProc.play;
            
            ~layers.state.isPlaying = true;
            ~layers.state.startTime = Main.elapsedTime;
            
            ~printLayerStatus.();
        } {
            "No active layers to start. Please assign melodies and enable layers.".warn;
        };
    };
};

// Stop all layers
~stopLayers = {
    if (~layers.state.isPlaying) {
        "Stopping all layers...".postln;
        
        // The parent's onRelease function will handle releasing child ProcMods
        if (~layers.parentProc.notNil) {
            ~layers.parentProc.release;
            ~layers.parentProc = nil;
        };
        
        ~layers.state.isPlaying = false;
        ~layers.state.startTime = nil;
        
        "All layers stopped".postln;
    } {
        "Layers not currently playing".warn;
    };
};

// Emergency stop
~killLayers = {
    if (~layers.parentProc.notNil) {
        // Kill all child ProcMods first
        ~layers.layerProcs.do { |proc|
            if (proc.notNil and: { proc.isRunning }) {
                "Killing child ProcMod: %".format(proc.id).postln;
                proc.kill;
            };
        };
        
        // Then kill parent
        ~layers.parentProc.kill;
        ~layers.parentProc = nil;
    };
    
    // Clear layer procs dictionary
    ~layers.layerProcs.clear;
    
    ~layers.state.isPlaying = false;
    ~layers.state.startTime = nil;
    
    "All layers killed".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         LAYER CONFIGURATION                                │
// └─────────────────────────────────────────────────────────────────────────────┘

// Set melody for a layer
~setLayerMelody = { |layerName, melodyKey|
    var config = ~layers.configs[layerName];
    
    config.melodyList = [melodyKey];  // Single melody, no progression
    
    // Find the melody in ~melodyData and add it to ~melodyDict
    if (~melodyData.notNil and: { ~melodyData[\melodies].notNil }) {
        var melodyInfo = ~melodyData[\melodies].detect { |m| m[\key].asSymbol == melodyKey };
        if (melodyInfo.notNil) {
            // Add to ~melodyDict for playback compatibility
            if (~melodyDict.isNil) {
                ~melodyDict = Dictionary.new;
            };
            ~melodyDict[melodyKey] = (
                name: melodyInfo[\name],
                patterns: [melodyInfo[\pattern]],  // Wrap in array for compatibility
                velocityMultipliers: (
                    first: melodyInfo[\velocityFirst] ? 1.0,
                    last: melodyInfo[\velocityLast] ? 1.0
                ),
                loopCount: melodyInfo[\loopCount] ? 1
            );
            "Added melody % to ~melodyDict".format(melodyKey).postln;
        } {
            "Warning: Melody % not found in ~melodyData".format(melodyKey).postln;
        };
    };
    
    "Layer % melody set to %".format(layerName, melodyKey).postln;
    
    // Recalculate duration
    ~calculateLayerDuration.(config);
};

// Enable/disable a layer
~setLayerEnabled = { |layerName, enabled|
    var config = ~layers.configs[layerName];
    
    config.enabled = enabled;
    "Layer % enabled: %".format(layerName, enabled).postln;
};

// Set VST group for a layer
~setLayerVSTGroup = { |layerName, vstGroup|
    var config = ~layers.configs[layerName];
    
    // Ensure vstGroup is a Symbol to match VSTManager's groups dictionary keys
    config.vstGroup = vstGroup.asSymbol;
    "Layer % VST group set to %".format(layerName, vstGroup).postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         BATCH OPERATIONS                                   │
// └─────────────────────────────────────────────────────────────────────────────┘

// Configure all layers at once
~configureAllLayers = { |layer1Melody, layer2Melody, layer3Melody|
    ~setLayerMelody.(\layer1, layer1Melody);
    ~setLayerMelody.(\layer2, layer2Melody);
    ~setLayerMelody.(\layer3, layer3Melody);
    
    "All layers configured".postln;
    ~printLayerStatus.();
};

// Enable all layers
~enableAllLayers = {
    ~layers.configs.keysValuesDo { |name, config|
        config.enabled = true;
    };
    "All layers enabled".postln;
};

// Disable all layers
~disableAllLayers = {
    ~layers.configs.keysValuesDo { |name, config|
        config.enabled = false;
    };
    "All layers disabled".postln;
};

// Clear all layer melodies
~clearAllLayers = {
    ~layers.configs.keysValuesDo { |name, config|
        config.melodyList = [];
        config.duration = 0;
    };
    "All layer melodies cleared".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         QUERY FUNCTIONS                                    │
// └─────────────────────────────────────────────────────────────────────────────┘

// Get current playback time
~getLayersPlayTime = {
    if (~layers.state.isPlaying) {
        Main.elapsedTime - ~layers.state.startTime
    } {
        0
    }
};

// Check if a specific layer is ready
~isLayerReady = { |layerName|
    // Safety check for initialization
    if (~layers.isNil or: { ~layers.configs.isNil }) {
        false;
    } {
        var config = ~layers.configs[layerName];
        if (config.notNil) {
            (config[\enabled] ? false) and: { (config[\melodyList] ? []).size > 0 };
        } {
            false;
        };
    };
};

// Get list of ready layers
~getReadyLayers = {
    var ready = [];
    ~layers.configs.keysValuesDo { |name, config|
        if (~isLayerReady.(name)) {
            ready = ready.add(name);
        };
    };
    ready
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         PRESET MANAGEMENT                                  │
// └─────────────────────────────────────────────────────────────────────────────┘

// Save current configuration
~saveLayerPreset = { |presetName|
    var preset = Dictionary.new;
    
    ~layers.configs.keysValuesDo { |name, config|
        preset[name] = (
            melodyList: config.melodyList.copy,
            vstGroup: config.vstGroup,
            enabled: config.enabled
        );
    };
    
    ~layerPresets = ~layerPresets ? Dictionary.new;
    ~layerPresets[presetName] = preset;
    
    "Layer preset '%' saved".format(presetName).postln;
};

// Load a preset
~loadLayerPreset = { |presetName|
    var preset = ~layerPresets[presetName];
    
    preset.keysValuesDo { |layerName, settings|
        var config = ~layers.configs[layerName];
        config.melodyList = settings.melodyList.copy;
        config.vstGroup = settings.vstGroup;
        config.enabled = settings.enabled;
    };
    
    "Layer preset '%' loaded".format(presetName).postln;
    ~printLayerStatus.();
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         FILE LOADING                                       │
// └─────────────────────────────────────────────────────────────────────────────┘

// Load melody from file for a specific layer
~loadMelodyFileForLayer = { |layerName, filePath|
    var loadedData, melodies;
    
    if (File.exists(filePath)) {
        var extension = PathName(filePath).extension.toLower;
        
        if (extension == "json") {
            // Handle JSON files
            try {
                "Loading JSON melody file for layer %: %".format(layerName, filePath).postln;
                loadedData = JSONlib.parseFile(filePath, useEvent: true);
                
                if (loadedData.notNil && loadedData[\melodies].notNil && loadedData[\melodies].size > 0) {
                    // Add ALL melodies from the file to ~melodyDict
                    if (~melodyDict.isNil) {
                        ~melodyDict = Dictionary.new;
                    };
                    
                    // Load each melody from the file
                    loadedData[\melodies].do { |melodyInfo|
                        var melodyKey = melodyInfo[\key].asSymbol;
                        
                        ~melodyDict[melodyKey] = (
                            name: melodyInfo[\name],
                            patterns: [melodyInfo[\pattern]],
                            velocityMultipliers: (
                                first: melodyInfo[\velocityFirst] ? 1.0,
                                last: melodyInfo[\velocityLast] ? 1.0
                            ),
                            loopCount: melodyInfo[\loopCount] ? 1
                        );
                        
                        "Added melody % (%s) to ~melodyDict".format(melodyKey, melodyInfo[\name]).postln;
                    };
                    
                    // Set the first melody as the active one for this layer
                    if (loadedData[\melodies].size > 0) {
                        var firstMelodyKey = loadedData[\melodies][0][\key].asSymbol;
                        ~setLayerMelody.(layerName, firstMelodyKey);
                        
                        "Loaded % melodies from file. Layer % set to use melody: %".format(
                            loadedData[\melodies].size, 
                            layerName, 
                            firstMelodyKey
                        ).postln;
                    } {
                        "Loaded % melodies from file. No melody set for layer %.".format(
                            loadedData[\melodies].size, 
                            layerName
                        ).postln;
                    };
                } {
                    "Error: JSON file does not contain valid melody data".postln;
                };
            } { |error|
                "Error parsing JSON file: %".format(error).postln;
            };
        } {
            if (extension == "scd") {
                // Handle SuperCollider files
                try {
                    filePath.load;
                    "Loaded SuperCollider file for layer %".format(layerName).postln;
                } { |error|
                    "Error loading SuperCollider file: %".format(error).postln;
                };
            } {
                "Error: Unsupported file type '%'. Use .json or .scd files.".format(extension).postln;
            };
        };
    } {
        "Error: File not found - %".format(filePath).postln;
    };
};

"Dependent layers control system loaded".postln;