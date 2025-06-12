/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                            SECOND LAYER SYSTEM                               ║
║                         Triggered note-by-note layer                         ║
║                         synchronized with primary sequence                   ║
║                                                                               ║
║                          Independent Layer System                            ║
║                        Communicates via OSC with primary                     ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                               MIDI MAPPING                                    ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                               ║
║  SECOND LAYER CONTROLS (Row 2 Knobs):                                        ║
║  - Knob 1 (Index 0): CC 17 - Unassigned                                      ║
║  - Knob 2 (Index 1): CC 21 - Note Duration (0.005-0.5s)                     ║
║  - Knob 3 (Index 2): CC 25 - Note Rest Time (0.0001-0.4s)                   ║
║  - Knob 4 (Index 3): CC 29 - Note Velocity (1-127)                           ║
║  - Knob 5 (Index 4): CC 47 - Expression Min (0-127)                          ║
║  - Knob 6 (Index 5): CC 51 - Expression Max (0-127)                          ║
║  - Knob 7 (Index 6): CC 55 - Duration Scalar (0.1-1.0)                       ║
║  - Knob 8 (Index 7): CC 59 - Unassigned                                      ║
║                                                                               ║
║  BUTTONS:                                                                    ║
║  - CC 46: Toggle Second Layer (enable/disable)                               ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                      SECOND LAYER STATE MANAGEMENT                         │
// └─────────────────────────────────────────────────────────────────────────────┘

// Second layer state and configuration
~layer2 = (
    enabled: false,              // Enable/disable second layer
    currentMelodyKey: nil,       // Current melody being played
    noteIndex: 0,                // Current position in melody
    pattern: nil,                // Current melody pattern
    activeVSTGroup: nil,         // VST group for second layer (independent)
    resetOnNewMelody: true,      // Reset note index when melody changes

    // MIDI-controlled parameters (using row 2 knobs)
    noteDuration: 0.2,           // Controlled by knob row 2, pos 2 (CC 21)
    noteRestTime: 0.2,           // Controlled by knob row 2, pos 3 (CC 25)
    velocity: 100,               // Controlled by knob row 2, pos 4 (CC 29)
    noteOffset: -12,             // Independent note offset

    // Expression control (using row 2 knobs)
    expressionMin: 10,           // Controlled by knob row 2, pos 5 (CC 47)
    expressionMax: 120,          // Controlled by knob row 2, pos 6 (CC 51)

    // === NEW: CC-Envelope internal state ===
    activeCCSynths: Dictionary.new, // stores running \ccEnvelope synths
    expressionPeakPos: 0.5          // 0-1, where the peak sits in one-shot mode
);

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                      SECOND LAYER CONTROL FUNCTIONS                        │
// └─────────────────────────────────────────────────────────────────────────────┘

// Enable/disable second layer
~layer2SetEnabled = { |enabled|
    ~layer2.enabled = enabled;
    "Second layer %".format(if(enabled, "ENABLED", "DISABLED")).postln;

    if(enabled.not) {
        // Reset state when disabled
        ~layer2.noteIndex = 0;
        ~layer2.currentMelodyKey = nil;
        ~layer2.pattern = nil;
    };
};

