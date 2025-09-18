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

// DEPRECATED: ProcMod SynthDef initialization - no longer needed for direct approach
// ~ensureProcModSynthDef = {
//     var temp;
//
//     "Forcing ProcMod SynthDef creation...".postln;
//
//     // Force ProcMod to create and send its SynthDef
//     temp = ProcMod.new(Env.asr(0.01, 1, 0.01), 1.0, \temp);
//     temp = nil;  // Clean up
//
//     // Force send to server
//     if (SynthDescLib.global[\procmodenv_5216].notNil) {
//         SynthDescLib.global[\procmodenv_5216].send(Server.default);
//         "ProcMod SynthDef sent to server".postln;
//     };
// };

// Note: ProcMod SynthDef creation skipped for direct approach


// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         PARENT PROCMOD CREATION (DEPRECATED)               │
// └─────────────────────────────────────────────────────────────────────────────┘

// DEPRECATED: Create the parent ProcMod that manages all layers
// This function is kept for backward compatibility but should not be used for new code
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
                    
                    // Set up VST routing for sketch system compatibility
                    if (loopCount == 1) {  // Only on first loop
                        if (~layers.configs[\layer1].notNil && ~setActiveVSTGroup.notNil) {
                            ~setActiveVSTGroup.(~layers.configs[\layer1].vstGroup);
                        };
                        if (~layers.configs[\layer2].notNil && ~setActiveVSTGroup_2.notNil) {
                            ~setActiveVSTGroup_2.(~layers.configs[\layer2].vstGroup);
                        };
                        // Note: Layer 3 doesn't have a corresponding sketch system function
                    };
                    
                    // Determine duration at the START of each loop (like sketch system)
                    if (~layers.state.manualControl) {
                        // Manual control: read fresh value from knob each iteration
                        currentDuration = ~getLayersDurationFromKnob.();
                        "Loop %: Using MIDI knob duration: % seconds".format(
                            loopCount, currentDuration.round(0.01)
                        ).postln;
                        
                        // Update note duration scalars for each layer from their respective rows
                        ~updateAllLayerNoteDurationScalars.();
                    } {
                        // Normal mode: use provided duration
                        currentDuration = duration;
                        "Loop %: Using fixed duration: % seconds".format(
                            loopCount, currentDuration.round(0.01)
                        ).postln;
                        // Reset all layers to 100% when manual control is off
                        ~layers.configs.keysValuesDo { |layerName, config|
                            config.noteDurationScalar = 1.0;
                        };
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
                                timingInfo = ~calculateLayerTiming.(melodyData, currentDuration, layerName);
                                
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
                            var proc;
                            if (config.enabled and: { config.melodyList.size > 0 }) {
                                proc = ~createLayerProcMod.(layerName, config, parentGroup);
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
                        
                        // Start CC envelopes based on mode
                        if (~layers.state.singleNoteCCMode) {
                            // Single note mode: CC envelopes will be triggered per note in ~playLayerNote
                            "Single note CC mode active - envelopes will trigger per note".postln;
                        } {
                            // Normal mode: Start CC envelopes for each active layer
                            ~layers.configs.keysValuesDo { |layerName, config|
                                var ccSynth;
                                if (config.enabled and: { config.melodyList.size > 0 }) {
                                    ccSynth = ~startLayerCCEnvelope.(layerName, currentDuration);
                                    if (ccSynth.notNil) {
                                        // Store synth reference for potential cleanup
                                        ~layers.timingData[layerName].ccSynth = ccSynth;
                                    };
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

            // Clean up all bend synths first
            ~cleanupAllBendSynths.();

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

            // Stop all windowing tasks
            if (~stopAllWindows.notNil) {
                ~stopAllWindows.();
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
// │                         LAYER PROCMOD CREATION (DEPRECATED)                │
// └─────────────────────────────────────────────────────────────────────────────┘

// DEPRECATED: Create a ProcMod for an individual layer - kept for backward compatibility
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
                    var waitCount;
                    
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
                        
                        // Check if windowing mode should be used
                        if (~shouldUseWindowing.notNil && ~shouldUseWindowing.(layerName)) {
                            // Use windowing playback
                            var windowingTask;
                            
                            "Layer % using WINDOWING mode".format(layerName).postln;
                            
                            windowingTask = ~createWindowingTask.(layerName, config, parentDuration);
                            if (windowingTask.notNil) {
                                // Store the task for tracking
                                ~layers.windowTasks[layerName] = windowingTask;
                                windowingTask.play;
                                
                                // Wait for the windowing task to complete with timeout
                                waitCount = 0;
                                while { windowingTask.isPlaying and: { waitCount < 1000 } } {
                                    0.1.wait;
                                    waitCount = waitCount + 1;
                                    
                                    // Check if parent is still running
                                    if (~layers.parentProc.isNil or: { ~layers.parentProc.isRunning.not }) {
                                        "Parent stopped, stopping windowing task".postln;
                                        windowingTask.stop;
                                        waitCount = 1000; // Force loop exit
                                    };
                                };
                                
                                if (waitCount >= 1000) {
                                    "Windowing task timeout, forcing stop".warn;
                                    windowingTask.stop;
                                };
                                
                                // Clean up
                                ~layers.windowTasks[layerName] = nil;
                                ~stopLayerWindows.(layerName);
                            } {
                                "Failed to create windowing task for layer %".format(layerName).warn;
                            };
                        } {
                            // Normal playback - use existing timing logic
                        if (currentTiming.notNil and: { currentTiming.hasTiming } and: { currentTiming.waitTimes.notNil }) {
                            // Use pre-calculated timing data
                            var waitTimes, durations, currentTime, finalWait;
                            waitTimes = currentTiming.waitTimes;
                            durations = currentTiming.durations;
                            currentTime = 0;
                            
                            noteCount.do { |noteIndex|
                                var note, waitTime, noteDuration, velocity, processedNote, isFirstNote, isLastNote;
                                note = pattern[noteIndex];
                                waitTime = waitTimes[noteIndex];
                                noteDuration = durations[noteIndex];
                                isFirstNote = (noteIndex == 0);
                                isLastNote = (noteIndex == (noteCount - 1));
                                
                                // Check manual control mode for velocity
                                if (~layers.state.manualControl) {
                                    // MANUAL CONTROL: Use Row 1, Knob 3 directly
                                    if (~midiController.notNil) {
                                        var knobValue;
                                        knobValue = ~midiController.getKnobRow1(3);
                                        velocity = knobValue.linlin(0, 127, 1, 127).asInteger;
                                    } {
                                        velocity = 100; // Default if no MIDI controller
                                    };
                                } {
                                    // Use melody velocity data
                                    velocity = velocities[noteIndex] ? 127;
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
                                    noteDuration,
                                    noteIndex
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
                                var velocity, processedNote, duration, isFirstNote, isLastNote;
                                duration = noteDurations[i] ? 0.5;
                                isFirstNote = (i == 0);
                                isLastNote = (i == (noteCount - 1));
                                
                                // Check manual control mode for velocity
                                if (~layers.state.manualControl) {
                                    // MANUAL CONTROL: Use Row 1, Knob 3 directly
                                    if (~midiController.notNil) {
                                        var knobValue;
                                        knobValue = ~midiController.getKnobRow1(3);
                                        velocity = knobValue.linlin(0, 127, 1, 127).asInteger;
                                    } {
                                        velocity = 100; // Default if no MIDI controller
                                    };
                                } {
                                    // Use melody velocity data
                                    velocity = velocities[i] ? 127;
                                };
                                
                                ~playLayerNote.(
                                    layerName,
                                    note,
                                    velocity,
                                    duration,
                                    i
                                );
                                noteInterval.wait;
                            };
                        };
                        
                        if (iterationCount == 1) {  // Only log first iteration
                            "Layer % completed all % notes".format(layerName, noteCount).postln;
                        };
                        }; // End of windowing check
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

            // Clean up bend synths for this layer
            ~cleanupLayerBendSynths.(layerName);

            // Could add per-layer cleanup here if needed
            // For example, releasing any stuck notes for this layer
        }
    );
};


// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         DIRECT NOTE PLAYBACK                               │
// └─────────────────────────────────────────────────────────────────────────────┘

// Direct function to play a note on a layer's VST group
~playLayerNote = { |layerNameOrGroup, note, velocity, duration, noteIndex|
    // Handle both layer names and direct VST group names
    var config, vstGroup, bendSynth, noteKey;

    // Check if it's a layer name first
    config = ~layers.configs[layerNameOrGroup];
    if (config.notNil) {
        // It's a layer name, get VST group from config
        vstGroup = config.vstGroup;
    } {
        // Assume it's already a VST group name (for windowing)
        vstGroup = layerNameOrGroup;
    };

    "DEBUG ~playLayerNote: input=%, note=%, vel=%, dur=%, vstGroup=%".format(
        layerNameOrGroup, note, velocity, duration, vstGroup
    ).postln;

    // Create bend envelope if bend mode enabled and this is an actual layer
    if (config.notNil and: { ~layers.state.bendMode } and: { config.bendControl.enabled }) {
        bendSynth = ~createLayerBendEnvelope.(
            layerNameOrGroup, note, duration, noteIndex ? 0
        );

        // Store reference for cleanup using unique key
        if (bendSynth.notNil) {
            noteKey = note.asString ++ "_" ++ (noteIndex ? 0).asString ++ "_" ++ Date.getDate.stamp;
            config.bendControl.activeBendSynths.put(noteKey, bendSynth);

            // Schedule cleanup of bend synth when note ends
            if (duration > 0) {
                SystemClock.sched(duration + 0.1, {  // Small buffer after note ends
                    ~cleanupLayerBendSynth.(layerNameOrGroup, noteKey);
                    nil  // Return nil to stop scheduling
                });
            };
        };
    };

    // Route to appropriate VST instances (if vstManager exists)
    if (~vstManager.notNil) {
        var instances = ~vstManager.getTargetInstances(vstGroup);

        "DEBUG: Found % VST instances for group %".format(instances.size, vstGroup).postln;

        instances.do { |vst, i|
            var midiVelocity;
            // Check if velocity is already in MIDI range (manual control) or normalized (melody data)
            if (~layers.state.manualControl && velocity > 1) {
                // Manual control: velocity already in MIDI range (1-127)
                midiVelocity = velocity.asInteger.clip(1, 127);
            } {
                // Melody data: velocity in normalized range (0-1), convert to MIDI
                midiVelocity = (velocity * 127).round.asInteger.clip(1, 127);
            };
            "DEBUG: Sending noteOn to VST instance % - note=%, vel=% (MIDI: %)".format(i, note, velocity, midiVelocity).postln;
            vst.midi.noteOn(0, note, midiVelocity);

            if (duration > 0) {
                SystemClock.sched(duration, {
                    "DEBUG: Sending noteOff to VST instance % - note=%".format(i, note).postln;
                    vst.midi.noteOff(0, note, 0);
                    nil  // Return nil to stop scheduling
                });
            };
        };
    } {
        "ERROR: ~vstManager not available, cannot route note to VST".postln;
    };

    // Trigger per-note CC envelope if single note mode is enabled (only for actual layers)
    if (config.notNil && ~layers.state.singleNoteCCMode) {
        ~startPerNoteCCEnvelope.(layerNameOrGroup, duration);
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

// Update note duration scalar for a layer from MIDI knobs
~updateLayerNoteDurationScalar = { |layerName|
    var rowNum = switch(layerName,
        \layer1, { 1 },
        \layer2, { 2 },
        \layer3, { 3 }
    );
    var config = ~layers.configs[layerName];
    
    if (~midiController.notNil && config.notNil) {
        var knobValue = ~midiController.getKnobRow(rowNum, 2);
        config.noteDurationScalar = knobValue.linlin(0, 127, 0.01, 1.5);
        "Layer % note duration scalar: %% (Row % Knob 2)".format(
            layerName, 
            (config.noteDurationScalar * 100).round(1),
            rowNum
        ).postln;
    };
};

// Update all layer note duration scalars from MIDI
~updateAllLayerNoteDurationScalars = {
    [\layer1, \layer2, \layer3].do { |layerName|
        ~updateLayerNoteDurationScalar.(layerName);
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                    PER-NOTE CC ENVELOPE SYSTEM                             │
// └─────────────────────────────────────────────────────────────────────────────┘

// Start CC envelope for a single note
~startPerNoteCCEnvelope = { |layerName, noteDuration|
    var config = ~layers.configs[layerName];
    var ccControl = config.ccControl;
    var synthDefName = switch(layerName,
        \layer1, { \ccEnvelope1 },
        \layer2, { \ccEnvelope2 },
        \layer3, { \ccEnvelope3 }
    );

    if (ccControl.notNil && ccControl.enabled && ~layers.state.singleNoteCCMode) {
        var scaledDuration = noteDuration;  // Use note duration directly
        var attackTime = scaledDuration * ccControl.expressionPeakPos;
        var releaseTime = scaledDuration * (1.0 - ccControl.expressionPeakPos);
        var newSynth;

        // Clean up any existing per-note CC synth for this layer
        var existingSynth = ~layers.directState.perNoteCCSynths[layerName];
        if (existingSynth.notNil) {
            existingSynth.free;
            };

        // Create new per-note CC synth
        newSynth = Synth(synthDefName, [
            \start, ccControl.expressionMin,
            \peak, ccControl.expressionMax,
            \end, ccControl.expressionMin,
            \attackTime, attackTime,
            \releaseTime, releaseTime,
            \chanIndex, 0,
            \ccNum, ccControl.expressionCC,
            \attackCurve, ccControl.expressionShape,
            \releaseCurve, ccControl.expressionShape
        ]);

        // Track the new synth
        ~layers.directState.perNoteCCSynths[layerName] = newSynth;
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                    DIRECT REPLACEMENT FUNCTIONS (NO PROCMOD)               │
// └─────────────────────────────────────────────────────────────────────────────┘

// Resource cleanup utility
~cleanupDirectResources = {
    var ds = ~layers.directState;

    "Cleaning up direct resources...".postln;

    // Stop and clear tasks
    ds.childTasks.do { |task|
        if (task.notNil) { task.stop };
    };
    ds.childTasks.clear;

    if (ds.parentTask.notNil) {
        ds.parentTask.stop;
        ds.parentTask = nil;
    };

    // Free groups (automatically frees child synths)
    ds.childGroups.do { |group|
        if (group.notNil) { group.free };
    };
    ds.childGroups.clear;

    if (ds.parentGroup.notNil) {
        ds.parentGroup.free;
        ds.parentGroup = nil;
    };

    // Free envelope synth
    if (ds.envSynth.notNil) {
        ds.envSynth.free;
        ds.envSynth = nil;
    };

    // Free per-note CC synths
    ds.perNoteCCSynths.do { |synth, layerName|
        if (synth.notNil) {
            synth.free;
        };
    };
    ds.perNoteCCSynths.clear;

    // Free control bus
    if (ds.controlBus.notNil) {
        ds.controlBus.free;
        ds.controlBus = nil;
    };

    // Clear resource tracking
    ds.resources.groups.clear;
    ds.resources.buses.clear;
    ds.resources.synths.clear;
    ds.resources.tasks.clear;

    ds.isRunning = false;
    "Direct resources cleaned up".postln;
};

// Start layers directly (replaces ~createLayersParentProc)
~startLayersDirectly = { |duration|
    var ds = ~layers.directState;

    if (ds.isRunning) {
        "Layers already running directly".warn;
        ^nil;
    };

    try {
        "Starting layers directly (duration: %s)...".format(duration).postln;

        // Create main group
        ds.parentGroup = Group.new;
        ds.resources.groups.add(ds.parentGroup);

        // Create control bus for amplitude envelope (optional)
        ds.controlBus = Bus.control(Server.default, 1);
        ds.resources.buses.add(ds.controlBus);

        // Create envelope synth (optional - for amplitude control)
        ds.envSynth = {
            var env = EnvGen.kr(Env.asr(0.05, 1.0, 0.05), \gate.kr(1));
            Out.kr(ds.controlBus, env);
        }.play(ds.parentGroup);
        ds.resources.synths.add(ds.envSynth);

        // Create parent coordination task (same logic as ProcMod version)
        ds.parentTask = Task({
            var loopCount = 0;
            var activeLayerCount, currentDuration;

            while { ~layers.state.loopingMode or: { loopCount == 0 } } {
                activeLayerCount = 0;

                loopCount = loopCount + 1;

                // Set up VST routing for sketch system compatibility
                if (loopCount == 1) {  // Only on first loop
                    if (~layers.configs[\layer1].notNil && ~setActiveVSTGroup.notNil) {
                        ~setActiveVSTGroup.(~layers.configs[\layer1].vstGroup);
                    };
                    if (~layers.configs[\layer2].notNil && ~setActiveVSTGroup_2.notNil) {
                        ~setActiveVSTGroup_2.(~layers.configs[\layer2].vstGroup);
                    };
                };

                // Determine duration at the START of each loop
                if (~layers.state.manualControl) {
                    currentDuration = ~getLayersDurationFromKnob.();
                    "Loop %: Using MIDI knob duration: % seconds".format(
                        loopCount, currentDuration.round(0.01)
                    ).postln;
                    ~updateAllLayerNoteDurationScalars.();
                } {
                    currentDuration = duration;
                    "Loop %: Using fixed duration: % seconds".format(
                        loopCount, currentDuration.round(0.01)
                    ).postln;
                    // Reset all layers to 100% when manual control is off
                    ~layers.configs.keysValuesDo { |layerName, config|
                        config.noteDurationScalar = 1.0;
                    };
                };

                // Calculate timing for all layers with current duration
                ~layers.configs.keysValuesDo { |layerName, config|
                    var melodyKey, melodyData, pattern, noteCount, timingInfo;
                    if (config.enabled and: { config.melodyList.size > 0 }) {
                        melodyKey = config.melodyList[0];
                        melodyData = ~melodyDict[melodyKey];
                        pattern = melodyData.patterns[0];
                        noteCount = pattern.size;

                        if (~calculateLayerTiming.notNil) {
                            timingInfo = ~calculateLayerTiming.(melodyData, currentDuration, layerName);

                            ~layers.timingData[layerName] = (
                                melodyKey: melodyKey,
                                noteCount: noteCount,
                                noteInterval: currentDuration / noteCount,
                                duration: currentDuration,
                                startTimes: timingInfo.startTimes,
                                durations: timingInfo.durations,
                                waitTimes: timingInfo.waitTimes,
                                hasTiming: melodyData.timing.notNil
                            );
                        } {
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

                // Update expression parameters from MIDI before each loop
                ~updateAllLayerExpressionParams.();

                // Create child layers on first iteration
                if (loopCount == 1) {
                    ~layers.configs.keysValuesDo { |layerName, config|
                        if (config.enabled and: { config.melodyList.size > 0 }) {
                            ~startChildLayerDirectly.(layerName, config);
                            activeLayerCount = activeLayerCount + 1;
                            "Created direct layer: %".format(layerName).postln;
                        };
                    };

                    "Starting % layer tasks simultaneously".format(activeLayerCount).postln;

                    // Start all child tasks
                    ds.childTasks.do { |task|
                        if (task.notNil) { task.play };
                    };
                };

                // Start CC envelopes based on mode
                if (~layers.state.singleNoteCCMode) {
                    "Single note CC mode active - envelopes will trigger per note".postln;
                } {
                    ~layers.configs.keysValuesDo { |layerName, config|
                        var ccSynth;
                        if (config.enabled and: { config.melodyList.size > 0 }) {
                            ccSynth = ~startLayerCCEnvelope.(layerName, currentDuration);
                            if (ccSynth.notNil) {
                                ~layers.timingData[layerName].ccSynth = ccSynth;
                            };
                        };
                    };
                };

                // Wait for loop duration
                currentDuration.wait;

                if (~layers.state.loopingMode.not) {
                    "Single iteration complete, stopping".postln;
                };
            };

            // Cleanup when task completes
            "Parent task finished, cleaning up...".postln;
            ~cleanupDirectResources.();
        });
        ds.resources.tasks.add(ds.parentTask);

        // Start the parent task
        ds.parentTask.play;
        ds.isRunning = true;

        "Layers started directly".postln;

    } { |error|
        "ERROR starting layers directly: %".format(error).postln;
        error.reportError;
        ~cleanupDirectResources.();  // Cleanup on error
        nil;
    };
};

// Start individual child layer (replaces ~createLayerProcMod)
~startChildLayerDirectly = { |layerName, config|
    var ds = ~layers.directState;
    var childGroup, childTask;

    // Create child group
    childGroup = Group.new(ds.parentGroup, \addToTail);
    ds.childGroups[layerName] = childGroup;
    ds.resources.groups.add(childGroup);

    // Create child task (same note playing logic as ProcMod version)
    childTask = Task({
        var iterationCount = 0;
        var melodyData, pattern, noteCount, currentTiming;
        var velocities, noteDurations, windowingTask, waitCount;

        while { ~layers.state.loopingMode or: { iterationCount == 0 } } {

            iterationCount = iterationCount + 1;

            // GET DYNAMIC MELODY DATA - FRESH EACH LOOP
            melodyData = ~getLayerMelodyDynamic.(layerName);

            if (melodyData.notNil) {
                pattern = melodyData.patterns[iterationCount % melodyData.patterns.size];
                velocities = melodyData.velocities;
                noteDurations = melodyData.noteDurations;
                noteCount = pattern.size;

                // Read fresh timing data at the start of each iteration
                currentTiming = ~layers.timingData[layerName];

                if (iterationCount == 1) {  // Only log first iteration
                    if (currentTiming.notNil and: { currentTiming.hasTiming }) {
                        "Layer %: % notes using timing data, total: % seconds".format(
                            layerName, noteCount, currentTiming.duration
                        ).postln;
                    } {
                        "Layer %: % notes, equal interval: % seconds, total: % seconds".format(
                            layerName, noteCount, currentTiming.noteInterval.round(0.001), currentTiming.duration
                        ).postln;
                    };
                };

                // Check if windowing mode should be used
                if (~shouldUseWindowing.notNil && ~shouldUseWindowing.(layerName)) {
                    // Use windowing playback (existing logic)
                    windowingTask = ~createWindowingTask.(layerName, config, currentTiming.duration);
                    if (windowingTask.notNil) {
                        ~layers.windowTasks[layerName] = windowingTask;
                        windowingTask.play;

                        // Wait for windowing task to complete
                        waitCount = 0;
                        while { windowingTask.isPlaying and: { waitCount < 1000 } } {
                            0.1.wait;
                            waitCount = waitCount + 1;

                            if (ds.isRunning.not) {
                                windowingTask.stop;
                                waitCount = 1000;
                            };
                        };

                        ~layers.windowTasks[layerName] = nil;
                        ~stopLayerWindows.(layerName);
                    };
                } {
                    // Normal playback - use existing timing logic
                    if (currentTiming.notNil and: { currentTiming.hasTiming } and: { currentTiming.waitTimes.notNil }) {
                        // Use pre-calculated timing data
                        var waitTimes, durations;
                        waitTimes = currentTiming.waitTimes;
                        durations = currentTiming.durations;

                        pattern.do { |note, i|
                            var noteVel, noteDur;

                            // Check manual control mode for velocity
                            if (~layers.state.manualControl) {
                                // MANUAL CONTROL: Use Row 1, Knob 3 directly
                                if (~midiController.notNil) {
                                    var knobValue = ~midiController.getKnobRow1(3);
                                    noteVel = knobValue.linlin(0, 127, 1, 127).asInteger;
                                } {
                                    noteVel = 100; // Default if no MIDI controller
                                    "DEBUG: Manual control (timing) - using default velocity = %".format(noteVel).postln;
                                };
                            } {
                                // Use melody velocity data
                                noteVel = if (velocities.notNil and: { i < velocities.size }) {
                                    velocities[i]
                                } { 100 };
                                "DEBUG: Using melody velocity data (timing) = %".format(noteVel).postln;
                            };

                            noteDur = if (durations.notNil and: { i < durations.size }) {
                                durations[i]
                            } { 0.5 };

                            if (i < waitTimes.size) {
                                waitTimes[i].wait;
                            };

                            if (ds.isRunning) {
                                ~playLayerNote.(layerName, note, noteVel, noteDur, childGroup);
                            };
                        };
                    } {
                        // Equal spacing
                        pattern.do { |note, i|
                            var noteVel, noteDur;

                            // Check manual control mode for velocity
                            if (~layers.state.manualControl) {
                                // MANUAL CONTROL: Use Row 1, Knob 3 directly
                                if (~midiController.notNil) {
                                    var knobValue = ~midiController.getKnobRow1(3);
                                    noteVel = knobValue.linlin(0, 127, 1, 127).asInteger;
                                } {
                                    noteVel = 100; // Default if no MIDI controller
                                    "DEBUG: Manual control (equal spacing) - using default velocity = %".format(noteVel).postln;
                                };
                            } {
                                // Use melody velocity data
                                noteVel = if (velocities.notNil and: { i < velocities.size }) {
                                    velocities[i]
                                } { 100 };
                                "DEBUG: Using melody velocity data (equal spacing) = %".format(noteVel).postln;
                            };

                            noteDur = if (noteDurations.notNil and: { i < noteDurations.size }) {
                                noteDurations[i]
                            } { 0.5 };

                            if (ds.isRunning) {
                                ~playLayerNote.(layerName, note, noteVel, noteDur, childGroup);
                            };

                            currentTiming.noteInterval.wait;
                        };
                    };
                };
            };

            if (~layers.state.loopingMode.not) {
                "Layer % single iteration complete".format(layerName).postln;
            };
        };

        "Layer % task finished".format(layerName).postln;
    });

    ds.childTasks[layerName] = childTask;
    ds.resources.tasks.add(childTask);

    "Child layer % created directly".format(layerName).postln;
};

// Stop layers directly (replaces ProcMod.release)
~stopLayersDirectly = {
    var ds = ~layers.directState;

    if (ds.isRunning.not) {
        "Layers not running directly".warn;
        ^nil;
    };

    "Stopping layers directly...".postln;

    // Clean up all bend synths first
    ~cleanupAllBendSynths.();

    // Release all CC synths first
    ~layers.timingData.keysValuesDo { |layerName, timing|
        if (timing.ccSynth.notNil) {
            "Releasing CC synth for %".format(layerName).postln;
            timing.ccSynth.release;
            timing.ccSynth = nil;
        };
    };

    // Stop all windowing tasks
    if (~stopAllWindows.notNil) {
        ~stopAllWindows.();
    };

    // Cleanup all resources
    ~cleanupDirectResources.();

    ~layers.state.startTime = nil;
    "Layers stopped directly".postln;
};

// Emergency stop (replaces ProcMod.kill)
~killLayersDirectly = {
    "Emergency stop: killing layers directly...".postln;

    // Clean up all bend synths first
    ~cleanupAllBendSynths.();

    // Nuclear cleanup
    ~layers.directState.parentGroup.freeAll;
    ~cleanupDirectResources.();

    "Layers killed directly".postln;
};

// Test that functions are defined
"DEBUG: Testing function definitions...".postln;
"  ~createLayersParentProc (DEPRECATED) is: %".format(~createLayersParentProc.class).postln;
"  ~createLayerProcMod (DEPRECATED) is: %".format(~createLayerProcMod.class).postln;
"  ~startLayersDirectly (NEW) is: %".format(~startLayersDirectly.class).postln;
"  ~stopLayersDirectly (NEW) is: %".format(~stopLayersDirectly.class).postln;
"  ~killLayersDirectly (NEW) is: %".format(~killLayersDirectly.class).postln;

"Dependent layers playback system loaded".postln;
"  - Direct (no ProcMod) functions: ✓ Available".postln;
"  - Legacy ProcMod functions: ✓ Available (deprecated)".postln;