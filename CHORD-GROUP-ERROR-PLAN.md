# Chord Group Error Analysis & Fix Plan

## Error from output.txt (Lines 27-81)

### The Error:
```
ERROR: ERROR: Chord group index 1 not found.
  → Available chord groups (count: 1): [chordGroup1]
  → Valid indices: 0 to 0
ERROR: ERROR: Could not resolve chord group: 1
EXTERNAL OSC /chord: 2 notes → chord group 'nil' (target: 1)
WARNING: Group nil not found in dynamic layers
ERROR: Message 'noteDurationScalar_' not understood.
RECEIVER: nil
```

### Root Cause Analysis

**Step 1: What's happening?**
- External app sends `/chord` message with `targetGroup: 1`
- System tries to find chord group at index 1
- Only 1 chord group exists: "chordGroup1" at index 0
- Index 1 doesn't exist → returns `nil`
- Tries to call `noteDurationScalar_` on `nil` → error

**Step 2: Why index 1?**
Looking at the configuration file structure:
```json
{
  "chordGroup1": {...},    // This is the ONLY chord group
  "flute-melody": {...}    // This is a REGULAR group, not chord
}
```

The external app is trying to send to chord group index 1, but:
- Chord groups: ["chordGroup1"] → only index 0 exists
- Regular groups: ["flute-melody"] → only index 0 exists

**Step 3: What's the code doing?**

From the error path (line 56-68):
```
< closed FunctionDef >
    arg groupName = nil         ← Failed to resolve
    var config = nil
    var rowNum = 1
< closed FunctionDef >
    var targetGroup = 1         ← Trying to use index 1
    var groupName = nil         ← Resolution failed
```

The `/chord` endpoint receives `targetGroup: 1` and tries to resolve it to a group name.

## The Code Flow

### 1. Chord endpoint receives message (layers-osc-core.scd ~line 802)
```supercollider
OSCFunc({|msg, time, addr|
    var jsonString, data, notes, targetGroup, groupName, maxDuration;

    jsonString = msg[1].asString;
    data = JSONlib.convertToSC(jsonString);
    notes = data[\notes];
    targetGroup = data[\metadata][\targetGroup];  // Gets 1 from JSON

    // Resolve chord group by index
    groupName = ~resolveChordGroup.(targetGroup);  // Returns nil!
```

### 2. Resolution function (~line 490)
```supercollider
~resolveChordGroup = { |target|
    var groupName, chordGroups;

    if (target.isKindOf(Integer) or: { target.isKindOf(Float) }) {
        var targetIndex = target.asInteger;
        groupName = ~oscLayers.indexToChordGroup[targetIndex];  // nil for index 1!

        if (groupName.isNil) {
            var available = ~vstManager.getChordGroupNames();
            "ERROR: Chord group index % not found.".format(targetIndex).error;
            "  → Available chord groups (count: %): %".format(
                available.size, available
            ).error;
            "  → Valid indices: 0 to %".format(available.size - 1).error;
        };
```

### 3. Tries to update duration scalar (fails on nil)
```supercollider
~updateLayerNoteDurationScalar.(groupName);  // groupName is nil
```

Inside that function:
```supercollider
config = ~oscLayers.dynamicConfigs[groupName];  // nil[nil] = nil
// ...
config.noteDurationScalar = ...;  // ERROR: nil doesn't understand noteDurationScalar_
```

## Why Is External App Sending Index 1?

The external app likely thinks:
- Index 0 = first group (any type)
- Index 1 = second group (any type)

But the system separates:
- Chord group indices (separate namespace)
- Regular group indices (separate namespace)

## Solutions

### Option 1: Better Error Handling (RECOMMENDED)
Prevent the crash when chord group not found:

**File**: layers-osc-core.scd, /chord endpoint

```supercollider
groupName = ~resolveChordGroup.(targetGroup);

// NEW: Return early if resolution failed
if (groupName.isNil) {
    "ERROR: Could not resolve chord group: %".format(targetGroup).error;
    ^this;  // Exit early, don't try to play
};

// Only proceed if we have a valid group
~updateLayerNoteDurationScalar.(groupName);
```

### Option 2: External App Fix
Update the external app to only send valid indices (0 for the only chord group).

### Option 3: Fallback to First Chord Group
If index out of range, use first available:

```supercollider
groupName = ~resolveChordGroup.(targetGroup);

if (groupName.isNil) {
    // Fallback to first chord group
    var chordGroups = ~vstManager.getChordGroupNames();
    if (chordGroups.size > 0) {
        groupName = chordGroups.first;
        "WARNING: Chord group index % not found, using % instead".format(
            targetGroup, groupName
        ).warn;
    } {
        "ERROR: No chord groups available".error;
        ^this;
    };
};
```

## Recommended Fix Plan

**Implement Option 1: Better Error Handling**

1. Add nil check after `~resolveChordGroup`
2. Return early if resolution failed
3. Prevent cascading errors on nil

This will:
- Stop the crash
- Show clear error message
- Allow system to continue functioning
- Help debug external app issues

## Implementation

**File**: layers-osc-core.scd, line ~820 (in /chord OSCFunc)

```supercollider
// Resolve chord group by index or name
groupName = ~resolveChordGroup.(targetGroup);

// NEW: Validate resolution succeeded
if (groupName.isNil) {
    "ERROR: Could not resolve chord group: %".format(targetGroup).error;
    "  Skipping chord playback".postln;
    ^this;  // Exit OSCFunc early
};

// Continue with valid group...
~updateLayerNoteDurationScalar.(groupName);
```

This prevents the `nil.noteDurationScalar_` error and provides clear debugging info.
