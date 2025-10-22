/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                    TEST: MELODY GROUP MIDI CONTROLS                            ║
╚═══════════════════════════════════════════════════════════════════════════════╝

This script tests the melody group MIDI control fixes:
- BPM control (Row 1 Knob 8)
- Note duration scalar (Row X Knob 2)
- Expression envelope parameters (Row X Knobs 4/5/6)
- Velocity control (Row X Knob 3)
*/

(
"=== Testing Melody Group MIDI Controls ===".postln;
"".postln;

// 1. Check if required functions exist
"1. Checking required functions...".postln;
if (~getBPMFromKnob.notNil) {
    "   ✓ ~getBPMFromKnob exists".postln;
} {
    "   ✗ ~getBPMFromKnob not found".error;
};

if (~calculateDurationFromBPM.notNil) {
    "   ✓ ~calculateDurationFromBPM exists".postln;
} {
    "   ✗ ~calculateDurationFromBPM not found".error;
};

if (~updateLayerNoteDurationScalar.notNil) {
    "   ✓ ~updateLayerNoteDurationScalar exists".postln;
} {
    "   ✗ ~updateLayerNoteDurationScalar not found".error;
};

if (~updateLayerExpressionParams.notNil) {
    "   ✓ ~updateLayerExpressionParams exists".postln;
} {
    "   ✗ ~updateLayerExpressionParams not found".error;
};
"".postln;

// 2. Test BPM reading
"2. Testing BPM control (Row 1 Knob 8)...".postln;
if (~getBPMFromKnob.notNil) {
    var bpm = ~getBPMFromKnob.();
    "   Current BPM: %".format(bpm.round(1)).postln;

    // Test duration calculation for 16 notes
    if (~calculateDurationFromBPM.notNil) {
        var duration16 = ~calculateDurationFromBPM.(bpm, 16);
        var duration8 = ~calculateDurationFromBPM.(bpm, 8);
        var duration4 = ~calculateDurationFromBPM.(bpm, 4);

        "   Duration for 16 notes: %s".format(duration16.round(0.01)).postln;
        "   Duration for 8 notes: %s".format(duration8.round(0.01)).postln;
        "   Duration for 4 notes: %s".format(duration4.round(0.01)).postln;
    };
};
"".postln;

// 3. Find melody groups to test
"3. Finding melody groups (non-chord groups)...".postln;
if (~vstManager.notNil) {
    var melodyGroups = ~vstManager.getGroupNames().select { |name|
        ~vstManager.getGroupType(name) != \chord
    };

    "   Found % melody groups: %".format(melodyGroups.size, melodyGroups).postln;

    if (melodyGroups.size > 0) {
        var testGroup = melodyGroups.first;
        var rowNum = ~getMIDIRowForGroup.(testGroup);
        var config = ~oscLayers.dynamicConfigs[testGroup];

        "".postln;
        "4. Testing with group: % (MIDI Row %)".format(testGroup, rowNum).postln;

        // Display current parameter values
        if (config.notNil) {
            "   Note Duration Scalar: %".format(config.noteDurationScalar.round(0.01)).postln;

            if (config.ccControl.notNil) {
                "   Expression Enabled: %".format(config.ccControl.enabled).postln;
                "   Expression Min: %".format(config.ccControl.expressionMin).postln;
                "   Expression Max: %".format(config.ccControl.expressionMax).postln;
                "   Expression Duration Scalar: %".format(
                    config.ccControl.expressionDurationScalar.round(0.001)
                ).postln;
            };
        };

        "".postln;
        "5. Creating test melody...".postln;

        // Create a simple test melody
        var testMelody = (
            patterns: [[60, 62, 64, 65, 67, 69, 71, 72]],  // C major scale
            metadata: (
                totalDuration: 4.0,
                name: "Test Scale"
            )
        );

        // Store in melody dictionary
        if (~melodyDict.isNil) { ~melodyDict = Dictionary.new };
        ~melodyDict[\testMelody] = testMelody;

        // Assign to group
        if (~setMelodyListForGroup.notNil) {
            ~setMelodyListForGroup.(testGroup, [\testMelody]);
            "   Assigned test melody to group %".format(testGroup).postln;
        };

        "".postln;
        "6. Starting playback with MIDI control...".postln;
        "   Manual control is: %".format(~oscLayers.state.manualControl).postln;
        "   Watch console for debug output:".postln;
        "   - Should show BPM being used".postln;
        "   - Should show note duration scalar".postln;
        "   - Should show expression envelope parameters".postln;
        "".postln;

        // Start playback (non-looping)
        ~startDynamicGroupPlayback.(testGroup, nil, false);

        "".postln;
        "7. MIDI Control Instructions:".postln;
        "   Row 1 Knob 8: Adjust BPM (60-400)".postln;
        "   Row % Knob 2: Note duration scalar (1-100%)".format(rowNum).postln;
        "   Row % Knob 3: Note velocity (1-127)".format(rowNum).postln;
        "   Row % Knob 4: Expression duration scalar".format(rowNum).postln;
        "   Row % Knob 5: Expression minimum (0-127)".format(rowNum).postln;
        "   Row % Knob 6: Expression maximum (0-127)".format(rowNum).postln;
        "".postln;
        "   Run this test again after adjusting knobs to see changes.".postln;

    } {
        "   No melody groups available for testing.".warn;
        "   Create a regular (non-chord) group first.".postln;
    };
} {
    "   VST Manager not available".warn;
};

"".postln;
"=== Test Complete ===".postln;
"".postln;
"To verify fixes are working:".postln;
"1. Adjust Row 1 Knob 8 and re-run - BPM should change".postln;
"2. Adjust Row X Knob 2 and re-run - Note duration should change".postln;
"3. Check console output shows 'Melody X using BPM Y'".postln;
"4. Check console output shows expression parameters".postln;
)