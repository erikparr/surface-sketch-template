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
    recordTimeout: nil
);

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
        
        // Also add to main melody data if it exists
        if (~melodyData.notNil) {
            if (~melodyData[\melodies].isNil) {
                ~melodyData[\melodies] = [];
            };
            ~melodyData[\melodies] = ~melodyData[\melodies] ++ [newClip];
        } {
            // Create melody data if it doesn't exist
            ~melodyData = (
                melodies: [newClip],
                settings: (
                    defaultNamePrefix: "clip",
                    nextSequenceNumber: 1,
                    selectedMelodyIndex: 0,
                    windowSize: [600, 400]
                )
            );
        };
        
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
// │                            CLIP FILE MANAGEMENT                            │
// └─────────────────────────────────────────────────────────────────────────────┘

// Load clips from main melody data
~loadClipsFromMelodyData = {
    var loadedClips = [];
    
    if (~melodyData.notNil and: { ~melodyData[\melodies].notNil }) {
        loadedClips = ~melodyData[\melodies].select({ |melody|
            melody[\isClip] == true and: { ~isValidClip.(melody) }
        });
        
        ~clipMgmtData.clips = loadedClips;
        "Loaded % clips from melody data".format(loadedClips.size).postln;
        
        // Re-initialize clip system to ensure ProcMods are created
        if (~initializeClipSystem.notNil) {
            ~initializeClipSystem.();
        };
        
        ~updateClipManagerUI.();
    } {
        "No melody data available to load clips from".postln;
    };
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

// Play selected clip
~playSelectedClip = {
    var selectedClip, tempoScale, playTask;
    
    if (~clipMgmtData.clips.size > 0 and: { ~clipMgmtData.selectedClipIndex < ~clipMgmtData.clips.size }) {
        selectedClip = ~clipMgmtData.clips[~clipMgmtData.selectedClipIndex];
        
        "▶️ Playing clip: %".format(selectedClip[\name]).postln;
        
        // Try different playback methods
        if (~testClipPlayback.notNil and: { ~isClipKey.notNil } and: { ~isClipKey.(selectedClip[\key]) }) {
            // Use clip system if available and clip is recognized
            ~testClipPlayback.(selectedClip[\key]);
        } {
            // Direct playback using clip data
            if (~playClip.notNil and: { selectedClip[\clipData].notNil }) {
                "Using direct clip playback".postln;
                tempoScale = if (~clipControl.notNil) { ~clipControl.tempoScale } { 1.0 };
                playTask = ~playClip.(selectedClip, tempoScale);
                if (playTask.notNil) {
                    playTask.play;
                };
            } {
                "No clip playback method available".postln;
                // Fallback: show clip info
                if (selectedClip[\clipData].notNil) {
                    "Clip info: % notes, %s duration".format(
                        selectedClip[\clipData][\notePairs].size,
                        selectedClip[\clipData][\duration].round(0.01)
                    ).postln;
                    selectedClip[\clipData][\notePairs].do({ |np, i|
                        "Note %: % at %s".format(i+1, np[\note], np[\startTime].round(0.01)).postln;
                    });
                };
            };
        };
        
        {
            if (~clipMgmtViews.statusText.notNil) {
                ~clipMgmtViews.statusText.string = "▶️ Playing: {}".format(selectedClip[\name]);
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
    if (~stopClips.notNil) {
        ~stopClips.();
        "⏹ All clip playback stopped".postln;
        
        {
            if (~clipMgmtViews.statusText.notNil) {
                ~clipMgmtViews.statusText.string = "⏹ Playback stopped";
            };
        }.defer;
    } {
        if (~emergencyStop.notNil) {
            ~emergencyStop.();
        };
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
                
                "% {} - {}s ({} notes)".format(active, clip[\name], duration, noteCount);
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
        
        // Update melody data if connected
        if (~melodyData.notNil and: { ~melodyData[\melodies].notNil }) {
            var melodyIndex = ~melodyData[\melodies].detectIndex({ |m| m[\key] == selectedClip[\key] });
            if (melodyIndex.notNil) {
                ~melodyData[\melodies][melodyIndex] = selectedClip;
            };
        };
        
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
    var nameField, keyField, activeCheck, durationText, noteCountText, statusText;
    
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
                .action_({ ~loadClipsFromMelodyData.(); }),
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
                noteCountText = StaticText().string_("Notes: --").font_(Font.sansSerif(11))
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
        stopButton: stopButton,
        loadButton: loadButton,
        saveButton: saveButton,
        nameField: nameField,
        keyField: keyField,
        activeCheck: activeCheck,
        durationText: durationText,
        noteCountText: noteCountText,
        statusText: statusText
    );
    
    // Load existing clips
    ~loadClipsFromMelodyData.();
    
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