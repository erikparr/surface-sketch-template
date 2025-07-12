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
    // The ProcMod class uses a writeDefs flag to ensure the SynthDef is only created once
    // However, .add only adds to SynthDescLib, not to the server
    // We need to ensure it's sent to the server
    
    if (SynthDescLib.global[\procmodenv_5216].isNil) {
        // Force ProcMod to create its SynthDef by creating a temporary instance
        var temp = ProcMod.new(Env.asr(0.01, 1, 0.01), 1.0, \temp);
        temp = nil;  // Clean up
    };
    
    // Now send the SynthDef to the server if it exists
    if (SynthDescLib.global[\procmodenv_5216].notNil) {
        SynthDescLib.global[\procmodenv_5216].send(Server.default);
        "ProcMod SynthDef sent to server".postln;
    } {
        "Warning: ProcMod SynthDef not found in SynthDescLib".warn;
    };
};

// Ensure SynthDef is available when layers system loads
~ensureProcModSynthDef.();


// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         PARENT PROCMOD CREATION                            │
// └─────────────────────────────────────────────────────────────────────────────┘

// Create the parent ProcMod that manages all layers
~createLayersParentProc = { |duration|
    // Use an envelope with a release node to keep it sustained
    var env = Env.asr(0.05, 1.0, 0.05, \lin, releaseNode: 1);  // Release node at sustain
    var id = ("layersParent_" ++ Date.getDate.stamp).asSymbol;
    
    // Use provided duration or calculate from current settings
    duration = duration ?? { 4.0 };  // Default to 10 seconds if not specified
    
    
    ProcMod.new(
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
                
                // Calculate timing once for all layers and store in shared structure
                ~layers.configs.keysValuesDo { |layerName, config|
                    if (config.enabled and: { config.melodyList.size > 0 }) {
                        var melodyKey = config.melodyList[0];
                        var pattern = ~melodyDict[melodyKey].patterns[0];
                        var noteCount = pattern.size;
                        
                        ~layers.timingData[layerName] = (
                            melodyKey: melodyKey,
                            noteCount: noteCount,
                            noteInterval: duration / noteCount,
                            duration: duration
                        );
                    };
                };
                
                while { ~layers.state.loopingMode or: { loopCount == 0 } } {
                    var layerProcs = [];
                    var activeLayerCount = 0;
                    
                    loopCount = loopCount + 1;
                    if (~layers.state.loopingMode) {
                        "=== Starting dependent layers (loop %) ===".format(loopCount).postln;
                    } {
                        "=== Starting dependent layers ===".postln;
                    };
                    "Parent group: %, Duration: % seconds".format(parentGroup, duration).postln;
                    
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
                        
                        // Wait for the parent duration
                        duration.wait;
                        
                        // Don't release child ProcMods - they loop internally
                        
                        if (~layers.state.loopingMode) {
                            "Parent loop % completed after % seconds - continuing...".format(loopCount, duration).postln;
                        } {
                            "All layers completed after % seconds".format(duration).postln;
                        };
                    } {
                        "No active layers to play".warn;
                        // Exit the loop by setting looping mode to false
                        ~layers.state.loopingMode = false;
                    };
                    
                    // Add a small delay between loops to ensure clean transitions
                    if (~layers.state.loopingMode) {
                        0.2.wait;  // Small delay before next loop to sync with children
                        "Parent starting loop %...".format(loopCount + 1).postln;
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
        },
        
        // onRelease function - executes when release is triggered
        { |parentGroup, envbus|
            "Parent ProcMod releasing...".postln;
            
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
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         LAYER PROCMOD CREATION                             │
// └─────────────────────────────────────────────────────────────────────────────┘

// Create a ProcMod for an individual layer
~createLayerProcMod = { |layerName, config, parentGroup|
    var id = (layerName.asString ++ "_" ++ Date.getDate.stamp).asSymbol;
    var melodyKey = config.melodyList[0];  // Always play first melody (no auto-progression)
    var env = Env.asr(0.01, 1.0, 0.01, \lin);  // Quick attack/release envelope for child layers
    var timing = ~layers.timingData[layerName];  // Get pre-calculated timing
    
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
                var pattern, noteCount, noteInterval, parentDuration;
                var iterationCount = 0;
                
                // Get melody pattern and timing from shared data
                pattern = ~melodyDict[melodyKey].patterns[0];
                noteCount = timing.noteCount;
                noteInterval = timing.noteInterval;
                parentDuration = timing.duration;
                
                "Layer %: % notes, interval: % seconds, total: % seconds".format(
                    layerName, noteCount, noteInterval.round(0.001), parentDuration
                ).postln;
                
                // Loop the melody based on shared looping state
                while { ~layers.state.loopingMode or: { iterationCount == 0 } } {
                    iterationCount = iterationCount + 1;
                    
                    // Play each note at calculated intervals
                    noteCount.do { |noteIndex|
                        var note = pattern[noteIndex];
                        var noteTime = noteIndex * noteInterval;
                        var isFirstNote = (noteIndex == 0);
                        var isLastNote = (noteIndex == (noteCount - 1));
                        var processedNote, velocity;
                        
                        // Process note for velocity, offset, etc.
                        if (~processNote.notNil) {
                            processedNote = ~processNote.value(note, isFirstNote, isLastNote, melodyKey);
                        } {
                            processedNote = [note, 100];  // Fallback
                        };
                        
                        if (iterationCount == 1) {  // Only log first iteration
                            "Layer % note % at time %s: note % vel %".format(
                                layerName, noteIndex + 1, noteTime.round(0.001), 
                                processedNote[0], processedNote[1]
                            ).postln;
                        };
                        
                        // Play note directly (no OSC indirection)
                        ~playLayerNote.(
                            layerName,
                            processedNote[0],  // note
                            processedNote[1],  // velocity
                            0.2  // Note duration (could be configurable)
                        );
                        
                        // Wait until next note time
                        if (noteIndex < (noteCount - 1)) {
                            noteInterval.wait;
                        } {
                            // For last note, wait the remaining time to complete the full duration
                            var remainingTime = parentDuration - (noteIndex * noteInterval);
                            remainingTime.wait;
                        };
                    };
                    
                    if (iterationCount == 1) {  // Only log first iteration
                        "Layer % completed all % notes".format(layerName, noteCount).postln;
                    };
                    
                    // Check if we should continue looping (single source of truth)
                    if (~layers.state.loopingMode) {
                        // Small gap before next iteration
                        0.1.wait;
                        "Layer % starting iteration %".format(layerName, iterationCount + 1).postln;
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

// Keep the old task creation function for backwards compatibility temporarily
~createLayerTask = { |layerName, config, parentGroup, maxDuration|
    Task({
        var currentTime = 0;
        var melodyKey = config.melodyList[0];  // Always play first melody (no auto-progression)
        
        "Layer % starting: melody % → VST group %".format(
            layerName, melodyKey, config.vstGroup
        ).postln;
        
        // Note: VST targeting is handled per-note in the OSC handler
        // Each layer sends its notes with its layer name, and the OSC handler
        // routes to the correct VST group based on the layer's config
        
        // Play the melody repeatedly until max duration
        while { currentTime < maxDuration } {
            var melodyDuration = ~calculateMelodyDuration.(melodyKey);
            var remainingTime = maxDuration - currentTime;
            var playDuration = min(melodyDuration, remainingTime);
            
            "Layer % playing % for % seconds".format(
                layerName, melodyKey, playDuration
            ).postln;
            
            // Play the melody segment
            ~playLayerMelodySegment.(melodyKey, layerName, playDuration, parentGroup);
            
            // Wait for this segment to complete
            playDuration.wait;
            
            currentTime = currentTime + playDuration;
        };
        
        // VST group targeting is handled in the OSC handler, no need to restore
        
        "Layer % completed".format(layerName).postln;
    })
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         MELODY PLAYBACK                                    │
// └─────────────────────────────────────────────────────────────────────────────┘

// Play a segment of a melody for a specific duration
~playLayerMelodySegment = { |melodyKey, layerName, duration, parentGroup|
    var pattern = ~melodyDict[melodyKey].patterns[0];
    var startTime = Main.elapsedTime;
    var noteIndex = 0;
    var noteCount = pattern.size;
    
    Task({
        while { 
            (noteIndex < noteCount) and: 
            ((Main.elapsedTime - startTime) < duration) 
        } {
            var note = pattern[noteIndex];
            var isFirstNote = (noteIndex == 0);
            var isLastNote = (noteIndex == (noteCount - 1));
            var processedNote, actualDuration, waitTime;
            
            // Process note - check if sketch system function exists
            if (~processNote.notNil) {
                processedNote = ~processNote.value(note, isFirstNote, isLastNote, melodyKey);
            } {
                // Fallback: just return note and default velocity
                processedNote = [note, 100];
            };
            
            // Get timing - use sketch system if available, otherwise defaults
            actualDuration = if (~ccControl.notNil and: { ~ccControl.noteDuration.notNil }) {
                ~ccControl.noteDuration
            } {
                0.2  // Default note duration
            };
            
            waitTime = if (~ccControl.notNil and: { ~ccControl.noteRestTime.notNil }) {
                ~ccControl.noteRestTime
            } {
                0.2  // Default rest time
            };
            
            // Check if we have enough time for this note
            if ((Main.elapsedTime - startTime + actualDuration) > duration) {
                // Truncate last note if needed
                actualDuration = duration - (Main.elapsedTime - startTime);
                if (actualDuration <= 0) {
                    // No time left, exit
                    noteIndex = noteCount;  // Force exit
                } {
                    // Send truncated note
                    ~playLayerNote.(
                        layerName,
                        processedNote[0],  // note
                        processedNote[1],  // velocity
                        actualDuration
                    );
                };
            } {
                // Normal note playback
                ~playLayerNote.(
                    layerName,
                    processedNote[0],  // note
                    processedNote[1],  // velocity
                    actualDuration
                );
                
                // Wait before next note
                (actualDuration + waitTime).wait;
            };
            
            noteIndex = noteIndex + 1;
        };
    }).play;
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

"Dependent layers playback system loaded".postln;