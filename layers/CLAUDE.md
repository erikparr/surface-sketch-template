# OSC Layers System

A synchronized multi-layer playback system using pure OSC-based architecture for coordinating multiple VST instruments playing different melodies in perfect temporal alignment. **Completely replaces the previous ProcMod architecture** with a modern, message-based approach.

## 🚧 FUTURE ARCHITECTURE: Dynamic Layers

**See: @layers/DYNAMIC-LAYERS-DESIGN.md for approved redesign plan**

The current system uses 3 hardcoded layers. The next version will create **one layer per VST group dynamically**:
- Name-based OSC paths (`/group/bass_tuba/note`)
- Event-driven layer creation (no polling)
- Independent melody navigation per group
- Unlimited layer count

**Current system documentation below** (will be migrated):

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
        singleNoteCCMode: false,  // CC envelope mode (false = layer-wide envelopes)
        bendMode: false,          // Bend envelope mode
        isRunning: false,         // System running state
        noteDurationScalar: 1.0,  // Note duration scalar (0.01-1.5) from Row 1 Knob 2
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

### OSC Responder Architecture

The system creates **7 OSCFunc instances per layer** (21 total for layers) + 13 system + 5 external = **39 total OSCFuncs**.

#### Per-Layer OSCFuncs (7 each)

Each layer has 7 independent OSC message handlers:

1. **`/layer[N]/note`** - Individual note trigger
   - Sends MIDI note to all VSTs in layer's group
   - Auto-schedules note-off after duration
   - Optionally triggers expression/bend envelopes

2. **`/layer[N]/chord`** - Chord trigger (1-3 notes)
   - Routes notes across layer groups (note 1 → Layer1, note 2 → Layer2, note 3 → Layer3)
   - Triggers expression envelopes for all 3 layers
   - Supports arpeggio mode with random delays

3. **`/layer[N]/cc`** - Direct MIDI CC control
   - Sends raw CC values to VSTs (no envelope)
   - Real-time parameter control

4. **`/layer[N]/expression`** - CC envelope trigger
   - Creates SynthDef-based CC envelope (ccEnvelope1/2/3)
   - Ramps from min → max → min over duration
   - Sends continuous CC 11/12/13 values

5. **`/layer[N]/bend`** - Pitch bend envelope trigger
   - Creates BendEnvelope SynthDef (one per VST in group)
   - Bends from center → peak → center
   - Controlled by bendAmount (octaves) and peakTimeRatio

6. **`/layer[N]/melody`** - Melody assignment
   - Assigns melody from ~melodyDict
   - Doesn't trigger playback, just sets data

7. **`/layer[N]/enabled`** - Layer enable/disable
   - Boolean on/off switch
   - Disabled layers skipped during playback

#### Visual OSCFunc Routing

```
Layer1 (7 OSCFuncs)                    Layer2 (7 OSCFuncs)                    Layer3 (7 OSCFuncs)
├─ /layer1/note                        ├─ /layer2/note                        ├─ /layer3/note
├─ /layer1/chord ─────────────────────┼─ /layer2/chord (receives note 2) ────┤─ /layer3/chord (receives note 3)
├─ /layer1/cc                          ├─ /layer2/cc                          ├─ /layer3/cc
├─ /layer1/expression                  ├─ /layer2/expression                  ├─ /layer3/expression
│  └→ ccEnvelope1 SynthDef             │  └→ ccEnvelope2 SynthDef             │  └→ ccEnvelope3 SynthDef
│     └→ sends CC 11                   │     └→ sends CC 12                   │     └→ sends CC 13
├─ /layer1/bend                        ├─ /layer2/bend                        ├─ /layer3/bend
│  └→ BendEnvelope SynthDefs           │  └→ BendEnvelope SynthDefs           │  └→ BendEnvelope SynthDefs
│     (one per VST in Layer1 group)    │     (one per VST in Layer2 group)    │     (one per VST in Layer3 group)
├─ /layer1/melody                      ├─ /layer2/melody                      ├─ /layer3/melody
└─ /layer1/enabled                     └─ /layer2/enabled                     └─ /layer3/enabled
```

