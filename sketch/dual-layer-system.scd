/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                        DUAL LAYER MIDI CONTROL SYSTEM                        ║
║                          Complete Integrated Solution                        ║
║                                                                               ║
║  Features:                                                                    ║
║  • Independent Layer 1 and Layer 2 musical sequences                         ║
║  • Row 1 MIDI controls → Layer 1 parameters                                  ║
║  • Row 2 MIDI controls → Layer 2 parameters                                  ║
║  • Real-time parameter updates during playback                               ║
║  • GUI management interface                                                   ║
║  • VST group assignment per layer                                            ║
║                                                                               ║
║  Quick Start:                                                                 ║
║  1. Load this file                                                            ║
║  2. ~showDualLayerGUI.();                                                     ║
║  3. Assign VST groups to layers                                               ║
║  4. Enable dual layer mode                                                    ║
║  5. Setup Row 2 → Layer 2 mapping                                            ║
║  6. Start/stop layers as needed                                               ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

"=== DUAL LAYER MIDI CONTROL SYSTEM ===".postln;
"Loading comprehensive dual layer system...".postln;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                           LAYER 2 STATE & SETUP                            │
// └─────────────────────────────────────────────────────────────────────────────┘

// Layer 2 VST targeting
~activeVSTGroup_2 = nil;

// Layer 2 loop control variables
~currentLoopIndex_2 = 0;
~currentLoopIteration_2 = 0;
~continuousLoopTask_2 = nil;
~continuousLoopRunning_2 = false;

// Layer 2 synthesis control
~activeCCSynths_2 = Dictionary.new;
~melodyProcs_2 = Dictionary.new;
~lastNoteDuration_2 = nil;
~lastFermataNote_2 = nil;

// Layer 2 CC control parameters
~ccControl_2 = (
    enabled: true,
    expressionCC: 16,
    expressionMin: 10,
    expressionMax: 120,
    expressionShape: \sin,
    expressionPeakPos: 0.5,
    expressionDurationScalar: 1.0,
    noteDuration: 0.2,
    noteRestTime: 0.2,
    velocity: 100
);

// Layer 2 modes
~modes_2 = (
    noteOffset: false,
    fermata: false,
    melodyRestMode: true,
    pauseNotesMode: false,
    removeLast: false,
    velocityMultiply: false,
    manualLooping: true
);

// Layer 2 VST group targeting function
~setActiveVSTGroup_2 = { |groupName|
    var previousGroup, isAllInstances, groupExists, actualGroupKey, symbolKey, stringKey, instances;
    
    previousGroup = ~activeVSTGroup_2;
    isAllInstances = false;
    groupExists = false;
    actualGroupKey = nil;

    // Check for "all instances" conditions
    if (groupName.isNil) {
        isAllInstances = true;
    } {
        if (groupName.isKindOf(String) || groupName.isKindOf(Symbol)) {
            if (groupName.asString.toLower == "all") {
                isAllInstances = true;
            };
        };
    };

    if (isAllInstances) {
        ~activeVSTGroup_2 = nil;
        "Layer 2 VST Group targeting set to: ALL INSTANCES (was: %)".format(previousGroup ? "ALL").postln;
    } {
        // Check if group exists (try both Symbol and String forms)
        if (~vstManager.groups.includesKey(groupName)) {
            groupExists = true;
            actualGroupKey = groupName;
        } {
            // Try converting String to Symbol or Symbol to String
            if (groupName.isKindOf(String)) {
                symbolKey = groupName.asSymbol;
                if (~vstManager.groups.includesKey(symbolKey)) {
                    groupExists = true;
                    actualGroupKey = symbolKey;
                };
            } {
                if (groupName.isKindOf(Symbol)) {
                    stringKey = groupName.asString;
                    if (~vstManager.groups.includesKey(stringKey)) {
                        groupExists = true;
                        actualGroupKey = stringKey;
                    };
                };
            };
        };

        if (~vstManager.notNil && groupExists) {
            ~activeVSTGroup_2 = actualGroupKey;
            instances = ~vstManager.getTargetInstances(actualGroupKey);
            "Layer 2 VST Group targeting set to: % (% instances) (was: %)".format(
                actualGroupKey, instances.size, previousGroup ? "ALL"
            ).postln;
        } {
            "Layer 2 VST Group '%' not found, keeping current setting: %".format(
                groupName, ~activeVSTGroup_2 ? "ALL"
            ).warn;
        };
    };
};

// Layer setup functions
~setupLayer1 = { |groupName|
    ~setActiveVSTGroup.(groupName);
    "Layer 1 targeting VST group: %".format(~activeVSTGroup).postln;
};

~setupLayer2 = { |groupName|
    ~setActiveVSTGroup_2.(groupName);
    "Layer 2 targeting VST group: %".format(~activeVSTGroup_2).postln;
};