// Set VST group for second layer (independent targeting)
~layer2SetVSTGroup = { |groupName|
    var previousGroup, isAllInstances, groupStr, instances, groupExists, actualGroupKey, symbolKey, stringKey;

    previousGroup = ~layer2.activeVSTGroup;
    isAllInstances = false;
    groupExists = false;
    actualGroupKey = nil;

    // Check for "all instances" conditions
    if (groupName.isNil) {
        isAllInstances = true;
    }, {
        if (groupName.isKindOf(String) || groupName.isKindOf(Symbol)) {
            groupStr = groupName.asString.toLower;
            if (groupStr == "all") {
                isAllInstances = true;
            };
        };
    };

    if (isAllInstances) {
        ~layer2.activeVSTGroup = nil;
        ["Second Layer VST Group set to: ALL INSTANCES (was: %)".format(previousGroup ? "ALL")].postln;
    }, {
        // Check if group exists (try both Symbol and String forms)
        if (~vstManager.groups.includesKey(groupName)) {
            groupExists = true;
            actualGroupKey = groupName;
        }, {
            if (groupName.isKindOf(String)) {
                symbolKey = groupName.asSymbol;
                if (~vstManager.groups.includesKey(symbolKey)) {
                    groupExists = true;
                    actualGroupKey = symbolKey;
                };
            }, {
                if (groupName.isKindOf(Symbol)) {
                    stringKey = groupName.asString;
                    if (~vstManager.groups.includesKey(stringKey)) {
                        groupExists = true;
                        actualGroupKey = stringKey;
                    };
                };
            };
        };

        if (groupExists) {
            ~layer2.activeVSTGroup = actualGroupKey;
            instances = ~vstManager.getTargetInstances(actualGroupKey);
            ["Second Layer VST Group set to: % (% instances) (was: %)".format(
                actualGroupKey, instances.size, previousGroup ? "ALL"
            )].postln;
        }, {
            "Second Layer VST Group '%' not found, keeping current setting: %".format(
                groupName, ~layer2.activeVSTGroup ? "ALL"
            ).warn;
        };
    };
};

// Convenience functions for second layer VST targeting
~layer2UseAllVSTs = { ~layer2SetVSTGroup.("All"); };

