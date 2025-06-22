/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                            CLIP MANAGEMENT GUI                               ║
║                            Record, manage, and play                          ║
║                            MIDI clips with timing data                       ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                           INITIALIZATION & PATHS                           │
// └─────────────────────────────────────────────────────────────────────────────┘

// Get the directory path for this file
~clipMgmtDir = thisProcess.nowExecutingPath.dirname;

// Load JSONlib if not already loaded
if (JSONlib.isNil) {
    try {
        (~clipMgmtDir +/+ "../reference/JSONlib.sc").load;
        "JSONlib loaded for clip saving".postln;
    } { |error|
        "JSONlib not found - using fallback format".postln;
    };
};

// Global clip management data
~clipMgmtData = (
    clips: [],
    selectedClipIndex: 0,
    recordingState: \idle,  // \idle, \recording, \processing
    recordedEvents: [],
    recordStartTime: nil,
    recordTimeout: nil,
    playbackMode: \manual,  // \manual or \auto (sequence advance)
    sequenceIndex: 0,
    sequenceRunning: false
);

// Storage for active clip playback ProcMods
~clipPlaybackProcs = Dictionary.new;

// UI references
~clipMgmtWindow = nil;
~clipMgmtViews = ();

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                           CLIP RECORDING SYSTEM                            │
// └─────────────────────────────────────────────────────────────────────────────┘

// Start MIDI recording for clips
~startClipRecording = {
    if (~clipMgmtData.recordingState != \idle) {
        "Recording already in progress".postln;
    } {
        "🔴 Starting clip recording...".postln;
        
        // Initialize recording state
        ~clipMgmtData.recordingState = \recording;
        ~clipMgmtData.recordedEvents = [];
        ~clipMgmtData.recordStartTime = Main.elapsedTime;
        
        // Update UI
        { 
            if (~clipMgmtViews.recordButton.notNil) {
                ~clipMgmtViews.recordButton.states = [["⏹ STOP", Color.white, Color.red]];
                ~clipMgmtViews.recordButton.refresh;
            };
            if (~clipMgmtViews.statusText.notNil) {
                ~clipMgmtViews.statusText.string = "🔴 RECORDING... (press stop when done)";
            };
        }.defer;
        
        // Setup MIDI recording
        if (~clipRecordMIDIdef.notNil) {
            ~clipRecordMIDIdef.free;
        };
        
        ~clipRecordMIDIdef = MIDIdef.noteOn(\clipRecording, { |velocity, note, channel, srcID|
            var eventTime = Main.elapsedTime - ~clipMgmtData.recordStartTime;
            var event = (
                type: \noteOn,
                time: eventTime,
                note: note,
                channel: channel,
                velocity: velocity
            );
            
            ~clipMgmtData.recordedEvents = ~clipMgmtData.recordedEvents ++ [event];
            
            // Update UI with event count
            {
                if (~clipMgmtViews.statusText.notNil) {
                    ~clipMgmtViews.statusText.string = "🔴 RECORDING... % events captured".format(
                        ~clipMgmtData.recordedEvents.size
                    );
                };
            }.defer;
        });
        
        // Set timeout to auto-stop recording
        ~clipMgmtData.recordTimeout = AppClock.sched(30.0, {
            "Auto-stopping recording after 30 seconds".postln;
            ~stopClipRecording.();
            nil;
        });
    };
};

// Stop MIDI recording and process clip
~stopClipRecording = {
    if (~clipMgmtData.recordingState == \recording) {
        "⏹ Stopping clip recording...".postln;
        
        // Update state
        ~clipMgmtData.recordingState = \processing;
        
        // Clean up MIDI recording
        if (~clipRecordMIDIdef.notNil) {
            ~clipRecordMIDIdef.free;
            ~clipRecordMIDIdef = nil;
        };
        
        // Cancel timeout
        if (~clipMgmtData.recordTimeout.notNil) {
            ~clipMgmtData.recordTimeout.clear;
        };
        
        // Update UI
        { 
            if (~clipMgmtViews.recordButton.notNil) {
                ~clipMgmtViews.recordButton.states = [["● RECORD", Color.black, Color.green]];
                ~clipMgmtViews.recordButton.refresh;
            };
            if (~clipMgmtViews.statusText.notNil) {
                ~clipMgmtViews.statusText.string = "Processing recorded clip...";
            };
        }.defer;
        
        // Process recorded events
        ~processRecordedClip.();
    } {
        "No recording in progress".postln;
    };
};