"✓ Layer 2 state and setup functions loaded".postln;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                        LAYER 2 CORE FUNCTIONS                              │
// └─────────────────────────────────────────────────────────────────────────────┘

// Layer 2 melody creation function
~createMelodyProc_2 = { |melodyKey, patternIndex=0|
    var pattern = ~melodyDict[melodyKey].patterns[patternIndex];
    var id = (melodyKey ++ "_" ++ patternIndex ++ "_layer2").asSymbol;
    var env = Env.asr(attackTime: 0.01, sustainLevel: 1.0, releaseTime: 0.1, curve: \lin);

    ProcMod.new(
        env,
        1.0,
        id,
        nil,
        0,
        1,

        // Main function - Layer 2 version
        { |group, envbus|
            var currentNote = pattern[0];
            var noteIndex = 0;
            var repetitionCount = 0;
            var effectiveLength = if(~modes_2.removeLast, {pattern.size - 1}, {pattern.size});
            var notePlaying = false;
            var task;
            var noteDuration = ~noteDuration;
            var noteRestTime = ~noteRest;
            var temporalAccent = 1;

            // Layer 2: Use Layer 2 parameters directly
            if(~midiController.notNil) {
                noteDuration = ~ccControl_2.noteDuration;
                noteRestTime = ~ccControl_2.noteRestTime;

                "Layer 2 - Using Layer 2 parameters: noteDuration: %, noteRestTime: %, velocity: %".format(
                    noteDuration, noteRestTime, ~ccControl_2.velocity
                ).postln;

                temporalAccent = ~midiController.getSliderValue(7).linlin(0, 1, 0, 8);
                ~melodyRestTime = ~midiController.getSliderValue(6).linlin(0, 1, 0.0, 1.0);
            };

            "Layer 2 - Starting melody: % with % notes".format(melodyKey, effectiveLength).postln;

            task = Task({
                ~repetitions.do { |repIndex|
                    noteIndex = 0;

                    while({ noteIndex < effectiveLength }) {
                        var note = pattern[noteIndex];
                        var isFirstNote = (noteIndex == 0);
                        var isLastNote = (noteIndex == (effectiveLength - 1));
                        var isFermata = isLastNote && ~modes_2.fermata && ~modes_2.melodyRestMode;
                        var actualDuration, processedNote;
                        var actualWaitTime;
                        var layer2Velocity;

                        processedNote = ~processNote.value(note, isFirstNote, isLastNote, melodyKey);

                        if(isFirstNote) {
                            actualDuration = noteDuration * 1;
                        } {
                            if(isLastNote) {
                                actualDuration = noteDuration * temporalAccent;
                            } {
                                actualDuration = noteDuration;
                            };
                        };

                        if(isLastNote) {
                            ~lastNoteDuration_2 = actualDuration;
                        };

                        if(~lastFermataNote_2.notNil) {
                            NetAddr.localAddr.sendMsg('/note/release2', ~lastFermataNote_2);
                            ~lastFermataNote_2 = nil;
                        };

                        // Use Layer 2 velocity parameter
                        layer2Velocity = ~ccControl_2.velocity;

                        "Layer 2 - Playing note: % duration: % velocity: % noteIndex: %".format(
                            processedNote[0], actualDuration, layer2Velocity, noteIndex
                        ).postln;

                        NetAddr.localAddr.sendMsg('/note/on2', 0, processedNote[0], layer2Velocity,
                            actualDuration, isFermata.asInteger,
                            isFirstNote.asInteger, isLastNote.asInteger);

                        if(isFirstNote) {
                            NetAddr.localAddr.sendMsg('/layer2/trigger', melodyKey);
                        };

                        if(isFermata) {
                            ~lastFermataNote_2 = processedNote[0];
                        };

                        actualWaitTime = noteRestTime;
                        actualWaitTime.wait;

                        noteIndex = noteIndex + 1;
                    };

                    if(repIndex < (~repetitions - 1)) {
                        (noteRestTime * 2).wait;
                    };
                };

                if(~modes_2.melodyRestMode) {
                    ~melodyRestTime.wait;

                    if(~lastFermataNote_2.notNil) {
                        NetAddr.localAddr.sendMsg('/note/release2', ~lastFermataNote_2);
                        ~lastFermataNote_2 = nil;
                    };
                };

                "Layer 2 - Melody % completed".format(melodyKey).postln;
            });

            task.play;
            task;
        },

        // Release function
        { |group, envbus|
            "Layer 2 - ProcMod for % has completed release".format(id).postln;
            ~activeNotes.clear;
        },

        // onReleaseFunc
        { |group, envbus|
            "Layer 2 - Releasing ProcMod for %".format(id).postln;
            if(~lastFermataNote_2.notNil) {
                NetAddr.localAddr.sendMsg('/note/release2', ~lastFermataNote_2);
                ~lastFermataNote_2 = nil;
            };
            ~activeNotes.keysValuesDo { |key, noteInfo|
                ~vstManager.getTargetInstances(~activeVSTGroup_2).keysValuesDo { |vstName, vst|
                    vst.midi.noteOff(0, noteInfo.note, 0);
                };
            };
            ~activeNotes.clear;
        }
    );
};

