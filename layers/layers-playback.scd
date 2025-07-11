/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                       DEPENDENT LAYERS - PLAYBACK                             ║
║                    ProcMod creation and timing logic                          ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         PARENT PROCMOD CREATION                            │
// └─────────────────────────────────────────────────────────────────────────────┘

// Create the parent ProcMod that manages all layers
~createLayersParentProc = {
    var env = Env.asr(0.05, 1.0, 0.05, \lin);  // Short fade in/out as requested
    var id = ("layersParent_" ++ Date.getDate.stamp).asSymbol;
    
    ProcMod.new(
        env,          // ASR envelope
        1.0,          // Amplitude
        id,           // Unique ID
        nil,          // Group (create new)
        0,            // addAction
        1,            // target
        
        // Main function - returns a Task
        { |parentGroup, envbus|
            var mainTask = Task({
                var maxDuration = ~calculateMaxDuration.();
                var layerProcs = [];
                var activeLayerCount = 0;
                
                "=== Starting dependent layers ===".postln;
                "Parent group: %, Max duration: % seconds".format(parentGroup, maxDuration).postln;
                
                // Clear any existing layer ProcMods
                ~layers.layerProcs.clear;
                
                // Create ProcMods for each enabled layer
                ~layers.configs.keysValuesDo { |layerName, config|
                    if (config.enabled and: { config.melodyList.size > 0 }) {
                        var proc = ~createLayerProcMod.(layerName, config, parentGroup, maxDuration);
                        ~layers.layerProcs[layerName] = proc;
                        layerProcs = layerProcs.add(proc);
                        activeLayerCount = activeLayerCount + 1;
                        "Created ProcMod for %".format(layerName).postln;
                    };
                };
                
                if (activeLayerCount > 0) {
                    "Starting % layer ProcMods simultaneously".format(activeLayerCount).postln;
                    
                    // Start all ProcMods at the same time
                    layerProcs.do { |proc|
                        proc.play;
                    };
                    
                    // Wait for the longest layer to complete
                    maxDuration.wait;
                    
                    "All layers completed".postln;
                } {
                    "No active layers to play".warn;
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
        }
    );
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         LAYER PROCMOD CREATION                             │
// └─────────────────────────────────────────────────────────────────────────────┘

// Create a ProcMod for an individual layer
~createLayerProcMod = { |layerName, config, parentGroup, maxDuration|
    var env = Env.asr(0.05, 1.0, 0.05, \lin);  // ASR envelope for layer
    var id = (layerName.asString ++ "_" ++ Date.getDate.stamp).asSymbol;
    var melodyKey = config.melodyList[0];  // Always play first melody (no auto-progression)
    
    ProcMod.new(
        env,          // ASR envelope
        1.0,          // Amplitude (can be individually controlled)
        id,           // Unique ID
        nil,          // Group (create new)
        0,            // addAction (head)
        parentGroup,  // Target is parent's group
        
        // Main function - returns a Task
        { |group, envbus|
            var task = Task({
                var currentTime = 0;
                
                "Layer % starting: melody % → VST group %".format(
                    layerName, melodyKey, config.vstGroup
                ).postln;
                
                // Play the melody repeatedly until max duration
                while { currentTime < maxDuration } {
                    var melodyDuration = ~calculateMelodyDuration.(melodyKey);
                    var remainingTime = maxDuration - currentTime;
                    var playDuration = min(melodyDuration, remainingTime);
                    
                    "Layer % playing % for % seconds".format(
                        layerName, melodyKey, playDuration
                    ).postln;
                    
                    // Play the melody segment
                    ~playLayerMelodySegment.(melodyKey, layerName, playDuration, group);
                    
                    // Wait for this segment to complete
                    playDuration.wait;
                    
                    currentTime = currentTime + playDuration;
                };
                
                "Layer % completed".format(layerName).postln;
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
                    NetAddr.localAddr.sendMsg(
                        '/layer/note/on',
                        layerName,
                        processedNote[0],  // note
                        processedNote[1],  // velocity
                        actualDuration
                    );
                };
            } {
                // Normal note playback
                NetAddr.localAddr.sendMsg(
                    '/layer/note/on',
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
// │                         OSC RESPONDERS                                     │
// └─────────────────────────────────────────────────────────────────────────────┘

// Layer-specific note handler
OSCdef(\layerNoteOn, { |msg, time, addr, recvPort|
    var layerName = msg[1].asSymbol;
    var note = msg[2].asInteger;
    var velocity = msg[3].asInteger;
    var duration = msg[4].asFloat;
    
    // Get the VST group for this layer
    var config = ~layers.configs[layerName];
    var vstGroup = config.vstGroup;
    
    // Route to appropriate VST instances (if vstManager exists)
    if (~vstManager.notNil) {
        var instances = ~vstManager.getTargetInstances(vstGroup);
        
        // Debug: Show which instances we're targeting
        if (instances.size > 0) {
            "Layer % → VST group '%' (%  instances: %)".format(
                layerName, vstGroup, instances.size, instances.keys.asArray
            ).postln;
        };
        
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
}, '/layer/note/on');

"Dependent layers playback system loaded".postln;