// Process recorded events into clip format
~processRecordedClip = {
    var notePairs = [], totalDuration = 0, clipName, timestamp, newClip;
    
    if (~clipMgmtData.recordedEvents.size == 0) {
        "No events recorded".postln;
        ~clipMgmtData.recordingState = \idle;
        {
            if (~clipMgmtViews.statusText.notNil) {
                ~clipMgmtViews.statusText.string = "No events recorded";
            };
        }.defer;
    } {
        "Processing % recorded events...".format(~clipMgmtData.recordedEvents.size).postln;
        
        // Convert events to note pairs with timing
        ~clipMgmtData.recordedEvents.do { |event|
            var notePair = (
                note: event.note,
                startTime: event.time,
                duration: 0.3,  // Default duration for single note events
                velocity: event.velocity,
                channel: event.channel
            );
            notePairs = notePairs ++ [notePair];
        };
        
        // Calculate total duration
        if (notePairs.size > 0) {
            totalDuration = notePairs.last.startTime + notePairs.last.duration;
        };
        
        // Generate clip name
        timestamp = Date.getDate.format("%d%m%y_%H%M%S");
        clipName = "clip-" ++ timestamp;
        
        // Create clip data structure
        newClip = (
            key: clipName,
            name: clipName ++ " (recorded clip)",
            pattern: notePairs.collect({ |np| np.note }),  // Legacy compatibility
            velocityFirst: 1.0,
            velocityLast: 1.0,
            loopCount: 1,
            clipLoopCount: 1,  // Individual clip loop count for ProcMod looping (0 = infinite)
            loopMode: \forward,  // \forward, \reverse, \pingpong, \random
            active: true,
            isClip: true,
            clipData: (
                notePairs: notePairs,
                duration: totalDuration,
                eventCount: ~clipMgmtData.recordedEvents.size,
                metadata: (
                    recordedAt: timestamp,
                    noteCount: notePairs.size,
                    recordingDuration: totalDuration
                )
            )
        );
        
        // Add to clips collection
        ~clipMgmtData.clips = ~clipMgmtData.clips ++ [newClip];
        
        // Update the clip system sequence if functions are available
        if (~refreshClipSequence.notNil) {
            ~refreshClipSequence.();
        };
        
        // Create ProcMod for the new clip so it can be played
        if (~createClipProc.notNil and: { ~melodyProcs.notNil }) {
            ~melodyProcs[newClip[\key]] = ~createClipProc.(newClip, newClip[\key]);
            "✅ ProcMod created for new clip: %".format(newClip[\key]).postln;
        } {
            "❌ Cannot create ProcMod - clip system not fully loaded".postln;
        };
        
        // Debug: verify clip integration
        "🔍 Checking clip integration:".postln;
        "- isValidClip: %".format(~isValidClip.(newClip)).postln;
        "- isClipKey: %".format(if (~isClipKey.notNil) { ~isClipKey.(newClip[\key]) } { "function not available" }).postln;
        "- clipData structure: %".format(newClip[\clipData].keys).postln;
        
        // Auto-save the clip
        ~saveClipToFileStandalone.(newClip);
        
        "✅ Clip created: % (% notes, %s duration)".format(
            clipName, 
            notePairs.size, 
            totalDuration.round(0.01)
        ).postln;
        
        // Update UI
        ~clipMgmtData.recordingState = \idle;
        ~updateClipManagerUI.();
        
        {
            if (~clipMgmtViews.statusText.notNil) {
                ~clipMgmtViews.statusText.string = "✅ Clip '{}' created and auto-saved ({} notes)".format(
                    clipName, notePairs.size
                );
            };
        }.defer;
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         PROCMOD CLIP LOOPING SYSTEM                        │
// └─────────────────────────────────────────────────────────────────────────────┘

// Create a ProcMod for looping clip playback with enhanced modes
~createLoopingClipProc = { |clip, loopCount=nil|
    var effectiveLoopCount = loopCount ?? { clip[\clipLoopCount] ?? 1 };
    var loopMode = clip[\loopMode] ?? \forward;
    var id = (clip[\key] ++ "_loop").asSymbol;
    var env = Env.asr(0.01, 1.0, 0.1, \lin);  // ASR envelope like sketch system
    var isInfinite = (effectiveLoopCount == 0) || (effectiveLoopCount == inf);
    
    if (isInfinite) {
        "🔄 Creating INFINITE looping ProcMod for clip: % (mode: %)".format(clip[\key], loopMode).postln;
    } {
        "🔄 Creating looping ProcMod for clip: % (% loops, mode: %)".format(clip[\key], effectiveLoopCount, loopMode).postln;
    };
    
    ProcMod.new(
        env,          // ASR envelope
        1.0,          // Amplitude
        id,           // Unique ID
        nil,          // Group (create new)
        0,            // addAction
        1,            // target
        
        // Main function - executes when ProcMod plays
        { |group, envbus|
            var task = Task({
                var currentIteration = 0;
                var notePairs = clip[\clipData][\notePairs];
                var processedNotePairs;
                
                // Process note pairs based on loop mode
                processedNotePairs = switch(loopMode,
                    \forward, { notePairs },
                    \reverse, { notePairs.reverse },
                    \pingpong, { notePairs ++ notePairs.drop(1).reverse.drop(-1) },
                    \random, { notePairs.scramble }
                );
                
                if (isInfinite) {
                    "▶️ Starting INFINITE clip loop playback".postln;
                } {
                    "▶️ Starting clip loop playback: % iterations".format(effectiveLoopCount).postln;
                };
                
                // Main loop - infinite or counted
                while { 
                    if (isInfinite) { 
                        ~clipPlaybackProcs[clip[\key]].notNil && ~clipPlaybackProcs[clip[\key]].isRunning 
                    } { 
                        currentIteration < effectiveLoopCount 
                    }
                } {
                    var tempoScale = if (~clipControl.notNil) { ~clipControl.tempoScale } { 1.0 };
                    var clipDuration = clip[\clipData][\duration] / tempoScale;
                    var scheduledNotes = [];
                    
                    if (isInfinite) {
                        "🎵 Infinite loop iteration % (tempo: %x)".format(
                            currentIteration + 1, tempoScale.round(0.01)
                        ).postln;
                    } {
                        "🎵 Loop iteration % of % (tempo: %x)".format(
                            currentIteration + 1, effectiveLoopCount, tempoScale.round(0.01)
                        ).postln;
                    };
                    
                    // Regenerate random sequence for each iteration if random mode
                    if (loopMode == \random) {
                        processedNotePairs = notePairs.scramble;
                    };
                    
                    // Schedule all notes for this iteration
                    processedNotePairs.do { |notePair|
                        var adjustedTime = notePair.startTime / tempoScale;
                        var adjustedDuration = notePair.duration / tempoScale;
                        
                        var scheduledTask = SystemClock.sched(adjustedTime, {
                            NetAddr.localAddr.sendMsg('/note/on', 0, 
                                notePair.note, 
                                notePair.velocity,
                                adjustedDuration,
                                0, 0, 0);
                            nil;
                        });
                        
                        scheduledNotes = scheduledNotes ++ [scheduledTask];
                    };
                    
                    // Wait for clip to complete
                    clipDuration.wait;
                    
                    // Add inter-loop delay
                    if (isInfinite || (currentIteration < (effectiveLoopCount - 1))) {
                        var gapTime = clipDuration * 0.05;  // 5% gap between loops
                        "⏸ Inter-loop gap: %s".format(gapTime.round(0.01)).postln;
                        gapTime.wait;
                    };
                    
                    currentIteration = currentIteration + 1;
                };
                
                "✅ Clip loop completed: %".format(id).postln;
            });
            
            task.play;
            task; // Return task for ProcMod tracking
        },
        
        // Release function - executes after ProcMod has fully released
        { |group, envbus|
            "🛑 ProcMod clip loop released: %".format(id).postln;
            // Clean up any remaining scheduled notes
        },
        
        // onReleaseFunc - executes when release is triggered
        { |group, envbus|
            "⏹ Releasing ProcMod clip loop: %".format(id).postln;
            // Clean up without triggering emergency stop to avoid loops
        }
    );
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                       REAL-TIME LOOP CONTROL FUNCTIONS                      │
// └─────────────────────────────────────────────────────────────────────────────┘

// Update loop count for currently playing clip
~updateClipLoopCount = { |clipKey, newLoopCount|
    var selectedClip = ~clipMgmtData.clips.detect({ |c| c[\key] == clipKey });
    
    if (selectedClip.notNil) {
        selectedClip[\clipLoopCount] = newLoopCount;
        "🔄 Updated loop count for %: % loops".format(clipKey, if (newLoopCount == 0) { "infinite" } { newLoopCount }).postln;
        
        // If currently playing, restart with new loop count
        if (~clipPlaybackProcs[clipKey].notNil && ~clipPlaybackProcs[clipKey].isRunning) {
            "♻️ Restarting % with new loop count".format(clipKey).postln;
            ~clipPlaybackProcs[clipKey].release;
            ~clipPlaybackProcs.removeAt(clipKey);
            
            // Small delay then restart
            {
                var proc = ~createLoopingClipProc.(selectedClip);
                ~clipPlaybackProcs[clipKey] = proc;
                proc.play;
            }.defer(0.1);
        };
        
        // Update UI if this is the selected clip
        if (~clipMgmtData.selectedClipIndex < ~clipMgmtData.clips.size &&
           ~clipMgmtData.clips[~clipMgmtData.selectedClipIndex][\key] == clipKey) {
            ~updateClipManagerUI.();
        };
    } {
        "❌ Clip not found: %".format(clipKey).postln;
    };
};

// Update loop mode for clip
~updateClipLoopMode = { |clipKey, newLoopMode|
    var selectedClip = ~clipMgmtData.clips.detect({ |c| c[\key] == clipKey });
    
    if (selectedClip.notNil) {
        selectedClip[\loopMode] = newLoopMode;
        "🔄 Updated loop mode for %: %".format(clipKey, newLoopMode).postln;
        
        // If currently playing, restart with new loop mode
        if (~clipPlaybackProcs[clipKey].notNil && ~clipPlaybackProcs[clipKey].isRunning) {
            "♻️ Restarting % with new loop mode".format(clipKey).postln;
            ~clipPlaybackProcs[clipKey].release;
            ~clipPlaybackProcs.removeAt(clipKey);
            
            // Small delay then restart
            {
                var proc = ~createLoopingClipProc.(selectedClip);
                ~clipPlaybackProcs[clipKey] = proc;
                proc.play;
            }.defer(0.1);
        };
        
        // Update UI if this is the selected clip
        if (~clipMgmtData.selectedClipIndex < ~clipMgmtData.clips.size &&
           ~clipMgmtData.clips[~clipMgmtData.selectedClipIndex][\key] == clipKey) {
            ~updateClipManagerUI.();
        };
    } {
        "❌ Clip not found: %".format(clipKey).postln;
    };
};

// Quick functions for common loop adjustments
~setInfiniteLoop = { |clipKey| ~updateClipLoopCount.(clipKey, 0); };
~setLoopCount = { |clipKey, count| ~updateClipLoopCount.(clipKey, count); };
~setLoopMode = { |clipKey, mode| ~updateClipLoopMode.(clipKey, mode); };

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                        QUANTIZED/SYNCHRONIZED PLAYBACK                      │
// └─────────────────────────────────────────────────────────────────────────────┘

// Play clip synchronized to beat grid
~playClipQuantized = { |clip, quantization=4|
    var currentBeat, nextBeat, delay, proc;
    
    // Use TempoClock if available, otherwise immediate playback
    if (TempoClock.default.notNil) {
        currentBeat = TempoClock.default.beats;
        nextBeat = (currentBeat / quantization).ceil * quantization;
        delay = (nextBeat - currentBeat) * TempoClock.default.beatDur;
        
        "🕐 Quantizing clip start: current beat %, next beat %, delay %s".format(
            currentBeat.round(0.01), nextBeat, delay.round(0.01)
        ).postln;
        
        // Schedule the playback
        SystemClock.sched(delay, {
            proc = ~createLoopingClipProc.(clip);
            ~clipPlaybackProcs[clip[\key]] = proc;
            proc.play;
            "🎵 Quantized playback started for: %".format(clip[\name]).postln;
            nil;
        });
    } {
        // Immediate playback if no TempoClock
        "⚠️ No TempoClock - playing immediately".postln;
        proc = ~createLoopingClipProc.(clip);
        ~clipPlaybackProcs[clip[\key]] = proc;
        proc.play;
    };
};

// Play selected clip with quantization
~playSelectedClipQuantized = { |quantization=4|
    var selectedClip;
    
    if (~clipMgmtData.clips.size > 0 and: { ~clipMgmtData.selectedClipIndex < ~clipMgmtData.clips.size }) {
        selectedClip = ~clipMgmtData.clips[~clipMgmtData.selectedClipIndex];
        
        // Stop any existing playback for this clip
        if (~clipPlaybackProcs[selectedClip[\key]].notNil) {
            "⏹ Stopping existing playback for: %".format(selectedClip[\key]).postln;
            ~clipPlaybackProcs[selectedClip[\key]].release;
            ~clipPlaybackProcs.removeAt(selectedClip[\key]);
        };
        
        ~playClipQuantized.(selectedClip, quantization);
        
        {
            if (~clipMgmtViews.statusText.notNil) {
                ~clipMgmtViews.statusText.string = "🕐 Quantized start: {} (Q: {})".format(
                    selectedClip[\name], quantization
                );
            };
        }.defer;
    } {
        "No clip selected to play".postln;
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                            CLIP FILE MANAGEMENT                            │
// └─────────────────────────────────────────────────────────────────────────────┘

// Load clips from file manager or previous session
~loadClipsFromStorage = {
    var loadedClips = [];
    
    "Loading clips from clip storage...".postln;
    
    // Try to load clips from file manager if available
    if (~listClipFiles.notNil) {
        var clipFiles = ~listClipFiles.();
        if (clipFiles.size > 0) {
            "Found % clip files available for loading".format(clipFiles.size).postln;
        };
    };
    
    // For now, just refresh the UI with existing clips
    ~updateClipManagerUI.();
    
    "Clip storage check complete - % clips in memory".format(~clipMgmtData.clips.size).postln;
};

// Standalone clip save function (works without clip system)
~saveClipToFileStandalone = { |clip, filename=nil|
    var saveData, filepath, baseDir, timestamp, result = false;
    
    if (clip.isNil) {
        "No clip provided to save".postln;
        ^false;
    };
    
    // Generate filename if not provided
    if (filename.isNil) {
        timestamp = Date.getDate.format("%Y%m%d_%H%M%S");
        filename = "clip_" ++ clip[\key] ++ "_" ++ timestamp ++ ".json";
    };
    
    // Ensure .json extension
    if (filename.endsWith(".json").not) {
        filename = filename ++ ".json";
    };
    
    // Build file path - use consistent path resolution with clip system
    if (~clipSystemDir.notNil) {
        baseDir = ~clipSystemDir.dirname.dirname; // From clip-system/ up to project root
    } {
        baseDir = ~clipMgmtDir.dirname.dirname; // Fallback: from setup/ up to project root
    };
    filepath = baseDir +/+ "data" +/+ "clips" +/+ filename;
    
    // Prepare save data
    saveData = (
        formatVersion: "1.0",
        savedAt: Date.getDate.stamp,
        clipData: clip,
        metadata: (
            originalKey: clip[\key],
            savedBy: "clip-management-gui",
            systemVersion: "1.0"
        )
    );
    
    // Create data directories if they don't exist
    File.mkdir(baseDir +/+ "data");
    File.mkdir(baseDir +/+ "data" +/+ "clips");
    
    // Save to file
    try {
        var jsonString;
        
        // Use JSONlib if available, otherwise simple string format
        if (JSONlib.notNil) {
            jsonString = JSONlib.convertToJSON(saveData);
        } {
            // Simple fallback format
            jsonString = saveData.asCompileString;
        };
        
        File.use(filepath, "w", { |file|
            file.write(jsonString);
        });
        
        "✅ Clip saved: % → %".format(clip[\key], filename).postln;
        "   Path: %".format(filepath).postln;
        
        result = true;
    } { |error|
        "ERROR: Failed to save clip: %".format(error).postln;
        result = false;
    };
    
    result;
};

// Save selected clip to individual file
~saveSelectedClipToFile = {
    var selectedClip;
    
    if (~clipMgmtData.clips.size > 0 and: { ~clipMgmtData.selectedClipIndex < ~clipMgmtData.clips.size }) {
        selectedClip = ~clipMgmtData.clips[~clipMgmtData.selectedClipIndex];
        
        // Try clip system first, then use standalone
        if (~saveClip.notNil) {
            if (~saveClip.(selectedClip[\key])) {
                {
                    if (~clipMgmtViews.statusText.notNil) {
                        ~clipMgmtViews.statusText.string = "✅ Clip '{}' saved to file".format(selectedClip[\name]);
                    };
                }.defer;
            } {
                {
                    if (~clipMgmtViews.statusText.notNil) {
                        ~clipMgmtViews.statusText.string = "❌ Failed to save clip to file";
                    };
                }.defer;
            };
        } {
            // Use standalone save function
            if (~saveClipToFileStandalone.(selectedClip)) {
                {
                    if (~clipMgmtViews.statusText.notNil) {
                        ~clipMgmtViews.statusText.string = "✅ Clip '{}' saved to data/ folder".format(selectedClip[\name]);
                    };
                }.defer;
            } {
                {
                    if (~clipMgmtViews.statusText.notNil) {
                        ~clipMgmtViews.statusText.string = "❌ Failed to save clip";
                    };
                }.defer;
            };
        };
    } {
        "No clip selected to save".postln;
        {
            if (~clipMgmtViews.statusText.notNil) {
                ~clipMgmtViews.statusText.string = "❌ No clip selected";
            };
        }.defer;
    };
};

// Load clip from file
~loadClipFromFile = {
    Dialog.openPanel({ |path|
        var filename = PathName(path).fileName;
        
        if (~loadClip.notNil) {
            var loadedClip = ~loadClip.(filename, false);  // Load but don't add to main melody data
            
            if (loadedClip.notNil) {
                ~clipMgmtData.clips = ~clipMgmtData.clips ++ [loadedClip];
                ~updateClipManagerUI.();
                
                {
                    if (~clipMgmtViews.statusText.notNil) {
                        ~clipMgmtViews.statusText.string = "✅ Clip loaded from file: {}".format(filename);
                    };
                }.defer;
            } {
                {
                    if (~clipMgmtViews.statusText.notNil) {
                        ~clipMgmtViews.statusText.string = "❌ Failed to load clip from file";
                    };
                }.defer;
            };
        } {
            "Clip file load function not available - load clip system first".postln;
            {
                if (~clipMgmtViews.statusText.notNil) {
                    ~clipMgmtViews.statusText.string = "❌ Load clip system first";
                };
            }.defer;
        };
    }, {
        // Cancel callback
        "File load cancelled".postln;
    });
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                            CLIP PLAYBACK                                   │
// └─────────────────────────────────────────────────────────────────────────────┘

// Play selected clip using ProcMod looping
~playSelectedClip = {
    var selectedClip, proc;
    
    if (~clipMgmtData.clips.size > 0 and: { ~clipMgmtData.selectedClipIndex < ~clipMgmtData.clips.size }) {
        selectedClip = ~clipMgmtData.clips[~clipMgmtData.selectedClipIndex];
        
        "▶️ Playing clip with ProcMod: % (% loops)".format(
            selectedClip[\name], 
            selectedClip[\clipLoopCount] ? 1
        ).postln;
        
        // Stop any existing playback for this clip
        if (~clipPlaybackProcs[selectedClip[\key]].notNil) {
            "⏹ Stopping existing playback for: %".format(selectedClip[\key]).postln;
            ~clipPlaybackProcs[selectedClip[\key]].release;
            ~clipPlaybackProcs.removeAt(selectedClip[\key]);
        };
        
        // Create and start ProcMod for this clip
        if (selectedClip[\clipData].notNil) {
            proc = ~createLoopingClipProc.(selectedClip);
            ~clipPlaybackProcs[selectedClip[\key]] = proc;
            proc.play;
            
            "✅ Started ProcMod playback for: %".format(selectedClip[\key]).postln;
        } {
            "❌ No clip data available for: %".format(selectedClip[\name]).postln;
        };
        
        {
            if (~clipMgmtViews.statusText.notNil) {
                ~clipMgmtViews.statusText.string = "▶️ Playing: {} ({} loops)".format(
                    selectedClip[\name], 
                    selectedClip[\clipLoopCount] ? 1
                );
            };
        }.defer;
    } {
        "No clip selected to play".postln;
        {
            if (~clipMgmtViews.statusText.notNil) {
                ~clipMgmtViews.statusText.string = "❌ No clip selected";
            };
        }.defer;
    };
};

// Stop all clip playback
~stopAllClipPlayback = {
    "⏹ Stopping all clip playback ProcMods...".postln;
    
    // Release all active ProcMod playback instances
    if (~clipPlaybackProcs.notNil) {
        ~clipPlaybackProcs.keysValuesDo { |key, proc|
            if (proc.notNil && proc.isRunning) {
                "⏹ Releasing ProcMod for clip: %".format(key).postln;
                proc.release;
            };
        };
        ~clipPlaybackProcs.clear;
    };
    
    "✅ All clip playback stopped".postln;
    
    {
        if (~clipMgmtViews.statusText.notNil) {
            ~clipMgmtViews.statusText.string = "⏹ All playback stopped";
        };
    }.defer;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                       CONTINUOUS CLIP SEQUENCE PLAYBACK                     │
// └─────────────────────────────────────────────────────────────────────────────┘

// Storage for sequence playback
~clipSequenceTask = nil;

// Start continuous clip sequence (like musical-implementation)
~startClipSequence = {
    var activeClips, sequenceIndex = 0;
    
    // Stop any existing sequence
    if (~clipSequenceTask.notNil) {
        ~clipSequenceTask.stop;
        ~clipSequenceTask = nil;
    };
    
    // Get active clips
    activeClips = ~clipMgmtData.clips.select({ |clip| clip[\active] == true });
    
    if (activeClips.size == 0) {
        "❌ No active clips to sequence".postln;
        ^nil;
    };
    
    "🎬 Starting clip sequence with % active clips".format(activeClips.size).postln;
    ~clipMgmtData.sequenceRunning = true;
    ~clipMgmtData.sequenceIndex = 0;
    
    ~clipSequenceTask = Task({
        while { ~clipMgmtData.sequenceRunning } {
            var currentClip = activeClips[~clipMgmtData.sequenceIndex];
            var clipDuration, totalWaitTime, proc;
            var effectiveLoopCount = currentClip[\clipLoopCount] ?? 1;
            var tempoScale = if (~clipControl.notNil) { ~clipControl.tempoScale } { 1.0 };
            
            "🎵 Sequence: Playing clip % of % - % (% loops)".format(
                ~clipMgmtData.sequenceIndex + 1, 
                activeClips.size, 
                currentClip[\name],
                if (effectiveLoopCount == 0) { "infinite" } { effectiveLoopCount }
            ).postln;
            
            // Calculate how long to wait for this clip
            clipDuration = currentClip[\clipData][\duration] / tempoScale;
            
            if (effectiveLoopCount == 0) {
                // Infinite loops in sequence don't make sense, treat as single play
                totalWaitTime = clipDuration;
                "⚠️ Infinite loop in sequence - playing once".postln;
            } {
                // Account for loop count and gaps
                totalWaitTime = (clipDuration * effectiveLoopCount) + (clipDuration * 0.05 * (effectiveLoopCount - 1));
            };
            
            // Stop any existing playback for this clip
            if (~clipPlaybackProcs[currentClip[\key]].notNil) {
                ~clipPlaybackProcs[currentClip[\key]].release;
                ~clipPlaybackProcs.removeAt(currentClip[\key]);
            };
            
            // Create and start clip with original loop count
            proc = ~createLoopingClipProc.(currentClip);
            ~clipPlaybackProcs[currentClip[\key]] = proc;
            proc.play;
            
            // Wait for clip to complete
            totalWaitTime.wait;
            
            // Advance sequence based on mode
            if (~clipMgmtData.playbackMode == \manual) {
                // Manual mode: stay on current clip
                "🔄 Manual mode: repeating %".format(currentClip[\name]).postln;
            } {
                // Auto mode: advance to next clip
                ~clipMgmtData.sequenceIndex = (~clipMgmtData.sequenceIndex + 1) % activeClips.size;
                if (~clipMgmtData.sequenceIndex == 0) {
                    "🔄 Sequence completed, starting over".postln;
                };
            };
        };
        
        "✅ Clip sequence stopped".postln;
    }).play;
    
    {
        if (~clipMgmtViews.statusText.notNil) {
            ~clipMgmtViews.statusText.string = "🎬 Sequence: % clips ({})".format(
                activeClips.size, ~clipMgmtData.playbackMode
            );
        };
    }.defer;
};

// Stop clip sequence
~stopClipSequence = {
    "⏹ Stopping clip sequence".postln;
    ~clipMgmtData.sequenceRunning = false;
    
    if (~clipSequenceTask.notNil) {
        ~clipSequenceTask.stop;
        ~clipSequenceTask = nil;
    };
    
    {
        if (~clipMgmtViews.statusText.notNil) {
            ~clipMgmtViews.statusText.string = "⏹ Sequence stopped";
        };
    }.defer;
};

// Toggle between manual and auto sequence modes
~toggleSequenceMode = {
    ~clipMgmtData.playbackMode = if (~clipMgmtData.playbackMode == \manual) { \auto } { \manual };
    "🔄 Sequence mode: %".format(~clipMgmtData.playbackMode).postln;
    
    {
        if (~clipMgmtViews.statusText.notNil) {
            ~clipMgmtViews.statusText.string = "🔄 Mode: {}".format(~clipMgmtData.playbackMode);
        };
    }.defer;
};

// Navigate sequence manually (like in musical-implementation)
~nextClipInSequence = {
    var activeClips = ~clipMgmtData.clips.select({ |clip| clip[\active] == true });
    
    if (activeClips.size > 0) {
        ~clipMgmtData.sequenceIndex = (~clipMgmtData.sequenceIndex + 1) % activeClips.size;
        "➡️ Next clip: % (% of %)".format(
            activeClips[~clipMgmtData.sequenceIndex][\name],
            ~clipMgmtData.sequenceIndex + 1,
            activeClips.size
        ).postln;
    };
};

~prevClipInSequence = {
    var activeClips = ~clipMgmtData.clips.select({ |clip| clip[\active] == true });
    
    if (activeClips.size > 0) {
        ~clipMgmtData.sequenceIndex = (~clipMgmtData.sequenceIndex - 1 + activeClips.size) % activeClips.size;
        "⬅️ Previous clip: % (% of %)".format(
            activeClips[~clipMgmtData.sequenceIndex][\name],
            ~clipMgmtData.sequenceIndex + 1,
            activeClips.size
        ).postln;
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                               GUI CREATION                                 │
// └─────────────────────────────────────────────────────────────────────────────┘

// Update UI with current clip data
~updateClipManagerUI = {
    if (~clipMgmtViews.clipList.notNil) {
        {
            var listItems = ~clipMgmtData.clips.collect({ |clip, i|
                var duration = if (clip[\clipData].notNil) { 
                    clip[\clipData][\duration].round(0.01) 
                } { 
                    "?" 
                };
                var noteCount = if (clip[\clipData].notNil) { 
                    clip[\clipData][\notePairs].size 
                } { 
                    "?" 
                };
                var active = if (clip[\active] == true) { "🎵" } { "🔇" };
                var loopCount = clip[\clipLoopCount] ? 1;
                var loopMode = clip[\loopMode] ? \forward;
                var loopDisplay = if (loopCount == 0) { "∞" } { loopCount.asString ++ "x" };
                
                "% {} - {}s ({} notes, {}, {})".format(active, clip[\name], duration, noteCount, loopDisplay, loopMode);
            });
            
            ~clipMgmtViews.clipList.items = listItems;
            
            // Ensure selected index is valid
            if (~clipMgmtData.selectedClipIndex >= ~clipMgmtData.clips.size) {
                ~clipMgmtData.selectedClipIndex = max(0, ~clipMgmtData.clips.size - 1);
            };
            
            if (~clipMgmtData.clips.size > 0) {
                ~clipMgmtViews.clipList.value = ~clipMgmtData.selectedClipIndex;
                ~updateClipDetails.();
            };
        }.defer;
    };
};

// Update clip details panel
~updateClipDetails = {
    var selectedClip;
    
    if (~clipMgmtData.clips.size > 0 and: { ~clipMgmtData.selectedClipIndex < ~clipMgmtData.clips.size }) {
        selectedClip = ~clipMgmtData.clips[~clipMgmtData.selectedClipIndex];
        
        {
            if (~clipMgmtViews.nameField.notNil) {
                ~clipMgmtViews.nameField.string = selectedClip[\name] ? "";
            };
            if (~clipMgmtViews.keyField.notNil) {
                ~clipMgmtViews.keyField.string = selectedClip[\key] ? "";
            };
            if (~clipMgmtViews.activeCheck.notNil) {
                ~clipMgmtViews.activeCheck.value = selectedClip[\active] == true;
            };
            if (~clipMgmtViews.durationText.notNil) {
                var duration = if (selectedClip[\clipData].notNil) { 
                    selectedClip[\clipData][\duration].round(0.001) 
                } { 
                    "Unknown" 
                };
                ~clipMgmtViews.durationText.string = "Duration: %s".format(duration);
            };
            if (~clipMgmtViews.noteCountText.notNil) {
                var noteCount = if (selectedClip[\clipData].notNil) { 
                    selectedClip[\clipData][\notePairs].size 
                } { 
                    "Unknown" 
                };
                ~clipMgmtViews.noteCountText.string = "Notes: %".format(noteCount);
            };
            if (~clipMgmtViews.loopCountField.notNil) {
                ~clipMgmtViews.loopCountField.value = selectedClip[\clipLoopCount] ? 1;
            };
            if (~clipMgmtViews.loopModeMenu.notNil) {
                var modeIndex = [\forward, \reverse, \pingpong, \random].indexOf(selectedClip[\loopMode] ? \forward);
                ~clipMgmtViews.loopModeMenu.value = modeIndex ? 0;
            };
        }.defer;
    };
};

// Save clip details from UI
~saveClipDetails = {
    var selectedClip;
    
    if (~clipMgmtData.clips.size > 0 and: { ~clipMgmtData.selectedClipIndex < ~clipMgmtData.clips.size }) {
        selectedClip = ~clipMgmtData.clips[~clipMgmtData.selectedClipIndex];
        
        // Update from UI fields
        if (~clipMgmtViews.nameField.notNil) {
            selectedClip[\name] = ~clipMgmtViews.nameField.string;
        };
        if (~clipMgmtViews.activeCheck.notNil) {
            selectedClip[\active] = ~clipMgmtViews.activeCheck.value;
        };
        if (~clipMgmtViews.loopCountField.notNil) {
            selectedClip[\clipLoopCount] = ~clipMgmtViews.loopCountField.value.asInteger.max(0);
        };
        if (~clipMgmtViews.loopModeMenu.notNil) {
            var modes = [\forward, \reverse, \pingpong, \random];
            selectedClip[\loopMode] = modes[~clipMgmtViews.loopModeMenu.value];
        };
        
        // Clip details saved to clip management data only
        
        ~updateClipManagerUI.();
        
        {
            if (~clipMgmtViews.statusText.notNil) {
                ~clipMgmtViews.statusText.string = "✅ Clip details saved";
            };
        }.defer;
    };
};

// Main GUI creation function
~createClipManagerGUI = {
    var window, mainLayout, topControls, contentLayout, leftPanel, rightPanel;
    var clipList, recordButton, playButton, stopButton, loadButton, saveButton;
    var nameField, keyField, activeCheck, durationText, noteCountText, loopCountField, loopModeMenu, statusText;
    var sequenceButton, modeButton, quantButton;
    
    // Close existing window
    if (~clipMgmtWindow.notNil) {
        ~clipMgmtWindow.close;
    };
    
    // Create main window
    window = Window.new("Clip Management", Rect(100, 100, 800, 600))
        .background_(Color.grey(0.9))
        .onClose_({
            "Clip Manager closed".postln;
            if (~clipRecordMIDIdef.notNil) {
                ~clipRecordMIDIdef.free;
            };
            ~clipMgmtWindow = nil;
        });
    
    // Main layout
    mainLayout = VLayout();
    
    // Top controls
    topControls = HLayout(
        // Recording controls
        StaticText().string_("RECORDING:").font_(Font.sansSerif(12, true)),
        recordButton = Button()
            .states_([["● RECORD", Color.black, Color.green]])
            .action_({ |btn|
                if (~clipMgmtData.recordingState == \idle) {
                    ~startClipRecording.();
                } {
                    ~stopClipRecording.();
                };
            }),
        
        StaticText().string_(" | PLAYBACK:").font_(Font.sansSerif(12, true)),
        playButton = Button()
            .states_([["▶️ PLAY", Color.black, Color.cyan]])
            .action_({ ~playSelectedClip.(); }),
        quantButton = Button()
            .states_([["🕐 QUANT", Color.black, Color(0.8, 0.9, 1.0)]])
            .action_({ ~playSelectedClipQuantized.(4); }),
        stopButton = Button()
            .states_([["⏹ STOP", Color.white, Color.red]])
            .action_({ ~stopAllClipPlayback.(); }),
        
        StaticText().string_(" | FILES:").font_(Font.sansSerif(12, true)),
        loadButton = Button()
            .states_([["📁 LOAD", Color.black, Color.yellow]])
            .action_({ ~loadClipFromFile.(); }),
        saveButton = Button()
            .states_([["💾 SAVE", Color.black, Color(1, 0.6, 0)]])  // Orange color
            .action_({ ~saveSelectedClipToFile.(); }),
        
        StaticText().string_(" | SEQUENCE:").font_(Font.sansSerif(12, true)),
        sequenceButton = Button()
            .states_([["🎬 START", Color.black, Color(0.7, 1.0, 0.7)], ["⏹ STOP", Color.white, Color.red]])
            .action_({ |btn|
                if (~clipMgmtData.sequenceRunning) {
                    ~stopClipSequence.();
                    btn.value = 0;
                } {
                    ~startClipSequence.();
                    btn.value = 1;
                };
            }),
        modeButton = Button()
            .states_([["🔄 MANUAL", Color.black, Color(1, 1, 0.7)], ["⏩ AUTO", Color.black, Color(0.7, 1, 1)]])
            .value_(if (~clipMgmtData.playbackMode == \auto) { 1 } { 0 })
            .action_({ |btn|
                ~toggleSequenceMode.();
                btn.value = if (~clipMgmtData.playbackMode == \auto) { 1 } { 0 };
            }),
        
        nil  // Stretch remaining space
    );
    
    // Content layout
    contentLayout = HLayout();
    
    // Left panel - clip list
    leftPanel = VLayout(
        StaticText().string_("CLIPS").font_(Font.sansSerif(14, true)),
        clipList = ListView()
            .selectionMode_(\single)
            .action_({ |list|
                ~clipMgmtData.selectedClipIndex = list.value;
                ~updateClipDetails.();
            }),
        
        // Quick actions
        HLayout(
            Button()
                .states_([["🔄 RELOAD", Color.black, Color.grey(0.8)]])
                .action_({ ~loadClipsFromStorage.(); }),
            Button()
                .states_([["🗑 DELETE", Color.white, Color.red]])
                .action_({
                    if (~clipMgmtData.clips.size > 0 and: { ~clipMgmtData.selectedClipIndex < ~clipMgmtData.clips.size }) {
                        var clipName = ~clipMgmtData.clips[~clipMgmtData.selectedClipIndex][\name];
                        // Simple confirmation dialog using post
                        "Delete clip '{}'? Type 'y' to confirm:".format(clipName).postln;
                        // For now, just delete immediately - can improve later
                        ~clipMgmtData.clips.removeAt(~clipMgmtData.selectedClipIndex);
                        ~updateClipManagerUI.();
                        {
                            if (~clipMgmtViews.statusText.notNil) {
                                ~clipMgmtViews.statusText.string = "🗑 Deleted clip: {}".format(clipName);
                            };
                        }.defer;
                    };
                })
        )
    );
    
    // Right panel - clip details
    rightPanel = VLayout(
        StaticText().string_("CLIP DETAILS").font_(Font.sansSerif(14, true)),
        
        VLayout(
            HLayout(
                StaticText().string_("Name:").minWidth_(80),
                nameField = TextField().action_({ ~saveClipDetails.(); })
            ),
            HLayout(
                StaticText().string_("Key:").minWidth_(80),
                keyField = TextField().enabled_(false)
            ),
            HLayout(
                StaticText().string_("Active:").minWidth_(80),
                activeCheck = CheckBox().action_({ ~saveClipDetails.(); }),
                nil
            ),
            
            VLayout(
                durationText = StaticText().string_("Duration: --").font_(Font.sansSerif(11)),
                noteCountText = StaticText().string_("Notes: --").font_(Font.sansSerif(11)),
                HLayout(
                    StaticText().string_("Loop Count:").minWidth_(80),
                    loopCountField = NumberBox().value_(1).minWidth_(60).maxWidth_(60)
                        .action_({ ~saveClipDetails.(); })
                ),
                HLayout(
                    StaticText().string_("Loop Mode:").minWidth_(80),
                    loopModeMenu = PopUpMenu()
                        .items_(["Forward", "Reverse", "Ping-Pong", "Random"])
                        .value_(0)
                        .action_({ ~saveClipDetails.(); })
                )
            ).spacing_(5),
            
            nil  // Stretch
        ).spacing_(10),
        
        nil  // Stretch
    );
    
    // Add to content layout
    contentLayout.add(leftPanel, 1);
    contentLayout.add(rightPanel, 1);
    
    // Status bar
    statusText = StaticText()
        .string_("Clip Manager ready")
        .background_(Color.grey(0.8))
        .font_(Font.sansSerif(10));
    
    // Assemble main layout
    mainLayout.add(topControls);
    mainLayout.add(contentLayout, 1);
    mainLayout.add(statusText);
    
    window.layout = mainLayout;
    
    // Store UI references
    ~clipMgmtWindow = window;
    ~clipMgmtViews = (
        clipList: clipList,
        recordButton: recordButton,
        playButton: playButton,
        quantButton: quantButton,
        stopButton: stopButton,
        loadButton: loadButton,
        saveButton: saveButton,
        sequenceButton: sequenceButton,
        modeButton: modeButton,
        nameField: nameField,
        keyField: keyField,
        activeCheck: activeCheck,
        durationText: durationText,
        noteCountText: noteCountText,
        loopCountField: loopCountField,
        loopModeMenu: loopModeMenu,
        statusText: statusText
    );
    
    // Load existing clips
    ~loadClipsFromStorage.();
    
    // Check if clip system is loaded and show status
    {
        if (~saveClip.isNil or: { ~loadClip.isNil } or: { ~testClipPlayback.isNil }) {
            if (~clipMgmtViews.statusText.notNil) {
                ~clipMgmtViews.statusText.string = "⚠️ Load clip system first: \"sketch/clip-system/clip-loader.scd\".load";
            };
        } {
            if (~clipMgmtViews.statusText.notNil) {
                ~clipMgmtViews.statusText.string = "✅ Clip Manager ready - clip system connected";
            };
        };
    }.defer;
    
    // Show window
    window.front;
    
    "Clip Manager GUI opened".postln;
    if (~saveClip.isNil) {
        "⚠️ For full functionality, load clip system first:".postln;
        "\"sketch/clip-system/clip-loader.scd\".load".postln;
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                              MAIN ENTRY POINT                              │
// └─────────────────────────────────────────────────────────────────────────────┘

// Auto-create GUI if loaded directly
// Note: clip-loader will call ~createClipManagerGUI.() explicitly after clearing ~clipSystemLoading
if (~clipSystemLoading != true) {
    "Creating Clip Manager GUI (loaded directly)".postln;
    ~createClipManagerGUI.();
} {
    "Clip Management functions loaded - clip-loader will create GUI".postln;
};

"Clip Management system loaded".postln;
"Available functions:".postln;
"• ~createClipManagerGUI.()     - Open the clip manager".postln;
"• ~startClipRecording.()       - Start MIDI recording".postln;
"• ~stopClipRecording.()        - Stop and process recording".postln;
"• ~loadClipsFromMelodyData.()  - Load clips from main data".postln;