#### Key Design Insights

- **OSCFuncs are per-layer, not per-VST**: Each layer routes to its configured VST group at runtime
- **Envelope OSCFuncs create SynthDefs**: Expression and bend don't send notes—they spawn synths that continuously send CC/bend values
- **Chord mode cross-routes**: `/layer1/chord` sends notes to all 3 layer groups (multi-instrument routing)
- **VST group mapping is dynamic**: Layer configs store group names ('Layer1', 'Layer2', 'Layer3'), allowing runtime changes

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
// - Knob 8: BPM (60-400) - tempo control with automatic duration calculation based on note count
// - Knob 3: Note velocity (1-127) - live control during playback
// - Knob 2: Note duration scalar (1-100%) - scales all note durations (100% = full duration before next note)
// - Knob 4: Timing offset (0-90%) - shifts note start times forward (fractional duration type only)
// BPM changes take effect on next loop iteration
// When disabled: Uses velocity and durations from melody data

// BPM SYSTEM:
// - Each note is treated as one beat
// - Formula: duration = noteCount / (BPM / 60)
// - Example: 17 notes @ 120 BPM = 17 / 2 = 8.5 seconds
// - Example: 5 notes @ 120 BPM = 5 / 2 = 2.5 seconds
// - Ensures consistent tempo regardless of melody length
```

### Melody Rest Parameter
```supercollider
// MIDI Slider 2: Melody rest time (0-1 seconds)
// - Adds controllable pause after each melody loop iteration
// - Only applies in looping mode
// - Linear mapping: slider position = rest duration
// - Direct MIDI CC handler (CC 23) updates state in real-time
// Note: Slider 1 is used for layer spread timing

// Manual control via OSC:
NetAddr.localAddr.sendMsg('/system/melody_rest', 0.5);  // 0.5 second rest

// MIDI control automatically active via ~setupMelodyRestMIDI.()
// GUI display shows current rest time in seconds

// Cleanup (if needed):
~cleanupMelodyRestMIDI.();
```

### Live Melody Updates (Always Active)
```supercollider
// Live melody mode is ALWAYS ACTIVE - no need to enable
// OSC receivers listen on /liveMelody/update/layer[1-3] from system startup

