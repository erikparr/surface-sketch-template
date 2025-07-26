# Melody Navigation for Layers System - Implementation Plan

## Overview
Add MIDI note controls (27 = next, 22 = previous) to navigate through melodies with two modes:
- **Global Mode ON**: Navigate all layers together
- **Global Mode OFF**: Navigate only Layer 1

## Design Decision: Simplified Navigation
- When `globalNavigationMode` is ON → All layers change melody together
- When `globalNavigationMode` is OFF → Only Layer 1 changes melody
- MIDI Notes 22/27 control navigation in both modes
- Simpler than full per-layer navigation

## Implementation Plan

### Step 1: Add State Variables
**File**: `layers/layers-core.scd`
```supercollider
state: (
    // ... existing state ...
    globalNavigationMode: true,    // true = all layers, false = layer1 only
    currentMelodyIndex: 0,         // Shared melody index
    layer1MelodyIndex: 0           // Layer 1 specific index when global is off
)
```

### Step 2: Create Navigation Functions
**File**: `layers/layers-control.scd`
```supercollider
// Navigate to next/previous melody (simplified version)
~navigateLayerMelody = { |direction|
    var config, newIndex;
    
    if (~layers.state.globalNavigationMode) {
        // Global: Update shared index
        newIndex = if (direction == \next) {
            (~layers.state.currentMelodyIndex + 1)
        } {
            (~layers.state.currentMelodyIndex - 1).max(0)
        };
        ~layers.state.currentMelodyIndex = newIndex;
        
        // Each layer uses index modulo its own list size
        ~layers.configs.keysValuesDo { |layerName, cfg|
            if (cfg.melodyList.size > 0) {
                cfg.currentMelodyKey = cfg.melodyList[newIndex % cfg.melodyList.size];
            };
        };
        
        "Global navigation: All layers → index %".format(newIndex).postln;
    } {
        // Layer 1 only
        config = ~layers.configs[\layer1];
        if (config.melodyList.size > 0) {
            newIndex = if (direction == \next) {
                (~layers.state.layer1MelodyIndex + 1) % config.melodyList.size
            } {
                (~layers.state.layer1MelodyIndex - 1).wrap(0, config.melodyList.size - 1)
            };
            ~layers.state.layer1MelodyIndex = newIndex;
            config.currentMelodyKey = config.melodyList[newIndex];
            
            "Layer 1 navigation: % - %".format(newIndex, config.currentMelodyKey).postln;
        };
    };
};

// Get current melody for a layer
~getCurrentLayerMelody = { |layerName|
    var config = ~layers.configs[layerName];
    
    if (config.notNil) {
        // Use currentMelodyKey if set, otherwise use first melody
        config.currentMelodyKey ?? { 
            if (config.melodyList.size > 0) {
                config.melodyList[0]
            } {
                nil
            }
        }
    } {
        nil
    }
};
```

### Step 3: Update Dynamic Melody Getter
**File**: `layers/layers-playback.scd`

The existing `~getLayerMelodyDynamic` function already handles dynamic melody updates.
We need to modify it to respect navigation:

```supercollider
// Modify ~getLayerMelodyDynamic (around line 256)
~getLayerMelodyDynamic = { |layerName|
    var config = ~layers.configs[layerName];
    var melodyKey, melodyData;
    
    // Check for pending live updates first
    if (~layers.state.liveMelodyMode and: { 
        ~layers.state.pendingUpdates[layerName].notNil 
    }) {
        // Apply pending update immediately
        ~applyPendingUpdateForLayer.(layerName);
    };
    
    // Get current melody based on navigation mode
    melodyKey = ~getCurrentLayerMelody.(layerName);
    
    if (melodyKey.notNil) {
        melodyData = ~melodyDict[melodyKey];
    };
    
    melodyData
};
```

Note: The child ProcMod already calls `~getLayerMelodyDynamic` at the start of each loop, so navigation changes will automatically apply!

### Step 4: Add MIDI Controls
**File**: `layers/layers-control.scd`
```supercollider
// MIDI note controls for melody navigation
~setupLayerMelodyNavigation = {
    // Next melody (Note 27)
    MIDIdef.noteOn(\layersNextMelody, { |veloc, note|
        if (note == 27 && veloc > 0) {
            ~navigateLayerMelody.(\next);
        };
    }, 27);
    
    // Previous melody (Note 22)
    MIDIdef.noteOn(\layersPrevMelody, { |veloc, note|
        if (note == 22 && veloc > 0) {
            ~navigateLayerMelody.(\prev);
        };
    }, 22);
    
    "Layer melody navigation MIDI controls enabled (22=prev, 27=next)".postln;
};
```

### Step 5: Update Initialization
**File**: `layers/load-layers.scd`

Add after loading all components:
```supercollider
// Initialize MIDI navigation
~setupLayerMelodyNavigation.();
```

### Step 6: GUI Updates
**File**: `layers/layers-gui.scd`

Add checkbox for global navigation mode after the Single Note CC Mode checkbox:
```supercollider
// Global navigation mode checkbox
layout.add(
    CheckBox()
        .string_("Global Navigation Mode (All layers vs Layer 1 only)")
        .value_(~layers.state.globalNavigationMode)
        .action_({ |cb|
            ~layers.state.globalNavigationMode = cb.value;
            statusText.string = if (cb.value) {
                "Navigation: All layers (MIDI 22/27)"
            } {
                "Navigation: Layer 1 only (MIDI 22/27)"
            };
        })
);
```

Add to status update function:
```supercollider
// Show current navigation mode
if (~layers.state.globalNavigationMode) {
    statusString = statusString ++ " | Nav: Global";
} {
    statusString = statusString ++ " | Nav: Layer1";
};
```


## Testing

1. **Global Mode ON**:
   - Load multiple melodies into all layers
   - Press MIDI note 27 → All layers advance together
   - Press MIDI note 22 → All layers go back together

2. **Global Mode OFF**:
   - Press MIDI note 27 → Only Layer 1 advances
   - Press MIDI note 22 → Only Layer 1 goes back
   - Layers 2 & 3 stay on their current melodies

3. **During Playback**:
   - Changes apply on next loop iteration
   - Test with live melody mode enabled
   - Verify GUI checkbox updates status

## Summary

This simplified approach provides:
- **Global Mode**: Performance-friendly synchronized navigation
- **Layer 1 Mode**: Focus control on lead layer while others maintain pattern
- Same MIDI controls (22/27) work in both modes
- Easy to understand and perform with
- GUI checkbox for mode switching