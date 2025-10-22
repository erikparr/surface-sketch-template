# Melody Group MIDI Control Fix Plan

## Problem Analysis

### Current Issues with Melody Groups:
1. **BPM Control (Row 1 Knob 8)** - Not affecting melody playback speed
2. **Expression Envelope** - Triggers but parameters may not be updated
3. **Note Duration Scalar (Row X Knob 2)** - Not being updated before playback

### Root Causes Identified:

#### 1. BPM Not Applied to Melody Playback
**Location**: `~startDynamicGroupPlayback` (lines 1710-1720)
```supercollider
// Current code - uses fixed duration or metadata
playDuration = duration ?? {
    if (melodyData.metadata.notNil and: { melodyData.metadata.totalDuration.notNil }) {
        melodyData.metadata.totalDuration
    } {
        4.0
    }
};
noteInterval = playDuration / pattern.size;
```
**Problem**: Not checking BPM from Row 1 Knob 8. Should use `~calculateDurationFromBPM`

#### 2. Note Duration Scalar Not Updated
**Location**: `~startDynamicGroupPlayback` (line 1744)
```supercollider
noteDuration = (noteInterval * 0.8) * config.noteDurationScalar;
```
**Problem**: Uses stale `config.noteDurationScalar` - needs to call `~updateLayerNoteDurationScalar` first

#### 3. Expression Envelope Parameters Updated But May Have Wrong Timing
**Location**: Lines 1752-1757
```supercollider
if (config.ccControl.enabled) {
    ~updateLayerExpressionParams.(groupName);  // ✓ This is correct
    NetAddr.localAddr.sendMsg('/group/' ++ sanitizedName ++ '/expression', playDuration);
};
```
**Status**: This looks correct, but needs verification

---

## Proposed Solution

### Fix 1: Apply BPM to Melody Playback
**Change `~startDynamicGroupPlayback` to use BPM**:
```supercollider
// After line 1710, replace duration determination with:
playDuration = duration ?? {
    if (~oscLayers.state.manualControl and: { ~getBPMFromKnob.notNil }) {
        var bpm = ~getBPMFromKnob.();
        var noteCount = pattern.size;
        ~calculateDurationFromBPM.(bpm, noteCount)
    } {
        // Fallback to metadata or default
        if (melodyData.metadata.notNil and: { melodyData.metadata.totalDuration.notNil }) {
            melodyData.metadata.totalDuration
        } {
            4.0
        }
    }
};
```

### Fix 2: Update Note Duration Scalar Before Playback
**Add before line 1744**:
```supercollider
// Update note duration scalar from MIDI right before playback
~updateLayerNoteDurationScalar.(groupName);
```

### Fix 3: Add Debug Output for Expression Envelope
**After line 1756, add**:
```supercollider
"Group % expression from MIDI (Row %): Min=%, Max=%, DurScalar=%".format(
    groupName, rowNum,
    config.ccControl.expressionMin,
    config.ccControl.expressionMax,
    config.ccControl.expressionDurationScalar
).postln;
```

---

## Implementation Steps

