# Expression Envelope Diagnosis Plan

## Evidence from output.txt

### What IS Working:
1. ✅ Expression envelope synth is being created
2. ✅ CC messages ARE being sent to the VST
3. ✅ MIDI knob values ARE being read (Min/Max changes)
4. ✅ Routing is correct (flute-melody group targeted)

### What We See:
```
Line 1:  [/midi/cc] Group: flute-melody, CC12: 58 → 1 VSTs
Line 25: [/midi/cc] Group: flute-melody, CC12: 77 → 1 VSTs
Line 77: [/midi/cc] Group: flute-melody, CC12: 99 → 1 VSTs
Line 96: [/midi/cc] Group: flute-melody, CC12: 115 → 1 VSTs
```

**CC12 messages ARE being sent to "1 VSTs" (SWAM Alto Flute)**

## The Problem

The VST (SWAM Alto Flute 3) is **receiving CC12** but **not responding to it**.

## Possible Causes

### 1. VST Not Mapped to CC12
SWAM instruments typically respond to:
- **CC1**: Modulation Wheel
- **CC2**: Breath Controller
- **CC11**: Expression (standard)
- **CC74**: Brightness

**CC12** is not a standard SWAM controller!

### 2. Why CC12?
From the code:
```supercollider
expressionCC: 11 + alphabeticalIndex
```

Groups in alphabetical order:
- chordGroup1 (index 0) → CC11
- flute-melody (index 1) → CC12 ← **This is the problem**

### 3. Alphabetical Index Check
From config:
```json
{
  "chordGroup1": {...},    // First alphabetically → index 0 → CC11
  "flute-melody": {...}    // Second alphabetically → index 1 → CC12
}
```

## Root Cause

**flute-melody is alphabetical index 1, so it gets CC12 instead of CC11.**

SWAM Alto Flute doesn't respond to CC12 by default - it needs CC11 (Expression) or CC1 (Mod Wheel) or CC2 (Breath).

## Solution Options

### Option 1: Use CC11 for All Groups (RECOMMENDED)
Change to use standard MIDI Expression CC for all groups.

**File**: layers-osc-core.scd, line ~1047
```supercollider
// BEFORE:
expressionCC: 11 + alphabeticalIndex,

// AFTER:
expressionCC: 11,  // Standard MIDI Expression CC for all groups
```

**Pros**:
- Works with all VSTs that support expression
- Standard MIDI practice
- No CC conflicts

**Cons**:
- All groups share same CC (but separate instances, so OK)

### Option 2: Use Different Standard CCs Per Group
Map to standard MIDI CCs that SWAM supports:

```supercollider
// Map alphabetical index to standard CCs
var ccMap = [11, 1, 74, 7];  // Expression, Mod, Brightness, Volume
expressionCC: ccMap.wrapAt(alphabeticalIndex)
```

**Pros**:
- Different control per group
- Uses only standard CCs

**Cons**:
- Different CCs behave differently
- More complex

### Option 3: Make CC Configurable
Add CC selection to group config/UI.

**Pros**:
- Full flexibility
- User can match VST

**Cons**:
- More implementation work
- Requires UI changes

## Recommended Fix

**Use Option 1: CC11 for all groups**

This is the simplest, most compatible solution. Expression (CC11) is the standard MIDI CC for dynamic control and is supported by virtually all VSTs including SWAM.

## Implementation

1. Change layers-osc-core.scd line 1047 and 1062
2. Test with flute-melody
3. Verify CC11 messages reach VST
4. Confirm VST responds to expression envelope

## Verification Steps

1. Check alphabetical index: `~oscLayers.groupToIndex[\flute-melody]`
2. Check assigned CC: `~oscLayers.dynamicConfigs[\flute-melody].ccControl.expressionCC`
3. Monitor /midi/cc messages for CC11 instead of CC12
4. Verify SWAM Alto Flute responds to CC11
