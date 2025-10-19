/*
═══════════════════════════════════════════════════════════════════════════════
  MIDI PARAMETER CONTROL TEST
  Tests that MIDI knobs directly control chord/melody playback
═══════════════════════════════════════════════════════════════════════════════
*/

(
var testGroup;

"═══════════════════════════════════════════════════════════════════════════════".postln;
"  MIDI PARAMETER CONTROL TEST".postln;
"═══════════════════════════════════════════════════════════════════════════════".postln;
"".postln;

testGroup = ~vstManager.getChordGroupNames().first;

if (testGroup.isNil) {
    "ERROR: No chord groups available".error;
    ^nil;
};

"Using test group: %".format(testGroup).postln;
"".postln;

// ─────────────────────────────────────────────────────────────────────────────
// TEST 1: Velocity Control (Row 1 Knob 3)
// ─────────────────────────────────────────────────────────────────────────────

"► TEST 1: Velocity Control".postln;
"  INSTRUCTIONS:".postln;
"    1. Set Row 1 Knob 3 to 25% (soft)".postln;
"    2. Send chord (see below)".postln;
"    3. Listen - should be SOFT".postln;
"    4. Set Row 1 Knob 3 to 100% (loud)".postln;
"    5. Send chord again".postln;
"    6. Listen - should be LOUD".postln;
"".postln;

"  Sending test chord in 3 seconds...".postln;
{
    var jsonString;
    3.wait;
    
    jsonString = "{
        \"notes\": [
            {\"midi\": 60, \"vel\": 0.5, \"dur\": 2.0}
        ],
        \"metadata\": {\"targetGroup\": 0}
    }";
    
    NetAddr("127.0.0.1", 7000).sendMsg('/chord', jsonString);
    "  → Chord sent (C note, 2s)".postln;
    "  → Velocity from Row 1 Knob 3 (NOT from JSON)".postln;
    "".postln;
}.fork;

// ─────────────────────────────────────────────────────────────────────────────
// TEST 2: Expression Min/Max Control (Row 1 Knobs 5 & 6)
// ─────────────────────────────────────────────────────────────────────────────

"► TEST 2: Expression Min/Max Control".postln;
"  INSTRUCTIONS:".postln;
"    1. Set Row 1 Knob 5 to 0% (expression min)".postln;
"    2. Set Row 1 Knob 6 to 100% (expression max)".postln;
"    3. Send chord (after Test 1 completes)".postln;
"    4. Listen for FULL sweep (0→127)".postln;
"    5. Set Row 1 Knob 5 to 50% (mid)".postln;
"    6. Set Row 1 Knob 6 to 75%".postln;
"    7. Send chord again".postln;
"    8. Listen for NARROW sweep (64→96)".postln;
"".postln;

"  Sending test chord in 6 seconds...".postln;
{
    var jsonString;
    6.wait;
    
    jsonString = "{
        \"notes\": [
            {\"midi\": 64, \"vel\": 0.5, \"dur\": 2.0}
        ],
        \"metadata\": {\"targetGroup\": 0}
    }";
    
    NetAddr("127.0.0.1", 7000).sendMsg('/chord', jsonString);
    "  → Chord sent (E note, 2s)".postln;
    "  → Expression min/max from Row 1 Knobs 5/6".postln;
    "  → Check post window for 'Expression envelope triggered' message".postln;
    "".postln;
}.fork;

// ─────────────────────────────────────────────────────────────────────────────
// TEST 3: Note Duration Scalar (Row 1 Knob 2)
// ─────────────────────────────────────────────────────────────────────────────

"► TEST 3: Note Duration Scalar".postln;
"  INSTRUCTIONS:".postln;
"    1. Set Row 1 Knob 2 to 50% (half duration)".postln;
"    2. Send chord (after Test 2 completes)".postln;
"    3. Note should last 1s (50% of 2s JSON duration)".postln;
"    4. Set Row 1 Knob 2 to 100% (full duration)".postln;
"    5. Send chord again".postln;
"    6. Note should last 2s (100% of JSON duration)".postln;
"".postln;

"  Sending test chord in 9 seconds...".postln;
{
    var jsonString;
    9.wait;
    
    jsonString = "{
        \"notes\": [
            {\"midi\": 67, \"vel\": 0.5, \"dur\": 2.0}
        ],
        \"metadata\": {\"targetGroup\": 0}
    }";
    
    NetAddr("127.0.0.1", 7000).sendMsg('/chord', jsonString);
    "  → Chord sent (G note, JSON dur: 2.0s)".postln;
    "  → Actual duration = JSON * Row 1 Knob 2 value".postln;
    "  → Check post window for actual duration".postln;
    "".postln;
}.fork;

// ─────────────────────────────────────────────────────────────────────────────
// Summary
// ─────────────────────────────────────────────────────────────────────────────

"═══════════════════════════════════════════════════════════════════════════════".postln;
"  EXPECTED BEHAVIOR".postln;
"═══════════════════════════════════════════════════════════════════════════════".postln;
"".postln;
"  ✓ Row 1 Knob 3: Controls note velocity (25% = soft, 100% = loud)".postln;
"  ✓ Row 1 Knob 5: Controls expression envelope minimum CC value".postln;
"  ✓ Row 1 Knob 6: Controls expression envelope maximum CC value".postln;
"  ✓ Row 1 Knob 2: Scales note duration (50% = half, 100% = full)".postln;
"  ✓ Row 1 Knob 4: Scales expression envelope duration".postln;
"".postln;
"  Post window should show:".postln;
"    - 'Note XX (vel YY, dur Zs)' with correct values".postln;
"    - 'Expression envelope triggered (dur: Xs, min: Y, max: Z)'".postln;
"    - '[/midi/cc] Group: ...' messages (CC routing)".postln;
"".postln;
"  Audio output should match knob positions!".postln;
"".postln;

)
