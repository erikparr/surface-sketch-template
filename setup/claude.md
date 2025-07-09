# Surfacing Setup System Documentation

## Overview
The Surfacing setup system is a modular SuperCollider environment for VST instrument control, MIDI mapping, and musical clip management. Files load in dependency order via `_setup-loader.scd`.

## Core Components

### 1. VSTManager (`VSTManager.sc`)
Central controller for VST instances with group management.

**Key Methods:**
- `addVST(name, synth, path, editor, groupName)` - Add VST instance
- `getInstances()` - Get all VST controllers
- `getTargetInstances(groupName)` - Get instances by group (nil/"all" = all)
- `setProgramByName(vstName, programName)` - Set VST program
- `createGroup(name, vstNames)` - Create VST group
- `setActiveGroup(groupName)` - Set active group for operations

**Important:** VST instances store controller, synth, path, group, and params.

### 2. MIDIController (`MIDIController.sc`)
Handles MIDI I/O, CC mapping, velocity control, and note routing.

**Key Features:**
- 9 sliders, configurable knobs (MIDIMix preset: 3 rows × 8 columns)
- Multi-channel/multi-instrument modes for VST routing
- Programmed mode with snapshots
- Mapping mode integration for dynamic CC routing
- Manual velocity override

**Access Methods:**
- `getSliderValue(index)` - Get slider 0-8
- `getKnobRow(row, pos)` - Get knob by row (1-3) and position (1-8)
- `getKnobValueByCC(ccNum)` - Get knob by CC number
- `setMappingMode(bool)` - Enable/disable MIDI control mapping

### 3. ProcMod (`ProcMod.sc`)
Modular processing units with envelope control and scheduling.

**Key Features:**
- Envelope-based amplitude control
- Group/target management
- Release time handling
- GUI support with meters
- MIDI CC mapping for amplitude

**Usage Pattern:**
```supercollider
ProcMod(env, amp, id, group, addAction, target, function, releaseFunc)
```

## Setup Files (Loading Order)

### 1. `synths-setup.scd`
**SynthDefs:** vstHost, insert, BendEnvelope, ccEnvelope
- VST hosting synthdefs with 1-3 channel variants
- Envelope generators for pitch bend and CC control

### 2. `vstplugin-setup.scd`
**Initializes:** VSTManager, loads default VSTs
- Creates 3 Bass Tuba instances in "Bass Tuba" group
- Opens VST editors after 5s delay
- Excludes problematic plugins during search

### 3. `vst-management.scd`
**GUI for:** Loading VSTs, managing groups
- Load VSTs from file list
- Create/manage groups
- Toggle multi-instrument mode
- Set manual velocity/expression overrides

### 4. `midi-setup.scd`
**Initializes:** MIDIController with VST instances
- MIDIMix preset configuration
- Multi-channel/instrument routing
- Mapping system integration

### 5. `midi-control-mapping.scd`
**GUI for:** Row-to-group-to-template mapping
- Control templates (Expression/Timing)
- Row enable/disable
- State persistence

### 6. `osc-setup.scd`
**OSC handlers:** /bend, /expression, /expression2
- Pitch bend routing to VST groups
- CC control for layers 1 & 2

### 7. `melody-management.scd` (commented out)
**Features:** Melody data management
- JSON persistence
- Active/inactive toggles
- MIDI recording integration

## Key Data Structures

### VST Instance
```
(
  name: String,
  controller: VSTPluginController,
  synth: Synth,
  path: String,
  group: String,
  params: Dictionary
)
```

### MIDI Mapping Row
```
(
  enabled: Boolean,
  vstGroup: String,
  template: Symbol
)
```

### Control Template
```
(
  name: String,
  knobMappings: Array[
    (pos: Integer, param: Symbol, range: Array[min, max])
  ]
)
```

## Common Operations

### Load VST and Add to Group
```supercollider
~vstManager.addVST(name, synth, vstPath, editor: true, groupName);
```

### Access VST Parameters
```supercollider
~vstManager.getInstances[vstName].set(param, value);
```

### Get MIDI Values
```supercollider
~midiController.getSliderValue(0);  // First slider
~midiController.getKnobRow(1, 1);   // Row 1, Position 1
```

### Create ProcMod Player
```supercollider
ProcMod.play(env, amp, id, group, function: {|group, envbus, server|
    // Your synthesis code
});
```

## Important Notes

1. **Load Order:** Files must load in sequence due to dependencies
2. **VST Channels:** VSTs always use channel 0 internally
3. **MIDI Mapping:** When enabled, overrides normal knob processing
4. **Groups:** "All" or nil targets all VST instances
5. **Async Operations:** VST loading uses callbacks with delays

## Global Variables
- `~vstManager` - Main VSTManager instance
- `~midiController` - Main MIDIController instance
- `~vstInstances` - Direct VST plugin references
- `~rowMappings` - MIDI control mapping configuration
- `~controlTemplates` - Available control templates