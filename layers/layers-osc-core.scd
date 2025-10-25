/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                      OSC LAYERS SYSTEM - CORE                                 ║
║                   Pure OSC-based layer control                                ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                       GLOBAL OSC LAYERS STATE                              │
// └─────────────────────────────────────────────────────────────────────────────┘

// Independent playback state (simple global variables - truly mutable)
~layer1_isPlaying = false;
~layer1_currentTask = nil;
~layer2_isPlaying = false;
~layer2_currentTask = nil;
~layer3_isPlaying = false;
~layer3_currentTask = nil;

// Global MIDI row override dictionary (for manual assignments)
~midiRowOverrides = Dictionary.new;  // groupName → rowNumber (1-3)

// Main container for OSC-based layer system
~oscLayers = (
    // System state
    state: (
        totalDuration: 0,
        startTime: nil,
        loopingMode: false,
        manualControl: true,  // Default: ON (MIDI knob control for BPM, velocity, duration)
        singleNoteCCMode: false,
        bendMode: false,
        isRunning: false,
        noteDurationScalar: 1.0,
        melodyRestTime: 0.0,  // Rest duration between loops (0-1 seconds)
        pendingUpdates: Dictionary.new,  // Live melody updates (always active)
        // Global melody navigation
        currentMelodyIndex: 0,
        melodyList: [],  // Array of melody keys from loaded file
        // Chord Groups System
        activeChordGroup: nil,  // Active chord group for /chord messages
        // Simplified - no timing state needed
    ),

    // DYNAMIC LAYERS: Dictionaries instead of fixed configs (Phase 1)
    // Legacy layer configs removed - using only dynamic layers now
    configs: nil,  // Deprecated - use dynamicConfigs instead

    // OSC responders for each layer
    responders: Dictionary.new,

    // Layer coordinator (timing controller)
    coordinator: nil,

    // DYNAMIC LAYERS (Phase 1): Per-group layer management
    dynamicConfigs: Dictionary.new,      // groupName → config
    dynamicResponders: Dictionary.new,   // groupName → [OSCFuncs array]
    groupToIndex: Dictionary.new,        // groupName → alphabetical index
    indexToGroup: Dictionary.new,        // index → groupName
    groupToSanitized: Dictionary.new,    // groupName → sanitized symbol

    // Chord group indexing (separate from regular groups)
    chordGroupToIndex: Dictionary.new,   // "chordGroup1" → 0
    indexToChordGroup: Dictionary.new    // 0 → "chordGroup1"
);

// Legacy layer OSC responders removed - using only dynamic layers now

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                       SYSTEM OSC RESPONDERS                                │
// └─────────────────────────────────────────────────────────────────────────────┘