// Layer 2 continuous loop sequence function
~startContinuousLoopSequence_2 = {
    var currentLoopKey, loopCount, pattern, noteCount, currentNoteRest;
    var melodyDuration, totalWaitTime, proc, isPaused = false;
    
    if(~continuousLoopTask_2.notNil) {
        ~continuousLoopTask_2.stop;
    };

    ~currentLoopIteration_2 = 0;
    ~continuousLoopRunning_2 = true;

    "Starting Layer 2 continuous loop sequence with % melodies".format(~currentSequence.size).postln;
    "Layer 2 current melody index: % - Melody: %".format(~currentLoopIndex_2, ~currentSequence[~currentLoopIndex_2]).postln;

    ~continuousLoopTask_2 = Task({

        while({ ~continuousLoopRunning_2 }) {
            
            if(~modes_2.pauseNotesMode) {
                if(isPaused.not) {
                    "Layer 2 - PAUSED: Waiting until pause mode is disabled".postln;
                    isPaused = true;
                };
                0.1.wait;
            } {
                if(isPaused) {
                    "Layer 2 - RESUMING: Pause mode disabled, continuing playback".postln;
                    isPaused = false;
                };

                currentLoopKey = ~currentSequence[~currentLoopIndex_2];
                loopCount = ~melodyDict[currentLoopKey].loopCount ? 1;

                "Layer 2 - Playing melody: % (% of %) - iteration %".format(
                    currentLoopKey, 
                    ~currentLoopIndex_2 + 1,
                    ~currentSequence.size,
                    ~currentLoopIteration_2 + 1
                ).postln;

                pattern = ~melodyDict[currentLoopKey].patterns[0];
                noteCount = if(~modes_2.removeLast, {pattern.size - 1}, {pattern.size});

                // Layer 2: Re-read parameters on each iteration
                currentNoteRest = ~ccControl_2.noteRestTime;
                "Layer 2 - Using current noteRestTime: %".format(currentNoteRest).postln;

                if(~lastNoteDuration_2.notNil) {
                    melodyDuration = (noteCount - 1) * currentNoteRest + ~lastNoteDuration_2;
                } {
                    melodyDuration = noteCount * currentNoteRest;
                };

                totalWaitTime = melodyDuration;

                if(~modes_2.melodyRestMode) {
                    "Layer 2 - Adding melody rest of % seconds".format(~melodyRestTime).postln;
                    totalWaitTime = totalWaitTime + ~melodyRestTime;
                } {
                    "Layer 2 - No melody rest".postln;
                };

                proc = ~createMelodyProc_2.value(currentLoopKey);
                ~melodyProcs_2[currentLoopKey] = proc;

                ~startCCEnvelopes_2.value(currentLoopKey);

                proc.play;

                "Layer 2 - Waiting % seconds before next iteration".format(totalWaitTime).postln;
                totalWaitTime.wait;

                ~currentLoopIteration_2 = ~currentLoopIteration_2 + 1;

                if(~modes_2.manualLooping) {
                    "Layer 2 - Manual looping mode: staying on melody % - iteration %".format(currentLoopKey, ~currentLoopIteration_2).postln;
                } {
                    if(~currentLoopIteration_2 >= loopCount) {
                        ~currentLoopIteration_2 = 0;
                        ~currentLoopIndex_2 = (~currentLoopIndex_2 + 1) % ~currentSequence.size;
                        "Layer 2 - Auto-advancing to next melody: %".format(~currentSequence[~currentLoopIndex_2]).postln;
                    };
                };
            };
        };
    }).play;
};

// Layer 2 stop function
~stopContinuousLoopSequence_2 = {
    "Stopping Layer 2 continuous loop sequence".postln;
    ~continuousLoopRunning_2 = false;

    if(~continuousLoopTask_2.notNil) {
        ~continuousLoopTask_2.stop;
        ~continuousLoopTask_2 = nil;
    };

    ~stopAllNotes_2.value;
};

// Layer 2 stop all notes function
~stopAllNotes_2 = {
    "Layer 2 - Stopping all notes".postln;
    
    ~vstManager.getTargetInstances(~activeVSTGroup_2).do { |vst|
        5.do { |channel|
            vst.midi.allNotesOff(channel);
        };
    };

    ~activeCCSynths_2.do { |synth|
        synth.free;
    };
    ~activeCCSynths_2.clear;

    ~lastFermataNote_2 = nil;
    ~activeNotes.clear;
};

