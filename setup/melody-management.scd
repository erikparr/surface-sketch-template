// Melody Management GUI
// Provides interface to manage sketch melodies with active/inactive toggles
// Uses JSON format for reliable data persistence
// PHASE 1: Enhanced MIDI Clip Recording System

// Capture the setup directory path at file load time
~melodyMgmtDir = thisProcess.nowExecutingPath.dirname;

// Global variables for melody management
~melodyData = nil;
~melodyManagerWin = nil;
~updateMelodyManagerUI = nil;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                    PHASE 1: MIDI CLIP RECORDING SYSTEM                     │
// └─────────────────────────────────────────────────────────────────────────────┘

// Global variables for MIDI clip recording
~clipRecordingState = \idle;  // \idle, \recording, \processing
~recordingStartTime = nil;
~recordingTimeout = 10.0;  // 10 second max recording
~recordedEvents = [];
~maxRecordedEvents = 1000;  // Prevent memory overflow
~recordingNoteOnDef = nil;
~recordingNoteOffDef = nil;
~recordingTimer = nil;
~recordingUI = (); // Dictionary to hold UI elements

// Global variables for legacy MIDI note capturing (preserved for compatibility)
~capturedNotes = [];
~maxCapturedNotes = 15;
~capturedNotesField = nil;
~keyOnResponder = nil;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                       PHASE 1.1: MIDI INPUT ENHANCEMENT                    │
// └─────────────────────────────────────────────────────────────────────────────┘

// Setup direct MIDI input for clip recording
~setupClipMIDIInput = {
    // Initialize MIDI client if needed
    if (MIDIClient.initialized.not) {
        MIDIClient.init;
        "MIDI Client initialized".postln;
    };
    
    // Cleanup existing MIDI handlers
    if (~recordingNoteOnDef.notNil) {
        ~recordingNoteOnDef.free;
    };
    if (~recordingNoteOffDef.notNil) {
        ~recordingNoteOffDef.free;
    };
    
    // Create MIDIdef for Note On events
    ~recordingNoteOnDef = MIDIdef.noteOn(\clipRecordingNoteOn, { |vel, note, chan, src|
        if (~clipRecordingState == \recording) {
            ~addRecordedEvent.(\noteOn, chan, note, vel);
        };
    });
    
    // Create MIDIdef for Note Off events  
    ~recordingNoteOffDef = MIDIdef.noteOff(\clipRecordingNoteOff, { |vel, note, chan, src|
        if (~clipRecordingState == \recording) {
            ~addRecordedEvent.(\noteOff, chan, note, vel);
        };
    });
    
    "Direct MIDI input setup complete using MIDIdef".postln;
};

