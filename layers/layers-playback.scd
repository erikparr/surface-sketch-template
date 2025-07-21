/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                       DEPENDENT LAYERS - PLAYBACK                             ║
║                    ProcMod creation and timing logic                          ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         INITIALIZATION                                     │
// └─────────────────────────────────────────────────────────────────────────────┘

// Ensure ProcMod SynthDef is available on the server
~ensureProcModSynthDef = {
    var temp;
    
    "Forcing ProcMod SynthDef creation...".postln;
    
    // Force ProcMod to create and send its SynthDef
    temp = ProcMod.new(Env.asr(0.01, 1, 0.01), 1.0, \temp);
    temp = nil;  // Clean up
    
    // Force send to server
    if (SynthDescLib.global[\procmodenv_5216].notNil) {
        SynthDescLib.global[\procmodenv_5216].send(Server.default);
        "ProcMod SynthDef sent to server".postln;
    };
};

// Ensure SynthDef is available when layers system loads
~ensureProcModSynthDef.();


// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         PARENT PROCMOD CREATION                            │
// └─────────────────────────────────────────────────────────────────────────────┘

// Create the parent ProcMod that manages all layers
~createLayersParentProc = { |duration|
    var env, id, procMod;
    
    "DEBUG: ~createLayersParentProc called with duration: %".format(duration).postln;
    
    try {
        // Use an envelope with a release node to keep it sustained
        env = Env.asr(0.05, 1.0, 0.05, \lin);  // ASR envelope
        id = ("layersParent_" ++ Date.getDate.stamp).asSymbol;
        
        // Use provided duration or calculate from current settings
        duration = duration ?? { 4.0 };  // Default to 10 seconds if not specified
        
        "DEBUG: Creating ProcMod with id: %".format(id).postln;
        
        procMod = ProcMod.new(
            env,          // ASR envelope with release node
            1.0,          // Amplitude
            id,           // Unique ID
            nil,          // Group (create new)
            0,            // addAction
            1,            // target
            
            // Main function - returns a Task
            { |parentGroup, envbus|
            var mainTask = Task({
                var loopCount = 0;
                
                // Timing will be calculated at the start of each loop iteration
                
                while { ~layers.state.loopingMode or: { loopCount == 0 } } {
                    var layerProcs = [];
                    var activeLayerCount = 0;
                    var currentDuration;
                    
                    loopCount = loopCount + 1;
                    
                    // REMOVED: Bulk update processing - individual layers handle updates now
                    
                    // Determine duration at the START of each loop (like sketch system)
                    if (~layers.state.manualControl) {
                        // Manual control: read fresh value from knob each iteration
                        currentDuration = ~getLayersDurationFromKnob.();
                        "Loop %: Using MIDI knob duration: % seconds".format(
                            loopCount, currentDuration.round(0.01)
                        ).postln;
                    } {
                        // Normal mode: use provided duration
                        currentDuration = duration;
                        "Loop %: Using fixed duration: % seconds".format(
                            loopCount, currentDuration.round(0.01)
                        ).postln;
                    };
                    
                    // Calculate timing for all layers with current duration
                    ~layers.configs.keysValuesDo { |layerName, config|
                        if (config.enabled and: { config.melodyList.size > 0 }) {
                            var melodyKey = config.melodyList[0];
                            var melodyData = ~melodyDict[melodyKey];
                            var pattern = melodyData.patterns[0];
                            var noteCount = pattern.size;
                            var timingInfo;
                            
                            // Use timing calculation function if available
                            if (~calculateLayerTiming.notNil) {
                                timingInfo = ~calculateLayerTiming.(melodyData, currentDuration);
                                
                                ~layers.timingData[layerName] = (
                                    melodyKey: melodyKey,
                                    noteCount: noteCount,
                                    noteInterval: currentDuration / noteCount,  // Keep for backward compatibility
                                    duration: currentDuration,
                                    // New timing data
                                    startTimes: timingInfo.startTimes,
                                    durations: timingInfo.durations,
                                    waitTimes: timingInfo.waitTimes,
                                    hasTiming: melodyData.timing.notNil
                                );
                            } {
                                // Fallback to original calculation
                                ~layers.timingData[layerName] = (
                                    melodyKey: melodyKey,
                                    noteCount: noteCount,
                                    noteInterval: currentDuration / noteCount,
                                    duration: currentDuration,
                                    hasTiming: false
                                );
                            };
                        };
                    };
                    
                    if (~layers.state.loopingMode) {
                        "=== Starting dependent layers (loop %) ===".format(loopCount).postln;
                    } {
                        "=== Starting dependent layers ===".postln;
                    };
                    "Parent group: %, Duration: % seconds".format(parentGroup, currentDuration).postln;
                    
                    // Update expression parameters from MIDI before each loop
                    ~updateAllLayerExpressionParams.();
                    
                    // Only create ProcMods on first iteration or if they're not running
                    if (loopCount == 1) {
                        // First iteration - create all ProcMods
                        ~layers.configs.keysValuesDo { |layerName, config|
                            if (config.enabled and: { config.melodyList.size > 0 }) {
                                var proc = ~createLayerProcMod.(layerName, config, parentGroup);
                                ~layers.layerProcs[layerName] = proc;
                                layerProcs = layerProcs.add(proc);
                                activeLayerCount = activeLayerCount + 1;
                                "Created ProcMod for %".format(layerName).postln;
                            };
                        };
                    } {
                        // Subsequent iterations - reuse existing ProcMods
                        ~layers.layerProcs.keysValuesDo { |layerName, proc|
                            if (proc.notNil) {
                                layerProcs = layerProcs.add(proc);
                                activeLayerCount = activeLayerCount + 1;
                            };
                        };
                        "Reusing % existing layer ProcMods".format(activeLayerCount).postln;
                    };
                    
                    if (activeLayerCount > 0) {
                        if (loopCount == 1) {
                            "Starting % layer ProcMods simultaneously".format(activeLayerCount).postln;
                            
                            // Start all ProcMods only on first iteration
                            layerProcs.do { |proc|
                                proc.play;
                            };
                        };
                        
                        // Start CC envelopes for each active layer
                        ~layers.configs.keysValuesDo { |layerName, config|
                            if (config.enabled and: { config.melodyList.size > 0 }) {
                                var ccSynth = ~startLayerCCEnvelope.(layerName, currentDuration);
                                if (ccSynth.notNil) {
                                    // Store synth reference for potential cleanup
                                    ~layers.timingData[layerName].ccSynth = ccSynth;
                                };
                            };
                        };
                        
                        // Wait for the current duration
                        currentDuration.wait;
                        
                        // Don't release child ProcMods - they loop internally
                        
                        if (~layers.state.loopingMode.not) {
                            "All layers completed after % seconds".format(currentDuration).postln;
                        };
                    } {
                        "No active layers to play".warn;
                        // Exit the loop by setting looping mode to false
                        ~layers.state.loopingMode = false;
                    };
                    
                    // Add a small delay between loops to ensure clean transitions
                    if (~layers.state.loopingMode) {
                        0.2.wait;  // Small delay before next loop to sync with children
                    } {
                        "Parent stopping - looping mode is off".postln;
                    };
                };
            });
            
            // Return the task
            mainTask
        },
        
        // Release function - executes after ProcMod has fully released
        { |parentGroup, envbus|
            "Parent ProcMod released".postln;
            
            // Clear layer procs dictionary
            ~layers.layerProcs.clear;
            
            // Clear parent reference so system knows it's not playing
            ~layers.parentProc = nil;
            ~layers.state.startTime = nil;
        },
        
        // onRelease function - executes when release is triggered
        { |parentGroup, envbus|
            "Parent ProcMod releasing...".postln;
            
            // Release all CC synths first
            ~layers.timingData.keysValuesDo { |layerName, timing|
                if (timing.ccSynth.notNil) {
                    "Releasing CC synth for %".format(layerName).postln;
                    timing.ccSynth.release;
                    timing.ccSynth = nil;
                };
            };
            
            // Release all child ProcMods
            ~layers.layerProcs.do { |proc|
                if (proc.notNil and: { proc.isRunning }) {
                    "Releasing child ProcMod: %".format(proc.id).postln;
                    proc.release;
                };
            };
            
            // Don't set isPlaying to false here - let control functions handle it
        }
    );
        
        "DEBUG: ProcMod created successfully".postln;
        procMod  // Return the ProcMod
        
    } { |error|
        "ERROR creating parent ProcMod: %".format(error).postln;
        error.reportError;
        nil  // Return nil on error
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         LAYER PROCMOD CREATION                             │
// └─────────────────────────────────────────────────────────────────────────────┘

// Create a ProcMod for an individual layer - NEW DYNAMIC VERSION
~createLayerProcMod = { |layerName, config, parentGroup|
    var id = (layerName.asString ++ "_" ++ Date.getDate.stamp).asSymbol;
    var env = Env.asr(0.01, 1.0, 0.01, \lin);  // Quick attack/release envelope for child layers
    
    ProcMod.new(
        env,          // All ProcMods need an envelope
        1.0,          // Amplitude (can be individually controlled)
        id,           // Unique ID
        nil,          // Group (create new)
        0,            // addAction (head)
        parentGroup,  // Target is parent's group
        
        // Main function - returns a Task
        { |group, envbus|
            var task = Task({
                var iterationCount = 0;
                
                // Loop based on shared looping state
                while { ~layers.state.loopingMode or: { iterationCount == 0 } } {
                    var melodyData, pattern, noteCount, noteInterval, parentDuration;
                    var currentTiming, velocities, noteDurations, timing;
                    
                    iterationCount = iterationCount + 1;
                    
                    // GET DYNAMIC MELODY DATA - FRESH EACH LOOP ⭐
                    melodyData = ~getLayerMelodyDynamic.(layerName);
                    
                    if (melodyData.notNil) {
                        pattern = melodyData.patterns[iterationCount % melodyData.patterns.size];
                        velocities = melodyData.velocities;
                        noteDurations = melodyData.noteDurations;
                        
                        noteCount = pattern.size;
                        
                        // Read fresh timing data at the start of each iteration
                        currentTiming = ~layers.timingData[layerName];
                        if (currentTiming.notNil) {
                            noteInterval = currentTiming.noteInterval;
                            parentDuration = currentTiming.duration;
                        } {
                            // Fallback if timing data not available
                            parentDuration = 4.0;
                            noteInterval = parentDuration / noteCount;
                        };
                        
                        // CC envelope is now handled by parent ProcMod only
                        
                        if (iterationCount == 1) {  // Only log first iteration
                            if (currentTiming.notNil and: { currentTiming.hasTiming }) {
                                "Layer %: % notes using timing data, total: % seconds".format(
                                    layerName, noteCount, parentDuration
                                ).postln;
                            } {
                                "Layer %: % notes, equal interval: % seconds, total: % seconds".format(
                                    layerName, noteCount, noteInterval.round(0.001), parentDuration
                                ).postln;
                            };
                        };
                        
                        // Play notes using existing timing logic - use waitTimes from currentTiming if available
                        if (currentTiming.notNil and: { currentTiming.hasTiming } and: { currentTiming.waitTimes.notNil }) {
                            // Use pre-calculated timing data
                            var waitTimes = currentTiming.waitTimes;
                            var durations = currentTiming.durations;
                            var currentTime = 0;
                            var finalWait;
                            
                            noteCount.do { |noteIndex|
                                var note = pattern[noteIndex];
                                var waitTime = waitTimes[noteIndex];
                                var noteDuration = durations[noteIndex];
                                var velocity, processedNote;
                                var isFirstNote = (noteIndex == 0);
                                var isLastNote = (noteIndex == (noteCount - 1));
                                
                                // Check manual control mode for velocity
                                if (~layers.state.manualControl) {
                                    // MANUAL CONTROL: Use Row 1, Knob 3 directly
                                    if (~midiController.notNil) {
                                        var knobValue = ~midiController.getKnobRow1(3);
                                        velocity = knobValue.linlin(0, 127, 1, 127).asInteger;
                                        "DEBUG: Manual control - knob raw: %, velocity: %".format(knobValue.round(0.001), velocity).postln;
                                    } {
                                        velocity = 100; // Default if no MIDI controller
                                        "DEBUG: Manual control - using default velocity = %".format(velocity).postln;
                                    };
                                } {
                                    // Use melody velocity data
                                    velocity = velocities[noteIndex] ? 127;
                                    "DEBUG: Using melody velocity data = %".format(velocity).postln;
                                };
                                
                                // Wait before playing the note
                                if (waitTime > 0) {
                                    waitTime.wait;
                                    currentTime = currentTime + waitTime;
                                };
                                
                                ~playLayerNote.(
                                    layerName,
                                    note,
                                    velocity,
                                    noteDuration
                                );
                            };
                            
                            // Wait for any remaining time after last note
                            finalWait = parentDuration - currentTime;
                            if (finalWait > 0) {
                                finalWait.wait;
                            };
                        } {
                            // Equal timing fallback
                            noteInterval = parentDuration / noteCount;
                            pattern.do { |note, i|
                                var velocity, processedNote;
                                var duration = noteDurations[i] ? 0.5;
                                var isFirstNote = (i == 0);
                                var isLastNote = (i == (noteCount - 1));
                                
                                // Check manual control mode for velocity
                                if (~layers.state.manualControl) {
                                    // MANUAL CONTROL: Use Row 1, Knob 3 directly
                                    if (~midiController.notNil) {
                                        var knobValue = ~midiController.getKnobRow1(3);
                                        velocity = knobValue.linlin(0, 127, 1, 127).asInteger;
                                        "DEBUG: Manual control (equal timing) - knob raw: %, velocity: %".format(knobValue.round(0.001), velocity).postln;
                                    } {
                                        velocity = 100; // Default if no MIDI controller
                                        "DEBUG: Manual control (equal timing) - using default velocity = %".format(velocity).postln;
                                    };
                                } {
                                    // Use melody velocity data
                                    velocity = velocities[i] ? 127;
                                    "DEBUG: Using melody velocity data (equal timing) = %".format(velocity).postln;
                                };
                                
                                ~playLayerNote.(
                                    layerName,
                                    note,
                                    velocity,
                                    duration
                                );
                                noteInterval.wait;
                            };
                        };
                        
                        if (iterationCount == 1) {  // Only log first iteration
                            "Layer % completed all % notes".format(layerName, noteCount).postln;
                        };
                    } {
                        // No melody data, just wait
                        var waitTime = (~layers.timingData.totalDuration ? 4.0);
                        waitTime.wait;
                        
                        if (iterationCount == 1) {
                            "Layer %: No melody data, waiting % seconds".format(layerName, waitTime).postln;
                        };
                    };
                    
                    // Check if we should continue looping
                    if (~layers.state.loopingMode) {
                        // Small gap before next iteration
                        0.1.wait;
                    } {
                        "Layer % stopping - looping mode is off".format(layerName).postln;
                    };
                };
            });
            
            // Return the task
            task
        },
        
        // Release function - executes after ProcMod has fully released
        { |group, envbus|
            "Layer % ProcMod released".format(layerName).postln;
            
            // Remove from layer procs dictionary
            ~layers.layerProcs[layerName] = nil;
        },
        
        // onRelease function - executes when release is triggered
        { |group, envbus|
            "Releasing layer % ProcMod...".format(layerName).postln;
            
            // Could add per-layer cleanup here if needed
            // For example, releasing any stuck notes for this layer
        }
    );
};


// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         DIRECT NOTE PLAYBACK                               │
// └─────────────────────────────────────────────────────────────────────────────┘

// Direct function to play a note on a layer's VST group
~playLayerNote = { |layerName, note, velocity, duration|
    // Get the VST group for this layer
    var config = ~layers.configs[layerName];
    var vstGroup = config.vstGroup;
    
    // Route to appropriate VST instances (if vstManager exists)
    if (~vstManager.notNil) {
        var instances = ~vstManager.getTargetInstances(vstGroup);
        
        instances.do { |vst|
            vst.midi.noteOn(0, note, velocity);
            
            if (duration > 0) {
                SystemClock.sched(duration, {
                    vst.midi.noteOff(0, note, 0);
                    nil  // Return nil to stop scheduling
                });
            };
        };
    } {
        "Warning: ~vstManager not available, cannot route note to VST".postln;
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                    LAYER-SPECIFIC EXPRESSION CONTROL                       │
// └─────────────────────────────────────────────────────────────────────────────┘

// Update expression parameters for a layer from MIDI knobs
~updateLayerExpressionParams = { |layerName|
    var rowNum = switch(layerName,
        \layer1, { 1 },
        \layer2, { 2 },
        \layer3, { 3 }
    );
    var config = ~layers.configs[layerName];
    var knob4, knob5, knob6;
    
    if (~midiController.notNil && config.notNil && config.ccControl.notNil) {
        // Check if mapping system is intercepting these values
        if (~midiController.mappingMode.notNil && ~midiController.mappingMode) {
            "Warning: MIDI mapping mode is active, knob values may be intercepted".postln;
        };
        
        // Read expression parameters from appropriate row
        // Position 5: expression min
        config.ccControl.expressionMin = ~midiController.getKnobRow(rowNum, 5);
        
        // Position 6: expression max
        config.ccControl.expressionMax = ~midiController.getKnobRow(rowNum, 6);
        
        // Position 4: expression duration scalar
        config.ccControl.expressionDurationScalar = ~midiController.getKnobRow(rowNum, 4).linlin(0.0, 1.0, 0.001, 1.0);
        
        // Ensure max > min
        if (config.ccControl.expressionMax <= config.ccControl.expressionMin) {
            config.ccControl.expressionMax = config.ccControl.expressionMin + 1;
        };
        
        // Debug output for knob changes
        knob4 = ~midiController.getKnobRow(rowNum, 4);
        knob5 = ~midiController.getKnobRow(rowNum, 5);
        knob6 = ~midiController.getKnobRow(rowNum, 6);
        
        // "[Layer %] Knob values - Pos 4: % (DurScale: %), Pos 5: % (Min: %), Pos 6: % (Max: %)".format(
        //     layerName,
        //     knob4.round(0.01), config.ccControl.expressionDurationScalar.round(0.01),
        //     knob5.round(0.01), config.ccControl.expressionMin,
        //     knob6.round(0.01), config.ccControl.expressionMax
        // ).postln;
    };
};

// Start CC envelope for a specific layer
~startLayerCCEnvelope = { |layerName, duration|
    var config = ~layers.configs[layerName];
    var ccControl = config.ccControl;
    var synthDefName = switch(layerName,
        \layer1, { \ccEnvelope1 },
        \layer2, { \ccEnvelope2 },
        \layer3, { \ccEnvelope3 }
    );
    
    if (ccControl.notNil && ccControl.enabled) {
        var scaledDuration = duration * ccControl.expressionDurationScalar;
        var attackTime = scaledDuration * ccControl.expressionPeakPos;
        var releaseTime = scaledDuration * (1.0 - ccControl.expressionPeakPos);
        var ccSynth;
        
        "Starting % envelope - Duration: %s, Attack: %s, Release: %s".format(
            synthDefName, 
            scaledDuration.round(0.01),
            attackTime.round(0.01),
            releaseTime.round(0.01)
        ).postln;
        
        // Create expression synth for this layer
        ccSynth = Synth(synthDefName, [
            \start, ccControl.expressionMin,
            \peak, ccControl.expressionMax,
            \end, ccControl.expressionMin,
            \attackTime, attackTime,
            \releaseTime, releaseTime,
            \chanIndex, 0,  // All layers use channel 0
            \ccNum, ccControl.expressionCC,
            \attackCurve, ccControl.expressionShape,
            \releaseCurve, ccControl.expressionShape
        ]);
        
        // Return synth for tracking
        ccSynth
    } {
        nil
    };
};

// Update all layer expression parameters from MIDI
~updateAllLayerExpressionParams = {
    [\layer1, \layer2, \layer3].do { |layerName|
        ~updateLayerExpressionParams.(layerName);
    };
};

// Test that functions are defined
"DEBUG: Testing function definitions...".postln;
"  ~createLayersParentProc is: %".format(~createLayersParentProc.class).postln;
"  ~createLayerProcMod is: %".format(~createLayerProcMod.class).postln;

"Dependent layers playback system loaded".postln;