# Dynamic Layers System - Implementation Plan

**Status**: Approved for Implementation
**Created**: 2025-10-17
**Context**: Complete redesign from hardcoded 3-layer to dynamic layer-per-VST-group architecture

---

## Design Decisions Summary

### 1. OSC Path Naming: Name-Based (Stable)
```supercollider
// NOT index-based (indices shift on add/remove)
❌ /group/0/note, /group/1/note

// YES name-based (stable, efficient)
✅ /group/bass_tuba/note, /group/sax/note
```

**Rationale**:
- O(1) add/remove operations (vs O(N) rebuild)
- Stable paths for external control
- Self-documenting
- Only recreate OSCFuncs when group deleted (7 funcs vs 7N funcs)

### 2. Reactive Updates: Event-Driven (No Polling)
```supercollider
// Hook into existing VST management GUI callbacks
~refreshLayerVSTGroups = { ~rebuildDynamicLayers.() };

// Called automatically when:
// - Group created via GUI
// - Group modified via GUI
// - VST added to/removed from group
```

**Rationale**:
- Zero overhead when idle
- Immediate response vs 2s polling delay
- Uses existing infrastructure (vst-management.scd lines 476, 503)

### 3. Melody Navigation: Independent Per-Group
```supercollider
// Each group maintains own melody list and index
config = (
    melodyList: [\melody1, \melody2, \melody3],
    currentMelodyIndex: 0
);

~nextMelodyForGroup.("Bass Tuba");  // Independent of other groups
```

**Rationale**: Different groups may have different melody sets

### 4. MIDI Row Assignment: Modulo-Based
```supercollider
~getMIDIRowForGroup = { |groupName|
    var idx = ~groupToIndex[groupName];  // Alphabetical index
    (idx % 3) + 1  // Returns 1, 2, or 3
};

// Group 0 → Row 1
// Group 1 → Row 2
// Group 2 → Row 3
// Group 3 → Row 1 (cycles)
```

**Rationale**: Only 3 MIDI rows available, all groups get control

### 5. SynthDef Strategy: Generic (One-Time Load)
```supercollider
// Single SynthDef used by all groups
SynthDef(\ccEnvelopeGeneric, { |ccNum=11, ...| }).add;

// NOT per-group SynthDefs (unnecessary)
```

**Rationale**: CC number is parameterized, no need for duplication

---

## Core Architecture

### Data Structure
```supercollider
~oscLayers = (
    state: (/* global state unchanged */),

    // CHANGED: Dynamic dictionaries instead of fixed configs
    configs: Dictionary.new,           // groupName → config
    responders: Dictionary.new,        // groupName → [7 OSCFuncs]

    // Index mappings for MIDI (alphabetical ordering)
    groupToIndex: Dictionary.new,      // "Bass Tuba" → 0
    indexToGroup: Dictionary.new,      // 0 → "Bass Tuba"
    groupToSanitized: Dictionary.new,  // "Bass Tuba" → \bass_tuba

    coordinator: nil
);
```

### Per-Group Configuration
```supercollider
config = (
    // Identity
    groupName: "Bass Tuba",
    sanitizedName: \bass_tuba,
    alphabeticalIndex: 0,
    vstGroup: "Bass Tuba",  // Direct 1:1 mapping

    // Independent melody navigation
    melodyList: [],
    currentMelodyIndex: 0,

    // Expression control
    expressionCC: 11 + alphabeticalIndex,  // Auto-assigned
    expressionMin: 10,
    expressionMax: 120,
    expressionDurationScalar: 1.0,

    // Playback state
    enabled: true,
    defaultDuration: 4.0,
    isPlaying: false,
    currentTask: nil,

    // Bend control
    bendControl: (/* unchanged */)
);
```

---

## OSC Path Structure

### Name Sanitization
```supercollider
~sanitizeGroupName = { |name|
    name.asString
        .toLower
        .replace(" ", "_")
        .replace("-", "_")
        .replace("/", "_")
        .replace("(", "")
        .replace(")", "")
        .replace("#", "")
        .asSymbol
};

// Examples:
"Bass Tuba"      → \bass_tuba
"Layer1"         → \layer1
"Sax Group #2"   → \sax_group_2
"Horn(s)"        → \horns
```

