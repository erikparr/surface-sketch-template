# OSC Layers System

A synchronized multi-layer playback system using pure OSC-based architecture for coordinating multiple VST instruments playing different melodies in perfect temporal alignment. **Completely replaces the previous ProcMod architecture** with a modern, message-based approach.

## System Overview

The layers system allows three independent layers to play different melodies through different VST groups while maintaining perfect synchronization. Each layer can have its own melody, VST routing, and timing, but all layers share a common duration and loop together.

## Architecture

### Core Structure (`layers-osc-core.scd`)
```supercollider
~oscLayers = (
    // System state
    state: (
        totalDuration: 0,
        startTime: nil,
        loopingMode: false,       // Enable/disable continuous looping
        manualControl: false,     // Enable MIDI knob control for duration and velocity
        liveMelodyMode: false,    // Enable live melody updates via OSC
        singleNoteCCMode: false,  // CC envelope mode (false = layer-wide envelopes)
        bendMode: false,          // Bend envelope mode
        isRunning: false,         // System running state
        noteDurationScalar: 1.0,  // Note duration scalar (0.01-1.5) from Row 1 Knob 2
        pendingUpdates: Dictionary.new  // Store pending melody updates per layer
    ),

    // Layer configurations (preserved from original system)
    configs: (
        layer1: (/* configuration */),
        layer2: (/* configuration */),
        layer3: (/* configuration */)
    ),

    // OSC-based coordinator (replaces ProcMod parent)
    coordinator: (/* coordinator object */)
)
```

### OSC Architecture
- **OSC Coordinator**: Pure function-based coordination without ProcMod dependencies
  - Task-based loop management with explicit function references
  - Duration validation and parameter handling
  - Clean start/stop/cleanup lifecycle management

- **OSC Responders**: Message-based layer control
  - `/layer1/note`, `/layer2/note`, `/layer3/note` - Individual note triggering
  - `/layer1/melody`, `/layer2/melody`, `/layer3/melody` - Melody assignment
  - `/layer1/expression`, `/layer2/expression`, `/layer3/expression` - CC envelope control
  - `/system/start`, `/system/stop`, `/system/looping` - System-wide control

- **External Control**: Network-accessible OSC interface
  - Port 7000 for external applications
  - Acknowledgment messages for remote control
  - Full compatibility with existing GUI and MIDI systems

## Key Components

### 1. OSC Core System (`layers-osc-core.scd`)
- `~initOSCLayersSystem()`: Initialize the complete OSC-based layers system
- `~createOSCCoordinator()`: Create coordination object with explicit function references
- `~createLayerOSCResponders(layerKey)`: Set up OSC message handlers for each layer
- `~createSystemOSCResponders()`: Set up system-wide OSC control messages
- `~startOSCLayer(layerKey, duration)`: Core layer playback function with timing and CC envelope triggering
- `~getLayerMelodyDynamic(layerKey)`: Dynamic melody getter for real-time updates
- `~setupExternalOSCControl(port)`: Enable external network control on specified port

### 2. Control Functions (OSC-based)
- `~startLayersOSC(duration)`: Start all enabled layers via OSC coordinator
- `~stopLayersOSC()`: Stop all layers gracefully via OSC coordinator
- OSC Message API:
  - `/system/start [duration]` - Start system with optional duration
  - `/system/stop` - Stop all layers
  - `/system/looping [bool]` - Enable/disable looping mode
  - `/system/manual_control [bool]` - Enable/disable MIDI control mode
  - `/layer[N]/melody [symbol]` - Assign melody to layer
  - `/layer[N]/note [midi] [velocity] [duration]` - Trigger individual note

### 3. GUI (`layers-gui-osc.scd`)
- **OSC-based interface**: All controls send OSC messages instead of direct function calls
- Transport controls (Start/Stop) → `/system/start`, `/system/stop`
- Loop mode checkbox → `/system/looping`
- Manual control checkbox → `/system/manual_control`
- Per-layer controls via OSC:
  - Enable/disable → `/layer[N]/enabled`
  - Melody selection → `/layer[N]/melody`
  - VST group routing (preserved from original)
  - Load melody from file with JSON import
- Auto-refreshing VST group detection
- Real-time status display

### 4. Loader (`load-layers.scd`)
- **OSC system by default**: Automatically loads OSC-based architecture
- Compatibility layer: Makes `~layers` point to `~oscLayers` for backward compatibility
- Preserves existing function interfaces: `~startLayers` → `~startLayersOSC`
- Creates GUI automatically with OSC integration