### Step 1: Update `~startDynamicGroupPlayback`
```supercollider
~startDynamicGroupPlayback = { |groupName, targetGroup = nil, loop = true, duration = nil|
    var config, melodyData, pattern, noteInterval, velocity, sanitizedName, playDuration, melodyKey, result, rowNum;

    // ... existing validation code ...

    if (pattern.notNil and: { pattern.size > 0 }) {
        // NEW: Use BPM for duration if manual control is on
        playDuration = duration ?? {
            if (~oscLayers.state.manualControl and: { ~getBPMFromKnob.notNil }) {
                var bpm = ~getBPMFromKnob.();
                var noteCount = pattern.size;
                var bpmDuration = ~calculateDurationFromBPM.(bpm, noteCount);
                "Melody % using BPM %: duration %s for % notes".format(
                    groupName, bpm.round(1), bpmDuration.round(0.01), noteCount
                ).postln;
                bpmDuration
            } {
                // Fallback to metadata or default
                if (melodyData.metadata.notNil and: { melodyData.metadata.totalDuration.notNil }) {
                    melodyData.metadata.totalDuration
                } {
                    4.0
                }
            }
        };

        sanitizedName = config.sanitizedName;
        noteInterval = playDuration / pattern.size;

        // Get MIDI row for this group
        rowNum = ~getMIDIRowForGroup.(groupName);

        // NEW: Update note duration scalar from MIDI before playback
        ~updateLayerNoteDurationScalar.(groupName);

        // Read velocity from MIDI controller Row X Knob 3
        velocity = if (~oscLayers.state.manualControl and: { ~midiController.notNil }) {
            var rawVel = ~midiController.getKnobRow(rowNum, 3);
            if (rawVel > 1.0) {
                rawVel.asInteger.clip(1, 127);
            } {
                (rawVel * 127).asInteger.clip(1, 127);
            };
        } {
            127;
        };

        "Starting dynamic group %: % notes, duration: %s, loop: %, velocity: %, noteDurScalar: %".format(
            groupName, pattern.size, playDuration.round(0.01), loop, velocity,
            config.noteDurationScalar.round(0.01)
        ).postln;

        // Send notes via OSC
        pattern.do { |note, i|
            var when = i * noteInterval;
            var noteDuration = (noteInterval * 0.8) * config.noteDurationScalar;

            SystemClock.sched(when, {
                NetAddr.localAddr.sendMsg('/group/' ++ sanitizedName ++ '/note', note, velocity, noteDuration);
            });
        };

        // Trigger expression envelope if enabled
        if (config.ccControl.enabled) {
            ~updateLayerExpressionParams.(groupName);

            // Debug output
            "Group % expression from MIDI (Row %): Min=%, Max=%, DurScalar=%".format(
                groupName, rowNum,
                config.ccControl.expressionMin,
                config.ccControl.expressionMax,
                config.ccControl.expressionDurationScalar
            ).postln;

            NetAddr.localAddr.sendMsg('/group/' ++ sanitizedName ++ '/expression', playDuration);
        };

        // ... rest of function ...
    }
};
```

### Step 2: Ensure BPM Functions Are Available
Verify that these functions exist and are loaded:
- `~getBPMFromKnob` - Should read Row 1 Knob 8
- `~calculateDurationFromBPM` - Should calculate duration from BPM and note count
- `~updateLayerNoteDurationScalar` - Should update from Row X Knob 2

### Step 3: Test Points
1. **BPM Control**: Turn Row 1 Knob 8 and verify duration changes
2. **Note Duration**: Turn Row X Knob 2 and verify note lengths change
3. **Expression**: Turn Row X Knobs 4/5/6 and verify envelope parameters
4. **Velocity**: Turn Row X Knob 3 and verify velocity changes

---

## Benefits

1. **Consistent Timing**: All melody groups will respect BPM setting
2. **Live Control**: Changes to MIDI knobs will affect playback immediately
3. **Per-Group Control**: Each group's row controls its own parameters
4. **Debug Visibility**: Clear console output shows what values are being used

---

## Testing Script

```supercollider
// Test melody group MIDI controls
(
"=== Testing Melody Group MIDI Controls ===".postln;

// 1. Check if BPM function exists
if (~getBPMFromKnob.notNil) {
    var bpm = ~getBPMFromKnob.();
    "BPM from Row 1 Knob 8: %".format(bpm).postln;
} {
    "ERROR: ~getBPMFromKnob not found".error;
};

// 2. Test with first melody group
if (~vstManager.notNil) {
    var groups = ~vstManager.getGroupNames().select { |name|
        ~vstManager.getGroupType(name) != \chord
    };

    if (groups.size > 0) {
        var testGroup = groups.first;
        var rowNum = ~getMIDIRowForGroup.(testGroup);

        "Testing group: % (Row %)".format(testGroup, rowNum).postln;

        // Start playback
        ~startDynamicGroupPlayback.(testGroup, nil, false);
    };
};
)
```

---

## Summary

The main issue is that `~startDynamicGroupPlayback` doesn't check BPM from Row 1 Knob 8. It uses either:
1. Passed duration parameter
2. Melody metadata totalDuration
3. Default 4.0 seconds

The fix adds BPM checking when manual control is enabled, updates note duration scalar before playback, and adds debug output to verify values.