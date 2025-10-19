# Dynamic Layers MIDI Parameter Integration - Issue Analysis & Design Fix

**Date**: 2025-10-19
**Status**: Design Proposal - Awaiting Review
**Related Files**:
- `layers/layers-osc-core.scd` (Dynamic layers system)
- `setup/midi-setup.scd` (MIDI controller initialization)
- `etc/ParameterRegistry/ParameterRegistry.sc` (Parameter management)
- `etc/VSTManager/VSTManager.sc` (Group type information)

---

## Executive Summary

The dynamic layers system successfully creates layers per VST group and assigns MIDI rows via modulo mapping, but **MIDI parameter updates are never applied**. Additionally, **chord group types are not preserved** in dynamic layer configs, breaking multi-instrument routing. Expression envelopes trigger but use default values, giving the appearance of being broken.

---

## Issue #1: MIDI Parameters Never Applied to Dynamic Groups

### Current Behavior
- Dynamic layers created with **hardcoded defaults**: `expressionMin: 10, expressionMax: 120, expressionDurationScalar: 1.0`
- MIDI knob changes have **zero effect** on dynamic group expression parameters
- Functions exist to read MIDI values but are **never called automatically**

### Root Cause Analysis

#### Functions Exist But Aren't Called
```supercollider
// LINE 1790-1834: Function to update single group from MIDI
~updateLayerExpressionParams = { |groupName|
    rowNum = ~getMIDIRowForGroup.(groupName);
    ccControl.expressionMin = ~midiController.getKnobRow(rowNum, 5);
    ccControl.expressionMax = ~midiController.getKnobRow(rowNum, 6);
    ccControl.expressionDurationScalar = ~midiController.getKnobRow(rowNum, 4).linlin(0.0, 1.0, 0.001, 1.0);
};

// LINE 1837-1853: Function to update all groups
~updateAllLayerExpressionParams = {
    ~oscLayers.dynamicConfigs.keysValuesDo { |groupName, config|
        ~updateLayerExpressionParams.(groupName);
    };
};
```

**Problem**: These functions are:
1. ✅ Correctly implemented
2. ✅ Use proper MIDI row mapping (`~getMIDIRowForGroup`)
3. ✅ Read correct knobs (Row X, Knobs 4/5/6)
4. ❌ **NEVER CALLED** except in test suite (line 2291)

#### No MIDI Callback Integration
```supercollider
// OLD SYSTEM (layer1/2/3) - LINE 974-1051
~updateAllLayerExpressionParams = {
    [\layer1, \layer2, \layer3].do { |layerKey, index|
        // Gets called by MIDI control mapping system
        // Integrates with ~processTemplateKnobValues
    };
};
```

**Problem**: Legacy system integrated with MIDI callbacks, dynamic system doesn't.

#### Where Updates Should Happen
1. **On layer creation** (line 1300-1376) - ❌ Missing
2. **On MIDI knob change** - ❌ No callback registered
3. **Before playback starts** (line 1919-2017) - ❌ Missing
4. **When VST groups rebuild** (line 1909-1913) - ❌ Missing

### Impact
- **User Experience**: MIDI knobs appear broken for dynamic groups
- **Workaround**: None - parameters are permanently stuck at defaults
- **Severity**: **HIGH** - Core feature non-functional

---

## Issue #2: Chord Group Type Not Preserved

### Current Behavior
- VSTManager stores group type (`\regular` or `\chord`) correctly
- ConfigurationManager saves/loads group type correctly
- Dynamic layers system **ignores group type entirely**
- All groups treated as regular groups during playback

### Root Cause Analysis

#### VSTManager Provides Type Information
```supercollider
// VSTManager.sc LINE 474-479
getGroupType { |groupName|
    if (groups[groupName].notNil) {
        ^groups[groupName].type  // Returns \regular or \chord
    };
    ^nil;
}

isChordGroup { |groupName|
    ^(groups[groupName].notNil and: {
        groups[groupName].type == \chord
    });
}
```