"✓ Layer 2 core functions loaded".postln;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                        MIDI ROW MAPPING SYSTEM                             │
// └─────────────────────────────────────────────────────────────────────────────┘

// Layer 2 MIDI parameter functions
~row2HandlesParameter = { |parameterName|
    var result = false;

    if (~rowMappings.notNil && ~controlTemplates.notNil) {
        var row2Mapping = ~rowMappings[2];

        if (row2Mapping.notNil && row2Mapping.enabled) {
            var template = ~controlTemplates[row2Mapping.template];

            if (template.notNil && template.knobMappings.notNil) {
                result = template.knobMappings.any { |knobMap|
                    knobMap.param == parameterName
                };
            };
        };
    };

    result;
};

// Layer 2 parameter update functions
~updateExpressionRangeFromKnobs_2 = {
    var mappingHandlesExpressionMin, mappingHandlesExpressionMax;

    mappingHandlesExpressionMin = ~row2HandlesParameter.(\expressionMin);
    mappingHandlesExpressionMax = ~row2HandlesParameter.(\expressionMax);

    if (mappingHandlesExpressionMin.not && mappingHandlesExpressionMax.not) {
        if (~midiController.notNil) {
            ~ccControl_2.expressionMin = ~midiController.getKnobRow2(5).linlin(0, 1, 0, 127).asInteger;
            ~ccControl_2.expressionMax = ~midiController.getKnobRow2(6).linlin(0, 1, 0, 127).asInteger;

            if (~ccControl_2.expressionMax <= ~ccControl_2.expressionMin) {
                ~ccControl_2.expressionMax = ~ccControl_2.expressionMin + 1;
            };
        };
    };

    if (~ccControl_2.expressionMax <= ~ccControl_2.expressionMin) {
        ~ccControl_2.expressionMax = ~ccControl_2.expressionMin + 1;
    };
};

~updateExpressionDurationScalarFromKnob_2 = {
    var mappingHandlesDurationScalar;

    mappingHandlesDurationScalar = ~row2HandlesParameter.(\expressionDurationScalar);

    if (mappingHandlesDurationScalar.not) {
        if (~midiController.notNil) {
            ~ccControl_2.expressionDurationScalar = ~midiController.getKnobRow2(3).linlin(0, 1, 0.1, 1.0);
        };
    };

    ~ccControl_2.expressionDurationScalar = ~ccControl_2.expressionDurationScalar.clip(0.1, 1.0);
};

~updateTimingParametersFromKnobs_2 = {
    var mappingHandlesNoteDuration, mappingHandlesNoteRestTime;

    mappingHandlesNoteDuration = ~row2HandlesParameter.(\noteDuration);
    mappingHandlesNoteRestTime = ~row2HandlesParameter.(\noteRestTime);

    if (mappingHandlesNoteDuration.not) {
        if (~midiController.notNil) {
            ~ccControl_2.noteDuration = ~midiController.getKnobRow2(2).linlin(0, 1, 0.005, 0.5);
        };
    };

    if (mappingHandlesNoteRestTime.not) {
        if (~midiController.notNil) {
            ~ccControl_2.noteRestTime = ~midiController.getKnobRow2(3).linlin(0, 1, 0.0001, 0.4);
        };
    };
};

~updateVelocityFromKnobs_2 = {
    var mappingHandlesVelocity;

    mappingHandlesVelocity = ~row2HandlesParameter.(\velocity);

    if (mappingHandlesVelocity.not) {
        if (~midiController.notNil) {
            ~ccControl_2.velocity = ~midiController.getKnobRow2(1).linlin(0, 1, 1, 127).asInteger;
        };
    };
};

// Layer 2 CC envelopes function
~startCCEnvelopes_2 = { |melodyKey|
    var currentActualNoteRest, duration;
    var attackTime, releaseTime;
    var scaledExpressionDuration;

    "Layer 2 - Starting CC envelopes for melody: %".format(melodyKey).postln;

    // Update all Layer 2 parameters from Row 2 MIDI controls
    ~updateExpressionRangeFromKnobs_2.value;
    ~updateExpressionDurationScalarFromKnob_2.value;
    ~updateTimingParametersFromKnobs_2.value;
    ~updateVelocityFromKnobs_2.value;

    // Use MIDI row mapping approach
    currentActualNoteRest = ~ccControl_2.noteRestTime;

    // Calculate envelope duration for Layer 2
    duration = ~calcEnvelopeDuration.value(currentActualNoteRest);
    scaledExpressionDuration = duration * ~ccControl_2.expressionDurationScalar;

    // Free any existing Layer 2 synths
    ~activeCCSynths_2.do { |synth|
        synth.free;
    };
    ~activeCCSynths_2 = Dictionary.new;

    if(~ccControl_2.enabled) {
        // Calculate timing parameters
        attackTime = scaledExpressionDuration * ~ccControl_2.expressionPeakPos;
        releaseTime = scaledExpressionDuration * (1.0 - ~ccControl_2.expressionPeakPos);

        // Create expression control synths for each VST in Layer 2 group
        ~vstManager.getTargetInstances(~activeVSTGroup_2).keysValuesDo { |vstKey, vst, i|
            var ccSynth;
            
            ccSynth = Synth(\ccEnvelope2, [
                \start, ~ccControl_2.expressionMin,
                \peak, ~ccControl_2.expressionMax,
                \end, ~ccControl_2.expressionMin,
                \attackTime, attackTime,
                \releaseTime, releaseTime,
                \chanIndex, i,
                \ccNum, ~ccControl_2.expressionCC,
                \attackCurve, ~ccControl_2.expressionShape,
                \releaseCurve, ~ccControl_2.expressionShape
            ]);

            ~activeCCSynths_2[vstKey] = ccSynth;
        };

        "Layer 2 - CC control synths started".postln;
    } {
        "Layer 2 - CC Control disabled".postln;
    };
};