### OSC API (7 Paths Per Group)
```
/group/<sanitized_name>/note       - Trigger note
/group/<sanitized_name>/chord      - Trigger chord
/group/<sanitized_name>/cc         - Direct CC control
/group/<sanitized_name>/expression - CC envelope
/group/<sanitized_name>/bend       - Pitch bend envelope
/group/<sanitized_name>/melody     - Set melody
/group/<sanitized_name>/enabled    - Enable/disable
```

**System paths unchanged**: `/system/start`, `/system/stop`, etc.

---

## Core Functions Reference

### Layer Lifecycle
```supercollider
~createLayerForGroup.(groupName)
// - Sanitize name
// - Compute alphabetical index
// - Create config
// - Create 7 OSCFunc responders
// - Store in dictionaries
// - Update MIDI index maps

~removeLayerForGroup.(groupName)
// - Stop playback if running
// - Free 7 OSCFunc responders
// - Remove from all dictionaries
// - Update MIDI index maps

~rebuildDynamicLayers.()
// - Get current VST groups
// - Diff vs existing layers
// - Remove deleted groups
// - Add new groups
// - O(added + removed), not O(total)
```

### OSC Responders
```supercollider
~createGroupOSCResponders.(sanitizedName, config)
// Creates 7 OSCFunc instances with paths:
//   /group/<sanitized>/note
//   /group/<sanitized>/chord
//   /group/<sanitized>/cc
//   /group/<sanitized>/expression
//   /group/<sanitized>/bend
//   /group/<sanitized>/melody
//   /group/<sanitized>/enabled
// Returns array of responders
```

### MIDI Integration
```supercollider
~updateMIDIIndices.()
// - Get sorted group list
// - Rebuild groupToIndex/indexToGroup maps
// - Update alphabeticalIndex in all configs

~getMIDIRowForGroup.(groupName)
// Returns 1, 2, or 3 based on (alphabeticalIndex % 3)

~updateLayerExpressionParams.(groupName)
// - Get MIDI row via modulo
// - Read knobs from corresponding row
// - Update config.expressionMin/Max/DurationScalar
```

### Melody Navigation
```supercollider
~nextMelodyForGroup.(groupName)
// Increment currentMelodyIndex (wrap around)

~prevMelodyForGroup.(groupName)
// Decrement currentMelodyIndex (wrap around)

~setMelodyListForGroup.(groupName, melodyKeys)
// Set melodyList array, reset index to 0
```

---

## Integration Points

### VST Management GUI Hook
```supercollider
// In vst-management.scd (already exists at lines 476, 503)
if (~refreshLayerVSTGroups.notNil) {
    ~refreshLayerVSTGroups.()
};

// Our implementation:
~refreshLayerVSTGroups = {
    "VST groups changed, rebuilding layers...".postln;
    ~rebuildDynamicLayers.();
    if (~refreshLayersGUI.notNil) { ~refreshLayersGUI.() };
};
```

### Coordinator Updates
```supercollider
// In ~startLayersOSC, iterate dynamic configs:
~oscLayers.configs.keysValuesDo { |groupName, config|
    if (config.enabled and: { config.melodyList.size > 0 }) {
        ~startOSCLayer.(groupName, duration);
    };
};
```

### Chord Mode Routing
```supercollider
// Route chord notes across ALL groups dynamically:
if (~oscLayers.state.chordMode) {
    var allGroups = ~oscLayers.configs.keys.asArray.sort;
    notes.do { |note, idx|
        var targetGroup = allGroups[idx % allGroups.size];
        // Send to targetGroup...
    };
}
```

---

## Initialization Sequence

```supercollider
~initDynamicLayersSystem = {
    // 1. Load generic SynthDefs
    ~loadDynamicLayersSynthDefs.();

    // 2. Initialize containers
    ~oscLayers.configs = Dictionary.new;
    ~oscLayers.responders = Dictionary.new;
    ~oscLayers.groupToIndex = Dictionary.new;
    ~oscLayers.indexToGroup = Dictionary.new;
    ~oscLayers.groupToSanitized = Dictionary.new;

    // 3. Create layers from existing VST groups
    ~vstManager.getGroups().do { |groupName|
        ~createLayerForGroup.(groupName);
    };

    // 4. Create coordinator & system responders
    ~oscLayers.coordinator = ~createOSCCoordinator.();
    ~createSystemOSCResponders.();
    ~setupExternalOSCControl.();

    // 5. Register event-driven callback
    ~refreshLayerVSTGroups = { ~rebuildDynamicLayers.() };

    // 6. Backward compatibility
    ~setupDynamicCompatibility.();
};
```