// Reset second layer position
~layer2Reset = {
    ~layer2.noteIndex = 0;
    "Second layer note index reset to 0".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                    SECOND LAYER MIDI PARAMETER UPDATES                     │
// └─────────────────────────────────────────────────────────────────────────────┘

// Update second layer parameters from MIDI knobs (row 2)
~layer2UpdateFromMIDI = {
    // Row 2 knob positions (1-based positions, 0-based in code)
    // Knob row 2, pos 2 (CC 21) - Note Duration
    ~layer2.noteDuration = ~midiController.getKnobRow2(2).linlin(0, 1, 0.005, 1);

    // Knob row 2, pos 3 (CC 25) - Note Rest Time
    ~layer2.noteRestTime = ~midiController.getKnobRow2(3).linlin(0, 1, 0.0001, 0.4);

    // Knob row 2, pos 4 (CC 29) - Velocity
    ~layer2.velocity = ~midiController.getKnobRow2(4).linlin(0, 1, 1, 127);

    // Knob row 2, pos 5 (CC 47) - Expression Min
    ~layer2.expressionMin = ~midiController.getKnobRow2(5).linlin(0, 1, 0, 127).asInteger;

    // Knob row 2, pos 6 (CC 51) - Expression Max
    ~layer2.expressionMax = ~midiController.getKnobRow2(6).linlin(0, 1, 0, 127).asInteger;

    // Ensure max > min for expression
    if(~layer2.expressionMax <= ~layer2.expressionMin) {
        ~layer2.expressionMax = ~layer2.expressionMin + 1;
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                      SECOND LAYER CORE FUNCTIONS                           │
// └─────────────────────────────────────────────────────────────────────────────┘

// Initialize second layer for a melody
~layer2InitMelody = { |melodyKey|
    if(~melodyDict.notNil && ~melodyDict[melodyKey].notNil) {
        ~layer2.currentMelodyKey = melodyKey;
        ~layer2.pattern = ~melodyDict[melodyKey].patterns[0];

        if(~layer2.resetOnNewMelody) {
            ~layer2.noteIndex = 0;
        };

        "Layer2: initialized for melody: % (noteIndex: %)".format(
            melodyKey, ~layer2.noteIndex
        ).postln;
    }, {
        "Layer2: melody key % not found in ~melodyDict".format(melodyKey).warn;
    };
};

// Process second layer note (similar to primary ~processNote but independent)
~layer2ProcessNote = { |note, melodyKey|
    var processedNote = note;
    var velocity = ~layer2.velocity;
    var velocityMultiplier = 1.0;

    // Update MIDI parameters before processing
    ~layer2UpdateFromMIDI.value;

    // Apply note offset if enabled (using second layer's independent offset)
    if(~modes.notNil && ~modes.noteOffset) {
        processedNote = (note + ~layer2.noteOffset).clip(0, 127);
    };

    // Apply velocity multipliers if enabled (reuse primary logic)
    if(~modes.notNil && ~modes.velocityMultiply && ~melodyDict.notNil && ~melodyDict[melodyKey].notNil) {
        var isFirstNote = (~layer2.noteIndex == 0);
        var isLastNote = (~layer2.noteIndex == (~layer2.pattern.size - 1));

        if(isFirstNote) {
            velocityMultiplier = ~melodyDict[melodyKey].velocityMultipliers[\first].asFloat;
        };
        if(isLastNote) {
            velocityMultiplier = ~melodyDict[melodyKey].velocityMultipliers[\last].asFloat;
        };
        velocity = (velocity * velocityMultiplier).asInteger.clip(1, 127);
    };

    [processedNote, velocity];
};

// Play note on second layer VST instances
~layer2PlayNote = { |note, velocity|
    var targetGroup = ~layer2.activeVSTGroup;
    var instances, baseNoteDuration;
    var existingCCSynth, noteAttackTime, noteReleaseTime, newCCSynth;

    instances = ~vstManager.getTargetInstances(targetGroup);
    baseNoteDuration = ~layer2.noteDuration; // MIDI note duration & CC envelope duration base

    if(instances.size == 0) {
        "Layer2: No VST instances found for group: %".format(targetGroup ? "ALL").warn;
        ^nil;
    };

    instances.keysValuesDo { |vstName, vst, i|
        vst.midi.noteOn(0, note, velocity);

        // --- CC Envelope per note ---
        existingCCSynth = ~layer2.activeCCSynths[vstName];
        if(existingCCSynth.notNil) { existingCCSynth.free; };

        noteAttackTime = baseNoteDuration * ~layer2.expressionPeakPos;
        noteReleaseTime = baseNoteDuration * (1 - ~layer2.expressionPeakPos);

        // Ensure times are positive, with a small minimum
        noteAttackTime = noteAttackTime.max(0.001);
        noteReleaseTime = noteReleaseTime.max(0.001);

        newCCSynth = Synth(\ccEnvelope2, [
            \start, ~layer2.expressionMin,
            \peak,  ~layer2.expressionMax,
            \end,   ~layer2.expressionMin,
            \attackTime, noteAttackTime,
            \releaseTime, noteReleaseTime,
            \chanIndex, i,       // OSC chanIndex for SynthDef's SendReply
            \ccNum, 17,          // Layer 2 expression CC
            \attackCurve, \sin,  // TODO: Make configurable in ~layer2 if needed
            \releaseCurve, \sin // TODO: Make configurable in ~layer2 if needed
        ]);
        ~layer2.activeCCSynths[vstName] = newCCSynth;
        // --- End CC Envelope ---

        // Schedule note off after baseNoteDuration
        SystemClock.sched(baseNoteDuration, {
            vst.midi.noteOff(0, note, 0);
            nil;
        });
    };

    "Layer2: sent note % (vel: %) to % VSTs (duration: %s)".format(
        note, velocity, instances.size, baseNoteDuration.round(0.001)
    ).postln;
};

// Main trigger function - called via OSC when primary sequence plays first note
~layer2TriggerNote = { |melodyKey|
    var note, processedNote, firstOfPattern;

    "Layer2: trigger received for melody: %, enabled: %".format(melodyKey, ~layer2.enabled).postln;

    if(~layer2.enabled.not) { ^nil };

    // Initialise pattern if needed
    if(~layer2.currentMelodyKey != melodyKey || ~layer2.pattern.isNil) {
        ~layer2InitMelody.(melodyKey);
    };

    firstOfPattern = (~layer2.noteIndex == 0);

    // No CC envelopes – keep it simple and just play notes.
    // Per-note CC envelopes are now handled in ~layer2PlayNote

    // Play current note if pattern exists
    if(~layer2.pattern.notNil && ~layer2.noteIndex < ~layer2.pattern.size) {
        note = ~layer2.pattern[~layer2.noteIndex];
        processedNote = ~layer2ProcessNote.(note, melodyKey);
        ~layer2PlayNote.(processedNote[0], processedNote[1]);
        ~layer2.noteIndex = (~layer2.noteIndex + 1) % ~layer2.pattern.size;
    }, {
        "Layer2: no pattern available or reached end".postln;
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                    SECOND LAYER STATUS & INFORMATION                       │
// └─────────────────────────────────────────────────────────────────────────────┘

// Show second layer status
~layer2ShowStatus = {
    var targetGroup = ~layer2.activeVSTGroup ? "ALL INSTANCES";
    var instances;

    instances = ~vstManager.getTargetInstances(~layer2.activeVSTGroup);

    "".postln;
    "┌─────────────────────────────────────────────────────────────────┐".postln;
    "│                    SECOND LAYER STATUS                         │".postln;
    "└─────────────────────────────────────────────────────────────────┘".postln;
    "Enabled: %".format(~layer2.enabled).postln;
    "Current Melody: %".format(~layer2.currentMelodyKey ? "None").postln;
    "Note Index: % / %".format(
        ~layer2.noteIndex,
        if(~layer2.pattern.notNil, ~layer2.pattern.size, "N/A")
    ).postln;
    "VST Target: %".format(targetGroup).postln;
    "Active Instances: %".format(instances.size).postln;
    "Instance Names: %".format(instances.keys.asArray.sort).postln;
    "".postln;
    "Parameters:".postln;
    "  Note Duration: %s".format(~layer2.noteDuration.round(0.001)).postln;
    "  Note Rest: %s".format(~layer2.noteRestTime.round(0.001)).postln;
    "  Velocity: %".format(~layer2.velocity.round(1)).postln;
    "  Note Offset: % semitones".format(~layer2.noteOffset).postln;
    "  Expression: % - %".format(~layer2.expressionMin, ~layer2.expressionMax).postln;
    "".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                           OSC COMMUNICATION                                │
// └─────────────────────────────────────────────────────────────────────────────┘

// OSC responder for layer 2 triggers from primary layer
OSCdef(\layer2Trigger).free; // Free any existing responder
OSCdef(\layer2Trigger, { |msg, time, addr, recvPort|
    var melodyKey = msg[1].asSymbol;

    // Call the trigger function
    ~layer2TriggerNote.(melodyKey);
}, '/layer2/trigger');

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                           MIDI CONTROLS                                    │
// └─────────────────────────────────────────────────────────────────────────────┘

// Toggle second layer on/off (CC 46)
~layer2ToggleButton.free;
~layer2ToggleButton = MIDIdef.noteOn(\layer2Toggle, { |veloc, note, chan, src|
    if (note == 46 && veloc > 0) {
        // Toggle the second layer
        ~layer2SetEnabled.(~layer2.enabled.not);
        ["MIDI Note 46: Second Layer toggled to",
            if(~layer2.enabled, "ON", "OFF")].postln;
    };
}, 46);  // Note 46 for second layer toggle

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         INITIALIZATION                                     │
// └─────────────────────────────────────────────────────────────────────────────┘

// Initialize with default settings
~layer2SetEnabled.(true);  // Start enabled

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         USAGE INSTRUCTIONS                                 │
// └─────────────────────────────────────────────────────────────────────────────┘

"''
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                        SECOND LAYER - PERFORMANCE CONTROLS                   ║
║                             Triggered Layer System                           ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝

┌─────────────────────────────────────────────────────────────────────────────┐
│                         SECOND LAYER CONTROLS                              │
└─────────────────────────────────────────────────────────────────────────────┘

Enable/Disable:
  ~layer2SetEnabled.(true);            // Enable second layer
  ~layer2SetEnabled.(false);           // Disable second layer

VST Group Targeting (Independent):
~layer2SetVSTGroup.('Winds');      // Target specific group
  ~layer2SetVSTGroup.(\"All\");          // Target all instances
  ~layer2UseAllVSTs.value;             // Convenience for all instances

Control & Status:
  ~layer2Reset.value;                  // Reset note position to start
  ~layer2ShowStatus.value;             // Show detailed status

┌─────────────────────────────────────────────────────────────────────────────┐
│                           MIDI CONTROLS                                    │
└─────────────────────────────────────────────────────────────────────────────┘

Button Controls:
  CC 46: Toggle Second Layer (enable/disable)

Second Layer Controls (Row 2 Knobs):
  2: Note Duration           (0.005 - 0.5 seconds)
  3: Note Rest Time          (0.0001 - 0.4 seconds)
  4: Velocity                (1 - 127)
  5: Expression Min          (0 - 127)
  6: Expression Max          (0 - 127)
  7: Expression Duration     (10% - 100% of melody duration)

┌─────────────────────────────────────────────────────────────────────────────┐
│                         USAGE WORKFLOW                                     │
└─────────────────────────────────────────────────────────────────────────────┘

1. Load both files:
*/
//  (PathName(thisProcess.nowExecutingPath).pathOnly ++ 'surfacing.scd').load;              // Primary layer
//  (PathName(thisProcess.nowExecutingPath).pathOnly ++ 'second-layer.scd').load;         // Second layer (this file)
/*
2. Configure second layer:
   ~layer2SetEnabled.(true);           // Enable
~layer2SetVSTGroup.('Winds');     // Set VST group
~setActiveVSTGroup.('Tuba');

3. Start primary sequence:
   ~startContinuousLoopSequence.value; // Automatically triggers second layer
   ~stopContinuousLoopSequence.value; // Automatically triggers second layer

4. Monitor status:
   ~layer2ShowStatus.value;            // Check current state

┌─────────────────────────────────────────────────────────────────────────────┐
│                         COMMUNICATION                                      │
└─────────────────────────────────────────────────────────────────────────────┘

The second layer receives OSC triggers from the primary layer:
- Primary sends: '/layer2/trigger' with melody key
- Second layer plays one note and advances position
- Completely independent operation and state management
".postln;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                      SECOND LAYER CC ENVELOPE SYSTEM                       │
// └─────────────────────────────────────────────────────────────────────────────┘


// Calculate total melody duration (rough) given rest time and current pattern
~layer2CalcEnvelopeDuration = { |melodyKey|
    var pattern = ~melodyDict[melodyKey].patterns[0];
    var noteCount = pattern.size;
    ^noteCount * ~layer2.noteRestTime; // simple but sufficient
};

// Start one-shot CC envelopes (\ccEnvelope) on CC 17
~layer2StartCCEnvelopes = { |melodyKey|
    var duration, attackTime, releaseTime;

    // Refresh MIDI-controlled parameters first
    ~layer2UpdateFromMIDI.value;

    duration     = ~layer2CalcEnvelopeDuration.(melodyKey) * ~layer2.expressionDurationScalar;
    attackTime   = duration * ~layer2.expressionPeakPos;
    releaseTime  = duration - attackTime;


    ~vstManager.getTargetInstances(~layer2.activeVSTGroup).keysValuesDo { |vstKey, vst, i|
        var synth = Synth(\ccEnvelope2, [
            \start, ~layer2.expressionMin,
            \peak,  ~layer2.expressionMax,
            \end,   ~layer2.expressionMin,
            \attackTime, attackTime,
            \releaseTime, releaseTime,
            \chanIndex, i,
            \ccNum, 17,
            \attackCurve, \sin,
            \releaseCurve, \sin
        ]);
        ~layer2.activeCCSynths[vstKey] = synth;
    };
    'Layer2: CC envelopes (one-shot) started, dur %s'.format(duration.round(0.01)).postln;
};


 