// Enhanced parameter callback for dual layers
~originalUpdateGroupParameterCallback = ~updateGroupParameterCallback;

~updateGroupParameterCallback = { |vstGroup, param, value|
    // Call original callback for Layer 1
    ~originalUpdateGroupParameterCallback.(vstGroup, param, value);

    // Handle Layer 2 parameters if Row 2 is mapped
    if (~rowMappings.notNil && ~rowMappings[2].notNil && ~rowMappings[2].enabled) {
        var row2Group = ~rowMappings[2].vstGroup;

        if (vstGroup == \layer2 || (row2Group.notNil && vstGroup == row2Group)) {
            "Row 2 → Layer 2: % = %".format(param, value).postln;

            if (~ccControl_2.includesKey(param)) {
                ~ccControl_2[param] = value;

                // Handle Layer 2 validation
                if(param == \expressionMax && ~ccControl_2[\expressionMin].notNil) {
                    if(value <= ~ccControl_2[\expressionMin]) {
                        ~ccControl_2[\expressionMax] = ~ccControl_2[\expressionMin] + 1;
                    };
                };

                if(param == \expressionMin && ~ccControl_2[\expressionMax].notNil) {
                    if(~ccControl_2[\expressionMax] <= value) {
                        ~ccControl_2[\expressionMax] = value + 1;
                    };
                };
            };
        };
    };
};

// Row 2 → Layer 2 mapping setup
~setupRow2ToLayer2Mapping = {
    "Setting up Row 2 → Layer 2 parameter mapping...".postln;

    if (~rowMappings.notNil && ~midiController.notNil) {
        // Configure Row 2 to target Layer 2
        ~rowMappings[2] = (
            enabled: true,
            vstGroup: \layer2,
            template: \expressionControl
        );

        // Refresh the MIDI controller with updated mappings
        if (~refreshMIDIControllerMappings.notNil) {
            ~refreshMIDIControllerMappings.();
        };

        // Update the callback in the MIDI controller
        if (~midiController.setGroupParameterCallback.notNil) {
            ~midiController.setGroupParameterCallback(~updateGroupParameterCallback);
        };

        "✓ Row 2 → Layer 2 parameter mapping configured".postln;
    } {
        "⚠ MIDI Control Mapping system not fully available".postln;
    };
};

"✓ MIDI row mapping system loaded".postln;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                        UTILITY FUNCTIONS                                   │
// └─────────────────────────────────────────────────────────────────────────────┘

~dualLayerUtils = (
    // Get available VST groups for GUI
    getAvailableVSTGroups: {
        if (~vstManager.notNil) {
            ~vstManager.getGroupNames().asArray.sort;
        } {
            ["No VST Manager available"];
        };
    },
    
    // Setup a layer with error handling
    setupLayer: { |layerNum, vstGroupName|
        var setupFunc, activeVSTGroupVar, result = false;
        
        if (layerNum == 1) {
            setupFunc = ~setupLayer1;
            activeVSTGroupVar = \activeVSTGroup;
        } {
            setupFunc = ~setupLayer2;
            activeVSTGroupVar = \activeVSTGroup_2;
        };
        
        if (setupFunc.notNil && vstGroupName.notNil) {
            try {
                setupFunc.(vstGroupName);
                result = true;
                "✓ Layer % assigned to VST group: %".format(layerNum, vstGroupName).postln;
            } { |error|
                "✗ Failed to setup Layer %: %".format(layerNum, error.errorString).warn;
            };
        } {
            "✗ Invalid setup parameters for Layer %".format(layerNum).warn;
        };
        
        result;
    },
    
    // Start/stop layer with error handling
    controlLayer: { |layerNum, action|
        var controlFunc, runningVar, result = false;
        
        if (layerNum == 1) {
            controlFunc = if (action == \start) { ~startContinuousLoopSequence } { ~stopContinuousLoopSequence };
            runningVar = \continuousLoopRunning;
        } {
            controlFunc = if (action == \start) { ~startContinuousLoopSequence_2 } { ~stopContinuousLoopSequence_2 };
            runningVar = \continuousLoopRunning_2;
        };
        
        if (controlFunc.notNil) {
            try {
                controlFunc.();
                result = true;
                "✓ Layer % %ed".format(layerNum, action).postln;
            } { |error|
                "✗ Failed to % Layer %: %".format(action, layerNum, error.errorString).warn;
            };
        };
        
        result;
    },
    
    // Get layer status
    getLayerStatus: { |layerNum|
        var vstGroup, isRunning;
        
        if (layerNum == 1) {
            vstGroup = ~activeVSTGroup;
            isRunning = ~continuousLoopRunning ? false;
        } {
            vstGroup = ~activeVSTGroup_2;
            isRunning = ~continuousLoopRunning_2 ? false;
        };
        
        (
            vstGroup: vstGroup ? "None",
            isRunning: isRunning,
            hasVSTGroup: vstGroup.notNil
        );
    }
);