// Send melody to layer1 → auto-starts independently
n = NetAddr("127.0.0.1", 57120);
n.sendMsg("/liveMelody/update/layer1", "{
  \"notes\": [
    {\"midi\": 60, \"vel\": 0.8, \"dur\": 0.5},
    {\"midi\": 62, \"vel\": 0.7, \"dur\": 0.5}
  ],
  \"metadata\": {\"totalDuration\": 4.0}
}");

// Send to layer2 → starts independently (layer1 keeps playing)
n.sendMsg("/liveMelody/update/layer2", jsonString);

// If layer already playing, update applies at next loop boundary
// Each layer has independent playback control
```

#### Automatic Chord Mode
The system automatically detects and applies chord mode settings from live melody metadata:

```supercollider
// Include chordMode in metadata - system automatically applies it
n = NetAddr("127.0.0.1", 57120);
n.sendMsg("/liveMelody/update/layer1", "{
  \"notes\": [
    {\"midi\": 46, \"vel\": 0.46, \"dur\": 1.0},
    {\"midi\": 58, \"vel\": 0.61, \"dur\": 0.875},
    {\"midi\": 70, \"vel\": 0.74, \"dur\": 0.75}
  ],
  \"metadata\": {
    \"totalDuration\": 2.25,
    \"chordMode\": true
  }
}");
// System automatically enables chord mode before starting playback

// Disable chord mode via metadata
n.sendMsg("/liveMelody/update/layer2", "{...\"chordMode\": false...}");
// System automatically disables chord mode

// Backward compatible: missing chordMode preserves current state
n.sendMsg("/liveMelody/update/layer3", "{...}");
// No change to chord mode setting
```

**Features:**
- **Automatic**: No manual toggling needed
- **Per-melody**: Each composition specifies its own mode
- **Backward compatible**: Missing `chordMode` field preserves current state
- **Applied before playback**: Ensures correct mode from first note

## Independent Layer Playback

Each layer now supports independent playback triggered by OSC messages or manual control:

### Auto-Start via Live Melody
```supercollider
// Send melody → layer auto-starts independently with metadata duration
n = NetAddr("127.0.0.1", 57120);
n.sendMsg("/liveMelody/update/layer1", jsonString);
// Layer1 starts playing with duration from JSON metadata

// Send to layer2 → starts independently (layer1 continues)
n.sendMsg("/liveMelody/update/layer2", jsonString);
```

### Manual Independent Control
```supercollider
// Start layer1 with specific duration
~startLayerIndependent.(\layer1, 4.0);

// Start layer2 with default duration (4.0s)
~startLayerIndependent.(\layer2);

// Start layer3 with MIDI knob duration (if manual control enabled)
~startLayerIndependent.(\layer3);

// Stop specific layer
~stopLayerIndependent.(\layer1);

// Stop all independent layers
~stopAllLayersIndependent.();

// Check playback status
~getLayersPlaybackStatus.();
// Returns: (layer1: (isPlaying: true, hasMelody: true, ...), ...)

// Check if any layer playing
~anyLayerPlaying.();  // Returns true/false
```

### Duration Priority (Independent Playback)
1. **Explicit parameter**: `~startLayerIndependent.(\layer1, 5.0)` → 5.0s
2. **JSON metadata**: `{"metadata": {"totalDuration": 4.0}}` → 4.0s
3. **MIDI knob**: Row 1 Knob 8 (if manual control enabled)
4. **Layer default**: `config.defaultDuration` → 4.0s

### Per-Layer State
Each layer maintains:
- `isPlaying`: Boolean playback state
- `currentTask`: Independent loop task
- `defaultDuration`: Fallback duration (4.0s)

## Timing Synchronization

1. **Duration**: All layers share the same duration (or play independently with their own durations)
2. **Note Intervals**: Each layer divides duration by its note count (or uses custom timing)
3. **Loop Synchronization**: All layers start new iterations together (coordinator mode)
4. **Dynamic Updates**: Duration can change between loops in manual mode
5. **Proportional Scaling**: When loop duration changes, note durations scale proportionally
6. **Note Duration Control**: Manual mode enables additional scaling via Knob 2 (1-150%)
7. **Timing Offset**: Knob 4 shifts all notes forward by 0-90% of duration (fractional type only)
8. **BPM-Based Duration**: Knob 8 controls BPM (60-200), duration auto-calculated from note count
   - Formula: `duration = noteCount / (BPM / 60)`
   - Ensures consistent tempo across melodies with different note counts
   - Each note treated as one beat
9. **Melody Rest**: Slider 2 adds 0-1 second pause after each loop iteration (looping mode only)

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

### MIDI Control Mapping

#### Manual Control Mode (Row 1)
When manual control is enabled, Row 1 knobs control global playback parameters:
- **Row 1, Knob 2** (CC 20): Note duration scalar (1-100%) - scales note durations (100% = full duration)
- **Row 1, Knob 3** (CC 24): Note velocity (1-127) - overrides melody velocity data
- **Row 1, Knob 4** (CC 28): Timing offset (0-90%) - shifts all note start times (fractional duration only)
- **Row 1, Knob 8** (CC 58): BPM (60-400) - tempo control, auto-calculates duration based on note count

#### Slider Controls
- **Slider 1** (CC 19): Layer spread timing
- **Slider 2** (CC 23): Melody rest (0-1s) - pause after each loop iteration (looping mode only)
- **Slider 3** (CC 27): Arpeggio min delay (0-90% of duration) - requires chord + arpeggio mode
- **Slider 4** (CC 31): Arpeggio max delay (0-90% of duration) - requires chord + arpeggio mode
- **Sliders 5-9** (CC 49, 53, 57, 61, 62): Available for future use

#### Expression Control (Per Layer)
Each layer's expression parameters are controlled by MIDI knobs on the corresponding row:

- **Row 1** (Layer 1): Knobs 5-7 control Layer 1 expression
- **Row 2** (Layer 2): Knobs 5-7 control Layer 2 expression
- **Row 3** (Layer 3): Knobs 5-7 control Layer 3 expression

##### Expression Knob Functions
- **Position 5** (CC 46/47/48): Expression minimum value (0-127) - CC value at start/end of envelope
- **Position 6** (CC 50/51/52): Expression duration scalar (0.1-1.0) - scales envelope duration relative to layer duration
- **Position 7** (CC 54/55/56): Expression maximum value (0-127) - CC value at peak of envelope

##### Other Row Controls
- **Row 2, Knob 1** (CC 17): Bend knob control
- **Row 2, Knob 2** (CC 21): Bend peak time ratio
- **Available knobs**: Row 2 Pos 3-4, Row 3 Pos 1-4 and 8 (various CCs)

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

## Arpeggio Chord Mode

When both chord mode and arpeggio mode are enabled, chord notes are triggered with random delays creating arpeggiated chord effects:

### MIDI Control
- **Slider 3** (CC 27): Arpeggio min delay (0-90% of duration)
- **Slider 4** (CC 31): Arpeggio max delay (0-90% of duration)

### Behavior
- Each chord note receives a random delay between min and max percentages of the chord duration
- Notes distributed across Layer1, Layer2, Layer3 (same multi-instrument routing as normal chord mode)
- Expression and bend envelopes triggered with each note independently
- Delays recalculated randomly on each loop iteration
- Requires both chord mode AND arpeggio mode to be enabled

### OSC API
- `/system/arpeggio_mode [bool]` - Enable/disable arpeggio mode
- `/system/arpeggio_min [float]` - Set min delay (0.0-0.9 = 0-90%)
- `/system/arpeggio_max [float]` - Set max delay (0.0-0.9 = 0-90%)

### Helper Functions
- `~setArpeggioMode.(true/false)` - Enable/disable arpeggio mode
- `~setArpeggioMinDelay.(0.1)` - Set min delay (0.0-0.9)
- `~setArpeggioMaxDelay.(0.5)` - Set max delay (0.0-0.9)
- `~getArpeggioStatus.()` - Display current arpeggio settings

### Usage Example
```supercollider
// Enable chord mode first
NetAddr.localAddr.sendMsg('/system/chord_mode', true);

// Enable arpeggio mode
~setArpeggioMode.(true);

// Set delay range to 10-50% of duration
~setArpeggioMinDelay.(0.1);  // 10%
~setArpeggioMaxDelay.(0.5);  // 50%

// Start playing - each chord will arpeggiate with random delays
~startLayers.();

// Check status
~getArpeggioStatus.();
```

### Technical Details
- Delays are percentages of chord duration (scales with BPM changes)
- Min and max values automatically swap if min > max
- Uses `/layer[N]/note` for arpeggiated notes (not `/chord` path)
- Random delays generated using `rrand()` on each chord trigger
- GUI checkbox disabled when chord mode is off
- Real-time MIDI slider control updates display

## Requirements

- **JSON Quark**: Required for JSON import functionality
  - Install: `Quarks.install("https://github.com/musikinformatik/JSONlib.git"); thisProcess.recompile;`
  - This provides the String extensions (parseJSON, parseJSONFile) that JSONlib depends on

## Known Issues

- MIDI control mapping system (if enabled) may intercept row knobs
  - Workaround: Comment out `midi-control-mapping.scd` in `setup/_setup-loader.scd`