---

## Implementation Checklist

### Phase 1: Core Functions
- [ ] `~sanitizeGroupName.(name)`
- [ ] `~createLayerForGroup.(groupName)`
- [ ] `~removeLayerForGroup.(groupName)`
- [ ] `~createGroupOSCResponders.(sanitizedName, config)`
- [ ] `~rebuildDynamicLayers.()`
- [ ] `~updateMIDIIndices.()`
- [ ] `~loadDynamicLayersSynthDefs.()`

### Phase 2: Melody Functions
- [ ] `~nextMelodyForGroup.(groupName)`
- [ ] `~prevMelodyForGroup.(groupName)`
- [ ] `~setMelodyListForGroup.(groupName, melodyKeys)`

### Phase 3: MIDI Integration
- [ ] `~getMIDIRowForGroup.(groupName)`
- [ ] `~updateLayerExpressionParams.(groupName)`
- [ ] `~updateAllLayerExpressionParams.()`

### Phase 4: System Integration
- [ ] Register `~refreshLayerVSTGroups` callback
- [ ] Update `~startOSCLayer` for dynamic iteration
- [ ] Update coordinator for dynamic configs
- [ ] Backward compatibility layer (`layer1/2/3` → first 3 groups)

### Phase 5: Testing
- [ ] Test with 2 groups
- [ ] Test with 5 groups
- [ ] Test with 10 groups
- [ ] Test add/remove groups dynamically
- [ ] Test MIDI row cycling (4+ groups)
- [ ] Test chord mode routing across N groups
- [ ] Test independent melody navigation
- [ ] Test backward compatibility

### Phase 6: Documentation
- [ ] Update layers/CLAUDE.md with new architecture
- [ ] Document OSC API changes
- [ ] Create migration guide
- [ ] Update GUI documentation (future)

---

## File Locations

### Files to Modify
- `layers/layers-osc-core.scd` - Core layer system (major rewrite)
- `layers/load-layers.scd` - Initialization
- `layers/layers-control.scd` - Control functions
- `setup/vst-management.scd` - Add hook if missing (line ~214)

### Files to Create
- `layers/layers-dynamic.scd` - New dynamic layer functions (optional split)

### Files to Update Documentation
- `layers/CLAUDE.md` - Add dynamic layers section
- `claude.md` - Reference new architecture

---

## Key Benefits

✅ **Unlimited layers** - No 3-layer restriction
✅ **O(1) updates** - Efficient add/remove
✅ **Stable OSC paths** - External control reliability
✅ **Self-documenting** - Readable path names
✅ **Event-driven** - Zero overhead when idle
✅ **MIDI cycling** - All groups controllable
✅ **Independent navigation** - Per-group melodies
✅ **Backward compatible** - Existing code works

---

## Migration Strategy

1. **Implement alongside existing system** (no breaking changes)
2. **Test thoroughly** with variable group counts
3. **Update GUI** for dynamic layer display
4. **Deprecate hardcoded references** gradually
5. **Release as v2.0** when stable

---

## Questions & Decisions Log

**Q: Index-based or name-based OSC paths?**
A: Name-based. More efficient (O(1) vs O(N)), stable, self-documenting.

**Q: Polling or event-driven updates?**
A: Event-driven via existing GUI callbacks. Zero overhead, immediate response.

**Q: Global or per-group melody navigation?**
A: Per-group. Each group manages own melody list independently.

**Q: MIDI row assignment for 4+ groups?**
A: Modulo-based cycling (group_index % 3 + 1). All groups controllable.

**Q: Per-group or generic SynthDef?**
A: Generic. CC number is parameterized, no duplication needed.

**Q: Automatic or manual layer rebuild?**
A: Automatic via `~refreshLayerVSTGroups` callback from GUI.

---

## Contact & Context

**Implementation timeline**: ~1 week
**Estimated effort**: Core (2d) + OSC (1d) + MIDI (1d) + Testing (2d)

**For future sessions**: Read this document first, then check implementation checklist progress.
