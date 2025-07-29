/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                          LAYERS LIVE MELODY MODE                              ║
║                   Real-time melody updates via OSC                            ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

(
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                            OSC RECEIVER SETUP                               │
// └─────────────────────────────────────────────────────────────────────────────┘

~initLiveMelodyOSC = {
    "Initializing live melody OSC receivers...".postln;
    
    [\layer1, \layer2, \layer3].do { |layerName|
        var oscPath = ("/liveMelody/update/" ++ layerName).asSymbol;
        var defName = ("liveMelody_" ++ layerName).asSymbol;
        
        OSCdef(
            defName,
            { |msg, time, addr, recvPort|
                var jsonData = msg[1].asString;
                "Received live melody update for % from %:%".format(
                    layerName, addr.ip, addr.port
                ).postln;
                
                try {
                    ~queueLiveMelodyUpdate.(layerName, jsonData);
                } { |error|
                    "Error processing live melody update: %".format(error).error;
                    "Error class: %".format(error.class).postln;
                    if (error.respondsTo(\what)) {
                        "Error what: %".format(error.what).postln;
                    };
                    if (error.respondsTo(\receiver)) {
                        "Error receiver: %".format(error.receiver).postln;
                    };
                    error.reportError;
                };
            },
            oscPath
        );
        
        "OSC receiver ready: %".format(oscPath).postln;
    };
    
    "Live melody OSC receivers initialized".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                          UPDATE QUEUE MANAGEMENT                            │
// └─────────────────────────────────────────────────────────────────────────────┘

~queueLiveMelodyUpdate = { |layerName, jsonData|
    var melodyData, validatedData;
    
    "DEBUG: Received JSON data for %: %".format(layerName, jsonData.asString.keep(200)).postln;
    
    // Parse JSON
    try {
        // Use JSONlib.convertToSC which is the correct method
        if (JSONlib.notNil) {
            melodyData = JSONlib.convertToSC(jsonData, useEvent: true);
            "Successfully parsed JSON with JSONlib".postln;
        } {
            "JSONlib not available - trying parseJSON method".postln;
            melodyData = jsonData.parseJSON;
        };
    } { |error|
        "Failed to parse JSON: %".format(error).error;
        "JSON data received: %".format(jsonData.keep(500)).postln;
        ^nil;
    };
    
    // Validate data
    validatedData = ~validateLiveMelodyData.(melodyData);
    
    if (validatedData.notNil) {
        // Store in pending updates
        ~layers.state.pendingUpdates[layerName] = validatedData;
        
        "Queued melody update for %: % notes".format(
            layerName, 
            validatedData.notes.size
        ).postln;
        
        // Log timing info if present
        if (validatedData.timing.notNil) {
            "  Timing: %".format(validatedData.timing.collect(_.round(0.001))).postln;
        };
    } {
        "Invalid melody data for %".format(layerName).error;
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                           DATA VALIDATION                                   │
// └─────────────────────────────────────────────────────────────────────────────┘

~validateLiveMelodyData = { |data|
    var notes, timing, metadata, expressionOverride;
    var noteCount, timingSum;
    
    // Check for required fields
    if (data.isNil or: { data.notes.isNil }) {
        "Missing required 'notes' field".error;
        ^nil;
    };
    
    notes = data.notes;
    timing = data.timing;
    metadata = data.metadata ? ();
    expressionOverride = data.expressionOverride;
    
    // Validate notes array
    if (notes.isArray.not or: { notes.size == 0 }) {
        "Notes must be a non-empty array".error;
        ^nil;
    };
    
    // Validate each note
    notes.do { |note, i|
        if (note.midi.isNil or: { note.midi < 0 } or: { note.midi > 127 }) {
            "Invalid MIDI note at index %: %".format(i, note.midi).error;
            ^nil;
        };
        
        if (note.vel.isNil or: { note.vel < 0 } or: { note.vel > 1.0 }) {
            "Invalid velocity at index %: %".format(i, note.vel).error;
            ^nil;
        };
        
        if (note.dur.isNil or: { note.dur <= 0 }) {
            "Invalid duration at index %: %".format(i, note.dur).error;
            ^nil;
        };
    };
    
    noteCount = notes.size;
    
    // Validate timing array if present
    if (timing.notNil) {
        if (timing.isArray.not) {
            "Timing must be an array".error;
            ^nil;
        };
        
        if (timing.size != (noteCount + 1)) {
            "Timing array size (%) doesn't match expected size (%) for % notes".format(
                timing.size, noteCount + 1, noteCount
            ).error;
            ^nil;
        };
        
        // Check that timing sums to 1.0
        timingSum = timing.sum;
        if ((timingSum - 1.0).abs > 0.001) {
            "Timing array sum (%) is not 1.0".format(timingSum).error;
            ^nil;
        };
        
        // Check all values are positive
        timing.do { |val, i|
            if (val < 0) {
                "Negative timing value at index %: %".format(i, val).error;
                ^nil;
            };
        };
    };
    
    // Validate expression override if present
    if (expressionOverride.notNil) {
        if (expressionOverride.expressionMin.notNil) {
            var min = expressionOverride.expressionMin;
            if (min < 0 or: { min > 127 }) {
                "Invalid expressionMin: %".format(min).error;
                ^nil;
            };
        };
        
        if (expressionOverride.expressionMax.notNil) {
            var max = expressionOverride.expressionMax;
            if (max < 0 or: { max > 127 }) {
                "Invalid expressionMax: %".format(max).error;
                ^nil;
            };
        };
        
        if (expressionOverride.expressionDurationScalar.notNil) {
            var scalar = expressionOverride.expressionDurationScalar;
            if (scalar < 0.1 or: { scalar > 1.0 }) {
                "Invalid expressionDurationScalar: %".format(scalar).error;
                ^nil;
            };
        };
    };
    
    // Return validated data
    (
        notes: notes,
        timing: timing,
        metadata: metadata,
        expressionOverride: expressionOverride
    )
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         DATA CONVERSION                                     │
// └─────────────────────────────────────────────────────────────────────────────┘

~convertLiveMelodyData = { |data|
    var notes = data.notes;
    var patterns, velocities, durations;
    var melodyData;
    
    // Extract arrays from note objects
    patterns = notes.collect { |n| n.midi };
    velocities = notes.collect { |n| (n.vel * 127).asInteger };
    durations = notes.collect { |n| n.dur };
    
    // Build melody dictionary entry
    melodyData = (
        name: "Live Melody",
        patterns: [patterns],  // Wrap in array for compatibility
        velocities: velocities,
        timing: data.timing,
        noteDurations: durations,
        durationType: data.metadata.durationType ? "absolute"
    );
    
    // Add metadata if present
    if (data.metadata.notNil) {
        melodyData.metadata = data.metadata;
    };
    
    melodyData
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                    APPLY PENDING UPDATES                                    │
// └─────────────────────────────────────────────────────────────────────────────┘

~applyPendingMelodyUpdates = {
    "INFO: Bulk update function called, but individual layers now handle updates automatically".postln;
    "Pending updates: %".format(~layers.state.pendingUpdates.keys).postln;
    
    // This function is now mainly for debugging/status
    ^nil;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                      DYNAMIC MELODY GETTERS                                 │
// └─────────────────────────────────────────────────────────────────────────────┘

~getLayerMelodyDynamic = { |layerName|
    var config = ~layers.configs[layerName];
    var melodyKey, melodyData;
    
    // Check for pending live updates first
    if (~layers.state.liveMelodyMode and: { 
        ~layers.state.pendingUpdates[layerName].notNil 
    }) {
        // Apply pending update immediately
        ~applyPendingUpdateForLayer.(layerName);
    };
    
    // Return current melody data
    if (config.melodyList.notNil and: { config.melodyList.size > 0 }) {
        melodyKey = config.melodyList[0];
        melodyData = ~melodyDict[melodyKey];
        
        "DEBUG ~getLayerMelodyDynamic: layer=%, melodyKey=%, melodyData keys=%".format(
            layerName, melodyKey, 
            if(melodyData.notNil, { melodyData.keys.asArray.sort }, { "nil" })
        ).postln;
        
        if (melodyData.notNil) {
            "  patterns size: %".format(melodyData.patterns !? _.size ?? "nil").postln;
            "  metadata: %".format(melodyData.metadata).postln;
            "  durationType: %".format(melodyData.durationType).postln;
        };
    };
    
    melodyData
};

~applyPendingUpdateForLayer = { |layerName|
    var melodyData = ~layers.state.pendingUpdates[layerName];
    var tempKey = ("live_" ++ layerName).asSymbol;
    var config = ~layers.configs[layerName];
    
    if (melodyData.notNil) {
        // Convert and store
        ~melodyDict[tempKey] = ~convertLiveMelodyData.(melodyData);
        config.melodyList = [tempKey];
        
        // Apply expression overrides if present
        if (melodyData.expressionOverride.notNil) {
            var override = melodyData.expressionOverride;
            var ccControl = config.ccControl;
            
            if (override.expressionMin.notNil) {
                ccControl.expressionMin = override.expressionMin;
            };
            if (override.expressionMax.notNil) {
                ccControl.expressionMax = override.expressionMax;
            };
            if (override.expressionDurationScalar.notNil) {
                ccControl.expressionDurationScalar = override.expressionDurationScalar;
            };
        };
        
        // Clear pending update
        ~layers.state.pendingUpdates[layerName] = nil;
        
        "LIVE UPDATE APPLIED: % during playback".format(layerName).postln;
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         CONTROL FUNCTIONS                                   │
// └─────────────────────────────────────────────────────────────────────────────┘

~enableLiveMelodyMode = {
    if (~layers.state.liveMelodyMode) {
        "Live melody mode already enabled".postln;
        ^nil;
    };
    
    ~layers.state.liveMelodyMode = true;
    ~layers.state.pendingUpdates = Dictionary.new;  // Ensure dictionary exists
    ~initLiveMelodyOSC.();
    
    "Live melody mode enabled - listening for OSC updates".postln;
    "Send updates to: /liveMelody/update/layer1, layer2, or layer3".postln;
};

~disableLiveMelodyMode = {
    if (~layers.state.liveMelodyMode.not) {
        "Live melody mode already disabled".postln;
        ^nil;
    };
    
    ~layers.state.liveMelodyMode = false;
    
    // Free OSC receivers
    [\layer1, \layer2, \layer3].do { |layer|
        OSCdef(("liveMelody_" ++ layer).asSymbol).free;
    };
    
    // Clear pending updates
    ~layers.state.pendingUpdates.clear;
    
    "Live melody mode disabled".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                          UTILITY FUNCTIONS                                  │
// └─────────────────────────────────────────────────────────────────────────────┘

// Convert SuperCollider Events to Dictionary format for JSON
~convertEventToDict = { |data|
    var convertValue = { |val|
        case 
        { val.isKindOf(Event) } {
            // Convert Event to Dictionary
            var dict = Dictionary.new;
            val.keysValuesDo { |key, value|
                dict[key.asString] = convertValue.(value);
            };
            dict;
        }
        { val.isKindOf(Array) } {
            // Convert Array recursively
            val.collect { |item| convertValue.(item) };
        }
        { val.isKindOf(Symbol) } {
            // Convert Symbol to String
            val.asString;
        }
        { 
            // Keep as is (numbers, strings, etc.)
            val;
        };
    };
    
    convertValue.(data);
};

// Test function to send update from within SC
~sendLiveMelodyUpdate = { |layerName, melodyData|
    var jsonString;
    var addr = NetAddr("127.0.0.1", 57120);  // Loopback to SC
    var path = ("/liveMelody/update/" ++ layerName).asSymbol;
    
    "DEBUG: Function called with layer: % data: %".format(layerName, melodyData).postln;
    
    // Check if conversion function exists
    if (~convertEventToDict.isNil) {
        "ERROR: ~convertEventToDict function not defined!".error;
        ^nil;
    };
    
    "DEBUG: Attempting to convert data: %".format(melodyData).postln;
    
    // Convert to JSON string
    try {
        if (JSONlib.notNil) {
            var convertedData;
            "Using JSONlib.stringify".postln;
            // Convert SuperCollider Events to Dictionary format for JSONlib
            convertedData = ~convertEventToDict.(melodyData);
            "DEBUG: Converted data: %".format(convertedData).postln;
            
            // Use the correct JSONlib method
            jsonString = JSONlib.convertToJSON(convertedData);
        } {
            "Warning: JSONlib not available, trying .asJSON".warn;
            if (melodyData.respondsTo(\asJSON)) {
                jsonString = melodyData.asJSON;
            } {
                "Error: No JSON conversion method available".error;
                ^nil;
            };
        };
    } { |error|
        "Error converting to JSON: %".format(error).error;
        ^nil;
    };
    
    "DEBUG: Sending JSON: %".format(jsonString.keep(200)).postln;
    addr.sendMsg(path, jsonString);
    "Sent test update to %".format(path).postln;
};

// Get current live melody status
~getLiveMelodyStatus = {
    var status = (
        enabled: ~layers.state.liveMelodyMode,
        pendingUpdates: Dictionary.new
    );
    
    if (~layers.state.pendingUpdates.notNil) {
        ~layers.state.pendingUpdates.keysValuesDo { |layer, data|
            if (data.notNil) {
                status.pendingUpdates[layer] = data.notes.size;
            };
        };
    };
    
    status
};

// Clear all pending updates
~clearLiveMelodyUpdates = {
    if (~layers.state.pendingUpdates.notNil) {
        ~layers.state.pendingUpdates.clear;
        "Cleared all pending live melody updates".postln;
    };
};

"Layers live melody system loaded successfully".postln;
);