#### Dynamic Layers Don't Use It
```supercollider
// LINE 1300-1376: ~createLayerForGroup
~createLayerForGroup = { |groupName|
    config = (
        groupName: groupName,
        sanitizedName: sanitizedName,
        alphabeticalIndex: alphabeticalIndex,
        vstGroup: groupName,

        // ❌ MISSING: groupType field
        // Should be: groupType: ~vstManager.getGroupType(groupName),

        melodyList: [],
        expressionCC: 11 + alphabeticalIndex,
        // ... rest of config
    );
};
```

#### Playback Doesn't Check Type
```supercollider
// LINE 1985-1992: ~startDynamicGroupPlayback
pattern.do { |note, i|
    var when, noteDuration;
    when = i * noteInterval;
    noteDuration = (noteInterval * 0.8) * config.noteDurationScalar;

    SystemClock.sched(when, {
        // ❌ ALWAYS uses /note which sends to ALL VSTs
        NetAddr.localAddr.sendMsg('/group/' ++ sanitizedName ++ '/note', note, velocity, noteDuration);

        // ❌ SHOULD check config.groupType and route differently:
        // - Regular groups: /note to all VSTs
        // - Chord groups: Each note to specific VST (round-robin or per-note assignment)
    });
};
```

### Expected Behavior: Chord Groups

**Chord groups should**:
1. Store `groupType: \chord` in dynamic config
2. During playback, route each note to a different VST:
   - Note 0 → VST 0
   - Note 1 → VST 1
   - Note 2 → VST 2
   - etc.

**Current /group/<name>/note responder** (line 1424-1445):
```supercollider
// Sends to ALL VSTs (wrong for chord groups)
instances.do { |vst|
    vst.midi.noteOn(0, note, velocity);
};

// Should be:
if (config.groupType == \chord) {
    // Send to specific VST based on note index
} else {
    // Send to all VSTs (regular behavior)
}
```

### Impact
- **User Experience**: Chord groups don't work as designed
- **Workaround**: None - feature completely broken
- **Severity**: **CRITICAL** - Recent feature addition non-functional

---

## Issue #3: Expression Envelopes Appear Broken

### Current Behavior
- Expression envelopes **ARE triggered** correctly (line 1996-1998)
- But use **stale parameter values** (never updated from MIDI)
- User perceives envelopes as "not working"

### Root Cause
```supercollider
// LINE 1996-1998: Expression triggered during playback
if (config.ccControl.enabled) {
    NetAddr.localAddr.sendMsg('/group/' ++ sanitizedName ++ '/expression', playDuration);
};

// LINE 1497-1525: Expression responder receives message
OSCFunc({ |msg|
    duration = msg[1] ? 1.0;
    ccControl = config.ccControl;  // ❌ Uses config values (never updated from MIDI!)

    if (ccControl.enabled) {
        Synth(\ccEnvelopeGeneric, [
            \start, ccControl.expressionMin,      // ❌ Always 10 (default)
            \peak, ccControl.expressionMax,       // ❌ Always 120 (default)
            \attackTime, duration * ccControl.expressionDurationScalar,  // ❌ Always 1.0 (default)
            \ccNum, ccControl.expressionCC,
        ]);
    };
}, '/group/' ++ sanitizedName ++ '/expression')
```

### Impact
- **User Experience**: Envelopes play with wrong min/max/duration, user thinks they're broken
- **Severity**: **MEDIUM** - Feature technically works but produces wrong output

---

## Proposed Design Fix

### Phase 1: Add MIDI Parameter Auto-Update (CRITICAL)

#### 1.1: Update Parameters on Layer Creation
```supercollider
// LINE ~1375: Add to ~createLayerForGroup
~createLayerForGroup = { |groupName|
    // ... existing code ...

    // Replace placeholder with full configuration
    ~oscLayers.dynamicConfigs[groupName] = config;

    // NEW: Update MIDI parameters immediately after creation
    if (~midiController.notNil) {
        ~updateLayerExpressionParams.(groupName);
        ~updateLayerNoteDurationScalar.(groupName);
    };

    // Create OSC responders for this group
    ~createGroupOSCResponders.(sanitizedName, config);
};
```

