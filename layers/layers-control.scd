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
~startLayers = { |duration|
    "DEBUG: ~startLayers called with duration: %".format(duration).postln;
    "DEBUG: parentProc = %, isRunning = %".format(
        ~layers.parentProc, 
        ~layers.parentProc.notNil and: { ~layers.parentProc.isRunning }
    ).postln;
    
    if (~layers.parentProc.notNil and: { ~layers.parentProc.isRunning }) {
        "Layers already playing".warn;
    } {
        var activeCount = ~getActiveLayerCount.();
        var effectiveDuration;
        
        if (activeCount > 0) {
            // Determine effective duration
            if (duration.notNil) {
                effectiveDuration = duration;
                "Starting % active layers for % seconds...".format(activeCount, duration).postln;
            } {
                // Use knob value if in manual control mode, otherwise default
                if (~layers.state.manualControl) {
                    effectiveDuration = ~getLayersDurationFromKnob.();
                    "Starting % active layers with MIDI knob duration: % seconds...".format(
                        activeCount, effectiveDuration
                    ).postln;
                } {
                    effectiveDuration = 4.0;  // Default duration
                    "Starting % active layers with default duration: % seconds...".format(
                        activeCount, effectiveDuration
                    ).postln;
                };
            };
            
            // Create and play parent ProcMod with determined duration
            "DEBUG: About to call ~createLayersParentProc...".postln;
            "DEBUG: ~createLayersParentProc is: %".format(~createLayersParentProc).postln;
            
            if (~createLayersParentProc.notNil) {
                ~layers.parentProc = ~createLayersParentProc.(effectiveDuration);
            } {
                "ERROR: ~createLayersParentProc is nil!".postln;
                ~layers.parentProc = nil;
            };
            
            "DEBUG: Created parentProc: %".format(~layers.parentProc).postln;
            
            ~layers.parentProc.play;
            "DEBUG: Called play on parentProc".postln;
            
            // Check if it's actually running
            {
                0.1.wait;
                "DEBUG: After play - isRunning: %".format(~layers.parentProc.isRunning).postln;
            }.fork;
            
            ~layers.state.startTime = Main.elapsedTime;
            ~layers.state.totalDuration = effectiveDuration;  // Store the duration
            
            ~printLayerStatus.();
        } {
            "No active layers to start. Please assign melodies and enable layers.".warn;
        };
    };
};

