/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                       DEPENDENT LAYERS - WINDOWING                            ║
║                    Progressive windowed playback system                       ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         WINDOWING UTILITIES                                │
// └─────────────────────────────────────────────────────────────────────────────┘

// Check if layer should use windowing mode
~shouldUseWindowing = { |layerName|
    var config = ~layers.configs[layerName];
    var melodyData, durationType;
    
    if (config.isNil || config.windowing.isNil) {
        false
    } {
        if (config.windowing.enabled && config.melodyList.size > 0) {
            // Check if melody has absolute duration type
            melodyData = ~melodyDict[config.melodyList[0]];
            if (melodyData.notNil) {
                durationType = melodyData[\durationType] ? melodyData[\metadata][\durationType];
                durationType == "absolute"
            } {
                false
            }
        } {
            false
        }
    }
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         WINDOW PLAYBACK                                    │
// └─────────────────────────────────────────────────────────────────────────────┘

// Play a single window of notes
~playLayerWindow = { |layerName, startIndex, windowSize, parentDuration|
    var config = ~layers.configs[layerName];
    var melodyData = ~getLayerMelodyDynamic.(layerName);
    var pattern, velocities, noteDurations;
    var endIndex, windowNotes;
    var currentTiming = ~layers.timingData[layerName];
    var task;
    
    if (melodyData.notNil) {
        pattern = melodyData.patterns[0];  // Use first pattern for windowing
        velocities = melodyData.velocities;
        noteDurations = melodyData.noteDurations;
        
        // Calculate window bounds
        endIndex = min(startIndex + windowSize - 1, pattern.size - 1);
        windowNotes = endIndex - startIndex + 1;
        
        "Window for %: notes % to % (% notes)".format(
            layerName, startIndex, endIndex, windowNotes
        ).postln;
        
        task = Task({
            var currentTime = 0;
            var windowStartTime, windowEndTime;
            
            // Calculate when this window starts and ends in absolute time
            if (currentTiming.notNil && currentTiming.hasTiming && currentTiming.startTimes.notNil) {
                windowStartTime = currentTiming.startTimes[startIndex] ? 0;
                
                // Play each note in the window
                (startIndex..endIndex).do { |noteIndex|
                    var note = pattern[noteIndex];
                    var noteStartTime = currentTiming.startTimes[noteIndex];
                    var noteDuration = currentTiming.durations[noteIndex];
                    var waitTime;
                    var velocity;
                    
                    // Calculate wait time from current position
                    waitTime = noteStartTime - currentTime;
                    
                    if (waitTime > 0) {
                        waitTime.wait;
                        currentTime = noteStartTime;
                    };
                    
                    // Get velocity (respecting manual control mode)
                    if (~layers.state.manualControl) {
                        if (~midiController.notNil) {
                            var knobValue = ~midiController.getKnobRow1(3);
                            velocity = knobValue.linlin(0, 127, 1, 127).asInteger;
                        } {
                            velocity = 100;
                        };
                    } {
                        velocity = velocities[noteIndex] ? 127;
                    };
                    
                    // Play the note
                    ~playLayerNote.(
                        layerName,
                        note,
                        velocity,
                        noteDuration * config.noteDurationScalar
                    );
                };
            } {
                // Fallback for equal timing
                var noteInterval = parentDuration / pattern.size;
                
                (startIndex..endIndex).do { |noteIndex|
                    var note = pattern[noteIndex];
                    var duration = noteDurations[noteIndex] ? 0.5;
                    var velocity;
                    
                    // Get velocity
                    if (~layers.state.manualControl) {
                        if (~midiController.notNil) {
                            var knobValue = ~midiController.getKnobRow1(3);
                            velocity = knobValue.linlin(0, 127, 1, 127).asInteger;
                        } {
                            velocity = 100;
                        };
                    } {
                        velocity = velocities[noteIndex] ? 127;
                    };
                    
                    ~playLayerNote.(
                        layerName,
                        note,
                        velocity,
                        duration * config.noteDurationScalar
                    );
                    
                    noteInterval.wait;
                };
            };
            
            "Window completed for %: notes % to %".format(
                layerName, startIndex, endIndex
            ).postln;
        });
        
        task
    } {
        nil
    }
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                      WINDOW MANAGEMENT                                     │
// └─────────────────────────────────────────────────────────────────────────────┘

// Create windowing Task for a layer
~createWindowingTask = { |layerName, config, parentDuration|
    var windowing = config.windowing;
    var windowSize = windowing.windowSize;
    var overlapTriggerIndex = windowing.overlapTriggerIndex;
    var stepSize = windowing.stepSize;
    var melodyData = ~getLayerMelodyDynamic.(layerName);
    var pattern, totalNotes;
    var currentTiming = ~layers.timingData[layerName];
    var mainTask;
    
    if (melodyData.notNil) {
        pattern = melodyData.patterns[0];
        totalNotes = pattern.size;
        
        // Initialize window task list for this layer
        ~layers.windowTasks[layerName] = List.new;
        
        mainTask = Task({
            var windowIndex = 0;
            var nextTriggerTime = 0;
            var currentTime = 0;
            
            // Keep spawning windows until we've covered all notes
            while { windowIndex < totalNotes } {
                var windowTask;
                var triggerNoteIndex;
                
                // Wait until trigger time
                if (nextTriggerTime > currentTime) {
                    (nextTriggerTime - currentTime).wait;
                    currentTime = nextTriggerTime;
                };
                
                // Spawn new window
                windowTask = ~playLayerWindow.(
                    layerName, 
                    windowIndex, 
                    windowSize, 
                    parentDuration
                );
                
                if (windowTask.notNil) {
                    ~layers.windowTasks[layerName].add(windowTask);
                    windowTask.play;
                    
                    // Calculate next trigger time
                    triggerNoteIndex = windowIndex + overlapTriggerIndex;
                    if (triggerNoteIndex < totalNotes && currentTiming.notNil && currentTiming.startTimes.notNil) {
                        nextTriggerTime = currentTiming.startTimes[triggerNoteIndex];
                    };
                };
                
                // Advance window
                windowIndex = windowIndex + stepSize;
            };
            
            "All windows spawned for layer %".format(layerName).postln;
        });
        
        mainTask
    } {
        nil
    }
};

// Stop all windows for a layer
~stopLayerWindows = { |layerName|
    if (~layers.windowTasks[layerName].notNil) {
        ~layers.windowTasks[layerName].do { |task|
            if (task.notNil && task.isPlaying) {
                task.stop;
            };
        };
        ~layers.windowTasks[layerName].clear;
    };
};

// Stop all windows for all layers
~stopAllWindows = {
    ~layers.windowTasks.keysValuesDo { |layerName, tasks|
        ~stopLayerWindows.(layerName);
    };
};

"Dependent layers windowing system loaded".postln;