"✓ Utility functions loaded".postln;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                    SYNCHRONIZED MELODY NAVIGATION                           │
// └─────────────────────────────────────────────────────────────────────────────┘

// Synchronized melody navigation for dual layer mode
~navigateMelody = { |direction|
    var newIndex;
    
    if (~currentSequence.notNil && ~currentSequence.size > 0) {
        if (direction == \next) {
            newIndex = (~currentLoopIndex + 1) % ~currentSequence.size;
        } {
            newIndex = (~currentLoopIndex - 1).wrap(0, ~currentSequence.size - 1);
        };
        
        // Update Layer 1 index
        ~currentLoopIndex = newIndex;
        
        // Update Layer 2 index if dual layer mode is enabled
        if (~dualLayerGUIData.notNil && ~dualLayerGUIData.dualLayerMode) {
            ~currentLoopIndex_2 = newIndex;
            "Dual Layer: Both layers moved to melody % - %".format(
                newIndex + 1, ~currentSequence[newIndex]
            ).postln;
        } {
            "Layer 1 only: Moved to melody % - %".format(
                newIndex + 1, ~currentSequence[newIndex]
            ).postln;
        };
    } {
        "No melody sequence available".postln;
    };
};

// Manual navigation functions for convenience
~nextMelodyDualLayer = { ~navigateMelody.(\next); };
~prevMelodyDualLayer = { ~navigateMelody.(\prev); };

// Function to show current melody status for both layers
~showMelodyStatusDualLayer = {
    if (~currentSequence.notNil && ~currentSequence.size > 0) {
        if (~dualLayerGUIData.notNil && ~dualLayerGUIData.dualLayerMode) {
            "Dual Layer Mode - Both layers on melody: % of % - %".format(
                ~currentLoopIndex + 1, 
                ~currentSequence.size, 
                ~currentSequence[~currentLoopIndex]
            ).postln;
            "Layer 2 index: % (should match Layer 1)".format(~currentLoopIndex_2 + 1).postln;
        } {
            "Single Layer Mode - Layer 1 on melody: % of % - %".format(
                ~currentLoopIndex + 1, 
                ~currentSequence.size, 
                ~currentSequence[~currentLoopIndex]
            ).postln;
            "Layer 2 index: % (independent)".format(~currentLoopIndex_2 + 1).postln;
        };
        "Use MIDI Note 22 (Previous) / 27 (Next) to navigate".postln;
    } {
        "No melody sequence available".postln;
    };
};

"✓ Synchronized melody navigation loaded".postln;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                        LAYER 2 OSC RESPONDERS                              │
// └─────────────────────────────────────────────────────────────────────────────┘

// Clean up any existing Layer 2 OSC responders
OSCdef(\noteOnLayer2).free;
OSCdef(\releaseFermataLayer2).free;

// OSC responder for Layer 2 note events
OSCdef(\noteOnLayer2, { |msg, time, addr, recvPort|
    var channel = msg[1].asInteger;
    var note = msg[2].asInteger;
    var velocity = msg[3].asInteger;
    var duration = msg[4].asFloat;
    var isFermata = msg[5].asInteger == 1;
    var isFirstNote = msg[6].asInteger == 1;
    var isLastNote = msg[7].asInteger == 1;

    // Apply note offset if mode is enabled (Layer 2)
    if(~modes_2.noteOffset) {
        note = (note + ~noteOffset).clip(0, 1);
    };

    "[Layer2] OSC Received: channel:% note:% vel:% dur:% fermata:% first:% last:%".format(
        channel, note, velocity, duration, isFermata, isFirstNote, isLastNote
    ).postln;

    // Play note on Layer 2 VST instances
    ~vstManager.getTargetInstances(~activeVSTGroup_2).keysValuesDo { |vstName, vst|
        "[Layer2] Playing on VST: %".format(vstName).postln;
        vst.midi.noteOn(0, note, velocity);

        // Schedule note off if duration is provided
        if(duration.notNil) {
            SystemClock.sched(duration, {
                vst.midi.noteOff(0, note, 0);
                nil;
            });
        };
    };
}, '/note/on2');