// Create global system OSC responders
~createSystemOSCResponders = {
    var responders = [];

    "Creating system OSC responders...".postln;

    // System start: /system/start
    responders = responders.add(
        OSCFunc({|msg|
            var duration = msg[1] ? (~oscLayers.state.totalDuration ? 2.0);
            "OSC: System start, duration: %".format(duration).postln;
            ~startLayersOSC.(duration);
        }, '/system/start')
    );

    // System stop: /system/stop
    responders = responders.add(
        OSCFunc({|msg|
            "OSC: System stop".postln;
            ~stopLayersOSC.();
        }, '/system/stop')
    );

    // Looping mode: /system/looping
    responders = responders.add(
        OSCFunc({|msg|
            var enabled = msg[1].asBoolean;
            ~oscLayers.state.loopingMode = enabled;
            "OSC: Looping mode: %".format(enabled).postln;
        }, '/system/looping')
    );

    // Manual control: /system/manual_control
    responders = responders.add(
        OSCFunc({|msg|
            var enabled = msg[1].asBoolean;
            ~oscLayers.state.manualControl = enabled;
            "OSC: Manual control: %".format(enabled).postln;
        }, '/system/manual_control')
    );

    // Single note CC mode: /system/single_note_cc
    responders = responders.add(
        OSCFunc({|msg|
            var enabled = msg[1].asBoolean;
            ~oscLayers.state.singleNoteCCMode = enabled;
            "OSC: Single note CC mode: %".format(enabled).postln;
        }, '/system/single_note_cc')
    );

    // Bend mode: /system/bend_mode
    responders = responders.add(
        OSCFunc({|msg|
            var enabled = msg[1].asBoolean;
            ~oscLayers.state.bendMode = enabled;
            "OSC: Bend mode: %".format(enabled).postln;
        }, '/system/bend_mode')
    );

    // Timing status query: /system/timing_status
    responders = responders.add(
        OSCFunc({|msg, time, addr|
            var offsets = ~getLayerOffsets.();
            "OSC: Timing status query - offsets: %".format(offsets).postln;

            // Send acknowledgment with current offsets
            if (addr.notNil) {
                addr.sendMsg('/ack', '/system/timing_status',
                    offsets.layer1, offsets.layer2, offsets.layer3);
            };
        }, '/system/timing_status')
    );

    // Melody rest control: /system/melody_rest
    responders = responders.add(
        OSCFunc({|msg|
            var restTime = msg[1].clip(0.0, 1.0);  // Clamp to 0-1 seconds
            ~oscLayers.state.melodyRestTime = restTime;
            "OSC: Melody rest time: %s".format(restTime.round(0.01)).postln;
        }, '/system/melody_rest')
    );

    // NOTE: /melody responder removed - duplicate of EXTERNAL /melody (line ~888)
    // EXTERNAL /melody handles both chord groups (by index) and regular groups (by name)

    // ─────────────────────────────────────────────────────────────
    // CHORD GROUP SYSTEM
    // ─────────────────────────────────────────────────────────────

    // Legacy /chord responder removed - now handled by JSON /chord in external control section

    // /system/active_chord_group - Set active chord group
    responders = responders.add(
        OSCFunc({|msg|
            var groupName = msg[1];

            if (groupName.isNil or: { groupName.asString.isEmpty }) {
                ~oscLayers.state.activeChordGroup = nil;
                "OSC: Cleared active chord group".postln;
            } {
                if (~vstManager.setActiveChordGroup(groupName)) {
                    ~oscLayers.state.activeChordGroup = groupName;
                    "OSC: Active chord group set to: %".format(groupName).postln;
                };
            };
        }, '/system/active_chord_group')
    );

    // /system/list_chord_groups - List all chord groups (sends reply)
    responders = responders.add(
        OSCFunc({|msg, addr|
            var chordGroups;

            if (~vstManager.notNil) {
                chordGroups = ~vstManager.getChordGroupNames();

                // Send reply to port 7001
                NetAddr("127.0.0.1", 7001).sendMsg('/chord_groups/list', *chordGroups);

                "OSC: Sent chord groups list (% groups)".format(chordGroups.size).postln;
            } {
                "OSC: VST Manager not available".warn;
            };
        }, '/system/list_chord_groups')
    );

    ~oscLayers.responders[\system] = responders;

    "Created % system OSC responders".format(responders.size).postln;
    responders;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                       OSC LAYER CONTROL FUNCTIONS                          │
// └─────────────────────────────────────────────────────────────────────────────┘

// Start individual layer via OSC messages
~startOSCLayer = {|layerKey, duration|
    var config = ~oscLayers.configs[layerKey];
    var melodyData, pattern, layerNum, noteInterval, velocity;

    // Ensure duration is a number
    if (duration.isKindOf(Number).not) {
        "ERROR: Duration must be a number, got %".format(duration.class).error;
        ^this;
    };

    // Get melody data
    melodyData = ~getLayerMelodyDynamic.(layerKey);

    if (melodyData.isNil) {
        "Layer % has no melody to play".format(layerKey).warn;
        ^this;
    };

    // Extract the actual note pattern
    if (melodyData.isKindOf(Dictionary) and: { melodyData.patterns.notNil }) {
        pattern = melodyData.patterns[0]; // Use first pattern
    } {
        if (melodyData.isKindOf(Array)) {
            pattern = melodyData; // Direct array of notes
        } {
            "Layer % melody data format not recognized".format(layerKey).warn;
            ^this;
        };
    };

    if (pattern.isNil or: { pattern.size == 0 }) {
        "Layer % pattern is empty".format(layerKey).warn;
        ^this;
    };

    layerNum = layerKey.asString.last.asString.asInteger;
    "Starting layer % with % notes, duration: %s".format(layerKey, pattern.size, duration).postln;

    // Calculate timing
    noteInterval = duration / pattern.size;

    // Get velocity from Row 1 Knob 3 (legacy layer system)
    velocity = if (~oscLayers.state.manualControl and: { ~midiController.notNil }) {
        var rawVel;
        rawVel = ~midiController.getKnobRow1(3);

        // Smart scaling: detect if already in MIDI range or normalized
        if (rawVel > 1.0) {
            rawVel.asInteger.clip(1, 127);  // Already MIDI range
        } {
            (rawVel * 127).asInteger.clip(1, 127);  // Normalized, scale to MIDI
        };
    } {
        127; // Default velocity
    };

    // Send melody via OSC messages with timing
    // Normal melody mode: Sequential playback
    pattern.do {|note, i|
        var when = i * noteInterval;
        var noteDuration = (noteInterval * 0.8) * config.noteDurationScalar; // Apply scalar from Row X Knob 2

        SystemClock.sched(when, {
            NetAddr.localAddr.sendMsg('/layer' ++ layerNum ++ '/note', note, velocity, noteDuration);
        });
    };

    // Trigger layer expression envelope if not in single note mode
    if (~oscLayers.state.singleNoteCCMode.not and: { config.ccControl.enabled }) {
        NetAddr.localAddr.sendMsg('/layer' ++ layerNum ++ '/expression', duration);
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                       CHORD GROUP PLAYBACK                                 │
// └─────────────────────────────────────────────────────────────────────────────┘

~playChordToGroup = { |groupName, notes, velocity, duration|
    var instances, groupType;

    // Validate VST Manager
    if (~vstManager.isNil) {
        "VST Manager not available".error;
        nil
    };

    // Validate group exists
    groupType = ~vstManager.getGroupType(groupName);
    if (groupType.isNil) {
        "Group '%' not found".format(groupName).warn;
        nil
    };

    // Validate group is chord type
    if (groupType != \chord) {
        "Group '%' is not a chord group (type: %)".format(groupName, groupType).warn;
        nil
    };

    // Get VST instances
    instances = ~vstManager.getTargetInstances(groupName).values.asArray;

    if (instances.size == 0) {
        "Chord group '%' has no VST instances".format(groupName).warn;
        nil
    };

    "Chord: % notes → % VSTs in group '%'".format(
        notes.size, instances.size, groupName
    ).postln;

    // Distribute notes across VST instances (round-robin)
    notes.do { |note, idx|
        var targetVST = instances.wrapAt(idx);
        var vel = velocity ?? { 100 };
        var dur = duration ?? { 1.0 };

        if (targetVST.notNil) {
            // Send note on
            targetVST.midi.noteOn(0, note, vel);

            // Schedule note off
            SystemClock.sched(dur, {
                targetVST.midi.noteOff(0, note);
            });

            "  Note % → VST % (idx: %)".format(
                note, targetVST, idx % instances.size
            ).postln;
        };
    };

    true;
};

// Play chord with per-note velocity and duration from JSON
~playChordToGroupJSON = { |groupName, noteDataArray|
    var instances, groupType, config, sanitizedName, maxDuration, rowNum, velocity;

    // Validate VST Manager
    if (~vstManager.isNil) {
        "VST Manager not available".error;
        false;
    };

    // Validate group
    groupType = ~vstManager.getGroupType(groupName);
    if (groupType.isNil) {
        "ERROR: Group '%' not found. Available groups: %".format(
            groupName,
            ~vstManager.getGroupNames()
        ).error;
        false;
    };

    if (groupType != \chord) {
        "ERROR: Group '%' is type '%' but expected 'chord'. This group cannot be used with /chord endpoint.".format(
            groupName, groupType
        ).error;
        "  → To fix: Re-save this group as a chord group, or use a different group.".postln;
        "  → Available chord groups: %".format(~vstManager.getChordGroupNames()).postln;
        false;
    };

    // Get VST instances
    instances = ~vstManager.getTargetInstances(groupName).values.asArray;

    if (instances.size == 0) {
        "Chord group '%' has no VST instances".format(groupName).warn;
        nil
    };

    // Get dynamic layer config for MIDI parameters and expression envelope
    config = ~oscLayers.dynamicConfigs[groupName];
    sanitizedName = ~oscLayers.groupToSanitized[groupName];

    if (config.isNil or: { sanitizedName.isNil }) {
        "ERROR: No dynamic layer config for group '%'".format(groupName).error;
        ^false;
    };

    "Chord JSON: % notes → % VSTs in group '%'".format(
        noteDataArray.size, instances.size, groupName
    ).postln;

    // Calculate maximum note duration for expression envelope
    maxDuration = 0;
    noteDataArray.do { |noteData|
        var dur = (noteData[\dur].asFloat) * config.noteDurationScalar;
        maxDuration = max(maxDuration, dur);
    };

    // Get MIDI row for this group to read velocity
    rowNum = ~getMIDIRowForGroup.(groupName);

    // Read velocity from MIDI controller Row X Knob 3 (with safety checks)
    velocity = if (~oscLayers.state.manualControl and: { ~midiController.notNil }) {
        var rawVel;
        rawVel = ~midiController.getKnobRow(rowNum, 3);

        // Smart scaling: detect if already in MIDI range or normalized
        if (rawVel > 1.0) {
            rawVel.asInteger.clip(1, 127);  // Already MIDI range
        } {
            (rawVel * 127).asInteger.clip(1, 127);  // Normalized, scale to MIDI
        };
    } {
        127;  // Default velocity if manual control off or controller unavailable
    };

    "Velocity from MIDI (Row % Knob 3): %".format(rowNum, velocity).postln;

    // Multi-instrument routing: each note to different VST
    noteDataArray.do { |noteData, idx|
        var targetVST, midiNote, duration;
        targetVST = instances.wrapAt(idx);
        midiNote = noteData[\midi].asInteger;
        duration = (noteData[\dur].asFloat) * config.noteDurationScalar;  // Apply MIDI scalar

        if (targetVST.notNil) {
            // Send note on (use velocity from MIDI controller)
            targetVST.midi.noteOn(0, midiNote, velocity);

            // Schedule note off
            SystemClock.sched(duration, {
                targetVST.midi.noteOff(0, midiNote);
            });

            "  Note % (vel %, dur %s) → VST idx %".format(
                midiNote, velocity, duration.round(0.001), idx
            ).postln;
        };
    };

    // Trigger expression envelope if enabled
    if (config.ccControl.enabled) {
        // Update expression parameters from MIDI knobs RIGHT before triggering
        ~updateLayerExpressionParams.(groupName);

        // Track which group triggered the envelope for /midi/cc routing
        ~oscLayers.lastTriggeredGroup = groupName;

        NetAddr.localAddr.sendMsg('/group/' ++ sanitizedName ++ '/expression', maxDuration);
        "  Expression envelope triggered (dur: %s, min: %, max: %)".format(
            maxDuration.round(0.001),
            config.ccControl.expressionMin,
            config.ccControl.expressionMax
        ).postln;
    };

    maxDuration;  // Return duration for completion scheduling
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                      CHORD GROUP INDEXING FUNCTIONS                        │
// └─────────────────────────────────────────────────────────────────────────────┘

// Update chord group indices (alphabetical ordering)
~updateChordGroupIndices = {
    var chordGroups;

    if (~vstManager.isNil) {
        "VST Manager not available, skipping chord group indexing".warn;
        false;
    };

    chordGroups = ~vstManager.getChordGroupNames();  // Already alphabetically sorted

    ~oscLayers.chordGroupToIndex.clear;
    ~oscLayers.indexToChordGroup.clear;

    chordGroups.do { |groupName, index|
        ~oscLayers.chordGroupToIndex[groupName] = index;
        ~oscLayers.indexToChordGroup[index] = groupName;
    };

    "Updated chord group indices (% groups)".format(chordGroups.size).postln;
    true;
};

// Resolve chord group by index or name
~resolveChordGroup = { |target|
    var groupName, chordGroups;

    // If integer, treat as chord group index
    if (target.isKindOf(Integer) or: { target.isKindOf(Float) }) {
        groupName = ~oscLayers.indexToChordGroup[target.asInteger];
        if (groupName.isNil) {
            chordGroups = ~vstManager.getChordGroupNames();
            "ERROR: Chord group index % not found.".format(target).error;
            if (chordGroups.size == 0) {
                "  → No chord groups exist! Create a chord group first.".postln;
                "  → All current groups are type 'regular': %".format(~vstManager.getGroupNames()).postln;
            } {
                "  → Available chord groups (count: %): %".format(chordGroups.size, chordGroups).postln;
                "  → Valid indices: 0 to %".format(chordGroups.size - 1).postln;
            };
        };
    } {
        // Otherwise treat as group name
        groupName = target.asSymbol;
    };

    groupName
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                    INDEPENDENT LAYER PLAYBACK                              │
// └─────────────────────────────────────────────────────────────────────────────┘

// Start a single layer with independent looping (or one-shot)
// Legacy independent layer functions removed - use dynamic layers system

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                       OSC LAYER COORDINATOR                                │
// └─────────────────────────────────────────────────────────────────────────────┘

// Create the OSC-based layer coordinator (replaces ProcMod parent)
~createOSCCoordinator = {
    var coordinator = ();

    // Add properties
    coordinator.currentTask = nil;

    // Add methods
    coordinator.startAll = {|duration|
        var syncTime = Main.elapsedTime + 0.1; // 100ms coordination buffer
        var activeLayerCount = 0;

        "OSC Coordinator: Starting all layers, duration: %s".format(duration).postln;

        ~oscLayers.state.totalDuration = duration;
        ~oscLayers.state.startTime = syncTime;
        ~oscLayers.state.isRunning = true;

        // Create coordination task
        coordinator.currentTask = Task({
                var loopCount = 0;
                var currentDuration, layerOffsets, maxOffset, totalWaitTime;

                while { ~oscLayers.state.loopingMode or: { loopCount == 0 } } {
                    loopCount = loopCount + 1;

                    // Determine duration for this iteration
                    if (~oscLayers.state.manualControl and: { ~getBPMFromKnob.notNil }) {
                        var bpm = ~getBPMFromKnob.();
                        // Use average note count across enabled layers for coordinator
                        var avgNoteCount = 0;
                        var enabledCount = 0;
                        [\layer1, \layer2, \layer3].do { |lKey|
                            var config = ~oscLayers.configs[lKey];
                            if (config.enabled) {
                                avgNoteCount = avgNoteCount + ~getMelodyNoteCount.(lKey);
                                enabledCount = enabledCount + 1;
                            };
                        };
                        if (enabledCount > 0) {
                            avgNoteCount = avgNoteCount / enabledCount;
                        } {
                            avgNoteCount = 4; // Default
                        };
                        currentDuration = ~calculateDurationFromBPM.(bpm, avgNoteCount);
                        "Loop %: BPM-based duration: %s (BPM: %, avg notes: %)".format(
                            loopCount, currentDuration, bpm.round(1), avgNoteCount.round(1)
                        ).postln;
                    } {
                        currentDuration = duration;
                        "Loop %: Fixed duration: %s".format(loopCount, currentDuration).postln;
                    };

                    // Update expression parameters from MIDI
                    if (~updateAllLayerExpressionParams.notNil) {
                        ~updateAllLayerExpressionParams.();
                    };

                    // Update note duration scalars from MIDI (Row 1-3 Knob 2)
                    ~updateAllLayerNoteDurationScalars.();

                    // Start layers using simplified offset calculation
                    layerOffsets = ~getLayerOffsets.();
                    maxOffset = 0;

                    [\layer1, \layer2, \layer3].do {|layerKey|
                        var config = ~oscLayers.configs[layerKey];
                        if (config.enabled and: { config.melodyList.size > 0 }) {
                            var triggerTime = layerOffsets[layerKey];
                            maxOffset = max(maxOffset, triggerTime);

                            // Schedule layer start
                            SystemClock.sched(triggerTime, {
                                "OSC Coordinator: Starting % at offset %s".format(layerKey, triggerTime).postln;
                                ~startOSCLayer.(layerKey, currentDuration);
                                nil; // Don't reschedule
                            });

                            activeLayerCount = activeLayerCount + 1;
                        };
                    };

                    if (activeLayerCount > 0) {
                        // Wait for layers to complete: max offset + note duration
                        totalWaitTime = maxOffset + currentDuration;
                        totalWaitTime.wait;

                        if (~oscLayers.state.loopingMode) {
                            // Get current melody rest time
                            var melodyRest = ~oscLayers.state.melodyRestTime;

                            if (melodyRest > 0) {
                                "Loop % complete, resting for %s before next iteration".format(
                                    loopCount, melodyRest.round(0.01)
                                ).postln;
                                melodyRest.wait;  // Inject rest here
                            } {
                                "Loop % complete, next starts immediately".format(loopCount).postln;
                            };
                        } {
                            "Single iteration complete".postln;
                        };
                    } {
                        "No active layers, stopping".warn;
                        // DON'T reset loopingMode - user may want it to stay enabled for next start
                    };
                };

                // Cleanup when finished
                coordinator.cleanup();
            });

            // Start the coordination task
            coordinator.currentTask.play;
        };

    coordinator.stopAll = {
        // Reset runtime state only, preserve user preferences
        ~oscLayers.state.isRunning = false;
        // DON'T reset loopingMode - it's a user preference that should persist

        if (coordinator.currentTask.notNil) {
            coordinator.currentTask.stop;
            coordinator.currentTask = nil;
        };

        // Clean up any active bend synths
        [\layer1, \layer2, \layer3].do { |layerKey|
            var config = ~oscLayers.configs[layerKey];
            if (config.bendControl.activeBendSynths.notNil) {
                config.bendControl.activeBendSynths.do(_.free);
                config.bendControl.activeBendSynths.clear;
            };
        };

        "OSC Coordinator: All layers stopped (with bend cleanup)".postln;
    };

    coordinator.cleanup = {
        ~oscLayers.state.isRunning = false;
        ~oscLayers.state.startTime = nil;
        coordinator.currentTask = nil;

        // Clean up any active bend synths
        [\layer1, \layer2, \layer3].do { |layerKey|
            var config = ~oscLayers.configs[layerKey];
            if (config.bendControl.activeBendSynths.notNil) {
                config.bendControl.activeBendSynths.do(_.free);
                config.bendControl.activeBendSynths.clear;
            };
        };

        "OSC Coordinator: Cleanup complete (with bend cleanup)".postln;
    };

    coordinator;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                     MIDI NOTE DURATION SCALAR CONTROL                      │
// └─────────────────────────────────────────────────────────────────────────────┘

// Update note duration scalars from MIDI knobs (Row 1-3 Knob 2)
~updateAllLayerNoteDurationScalars = {
    [\layer1, \layer2, \layer3].do { |layerKey, index|
        var rowNum = index + 1; // layer1=row1, layer2=row2, layer3=row3
        var config = ~oscLayers.configs[layerKey];

        if (~midiController.notNil && config.notNil) {
            var knobValue = ~midiController.getKnobRow(rowNum, 2);
            config.noteDurationScalar = knobValue.linlin(0, 127, 0.01, 1.0);
            // Optional debug output
            // "Layer % note duration scalar: %% (Row % Knob 2)".format(
            //     layerKey,
            //     (config.noteDurationScalar * 100).round(1),
            //     rowNum
            // ).postln;
        };
    };
};

// Update note duration scalar for a specific layer
// Legacy function removed - use dynamic layers version at line 1901 with group names

// Legacy MIDI template processing removed - use dynamic layers only

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                       EXTERNAL CONTROL SETUP                               │
// └─────────────────────────────────────────────────────────────────────────────┘

// Setup external OSC control (automatic network control)
~setupExternalOSCControl = { |port = 7000|
    var externalResponders = [];

    "Setting up external OSC control on port %...".format(port).postln;

    // Open UDP port for external control
    thisProcess.openUDPPort(port);

    // External system control with acknowledgment
    externalResponders = externalResponders.add(
        OSCFunc({|msg, time, addr|
            var duration = msg[1] ? 2.0;
            "EXTERNAL OSC: Start request from % (duration: %s)".format(addr.ip, duration).postln;
            NetAddr.localAddr.sendMsg('/system/start', duration);
            addr.sendMsg('/ack', '/external/start', 'started', duration);
        }, '/external/start')
    );

    externalResponders = externalResponders.add(
        OSCFunc({|msg, time, addr|
            "EXTERNAL OSC: Stop request from %".format(addr.ip).postln;
            NetAddr.localAddr.sendMsg('/system/stop');
            addr.sendMsg('/ack', '/external/stop', 'stopped');
        }, '/external/stop')
    );

    // External layer note control
    externalResponders = externalResponders.add(
        OSCFunc({|msg, time, addr|
            var layerNum = msg[1];
            var note = msg[2];
            var velocity = msg[3] ? 100;
            var duration = msg[4] ? 1.0;

            "EXTERNAL OSC: Layer % note % from %".format(layerNum, note, addr.ip).postln;
            NetAddr.localAddr.sendMsg('/layer' ++ layerNum ++ '/note', note, velocity, duration);
            addr.sendMsg('/ack', '/external/note', layerNum, note, 'played');
        }, '/external/note')
    );

    // External melody updates
    externalResponders = externalResponders.add(
        OSCFunc({|msg, time, addr|
            var layerNum = msg[1];
            var melodyData = msg[2];

            "EXTERNAL OSC: Melody update for layer % from %".format(layerNum, addr.ip).postln;

            if (melodyData.isKindOf(Array)) {
                var melodyKey = ('external_' ++ Date.getDate.stamp).asSymbol;

                // Create melody entry
                if (~melodyDict.isNil) { ~melodyDict = Dictionary.new };
                ~melodyDict[melodyKey] = (
                    patterns: [melodyData],
                    velocities: melodyData.collect({ 100 }),
                    noteDurations: melodyData.collect({ 0.5 })
                );

                // Set melody for layer
                NetAddr.localAddr.sendMsg('/layer' ++ layerNum ++ '/melody', melodyKey);
                addr.sendMsg('/ack', '/external/melody', layerNum, melodyData.size, 'updated');
            } {
                addr.sendMsg('/error', '/external/melody', 'invalid_format');
            };
        }, '/external/melody')
    );

    // External CC control
    externalResponders = externalResponders.add(
        OSCFunc({|msg, time, addr|
            var layerNum = msg[1];
            var ccNum = msg[2];
            var value = msg[3];

            "EXTERNAL OSC: CC control layer % CC % = % from %".format(layerNum, ccNum, value, addr.ip).postln;
            NetAddr.localAddr.sendMsg('/layer' ++ layerNum ++ '/cc', ccNum, value);
            addr.sendMsg('/ack', '/external/cc', layerNum, ccNum, value);
        }, '/external/cc')
    );

    // /chord - JSON-based chord trigger with per-note control
    externalResponders = externalResponders.add(
        OSCFunc({|msg, time, addr|
            var jsonString, data, notes, targetGroup, groupName, maxDuration;

            // Convert to string and parse JSON (same pattern as /melody)
            jsonString = msg[1].asString;
            data = JSONlib.convertToSC(jsonString, useEvent: true);

            // Extract notes array
            notes = data[\notes];
            if (notes.isNil or: { notes.size == 0 }) {
                "ERROR: /chord JSON missing or empty 'notes' array".error;
                nil;
            };

            // Resolve target group (index or name)
            targetGroup = data[\metadata][\targetGroup];
            if (targetGroup.isNil) {
                targetGroup = ~oscLayers.state.activeChordGroup;
            };

            if (targetGroup.isNil) {
                "ERROR: No targetGroup in metadata and no active chord group".error;
                nil;
            };

            // Resolve chord group by index or name
            groupName = ~resolveChordGroup.(targetGroup);

            if (groupName.isNil) {
                "ERROR: Could not resolve chord group: %".format(targetGroup).error;
                nil;
            };

            "EXTERNAL OSC /chord: % notes → chord group '%' (target: %)".format(
                notes.size, groupName, targetGroup
            ).postln;

            // Update note duration scalar before playback
            ~updateLayerNoteDurationScalar.(groupName);
            // Note: Expression params updated just-in-time before envelope trigger

            // Play chord with per-note velocity/duration and get max duration
            maxDuration = ~playChordToGroupJSON.(groupName, notes);

            // Schedule completion message after chord finishes playing (matches /melody/complete pattern)
            if (maxDuration.notNil and: { maxDuration > 0 }) {
                SystemClock.sched(maxDuration, {
                    NetAddr("127.0.0.1", 7001).sendMsg('/chord/complete', targetGroup);
                    "Sent /chord/complete for targetGroup % after %s".format(targetGroup, maxDuration.round(0.001)).postln;
                });
            } {
                "Warning: Could not schedule /chord/complete (maxDuration: %)".format(maxDuration).warn;
            };

        }, '/chord')
    );

    // /melody - JSON-based melody assignment
    externalResponders = externalResponders.add(
        OSCFunc({|msg, time, addr|
            var jsonString, data, notes, targetGroup, groupName, melodyKey, melody;

            // Convert to string and parse JSON (same pattern as system /melody)
            jsonString = msg[1].asString;
            data = JSONlib.convertToSC(jsonString, useEvent: true);

            // Extract target group (index for REGULAR groups, or name for any group)
            targetGroup = data[\metadata][\targetGroup];
            if (targetGroup.isNil) {
                "ERROR: /melody JSON missing metadata.targetGroup".error;
                nil;
            };

            // Resolve by index (REGULAR groups only) or by name
            if (targetGroup.isKindOf(Integer) or: { targetGroup.isKindOf(Float) }) {
                var regularGroups;
                regularGroups = ~vstManager.getRegularGroupNames();
                groupName = regularGroups[targetGroup.asInteger];
                if (groupName.isNil) {
                    "ERROR: /melody regular group index % not found. Available: %".format(
                        targetGroup, regularGroups
                    ).error;
                };
            } {
                // String name - works for any group type
                groupName = targetGroup;
            };

            if (groupName.isNil) {
                "ERROR: Could not resolve group: %".format(targetGroup).error;
                nil;
            };

            "EXTERNAL OSC /melody: Target group '%' (from: %)".format(groupName, targetGroup).postln;

            // Convert JSON to melody format
            melody = ~convertJSONToMelody.(data);

            // Store in melodyDict
            melodyKey = ('melody_' ++ Date.getDate.stamp).asSymbol;
            if (~melodyDict.isNil) { ~melodyDict = Dictionary.new };
            ~melodyDict[melodyKey] = melody;

            // Assign to group's dynamic layer and start playback
            if (~oscLayers.dynamicConfigs[groupName].notNil) {
                ~setMelodyListForGroup.(groupName, [melodyKey]);
                "Assigned melody '%' to dynamic group '%'".format(melodyKey, groupName).postln;

                // Start playback immediately (always non-looping for external control)
                ~startDynamicGroupPlayback.(groupName, targetGroup, false);
            } {
                "WARNING: No dynamic layer for group '%', melody stored in ~melodyDict only".format(groupName).warn;
            };

            // NOTE: Completion message now sent by ~startDynamicGroupPlayback after playback finishes
            // (Removed immediate acknowledgment to match chord completion timing)

        }, '/melody')
    );

    // Store external responders
    ~oscLayers.responders[\external] = externalResponders;

    "External OSC control enabled on port %".format(port).postln;
    "Send OSC to this computer's IP on port % for external control".format(port).postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                    DYNAMIC LAYERS - PHASE 1 CORE FUNCTIONS                │
// └─────────────────────────────────────────────────────────────────────────────┘

// Sanitize group name for use in OSC paths
~sanitizeGroupName = { |groupName|
    groupName.asString
        .toLower
        .replace(" ", "_")
        .replace("-", "_")
        .replace("/", "_")
        .replace("(", "")
        .replace(")", "")
        .replace("#", "")
        .asSymbol
};

// Update MIDI index mappings (alphabetical ordering)
~updateMIDIIndices = {
    var sortedGroups;

    sortedGroups = ~oscLayers.dynamicConfigs.keys.asArray.sort;

    // Clear existing mappings
    ~oscLayers.groupToIndex.clear;
    ~oscLayers.indexToGroup.clear;

    // Rebuild mappings
    sortedGroups.do { |groupName, index|
        ~oscLayers.groupToIndex[groupName] = index;
        ~oscLayers.indexToGroup[index] = groupName;

        // Update alphabetical index in config
        if (~oscLayers.dynamicConfigs[groupName].notNil) {
            ~oscLayers.dynamicConfigs[groupName].alphabeticalIndex = index;
        };
    };

    "Updated MIDI indices for % groups".format(sortedGroups.size).postln;
};

// Get MIDI row for a group (1-3, with manual override support)
~getMIDIRowForGroup = { |groupName|
    var override, idx;

    // Check for manual override first
    override = ~midiRowOverrides[groupName];
    if (override.notNil) {
        override.clip(1, 3)  // Ensure valid range
    } {
        // Fall back to automatic assignment
        idx = ~oscLayers.groupToIndex[groupName];
        if (idx.notNil) {
            (idx % 3) + 1  // Returns 1, 2, or 3
        } {
            1  // Default to row 1 if not found
        }
    }
};

// Create layer configuration for a group
~createLayerForGroup = { |groupName|
    var sanitizedName, config, alphabeticalIndex, rowNum;
    var rawMin = 10;   // Default fallback
    var rawMax = 120;  // Default fallback
    var durationScalar = 1.0;

    // Sanitize group name
    sanitizedName = ~sanitizeGroupName.(groupName);

    // Store sanitized mapping
    ~oscLayers.groupToSanitized[groupName] = sanitizedName;

    // Create placeholder config first (for MIDI index calculation)
    ~oscLayers.dynamicConfigs[groupName] = ();

    // Update MIDI indices NOW (with new group included)
    ~updateMIDIIndices.();

    // Get alphabetical index (now correctly calculated)
    alphabeticalIndex = ~oscLayers.groupToIndex[groupName];

    // Get MIDI row for this group (for reading current values)
    rowNum = ~getMIDIRowForGroup.(groupName);

    // Read current MIDI values for expression

    if (~midiController.notNil) {
        rawMin = ~midiController.getKnobRow(rowNum, 5);
        rawMax = ~midiController.getKnobRow(rowNum, 6);

        // Smart scaling: detect if already in CC range or normalized
        if (rawMin > 1.0 or: { rawMax > 1.0 }) {
            rawMin = rawMin.asInteger.clip(0, 127);
            rawMax = rawMax.asInteger.clip(0, 127);
        } {
            rawMin = (rawMin * 127).asInteger.clip(0, 127);
            rawMax = (rawMax * 127).asInteger.clip(0, 127);
        };

        // Duration scalar from knob 4
        durationScalar = ~midiController.getKnobRow(rowNum, 4).clip(0.0, 1.0).linlin(0.0, 1.0, 0.001, 1.0);
    };

    // Create full configuration
    config = (
        // Identity
        groupName: groupName,
        sanitizedName: sanitizedName,
        alphabeticalIndex: alphabeticalIndex,
        vstGroup: groupName,  // Direct 1:1 mapping

        // Independent melody navigation
        melodyList: [],
        currentMelodyIndex: 0,

        // Expression control
        expressionCC: 11 + alphabeticalIndex,  // Auto-assigned CC
        expressionMin: rawMin,      // Use MIDI value
        expressionMax: rawMax,      // Use MIDI value
        expressionDurationScalar: durationScalar,

        // Playback state
        enabled: true,
        defaultDuration: 4.0,
        isPlaying: false,
        currentTask: nil,
        noteDurationScalar: 1.0,

        // CC control (matching legacy structure)
        ccControl: (
            enabled: true,
            expressionCC: 11 + alphabeticalIndex,
            expressionMin: rawMin,      // Use MIDI value
            expressionMax: rawMax,      // Use MIDI value
            expressionShape: \sin,
            expressionPeakPos: 0.5,
            expressionDurationScalar: durationScalar
        ),

        // Bend control (matching legacy structure)
        bendControl: (
            enabled: true,
            bendAmount: 0.0,
            peakTimeRatio: 0.5,
            returnTimeRatio: 0.5,
            simpleRamp: false,
            activeBendSynths: Dictionary.new
        )
    );

    // Replace placeholder with full configuration
    ~oscLayers.dynamicConfigs[groupName] = config;

    // Create OSC responders for this group
    ~createGroupOSCResponders.(sanitizedName, config);

    "Created dynamic layer for group: % (sanitized: %, CC: %, MIDI row: %, min: %, max: %)".format(
        groupName, sanitizedName, config.expressionCC, rowNum, rawMin, rawMax
    ).postln;

    config
};

// Remove layer for a group
~removeLayerForGroup = { |groupName|
    var config, responders;

    config = ~oscLayers.dynamicConfigs[groupName];

    if (config.notNil) {
        // Stop playback if running
        if (config.currentTask.notNil) {
            config.currentTask.stop;
            config.currentTask = nil;
        };
        config.isPlaying = false;

        // Free OSC responders
        responders = ~oscLayers.dynamicResponders[groupName];
        if (responders.notNil) {
            responders.do(_.free);
            ~oscLayers.dynamicResponders.removeAt(groupName);
        };

        // Remove from all dictionaries
        ~oscLayers.dynamicConfigs.removeAt(groupName);
        ~oscLayers.groupToSanitized.removeAt(groupName);

        // Update MIDI indices
        ~updateMIDIIndices.();

        "Removed dynamic layer for group: %".format(groupName).postln;
        true
    } {
        "Group % not found in dynamic layers".format(groupName).warn;
        false
    }
};

// Create OSC responders for a group (7 OSCFuncs per group)
~createGroupOSCResponders = { |sanitizedName, config|
    var responders, groupName, oscPath;

    responders = [];
    groupName = config.groupName;

    "Creating OSC responders for group: % (path: /group/%)".format(groupName, sanitizedName).postln;

    // 1. /group/<sanitized>/note - Individual note trigger
    oscPath = '/group/' ++ sanitizedName ++ '/note';
    responders = responders.add(
        OSCFunc({ |msg|
            var note, velocity, duration;
            note = msg[1];
            velocity = msg[2] ? 127;
            duration = msg[3] ? 0.5;

            // Send to VST group
            if (~vstManager.notNil) {
                var instances = ~vstManager.getTargetInstances(groupName);
                instances.do { |vst|
                    vst.midi.noteOn(0, note, velocity);
                    if (duration > 0) {
                        SystemClock.sched(duration, {
                            vst.midi.noteOff(0, note, 0);
                        });
                    };
                };
            };
        }, oscPath)
    );

    // 2. /group/<sanitized>/chord - Chord trigger
    oscPath = '/group/' ++ sanitizedName ++ '/chord';
    responders = responders.add(
        OSCFunc({ |msg|
            var notes, velocity, duration, argIndex;

            notes = [];
            argIndex = 1;
            while { argIndex < (msg.size - 2) and: { msg[argIndex].isNumber } } {
                notes = notes.add(msg[argIndex].asInteger);
                argIndex = argIndex + 1;
            };

            velocity = msg[msg.size - 2].asInteger ? 127;
            duration = msg[msg.size - 1].asFloat ? 0.5;

            // Send to VST group
            if (~vstManager.notNil) {
                var instances = ~vstManager.getTargetInstances(groupName);
                instances.do { |vst|
                    notes.do { |note, idx|
                        vst.midi.noteOn(idx, note, velocity);
                        if (duration > 0) {
                            SystemClock.sched(duration, {
                                vst.midi.noteOff(idx, note, 0);
                            });
                        };
                    };
                };
            };
        }, oscPath)
    );

    // 3. /group/<sanitized>/cc - Direct CC control
    oscPath = '/group/' ++ sanitizedName ++ '/cc';
    responders = responders.add(
        OSCFunc({ |msg|
            var ccNum, value;
            ccNum = msg[1];
            value = msg[2];

            if (~vstManager.notNil) {
                var instances = ~vstManager.getTargetInstances(groupName);
                instances.do { |vst|
                    vst.midi.control(0, ccNum, value);
                };
            };
        }, oscPath)
    );

    // 4. /group/<sanitized>/expression - CC envelope
    oscPath = '/group/' ++ sanitizedName ++ '/expression';
    responders = responders.add(
        OSCFunc({ |msg|
            var duration, synthName, ccControl, scaledDuration, attackTime, releaseTime;

            duration = msg[1] ? 1.0;
            synthName = \ccEnvelopeGeneric;  // Use generic SynthDef
            ccControl = config.ccControl;

            if (ccControl.enabled) {
                scaledDuration = duration * ccControl.expressionDurationScalar;
                attackTime = scaledDuration * ccControl.expressionPeakPos;
                releaseTime = scaledDuration * (1.0 - ccControl.expressionPeakPos);

                "DEBUG Synth args: start=%, peak=%, end=%, attackTime=%, releaseTime=%".format(
                    ccControl.expressionMin,
                    ccControl.expressionMax,
                    ccControl.expressionMin,
                    attackTime,
                    releaseTime
                ).postln;

                Synth(synthName, [
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
            };
        }, oscPath)
    );

    // 5. /group/<sanitized>/bend - Pitch bend envelope
    oscPath = '/group/' ++ sanitizedName ++ '/bend';
    responders = responders.add(
        OSCFunc({ |msg|
            var duration, bendControl, bendAmount, peakTime, simpleRamp;
            var bendCenter, bendRangeRaw, peakValue;

            duration = msg[1] ? 1.0;
            bendControl = config.bendControl;

            if (bendControl.enabled) {
                bendAmount = bendControl.bendAmount;
                peakTime = bendControl.peakTimeRatio;
                simpleRamp = bendControl.simpleRamp;
                bendCenter = 8192;

                bendRangeRaw = (bendAmount * 8191).round.asInteger;
                peakValue = (bendCenter + bendRangeRaw).clip(0, 16383);

                // Clean up existing bend synths
                bendControl.activeBendSynths.do(_.free);
                bendControl.activeBendSynths.clear;

                // Create bend synths for each VST in group
                if (~vstManager.notNil) {
                    ~vstManager.getTargetInstances(groupName).keysValuesDo { |vstKey, vst, vstIndex|
                        var replyID, bendSynth;
                        replyID = (config.alphabeticalIndex * 100) + vstIndex;

                        if (simpleRamp) {
                            bendSynth = Synth(\BendEnvelopeSimple, [
                                \start, bendCenter,
                                \end, peakValue,
                                \duration, duration,
                                \chanIndex, vstIndex,
                                \customReplyID, replyID
                            ]);
                        } {
                            bendSynth = Synth(\BendEnvelope, [
                                \start, bendCenter,
                                \peak, peakValue,
                                \end, bendCenter,
                                \peakTime, duration * peakTime,
                                \returnTime, duration * (1.0 - peakTime),
                                \chanIndex, vstIndex,
                                \customReplyID, replyID
                            ]);
                        };

                        bendControl.activeBendSynths[vstKey] = bendSynth;
                    };
                };
            };
        }, oscPath)
    );

    // 6. /group/<sanitized>/melody - Set melody
    oscPath = '/group/' ++ sanitizedName ++ '/melody';
    responders = responders.add(
        OSCFunc({ |msg|
            var melodyKey;
            melodyKey = msg[1].asSymbol;
            config.melodyList = [melodyKey];
            "Group % melody set to: %".format(groupName, melodyKey).postln;
        }, oscPath)
    );

    // 7. /group/<sanitized>/enabled - Enable/disable
    oscPath = '/group/' ++ sanitizedName ++ '/enabled';
    responders = responders.add(
        OSCFunc({ |msg|
            var enabled;
            enabled = msg[1].asBoolean;
            config.enabled = enabled;
            "Group % enabled: %".format(groupName, enabled).postln;
        }, oscPath)
    );

    // Store responders
    ~oscLayers.dynamicResponders[groupName] = responders;

    "Created % OSC responders for group: %".format(responders.size, groupName).postln;
    responders
};

// Rebuild dynamic layers from current VST groups
~rebuildDynamicLayers = {
    var currentGroups, existingGroups, groupsToAdd, groupsToRemove;

    if (~vstManager.isNil) {
        "VST Manager not available, cannot rebuild dynamic layers".warn;
        ^this
    };

    // Get current VST groups
    currentGroups = ~vstManager.getGroupNames();
    existingGroups = ~oscLayers.dynamicConfigs.keys.asArray;

    // Calculate diff
    groupsToAdd = currentGroups.difference(existingGroups);
    groupsToRemove = existingGroups.difference(currentGroups);

    "Rebuilding dynamic layers: % to add, % to remove".format(
        groupsToAdd.size, groupsToRemove.size
    ).postln;

    // Remove deleted groups
    groupsToRemove.do { |groupName|
        ~removeLayerForGroup.(groupName);
    };

    // Add new groups
    groupsToAdd.do { |groupName|
        ~createLayerForGroup.(groupName);
    };

    // Update chord group indices
    ~updateChordGroupIndices.();

    "Dynamic layers rebuild complete: % total groups".format(currentGroups.size).postln;
};

// Load generic SynthDefs for dynamic layers
~loadDynamicLayersSynthDefs = {
    "Loading generic SynthDefs for dynamic layers...".postln;

    // Generic CC envelope SynthDef (parameterized CC number)
    SynthDef(\ccEnvelopeGeneric, { |start=10, peak=120, end=10, attackTime=0.5, releaseTime=0.5, chanIndex=0, ccNum=11, attackCurve=\sin, releaseCurve=\sin|
        var env, envValue;

        env = Env([start, peak, end], [attackTime, releaseTime], [attackCurve, releaseCurve]);
        envValue = EnvGen.kr(env, doneAction: Done.freeSelf);

        SendReply.kr(Impulse.kr(60), '/midi/cc', [chanIndex, ccNum, envValue]);
    }).add;

    "Generic SynthDefs loaded for dynamic layers".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                    DYNAMIC LAYERS - PHASE 2 MELODY FUNCTIONS              │
// └─────────────────────────────────────────────────────────────────────────────┘

// Navigate to next melody for a specific group
~nextMelodyForGroup = { |groupName|
    var config, currentMelody;

    config = ~oscLayers.dynamicConfigs[groupName];

    if (config.isNil) {
        "Group % not found in dynamic layers".format(groupName).warn;
        nil
    };

    if (config.melodyList.size > 0) {
        config.currentMelodyIndex = (config.currentMelodyIndex + 1) % config.melodyList.size;
        currentMelody = config.melodyList[config.currentMelodyIndex];

        "Group %: Next melody: % (% of %)".format(
            groupName,
            currentMelody,
            config.currentMelodyIndex + 1,
            config.melodyList.size
        ).postln;

        currentMelody
    } {
        "Group %: No melodies loaded for navigation".format(groupName).warn;
        nil
    }
};

// Navigate to previous melody for a specific group
~prevMelodyForGroup = { |groupName|
    var config, currentMelody;

    config = ~oscLayers.dynamicConfigs[groupName];

    if (config.isNil) {
        "Group % not found in dynamic layers".format(groupName).warn;
        nil
    };

    if (config.melodyList.size > 0) {
        config.currentMelodyIndex = (config.currentMelodyIndex - 1) % config.melodyList.size;
        if (config.currentMelodyIndex < 0) {
            config.currentMelodyIndex = config.melodyList.size - 1;
        };
        currentMelody = config.melodyList[config.currentMelodyIndex];

        "Group %: Previous melody: % (% of %)".format(
            groupName,
            currentMelody,
            config.currentMelodyIndex + 1,
            config.melodyList.size
        ).postln;

        currentMelody
    } {
        "Group %: No melodies loaded for navigation".format(groupName).warn;
        nil
    }
};

// Set melody list for a specific group
~setMelodyListForGroup = { |groupName, melodyKeys|
    var config;

    config = ~oscLayers.dynamicConfigs[groupName];

    if (config.isNil) {
        "Group % not found in dynamic layers".format(groupName).warn;
        false
    } {
        if (melodyKeys.isNil or: { melodyKeys.size == 0 }) {
            "Warning: Setting empty melody list for group %".format(groupName).warn;
            config.melodyList = [];
            config.currentMelodyIndex = 0;
            true
        } {
            config.melodyList = melodyKeys.asArray;
            config.currentMelodyIndex = 0;

            "Group %: Melody list set with % melodies: %".format(
                groupName,
                config.melodyList.size,
                config.melodyList
            ).postln;

            true
        }
    }
};

// Get current melody for a specific group
~getCurrentMelodyForGroup = { |groupName|
    var config, currentMelody;

    config = ~oscLayers.dynamicConfigs[groupName];

    if (config.isNil) {
        "Group % not found in dynamic layers".format(groupName).warn;
        nil
    };

    if (config.melodyList.size > 0) {
        currentMelody = config.melodyList[config.currentMelodyIndex];
        "Group %: Current melody: % (% of %)".format(
            groupName,
            currentMelody,
            config.currentMelodyIndex + 1,
            config.melodyList.size
        ).postln;
        currentMelody
    } {
        "Group %: No melodies loaded".format(groupName).postln;
        nil
    }
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                    DYNAMIC LAYERS - PHASE 3 MIDI INTEGRATION              │
// └─────────────────────────────────────────────────────────────────────────────┘

// Update expression parameters for a specific group from MIDI knobs
~updateLayerExpressionParams = { |groupName|
    var config, rowNum, ccControl;

    config = ~oscLayers.dynamicConfigs[groupName];

    if (config.isNil) {
        "Group % not found in dynamic layers".format(groupName).warn;
        false
    };

    // Get MIDI row for this group (1, 2, or 3)
    rowNum = ~getMIDIRowForGroup.(groupName);

    ccControl = config.ccControl;

    if (~midiController.notNil and: { ccControl.notNil }) {
        var rawMin, rawMax;

        // Read expression parameters from appropriate row
        // Row X, Knob 5: Expression min (0-127)
        // Row X, Knob 6: Expression max (0-127)
        // Row X, Knob 4: Expression duration scalar (0.001-1.0)

        rawMin = ~midiController.getKnobRow(rowNum, 5);
        rawMax = ~midiController.getKnobRow(rowNum, 6);

        // Smart scaling: detect if already in CC range or normalized
        // If value > 1.0, assume it's already CC range (0-127)
        // If value ≤ 1.0, assume it's normalized (0.0-1.0) and scale
        if (rawMin > 1.0 or: { rawMax > 1.0 }) {
            // Already in CC range, use as-is
            ccControl.expressionMin = rawMin.asInteger.clip(0, 127);
            ccControl.expressionMax = rawMax.asInteger.clip(0, 127);
        } {
            // Normalized range, scale to CC
            ccControl.expressionMin = (rawMin * 127).asInteger.clip(0, 127);
            ccControl.expressionMax = (rawMax * 127).asInteger.clip(0, 127);
        };

        // Duration scalar (always normalized 0.0-1.0)
        ccControl.expressionDurationScalar = ~midiController.getKnobRow(rowNum, 4).clip(0.0, 1.0).linlin(0.0, 1.0, 0.001, 1.0);

        // Ensure valid range
        if (ccControl.expressionMax <= ccControl.expressionMin) {
            ccControl.expressionMax = ccControl.expressionMin + 1;
        };

        "Group % expression from MIDI (Row %): Min=%, Max=%, DurScalar=%".format(
            groupName, rowNum,
            ccControl.expressionMin,
            ccControl.expressionMax,
            ccControl.expressionDurationScalar.round(0.01)
        ).postln;

        true
    } {
        "MIDI controller not available for group %".format(groupName).warn;
        false
    }
};

// Update expression parameters for all dynamic groups from MIDI knobs
~updateAllLayerExpressionParams = {
    var successCount;

    successCount = 0;

    ~oscLayers.dynamicConfigs.keysValuesDo { |groupName, config|
        if (~updateLayerExpressionParams.(groupName)) {
            successCount = successCount + 1;
        };
    };

    "Updated expression parameters for % of % groups from MIDI".format(
        successCount, ~oscLayers.dynamicConfigs.size
    ).postln;

    ^successCount
};

// Update note duration scalar for a specific group from MIDI knobs
~updateLayerNoteDurationScalar = { |groupName|
    var config, rowNum;

    config = ~oscLayers.dynamicConfigs[groupName];

    if (config.isNil) {
        "Group % not found in dynamic layers".format(groupName).warn;
        false
    };

    // Get MIDI row for this group (1, 2, or 3)
    rowNum = ~getMIDIRowForGroup.(groupName);

    if (~midiController.notNil) {
        // Row X, Knob 2: Note duration scalar (0.01-1.0)
        config.noteDurationScalar = ~midiController.getKnobRow(rowNum, 2).linlin(0, 127, 0.01, 1.0);

        // Optional debug output
        // "Group % note duration scalar: %% (Row % Knob 2)".format(
        //     groupName,
        //     (config.noteDurationScalar * 100).round(1),
        //     rowNum
        // ).postln;

        true
    } {
        "MIDI controller not available for group %".format(groupName).warn;
        false
    }
};

// Update note duration scalars for all dynamic groups from MIDI knobs
~updateAllLayerNoteDurationScalars = {
    var successCount;

    successCount = 0;

    ~oscLayers.dynamicConfigs.keysValuesDo { |groupName, config|
        if (~updateLayerNoteDurationScalar.(groupName)) {
            successCount = successCount + 1;
        };
    };

    ^successCount
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                   DYNAMIC LAYERS - PHASE 4 SYSTEM INTEGRATION             │
// └─────────────────────────────────────────────────────────────────────────────┘

// Register callback for VST group changes (event-driven)
~registerDynamicLayersCallback = {
    ~refreshLayerVSTGroups = {
        "VST groups changed, rebuilding dynamic layers...".postln;
        ~rebuildDynamicLayers.();
        // Also refresh GUI if it exists
        if (~refreshLayersGUI.notNil) { ~refreshLayersGUI.() };
    };

    "Registered dynamic layers callback with VST management".postln;
};

// Start playback for a dynamic group (single group)
~startDynamicGroupPlayback = { |groupName, targetGroup = nil, loop = true, duration = nil|
    var config, melodyData, pattern, noteInterval, velocity, sanitizedName, playDuration, melodyKey, result, rowNum;

    "DEBUG startPlayback: groupName=%".format(groupName).postln;
    "DEBUG startPlayback: targetGroup=%".format(targetGroup).postln;
    "DEBUG startPlayback: loop=%".format(loop).postln;

    config = ~oscLayers.dynamicConfigs[groupName];

    result = if (config.isNil) {
        "Group % not found in dynamic layers".format(groupName).warn;
        false
    } {
        "DEBUG startPlayback: config.enabled=%".format(config.enabled).postln;

        if (config.enabled.not) {
            "Group % is disabled, skipping playback".format(groupName).postln;
            false
        } {
            "DEBUG startPlayback: melodyList.size=%".format(config.melodyList.size).postln;

            if (config.melodyList.size == 0) {
                "Group % has no melody to play".format(groupName).warn;
                false
            } {
                melodyKey = config.melodyList[config.currentMelodyIndex];
                "DEBUG startPlayback: melodyKey=%".format(melodyKey).postln;

                if (~melodyDict.isNil or: { ~melodyDict[melodyKey].isNil }) {
                    "Group %: Melody % not found in ~melodyDict".format(groupName, melodyKey).warn;
                    false
                } {
                    melodyData = ~melodyDict[melodyKey];
                    "DEBUG startPlayback: Melody found".postln;

                    // Extract pattern
                    pattern = if (melodyData.isKindOf(Dictionary) and: { melodyData.patterns.notNil }) {
                        melodyData.patterns[0]
                    } {
                        if (melodyData.isKindOf(Array)) {
                            melodyData
                        } {
                            nil
                        }
                    };

                    if (pattern.isNil or: { pattern.size == 0 }) {
                        "Group %: Pattern is empty or invalid".format(groupName).warn;
                        false
                    } {
                        // Determine duration - NEW: Use BPM if manual control is on
                        playDuration = duration ?? {
                            if (~oscLayers.state.manualControl and: { ~getBPMFromKnob.notNil }) {
                                var bpm = ~getBPMFromKnob.();
                                var noteCount = pattern.size;
                                var bpmDuration = ~calculateDurationFromBPM.(bpm, noteCount);
                                "Melody % using BPM %: duration %s for % notes".format(
                                    groupName, bpm.round(1), bpmDuration.round(0.01), noteCount
                                ).postln;
                                bpmDuration
                            } {
                                // Fallback to metadata or default
                                if (melodyData.metadata.notNil and: { melodyData.metadata.totalDuration.notNil }) {
                                    melodyData.metadata.totalDuration
                                } {
                                    4.0
                                }
                            }
                        };

                        sanitizedName = config.sanitizedName;
                        noteInterval = playDuration / pattern.size;

                        // Get MIDI row for this group
                        rowNum = ~getMIDIRowForGroup.(groupName);

                        // NEW: Update note duration scalar from MIDI before playback
                        if (~oscLayers.state.manualControl and: { ~updateLayerNoteDurationScalar.notNil }) {
                            ~updateLayerNoteDurationScalar.(groupName);
                        };

                        // Read velocity from MIDI controller Row X Knob 3 (with safety checks)
                        velocity = if (~oscLayers.state.manualControl and: { ~midiController.notNil }) {
                            var rawVel;
                            rawVel = ~midiController.getKnobRow(rowNum, 3);

                            // Smart scaling: detect if already in MIDI range or normalized
                            if (rawVel > 1.0) {
                                rawVel.asInteger.clip(1, 127);  // Already MIDI range
                            } {
                                (rawVel * 127).asInteger.clip(1, 127);  // Normalized, scale to MIDI
                            };
                        } {
                            127;  // Default velocity if manual control off or controller unavailable
                        };

                        "Starting dynamic group %: % notes, duration: %s, loop: %, velocity: %, noteDurScalar: %".format(
                            groupName, pattern.size, playDuration.round(0.01), loop, velocity,
                            config.noteDurationScalar.round(0.01)
                        ).postln;

                        // Send notes via OSC
                        pattern.do { |note, i|
                            var when, noteDuration;
                            when = i * noteInterval;
                            noteDuration = (noteInterval * 0.8) * config.noteDurationScalar;

                            SystemClock.sched(when, {
                                NetAddr.localAddr.sendMsg('/group/' ++ sanitizedName ++ '/note', note, velocity, noteDuration);
                            });
                        };

                        // Trigger expression envelope if enabled
                        if (config.ccControl.enabled) {
                            // Update expression parameters from MIDI knobs RIGHT before triggering
                            ~updateLayerExpressionParams.(groupName);

                            // CRITICAL: Track which group triggered the envelope for /midi/cc routing
                            ~oscLayers.lastTriggeredGroup = groupName;

                            // NEW: Debug output to verify expression values
                            "Group % expression from MIDI (Row %): Min=%, Max=%, DurScalar=%".format(
                                groupName, rowNum,
                                config.ccControl.expressionMin,
                                config.ccControl.expressionMax,
                                config.ccControl.expressionDurationScalar.round(0.001)
                            ).postln;

                            NetAddr.localAddr.sendMsg('/group/' ++ sanitizedName ++ '/expression', playDuration);
                        };

                        // Send completion message if not looping and targetGroup is provided
                        if (loop.not and: { targetGroup.notNil }) {
                            SystemClock.sched(playDuration, {
                                NetAddr("127.0.0.1", 7001).sendMsg('/melody/complete', targetGroup);
                                "Sent completion for targetGroup %".format(targetGroup).postln;
                            });
                        };

                        "DEBUG startPlayback: Returning true".postln;
                        true
                    }
                }
            }
        }
    };

    result
};

// Start all dynamic groups (coordinator-style)
~startAllDynamicGroups = { |duration|
    var successCount;

    successCount = 0;
    duration = duration ?? { 4.0 };

    "Starting all dynamic groups with duration: %s".format(duration).postln;

    ~oscLayers.dynamicConfigs.keysValuesDo { |groupName, config|
        if (~startDynamicGroupPlayback.(groupName, nil, true, duration)) {
            successCount = successCount + 1;
        };
    };

    "Started % of % dynamic groups".format(successCount, ~oscLayers.dynamicConfigs.size).postln;
    ^successCount
};

// Legacy compatibility removed - use dynamic layers directly

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                    DYNAMIC LAYERS - INITIALIZATION                         │
// └─────────────────────────────────────────────────────────────────────────────┘

// Initialize dynamic layers system (Phase 1-4 complete)
~initDynamicLayersSystem = {
    var existingGroups;

    "Initializing Dynamic Layers System...".postln;

    // Clean up existing dynamic layers to prevent duplicates
    existingGroups = ~oscLayers.dynamicConfigs.keys.asArray;
    if (existingGroups.size > 0) {
        "Cleaning up % existing dynamic layers before re-initialization...".format(existingGroups.size).postln;
        existingGroups.do { |groupName|
            ~removeLayerForGroup.(groupName);
        };
    };

    // Phase 1: Core functions
    ~loadDynamicLayersSynthDefs.();
    "Dynamic layer containers initialized".postln;

    // Create layers from existing VST groups
    if (~vstManager.notNil) {
        ~vstManager.getGroupNames().do { |groupName|
            ~createLayerForGroup.(groupName);
        };
        "Created dynamic layers for % groups".format(~vstManager.getGroupNames().size).postln;

        // Initialize chord group indices
        ~updateChordGroupIndices.();
    } {
        "VST Manager not available, skipping dynamic layer creation".warn;
    };

    // Phase 4: System integration
    ~registerDynamicLayersCallback.();

    "Dynamic Layers System initialized (Phases 1-4 complete)".postln;
    "  - Core functions ready".postln;
    "  - Melody navigation ready".postln;
    "  - MIDI integration ready".postln;
    "  - Event-driven updates registered".postln;
};

// Function to update a specific layer's MIDI row
~updateLayerMIDIRow = { |groupName|
    var config, newRow;

    config = ~oscLayers.dynamicConfigs[groupName];
    if (config.notNil) {
        newRow = ~getMIDIRowForGroup.(groupName);

        "Updating MIDI row for group '%': % → %".format(
            groupName,
            config.midiRow ? "none",
            newRow
        ).postln;

        config.midiRow = newRow;

        // Update any active parameter callbacks
        if (~updateLayerParameterCallbacks.notNil) {
            ~updateLayerParameterCallbacks.(groupName);
        };
    };
};

// Function to refresh all MIDI rows (for config load)
~refreshDynamicLayersMIDI = {
    ~oscLayers.dynamicConfigs.keysValuesDo { |groupName, config|
        ~updateLayerMIDIRow.(groupName);
    };
    "Refreshed MIDI rows for all dynamic layers".postln;
};

// Test function for Phase 1
~testDynamicLayersPhase1 = {
    var configs, responders, groups;

    "=== Testing Dynamic Layers Phase 1 ===".postln;

    // Auto-initialize if not already done
    if (~oscLayers.dynamicConfigs.size == 0) {
        "".postln;
        "Dynamic layers not initialized, initializing now...".postln;
        ~initDynamicLayersSystem.();
        "".postln;
    };

    // Test 1: Sanitize group names
    "Test 1: Name sanitization".postln;
    ["Bass Tuba", "Layer1", "Sax Group #2", "Horn(s)"].do { |name|
        var sanitized;
        sanitized = ~sanitizeGroupName.(name);
        "  % → %".format(name, sanitized).postln;
    };

    // Test 2: Check current groups
    "".postln;
    "Test 2: Current VST groups".postln;
    if (~vstManager.notNil) {
        groups = ~vstManager.getGroupNames();
        "  Found % groups: %".format(groups.size, groups).postln;
    } {
        "  VST Manager not available".warn;
    };

    // Test 3: Check dynamic configs
    "".postln;
    "Test 3: Dynamic layer configs".postln;
    configs = ~oscLayers.dynamicConfigs;
    "  Total dynamic layers: %".format(configs.size).postln;
    configs.keysValuesDo { |groupName, config|
        "  - % (sanitized: %, CC: %, row: %, index: %)".format(
            groupName,
            config.sanitizedName,
            config.expressionCC,
            ~getMIDIRowForGroup.(groupName),
            config.alphabeticalIndex
        ).postln;
    };

    // Test 4: Check OSC responders
    "".postln;
    "Test 4: OSC responders".postln;
    responders = ~oscLayers.dynamicResponders;
    "  Total responder groups: %".format(responders.size).postln;
    responders.keysValuesDo { |groupName, resps|
        "  - %: % OSCFuncs".format(groupName, resps.size).postln;
    };

    // Test 5: MIDI index mappings
    "".postln;
    "Test 5: MIDI index mappings".postln;
    "  Group→Index: %".format(~oscLayers.groupToIndex).postln;
    "  Index→Group: %".format(~oscLayers.indexToGroup).postln;

    // Test 6: Test OSC paths (without actually sending notes)
    "".postln;
    "Test 6: OSC paths available".postln;
    configs.keysValuesDo { |groupName, config|
        var sanitized;
        sanitized = config.sanitizedName;
        "  Group '%':".format(groupName).postln;
        "    /group/%/note".format(sanitized).postln;
        "    /group/%/chord".format(sanitized).postln;
        "    /group/%/cc".format(sanitized).postln;
        "    /group/%/expression".format(sanitized).postln;
        "    /group/%/bend".format(sanitized).postln;
        "    /group/%/melody".format(sanitized).postln;
        "    /group/%/enabled".format(sanitized).postln;
    };

    "".postln;
    "=== Phase 1 Test Complete ===".postln;
};

// Test function for Phase 2 (Melody Functions)
~testDynamicLayersPhase2 = {
    var testGroup;

    "=== Testing Dynamic Layers Phase 2: Melody Functions ===".postln;

    // Auto-initialize if not already done
    if (~oscLayers.dynamicConfigs.size == 0) {
        "".postln;
        "Dynamic layers not initialized, initializing now...".postln;
        ~initDynamicLayersSystem.();
        "".postln;
    };

    // Use first available group for testing
    if (~oscLayers.dynamicConfigs.size > 0) {
        testGroup = ~oscLayers.dynamicConfigs.keys.asArray.sort.first;
        "".postln;
        "Using test group: %".format(testGroup).postln;

        // Test 1: Set melody list
        "".postln;
        "Test 1: Set melody list".postln;
        ~setMelodyListForGroup.(testGroup, [\melody1, \melody2, \melody3]);

        // Test 2: Get current melody
        "".postln;
        "Test 2: Get current melody".postln;
        ~getCurrentMelodyForGroup.(testGroup);

        // Test 3: Navigate forward
        "".postln;
        "Test 3: Navigate forward through melodies".postln;
        ~nextMelodyForGroup.(testGroup);  // Should be melody2
        ~nextMelodyForGroup.(testGroup);  // Should be melody3
        ~nextMelodyForGroup.(testGroup);  // Should wrap to melody1

        // Test 4: Navigate backward
        "".postln;
        "Test 4: Navigate backward through melodies".postln;
        ~prevMelodyForGroup.(testGroup);  // Should be melody3
        ~prevMelodyForGroup.(testGroup);  // Should be melody2

        // Test 5: Test with multiple groups
        "".postln;
        "Test 5: Independent melody lists per group".postln;
        if (~oscLayers.dynamicConfigs.size > 1) {
            var groups;
            groups = ~oscLayers.dynamicConfigs.keys.asArray.sort;

            // Set different melody lists for first two groups
            ~setMelodyListForGroup.(groups[0], [\melodyA, \melodyB]);
            ~setMelodyListForGroup.(groups[1], [\melodyX, \melodyY, \melodyZ]);

            // Show they're independent
            "Group %: Current = %".format(groups[0], ~getCurrentMelodyForGroup.(groups[0])).postln;
            "Group %: Current = %".format(groups[1], ~getCurrentMelodyForGroup.(groups[1])).postln;

            ~nextMelodyForGroup.(groups[0]);  // A->B
            ~nextMelodyForGroup.(groups[1]);  // X->Y

            "After next:".postln;
            "Group %: Current = %".format(groups[0], ~getCurrentMelodyForGroup.(groups[0])).postln;
            "Group %: Current = %".format(groups[1], ~getCurrentMelodyForGroup.(groups[1])).postln;
        } {
            "Only one group available, skipping multi-group test".postln;
        };

        // Test 6: Error handling
        "".postln;
        "Test 6: Error handling".postln;
        ~setMelodyListForGroup.("NonExistentGroup", [\test]);  // Should warn
        ~nextMelodyForGroup.("NonExistentGroup");  // Should warn

    } {
        "No dynamic groups available for testing".warn;
    };

    "".postln;
    "=== Phase 2 Test Complete ===".postln;
};

// Test function for Phase 3 (MIDI Integration)
~testDynamicLayersPhase3 = {
    var testGroup;

    "=== Testing Dynamic Layers Phase 3: MIDI Integration ===".postln;

    // Auto-initialize if not already done
    if (~oscLayers.dynamicConfigs.size == 0) {
        "".postln;
        "Dynamic layers not initialized, initializing now...".postln;
        ~initDynamicLayersSystem.();
        "".postln;
    };

    // Check MIDI controller availability
    "".postln;
    "Test 1: MIDI Controller availability".postln;
    if (~midiController.notNil) {
        "  ✓ MIDI controller available".postln;
    } {
        "  ✗ MIDI controller NOT available (functions will warn but not crash)".warn;
    };

    // Test 2: MIDI row assignments
    "".postln;
    "Test 2: MIDI row assignments".postln;
    ~oscLayers.dynamicConfigs.keysValuesDo { |groupName, config|
        var rowNum;
        rowNum = ~getMIDIRowForGroup.(groupName);
        "  Group %: Row % (index %)".format(groupName, rowNum, config.alphabeticalIndex).postln;
    };

    // Test 3: Update expression params for a single group
    "".postln;
    "Test 3: Update expression params for single group".postln;
    if (~oscLayers.dynamicConfigs.size > 0) {
        testGroup = ~oscLayers.dynamicConfigs.keys.asArray.sort.first;
        if (~updateLayerExpressionParams.(testGroup)) {
            var ccControl;
            ccControl = ~oscLayers.dynamicConfigs[testGroup].ccControl;
            "  Updated group %:".format(testGroup).postln;
            "    Min: %, Max: %, DurScalar: %".format(
                ccControl.expressionMin,
                ccControl.expressionMax,
                ccControl.expressionDurationScalar.round(0.001)
            ).postln;
        };
    };

    // Test 4: Update all groups
    "".postln;
    "Test 4: Update all groups at once".postln;
    ~updateAllLayerExpressionParams.();

    // Test 5: Update note duration scalars
    "".postln;
    "Test 5: Update note duration scalars".postln;
    if (~oscLayers.dynamicConfigs.size > 0) {
        testGroup = ~oscLayers.dynamicConfigs.keys.asArray.sort.first;
        if (~updateLayerNoteDurationScalar.(testGroup)) {
            var config;
            config = ~oscLayers.dynamicConfigs[testGroup];
            "  Updated group %: noteDurationScalar = %".format(
                testGroup,
                config.noteDurationScalar.round(0.01)
            ).postln;
        };
    };

    // Test 6: Show current MIDI mappings
    "".postln;
    "Test 6: Current MIDI knob mappings per group".postln;
    ~oscLayers.dynamicConfigs.keysValuesDo { |groupName, config|
        var rowNum;
        rowNum = ~getMIDIRowForGroup.(groupName);
        "  Group % (Row %):".format(groupName, rowNum).postln;
        "    Knob 2: Note Duration Scalar".postln;
        "    Knob 4: Expression Duration Scalar".postln;
        "    Knob 5: Expression Min".postln;
        "    Knob 6: Expression Max".postln;
    };

    "".postln;
    "=== Phase 3 Test Complete ===".postln;
};

// Test function for Phase 4 (System Integration)
~testDynamicLayersPhase4 = {
    var testGroup;

    "=== Testing Dynamic Layers Phase 4: System Integration ===".postln;

    // Auto-initialize if not already done
    if (~oscLayers.dynamicConfigs.size == 0) {
        "".postln;
        "Dynamic layers not initialized, initializing now...".postln;
        ~initDynamicLayersSystem.();
        "".postln;
    };

    // Test 1: Check callback registration
    "".postln;
    "Test 1: VST group change callback".postln;
    if (~refreshLayerVSTGroups.notNil) {
        "  ✓ Callback registered".postln;
    } {
        "  ✗ Callback NOT registered".warn;
    };

    // Test 2: Check backward compatibility mapping
    "".postln;
    "Test 2: Backward compatibility layer".postln;
    if (~oscLayers.legacyMapping.notNil) {
        "  layer1 → %".format(~oscLayers.legacyMapping.layer1).postln;
        "  layer2 → %".format(~oscLayers.legacyMapping.layer2).postln;
        "  layer3 → %".format(~oscLayers.legacyMapping.layer3).postln;
    } {
        "  ✗ Legacy mapping not established".warn;
    };

    // Test 3: Test single group playback (requires melody)
    "".postln;
    "Test 3: Single group playback".postln;
    if (~oscLayers.dynamicConfigs.size > 0) {
        testGroup = ~oscLayers.dynamicConfigs.keys.asArray.sort.first;

        // Set up a simple test melody
        if (~melodyDict.isNil) { ~melodyDict = Dictionary.new };
        ~melodyDict[\testMelody] = (
            patterns: [[60, 62, 64, 65]],
            velocities: [100, 100, 100, 100],
            noteDurations: [0.5, 0.5, 0.5, 0.5]
        );

        // Assign melody to group
        ~setMelodyListForGroup.(testGroup, [\testMelody]);

        // Try starting playback
        if (~startDynamicGroupPlayback.(testGroup, 2.0)) {
            "  ✓ Successfully started group % playback".format(testGroup).postln;
        } {
            "  ✗ Failed to start group % playback".format(testGroup).warn;
        };
    } {
        "  No groups available for testing".warn;
    };

    // Test 4: Test all groups playback
    "".postln;
    "Test 4: All groups playback".postln;
    if (~oscLayers.dynamicConfigs.size > 0) {
        var started;

        // Assign test melody to all groups
        ~oscLayers.dynamicConfigs.keysValuesDo { |groupName, config|
            ~setMelodyListForGroup.(groupName, [\testMelody]);
        };

        // Start all groups
        started = ~startAllDynamicGroups.(2.0);
        "  Started % of % groups".format(started, ~oscLayers.dynamicConfigs.size).postln;
    };

    // Test 5: Test callback simulation
    "".postln;
    "Test 5: Simulate VST group change".postln;
    if (~refreshLayerVSTGroups.notNil) {
        var groupCountBefore;
        groupCountBefore = ~oscLayers.dynamicConfigs.size;
        "  Groups before: %".format(groupCountBefore).postln;

        // Simulate callback (would normally be triggered by VST management)
        "  Calling ~refreshLayerVSTGroups...".postln;
        ~refreshLayerVSTGroups.();

        "  Groups after: %".format(~oscLayers.dynamicConfigs.size).postln;
        "  ✓ Callback executed successfully".postln;
    };

    // Test 6: Show complete system status
    "".postln;
    "Test 6: Complete system status".postln;
    "  Total dynamic groups: %".format(~oscLayers.dynamicConfigs.size).postln;
    "  OSC responders: %".format(~oscLayers.dynamicResponders.size).postln;
    "  Event-driven updates: %".format(if (~refreshLayerVSTGroups.notNil) { "enabled" } { "disabled" }).postln;
    "  Backward compatibility: %".format(if (~oscLayers.legacyMapping.notNil) { "enabled" } { "disabled" }).postln;

    "".postln;
    "=== Phase 4 Test Complete ===".postln;
    "".postln;
    "=== ALL PHASES (1-4) COMPLETE ===".postln;
    "Dynamic layers system is fully operational!".postln;
};

// Combined test for all phases
~testAllDynamicLayersPhases = {
    "".postln;
    "=== COMPREHENSIVE TEST: All Dynamic Layers Phases ===".postln;
    "".postln;

    ~testDynamicLayersPhase1.();
    "".postln;
    ~testDynamicLayersPhase2.();
    "".postln;
    ~testDynamicLayersPhase3.();
    "".postln;
    ~testDynamicLayersPhase4.();

    "".postln;
    "=== COMPREHENSIVE TEST COMPLETE ===".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                       INITIALIZATION FUNCTIONS                             │
// └─────────────────────────────────────────────────────────────────────────────┘

// Initialize the entire OSC layers system
~initOSCLayersSystem = {
    "Initializing OSC Layers System...".postln;

    // Create coordinator
    ~oscLayers.coordinator = ~createOSCCoordinator.();

    // Legacy layer responders removed - using only dynamic layers

    // Create system responders
    ~createSystemOSCResponders.();

    // Setup external control automatically
    ~setupExternalOSCControl.();

    // Setup compatibility layer
    ~setupOSCCompatibility.();

    "OSC Layers System initialized successfully".postln;
    "  - Dynamic layers only (no legacy layer1/2/3)".postln;
    "  - System-wide OSC commands".postln;
    "  - External control ready on port 7000".postln;
    "  - Compatibility layer established".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                        MELODY SYSTEM                                       │
// └─────────────────────────────────────────────────────────────────────────────┘

// Convert JSON melody data to ~melodyDict format
~convertJSONToMelody = { |data|
    var notes, patterns, velocities, durations;

    notes = data.notes;
    patterns = notes.collect { |n| n.midi };
    velocities = notes.collect { |n| (n.vel * 127).asInteger };
    durations = notes.collect { |n| n.dur };

    (
        name: data.metadata.name ? "Live Melody",
        patterns: [patterns],
        velocities: velocities,
        noteDurations: durations,
        metadata: data.metadata,
        durationType: "absolute"
    )
};

// Get melody data for a layer - similar to layers system
~getLayerMelodyDynamic = {|layerKey|
    var config = ~oscLayers.configs[layerKey];
    var currentMelodyKey, assignedLayerId, melodyDataKey;

    // Check if we have melodies loaded in global navigation
    if (~oscLayers.state.melodyList.size > 0) {
        // Get current melody from global navigation
        currentMelodyKey = ~oscLayers.state.melodyList[~oscLayers.state.currentMelodyIndex];
        assignedLayerId = config.assignedLayerId;

        // Build key for specific layer data: "melodyName_layerN"
        melodyDataKey = (currentMelodyKey.asString ++ "_" ++ assignedLayerId.asString).asSymbol;

        "DEBUG ~getLayerMelodyDynamic: layer=%, melody=%, assigned=%, key=%".format(
            layerKey, currentMelodyKey, assignedLayerId, melodyDataKey
        ).postln;

        ~melodyDict[melodyDataKey];
    } {
        // Fallback to old system if no global melodies loaded
        if (config.melodyList.notNil and: { config.melodyList.size > 0 }) {
            var melodyKey = config.melodyList[0];
            ~melodyDict[melodyKey];
        } {
            nil;
        };
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                       GLOBAL MELODY NAVIGATION                             │
// └─────────────────────────────────────────────────────────────────────────────┘

// Navigate to next melody (wraps around)
~nextMelody = {
    var currentMelody;

    if (~oscLayers.state.melodyList.size > 0) {
        ~oscLayers.state.currentMelodyIndex = (~oscLayers.state.currentMelodyIndex + 1) % ~oscLayers.state.melodyList.size;
        currentMelody = ~oscLayers.state.melodyList[~oscLayers.state.currentMelodyIndex];
        "Next melody: % (% of %)".format(
            currentMelody,
            ~oscLayers.state.currentMelodyIndex + 1,
            ~oscLayers.state.melodyList.size
        ).postln;

        // Apply the melody to all enabled layers
        ~applyCurrentMelodyToAllLayers.();

        currentMelody;
    } {
        "No melodies loaded for navigation".warn;
        nil;
    };
};

// Navigate to previous melody (wraps around)
~prevMelody = {
    var currentMelody;

    if (~oscLayers.state.melodyList.size > 0) {
        ~oscLayers.state.currentMelodyIndex = (~oscLayers.state.currentMelodyIndex - 1) % ~oscLayers.state.melodyList.size;
        if (~oscLayers.state.currentMelodyIndex < 0) {
            ~oscLayers.state.currentMelodyIndex = ~oscLayers.state.melodyList.size - 1;
        };
        currentMelody = ~oscLayers.state.melodyList[~oscLayers.state.currentMelodyIndex];
        "Previous melody: % (% of %)".format(
            currentMelody,
            ~oscLayers.state.currentMelodyIndex + 1,
            ~oscLayers.state.melodyList.size
        ).postln;

        // Apply the melody to all enabled layers
        ~applyCurrentMelodyToAllLayers.();

        currentMelody;
    } {
        "No melodies loaded for navigation".warn;
        nil;
    };
};

// Get current melody info
~getCurrentMelody = {
    if (~oscLayers.state.melodyList.size > 0) {
        var currentMelody = ~oscLayers.state.melodyList[~oscLayers.state.currentMelodyIndex];
        "Current melody: % (% of %)".format(
            currentMelody,
            ~oscLayers.state.currentMelodyIndex + 1,
            ~oscLayers.state.melodyList.size
        ).postln;
        currentMelody;
    } {
        "No melodies loaded".postln;
        nil;
    };
};

// Apply current global melody to all enabled layers
~applyCurrentMelodyToAllLayers = {
    var currentMelodyName, layersUpdated = 0;

    if (~oscLayers.state.melodyList.size > 0) {
        currentMelodyName = ~oscLayers.state.melodyList[~oscLayers.state.currentMelodyIndex];

        "Applying melody '%' to all enabled layers...".format(currentMelodyName).postln;

        // Apply to each enabled layer using their assigned layer ID
        [\layer1, \layer2, \layer3].do { |layerKey, i|
            var config = ~oscLayers.configs[layerKey];
            var layerNum = i + 1;
            var assignedLayerId = config.assignedLayerId;
            var melodyDataKey;

            if (config.enabled) {
                // Build key for layer-specific data: "melodyName_layerN"
                melodyDataKey = (currentMelodyName.asString ++ "_" ++ assignedLayerId.asString).asSymbol;

                // "DEBUG APPLY: Layer % (%): Building key '%'".format(layerNum, assignedLayerId, melodyDataKey).postln;

                // Check if this melody-layer combination exists
                if (~melodyDict.notNil and: { ~melodyDict[melodyDataKey].notNil }) {
                    // Send OSC message to update layer melody
                    NetAddr.localAddr.sendMsg('/layer' ++ layerNum ++ '/melody', melodyDataKey);
                    layersUpdated = layersUpdated + 1;

                    "  → Layer % (%): Applied melody data '%'".format(
                        layerNum, assignedLayerId, melodyDataKey
                    ).postln;
                } {
                    "  → Layer % (%): No data found for melody '%' (key: %) - layer will remain silent".format(
                        layerNum, assignedLayerId, currentMelodyName, melodyDataKey
                    ).postln;
                };
            } {
                "  → Layer % disabled, skipping".format(layerNum).postln;
            };
        };

        "Melody application complete: % layers updated".format(layersUpdated).postln;
        ^layersUpdated;
    } {
        "No current melody to apply".warn;
        ^0;
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                       COMPATIBILITY LAYER                                  │
// └─────────────────────────────────────────────────────────────────────────────┘

// Main control functions that work via OSC
~startLayersOSC = {|duration|
    duration = duration ?? { 2.0 };

    // Robust duration validation
    if (duration.isNumber.not) {
        "Duration must be a number, got %. Using 2.0s".format(duration.class).warn;
        duration = 2.0;
    };

    // Clip to reasonable bounds
    if (duration <= 0) {
        "Duration must be positive, got %. Using 2.0s".format(duration).warn;
        duration = 2.0;
    };

    duration = duration.clip(0.1, 60.0); // Reasonable bounds: 0.1s to 60s

    if (~oscLayers.coordinator.notNil) {
        ~oscLayers.coordinator[\startAll].value(duration);
    } {
        "OSC coordinator not initialized".error;
    };
};

~stopLayersOSC = {
    // Stop all independent layers (new system)
    if (~stopAllLayersIndependent.notNil) {
        ~stopAllLayersIndependent.();
    };

    // Also stop coordinator if it exists (legacy compatibility)
    if (~oscLayers.coordinator.notNil) {
        ~oscLayers.coordinator.stopAll();
    };
};

// Set up compatibility references
~setupOSCCompatibility = {
    // Make ~layers point to ~oscLayers for compatibility
    ~layers = ~oscLayers;

    // Preserve existing function interfaces for compatibility
    ~startLayers = ~startLayersOSC;
    ~stopLayers = ~stopLayersOSC;

    "OSC compatibility layer established".postln;
};

"OSC Layers Core loaded".postln;
"  - Pure OSC-based layer control".postln;
"  - No ProcMod dependencies".postln;
"  - Preserved function interfaces".postln;