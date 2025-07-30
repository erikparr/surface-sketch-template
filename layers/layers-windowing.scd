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
    
    "DEBUG: ~shouldUseWindowing called for %".format(layerName).postln;
    
    // Simple guard clauses - SuperCollider handles nil gracefully
    if (config.isNil or: { config.windowing.isNil or: { config.windowing.enabled.not } }) {
        "DEBUG: Windowing check failed - config/windowing/enabled issue".postln;
        false
    } {
        // Windowing only works on layer1
        if (layerName != \layer1) {
            "DEBUG: Windowing only supported on layer1".postln;
            false
        } {
            // Basic validation - trust SuperCollider's type system
            if (config.melodyList.isEmpty) {
                "DEBUG: Windowing check failed - empty melodyList".postln;
                false
            } {
                melodyData = ~melodyDict[config.melodyList[0]];
                if (melodyData.notNil) {
                    durationType = melodyData[\durationType] ?? { melodyData[\metadata] !? { melodyData[\metadata][\durationType] } };
                    "DEBUG: Found durationType: %".format(durationType).postln;
                    durationType == "absolute"
                } {
                    "DEBUG: Windowing check failed - no melody data".postln;
                    false
                }
            }
        }
    }
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                    WINDOW DATA EXTRACTION                                  │
// └─────────────────────────────────────────────────────────────────────────────┘

