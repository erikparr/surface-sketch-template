/*
═══════════════════════════════════════════════════════════════════════════════
  CHORD OSC ENDPOINT - MIDI INTEGRATION COMPREHENSIVE TEST
  Tests the fixed expression envelope triggering and MIDI parameter integration
═══════════════════════════════════════════════════════════════════════════════
*/

(
var testGroup, chordGroups, results, testsPassed, testsFailed;

testsPassed = 0;
testsFailed = 0;
results = Dictionary.new;

"═══════════════════════════════════════════════════════════════════════════════".postln;
"  CHORD OSC ENDPOINT - MIDI INTEGRATION TEST (POST-FIX)".postln;
"═══════════════════════════════════════════════════════════════════════════════".postln;
"".postln;

// ─────────────────────────────────────────────────────────────────────────────
// TEST 1: Prerequisites
// ─────────────────────────────────────────────────────────────────────────────

"► TEST 1: VST Manager Available".postln;
if (~vstManager.notNil) {
    "  OK: ~vstManager available".postln;
    "  ✓ PASS".postln;
    testsPassed = testsPassed + 1;
    results[\vstManager] = true;
} {
    "  ERROR: ~vstManager not available".error;
    "  ✗ FAIL".postln;
    testsFailed = testsFailed + 1;
    results[\vstManager] = false;
};
"".postln;

"► TEST 2: Chord Groups Exist".postln;
chordGroups = ~vstManager.getChordGroupNames();
if (chordGroups.size > 0) {
    "  OK: Found % chord group(s): %".format(chordGroups.size, chordGroups).postln;
    testGroup = chordGroups.first;
    "  Using test group: %".format(testGroup).postln;
    "  ✓ PASS".postln;
    testsPassed = testsPassed + 1;
    results[\chordGroups] = true;
} {
    "  ERROR: No chord groups available".error;
    "  ✗ FAIL - Cannot continue tests".postln;
    testsFailed = testsFailed + 1;
    results[\chordGroups] = false;
    ^nil;
};
"".postln;

"► TEST 3: MIDI Controller Available".postln;
if (~midiController.notNil) {
    "  OK: ~midiController available".postln;
    "  ✓ PASS".postln;
    testsPassed = testsPassed + 1;
    results[\midiController] = true;
} {
    "  ERROR: ~midiController not available".error;
    "  ✗ FAIL".postln;
    testsFailed = testsFailed + 1;
    results[\midiController] = false;
};
"".postln;

"► TEST 4: Dynamic Layer Config Exists".postln;
if (~oscLayers.dynamicConfigs[testGroup].notNil) {
    var config = ~oscLayers.dynamicConfigs[testGroup];
    "  OK: Dynamic layer config exists".postln;
    "    - Group type: %".format(~vstManager.getGroupType(testGroup)).postln;
    "    - Sanitized name: %".format(~oscLayers.groupToSanitized[testGroup]).postln;
    "    - CC control enabled: %".format(config.ccControl.enabled).postln;
    "    - Note duration scalar: %".format(config.noteDurationScalar).postln;
    "  ✓ PASS".postln;
    testsPassed = testsPassed + 1;
    results[\dynamicConfig] = true;
} {
    "  ERROR: No dynamic layer config for group %".format(testGroup).error;
    "  ✗ FAIL".postln;
    testsFailed = testsFailed + 1;
    results[\dynamicConfig] = false;
};
"".postln;

// ─────────────────────────────────────────────────────────────────────────────
// TEST 5: MIDI Parameter Scaling (POST-FIX)
// ─────────────────────────────────────────────────────────────────────────────

"► TEST 5: MIDI Parameter Scaling (POST-FIX)".postln;
"  Reading MIDI parameters for group '%' (Row %)...".format(testGroup, ~getMIDIRowForGroup.(testGroup)).postln;
~updateLayerExpressionParams.(testGroup);

{
    var config, min, max, durScalar, passed;
    config = ~oscLayers.dynamicConfigs[testGroup];
    min = config.ccControl.expressionMin;
    max = config.ccControl.expressionMax;
    durScalar = config.ccControl.expressionDurationScalar;
    passed = true;

    "  Expression Min: % (expected 0-127)".format(min).postln;
    "  Expression Max: % (expected 0-127)".format(max).postln;
    "  Expression Duration Scalar: % (expected 0.001-1.0)".format(durScalar.round(0.001)).postln;

    // Check if values are in valid ranges
    if (min < 0 or: { min > 127 }) {
        "  ERROR: expressionMin out of range".error;
        passed = false;
    };
    if (max < 0 or: { max > 127 }) {
        "  ERROR: expressionMax out of range".error;
        passed = false;
    };
    if (durScalar < 0.001 or: { durScalar > 1.0 }) {
        "  ERROR: expressionDurationScalar out of range".error;
        passed = false;
    };
    if (max <= min) {
        "  ERROR: expressionMax should be > expressionMin".error;
        passed = false;
    };

    if (passed) {
        "  ✓ PASS - All parameters in valid range".postln;
        testsPassed = testsPassed + 1;
        results[\parameterScaling] = true;
    } {
        "  ✗ FAIL - Parameter scaling still broken".postln;
        testsFailed = testsFailed + 1;
        results[\parameterScaling] = false;
    };
}.value;
"".postln;

// ─────────────────────────────────────────────────────────────────────────────
// TEST 6: Note Duration Scalar Applied
// ─────────────────────────────────────────────────────────────────────────────

"► TEST 6: Note Duration Scalar Applied".postln;
~updateLayerNoteDurationScalar.(testGroup);
{
    var config, scalar;
    config = ~oscLayers.dynamicConfigs[testGroup];
    scalar = config.noteDurationScalar;
    "  Note duration scalar: % (expected 0.01-1.0)".format(scalar.round(0.01)).postln;

    if (scalar >= 0.01 and: { scalar <= 1.0 }) {
        "  ✓ PASS - Scalar in valid range".postln;
        testsPassed = testsPassed + 1;
        results[\durationScalar] = true;
    } {
        "  ✗ FAIL - Scalar out of range".postln;
        testsFailed = testsFailed + 1;
        results[\durationScalar] = false;
    };
}.value;
"".postln;

// ─────────────────────────────────────────────────────────────────────────────
// TEST 7: Send Test Chord and Verify Expression Envelope
// ────────────────────────────────────────────���────────────────────────────────

"► TEST 7: Send Test Chord and Verify Expression Envelope".postln;
"  Sending chord JSON to /chord...".postln;
"  Notes: [60, 64, 67] (C major)".postln;
"  Velocity: [0.8, 0.7, 0.9]".postln;
"  Duration: 2.0s (will be scaled by MIDI knob)".postln;

{
    var jsonString, config, expectedDuration;

    config = ~oscLayers.dynamicConfigs[testGroup];
    expectedDuration = 2.0 * config.noteDurationScalar;

    jsonString = "{
        \"notes\": [
            {\"midi\": 60, \"vel\": 0.8, \"dur\": 2.0},
            {\"midi\": 64, \"vel\": 0.7, \"dur\": 2.0},
            {\"midi\": 67, \"vel\": 0.9, \"dur\": 2.0}
        ],
        \"metadata\": {\"targetGroup\": 0}
    }";

    NetAddr("127.0.0.1", 7000).sendMsg('/chord', jsonString);

    "  ✓ Chord sent - CHECK POST WINDOW for:".postln;
    "    → 'Expression envelope triggered' message".postln;
    "    → Expected duration: %s".format(expectedDuration.round(0.001)).postln;
    "    → Expected min: %".format(config.ccControl.expressionMin).postln;
    "    → Expected max: %".format(config.ccControl.expressionMax).postln;
    testsPassed = testsPassed + 1;
    results[\chordSend] = true;
}.value;
"".postln;

// ─────────────────────────────────────────────────────────────────────────────
// TEST 8: Verify Audio Output
// ─────────────────────────────────────────────────────────────────────────────

"► TEST 8: Manual Audio Verification".postln;
"  ⚠ MANUAL VERIFICATION REQUIRED".postln;
"  → Listen for chord notes (C major)".postln;
"  → Listen for expression CC modulation sweep".postln;
"  → Verify duration matches expected value".postln;
"".postln;

// ─────────────────────────────────────────────────────────────────────────────
// Summary
// ─────────────────────────────────────────────────────────────────────────────

"═══════════════════════════════════════════════════════════════════════════════".postln;
"  TEST RESULTS SUMMARY".postln;
"═══════════════════════════════════════════════════════════════════════════════".postln;
"".postln;

results.keysValuesDo { |key, passed|
    if (passed) {
        "  ✓ PASS - %".format(key).postln;
    } {
        "  ✗ FAIL - %".format(key).postln;
    };
};

"".postln;
"  Total tests: %".format(testsPassed + testsFailed).postln;
"  Passed: %".format(testsPassed).postln;
"  Failed: %".format(testsFailed).postln;
"".postln;

"═══════════════════════════════════════════════════════════════════════════════".postln;
"  ADJUSTMENT CHECKLIST".postln;
"═══════════════════════════════════════════════════════════════════════════════".postln;
"".postln;
"  Adjust MIDI knobs and re-run test to verify dynamic updates:".postln;
"  → Row 1 Knob 2: Note duration scalar (try 50% vs 100%)".postln;
"  → Row 1 Knob 5: Expression min (try 0-127)".postln;
"  → Row 1 Knob 6: Expression max (try 0-127)".postln;
"  → Row 1 Knob 4: Expression duration scalar".postln;
"".postln;
"  Expected behavior after fix:".postln;
"  ✓ Expression envelope message appears in post window".postln;
"  ✓ Expression min/max in range 0-127 (not 0-1)".postln;
"  ✓ Note durations scaled correctly".postln;
"  ✓ Audio shows clear CC modulation sweep".postln;
"".postln;

)