### 5. Compatibility System
- `~setupOSCCompatibility()`: Establishes backward compatibility references
- `~layers` → `~oscLayers` mapping for existing code
- Function interface preservation for seamless migration
- All original functionality maintained through OSC message routing

## Usage

### Basic Operation
```supercollider
// Load the OSC system (loads automatically after normal startup)
// OSC layers system is now the default - no manual loading needed

// Configure layers via OSC messages
NetAddr.localAddr.sendMsg('/layer1/melody', \melody1);
NetAddr.localAddr.sendMsg('/layer2/melody', \melody2);
NetAddr.localAddr.sendMsg('/layer3/melody', \melody3);

// Or use compatibility functions (work exactly as before)
~setLayerMelody.(\layer1, \melody1);  // Sends OSC message internally
~setLayerMelody.(\layer2, \melody2);
~setLayerMelody.(\layer3, \melody3);

// Start playback (OSC-based)
NetAddr.localAddr.sendMsg('/system/start', 3.0);  // 3 second duration
// Or use compatibility function
~startLayers.();  // Uses default duration, sends OSC internally

// Enable looping
NetAddr.localAddr.sendMsg('/system/looping', true);
// Or use compatibility
~oscLayers.state.loopingMode = true;  // Same effect

// Stop playback
NetAddr.localAddr.sendMsg('/system/stop');
// Or use compatibility function
~stopLayers.();  // Sends OSC message internally
```

### Manual Control Mode
```supercollider
// Enable MIDI knob control
~setLayersManualControl.(true);

// Manual control mappings (Row 1):
// - Knob 8: Loop duration (0.01-10 seconds) - exponential scaling for fine control at low values
// - Knob 3: Note velocity (1-127) - live control during playback
// - Knob 2: Note duration scalar (1-150%) - scales all note durations (works with fractional & absolute)
// - Knob 4: Timing offset (0-90%) - shifts note start times forward (fractional duration type only)
// Duration changes take effect on next loop iteration
// When disabled: Uses velocity and durations from melody data
```

### Live Melody Updates
```supercollider
// Enable live melody mode for real-time OSC updates
~enableLiveMelodyMode.();

// Send OSC update during playback (applies immediately to live layers)
n = NetAddr("127.0.0.1", 57120);
n.sendMsg("/liveMelody", "layer1", "{\"patterns\":[[60,62,64,65]],\"velocities\":[100,110,120,127]}");

// Updates apply live without stopping/restarting layers
// Disable live melody mode
~disableLiveMelodyMode.();
```

## Timing Synchronization

1. **Duration**: All layers share the same duration
2. **Note Intervals**: Each layer divides duration by its note count (or uses custom timing)
3. **Loop Synchronization**: All layers start new iterations together
4. **Dynamic Updates**: Duration can change between loops in manual mode
5. **Proportional Scaling**: When loop duration changes, note durations scale proportionally
6. **Note Duration Control**: Manual mode enables additional scaling via Knob 2 (1-150%)
7. **Timing Offset**: Knob 4 shifts all notes forward by 0-90% of duration (fractional type only)
8. **Exponential Duration**: Knob 8 uses exponential mapping for fine control at short durations

## Integration Points

- **VST Manager**: Routes notes to appropriate VST instances
- **Melody Dictionary**: Sources melodies from `~melodyDict`
- **MIDI Controller**: Reads knob values for manual control and expression parameters
- **Sketch System**: Compatible with main sketch timing parameters and velocity control (Row 1 Knob 3)
- **Expression Control**: Independent CC envelope control for each layer
- **OSC System**: Receives live melody updates during playback
- **Live Updates**: Dynamic melody references enable real-time changes

## State Management

- **Single source of truth**: `~oscLayers.state` for all system state
- **OSC-driven state**: All state changes triggered via OSC messages
- **Coordinator lifecycle**: Clean start/stop/cleanup without ProcMod dependencies
- **Explicit state control**: Clear separation between coordinator, responders, and layer functions
- **Compatibility mapping**: `~layers` points to `~oscLayers` for backward compatibility

## Recent Improvements (OSC Migration)

### **MAJOR ARCHITECTURE OVERHAUL**
1. **Complete ProcMod removal**: Eliminated complex hierarchical ProcMod architecture entirely
2. **Pure OSC architecture**: Built from ground up using OSC message-based coordination
3. **Message-driven design**: All layer control via OSC messages for modularity and external access
4. **Explicit function references**: Solved context issues with coordinator using explicit object references
5. **Parameter validation**: Robust duration and type checking throughout the system
6. **Clean lifecycle management**: Proper start/stop/cleanup without ProcMod dependencies

