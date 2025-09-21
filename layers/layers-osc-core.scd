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

// Main container for OSC-based layer system
~oscLayers = (
    // System state
    state: (
        totalDuration: 0,
        startTime: nil,
        loopingMode: false,
        manualControl: false,
        liveMelodyMode: false,
        singleNoteCCMode: false,
        bendMode: false,
        isRunning: false,
        noteDurationScalar: 1.0,
        pendingUpdates: Dictionary.new
    ),

    // Layer configurations (preserved from original system)
    configs: (
        layer1: (
            melodyList: [],
            vstGroup: 'Layer1',
            enabled: true,
            duration: 0,
            noteDurationScalar: 1.0,
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
            vstGroup: 'Layer2',
            enabled: true,
            duration: 0,
            noteDurationScalar: 1.0,
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
            vstGroup: 'Layer3',
            enabled: true,
            duration: 0,
            noteDurationScalar: 1.0,
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

            "OSC: Layer % note % vel % dur %".format(layerNum, note, velocity, duration).postln;

            // Send to VST
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

                if (simpleRamp) {
                    Synth(\BendEnvelopeSimple, [
                        \start, 0,
                        \end, bendAmount,
                        \duration, duration,
                        \chanIndex, 0
                    ]);
                } {
                    Synth(\BendEnvelope, [
                        \start, 0,
                        \peak, bendAmount,
                        \return, 0,
                        \attackTime, duration * peakTime,
                        \releaseTime, duration * (1.0 - peakTime),
                        \chanIndex, 0
                    ]);
                };
            };
        }, '/layer' ++ layerNum ++ '/bend')
    );

    // Melody change: /layer1/melody, /layer2/melody, /layer3/melody
    responders = responders.add(
        OSCFunc({|msg|
            var melodyKey = msg[1].asSymbol;
            ~setLayerMelody.(layerKey, melodyKey);
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

    // Live melody mode: /system/live_melody
    responders = responders.add(
        OSCFunc({|msg|
            var enabled = msg[1].asBoolean;
            ~oscLayers.state.liveMelodyMode = enabled;
            "OSC: Live melody mode: %".format(enabled).postln;
        }, '/system/live_melody')
    );

    ~oscLayers.responders[\system] = responders;

    "Created % system OSC responders".format(responders.size).postln;
    responders;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                       OSC LAYER COORDINATOR                                │
// └─────────────────────────────────────────────────────────────────────────────┘

// Create the OSC-based layer coordinator (replaces ProcMod parent)
~createOSCCoordinator = {
    var coordinator = (
        // Currently running task
        currentTask: nil,

        // Start all layers with coordinated timing
        startAll: {|duration|
            var syncTime = Main.elapsedTime + 0.1; // 100ms coordination buffer
            var activeLayerCount = 0;

            "OSC Coordinator: Starting all layers, duration: %s".format(duration).postln;

            ~oscLayers.state.totalDuration = duration;
            ~oscLayers.state.startTime = syncTime;
            ~oscLayers.state.isRunning = true;

            // Create coordination task
            this.currentTask = Task({
                var loopCount = 0;
                var currentDuration;

                while { ~oscLayers.state.loopingMode or: { loopCount == 0 } } {
                    loopCount = loopCount + 1;

                    // Determine duration for this iteration
                    if (~oscLayers.state.manualControl and: { ~getLayersDurationFromKnob.notNil }) {
                        currentDuration = ~getLayersDurationFromKnob.();
                        "Loop %: MIDI knob duration: %s".format(loopCount, currentDuration).postln;
                    } {
                        currentDuration = duration;
                        "Loop %: Fixed duration: %s".format(loopCount, currentDuration).postln;
                    };

                    // Update expression parameters from MIDI
                    if (~updateAllLayerExpressionParams.notNil) {
                        ~updateAllLayerExpressionParams.();
                    };

                    // Start all enabled layers
                    [\layer1, \layer2, \layer3].do {|layerKey|
                        var config = ~oscLayers.configs[layerKey];
                        if (config.enabled and: { config.melodyList.size > 0 }) {
                            this.startLayer(layerKey, currentDuration);
                            activeLayerCount = activeLayerCount + 1;
                        };
                    };

                    if (activeLayerCount > 0) {
                        // Wait for this iteration to complete
                        currentDuration.wait;

                        if (~oscLayers.state.loopingMode) {
                            "Loop % complete, starting next...".format(loopCount).postln;
                            0.1.wait; // Small gap between loops
                        } {
                            "Single iteration complete".postln;
                        };
                    } {
                        "No active layers, stopping".warn;
                        ~oscLayers.state.loopingMode = false;
                    };
                };

                // Cleanup when finished
                this.cleanup();
            });

            // Start the coordination task
            this.currentTask.play;
        },

        // Start individual layer via OSC messages
        startLayer: {|layerKey, duration|
            var config = ~oscLayers.configs[layerKey];
            var melody = ~getLayerMelodyDynamic.(layerKey);
            var layerNum = layerKey.asString.last.asString.asInteger;
            var noteInterval, velocity;

            if (melody.isNil or: { melody.size == 0 }) {
                "Layer % has no melody to play".format(layerKey).warn;
                ^this;
            };

            "Starting layer % with % notes".format(layerKey, melody.size).postln;

            // Calculate timing
            noteInterval = duration / melody.size;

            // Get velocity
            velocity = if (~oscLayers.state.manualControl and: { ~midiController.notNil }) {
                ~midiController.getKnobRow1(3).linlin(0, 127, 1, 127).asInteger;
            } {
                127; // Default velocity
            };

            // Send melody via OSC messages with timing
            melody.do {|note, i|
                var when = i * noteInterval;
                var noteDuration = noteInterval * 0.8; // Note duration is 80% of interval

                SystemClock.sched(when, {
                    NetAddr.localAddr.sendMsg('/layer' ++ layerNum ++ '/note', note, velocity, noteDuration);
                });
            };

            // Trigger layer expression envelope if not in single note mode
            if (~oscLayers.state.singleNoteCCMode.not and: { config.ccControl.enabled }) {
                NetAddr.localAddr.sendMsg('/layer' ++ layerNum ++ '/expression', duration);
            };
        },

        // Stop all layers
        stopAll: {
            ~oscLayers.state.isRunning = false;
            ~oscLayers.state.loopingMode = false;

            if (this.currentTask.notNil) {
                this.currentTask.stop;
                this.currentTask = nil;
            };

            "OSC Coordinator: All layers stopped".postln;
        },

        // Cleanup resources
        cleanup: {
            ~oscLayers.state.isRunning = false;
            ~oscLayers.state.startTime = nil;
            this.currentTask = nil;
            "OSC Coordinator: Cleanup complete".postln;
        }
    );

    coordinator;
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

    "OSC Layers System initialized successfully".postln;
    "  - 3 layers with OSC control".postln;
    "  - System-wide OSC commands".postln;
    "  - All existing functionality preserved".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                       COMPATIBILITY LAYER                                  │
// └─────────────────────────────────────────────────────────────────────────────┘

// Main control functions that work via OSC
~startLayersOSC = {|duration|
    duration = duration ?? { 2.0 };
    if (~oscLayers.coordinator.notNil) {
        ~oscLayers.coordinator.startAll(duration);
    } {
        "OSC coordinator not initialized".error;
    };
};

~stopLayersOSC = {
    if (~oscLayers.coordinator.notNil) {
        ~oscLayers.coordinator.stopAll();
    } {
        "OSC coordinator not initialized".error;
    };
};

// Preserve existing function interfaces for compatibility
~startLayers = ~startLayersOSC;
~stopLayers = ~stopLayersOSC;

"OSC Layers Core loaded".postln;
"  - Pure OSC-based layer control".postln;
"  - No ProcMod dependencies".postln;
"  - Preserved function interfaces".postln;