/*
═══════════════════════════════════════════════════════════════════════════════
  CHORD EXPRESSION ENVELOPE - END-TO-END TEST
  Tests complete chain: MIDI params → Expression trigger → /midi/cc → VST
═══════════════════════════════════════════════════════════════════════════════
*/

(
var testGroup, chordGroups;

"═══════════════════════════════════════════════════════════════════════════════".postln;
"  CHORD EXPRESSION ENVELOPE - END-TO-END TEST".postln;
"═══════════════════════════════════════════════════════════════════════════════".postln;
"".postln;

// ─────────────────────────────────────────────────────────────────────────────
// STEP 1: Setup
// ─────────────────────────────────────────────────────────────────────────────

"► STEP 1: Finding chord group".postln;
chordGroups = ~vstManager.getChordGroupNames();
if (chordGroups.size > 0) {
    testGroup = chordGroups.first;
    "  ✓ Using chord group: %".format(testGroup).postln;
} {
    "  ✗ ERROR: No chord groups available".error;
    ^nil;
};
"".postln;

// ─────────────────────────────────────────────────────────────────────────────
// STEP 2: Update MIDI Parameters
// ─────────────────────────────────────────────────────────────────────────────

"► STEP 2: Updating MIDI parameters".postln;
"  Current knob values:".postln;
"    Row 1 Knob 5 raw: %".format(~midiController.getKnobRow(1, 5)).postln;
"    Row 1 Knob 6 raw: %".format(~midiController.getKnobRow(1, 6)).postln;
"".postln;

~updateLayerExpressionParams.(testGroup);
{
    var config;
    config = ~oscLayers.dynamicConfigs[testGroup];
    "  After update:".postln;
    "    Expression Min: % (should be 0-127)".format(config.ccControl.expressionMin).postln;
    "    Expression Max: % (should be 0-127)".format(config.ccControl.expressionMax).postln;
    "    Duration Scalar: %".format(config.ccControl.expressionDurationScalar.round(0.001)).postln;

    if (config.ccControl.expressionMax > 127 or: { config.ccControl.expressionMin > 127 }) {
        "  ✗ ERROR: Values overflow CC range!".error;
    } {
        "  ✓ Values in valid range".postln;
    };
}.value;
"".postln;

// ─────────────────────────────────────────────────────────────────────────────
// STEP 3: Send Test Chord
// ─────────────────────────────────────────────────────────────────────────────

"► STEP 3: Sending test chord".postln;
"  Watch for these log messages:".postln;
"    1. 'Chord JSON: 3 notes...' (chord received)".postln;
"    2. 'Expression envelope triggered...' (envelope started)".postln;
"    3. '[/midi/cc] Group: ...' (CC routing, appears every 50th message)".postln;
"".postln;

{
    var jsonString;
    jsonString = "{
        \"notes\": [
            {\"midi\": 60, \"vel\": 0.8, \"dur\": 3.0},
            {\"midi\": 64, \"vel\": 0.7, \"dur\": 3.0},
            {\"midi\": 67, \"vel\": 0.9, \"dur\": 3.0}
        ],
        \"metadata\": {\"targetGroup\": 0}
    }";

    NetAddr("127.0.0.1", 7000).sendMsg('/chord', jsonString);

    "  ✓ Chord sent (C major, 3 seconds duration)".postln;
    "  → Listen for expression CC sweep on audio output".postln;
    "  → Check post window for /midi/cc routing messages".postln;
}.value;
"".postln;

// ─────────────────────────────────────────────────────────────────────────────
// STEP 4: Verify Tracking
// ─────────────────────────────────────────────────────────────────────────────

"► STEP 4: Verify group tracking".postln;
{
    1.wait;  // Wait for chord to trigger

    if (~oscLayers.lastTriggeredGroup.notNil) {
        "  ✓ Last triggered group: %".format(~oscLayers.lastTriggeredGroup).postln;
    } {
        "  ✗ WARNING: lastTriggeredGroup not set".warn;
    };
}.fork;
"".postln;

// ─────────────────────────────────────────────────────────────────────────────
// Summary
// ─────────────────────────────────────────────────────────────────────────────

"═══════════════════════════════════════════════════════════════════════════════".postln;
"  WHAT TO CHECK".postln;
"═══════════════════════════════════════════════════════════════════════════════".postln;
"".postln;
"  Audio Output:".postln;
"    □ Hear C major chord (3 notes)".postln;
"    □ Hear CC modulation sweep (expression envelope)".postln;
"    □ Sweep lasts ~3 seconds".postln;
"".postln;
"  Post Window:".postln;
"    □ 'Chord JSON: 3 notes...' message appears".postln;
"    □ 'Expression envelope triggered...' message appears".postln;
"    □ '[/midi/cc] Group: ...' messages appear (every 50th)".postln;
"    □ No overflow errors (values > 127)".postln;
"".postln;
"  If expression NOT working:".postln;
"    1. Check osc-setup.scd has ~midiCCFunc responder".postln;
"    2. Run: ~midiCCFunc.notNil.postln (should be true)".postln;
"    3. Reload system: reboot SuperCollider".postln;
"".postln;
"  Adjust MIDI knobs and re-run to test dynamic updates:".postln;
"    → Row 1 Knob 5: Expression min".postln;
"    → Row 1 Knob 6: Expression max".postln;
"    → Row 1 Knob 4: Expression duration scalar".postln;
"".postln;

)