// Stop all layers
~stopLayers = {
    if (~layers.parentProc.notNil and: { ~layers.parentProc.isRunning }) {
        "Stopping all layers...".postln;
        
        // The parent's onRelease function will handle releasing child ProcMods
        if (~layers.parentProc.notNil) {
            ~layers.parentProc.release;
            ~layers.parentProc = nil;
        };
        
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
    
    // Clear layer procs dictionary and timing data
    ~layers.layerProcs.clear;
    ~layers.timingData.clear;
    
    ~layers.state.startTime = nil;
    
    "All layers killed".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         LAYER CONFIGURATION                                │
// └─────────────────────────────────────────────────────────────────────────────┘

// Set melody for a layer
~setLayerMelody = { |layerName, melodyKey|
    var config = ~layers.configs[layerName];
    
    if (config.isNil) {
        "Error: Layer % not found".format(layerName).error;
        ^nil;
    };
    
    // Check if melody exists
    if (~melodyDict.notNil and: { ~melodyDict[melodyKey].notNil }) {
        config.melodyList = [melodyKey];  // Single melody, no progression
        "Layer %: assigned melody %".format(layerName, melodyKey).postln;
    } {
        // Try to find the melody in ~melodyData and add it to ~melodyDict
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
            config.melodyList = [melodyKey];
            "Added melody % from ~melodyData to ~melodyDict".format(melodyKey).postln;
        } {
            // Melody not found in either dict, but still set it
            config.melodyList = [melodyKey];
            "Warning: Melody % not found in ~melodyDict or ~melodyData".format(melodyKey).warn;
        };
    } {
        // No ~melodyData available, just set the melody
        config.melodyList = [melodyKey];
        "Warning: Melody % not found in ~melodyDict".format(melodyKey).warn;
    };
    };
    
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
// │                         MANUAL CONTROL FUNCTIONS                           │
// └─────────────────────────────────────────────────────────────────────────────┘

// Get duration from MIDI knob (row 1, position 8)
~getLayersDurationFromKnob = {
    var duration = 4.0; // Default duration
    var rawValue, normalizedValue, mappedDuration;
    
    if (~layers.state.manualControl and: { ~midiController.notNil }) {
        // Get the raw value from the knob
        rawValue = ~midiController.getKnobRow1(8);
        
        // Check if we need to normalize (if value > 1, it's likely raw MIDI 0-127)
        if (rawValue > 1) {
            normalizedValue = rawValue / 127.0;
        } {
            normalizedValue = rawValue;
        };
        
        // Map to duration range
        duration = normalizedValue.linlin(0, 1, 0.1, 10.0);
    };
    
    duration
};

// Enable/disable manual control mode
~setLayersManualControl = { |enabled|
    ~layers.state.manualControl = enabled;
    
    if (enabled) {
        "Layers manual control mode: ENABLED".postln;
        "- Duration: Row 1, Knob 8 (0.1-10 seconds)".postln;
        "- Velocity: Row 1, Knob 3 (1-127)".postln;
        "- Note Duration: Row 1, Knob 2 (1-150%)".postln;
    } {
        "Layers manual control mode: DISABLED".postln;
        "- Duration: Fixed/default values".postln;
        "- Velocity: From melody data".postln;
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         QUERY FUNCTIONS                                    │
// └─────────────────────────────────────────────────────────────────────────────┘

// Get current playback time
~getLayersPlayTime = {
    if (~layers.state.startTime.notNil) {
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
// │                       EXPRESSION CONTROL                                   │
// └─────────────────────────────────────────────────────────────────────────────┘

// Enable/disable expression control for a specific layer
~setLayerExpressionEnabled = { |layerName, enabled|
    var config = ~layers.configs[layerName];
    
    if (config.notNil && config.ccControl.notNil) {
        config.ccControl.enabled = enabled;
        "Layer % expression control: %".format(
            layerName, 
            if(enabled, "ENABLED", "DISABLED")
        ).postln;
    };
};

// Set expression CC number for a layer
~setLayerExpressionCC = { |layerName, ccNum|
    var config = ~layers.configs[layerName];
    
    if (config.notNil && config.ccControl.notNil) {
        config.ccControl.expressionCC = ccNum;
        "Layer % expression CC set to %".format(layerName, ccNum).postln;
    };
};

// Set expression parameters for a layer
~setLayerExpressionParams = { |layerName, min, max, shape = \sin, peakPos = 0.5|
    var config = ~layers.configs[layerName];
    
    if (config.notNil && config.ccControl.notNil) {
        config.ccControl.expressionMin = min.clip(0, 127);
        config.ccControl.expressionMax = max.clip(0, 127);
        config.ccControl.expressionShape = shape;
        config.ccControl.expressionPeakPos = peakPos.clip(0, 1);
        
        // Ensure max > min
        if (config.ccControl.expressionMax <= config.ccControl.expressionMin) {
            config.ccControl.expressionMax = config.ccControl.expressionMin + 1;
        };
        
        "Layer % expression: Min=%, Max=%, Shape=%, PeakPos=%".format(
            layerName, 
            config.ccControl.expressionMin,
            config.ccControl.expressionMax,
            config.ccControl.expressionShape,
            config.ccControl.expressionPeakPos
        ).postln;
    };
};

// Enable expression control for all layers
~enableAllLayerExpression = {
    [\layer1, \layer2, \layer3].do { |layerName|
        ~setLayerExpressionEnabled.(layerName, true);
    };
};

// Disable expression control for all layers
~disableAllLayerExpression = {
    [\layer1, \layer2, \layer3].do { |layerName|
        ~setLayerExpressionEnabled.(layerName, false);
    };
};

// Print expression settings for a layer
~printLayerExpressionSettings = { |layerName|
    var config = ~layers.configs[layerName];
    
    if (config.notNil && config.ccControl.notNil) {
        var cc = config.ccControl;
        "=== Layer % Expression Settings ===".format(layerName).postln;
        "  Enabled: %".format(cc.enabled).postln;
        "  CC Number: %".format(cc.expressionCC).postln;
        "  Min: %".format(cc.expressionMin).postln;
        "  Max: %".format(cc.expressionMax).postln;
        "  Shape: %".format(cc.expressionShape).postln;
        "  Peak Position: %".format(cc.expressionPeakPos).postln;
        "  Duration Scalar: %".format(cc.expressionDurationScalar).postln;
        "================================".postln;
    };
};

// Print all layer expression settings
~printAllLayerExpressionSettings = {
    [\layer1, \layer2, \layer3].do { |layerName|
        ~printLayerExpressionSettings.(layerName);
    };
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
            enabled: config.enabled,
            ccControl: config.ccControl.copy  // Include expression settings
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
        
        // Load expression settings if available
        if (settings.ccControl.notNil) {
            config.ccControl = settings.ccControl.copy;
        };
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
            // Handle JSON files using our timing-aware import function
            try {
                "Loading JSON melody file for layer %: %".format(layerName, filePath).postln;
                
                // Use the timing-aware import function
                if (~importLayerMelodyFromJSON.notNil) {
                    melodies = ~importLayerMelodyFromJSON.(filePath);
                    
                    if (melodies.notNil) {
                        var layerKey, matchingKey;
                        
                        // Add imported melodies to global dictionary
                        ~addImportedMelodiesToDict.(melodies, "");  // Empty prefix to use original layer names
                        
                        // Find the appropriate layer data
                        layerKey = layerName.asString.replace("layer", "layer");  // Ensure format matches
                        
                        // Try to find a matching layer in the imported data
                        // First try exact match
                        matchingKey = melodies.keys.detect { |key|
                            key == layerName
                        };
                        
                        // If no exact match, try by layer number
                        if (matchingKey.isNil) {
                            var layerNum = layerName.asString.last.asString.asInteger;
                            // Try 0-indexed match (layer1 -> layer0)
                            matchingKey = ("layer" ++ (layerNum - 1)).asSymbol;
                            if (melodies[matchingKey].isNil) {
                                // Try 1-indexed match (layer1 -> layer1)
                                matchingKey = layerName;
                                if (melodies[matchingKey].isNil) {
                                    matchingKey = nil;
                                };
                            };
                        };
                        
                        if (matchingKey.isNil) {
                            // Fallback: use the first available layer from the file
                            matchingKey = melodies.keys.asArray.sort.first;
                        };
                        
                        if (matchingKey.notNil) {
                            ~setLayerMelody.(layerName, matchingKey);
                            "Loaded melody '%' from JSON for layer %".format(matchingKey, layerName).postln;
                        } {
                            "Warning: No suitable melody found in JSON for layer %".format(layerName).postln;
                        };
                    } {
                        "Error: Failed to import melodies from JSON file".postln;
                    };
                } {
                    "Error: ~importLayerMelodyFromJSON function not available".postln;
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