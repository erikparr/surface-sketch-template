# Dependent Layers System

A synchronized multi-layer playback system using ProcMod architecture for coordinating multiple VST instruments playing different melodies in perfect temporal alignment.

## System Overview

The layers system allows three independent layers to play different melodies through different VST groups while maintaining perfect synchronization. Each layer can have its own melody, VST routing, and timing, but all layers share a common duration and loop together.

## Architecture

### Core Structure (`layers-core.scd`)
```supercollider
~layers = (
    parentProc: nil,              // Parent ProcMod managing overall timing
    configs: Dictionary.new,      // Layer configurations (layer1, layer2, layer3)
    layerProcs: Dictionary.new,   // Child ProcMod instances for each layer
    timingData: Dictionary.new,   // Pre-calculated timing data
    state: (
        totalDuration: 0,
        startTime: nil,
        loopingMode: false,       // Enable/disable continuous looping
        manualControl: false      // Enable MIDI knob control for duration
    )
)
```

### ProcMod Hierarchy
- **Parent ProcMod**: Controls overall timing and loop management
  - ASR envelope with release node for sustained operation
  - Contains a Task that manages loop iterations
  - Calculates timing once and shares with children
  
- **Child ProcMods** (one per layer): Handle individual layer playback
  - Each has its own Task for note sequencing
  - Read timing from shared `~layers.timingData`
  - Loop internally based on parent's looping state

## Key Components

### 1. Playback System (`layers-playback.scd`)
- `~ensureProcModSynthDef`: Ensures ProcMod's SynthDef is available on server
- `~createLayersParentProc`: Creates parent ProcMod with timing management
- `~createLayerProcMod`: Creates child ProcMod for individual layer
- `~playLayerNote`: Direct function for VST note playback (no OSC indirection)

### 2. Control Functions (`layers-control.scd`)
- `~startLayers(duration)`: Start all enabled layers
- `~stopLayers`: Stop all layers gracefully
- `~killLayers`: Emergency stop
- `~setLayerMelody(layerName, melodyKey)`: Assign melody to layer
- `~setLayerVSTGroup(layerName, vstGroup)`: Route layer to VST group
- `~setLayersManualControl(enabled)`: Enable/disable MIDI control mode
- `~getLayersDurationFromKnob`: Read duration from MIDI knob (row 1, pos 8)

### 3. GUI (`layers-gui.scd`)
- Transport controls (Start/Stop)
- Loop mode checkbox
- Manual control checkbox
- Per-layer controls:
  - Enable/disable
  - Melody selection
  - VST group routing
  - Load melody from file
- Auto-refreshing VST group detection

### 4. Loader (`load-layers.scd`)
- Loads all components in correct order
- Initializes the system
- Creates GUI automatically

## Usage

### Basic Operation
```supercollider
// Load the system (after normal startup)
(thisProcess.nowExecutingPath.dirname +/+ "layers/load-layers.scd").load;

// Configure layers
~setLayerMelody.(\layer1, \melody1);
~setLayerMelody.(\layer2, \melody2);
~setLayerMelody.(\layer3, \melody3);

// Start playback
~startLayers.();  // Uses default or MIDI-controlled duration

// Enable looping
~layers.state.loopingMode = true;

// Stop playback
~stopLayers.();
```

### Manual Control Mode
```supercollider
// Enable MIDI knob control
~setLayersManualControl.(true);

// Now row 1, knob 8 controls duration (0.1-10 seconds)
// Duration changes take effect on next loop iteration
```

## Timing Synchronization

1. **Duration**: All layers share the same duration
2. **Note Intervals**: Each layer divides duration by its note count
3. **Loop Synchronization**: All layers start new iterations together
4. **Dynamic Updates**: Duration can change between loops in manual mode

## Integration Points

- **VST Manager**: Routes notes to appropriate VST instances
- **Melody Dictionary**: Sources melodies from `~melodyDict`
- **MIDI Controller**: Reads knob values for manual control
- **Sketch System**: Compatible with main sketch timing parameters

## State Management

- **Single source of truth**: `~layers.state` for all state
- **No duplicate state**: Removed problematic `isPlaying` checks
- **ProcMod lifecycle**: Rely on ProcMod's built-in state management
- **Clean separation**: Parent manages timing, children manage playback

## Recent Improvements

1. **Removed OSC indirection**: Direct function calls for better performance
2. **Simplified timing**: Calculate once in parent, share with children
3. **Fixed initialization**: Proper SynthDef availability without hacks
4. **Consolidated state**: Single looping mode flag, no state duplication
5. **Manual control**: MIDI knob control for real-time duration adjustment

## Known Issues

- MIDI control mapping system (if enabled) may intercept row 1 knobs
- Workaround: Comment out `midi-control-mapping.scd` in `setup/_setup-loader.scd`