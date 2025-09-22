/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                     LAYER TIMING CONTROLLER                                   ║
║              MIDI control for sequential layer triggering                     ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

"Loading Layer Timing Controller...".postln;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                        MIDI CONTROL INTEGRATION                            │
// └─────────────────────────────────────────────────────────────────────────────┘

// Function to get current MIDI control values
~getTimingControlMIDIValues = {
    var enableValue, waitTimeValue, enabled, waitTime;

    if (~midiController.notNil) {
        // Row 1 Knob 1 (CC 16): Enable/disable offset timing
        enableValue = ~midiController.getKnobRow1(1); // 0-127
        enabled = enableValue > 63; // Above middle = enabled

        // Row 1 Knob 2 (CC 20): Wait time with exponential scaling
        waitTimeValue = ~midiController.getKnobRow1(2); // 0-127
        // Exponential scaling: 0.1s to 2.0s
        waitTime = 0.1 * (20 ** (waitTimeValue / 127.0));
        waitTime = waitTime.clip(0.1, 2.0);

        (enabled: enabled, waitTime: waitTime, enableValue: enableValue, waitTimeValue: waitTimeValue);
    } {
        // Fallback values when MIDI controller not available
        (enabled: false, waitTime: 0.5, enableValue: 0, waitTimeValue: 64);
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                      REAL-TIME PARAMETER UPDATES                           │
// └─────────────────────────────────────────────────────────────────────────────┘

// Function to update timing parameters from MIDI in real-time
~updateTimingFromMIDI = {
    var values, changed = false;

    values = ~getTimingControlMIDIValues.();

    // Update offset timing enabled state
    if (~oscLayers.state.offsetTimingEnabled != values.enabled) {
        ~oscLayers.state.offsetTimingEnabled = values.enabled;
        "Timing Controller: Offset mode % (MIDI: %)".format(
            if(values.enabled, "ENABLED", "DISABLED"),
            values.enableValue
        ).postln;
        changed = true;
    };

    // Update offset time with tolerance to avoid constant updates
    if ((~oscLayers.state.offsetTime - values.waitTime).abs > 0.01) {
        ~oscLayers.state.offsetTime = values.waitTime;
        "Timing Controller: Wait time %.2fs (MIDI: %)".format(
            values.waitTime,
            values.waitTimeValue
        ).postln;
        changed = true;
    };

    // Return whether anything changed (for GUI updates)
    changed;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                      POLLING ROUTINE INTEGRATION                           │
// └─────────────────────────────────────────────────────────────────────────────┘

// Start MIDI polling for timing control
~startTimingControlMIDIPolling = {
    ~stopTimingControlMIDIPolling.(); // Stop existing routine

    ~timingControlMIDIRoutine = Routine({
        inf.do {
            ~updateTimingFromMIDI.();
            0.1.wait; // Poll every 100ms for responsive control
        };
    }).play;

    "Timing Controller: MIDI polling started".postln;
};

// Stop MIDI polling
~stopTimingControlMIDIPolling = {
    if (~timingControlMIDIRoutine.notNil) {
        ~timingControlMIDIRoutine.stop;
        ~timingControlMIDIRoutine = nil;
        "Timing Controller: MIDI polling stopped".postln;
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         INTEGRATION FUNCTIONS                              │
// └─────────────────────────────────────────────────────────────────────────────┘

// Initialize timing controller integration
~initTimingController = {
    "Initializing Layer Timing Controller...".postln;

    // Start MIDI polling if MIDI controller is available
    if (~midiController.notNil) {
        ~startTimingControlMIDIPolling.();
        "Timing Controller: MIDI integration active".postln;
        "  - Knob 1 (CC 16): Enable sequential mode".postln;
        "  - Knob 2 (CC 20): Adjust wait time (0.1-2.0s)".postln;
    } {
        "Timing Controller: MIDI controller not available, using manual control only".postln;
    };

    // Initial parameter update
    ~updateTimingFromMIDI.();

    "Layer Timing Controller initialized".postln;
};

// Cleanup function
~cleanupTimingController = {
    ~stopTimingControlMIDIPolling.();
    "Timing Controller: Cleaned up".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                           MANUAL CONTROL API                               │
// └─────────────────────────────────────────────────────────────────────────────┘

// Manual control functions (bypass MIDI)
~setOffsetTimingEnabled = {|enabled|
    ~oscLayers.state.offsetTimingEnabled = enabled.asBoolean;
    "Timing Controller: Manual control - offset mode %".format(
        if(enabled, "ENABLED", "DISABLED")
    ).postln;
};

~setOffsetTime = {|time|
    var clippedTime = time.asFloat.clip(0.1, 2.0);
    ~oscLayers.state.offsetTime = clippedTime;
    "Timing Controller: Manual control - wait time %.2fs".format(clippedTime).postln;
};

// Quick presets
~setTimingPreset = {|preset|
    switch(preset,
        \off, {
            ~setOffsetTimingEnabled.(false);
        },
        \short, {
            ~setOffsetTimingEnabled.(true);
            ~setOffsetTime.(0.25);
        },
        \medium, {
            ~setOffsetTimingEnabled.(true);
            ~setOffsetTime.(0.5);
        },
        \long, {
            ~setOffsetTimingEnabled.(true);
            ~setOffsetTime.(1.0);
        },
        \verylong, {
            ~setOffsetTimingEnabled.(true);
            ~setOffsetTime.(1.5);
        },
        {
            "Unknown timing preset: %. Available: \\off, \\short, \\medium, \\long, \\verylong".format(preset).warn;
        }
    );
};

// Status function
~getTimingControlStatus = {
    var midiValues = ~getTimingControlMIDIValues.();
    var status = (
        offsetEnabled: ~oscLayers.state.offsetTimingEnabled,
        offsetTime: ~oscLayers.state.offsetTime,
        midiEnabled: midiValues.enabled,
        midiWaitTime: midiValues.waitTime,
        midiController: ~midiController.notNil,
        polling: ~timingControlMIDIRoutine.notNil
    );

    "=== TIMING CONTROLLER STATUS ===".postln;
    "Offset Mode: % (%.2fs wait)".format(
        if(status.offsetEnabled, "ENABLED", "DISABLED"),
        status.offsetTime
    ).postln;
    "MIDI Controller: %".format(if(status.midiController, "Available", "Not Available")).postln;
    if (status.midiController) {
        "MIDI Polling: %".format(if(status.polling, "Active", "Stopped")).postln;
        "MIDI Values: Enable=% (%), WaitTime=%.2fs (%)".format(
            if(midiValues.enabled, "ON", "OFF"), midiValues.enableValue,
            midiValues.waitTime, midiValues.waitTimeValue
        ).postln;
    };
    "Last Trigger States: %".format(~oscLayers.state.layerTriggerStates.keys).postln;
    "================================".postln;

    status;
};

"Layer Timing Controller loaded".postln;
"Available functions:".postln;
"• ~initTimingController.() - Initialize with MIDI polling".postln;
"• ~setTimingPreset.(\\medium) - Quick presets (\\off, \\short, \\medium, \\long, \\verylong)".postln;
"• ~setOffsetTimingEnabled.(true) - Manual enable/disable".postln;
"• ~setOffsetTime.(1.0) - Manual wait time setting".postln;
"• ~getTimingControlStatus.() - Show current status".postln;
"• ~updateTimingFromMIDI.() - Force MIDI update".postln;
"".postln;
"MIDI Control:".postln;
"• Row 1 Knob 1 (CC 16): Enable sequential mode".postln;
"• Row 1 Knob 2 (CC 20): Wait time (0.1-2.0s exponential)".postln;