### **Performance & Reliability**
7. **Simplified coordination**: Single Task-based coordinator with explicit state management
8. **Reduced complexity**: Eliminated nested ProcMod hierarchy and timing synchronization issues
9. **Better error handling**: Clear error messages and graceful degradation
10. **Network accessibility**: External control via port 7000 for remote applications
11. **Backward compatibility**: All existing functions preserved through compatibility layer

### **Enhanced Functionality**
12. **OSC external control**: Full system control from external applications
13. **Dynamic melody updates**: Real-time melody switching via OSC messages during playback
14. **JSON melody import**: Complete melody loading with timing data via GUI
15. **Layer-specific CC envelopes**: Independent expression control per layer with proper triggering
16. **Timing data support**: Custom inter-onset intervals and note durations
17. **Manual MIDI control**: MIDI knob integration for duration, velocity, and expression parameters
18. **Looping mode**: Continuous playback with real-time parameter updates

### **Code Quality**
19. **Eliminated gold plating**: Focused on essential functionality without unnecessary complexity
20. **Clear separation of concerns**: OSC responders, coordinator, and layer functions cleanly separated
21. **Maintainable codebase**: Well-structured, documented code with clear interfaces
22. **Compatibility preservation**: Seamless migration path from ProcMod system

## Expression Control System

Each layer now has independent expression control via CC envelopes that send MIDI CC values to VST instruments:

### CC Envelope Mapping
- **Layer 1**: CC 11 via `ccEnvelope1` SynthDef → `/expression1` OSC path
- **Layer 2**: CC 12 via `ccEnvelope2` SynthDef → `/expression2` OSC path  
- **Layer 3**: CC 13 via `ccEnvelope3` SynthDef → `/expression3` OSC path

### MIDI Knob Control

#### Manual Control Mode (Row 1)
When manual control is enabled, Row 1 knobs control global playback parameters:
- **Knob 2**: Note duration scalar (1-150%) - applies to all layers
- **Knob 3**: Note velocity (1-127) - overrides melody velocity data
- **Knob 4**: Timing offset (0-90%) - shifts all note start times (fractional duration only)
- **Knob 8**: Loop duration (0.01-10s) - exponential scaling for fine control

#### Expression Control (Per Layer)
Each layer's expression parameters are controlled by MIDI knobs on the corresponding row:

- **Row 1** (Layer 1): Knobs 5-7 control Layer 1 expression
- **Row 2** (Layer 2): Knobs 5-7 control Layer 2 expression
- **Row 3** (Layer 3): Knobs 5-7 control Layer 3 expression

##### Expression Knob Functions
- **Position 5**: Expression duration scalar (0.1-1.0) - scales envelope duration relative to layer duration
- **Position 6**: Expression minimum value (0-127) - CC value at start/end of envelope
- **Position 7**: Expression maximum value (0-127) - CC value at peak of envelope

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

## Timing Offset Feature (Knob 4)

The timing offset feature allows real-time shifting of note start times for fractional duration melodies:

### How It Works
- **Control**: Row 1, Knob 4 (only active in manual control mode)
- **Range**: 0-90% of total loop duration
- **Applies to**: Fractional duration type melodies only
- **Behavior**: Shifts all notes forward by the same amount while preserving relative timing

### Use Cases
1. **Groove adjustment**: Create swing or shuffle feel by offsetting notes
2. **Polyrhythmic effects**: Offset layers relative to each other
3. **Live performance**: Real-time rhythmic variation without changing melody data
4. **Phase shifting**: Gradually shift timing relationships between layers

### Technical Details
- Offset is calculated as a fraction of total duration
- Notes are clamped to 95% of duration to prevent overflow
- Works seamlessly with note duration scalar (Knob 2)
- Visual feedback in GUI shows current offset percentage
- Debug output shows applied offset in console

## Requirements

- **JSON Quark**: Required for JSON import functionality
  - Install: `Quarks.install("https://github.com/musikinformatik/JSONlib.git"); thisProcess.recompile;`
  - This provides the String extensions (parseJSON, parseJSONFile) that JSONlib depends on

## Known Issues

- MIDI control mapping system (if enabled) may intercept row knobs
  - Workaround: Comment out `midi-control-mapping.scd` in `setup/_setup-loader.scd`