#### 1.2: Register MIDI Change Callback
```supercollider
// NEW FUNCTION: Register callback for MIDI knob changes
~registerDynamicLayersMIDICallback = {
    if (~midiController.notNil) {
        // Hook into MIDIController's knob change event
        // (Requires investigation of MIDIController class callback system)

        // OPTION A: Register callback with MIDIController
        ~midiController.onKnobChange = { |rowNum, knobNum, value|
            // Update affected groups for this MIDI row
            ~updateGroupsForMIDIRow.(rowNum);
        };

        // OPTION B: Use existing template system
        if (~processTemplateKnobValues.notNil) {
            // Wrap existing function to also update dynamic layers
            ~originalProcessTemplateKnobValues = ~processTemplateKnobValues;
            ~processTemplateKnobValues = {
                ~originalProcessTemplateKnobValues.();  // Call original
                ~updateAllLayerExpressionParams.();     // Update dynamic layers
            };
        };

        "Registered MIDI callback for dynamic layers".postln;
    };
};

// NEW HELPER: Update all groups on specific MIDI row
~updateGroupsForMIDIRow = { |rowNum|
    ~oscLayers.dynamicConfigs.keysValuesDo { |groupName, config|
        if (~getMIDIRowForGroup.(groupName) == rowNum) {
            ~updateLayerExpressionParams.(groupName);
            ~updateLayerNoteDurationScalar.(groupName);
        };
    };
};
```

#### 1.3: Update Parameters Before Playback
```supercollider
// LINE ~1926: Add to ~startDynamicGroupPlayback
~startDynamicGroupPlayback = { |groupName, targetGroup = nil, loop = true, duration = nil|
    config = ~oscLayers.dynamicConfigs[groupName];

    if (config.isNil) {
        "Group % not found in dynamic layers".format(groupName).warn;
        ^false
    };

    // NEW: Refresh MIDI parameters before playback starts
    if (~midiController.notNil) {
        ~updateLayerExpressionParams.(groupName);
        ~updateLayerNoteDurationScalar.(groupName);
    };

    // ... rest of existing playback logic ...
};
```

### Phase 2: Add Chord Group Type Support (CRITICAL)

#### 2.1: Store Group Type in Config
```supercollider
// LINE ~1319: Modify ~createLayerForGroup
config = (
    // Identity
    groupName: groupName,
    sanitizedName: sanitizedName,
    alphabeticalIndex: alphabeticalIndex,
    vstGroup: groupName,

    // NEW: Store group type from VSTManager
    groupType: if (~vstManager.notNil) {
        ~vstManager.getGroupType(groupName) ?? \regular
    } {
        \regular
    },

    // Independent melody navigation
    melodyList: [],
    currentMelodyIndex: 0,
    // ... rest of config ...
);
```

#### 2.2: Update Note Responder to Handle Chord Groups
```supercollider
// LINE 1424-1445: Modify /group/<sanitized>/note responder
oscPath = '/group/' ++ sanitizedName ++ '/note';
responders = responders.add(
    OSCFunc({ |msg|
        var note, velocity, duration, instances;
        note = msg[1];
        velocity = msg[2] ? 127;
        duration = msg[3] ? 0.5;

        if (~vstManager.notNil) {
            instances = ~vstManager.getTargetInstances(groupName);

            // NEW: Check group type and route accordingly
            if (config.groupType == \chord) {
                // CHORD GROUP: Send to single VST (round-robin or note index)
                // For now, simple round-robin on each note
                var vstArray = instances.values.asArray;
                var targetVST = vstArray.wrapAt(note % vstArray.size);

                targetVST.midi.noteOn(0, note, velocity);
                if (duration > 0) {
                    SystemClock.sched(duration, {
                        targetVST.midi.noteOff(0, note, 0);
                    });
                };
            } {
                // REGULAR GROUP: Send to all VSTs (existing behavior)
                instances.do { |vst|
                    vst.midi.noteOn(0, note, velocity);
                    if (duration > 0) {
                        SystemClock.sched(duration, {
                            vst.midi.noteOff(0, note, 0);
                        });
                    };
                };
            };
        };
    }, oscPath)
);
```

