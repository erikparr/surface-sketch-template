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

// Main container for OSC-based layer system
~oscLayers = (
    // System state
    state: (
        totalDuration: 0,
        startTime: nil,
        loopingMode: false,
        manualControl: false,
        singleNoteCCMode: false,
        bendMode: false,
        isRunning: false,
        noteDurationScalar: 1.0,
        melodyRestTime: 0.0,  // Rest duration between loops (0-1 seconds)
        chordMode: false,  // Enable chord mode (play melody notes as simultaneous chords)
        pendingUpdates: Dictionary.new,  // Live melody updates (always active)
        // Global melody navigation
        currentMelodyIndex: 0,
        melodyList: [],  // Array of melody keys from loaded file
        // Simplified - no timing state needed
    ),

    // Layer configurations (preserved from original system)
    configs: (
        layer1: (
            melodyList: [],
            assignedLayerId: \layer1,  // Which layer data to use from current melody
            vstGroup: 'Layer1',
            enabled: true,
            duration: 0,
            noteDurationScalar: 1.0,
            // Independent playback state
            isPlaying: false,
            currentTask: nil,
            defaultDuration: 4.0,
            ccControl: (
                enabled: true,
                expressionCC: 11,
                expressionMin: 10,
                expressionMax: 120,
                expressionShape: \sin,
                expressionPeakPos: 0.5,
                expressionDurationScalar: 1.0
            ),
            windowing: (
                enabled: false,
                windowSize: 5,
                overlapTriggerIndex: 2,
                stepSize: 1,
                melodyDurationScalar: 1.0
            ),
            bendControl: (
                enabled: true,
                bendAmount: 0.0,
                peakTimeRatio: 0.5,
                returnTimeRatio: 0.5,
                simpleRamp: false,
                activeBendSynths: Dictionary.new
            )
        ),
        layer2: (
            melodyList: [],
            assignedLayerId: \layer2,  // Which layer data to use from current melody
            vstGroup: 'Layer2',
            enabled: true,
            duration: 0,
            noteDurationScalar: 1.0,
            // Independent playback state
            isPlaying: false,
            currentTask: nil,
            defaultDuration: 4.0,
            ccControl: (
                enabled: true,
                expressionCC: 12,
                expressionMin: 10,
                expressionMax: 120,
                expressionShape: \sin,
                expressionPeakPos: 0.5,
                expressionDurationScalar: 1.0
            ),
            windowing: (
                enabled: false,
                windowSize: 5,
                overlapTriggerIndex: 2,
                stepSize: 1,
                melodyDurationScalar: 1.0
            ),
            bendControl: (
                enabled: true,
                bendAmount: 0.0,
                peakTimeRatio: 0.5,
                returnTimeRatio: 0.5,
                simpleRamp: false,
                activeBendSynths: Dictionary.new
            )
        ),
        layer3: (
            melodyList: [],
            assignedLayerId: \layer3,  // Which layer data to use from current melody
            vstGroup: 'Layer3',
            enabled: true,
            duration: 0,
            noteDurationScalar: 1.0,
            // Independent playback state
            isPlaying: false,
            currentTask: nil,
            defaultDuration: 4.0,
            ccControl: (
                enabled: true,
                expressionCC: 13,
                expressionMin: 10,
                expressionMax: 120,
                expressionShape: \sin,
                expressionPeakPos: 0.5,
                expressionDurationScalar: 1.0
            ),
            windowing: (
                enabled: false,
                windowSize: 5,
                overlapTriggerIndex: 2,
                stepSize: 1,
                melodyDurationScalar: 1.0
            ),
            bendControl: (
                enabled: true,
                bendAmount: 0.0,
                peakTimeRatio: 0.5,
                returnTimeRatio: 0.5,
                simpleRamp: false,
                activeBendSynths: Dictionary.new
            )
        )
    ),

    // OSC responders for each layer
    responders: Dictionary.new,

    // Layer coordinator (timing controller)
    coordinator: nil
);

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                       LAYER OSC RESPONDERS                                 │
// └─────────────────────────────────────────────────────────────────────────────┘