// OSC responder for Layer 2 fermata release
OSCdef(\releaseFermataLayer2, { |msg, time, addr, recvPort|
    var note = msg[1].asInteger;
    var instances = ~vstManager.getTargetInstances(~activeVSTGroup_2);

    "[Layer2] Releasing fermata note: %".format(note).postln;

    instances.keysValuesDo { |vstName, vst|
        vst.midi.noteOff(0, note, 0);
        "[Layer2] Released note: % on VST: %".format(note, vstName).postln;
    };
}, '/note/release2');

"✓ Layer 2 OSC responders loaded".postln;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                           GUI MANAGEMENT                                   │
// └─────────────────────────────────────────────────────────────────────────────┘

~dualLayerGUI = nil;
~dualLayerGUIData = (
    layer1Group: nil,
    layer2Group: nil,
    dualLayerMode: false,
    row2MappingEnabled: false
);

~createDualLayerGUI = {
    var window, layout;
    var layer1GroupMenu, layer2GroupMenu;
    var dualLayerToggle, row2MappingButton;
    var layer1StartButton, layer1StopButton;
    var layer2StartButton, layer2StopButton;
    var statusText;
    var availableGroups;
    
    // Close existing GUI if open
    if (~dualLayerGUI.notNil) {
        ~dualLayerGUI.close;
    };
    
    // Get available VST groups
    availableGroups = ~dualLayerUtils[\getAvailableVSTGroups].();
    
    // Create main window
    window = Window("Dual Layer Control", Rect(100, 100, 400, 300));
    window.background = Color.gray(0.9);
    
    // Create layout
    layout = VLayout(
        // Title
        StaticText().string_("Dual Layer MIDI Control System").font_(Font.default.size_(16)).align_(\center),
        
        // VST Group Assignment Section
        HLayout(
            VLayout(
                StaticText().string_("Layer 1 VST Group:").font_(Font.default.size_(12)),
                layer1GroupMenu = PopUpMenu().items_(["None"] ++ availableGroups)
                    .action_({ |menu|
                        var selectedGroup = if (menu.value == 0) { nil } { availableGroups[menu.value - 1] };
                        ~dualLayerGUIData.layer1Group = selectedGroup;
                        if (selectedGroup.notNil) {
                            ~dualLayerUtils[\setupLayer].(1, selectedGroup);
                        };
                        ~updateGUIStatus.();
                    })
            ),
            VLayout(
                StaticText().string_("Layer 2 VST Group:").font_(Font.default.size_(12)),
                layer2GroupMenu = PopUpMenu().items_(["None"] ++ availableGroups)
                    .action_({ |menu|
                        var selectedGroup = if (menu.value == 0) { nil } { availableGroups[menu.value - 1] };
                        ~dualLayerGUIData.layer2Group = selectedGroup;
                        if (selectedGroup.notNil) {
                            ~dualLayerUtils[\setupLayer].(2, selectedGroup);
                        };
                        ~updateGUIStatus.();
                    })
            )
        ),
        
        // Configuration Section
        VLayout(
            dualLayerToggle = CheckBox().string_("Enable Dual Layer Mode")
                .action_({ |checkbox|
                    ~dualLayerGUIData.dualLayerMode = checkbox.value;
                    ~updateGUIStatus.();
                }),
            
            row2MappingButton = Button().string_("Setup Row 2 → Layer 2 Mapping")
                .action_({
                    ~setupRow2ToLayer2Mapping.();
                    ~dualLayerGUIData.row2MappingEnabled = true;
                    ~updateGUIStatus.();
                })
        ),
        
        // Transport Controls Section
        StaticText().string_("Transport Controls").font_(Font.default.size_(14)).align_(\center),
        
        HLayout(
            VLayout(
                StaticText().string_("Layer 1:").align_(\center),
                HLayout(
                    layer1StartButton = Button().string_("Start")
                        .action_({
                            ~dualLayerUtils[\controlLayer].(1, \start);
                            ~updateGUIStatus.();
                        }),
                    layer1StopButton = Button().string_("Stop")
                        .action_({
                            ~dualLayerUtils[\controlLayer].(1, \stop);
                            ~updateGUIStatus.();
                        })
                )
            ),
            VLayout(
                StaticText().string_("Layer 2:").align_(\center),
                HLayout(
                    layer2StartButton = Button().string_("Start")
                        .action_({
                            ~dualLayerUtils[\controlLayer].(2, \start);
                            ~updateGUIStatus.();
                        }),
                    layer2StopButton = Button().string_("Stop")
                        .action_({
                            ~dualLayerUtils[\controlLayer].(2, \stop);
                            ~updateGUIStatus.();
                        })
                )
            )
        ),
        
        // Status Section
        StaticText().string_("Status").font_(Font.default.size_(14)).align_(\center),
        statusText = StaticText().string_("Ready").font_(Font.default.size_(10))
            .background_(Color.white).align_(\left)
    );
    
    // Store GUI elements for updates
    ~dualLayerGUIElements = (
        window: window,
        layer1GroupMenu: layer1GroupMenu,
        layer2GroupMenu: layer2GroupMenu,
        dualLayerToggle: dualLayerToggle,
        row2MappingButton: row2MappingButton,
        layer1StartButton: layer1StartButton,
        layer1StopButton: layer1StopButton,
        layer2StartButton: layer2StartButton,
        layer2StopButton: layer2StopButton,
        statusText: statusText
    );
    
    // Update GUI status function
    ~updateGUIStatus = {
        var layer1Status, layer2Status, statusString;
        
        if (~dualLayerGUIElements.notNil) {
            layer1Status = ~dualLayerUtils[\getLayerStatus].(1);
            layer2Status = ~dualLayerUtils[\getLayerStatus].(2);
            
            // Update button states
            ~dualLayerGUIElements.layer1StartButton.enabled_(layer1Status.hasVSTGroup && layer1Status.isRunning.not);
            ~dualLayerGUIElements.layer1StopButton.enabled_(layer1Status.isRunning);
            
            if (~dualLayerGUIData.dualLayerMode) {
                ~dualLayerGUIElements.layer2StartButton.enabled_(layer2Status.hasVSTGroup && layer2Status.isRunning.not);
                ~dualLayerGUIElements.layer2StopButton.enabled_(layer2Status.isRunning);
            } {
                ~dualLayerGUIElements.layer2StartButton.enabled_(false);
                ~dualLayerGUIElements.layer2StopButton.enabled_(false);
            };
            
            // Update status text
            statusString = "Layer 1: % (%) | Layer 2: % (%) | Row 2 Mapping: %".format(
                layer1Status.vstGroup,
                if (layer1Status.isRunning) { "Running" } { "Stopped" },
                layer2Status.vstGroup,
                if (layer2Status.isRunning) { "Running" } { "Stopped" },
                if (~dualLayerGUIData.row2MappingEnabled) { "Enabled" } { "Disabled" }
            );
            
            ~dualLayerGUIElements.statusText.string_(statusString);
        };
    };
    
    // Set window layout and show
    window.layout_(layout);
    window.onClose_({
        ~dualLayerGUI = nil;
        ~dualLayerGUIElements = nil;
    });
    
    // Initial status update
    ~updateGUIStatus.();
    
    window.front;
    ~dualLayerGUI = window;
    
    "✓ Dual Layer GUI created".postln;
};