// Add recorded MIDI event with precise timing
~addRecordedEvent = { |type, channel, note, velocity|
    var currentTime, relativeTime, event;
    
    if (~recordedEvents.size >= ~maxRecordedEvents) {
        "Maximum events reached, stopping recording".postln;
        ~stopClipRecording.();
        ^nil;
    };
    
    currentTime = Main.elapsedTime;
    relativeTime = currentTime - ~recordingStartTime;
    
    event = (
        type: type,
        time: relativeTime,
        note: note,
        channel: channel,
        velocity: velocity
    );
    
    ~recordedEvents = ~recordedEvents.add(event);
    
    // Update UI if available
    if (~recordingUI[\eventCount].notNil) {
        { ~recordingUI[\eventCount].string = "Events: %".format(~recordedEvents.size); }.defer;
    };
    
    "Recorded % event: ch=%, note=%, vel=%, time=%".format(
        type, channel, note, velocity, relativeTime.round(0.001)
    ).postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                    PHASE 1.2: RECORDING STATE MACHINE                      │
// └─────────────────────────────────────────────────────────────────────────────┘

// Start clip recording
~startClipRecording = {
    if (~clipRecordingState != \idle) {
        "Cannot start recording: currently in state %".format(~clipRecordingState).postln;
        ^false;
    };
    
    // Initialize recording
    ~clipRecordingState = \recording;
    ~recordingStartTime = Main.elapsedTime;
    ~recordedEvents = [];
    
    // Setup timeout
    ~recordingTimer = AppClock.sched(~recordingTimeout, {
        // Only stop if we're still recording (avoid race condition with manual stop)
        if (~clipRecordingState == \recording) {
            "Recording auto-stopped after % seconds".format(~recordingTimeout).postln;
            ~stopClipRecording.();
        } {
            "Recording timeout fired but recording already stopped".postln;
        };
        nil; // Don't reschedule
    });
    
    // Update UI
    if (~recordingUI[\recordButton].notNil) {
        { 
            ~recordingUI[\recordButton].states = [["● STOP", Color.white, Color.red]];
            ~recordingUI[\recordButton].value = 0;
            ~recordingUI[\statusText].string = "Recording...";
            ~recordingUI[\eventCount].string = "Events: 0";
        }.defer;
    };
    
    "Clip recording started (max % seconds)".format(~recordingTimeout).postln;
    ^true;
};

// Stop clip recording
~stopClipRecording = {
    // Handle case where recording has already been stopped (prevent race condition)
    if (~clipRecordingState == \idle) {
        // Already stopped and processed, just update UI to be safe
        if (~recordingUI[\recordButton].notNil) {
            { 
                ~recordingUI[\recordButton].states = [["● RECORD", Color.black, Color.green]];
                ~recordingUI[\recordButton].value = 0;
                ~recordingUI[\statusText].string = "Ready to record";
            }.defer;
        };
        ^true; // Return success since we're already in the desired state
    };
    
    if (~clipRecordingState == \processing) {
        "Recording is currently being processed, please wait".postln;
        ^false;
    };
    
    if (~clipRecordingState != \recording) {
        "Cannot stop recording: not currently recording (state: %)".format(~clipRecordingState).postln;
        ^false;
    };
    
    // Change state to processing
    ~clipRecordingState = \processing;
    
    // Cancel timeout timer
    if (~recordingTimer.notNil) {
        ~recordingTimer.clear;
        ~recordingTimer = nil;
    };
    
    // Process the recorded data
    ~processRecordedClip.();
    
    // Update UI
    if (~recordingUI[\recordButton].notNil) {
        { 
            ~recordingUI[\recordButton].states = [["● RECORD", Color.black, Color.green]];
            ~recordingUI[\recordButton].value = 0;
        }.defer;
    };
    
    ^true;
};

// Toggle recording state
~toggleClipRecording = {
    if (~clipRecordingState == \idle) {
        ~startClipRecording.();
    } {
        if (~clipRecordingState == \recording) {
            "User stopped recording".postln;
            ~stopClipRecording.();
        } {
            "Cannot toggle: currently processing previous recording (state: %)".format(~clipRecordingState).postln;
        };
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                      PHASE 1.3: DATA PROCESSING                            │
// └─────────────────────────────────────────────────────────────────────────────┘

// Process recorded clip data
~processRecordedClip = {
    var totalDuration, notePairs, statusText, noteOnEvents, clipMelody;
    
    if (~recordedEvents.size == 0) {
        "No events recorded".postln;
        ~clipRecordingState = \idle;
        if (~recordingUI[\statusText].notNil) {
            { ~recordingUI[\statusText].string = "No events recorded"; }.defer;
        };
        ^nil;
    };
    
    "Processing % events...".format(~recordedEvents.size).postln;
    
    // Calculate total duration
    totalDuration = ~recordedEvents.last[\time] + 0.1;
    
    // Sort events by time
    ~recordedEvents = ~recordedEvents.sort({ |a, b| a[\time] <= b[\time] });
    
    // Calculate note durations directly (simplified approach)
    noteOnEvents = IdentityDictionary.new;
    notePairs = [];
    
    ~recordedEvents.do { |event|
        var noteKey = (event[\channel].asString ++ "_" ++ event[\note]).asSymbol;
        
        if (event[\type] == \noteOn && (event[\velocity].isNumber && event[\velocity] > 0)) {
            noteOnEvents[noteKey] = event;
        } {
            if (event[\type] == \noteOff || (event[\type] == \noteOn && (event[\velocity].isNumber.not || event[\velocity] == 0))) {
                var noteOnEvent = noteOnEvents[noteKey];
                if (noteOnEvent.notNil) {
                    var duration = event[\time] - noteOnEvent[\time];
                    var notePair = (
                        note: noteOnEvent[\note],
                        channel: noteOnEvent[\channel],
                        startTime: noteOnEvent[\time],
                        duration: duration.max(0.01),
                        velocity: noteOnEvent[\velocity]
                    );
                    notePairs = notePairs.add(notePair);
                    noteOnEvents.removeAt(noteKey);
                };
            };
        };
    };
    
    "Created % note pairs".format(notePairs.size).postln;
    
    // PHASE 2: Store full timing data instead of converting to old format
    if (notePairs.size > 0) {
        var clipName = "clip-" ++ Date.getDate.format("%H%M%S");
        var notePattern = notePairs.collect({ |pair| pair[\note] }); // For compatibility only
        
        clipMelody = (
            key: clipName,
            name: clipName ++ " (recorded clip)",
            // Legacy compatibility fields
            pattern: notePattern,
            velocityFirst: 1.0,
            velocityLast: 1.0,
            loopCount: 1,
            active: true,
            // PHASE 2: Store full clip timing data
            isClip: true,
            clipData: (
                notePairs: notePairs,
                duration: totalDuration,
                eventCount: ~recordedEvents.size,
                metadata: (
                    recordedAt: Date.getDate.stamp,
                    noteCount: notePairs.size,
                    recordingDuration: totalDuration
                )
            )
        );
        
        // Add to melody data
        ~melodyData[\melodies] = ~melodyData[\melodies].add(clipMelody);
        
        statusText = "Recorded clip: % notes, %s duration (TIMING PRESERVED)".format(
            notePairs.size, totalDuration.round(0.01)
        );
        
        "PHASE 2: Clip processing successful with timing data preserved: %".format(statusText).postln;
        "PHASE 2: Clip data structure: %".format(clipMelody[\clipData]).postln;
    } {
        statusText = "No complete note pairs found";
        "Warning: %".format(statusText).postln;
    };
    
    // Update UI
    if (~recordingUI[\statusText].notNil) {
        { ~recordingUI[\statusText].string = statusText; }.defer;
    };
    
    // Reset state
    ~clipRecordingState = \idle;
    ~recordedEvents = [];
    
    // Update melody manager UI
    if (~updateMelodyManagerUI.notNil) {
        ~updateMelodyManagerUI.();
    };
    
    "Clip processing complete".postln;
    ^clipMelody;
};

// Calculate note durations from note on/off pairs
~calculateNoteDurations = { |events|
    var noteOnEvents, notePairs, openNotes;
    
    noteOnEvents = IdentityDictionary.new;
    notePairs = [];
    
    events.do { |event|
        var noteKey = (event[\channel].asString ++ "_" ++ event[\note]).asSymbol;
        
        if (event[\type] == \noteOn && (event[\velocity].isNumber && event[\velocity] > 0)) {
            // Store note on event
            noteOnEvents[noteKey] = event;
        } {
            if (event[\type] == \noteOff || (event[\type] == \noteOn && (event[\velocity].isNumber.not || event[\velocity] == 0))) {
                // Find matching note on event
                var noteOnEvent = noteOnEvents[noteKey];
                if (noteOnEvent.notNil) {
                    var duration = event[\time] - noteOnEvent[\time];
                    var notePair = (
                        note: noteOnEvent[\note],
                        channel: noteOnEvent[\channel],
                        startTime: noteOnEvent[\time],
                        duration: duration.max(0.01), // Minimum 10ms duration
                        velocity: noteOnEvent[\velocity]
                    );
                    notePairs = notePairs.add(notePair);
                    noteOnEvents.removeAt(noteKey);
                };
            };
        };
    };
    
    // Handle any remaining open notes (no note off received)
    noteOnEvents.keysValuesDo { |key, noteOnEvent|
        var duration = (~recordedEvents.last[\time] - noteOnEvent[\time]).max(0.1);
        var notePair = (
            note: noteOnEvent[\note],
            channel: noteOnEvent[\channel], 
            startTime: noteOnEvent[\time],
            duration: duration,
            velocity: noteOnEvent[\velocity]
        );
        notePairs = notePairs.add(notePair);
        "Note left open, auto-closed: %".format(notePair).postln;
    };
    
    ^notePairs.sort({ |a, b| a[\startTime] <= b[\startTime] });
};

// Generate unique clip name
~generateClipName = {
    var timestamp = Date.getDate.format("%H%M%S");
    var name = "clip-" ++ timestamp;
    ^name;
};

// Add processed clip to melody data structure
~addClipToMelodyData = { |clipData|
    var clipMelody;
    
    // Convert clip to melody format for compatibility
    clipMelody = (
        key: clipData[\metadata][\name],
        name: clipData[\metadata][\name] ++ " (recorded clip)",
        pattern: clipData[\notePairs].collect({ |note| note[\note] }), // Extract just note numbers for compatibility
        velocityFirst: 1.0,
        velocityLast: 1.0,
        loopCount: 1,
        active: true,
        // Add clip-specific data
        isClip: true,
        clipData: clipData
    );
    
    ~melodyData[\melodies] = ~melodyData[\melodies].add(clipMelody);
    "Added clip % to melody data".format(clipData[\metadata][\name]).postln;
};

// Function to load melody data from JSON file or create default
~loadMelodyData = {
    var melodyDataPath, loadedData;
    melodyDataPath = ~melodyMgmtDir +/+ "../data/melody-data.json";
    
    if (File.exists(melodyDataPath)) {
        "Loading melody data from: %".format(melodyDataPath).postln;
        try {
            loadedData = JSONlib.parseFile(melodyDataPath, useEvent: true);
            ~melodyData = loadedData;
            "Successfully loaded melody data".postln;
        } { |error|
            "Error loading JSON file: %".format(error).postln;
            "Falling back to conversion from sketch-melody.scd".postln;
            ~convertSketchMelodyToNewFormat.();
        };
    } {
        "Melody data file not found, checking for sketch-melody.scd to convert...".postln;
        ~convertSketchMelodyToNewFormat.();
    };
};

// Function to save melody data to JSON file
~saveMelodyData = {
    var melodyDataPath, file, jsonString;
    melodyDataPath = ~melodyMgmtDir +/+ "../data/empty-melodies.json";
    
    if (~melodyData.notNil) {
        try {
            jsonString = JSONlib.convertToJSON(~melodyData);
            file = File(melodyDataPath, "w");
            file.write(jsonString);
            file.close;
            "Melody data saved to: %".format(melodyDataPath).postln;
        } { |error|
            "Error saving melody data: %".format(error).postln;
        };
    } {
        "No melody data to save".postln;
    };
};

// Function to convert sketch-melody.scd to new JSON format
~convertSketchMelodyToNewFormat = {
    var sketchMelodyPath, convertedMelodies, sequenceNumber;
    sketchMelodyPath = ~melodyMgmtDir +/+ "../data/sketch-melody.scd";
    
    if (File.exists(sketchMelodyPath)) {
        "Converting sketch-melody.scd to new JSON format...".postln;
        sketchMelodyPath.load; // This populates ~melodyDict
        
        convertedMelodies = [];
        sequenceNumber = 1;
        
        ~melodyDict.keysValuesDo { |key, melody|
            var pattern = if (melody.patterns.notNil and: { melody.patterns.size > 0 }) {
                melody.patterns[0]; // Get first pattern and flatten
            } {
                [60]; // Default pattern if none found
            };
            
            var velocityFirst = 1.0;
            var velocityLast = 1.0;
            
            // Extract velocity multipliers safely
            if (melody.velocityMultipliers.notNil) {
                if (melody.velocityMultipliers.isKindOf(Event)) {
                    velocityFirst = melody.velocityMultipliers[\first] ? 1.0;
                    velocityLast = melody.velocityMultipliers[\last] ? 1.0;
                };
            };
            
            convertedMelodies = convertedMelodies.add((
                key: "seq-" ++ sequenceNumber,
                name: "seq-" ++ sequenceNumber,
                pattern: pattern,
                velocityFirst: velocityFirst,
                velocityLast: velocityLast,
                loopCount: melody.loopCount ? 1,
                active: true
            ));
            sequenceNumber = sequenceNumber + 1;
        };
        
        ~melodyData = (
            settings: (
                defaultNamePrefix: "seq",
                nextSequenceNumber: sequenceNumber,
                windowSize: [600, 400],
                selectedMelodyIndex: 0
            ),
            melodies: convertedMelodies
        );
        
        ~saveMelodyData.(); // Save converted data
        "Converted % melodies from sketch-melody.scd".format(convertedMelodies.size).postln;
    } {
        "sketch-melody.scd not found, creating empty melody data".postln;
        ~melodyData = (
            settings: (
                defaultNamePrefix: "seq",
                nextSequenceNumber: 1,
                windowSize: [600, 400],
                selectedMelodyIndex: 0
            ),
            melodies: []
        );
        ~saveMelodyData.();
    };
};

// Function to load active melodies into ~melodyDict for sketch system
~loadActiveMelodies = {
    var activeMelodies, activeMelodyKeys;
    
    if (~melodyData.isNil) {
        "No melody data available. Loading first...".postln;
        ~loadMelodyData.();
    };
    
    activeMelodies = ~melodyData[\melodies].select({ |melody| melody[\active] == true });
    activeMelodyKeys = activeMelodies.collect({ |melody| melody[\key].asSymbol });
    
    // Load melodies into ~melodyDict (for sketch system compatibility)
    ~melodyDict = Dictionary.new;
    activeMelodies.do { |melody|
        ~melodyDict.put(melody[\key].asSymbol, (
            name: melody[\name],
            patterns: [melody[\pattern]], // Wrap back to array for compatibility
            velocityMultipliers: (
                first: melody[\velocityFirst],
                last: melody[\velocityLast]
            ),
            loopCount: melody[\loopCount]
        ));
    };
    
    // Set up the melody sequence for direct navigation
    ~currentSequence = activeMelodyKeys;
    
    // Initialize navigation index if not set
    if (~currentLoopIndex.isNil) {
        ~currentLoopIndex = 0;
    };
    
    // Ensure index is within bounds
    ~currentLoopIndex = ~currentLoopIndex.clip(0, activeMelodyKeys.size - 1);
    
    "Loaded % active melodies into ~melodyDict".format(activeMelodies.size).postln;
    "Updated ~currentSequence with active melody keys: %".format(activeMelodyKeys).postln;
    "Current melody index: % (melody: %)".format(~currentLoopIndex, activeMelodyKeys[~currentLoopIndex]).postln;
    
    ^activeMelodies.size;
};

// Function to generate next melody name
~generateMelodyName = { |prefix, number|
    prefix ++ "-" ++ number;
};

// Function to get next melody key
~getNextMelodyKey = {
    var settings = ~melodyData[\settings];
    var key = ~generateMelodyName.(settings[\defaultNamePrefix], settings[\nextSequenceNumber]);
    settings[\nextSequenceNumber] = settings[\nextSequenceNumber] + 1;
    key;
};

// Functions for MIDI note capturing
~clearCapturedNotes = {
    ~capturedNotes = [];
    if (~capturedNotesField.notNil) {
        { ~capturedNotesField.string = "[]"; }.defer;
    };
    "Cleared captured notes".postln;
};

~addCapturedNote = { |note|
    if (~capturedNotes.size < ~maxCapturedNotes) {
        ~capturedNotes = ~capturedNotes.add(note);
        if (~capturedNotesField.notNil) {
            { ~capturedNotesField.string = ~capturedNotes.asCompileString; }.defer;
        };
        "Added note % to captured notes (% / %)".format(note, ~capturedNotes.size, ~maxCapturedNotes).postln;
    } {
        "Captured notes at maximum limit (%)".format(~maxCapturedNotes).postln;
    };
};

~setupKeyOnResponder = {
    // Clean up existing responder
    if (~keyOnResponder.notNil) {
        ~keyOnResponder.free;
    };
    
    // Create OSC responder for keyOn messages from MidiController
    // Try multiple address configurations to find the working one
    ~keyOnResponder = OSCdef(\melodyCapture, { |msg|
        var channel = msg[1].asInteger;
        var note = msg[2].asInteger;
        var velocity = msg[3].asInteger;
        
        "*** OSC /keyOn received: msg=%, channel=%, note=%, velocity=%".format(msg, channel, note, velocity).postln;
        
        if (velocity > 0 && note >= 0 && note <= 127) {
            ~addCapturedNote.(note);
        } {
            "Note rejected: velocity=%, note=%".format(velocity, note).postln;
        };
    }, '/keyOn');  // Try without specifying address to catch all sources
    
    // Also create a test responder that catches ALL OSC messages temporarily
    ~testResponder = OSCdef(\testAll, { |msg, time, addr, recvPort|
        if (msg[0] == '/keyOn') {
            "*** TEST: Caught /keyOn from addr=%, port=%, msg=%".format(addr, recvPort, msg).postln;
        };
    });
    
    "OSC keyOn responder setup for melody capture (listening on all addresses)".postln;
};

~saveCapturedMelody = {
    if (~capturedNotes.size > 0) {
        var newKey = ~getNextMelodyKey.();
        var newMelody = (
            key: newKey,
            name: newKey ++ " (captured)",
            pattern: ~capturedNotes.copy,
            velocityFirst: 1.0,
            velocityLast: 1.0,
            loopCount: 1,
            active: true
        );
        ~melodyData[\melodies] = ~melodyData[\melodies].add(newMelody);
        if (~updateMelodyManagerUI.notNil) {
            ~updateMelodyManagerUI.();
        };
        "Saved captured melody: % with % notes".format(newKey, ~capturedNotes.size).postln;
        ^newKey;
    } {
        "No captured notes to save".postln;
        ^nil;
    };
};

// Function to open and load melody file
~openMelodyFile = { |statusText, updateMelodyList|
    FileDialog({ |path|
        if (path.notNil) {
            ~loadMelodyFileFromPath.(path, statusText, updateMelodyList);
        } {
            if (statusText.notNil) {
                { statusText.string = "File selection cancelled"; }.defer;
            };
        };
    }, 
    fileMode: 1, // 1 = open file mode
    acceptMode: 0, // 0 = open mode
    stripResult: true
    );
};

// Function to load melody data from file path
~loadMelodyFileFromPath = { |filePath, statusText, updateMelodyList|
    var loadedData, melodyCount;
    
    if (File.exists(filePath)) {
        try {
            "Loading melody file from: %".format(filePath).postln;
            loadedData = JSONlib.parseFile(filePath, useEvent: true);
            
            if (loadedData.notNil && loadedData[\melodies].notNil) {
                ~melodyData = loadedData;
                melodyCount = ~melodyData[\melodies].size;
                
                // Update GUI
                if (updateMelodyList.notNil) {
                    { updateMelodyList.(); }.defer;
                };
                
                if (statusText.notNil) {
                    { statusText.string = "Loaded % melodies from file".format(melodyCount); }.defer;
                };
                
                "Successfully loaded % melodies from %".format(melodyCount, filePath).postln;
            } {
                if (statusText.notNil) {
                    { statusText.string = "Invalid melody file format"; }.defer;
                };
                "Error: File does not contain valid melody data".postln;
            };
        } { |error|
            if (statusText.notNil) {
                { statusText.string = "Error loading file: %".format(error); }.defer;
            };
            "Error loading melody file: %".format(error).postln;
        };
    } {
        if (statusText.notNil) {
            { statusText.string = "File not found: %".format(filePath); }.defer;
        };
        "Error: File not found - %".format(filePath).postln;
    };
};

// Main function to create the Melody Manager UI
~createMelodyManagerUI = {
    var win, layout, melodyList, editPanel;
    var prefixField, loadButton, saveButton, openFileButton, addButton, deleteButton;
    var nameField, patternField, firstVelField, lastVelField, loopCountField, activeCheckbox;
    var updateButton, updateMelodyList, updateEditPanel, selectedMelodyIndex, statusText;
    var topLayout, mainLayout, leftLayout, rightLayout, listButtonLayout;
    var captureLayout, captureButtonLayout, clearCapturedButton, saveCapturedButton;
    var clipRecordingLayout, recordingControlsLayout, recordButton, clipStatusText, eventCountText, paramsLayout;

    // Check if melody data is loaded
    if (~melodyData.isNil) {
        "Loading melody data...".postln;
        ~loadMelodyData.();
    };

    // Create the window
    win = Window("Melody Manager", Rect(100, 100, 700, 500));
    layout = VLayout();

    // Top controls
    topLayout = HLayout();
    topLayout.add(StaticText().string_("Prefix:"));
    prefixField = TextField()
        .string_(~melodyData[\settings][\defaultNamePrefix])
        .fixedWidth_(60)
        .action_({ |field|
            ~melodyData[\settings][\defaultNamePrefix] = field.string;
        });
    topLayout.add(prefixField);
    topLayout.add(nil, stretch: 1); // Spacer
    
    loadButton = Button()
        .states_([["Load Melodies"]])
        .action_({
            var count = ~loadActiveMelodies.();
            statusText.string = "Loaded % active melodies into ~melodyDict".format(count);
        });
    topLayout.add(loadButton);
    
    saveButton = Button()
        .states_([["Save"]])
        .action_({
            ~saveMelodyData.();
            statusText.string = "Melody data saved";
        });
    topLayout.add(saveButton);
    
    openFileButton = Button()
        .states_([["Open File"]])
        .action_({
            ~openMelodyFile.(statusText, updateMelodyList);
        });
    topLayout.add(openFileButton);
    
    layout.add(topLayout);

    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                    PHASE 1: CLIP RECORDING UI SECTION                      │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    // Clip Recording Section
    clipRecordingLayout = VLayout();
    clipRecordingLayout.add(StaticText().string_("MIDI Clip Recording (Phase 1)").font_(Font.default.boldVariant));
    
    // Recording controls row
    recordingControlsLayout = HLayout();
    
    // Record button
    recordButton = Button()
        .states_([["● RECORD", Color.black, Color.green]])
        .action_({
            ~toggleClipRecording.();
        });
    recordingControlsLayout.add(recordButton);
    
    // Status and event count
    clipStatusText = StaticText().string_("Ready to record");
    eventCountText = StaticText().string_("Events: 0");
    recordingControlsLayout.add(clipStatusText, stretch: 1);
    recordingControlsLayout.add(eventCountText);
    
    clipRecordingLayout.add(recordingControlsLayout);
    
    // Recording parameters
    paramsLayout = HLayout();
    paramsLayout.add(StaticText().string_("Max duration: %s".format(~recordingTimeout)));
    paramsLayout.add(StaticText().string_("Max events: %".format(~maxRecordedEvents)), stretch: 1);
    clipRecordingLayout.add(paramsLayout);
    
    // Store UI elements for state updates
    ~recordingUI[\recordButton] = recordButton;
    ~recordingUI[\statusText] = clipStatusText;
    ~recordingUI[\eventCount] = eventCountText;
    
    layout.add(clipRecordingLayout);

    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                    LEGACY MIDI NOTE CAPTURE SECTION                        │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    // MIDI Note Capture Section (Legacy - preserved for compatibility)
    captureLayout = VLayout();
    captureLayout.add(StaticText().string_("Legacy MIDI Note Capture"));
    
    // Captured notes display field
    ~capturedNotesField = TextField()
        .string_("[]")
        .background_(Color.gray(0.95))
        .enabled_(false); // Read-only
    captureLayout.add(~capturedNotesField);
    
    // Capture control buttons
    captureButtonLayout = HLayout();
    clearCapturedButton = Button()
        .states_([["Clear Notes"]])
        .action_({
            ~clearCapturedNotes.();
            statusText.string = "Cleared captured notes";
        });
    
    saveCapturedButton = Button()
        .states_([["Save as Melody"]])
        .action_({
            var savedKey = ~saveCapturedMelody.();
            if (savedKey.notNil) {
                statusText.string = "Saved captured melody: %".format(savedKey);
            } {
                statusText.string = "No notes to save";
            };
        });
    
    captureButtonLayout.add(clearCapturedButton);
    captureButtonLayout.add(saveCapturedButton);
    captureButtonLayout.add(StaticText().string_("Max % notes".format(~maxCapturedNotes)), stretch: 1);
    captureLayout.add(captureButtonLayout);
    
    layout.add(captureLayout);

    // Main content area
    mainLayout = HLayout();
    
    // Left side - Melody List
    leftLayout = VLayout();
    leftLayout.add(StaticText().string_("Melody List"));
    
    melodyList = ListView()
        .selectionMode_(\single);
    leftLayout.add(melodyList, stretch: 1);
    
    // Bottom buttons for melody list
    listButtonLayout = HLayout();
    addButton = Button()
        .states_([["Add New"]])
        .action_({
            var newKey = ~getNextMelodyKey.();
            var newMelody = (
                key: newKey,
                name: newKey,
                pattern: [60, 62, 64],
                velocityFirst: 1.0,
                velocityLast: 1.0,
                loopCount: 1,
                active: true
            );
            ~melodyData[\melodies] = ~melodyData[\melodies].add(newMelody);
            updateMelodyList.();
            statusText.string = "Added new melody: %".format(newKey);
        });
    
    deleteButton = Button()
        .states_([["Delete Selected"]])
        .action_({
            var selectedIndex = melodyList.value;
            if (selectedIndex.notNil and: { selectedIndex < ~melodyData[\melodies].size }) {
                var deletedKey = ~melodyData[\melodies][selectedIndex][\key];
                ~melodyData[\melodies].removeAt(selectedIndex);
                updateMelodyList.();
                statusText.string = "Deleted melody: %".format(deletedKey);
            };
        });
    
    listButtonLayout.add(addButton);
    listButtonLayout.add(deleteButton);
    leftLayout.add(listButtonLayout);
    
    mainLayout.add(leftLayout, stretch: 1);
    
    // Right side - Edit Panel (COMPLETE FORM)
    rightLayout = VLayout();
    rightLayout.add(StaticText().string_("Edit Selected Melody"));
    
    // Create all form fields
    nameField = TextField().string_("TEST TEXT FIELD");
    patternField = TextField().string_("");
    firstVelField = NumberBox().value_(1.0).decimals_(2);
    lastVelField = NumberBox().value_(1.0).decimals_(2);
    loopCountField = NumberBox().value_(1).decimals_(0);
    activeCheckbox = CheckBox().value_(true);
    
    // Add all fields to layout
    rightLayout.add(HLayout([
        StaticText().string_("Key:").fixedWidth_(80),
        StaticText().string_("(readonly)").background_(Color.gray(0.9))
    ]));
    
    rightLayout.add(StaticText().string_("Name:"));
    rightLayout.add(nameField);
    
    rightLayout.add(StaticText().string_("Pattern:"));
    rightLayout.add(patternField);
    
    rightLayout.add(StaticText().string_("First Vel:"));
    rightLayout.add(firstVelField);
    
    rightLayout.add(StaticText().string_("Last Vel:"));
    rightLayout.add(lastVelField);
    
    rightLayout.add(StaticText().string_("Loop Count:"));
    rightLayout.add(loopCountField);
    
    rightLayout.add(StaticText().string_("Active:"));
    rightLayout.add(activeCheckbox);
    
    // Update button
    updateButton = Button()
        .states_([["Update Melody"]])
        .action_({
            var selectedIndex = melodyList.value;
            if (selectedIndex.notNil and: { selectedIndex < ~melodyData[\melodies].size }) {
                var melody = ~melodyData[\melodies][selectedIndex];
                var patternString = patternField.string;
                var patternArray;
                
                // Parse pattern string to array
                try {
                    patternArray = patternString.interpret;
                    if (patternArray.isArray.not) {
                        patternArray = [patternArray];
                    };
                } {
                    "Invalid pattern format, keeping original".postln;
                    patternArray = melody[\pattern];
                };
                
                melody[\name] = nameField.string;
                melody[\pattern] = patternArray;
                melody[\velocityFirst] = firstVelField.value;
                melody[\velocityLast] = lastVelField.value;
                melody[\loopCount] = loopCountField.value.asInteger;
                melody[\active] = activeCheckbox.value;
                
                updateMelodyList.();
                statusText.string = "Updated melody: %".format(melody[\key]);
            };
        });
    rightLayout.add(updateButton);
    
    mainLayout.add(rightLayout, stretch: 1);
    layout.add(mainLayout, stretch: 1);

    // Status text - create AFTER other widgets
    statusText = StaticText()
        .string_("Ready. Use checkboxes to toggle active/inactive status");
    layout.add(statusText);

    // Update functions
    updateMelodyList = {
        var items = ~melodyData[\melodies].collect { |melody, i|
            var checkbox = if (melody[\active]) { "☑" } { "☐" };
            "% % (%)".format(checkbox, melody[\key], melody[\name]);
        };
        
        "updateMelodyList called, melody count: %".format(~melodyData[\melodies].size).postln;
        "First melody example: %".format(~melodyData[\melodies][0]).postln;
        
        {
            melodyList.items = items;
            if (~melodyData[\melodies].size > 0 and: { melodyList.value.isNil }) {
                melodyList.value = 0;
                updateEditPanel.();
            };
        }.defer;
    };
    
    updateEditPanel = {
        var selectedIndex, melody;
        
        if (~melodyData.isNil or: { ~melodyData[\melodies].isNil }) {
            "ERROR: melodyData is nil in updateEditPanel".postln;
            ^nil;
        };
        
        selectedIndex = melodyList.value;
        "updateEditPanel called with selectedIndex: %".format(selectedIndex).postln;
        
        if (selectedIndex.notNil and: { selectedIndex < ~melodyData[\melodies].size }) {
            melody = ~melodyData[\melodies][selectedIndex];
            "Selected melody: %".format(melody).postln;
            
            {
                // Update all fields
                "Updating name field to: %".format(melody[\name]).postln;
                nameField.string_(melody[\name].asString);
                
                "Updating pattern field to: %".format(melody[\pattern]).postln;
                patternField.string_(melody[\pattern].asCompileString);
                
                "Updating velocity fields: first=%, last=%".format(melody[\velocityFirst], melody[\velocityLast]).postln;
                firstVelField.value_(melody[\velocityFirst]);
                lastVelField.value_(melody[\velocityLast]);
                
                "Updating loop count: %".format(melody[\loopCount]).postln;
                loopCountField.value_(melody[\loopCount]);
                
                "Updating active checkbox: %".format(melody[\active]).postln;
                activeCheckbox.value_(melody[\active]);
                
                "Field updates completed".postln;
            }.defer;
        } {
            "No valid selection or index out of range".postln;
            "melodyData size: %, selectedIndex: %".format(
                if (~melodyData.notNil and: { ~melodyData[\melodies].notNil }) { ~melodyData[\melodies].size } { "nil or invalid" },
                selectedIndex
            ).postln;
        };
    };
    
    // List selection action
    melodyList.action = { |list|
        updateEditPanel.();
    };
    
    // List mouse action for checkbox toggling
    melodyList.mouseDownAction = { |list, x, y, modifiers, buttonNumber, clickCount|
        var selectedIndex = list.value;
        if (selectedIndex.notNil and: { selectedIndex < ~melodyData[\melodies].size }) {
            // Check if click is in checkbox area (first ~15 pixels)
            if (x < 15) {
                ~melodyData[\melodies][selectedIndex][\active] = ~melodyData[\melodies][selectedIndex][\active].not;
                updateMelodyList.();
                updateEditPanel.();
                statusText.string = "Toggled % to %".format(
                    ~melodyData[\melodies][selectedIndex][\key],
                    if (~melodyData[\melodies][selectedIndex][\active]) { "active" } { "inactive" }
                );
            };
        };
    };

    // Store update function globally
    ~updateMelodyManagerUI = {
        updateMelodyList.();
    };

    // Set the layout and show
    win.layout = layout;
    updateMelodyList.();
    
    // Setup OSC responder for MIDI note capture
    ~setupKeyOnResponder.();
    
    // Cleanup on close
    win.onClose = {
        ~melodyManagerWin = nil;
        // Clean up OSC responders
        if (~keyOnResponder.notNil) {
            ~keyOnResponder.free;
            ~keyOnResponder = nil;
        };
        if (~testResponder.notNil) {
            ~testResponder.free;
            ~testResponder = nil;
        };
        // Clean up MIDI clip recording handlers
        if (~recordingNoteOnDef.notNil) {
            ~recordingNoteOnDef.free;
            ~recordingNoteOnDef = nil;
        };
        if (~recordingNoteOffDef.notNil) {
            ~recordingNoteOffDef.free;
            ~recordingNoteOffDef = nil;
        };
        // Clean up any active recording timer
        if (~recordingTimer.notNil) {
            ~recordingTimer.clear;
            ~recordingTimer = nil;
        };
    };
    
    // Store window reference
    ~melodyManagerWin = win;
    
    win.front;
    ^win;
};

// Initialize GUI after setup completes - with delay to avoid setup conflicts
AppClock.sched(1.0, {
    if (~melodyManagerWin.isNil) {
        ~createMelodyManagerUI.();
    };
    nil; // Don't reschedule
});

// Note: To create the melody manager UI, call ~createMelodyManagerUI.(); 

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                      PHASE 1: TESTING AND DEBUGGING                        │
// └─────────────────────────────────────────────────────────────────────────────┘

// Test function to inspect captured clip data
~inspectLastClip = {
    var lastClip, clips;
    
    if (~melodyData.isNil or: { ~melodyData[\melodies].isNil }) {
        "No melody data available for inspection".postln;
        ^nil;
    };
    
    clips = ~melodyData[\melodies].select({ |melody| melody[\isClip] == true });
    
    if (clips.size == 0) {
        "No clips found in melody data".postln;
        ^nil;
    };
    
    lastClip = clips.last;
    
    "=== CLIP INSPECTION ===".postln;
    "Clip name: %".format(lastClip[\name]).postln;
    "Clip key: %".format(lastClip[\key]).postln;
    "Is clip: %".format(lastClip[\isClip]).postln;
    "".postln;
    
    if (lastClip[\clipData].notNil) {
        "✅ CLIP DATA PRESERVED!".postln;
        "Total duration: %s".format(lastClip[\clipData][\duration].round(0.001)).postln;
        "Event count: %".format(lastClip[\clipData][\eventCount]).postln;
        "Note count: %".format(lastClip[\clipData][\metadata][\noteCount]).postln;
        "Recorded at: %".format(lastClip[\clipData][\metadata][\recordedAt]).postln;
        "".postln;
        
        "=== TIMING DATA ===".postln;
        lastClip[\clipData][\notePairs].do({ |notePair, i|
            "Note %: pitch=%, start=%s, duration=%s, velocity=%".format(
                i + 1,
                notePair[\note],
                notePair[\startTime].round(0.001),
                notePair[\duration].round(0.001),
                notePair[\velocity]
            ).postln;
        });
        
        "".postln;
        "✅ SUCCESS: Timing data is being preserved!".postln;
    } {
        "❌ ERROR: No clipData found - timing data was lost!".postln;
    };
    
    ^lastClip;
};

// Test function to verify MIDI capture is working
~testMIDICapture = {
    "=== MIDI CAPTURE TEST ===".postln;
    "Recording state: %".format(~clipRecordingState).postln;
    "Recorded events: %".format(~recordedEvents.size).postln;
    "".postln;
    
    if (~recordedEvents.size > 0) {
        "Recent events:".postln;
        ~recordedEvents.do({ |event, i|
            "Event %: type=%, note=%, velocity=%, time=%s".format(
                i + 1,
                event[\type],
                event[\note],
                event[\velocity],
                event[\time].round(0.001)
            ).postln;
        });
    } {
        "No events captured yet".postln;
    };
    
    "".postln;
    "MIDI handlers status:".postln;
    "Note On handler: %".format(if (~recordingNoteOnDef.notNil) { "✅ Active" } { "❌ Not active" }).postln;
    "Note Off handler: %".format(if (~recordingNoteOffDef.notNil) { "✅ Active" } { "❌ Not active" }).postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                      PHASE 1: SYSTEM INITIALIZATION                        │
// └─────────────────────────────────────────────────────────────────────────────┘

// Initialize the MIDI clip recording system
AppClock.sched(0.5, {
    // Setup MIDI input for clip recording
    ~setupClipMIDIInput.();
    "MIDI Clip Recording System (Phase 1) initialized".postln;
    nil; // Don't reschedule
}); 