// Create OSC responders for a single layer
~createLayerOSCResponders = {|layerKey|
    var layerNum = layerKey.asString.last.asString.asInteger;
    var config = ~oscLayers.configs[layerKey];
    var responders = [];

    "Creating OSC responders for %".format(layerKey).postln;

    // Individual note control: /layer1/note, /layer2/note, /layer3/note
    responders = responders.add(
        OSCFunc({|msg|
            var note = msg[1];
            var velocity = msg[2] ? 127;
            var duration = msg[3] ? 0.5;

            // "OSC: Layer % note % vel % dur %".format(layerNum, note, velocity, duration).postln;

            // Send to VST - single note to all VSTs on channel 0
            if (~vstManager.notNil) {
                var instances = ~vstManager.getTargetInstances(config.vstGroup);
                instances.do { |vst|
                    vst.midi.noteOn(0, note, velocity);
                    if (duration > 0) {
                        SystemClock.sched(duration, {
                            vst.midi.noteOff(0, note, 0);
                        });
                    };
                };
            };

            // Trigger CC envelope if single note mode
            if (~oscLayers.state.singleNoteCCMode and: { config.ccControl.enabled }) {
                NetAddr.localAddr.sendMsg('/layer' ++ layerNum ++ '/expression', duration);
            };

            // Trigger bend envelope if bend mode
            if (~oscLayers.state.bendMode and: { config.bendControl.enabled }) {
                NetAddr.localAddr.sendMsg('/layer' ++ layerNum ++ '/bend', duration);
            };

        }, '/layer' ++ layerNum ++ '/note')
    );

    // Chord control: /layer1/chord, /layer2/chord, /layer3/chord
    responders = responders.add(
        OSCFunc({|msg|
            var notes = [];
            var velocity, duration, argIndex;

            // Parse variable number of note arguments (1-3 notes)
            // msg format: [path, note1, note2?, note3?, velocity, duration]
            argIndex = 1;
            while { argIndex < (msg.size - 2) and: { msg[argIndex].isNumber and: { msg[argIndex] >= 0 and: { msg[argIndex] <= 127 } } } } {
                notes = notes.add(msg[argIndex].asInteger);
                argIndex = argIndex + 1;
            };

            // Last two arguments are velocity and duration
            velocity = msg[msg.size - 2].asInteger ? 127;
            duration = msg[msg.size - 1].asFloat ? 0.5;

            "OSC: Layer % chord % notes: % vel: % dur: %".format(layerNum, notes.size, notes, velocity, duration).postln;

            // Send to VST with multi-instrument routing (across layer groups)
            if (~vstManager.notNil) {
                var layerGroups = ['Layer1', 'Layer2', 'Layer3'];

                notes.do { |note, idx|
                    var targetGroup = layerGroups[idx % layerGroups.size];
                    var instances = ~vstManager.getTargetInstances(targetGroup);
                    var vst = instances.values.asArray.first;  // Get first (and likely only) VST in group

                    if (vst.notNil) {
                        vst.midi.noteOn(idx, note, velocity);  // Use idx as channel
                        "Chord note %: pitch % chan % vel % to group % VST %".format(
                            idx, note, idx, velocity, targetGroup, instances.keys.asArray.first
                        ).postln;
                        if (duration > 0) {
                            SystemClock.sched(duration, {
                                vst.midi.noteOff(idx, note, 0);
                            });
                        };
                    };
                };
            };

            // Trigger CC envelope
            if (~oscLayers.state.singleNoteCCMode) {
                // Single note mode: only trigger for this layer
                if (config.ccControl.enabled) {
                    NetAddr.localAddr.sendMsg('/layer' ++ layerNum ++ '/expression', duration);
                };
            } {
                // Layer-wide mode: in chord mode, trigger for all layers receiving notes
                [1, 2, 3].do { |layerIdx|
                    var layerConfig = ~oscLayers.configs[('layer' ++ layerIdx).asSymbol];
                    if (layerConfig.ccControl.enabled) {
                        NetAddr.localAddr.sendMsg('/layer' ++ layerIdx ++ '/expression', duration);
                    };
                };
            };

            // Trigger bend envelope if bend mode
            if (~oscLayers.state.bendMode) {
                // In chord mode, trigger bend for all layers receiving notes
                [1, 2, 3].do { |layerIdx|
                    var layerConfig = ~oscLayers.configs[('layer' ++ layerIdx).asSymbol];
                    if (layerConfig.bendControl.enabled) {
                        NetAddr.localAddr.sendMsg('/layer' ++ layerIdx ++ '/bend', duration);
                    };
                };
            };

        }, '/layer' ++ layerNum ++ '/chord')
    );

    // CC control: /layer1/cc, /layer2/cc, /layer3/cc
    responders = responders.add(
        OSCFunc({|msg|
            var ccNum = msg[1];
            var value = msg[2];

            if (~vstManager.notNil) {
                var instances = ~vstManager.getTargetInstances(config.vstGroup);
                instances.do { |vst|
                    vst.midi.control(0, ccNum, value);
                };
            };
        }, '/layer' ++ layerNum ++ '/cc')
    );

    // Expression envelope: /layer1/expression, /layer2/expression, /layer3/expression
    responders = responders.add(
        OSCFunc({|msg|
            var duration = msg[1] ? 1.0;
            var synthName = ('ccEnvelope' ++ layerNum).asSymbol;
            var ccControl = config.ccControl;

            if (ccControl.enabled) {
                var scaledDuration = duration * ccControl.expressionDurationScalar;
                var attackTime = scaledDuration * ccControl.expressionPeakPos;
                var releaseTime = scaledDuration * (1.0 - ccControl.expressionPeakPos);

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
        }, '/layer' ++ layerNum ++ '/expression')
    );

    // Bend envelope: /layer1/bend, /layer2/bend, /layer3/bend
    responders = responders.add(
        OSCFunc({|msg|
            var duration = msg[1] ? 1.0;
            var bendControl = config.bendControl;

            if (bendControl.enabled and: { ~getLayerBendAmount.notNil }) {
                var bendAmount = ~getLayerBendAmount.();
                var peakTime = ~getLayerBendPeakTime.();
                var simpleRamp = ~getLayerBendSimpleRamp.();
                var bendCenter = 8192;  // MIDI pitch bend center
                var bendRangeRaw, peakValue;

                // FIXED: Convert octave range (-1 to +1) to MIDI offset and apply to center
                bendRangeRaw = (bendAmount * 8191).round.asInteger;  // Max range ±8191
                peakValue = (bendCenter + bendRangeRaw).clip(0, 16383);

                // Clean up existing bend synths for this layer
                bendControl.activeBendSynths.do(_.free);
                bendControl.activeBendSynths.clear;

                // NEW: Create one bend synth per VST in this layer's group
                if (~vstManager.notNil) {
                    ~vstManager.getTargetInstances(config.vstGroup).keysValuesDo { |vstKey, vst, vstIndex|
                        var layerReplyID = (layerNum * 100) + vstIndex;  // Layer-encoded ID
                        var bendSynth;

                        if (simpleRamp) {
                            bendSynth = Synth(\BendEnvelopeSimple, [
                                \start, bendCenter,       // MIDI center (8192)
                                \end, peakValue,          // MIDI converted value
                                \duration, duration,
                                \chanIndex, vstIndex,
                                \customReplyID, layerReplyID
                            ]);
                        } {
                            bendSynth = Synth(\BendEnvelope, [
                                \start, bendCenter,       // MIDI center (8192)
                                \peak, peakValue,         // MIDI converted value
                                \end, bendCenter,         // MIDI center (8192)
                                \peakTime, duration * peakTime,
                                \returnTime, duration * (1.0 - peakTime),
                                \chanIndex, vstIndex,
                                \customReplyID, layerReplyID  // Layer-encoded replyID
                            ]);
                        };

                        // Store synth for cleanup
                        bendControl.activeBendSynths[vstKey] = bendSynth;
                    };

                    "Layer % bend: Created % synths for group % (amount: % octaves → MIDI: %)".format(
                        layerKey, bendControl.activeBendSynths.size, config.vstGroup,
                        bendAmount.round(0.01), peakValue
                    ).postln;
                };
            };
        }, '/layer' ++ layerNum ++ '/bend')
    );

    // Melody change: /layer1/melody, /layer2/melody, /layer3/melody
    responders = responders.add(
        OSCFunc({|msg|
            var melodyKey = msg[1].asSymbol;
            if (~setLayerMelody.notNil) {
                ~setLayerMelody.(layerKey, melodyKey);
            } {
                // Fallback: set melody directly in OSC config
                config.melodyList = [melodyKey];
                "Layer % melody set to: % (OSC direct)".format(layerKey, melodyKey).postln;
            };
        }, '/layer' ++ layerNum ++ '/melody')
    );

    // Configuration changes: /layer1/enabled, /layer2/enabled, /layer3/enabled
    responders = responders.add(
        OSCFunc({|msg|
            var enabled = msg[1].asBoolean;
            config.enabled = enabled;
            "Layer % enabled: %".format(layerKey, enabled).postln;
        }, '/layer' ++ layerNum ++ '/enabled')
    );

    // Store responders
    ~oscLayers.responders[layerKey] = responders;

    "Created % OSC responders for %".format(responders.size, layerKey).postln;
    responders;
};

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

    // Chord mode control: /system/chord_mode
    responders = responders.add(
        OSCFunc({|msg|
            var enabled = msg[1].asBoolean;
            ~oscLayers.state.chordMode = enabled;
            "OSC: Chord mode: % (BPM range: %)".format(
                enabled,
                if (enabled) { "6-100" } { "60-400" }
            ).postln;
        }, '/system/chord_mode')
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

    // Get velocity
    velocity = if (~oscLayers.state.manualControl and: { ~midiController.notNil }) {
        ~midiController.getKnobRow1(3).linlin(0, 127, 1, 127).asInteger;
    } {
        127; // Default velocity
    };

    // Send melody via OSC messages with timing
    if (~oscLayers.state.chordMode) {
        // Chord mode: Play first 3 notes simultaneously
        var chord = pattern[..2];  // Take first 3 notes (or fewer if pattern is shorter)
        var noteDuration = (duration * 0.8) * config.noteDurationScalar;

        "Chord mode: Playing % notes as chord: %".format(chord.size, chord).postln;

        // Send chord via dedicated /chord path with notes as separate arguments
        case
            { chord.size == 1 } {
                NetAddr.localAddr.sendMsg('/layer' ++ layerNum ++ '/chord', chord[0], velocity, noteDuration);
            }
            { chord.size == 2 } {
                NetAddr.localAddr.sendMsg('/layer' ++ layerNum ++ '/chord', chord[0], chord[1], velocity, noteDuration);
            }
            { chord.size >= 3 } {
                NetAddr.localAddr.sendMsg('/layer' ++ layerNum ++ '/chord', chord[0], chord[1], chord[2], velocity, noteDuration);
            };
    } {
        // Normal melody mode: Sequential playback
        pattern.do {|note, i|
            var when = i * noteInterval;
            var noteDuration = (noteInterval * 0.8) * config.noteDurationScalar; // Apply scalar from Row X Knob 2

            SystemClock.sched(when, {
                NetAddr.localAddr.sendMsg('/layer' ++ layerNum ++ '/note', note, velocity, noteDuration);
            });
        };
    };

    // Trigger layer expression envelope if not in single note mode
    if (~oscLayers.state.singleNoteCCMode.not and: { config.ccControl.enabled }) {
        NetAddr.localAddr.sendMsg('/layer' ++ layerNum ++ '/expression', duration);
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                    INDEPENDENT LAYER PLAYBACK                              │
// └─────────────────────────────────────────────────────────────────────────────┘

// Start a single layer with independent looping (or one-shot)
~startLayerIndependent = {|layerKey, duration = nil, loop = true|
    var config = ~oscLayers.configs[layerKey];
    var melodyData, playDuration, loopTask;
    var isPlayingVar, taskVar;

    // Get the correct global variables based on layer
    case
        { layerKey == \layer1 } {
            isPlayingVar = \layer1_isPlaying;
            taskVar = \layer1_currentTask;
        }
        { layerKey == \layer2 } {
            isPlayingVar = \layer2_isPlaying;
            taskVar = \layer2_currentTask;
        }
        { layerKey == \layer3 } {
            isPlayingVar = \layer3_isPlaying;
            taskVar = \layer3_currentTask;
        };

    // Stop existing playback for this layer if running
    if (currentEnvironment[taskVar].notNil) {
        currentEnvironment[taskVar].stop;
        currentEnvironment[taskVar] = nil;
    };

    // Determine duration
    playDuration = case
        { duration.notNil } { duration }                    // Explicit parameter (highest priority)
        { ~oscLayers.state.manualControl and: { ~getBPMFromKnob.notNil } } {
            var bpm = ~getBPMFromKnob.();
            var noteCount = ~getMelodyNoteCount.(layerKey);
            ~calculateDurationFromBPM.(bpm, noteCount)      // BPM-based calculation
        }
        { config.defaultDuration };                         // Default

    "Starting % independently with duration: %s (loop: %)".format(layerKey, playDuration, loop).postln;

    // Set playing state
    currentEnvironment[isPlayingVar] = true;

    // Create independent playback task (looping or one-shot)
    loopTask = Task({
        var loopCount = 0;
        var currentDuration;

        while { currentEnvironment[isPlayingVar] } {
            loopCount = loopCount + 1;

            // Update duration from MIDI if in manual control mode
            currentDuration = if (~oscLayers.state.manualControl and: { ~getBPMFromKnob.notNil }) {
                var bpm = ~getBPMFromKnob.();
                var noteCount = ~getMelodyNoteCount.(layerKey);
                ~calculateDurationFromBPM.(bpm, noteCount)
            } { playDuration };

            // Update expression parameters from MIDI
            if (~updateLayerExpressionParams.notNil) {
                if (~oscLayers.state.chordMode) {
                    // Chord mode: update all layers (they all receive expression)
                    [\layer1, \layer2, \layer3].do { |lKey|
                        ~updateLayerExpressionParams.(lKey);
                    };
                } {
                    // Normal mode: only this layer
                    ~updateLayerExpressionParams.(layerKey);
                };
            };

            // Update note duration scalar from MIDI
            if (~updateLayerNoteDurationScalar.notNil) {
                ~updateLayerNoteDurationScalar.(layerKey);
            };

            // Play the layer
            if (loop) {
                "% loop %: duration %s".format(layerKey, loopCount, currentDuration).postln;
            } {
                "% playing once: duration %s".format(layerKey, currentDuration).postln;
            };
            ~startOSCLayer.(layerKey, currentDuration);

            // Wait for completion
            currentDuration.wait;

            // If one-shot mode, stop after first play
            if (loop.not) {
                var layerNumber = layerKey.asString.last.asString.asInteger;

                currentEnvironment[isPlayingVar] = false;

                // Send OSC completion message to external app
                NetAddr("127.0.0.1", 7001).sendMsg('/liveMelody/complete', layerNumber);
                "Sent completion message for % to port 7001".format(layerKey).postln;
            } {
                // Add melody rest if configured (loop mode only)
                if (~oscLayers.state.melodyRestTime > 0) {
                    ~oscLayers.state.melodyRestTime.wait;
                };
            };
        };

        "% playback stopped".format(layerKey).postln;
    });

    // Store and start task
    currentEnvironment[taskVar] = loopTask;
    loopTask.play;

    layerKey;  // Return layer key
};

// Stop a single layer's independent playback
~stopLayerIndependent = {|layerKey|
    var isPlayingVar, taskVar;

    // Get the correct global variables based on layer
    case
        { layerKey == \layer1 } {
            isPlayingVar = \layer1_isPlaying;
            taskVar = \layer1_currentTask;
        }
        { layerKey == \layer2 } {
            isPlayingVar = \layer2_isPlaying;
            taskVar = \layer2_currentTask;
        }
        { layerKey == \layer3 } {
            isPlayingVar = \layer3_isPlaying;
            taskVar = \layer3_currentTask;
        };

    if (currentEnvironment[taskVar].notNil) {
        currentEnvironment[isPlayingVar] = false;
        currentEnvironment[taskVar].stop;
        currentEnvironment[taskVar] = nil;
        "Stopped % independently".format(layerKey).postln;
    } {
        "% is not playing".format(layerKey).postln;
    };

    layerKey;
};

// Check if any layer is playing independently
~anyLayerPlaying = {
    ~layer1_isPlaying or: { ~layer2_isPlaying } or: { ~layer3_isPlaying }
};

// Get status of all layers
~getLayersPlaybackStatus = {
    var status = ();
    var config;

    config = ~oscLayers.configs[\layer1];
    status[\layer1] = (
        isPlaying: ~layer1_isPlaying,
        hasMelody: config.melodyList.size > 0,
        enabled: config.enabled,
        defaultDuration: config.defaultDuration
    );

    config = ~oscLayers.configs[\layer2];
    status[\layer2] = (
        isPlaying: ~layer2_isPlaying,
        hasMelody: config.melodyList.size > 0,
        enabled: config.enabled,
        defaultDuration: config.defaultDuration
    );

    config = ~oscLayers.configs[\layer3];
    status[\layer3] = (
        isPlaying: ~layer3_isPlaying,
        hasMelody: config.melodyList.size > 0,
        enabled: config.enabled,
        defaultDuration: config.defaultDuration
    );

    status
};

// Stop all independent layers
~stopAllLayersIndependent = {
    [\layer1, \layer2, \layer3].do {|layerKey|
        ~stopLayerIndependent.(layerKey);
    };
    "Stopped all independent layer playback".postln;
};

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
~updateLayerNoteDurationScalar = { |layerKey|
    var rowNum, config;

    // Map layer to row number
    case
        { layerKey == \layer1 } { rowNum = 1 }
        { layerKey == \layer2 } { rowNum = 2 }
        { layerKey == \layer3 } { rowNum = 3 };

    config = ~oscLayers.configs[layerKey];

    if (~midiController.notNil && config.notNil && rowNum.notNil) {
        var knobValue = ~midiController.getKnobRow(rowNum, 2);
        config.noteDurationScalar = knobValue.linlin(0, 127, 0.01, 1.0);

        // Debug output when manual control is enabled
        if (~oscLayers.state.manualControl) {
            "% note duration scalar: %% (Row % Knob 2)".format(
                layerKey,
                (config.noteDurationScalar * 100).round(1),
                rowNum
            ).postln;
        };
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                    MIDI TEMPLATE PROCESSING & EXPRESSION CONTROL           │
// └─────────────────────────────────────────────────────────────────────────────┘

// Update expression parameters for all layers from MIDI knobs
~updateAllLayerExpressionParams = {
    [\layer1, \layer2, \layer3].do { |layerKey, index|
        var rowNum = index + 1; // layer1=row1, layer2=row2, layer3=row3
        var config = ~oscLayers.configs[layerKey];
        var foundInTemplate = false;

        if (config.notNil && config.ccControl.notNil) {

            // PHASE 1: Try to get values from template system
            if (~processTemplateKnobValues.notNil and: { ~rowMappings.notNil }) {
                // First, update all template parameter storage
                ~processTemplateKnobValues.();

                // Check if current row has template mappings for expression parameters
                ~rowMappings.keysValuesDo { |templateRowNum, mapping|
                    if (mapping.enabled and: { templateRowNum == rowNum and: { foundInTemplate.not } }) {
                        var template = ~controlTemplates[mapping.template];
                        var paramStorage = ~getGroupParams.(mapping.vstGroup);

                        if (template.notNil and: { paramStorage.notNil }) {
                            var hasExpressionMin = false;
                            var hasExpressionMax = false;
                            var hasExpressionDur = false;

                            // Check what expression parameters this template handles
                            template.knobMappings.do { |knobMap|
                                switch(knobMap.param,
                                    \expressionMin, {
                                        hasExpressionMin = true;
                                        config.ccControl.expressionMin = paramStorage[\expressionMin] ? 10;
                                    },
                                    \expressionMax, {
                                        hasExpressionMax = true;
                                        config.ccControl.expressionMax = paramStorage[\expressionMax] ? 120;
                                    },
                                    \expressionDurationScalar, {
                                        hasExpressionDur = true;
                                        config.ccControl.expressionDurationScalar = paramStorage[\expressionDurationScalar] ? 0.5;
                                    }
                                );
                            };

                            if (hasExpressionMin or: { hasExpressionMax }) {
                                foundInTemplate = true;
                                "OSC: Layer % expression from template (Row % %): Min=%, Max=%, DurScalar=%".format(
                                    layerKey, rowNum, mapping.template,
                                    config.ccControl.expressionMin,
                                    config.ccControl.expressionMax,
                                    config.ccControl.expressionDurationScalar.round(0.01)
                                ).postln;
                            };
                        };
                    };
                };
            };

            // PHASE 2: Fallback to direct knob reads (backward compatibility)
            if (foundInTemplate.not and: { ~midiController.notNil }) {
                // Read expression parameters from appropriate row (legacy behavior)
                config.ccControl.expressionMin = ~midiController.getKnobRow(rowNum, 5);
                config.ccControl.expressionMax = ~midiController.getKnobRow(rowNum, 6);
                config.ccControl.expressionDurationScalar = ~midiController.getKnobRow(rowNum, 4).linlin(0.0, 1.0, 0.001, 1.0);

                "OSC: Layer % expression from direct knobs (Row %): Min=%, Max=%, DurScalar=%".format(
                    layerKey, rowNum,
                    config.ccControl.expressionMin,
                    config.ccControl.expressionMax,
                    config.ccControl.expressionDurationScalar.round(0.01)
                ).postln;
            };

            // PHASE 3: Ensure valid ranges regardless of source
            if (config.ccControl.expressionMax <= config.ccControl.expressionMin) {
                config.ccControl.expressionMax = config.ccControl.expressionMin + 1;
            };
        };
    };
};

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

    // Store external responders
    ~oscLayers.responders[\external] = externalResponders;

    "External OSC control enabled on port %".format(port).postln;
    "Send OSC to this computer's IP on port % for external control".format(port).postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                       INITIALIZATION FUNCTIONS                             │
// └─────────────────────────────────────────────────────────────────────────────┘

// Initialize the entire OSC layers system
~initOSCLayersSystem = {
    "Initializing OSC Layers System...".postln;

    // Create coordinator
    ~oscLayers.coordinator = ~createOSCCoordinator.();

    // Create layer responders
    [\layer1, \layer2, \layer3].do {|layerKey|
        ~createLayerOSCResponders.(layerKey);
    };

    // Create system responders
    ~createSystemOSCResponders.();

    // Setup external control automatically
    ~setupExternalOSCControl.();

    // Setup compatibility layer
    ~setupOSCCompatibility.();

    "OSC Layers System initialized successfully".postln;
    "  - 3 layers with OSC control".postln;
    "  - System-wide OSC commands".postln;
    "  - External control ready on port 7000".postln;
    "  - Compatibility layer established".postln;
    "  - All existing functionality preserved".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                        MELODY SYSTEM                                       │
// └─────────────────────────────────────────────────────────────────────────────┘

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