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
- **MIDI Controller**: Reads knob values for manual control and expression parameters
- **Sketch System**: Compatible with main sketch timing parameters
- **Expression Control**: Independent CC envelope control for each layer

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
6. **Layer-specific expression control**: Independent CC envelopes for each layer
7. **Timing data support**: Custom inter-onset intervals and note durations
8. **JSON import**: Full support for importing melodies with timing data via GUI or code
9. **Smart layer mapping**: Automatically handles 0-indexed JSON to 1-indexed GUI mapping

## Expression Control System

Each layer now has independent expression control via CC envelopes that send MIDI CC values to VST instruments:

### CC Envelope Mapping
- **Layer 1**: CC 11 via `ccEnvelope1` SynthDef → `/expression1` OSC path
- **Layer 2**: CC 12 via `ccEnvelope2` SynthDef → `/expression2` OSC path  
- **Layer 3**: CC 13 via `ccEnvelope3` SynthDef → `/expression3` OSC path

### MIDI Knob Control
Each layer's expression parameters are controlled by MIDI knobs on the corresponding row:

- **Row 1** (Layer 1): Knobs 4-6 control Layer 1 expression
- **Row 2** (Layer 2): Knobs 4-6 control Layer 2 expression
- **Row 3** (Layer 3): Knobs 4-6 control Layer 3 expression

#### Knob Functions
- **Position 4**: Expression duration scalar (0.1-1.0) - scales envelope duration relative to layer duration
- **Position 5**: Expression minimum value (0-127) - CC value at start/end of envelope
- **Position 6**: Expression maximum value (0-127) - CC value at peak of envelope

### Configuration Structure
Each layer's `ccControl` configuration:
```supercollider
ccControl: (
    enabled: true,
    expressionCC: 11,              // CC number (11, 12, or 13)
    expressionMin: 10,             // Minimum CC value
    expressionMax: 120,            // Maximum CC value
    expressionShape: \sin,         // Envelope curve shape
    expressionPeakPos: 0.5,        // Peak position (0-1)
    expressionDurationScalar: 1.0  // Duration multiplier
)
```

### Expression Control API
- `~setLayerExpressionEnabled.(layerName, enabled)`: Enable/disable expression for a layer
- `~setLayerExpressionCC.(layerName, ccNum)`: Set CC number for a layer
- `~setLayerExpressionParams.(layerName, min, max, shape, peakPos)`: Set expression parameters
- `~enableAllLayerExpression.()`: Enable expression for all layers
- `~disableAllLayerExpression.()`: Disable expression for all layers
- `~printLayerExpressionSettings.(layerName)`: Show current expression settings
- `~printAllLayerExpressionSettings.()`: Show all layer expression settings

## Timing Data System

The layers system now supports custom timing patterns for melodies, allowing precise control over note placement and duration.

### Timing Structure
```supercollider
melodyData.timing = [0.1, 0.2, 0.5, 0.2];  // Fractions that sum to 1.0
melodyData.noteDurations = [0.5, 0.5, 1.0]; // Individual note durations
melodyData.durationType = "absolute";        // or "fractional"
```

### How Timing Works
For n notes, provide n+1 timing values:
- `timing[0]`: Wait before first note (fraction of total duration)
- `timing[1..n-1]`: Inter-onset intervals between notes
- `timing[n]`: Wait after last note

Example with 3 notes and 4s total duration:
- `[0.1, 0.2, 0.5, 0.2]` produces:
  - 0.4s: Note 1 (10% × 4s wait)
  - 1.2s: Note 2 (0.4s + 20% × 4s)
  - 3.2s: Note 3 (1.2s + 50% × 4s)
  - 4.0s: End (3.2s + 20% × 4s)

### JSON Import
```supercollider
// Import via GUI: Use "Load File" button and select .json file
// Or programmatically:
var melodies = ~importLayerMelodyFromJSON.("path/to/melody.json");
~addImportedMelodiesToDict.(melodies);

// The system automatically maps:
// JSON layer0 → GUI layer1
// JSON layer1 → GUI layer2  
// JSON layer2 → GUI layer3

// JSON format:
{
  "layers": {
    "layer0": {
      "notes": [
        {"midi": 60, "vel": 0.8, "dur": 0.6},
        {"midi": 62, "vel": 0.7, "dur": 0.6}
      ],
      "timing": [0.1, 0.2, 0.5, 0.2],
      "metadata": {
        "totalDuration": 4.0,
        "durationType": "absolute"
      }
    }
  }
}
```

### Manual Creation
```supercollider
~melodyDict[\myTimedMelody] = (
    name: "Custom Timed Melody",
    patterns: [[60, 62, 64, 65]],
    timing: [0.1, 0.1, 0.2, 0.3, 0.3],  // Custom timing
    noteDurations: [0.4, 0.4, 0.4, 0.8], // Individual durations
    durationType: "absolute"
);
```

### Testing
- **Example data**: `data/melody-export.json` - Sample JSON file with 3 layers
- **Backward compatible**: Melodies without timing data automatically use equal spacing
- **GUI testing**: Use "Load File" button on any layer to import JSON melodies

## Requirements

- **JSON Quark**: Required for JSON import functionality
  - Install: `Quarks.install("https://github.com/musikinformatik/JSONlib.git"); thisProcess.recompile;`
  - This provides the String extensions (parseJSON, parseJSONFile) that JSONlib depends on

## Known Issues

- MIDI control mapping system (if enabled) may intercept row knobs
  - Workaround: Comment out `midi-control-mapping.scd` in `setup/_setup-loader.scd`