#### 2.3: Update Playback for Chord Groups
```supercollider
// LINE 1984-1998: Modify ~startDynamicGroupPlayback note sending
if (config.groupType == \chord) {
    // CHORD GROUP: Route each note to different VST
    var vstArray = ~vstManager.getTargetInstances(groupName).values.asArray;

    pattern.do { |note, i|
        var when, noteDuration, vstIndex;
        when = i * noteInterval;
        noteDuration = (noteInterval * 0.8) * config.noteDurationScalar;
        vstIndex = i % vstArray.size;  // Round-robin assignment

        SystemClock.sched(when, {
            // Send to specific VST
            vstArray[vstIndex].midi.noteOn(0, note, velocity);
            SystemClock.sched(noteDuration, {
                vstArray[vstIndex].midi.noteOff(0, note, 0);
            });
        });
    };
} {
    // REGULAR GROUP: Use existing broadcast logic
    pattern.do { |note, i|
        var when, noteDuration;
        when = i * noteInterval;
        noteDuration = (noteInterval * 0.8) * config.noteDurationScalar;

        SystemClock.sched(when, {
            NetAddr.localAddr.sendMsg('/group/' ++ sanitizedName ++ '/note', note, velocity, noteDuration);
        });
    };
};
```

### Phase 3: Integration with ParameterRegistry (OPTIONAL)

The existing ParameterRegistry.sc provides a robust parameter management system with:
- Change callbacks
- Input source tracking
- Address mapping (MIDI CC, OSC, semantic)

**Recommendation**: Consider migrating dynamic layers to use ParameterRegistry for:
1. Unified parameter management across MIDI/OSC
2. Automatic change propagation
3. Parameter persistence
4. Multi-source conflict resolution

**Example Integration**:
```supercollider
~initDynamicLayersWithRegistry = {
    // Register parameters for each group
    ~oscLayers.dynamicConfigs.keysValuesDo { |groupName, config|
        var paramPrefix = ("group_" ++ groupName ++ "_").asSymbol;

        // Register expression parameters
        ~paramRegistry.registerParameter(
            (paramPrefix ++ "expressionMin").asSymbol,
            ControlSpec(0, 127, \lin, 1, 10)
        );

        // Add MIDI address mapping
        var rowNum = ~getMIDIRowForGroup.(groupName);
        ~paramRegistry.addAddress(
            (paramPrefix ++ "expressionMin").asSymbol,
            \midiCC,
            "row%_knob5".format(rowNum)
        );

        // Register change callback
        ~paramRegistry.onParameterChange(
            (paramPrefix ++ "expressionMin").asSymbol,
            { |paramId, oldVal, newVal, source|
                config.ccControl.expressionMin = newVal;
            }
        );
    };
};
```

---

## Implementation Priority

### CRITICAL (Must Fix)
1. ✅ **Phase 1.1**: Update MIDI parameters on layer creation
2. ✅ **Phase 1.3**: Update MIDI parameters before playback
3. ✅ **Phase 2.1**: Store group type in config
4. ✅ **Phase 2.2**: Update note responder for chord groups

### HIGH (Should Fix)
5. ✅ **Phase 1.2**: Register MIDI change callback (Option B: wrap template system)
6. ✅ **Phase 2.3**: Update playback for chord groups

### MEDIUM (Nice to Have)
7. ⏸️ **Phase 3**: Integrate with ParameterRegistry (future enhancement)

---

## Testing Plan

