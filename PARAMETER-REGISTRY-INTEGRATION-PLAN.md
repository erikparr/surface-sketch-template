# ParameterRegistry Integration Plan

## Current State (2025-01-19)

### Problem
ParameterRegistry exists and is properly designed, but **MIDI parameter updates bypass it completely**.

### Evidence
- ParameterRegistry is initialized: `~paramRegistry = LiveParameterRegistry.new(true)` (line 2222)
- Parameters ARE registered with specs and callbacks (lines 1736-1835)
- BUT: `~updateLayerExpressionParams` reads MIDI directly via `~midiController.getKnobRow()` (lines 1955-1957)

### Architecture Gap

```
┌──────────────────────────────────────────────────────────────┐
│                     DESIGNED FLOW (NOT USED)                 │
└──────────────────────────────────────────────────────────────┘

MIDI Knob Change
    ↓
~updateParameterRegistryFromMIDI()  ← exists but not called
    ↓
ParameterRegistry.updateParameter()
    ↓
Callbacks fire → update config.ccControl values
    ↓
/chord playback uses updated values


┌──────────────────────────────────────────────────────────────┐
│                   CURRENT FLOW (BYPASSES REGISTRY)           │
└──────────────────────────────────────────────────────────────┘

/chord OSC message received
    ↓
~playChordToGroupJSON() calls ~updateLayerExpressionParams()
    ↓
DIRECTLY reads: ~midiController.getKnobRow(rowNum, 5)
    ↓
Manual mapping: .linlin(0.0, 1.0, 0, 127).asInteger
    ↓
Writes to config.ccControl.expressionMin
    ↓
Chord plays with these values
```

## Root Cause

**The missing link:** MIDI knob changes are NOT routed through ParameterRegistry.

Looking at line 1898:
```supercollider
// Update ParameterRegistry (which triggers callbacks to update configs)
~updateParameterRegistryFromMIDI.(rowNum, knobNum, value);
```

This function exists but is likely NOT being called by the MIDI callback system.

## Options

### Option A: Keep Current Direct MIDI Approach (RECOMMENDED FOR NOW)
**Rationale:** System is working after recent fixes, minimal risk

**Pros:**
- ✓ Simple, direct, proven to work
- ✓ Low coupling, easy to debug
- ✓ No refactoring required

**Cons:**
- ✗ Harder to extend with OSC/automation control
- ✗ Manual range mapping everywhere
- ✗ No input source arbitration

**Action:** Document current approach, remove unused ParameterRegistry code or mark as "future enhancement"

### Option B: Fully Integrate ParameterRegistry (FUTURE ENHANCEMENT)
**Rationale:** Better architecture, but requires system-wide refactor

**Pros:**
- ✓ Single source of truth for all parameters
- ✓ Automatic ControlSpec mapping
- ✓ Multiple input sources (MIDI, OSC, automation)
- ✓ Change tracking and callbacks

**Cons:**
- ✗ Requires refactoring all MIDI parameter reads
- ✗ Higher complexity
- ✗ Risk of breaking current working system

**Action:**
1. Create MIDI callback hook that updates ParameterRegistry on knob changes
2. Refactor `~updateLayerExpressionParams` to read from ParameterRegistry instead of direct MIDI
3. Test thoroughly

### Option C: Hybrid Approach
**Rationale:** Use ParameterRegistry for OSC/external control, keep direct MIDI

**Pros:**
- ✓ Allows external parameter control via ParameterRegistry
- ✓ Keeps working MIDI system intact
- ✓ Gradual migration path

**Cons:**
- ✗ Two parallel systems (confusing)
- ✗ Potential inconsistency

## Recommendation

**SHORT TERM: Option A**
- Current system works after recent MIDI parameter fixes
- Don't break what's working
- Document the architecture gap

**LONG TERM: Option B**
- When adding OSC parameter control or automation
- When MIDI parameter count grows (currently 4 per group)
- When needing parameter snapshots/presets

## Implementation Plan (If choosing Option B)

### Phase 1: Connect MIDI to ParameterRegistry
```supercollider
// In MIDI callback system (setup/midi-setup.scd or similar)
MIDIFunc.cc({ |val, num, chan, src|
    var rowNum, knobNum, addressKey, parameterId;

    // Determine row/knob from CC number
    rowNum = /* calculate from num */;
    knobNum = /* calculate from num */;

    // Update ParameterRegistry
    addressKey = ("row" ++ rowNum ++ "_knob" ++ knobNum).asSymbol;
    parameterId = ~paramRegistry.getParameterByAddress(\midiCC, addressKey);

    if (parameterId.notNil) {
        // Registry automatically maps via ControlSpec and fires callbacks
        ~paramRegistry.updateParameter(parameterId, val / 127.0, \midi);
    };
});
```

### Phase 2: Refactor Parameter Reads
```supercollider
// BEFORE (current):
ccControl.expressionMin = ~midiController.getKnobRow(rowNum, 5).linlin(0.0, 1.0, 0, 127).asInteger;

// AFTER (using registry):
var paramId = ("group_" ++ groupName ++ "_expressionMin").asSymbol;
ccControl.expressionMin = ~paramRegistry.getParameterValue(paramId);
// Value already mapped via ControlSpec(0, 127, \lin, 1, 10)
```

### Phase 3: Remove Direct MIDI Reads
- Delete manual `.linlin()` mapping code
- Remove `~midiController.getKnobRow()` calls from parameter update functions
- ParameterRegistry callbacks handle all updates

## Testing Strategy

1. **Before refactor:** Document current MIDI parameter values
2. **During refactor:** Run test-chord-midi-integration.scd after each change
3. **After refactor:** Verify:
   - MIDI knobs update parameters (check logs)
   - Parameters apply to chord playback (check durations, expression)
   - ParameterRegistry callbacks fire (debug mode logs)
   - No performance degradation

## Files Affected

- `layers/layers-osc-core.scd` - Parameter update functions (lines 1934-2021)
- `setup/midi-setup.scd` - MIDI callback routing (needs to update registry)
- `test-chord-midi-integration.scd` - Add ParameterRegistry validation tests

## Questions to Answer

1. **Where are MIDI callbacks currently registered?**
   - Check `setup/midi-setup.scd` for `MIDIFunc.cc` definitions
   - Find where `~midiController.getKnobRow()` gets its values

2. **Is `~updateParameterRegistryFromMIDI` ever called?**
   - Grep for calls to this function
   - If not, this is the missing link

3. **Should we keep both systems or migrate fully?**
   - Current: Direct MIDI works, ParameterRegistry unused
   - Decision: Document now, migrate when needed

## Status: DOCUMENTATION ONLY (No changes recommended at this time)

Current system is working after MIDI parameter fixes. ParameterRegistry integration is a good future enhancement but not critical for current functionality.