// Extract window-specific data from original melody
~extractWindowData = { |melodyData, startIndex, windowSize, layerName|
    var endIndex, windowNotes, windowVelocities, windowDurations;
    var totalWindowDuration = 0;
    var originalTotalDuration, pattern, noteCount;
    var windowTiming, layerConfig, noteDurationScalar;
    
    // Convert windowSize to integer to avoid float indexing issues
    windowSize = windowSize.asInteger;
    startIndex = startIndex.asInteger;
    
    // Get layer configuration and note duration scalar
    layerConfig = ~layers.configs[layerName];
    noteDurationScalar = if (layerConfig.notNil and: { layerConfig.noteDurationScalar.notNil }) {
        layerConfig.noteDurationScalar
    } {
        1.0  // Default to 100% scaling if not available
    };
    
    "DEBUG: Layer % noteDurationScalar = %% (Knob 2)".format(
        layerName, (noteDurationScalar * 100).round(1)
    ).postln;
    
    // Safety checks
    if (melodyData.isNil) {
        "ERROR in ~extractWindowData: melodyData is nil".postln;
        ^nil;
    };
    
    if (melodyData.patterns.isNil or: { melodyData.patterns.size == 0 }) {
        "ERROR in ~extractWindowData: melodyData.patterns is nil or empty".postln;
        ^nil;
    };
    
    pattern = melodyData.patterns[0];
    if (pattern.isNil) {
        "ERROR in ~extractWindowData: first pattern is nil".postln;
        ^nil;
    };
    
    noteCount = pattern.size;
    if (noteCount == 0) {
        "ERROR in ~extractWindowData: pattern is empty".postln;
        ^nil;
    };
    
    originalTotalDuration = melodyData.metadata !? { melodyData.metadata.totalDuration } ?? 211.5;
    
    // Check bounds
    if (startIndex >= noteCount) {
        "ERROR in ~extractWindowData: startIndex (%) >= noteCount (%)".format(startIndex, noteCount).postln;
        ^nil;
    };
    
    // Calculate actual end index (may be less than windowSize at end of melody)
    endIndex = min(startIndex + windowSize - 1, noteCount - 1);
    
    "DEBUG ~extractWindowData: startIndex=%, endIndex=%, noteCount=%, windowSize=%".format(
        startIndex, endIndex, noteCount, windowSize
    ).postln;
    
    // Extract notes for this window
    try {
        windowNotes = pattern[startIndex..endIndex];
    } { |error|
        "ERROR in ~extractWindowData: Failed to extract notes: %".format(error).postln;
        ^nil;
    };
    windowVelocities = if (melodyData.velocities.notNil) {
        melodyData.velocities[startIndex..endIndex]
    } {
        Array.fill(windowNotes.size, 127)
    };
    
    // Calculate REASONABLE window duration
    if (melodyData.timing.notNil && melodyData.timing.size == (noteCount + 1)) {
        var timingSum = 0;
        
        // Extract timing values for this window only
        windowTiming = melodyData.timing[startIndex..(endIndex + 1)];
        timingSum = windowTiming.sum;
        
        // NEW: Scale down to reasonable duration for a window
        // Target: approximately 0.3-0.5 seconds per note (timing NOT affected by Knob 2)
        totalWindowDuration = windowNotes.size * 0.4;
        
        "Window %-%: % notes, duration=%s (timing unaffected by Knob 2)".format(
            startIndex, endIndex, windowNotes.size, totalWindowDuration.round(0.01)
        ).postln;
    } {
        // Fallback: estimate based on note count (timing NOT affected by Knob 2)
        totalWindowDuration = windowNotes.size * 0.4; // 0.4s per note
        "Window %-%: using fallback duration=%s (timing unaffected by Knob 2)".format(
            startIndex, endIndex, totalWindowDuration.round(0.01)
        ).postln;
    };
    
    // Extract durations if available (scale them proportionally, then apply Knob 2 scaling)
    windowDurations = if (melodyData.noteDurations.notNil) {
        // Scale original durations to fit our window duration
        var originalDurs = melodyData.noteDurations[startIndex..endIndex];
        var durSum = originalDurs.sum;
        if (durSum > 0) {
            originalDurs.collect { |dur| 
                ((dur / durSum) * totalWindowDuration * 0.8) * noteDurationScalar // Apply Knob 2 scaling to note duration
            };
        } {
            Array.fill(windowNotes.size, (totalWindowDuration * 0.8 / windowNotes.size) * noteDurationScalar)
        }
    } {
        Array.fill(windowNotes.size, (totalWindowDuration * 0.8 / windowNotes.size) * noteDurationScalar) // Apply Knob 2 scaling to default duration
    };
    
    "DEBUG: Note durations scaled by Knob 2 (%%): [%]".format(
        (noteDurationScalar * 100).round(1),
        windowDurations.collect(_.round(0.01)).join(", ")
    ).postln;
    
    // Return window-specific data
    (
        notes: windowNotes,
        velocities: windowVelocities,
        durations: windowDurations,
        totalDuration: totalWindowDuration,
        windowIndex: startIndex,
        startIndex: startIndex,
        endIndex: endIndex,
        originalMelodyData: melodyData,
        windowTiming: windowTiming  // Store for internal timing calculation
    )
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                      VST GROUP CYCLING                                     │
// └─────────────────────────────────────────────────────────────────────────────┘

// Get VST group for window (cycles through available groups)
~getWindowVSTGroup = { |windowNumber|
    var groups = ['Layer1', 'Layer2', 'Layer3'];
    var groupIndex = windowNumber % 3;
    var group = groups[groupIndex];
    "Window % assigned to VST group % (index %)".format(windowNumber, group, groupIndex).postln;
    group
};

// Get maximum concurrent windows based on VST availability
~getMaxConcurrentWindows = {
    if (~vstManager.notNil) {
        min(~vstManager.getGroupNames().size, 3)
    } {
        3 // Default to 3
    }
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                    WINDOW PROCMOD CREATION                                 │
// └─────────────────────────────────────────────────────────────────────────────┘

// Create individual ProcMod for a window
~createWindowProcMod = { |windowData, vstGroup, windowNumber|
    var windowDuration = windowData.totalDuration;
    var env = Env.asr(0.01, 1.0, 0.01); // Quick envelope
    var id = ("window_" ++ windowNumber ++ "_" ++ Date.getDate.stamp).asSymbol;
    
    "Creating window ProcMod: id=%, VST=%, duration=%s, notes=%".format(
        id, vstGroup, windowDuration.round(0.01), windowData.notes.size
    ).postln;
    
    ProcMod.new(
        env, 1.0, id, nil, 0, 1,
        // Window function - plays exactly this window's notes
        { |group, envbus|
            var windowTask;
            
            // Capture window data locally to avoid scope issues
            var localNotes = windowData.notes.copy;
            var localVelocities = windowData.velocities.copy;
            var localDurations = windowData.durations.copy;
            var localWindowNumber = windowNumber;
            var localVstGroup = vstGroup.asSymbol;
            var localWindowDuration = windowDuration;
            
            windowTask = Task({
                var currentTime = 0;
                var waitBetweenNotes = localWindowDuration * 0.2 / localNotes.size; // 20% for spacing
                var remainingTime;
                
                "Window % Task starting - playing % notes".format(
                    localWindowNumber, localNotes.size
                ).postln;
                
                try {
                    // Simple approach: play notes with equal spacing within window duration
                    localNotes.do { |note, i|
                        var rawVelocity = localVelocities[i] ? 1.0;
                        var velocity = (rawVelocity * 127).asInteger.clip(1, 127); // Scale 0.0-1.0 to 1-127
                        var duration = localDurations[i];
                        
                        // Log what we're about to play
                        "Window % playing note %: midi=%, vel=% (raw=%), dur=%s".format(
                            localWindowNumber, i, note, velocity, rawVelocity.round(0.01), duration.round(0.01)
                        ).postln;
                        
                        // Play the note on assigned VST group
                        try {
                            ~playLayerNote.(
                                localVstGroup,  // Use VST group as layer name
                                note,
                                velocity,
                                duration
                            );
                        } { |noteError|
                            "Error playing note in window %: %".format(localWindowNumber, noteError).postln;
                        };
                        
                        // Wait between notes (except after last note)
                        if (i < (localNotes.size - 1)) {
                            waitBetweenNotes.wait;
                            currentTime = currentTime + waitBetweenNotes;
                        };
                    };
                    
                    // Wait for remaining window duration
                    remainingTime = localWindowDuration - currentTime;
                    if (remainingTime > 0 and: { remainingTime < 10.0 }) {
                        remainingTime.wait;
                    };
                } { |error|
                    "Error in window % task: %".format(localWindowNumber, error).postln;
                };
                
                "Window % Task completed".format(localWindowNumber).postln;
            });
            
            // Start the task immediately
            windowTask.play;
            
            // Return the task so the ProcMod can manage it
            windowTask
        },
        // Release function
        { |group, envbus|
            "Window % ProcMod released".format(windowNumber).postln;
        }
    )
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                      WINDOW SCHEDULER                                      │
// └─────────────────────────────────────────────────────────────────────────────┘

// Calculate when to trigger next window based on current window timing
~calculateWindowTriggerTime = { |windowData, triggerIndex|
    var triggerTime;
    
    // Simple calculation: trigger when we reach the specified note index
    // Since notes are evenly spaced within the window, we can calculate this easily
    if (triggerIndex < windowData.notes.size) {
        var noteSpacing = windowData.totalDuration * 0.2 / windowData.notes.size;
        triggerTime = noteSpacing * triggerIndex;
    } {
        // If trigger index is beyond window, use 80% of window duration
        triggerTime = windowData.totalDuration * 0.8;
    };
    
    "Window trigger time: %s (for trigger index %)".format(
        triggerTime.round(0.01), triggerIndex
    ).postln;
    
    triggerTime
};

// Create main windowing scheduler task
~createWindowingTask = { |layerName, config, parentDuration|
    var windowing = config.windowing;
    var windowSize = windowing.windowSize;
    var overlapTriggerIndex = windowing.overlapTriggerIndex;
    var stepSize = windowing.stepSize;
    var melodyData = ~getLayerMelodyDynamic.(layerName);
    var activeWindows = List.new;
    var maxWindows = ~getMaxConcurrentWindows.();
    var mainTask;
    
    if (melodyData.notNil && melodyData.patterns.notNil) {
        var pattern = melodyData.patterns[0];
        var totalNotes = pattern.size;
        
        "Creating windowing scheduler: % notes, window=%, trigger=%, step=%".format(
            totalNotes, windowSize, overlapTriggerIndex, stepSize
        ).postln;
        
        // Initialize tracking
        ~layers.activeWindowProcs = List.new;
        
        mainTask = Task({
            var windowIndex = 0;
            var windowNumber = 0;
            var currentTime = 0;
            var keepRunning = true;
            var waitCount;
            
            // Capture parameters locally to avoid scope issues
            var localTotalNotes = totalNotes;
            var localWindowSize = windowSize;
            var localStepSize = stepSize;
            var localOverlapTriggerIndex = overlapTriggerIndex;
            var localMelodyData = melodyData;
            var localMaxWindows = maxWindows;
            var localLayerName = layerName;
            
            // Disable other layers when windowing starts
            ~layers.configs[\layer2].enabled = false;
            ~layers.configs[\layer3].enabled = false;
            "Windowing mode: Layer2 & Layer3 disabled for window VST routing".postln;
            
            // Keep spawning windows - loop if layers looping mode is enabled
            while { keepRunning } {
                var windowData, vstGroup, windowProcMod;
                var triggerTime;
                
                try {
                    // Debug what we're about to try
                    "DEBUG: Creating window % at index % of % total notes".format(
                        windowNumber, windowIndex, localTotalNotes
                    ).postln;
                    
                    // Extract data for this window - add nil checks
                    if (localMelodyData.isNil) {
                        "ERROR: localMelodyData is nil".postln;
                        keepRunning = false;
                    } {
                        windowData = ~extractWindowData.(
                            localMelodyData,
                            windowIndex,
                            localWindowSize,
                            localLayerName
                        );
                        
                        if (windowData.isNil) {
                            "ERROR: windowData is nil for window %".format(windowNumber).postln;
                            keepRunning = false;
                        } {
                            // Assign VST group (cycling)
                            vstGroup = ~getWindowVSTGroup.(windowNumber);
                            
                            if (vstGroup.isNil) {
                                "ERROR: vstGroup is nil for window %".format(windowNumber).postln;
                                keepRunning = false;
                            } {
                                "DEBUG: About to create ProcMod for window % with VST group %".format(
                                    windowNumber, vstGroup
                                ).postln;
                                
                                // Create and start window ProcMod
                                windowProcMod = ~createWindowProcMod.(windowData, vstGroup, windowNumber);
                                if (windowProcMod.notNil) {
                                    windowProcMod.play;
                                    
                                    // Track active window
                                    activeWindows.add(windowProcMod);
                                    ~layers.activeWindowProcs.add(windowProcMod);
                                    
                                    // Calculate when to trigger next window
                                    triggerTime = ~calculateWindowTriggerTime.(windowData, localOverlapTriggerIndex);
                                    
                                    "Window % started, next trigger in %s".format(
                                        windowNumber, triggerTime.round(0.01)
                                    ).postln;
                                    
                                    // Wait until trigger time (with safety check)
                                    if (triggerTime > 0 and: { triggerTime < 10.0 }) {
                                        triggerTime.wait;
                                        currentTime = currentTime + triggerTime;
                                    };
                                    
                                    // Clean up completed windows
                                    activeWindows.removeAllSuchThat({ |proc| proc.isRunning.not });
                                    ~layers.activeWindowProcs.removeAllSuchThat({ |proc| proc.isRunning.not });
                                    
                                    // Check concurrent window count (for monitoring only)
                                    if (activeWindows.size >= localMaxWindows) {
                                        "Maximum concurrent windows (%) reached - continuing".format(localMaxWindows).postln;
                                        // No wait needed - natural timing from trigger intervals handles pacing
                                    };
                                } {
                                    "Failed to create window ProcMod for window %".format(windowNumber).warn;
                                    keepRunning = false;
                                };
                            };
                        };
                    };
                } { |error|
                    "Error in windowing loop: % (class: %, message: %)".format(
                        error, error.class, error.errorString
                    ).postln;
                    error.postProtectedBacktrace;
                    keepRunning = false;
                };
                
                // Advance to next window
                windowIndex = windowIndex + localStepSize;
                windowNumber = windowNumber + 1;
                
                // Check if we've reached the end of the melody
                if (windowIndex >= localTotalNotes) {
                    if (~layers.state.loopingMode) {
                        // Loop back to beginning
                        windowIndex = 0;
                        "Windowing: Looping back to beginning (window %)".format(windowNumber).postln;
                    } {
                        // Single play mode - stop when done
                        "Windowing: Reached end of melody, stopping".postln;
                        keepRunning = false;
                    };
                };
                
                // Safety check to prevent infinite loops
                if (windowNumber > 1000) {
                    "Safety limit reached, stopping windowing".warn;
                    keepRunning = false;
                };
                
                // Check if parent is still running
                if (~layers.parentProc.isNil or: { ~layers.parentProc.isRunning.not }) {
                    "Parent stopped, ending windowing".postln;
                    keepRunning = false;
                };
            };
            
            "All windows spawned, waiting for completion...".postln;
            
            // Wait for all windows to complete (with timeout)
            waitCount = 0;
            while { activeWindows.any({ |proc| proc.isRunning }) and: { waitCount < 500 } } {
                0.1.wait;
                waitCount = waitCount + 1;
                activeWindows.removeAllSuchThat({ |proc| proc.isRunning.not });
                ~layers.activeWindowProcs.removeAllSuchThat({ |proc| proc.isRunning.not });
                
                // Check if parent is still running
                if (~layers.parentProc.isNil or: { ~layers.parentProc.isRunning.not }) {
                    "Parent stopped during cleanup, ending windowing".postln;
                    waitCount = 500; // Force loop exit
                };
            };
            
            if (waitCount >= 500) {
                "Windowing cleanup timeout, forcing completion".warn;
            };
            
            "All windows completed for layer %".format(localLayerName).postln;
        });
        
        mainTask
    } {
        nil
    }
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                      WINDOW MANAGEMENT                                     │
// └─────────────────────────────────────────────────────────────────────────────┘

// Stop all windows for a layer
~stopLayerWindows = { |layerName|
    if (~layers.activeWindowProcs.notNil) {
        "Stopping all window ProcMods...".postln;
        ~layers.activeWindowProcs.do { |proc|
            if (proc.notNil && proc.isRunning) {
                proc.release;
            };
        };
        ~layers.activeWindowProcs.clear;
    };
    
    // Re-enable other layers
    ~layers.configs[\layer2].enabled = true;
    ~layers.configs[\layer3].enabled = true;
    "Normal mode: All layers re-enabled".postln;
};

// Stop all windows for all layers
~stopAllWindows = {
    ~stopLayerWindows.(\layer1);
};

"Dependent layers windowing system loaded".postln;