### Test 1: MIDI Parameter Updates
```supercollider
// Setup
~initDynamicLayersSystem.();

// Test: Change MIDI knobs for Row 1
// Expected: Group on Row 1 should update expressionMin/Max/DurationScalar

// Verify
~testDynamicLayersPhase3MIDIIntegration.();
```

### Test 2: Chord Group Routing
```supercollider
// Setup: Load chord group config
~configManager.loadConfig("chord-btuba");

// Test: Send 3-note chord to chord group
NetAddr("127.0.0.1", 7000).sendMsg('/chord', "{
  \"notes\": [
    {\"midi\": 48, \"vel\": 0.8, \"dur\": 1.0},
    {\"midi\": 52, \"vel\": 0.8, \"dur\": 1.0},
    {\"midi\": 55, \"vel\": 0.8, \"dur\": 1.0}
  ],
  \"metadata\": {\"targetGroup\": 0}
}");

// Expected:
// - Note 48 → VST 0 (SWAM Bass Tuba 01)
// - Note 52 → VST 1 (SWAM Bass Tuba 02)
// - Note 55 → VST 2 (SWAM Bass Tuba 00)

// Verify: Listen for distinct timbres on each note
```

### Test 3: Expression Envelopes with MIDI
```supercollider
// Setup
~initDynamicLayersSystem.();

// Set MIDI knobs for Row 1:
// - Knob 5 (Expression Min): 50
// - Knob 6 (Expression Max): 100
// - Knob 4 (Duration Scalar): 0.5

// Trigger expression
var groupName = ~oscLayers.dynamicConfigs.keys.asArray.first;
NetAddr.localAddr.sendMsg('/group/' ++ groupName ++ '/expression', 2.0);

// Expected: Envelope from 50→100 over 1.0s (2.0 * 0.5)
```

---

## Backward Compatibility

### Legacy Layer System (layer1/2/3)
- Preserve existing `~updateAllLayerExpressionParams` for layer1/2/3 (line 974)
- Rename dynamic version to `~updateAllDynamicLayerExpressionParams` to avoid collision
- OR: Check if `~oscLayers.dynamicConfigs.size > 0` to determine which system to update

### Migration Path
1. Fix dynamic layers system first (this proposal)
2. Test with existing VST configurations
3. Gradually migrate users to dynamic-only system
4. Deprecate legacy layer1/2/3 system in future release

---

## Questions for Review

1. **MIDI Callback Approach**: Should we use Option A (direct MIDIController callback) or Option B (wrap existing template system)?
   - Option A: Cleaner, more direct
   - Option B: Safer, preserves existing template logic

2. **Chord Group Routing**: Should we use:
   - Round-robin (note 0→VST 0, note 1→VST 1, note 2→VST 2, note 3→VST 0, ...)
   - Fixed assignment (note index % VST count)
   - Per-note metadata (allow external control of routing)

3. **ParameterRegistry Migration**: Should we integrate with ParameterRegistry now or defer to future work?
   - Now: More robust, unified parameter system
   - Later: Smaller scope for this fix, less risk

4. **Function Naming**: Rename `~updateAllLayerExpressionParams` to avoid collision?
   - Rename to `~updateAllDynamicLayerExpressionParams`
   - OR: Make it detect which system to update automatically

---

## References

- **Dynamic Layers Design**: `layers/DYNAMIC-LAYERS-DESIGN.md`
- **Phase 1 Implementation**: `layers/PHASE-1-IMPLEMENTATION.md`
- **VSTManager API**: `etc/VSTManager/VSTManager.sc`
- **ParameterRegistry**: `etc/ParameterRegistry/ParameterRegistry.sc`
- **MIDI Setup**: `setup/midi-setup.scd`
- **Recent Commits**:
  - `8e44366` - Fix chord group configuration saving
  - `5c2d097` - Add chord groups system with JSON OSC endpoints
  - `8abd6ac` - Fix expression envelopes for arpeggio chord mode

---

**Ready for review and implementation approval.**