// Convenience functions for GUI management
~showDualLayerGUI = { ~createDualLayerGUI.(); };
~closeDualLayerGUI = { 
    if (~dualLayerGUI.notNil) { 
        ~dualLayerGUI.close; 
        "✓ Dual Layer GUI closed".postln;
    }; 
};

"✓ GUI management system loaded".postln;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                        AUTO-INITIALIZATION                                 │
// └─────────────────────────────────────────────────────────────────────────────┘

// Auto-setup Row 2 → Layer 2 mapping
~setupRow2ToLayer2Mapping.();

// Status and usage information
"".postln;
"╔═══════════════════════════════════════════════════════════════════════════════╗".postln;
"║                    DUAL LAYER SYSTEM READY                                   ║".postln;
"╚═══════════════════════════════════════════════════════════════════════════════╝".postln;
"".postln;
"Quick Start:".postln;
"  ~showDualLayerGUI.();     // Open control interface".postln;
"".postln;
"Manual Control:".postln;
"  ~setupLayer1.(\"GroupName\");     // Assign Layer 1 to VST group".postln;
"  ~setupLayer2.(\"GroupName\");     // Assign Layer 2 to VST group".postln;
"  ~startContinuousLoopSequence.();     // Start Layer 1".postln;
"  ~startContinuousLoopSequence_2.();   // Start Layer 2".postln;
"  ~stopContinuousLoopSequence.();      // Stop Layer 1".postln;
"  ~stopContinuousLoopSequence_2.();    // Stop Layer 2".postln;
"".postln;
"Features:".postln;
"  • Row 1 MIDI controls → Layer 1 parameters".postln;
"  • Row 2 MIDI controls → Layer 2 parameters".postln;
"  • Independent VST group targeting per layer".postln;
"  • Real-time parameter updates during playback".postln;
"  • GUI-driven workflow with status monitoring".postln;
"".postln; 