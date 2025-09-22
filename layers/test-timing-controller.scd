/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                   LAYER TIMING CONTROLLER - TEST SCRIPT                      ║
║                   Comprehensive testing and demonstration                     ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

"=== LAYER TIMING CONTROLLER TEST SCRIPT ===".postln;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                           BASIC FUNCTIONALITY TEST                         │
// └─────────────────────────────────────────────────────────────────────────────┘

~testTimingControllerBasics = {
    "Testing basic timing controller functionality...".postln;

    // Test 1: Check initial state
    "1. Initial state check...".postln;
    ~getTimingControlStatus.();

    // Test 2: Manual control functions
    "2. Testing manual control functions...".postln;
    ~setOffsetTimingEnabled.(true);
    1.wait;
    ~setOffsetTime.(0.75);
    1.wait;
    ~getTimingControlStatus.();

    // Test 3: Preset functions
    "3. Testing preset functions...".postln;
    ~setTimingPreset.(\short);
    1.wait;
    ~setTimingPreset.(\medium);
    1.wait;
    ~setTimingPreset.(\long);
    1.wait;
    ~setTimingPreset.(\off);
    1.wait;

    "Basic functionality test complete!".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                             OSC COMMANDS TEST                              │
// └─────────────────────────────────────────────────────────────────────────────┘

~testOSCCommands = {
    "Testing OSC command interface...".postln;

    // Test OSC commands
    "Testing /system/offset_timing command...".postln;
    NetAddr.localAddr.sendMsg('/system/offset_timing', 1);
    1.wait;

    "Testing /system/offset_time command...".postln;
    NetAddr.localAddr.sendMsg('/system/offset_time', 1.25);
    1.wait;

    "Testing /system/offset_status query...".postln;
    NetAddr.localAddr.sendMsg('/system/offset_status');
    1.wait;

    // Reset to defaults
    NetAddr.localAddr.sendMsg('/system/offset_timing', 0);

    "OSC commands test complete!".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         SEQUENTIAL PLAYBACK TEST                           │
// └─────────────────────────────────────────────────────────────────────────────┘

~testSequentialPlayback = {
    "Testing sequential layer playback...".postln;

    // Ensure we have some test melodies
    if (~melodyDict.isNil or: { ~melodyDict.size == 0 }) {
        "Creating test melodies...".postln;
        ~melodyDict = Dictionary.new;
        ~melodyDict[\testMelody1] = (
            patterns: [[60, 62, 64, 65]],
            velocities: [100, 100, 100, 100],
            noteDurations: [0.2, 0.2, 0.2, 0.2]
        );
        ~melodyDict[\testMelody2] = (
            patterns: [[67, 69, 71, 72]],
            velocities: [90, 90, 90, 90],
            noteDurations: [0.2, 0.2, 0.2, 0.2]
        );
        ~melodyDict[\testMelody3] = (
            patterns: [[55, 57, 59, 60]],
            velocities: [110, 110, 110, 110],
            noteDurations: [0.2, 0.2, 0.2, 0.2]
        );
    };

    // Set up layers
    "Setting up test layers...".postln;
    ~setLayerMelody.(\layer1, \testMelody1);
    ~setLayerMelody.(\layer2, \testMelody2);
    ~setLayerMelody.(\layer3, \testMelody3);

    // Test simultaneous mode
    "Testing simultaneous mode...".postln;
    ~setOffsetTimingEnabled.(false);
    ~startLayers.(3.0);
    4.wait;
    ~stopLayers.();
    1.wait;

    // Test sequential mode
    "Testing sequential mode with 0.5s offsets...".postln;
    ~setOffsetTimingEnabled.(true);
    ~setOffsetTime.(0.5);
    ~startLayers.(2.0);
    4.wait;
    ~stopLayers.();
    1.wait;

    // Test different offset times
    "Testing sequential mode with 1.0s offsets...".postln;
    ~setOffsetTime.(1.0);
    ~startLayers.(2.0);
    5.wait;
    ~stopLayers.();

    "Sequential playback test complete!".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                           MIDI INTEGRATION TEST                            │
// └─────────────────────────────────────────────────────────────────────────────┘

~testMIDIIntegration = {
    "Testing MIDI integration...".postln;

    if (~midiController.notNil) {
        "MIDI Controller available - testing values...".postln;

        // Test MIDI value reading
        var midiValues = ~getTimingControlMIDIValues.();
        "Current MIDI values:".postln;
        "  Enable knob (Row 1, Pos 1): % -> %".format(
            midiValues.enableValue,
            if(midiValues.enabled, "ENABLED", "DISABLED")
        ).postln;
        "  Wait time knob (Row 1, Pos 2): % -> %.2fs".format(
            midiValues.waitTimeValue,
            midiValues.waitTime
        ).postln;

        // Test manual updates
        "Force updating from MIDI...".postln;
        ~updateTimingFromMIDI.();

        "MIDI integration test complete!".postln;
    } {
        "MIDI Controller not available - skipping MIDI test".warn;
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                              GUI TEST                                      │
// └─────────────────────────────────────────────────────────────────────────────┘

~testGUIIntegration = {
    "Testing GUI integration...".postln;

    // Create timing GUI if not exists
    if (~timingControllerGUIWindow.isNil) {
        "Creating timing controller GUI...".postln;
        ~createTimingControllerGUI.();
        2.wait;
    };

    // Test GUI updates
    "Testing GUI update functions...".postln;
    ~updateTimingGUIFromState.();
    ~refreshTimingGUITimeline.();

    // Test different states in GUI
    "Cycling through different timing states for GUI visualization...".postln;
    [\off, \short, \medium, \long].do { |preset|
        "Setting preset: %".format(preset).postln;
        ~setTimingPreset.(preset);
        2.wait;
    };

    "GUI integration test complete!".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                          COMPREHENSIVE TEST SUITE                          │
// └─────────────────────────────────────────────────────────────────────────────┘

~runTimingControllerTests = {
    "=== STARTING COMPREHENSIVE TIMING CONTROLLER TESTS ===".postln;

    Task({
        // Basic functionality
        ~testTimingControllerBasics.();
        2.wait;

        // OSC commands
        ~testOSCCommands.();
        2.wait;

        // MIDI integration
        ~testMIDIIntegration.();
        2.wait;

        // GUI integration
        ~testGUIIntegration.();
        2.wait;

        // Sequential playback (most important test)
        if (~vstManager.notNil) {
            ~testSequentialPlayback.();
        } {
            "VST Manager not available - skipping playback test".warn;
        };

        "=== ALL TIMING CONTROLLER TESTS COMPLETE ===".postln;
        "".postln;
        "To manually test:".postln;
        "1. Turn Row 1 Knob 1 past middle to enable sequential mode".postln;
        "2. Adjust Row 1 Knob 2 to change wait time".postln;
        "3. Use ~startLayers.() to hear the sequential triggering".postln;
        "4. Watch the timing GUI for visual feedback".postln;

    }).play;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                              QUICK DEMOS                                   │
// └─────────────────────────────────────────────────────────────────────────────┘

~demoSequentialTiming = {
    "=== QUICK SEQUENTIAL TIMING DEMO ===".postln;

    Task({
        // Setup
        if (~melodyDict.isNil) { ~runTimingControllerTests.(); ^this };

        "Demo 1: Simultaneous (normal) mode".postln;
        ~setOffsetTimingEnabled.(false);
        ~startLayers.(2.0);
        3.wait;
        ~stopLayers.();
        2.wait;

        "Demo 2: Sequential mode - 0.5s offsets".postln;
        ~setTimingPreset.(\medium);
        ~startLayers.(2.0);
        4.wait;
        ~stopLayers.();
        2.wait;

        "Demo 3: Sequential mode - 1.0s offsets".postln;
        ~setTimingPreset.(\long);
        ~startLayers.(2.0);
        5.wait;
        ~stopLayers.();

        "Demo complete! Try adjusting MIDI knobs for real-time control.".postln;
    }).play;
};

"Layer Timing Controller test script loaded!".postln;
"".postln;
"Available test functions:".postln;
"• ~runTimingControllerTests.() - Run full test suite".postln;
"• ~demoSequentialTiming.() - Quick demo of sequential vs simultaneous".postln;
"• ~testTimingControllerBasics.() - Test basic functions only".postln;
"• ~testSequentialPlayback.() - Test playback modes only".postln;
"• ~testMIDIIntegration.() - Test MIDI control only".postln;
"• ~testGUIIntegration.() - Test GUI features only".postln;