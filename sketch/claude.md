# Surfacing System Documentation

## Overview

The Surfacing system is a sophisticated live electronic music performance framework built in SuperCollider, designed for real-time control of VST instruments through MIDI controllers. It features complex musical sequencing, dual-layer performance capabilities, and intelligent parameter mapping.

## How The System Works

### Initialization Flow

The system starts with `setup/_setup-loader.scd`, which orchestrates the entire initialization process:

1. **Prevents Double-Loading**: Uses `~setupAlreadyLoaded` flag to ensure setup only runs once
2. **Sequential Loading**: Files are loaded in dependency order with appropriate delays
3. **Error Resilience**: Continues loading even if individual files fail
4. **Asynchronous Handling**: Longer delays (5s) for MIDI and VST setup, shorter (0.2s) for others

### File Loading Order & Dependencies

```
synths-setup.scd          → Defines SynthDefs (no dependencies)
vstplugin-setup.scd       → Initializes VST system (needs synths)
vst-management.scd        → Creates GUI (needs VST system)
midi-setup.scd            → MIDI controller (needs VST manager)
midi-control-mapping.scd  → Parameter mapping (needs MIDI controller)
osc-setup.scd             → OSC handlers (needs VST manager)
```

## System Architecture

### Core Components

1. **Setup System** (`../setup/`)
   - Modular initialization framework
   - Manages VST plugins, MIDI controllers, OSC communication
   - Provides GUI for VST management
   - Implements advanced MIDI parameter mapping

2. **Sketch System** (`sketch/`)
   - Live performance engine
   - Chord progression and melody modes
   - Per-note bend envelopes synchronized to note duration
   - ProcMod-based musical sequencing
   - Real-time parameter modulation

3. **VSTManager** (`VSTManager/VSTManager.sc`)
   - Singleton pattern for VST instance management
   - Group-based organization
   - Dynamic targeting during performance
   - Program (preset) management

4. **ProcMod** (`reference/procmod-reference/ProcMod.sc`)
   - Process modulation framework
   - Envelope-controlled execution
   - Resource lifecycle management
   - Model-View-Controller messaging

## How Key Classes Work Together

### Class Interaction Flow

1. **VSTPlugin (UGen)** → Hosts VST in audio chain
2. **VSTPluginController** → Controls VSTPlugin instance  
3. **VSTManager** → Manages multiple controllers
4. **MIDIController** → Routes MIDI to VSTManager
5. **ProcMod** → Wraps processes with lifecycle management

### Signal & Control Flow

```
Audio Input → VSTPlugin UGen → Audio Output
     ↑              ↑
     |              |
SynthDef     VSTPluginController
                    ↑
                    |
              VSTManager ← MIDIController ← MIDI Hardware
                    ↑
                    |
              ProcMod System
```

## Key Classes

### VSTPlugin (UGen)

**Purpose**: Audio Unit Generator that hosts VST plugins in the signal chain

**Key Features**:
- Processes audio with VST effects/instruments
- Supports multiple input/output buses
- Parameter automation at control or audio rate
- Bypass modes (hard/soft)

**Usage in SynthDef**:
```supercollider
SynthDef(\vstHost, { |out=0|
    var sig = VSTPlugin.ar(nil, 2, id: \vsti);
    Out.ar(out, sig);
}).add;
```

### VSTPluginController

**Purpose**: Client-side control interface for VSTPlugin UGen

**Key Features**:
- Opens/closes VST plugins
- Parameter control (set/get/map)
- MIDI interface via `.midi` proxy
- Preset/program management
- GUI control (native or generic)

**Relationship to VSTPlugin**:
- Each VSTPluginController controls one VSTPlugin UGen
- Communicates via OSC messages to the Server
- Maintains parameter cache and state

### VSTManager

**Purpose**: Centralized management of VST plugin instances

**Key Features**:
- **Singleton Pattern**: Only one instance via `VSTManager.current`
- **Group Management**: Organize VSTs into named groups
- **Active Group**: One group active at a time for performance
- **Instance Access**: Multiple ways to retrieve VST controllers

**Important Methods**:
```supercollider
// Get all instances as name->controller dictionary
~vstManager.getInstances()

// Get instances by group (nil/"All" = all instances)
~vstManager.getTargetInstances(groupName)

// Add VST with group assignment
~vstManager.addVST(name, synth, vstPath, editor, groupName)

// Group management
~vstManager.setActiveGroup(groupName)
~vstManager.getActiveInstances()

// Program management
~vstManager.setProgramByName(vstName, programName)
~vstManager.setProgramByNameAll(programName)  // Active group
~vstManager.setProgramByNameAllInstances(programName)  // All VSTs
```

**Group System**:
- VSTs belong to groups for organization
- One "active group" for current performance focus
- Special "All" syntax targets every instance
- Groups can be created dynamically

### ProcMod & ProcModR

**Purpose**: Process modulation with envelope control and lifecycle management

**Architecture**:
- **Envelope-driven**: Process lifetime controlled by ASR envelope
- **Group-based**: Each process gets its own Group node
- **Resource Management**: Automatic cleanup of nodes, buses, responders
- **State Tracking**: `isRunning`, `isReleasing` flags
- **MVC Pattern**: Changes broadcast via `.changed()` method

**How It Works**:
1. Creates a Group for the process
2. If envelope provided, creates envelope synth (`procmodenv_5216`)
3. Executes user function with (group, envbus, server, procmod)
4. Schedules release based on envelope duration
5. Cleans up all resources on release/kill

**Basic Usage**:
```supercollider
// Create and play
p = ProcMod.play(
    env: Env.asr(0.1, 1, 0.1),
    amp: 1,
    id: "myProcess",
    function: { |group, envbus, server, procmod|
        // Create synths in 'group'
        // Read envelope from 'envbus' if needed
    }
);

// Control during playback
p.amp_(0.5);
p.release;  // Graceful release
p.kill;     // Immediate stop
```

**ProcModR** (Routing version) adds:
- **Audio Bus Allocation**: `routebus` for internal routing
- **Multi-channel Support**: 1-16 channels
- **Recording**: Built-in recording to disk
- **Processor Integration**: Can insert processors in signal chain

**Key Differences**:
- ProcMod: Simple process control
- ProcModR: Audio routing + recording capabilities

### MIDIController

**Purpose**: Comprehensive MIDI input handling and routing

**Architecture**:
- **Preset System**: Controller layouts (MIDIMix, nanoKONTROL2)
- **Snapshot System**: Save/load controller states
- **Mapping System**: Route CCs to parameters
- **Multi-mode Support**: Channel, instrument, velocity modes

**Core Components**:
1. **MIDI Handlers** (via MIDIFunc):
   - noteOn/noteOff with multi-channel routing
   - CC processing for knobs/sliders
   - Pitch bend support

2. **Value Storage**:
   - `sliderValues`: Array[9] for sliders
   - `knobValues`: Dictionary of CC->value
   - `buttonStates`: Toggle states

3. **Mapping Integration**:
   - Checks if CC is mapped to row/parameter
   - Routes through mapping system if enabled
   - Falls back to direct value access

**Usage Pattern**:
```supercollider
// Create controller
~midi = MIDIController.new(vstList, oscAddr);

// Set preset
~midi.setControllerPreset(\midiMix);

// Enable mapping mode
~midi.setMappingMode(true);

// Get values
~midi.getSliderValue(0);      // Get slider 1
~midi.getKnobRow1(1);         // Get row 1, knob 1
~midi.getKnobValueByCC(16);   // Get by CC number
```

## Setup System Components

### 1. Main Loader (`_setup-loader.scd`)
- Prevents double-loading with `~setupAlreadyLoaded` flag
- Loads components in dependency order
- Handles asynchronous operations with appropriate delays
- Continues loading even if individual files fail

### 2. Synths Setup (`synths-setup.scd`)
**SynthDefs Defined**:
- VST hosting synths: `\insert`, `\insert2`, `\insert3`, `\vstHost`
- Envelope synths: `\BendEnvelope`, `\ccEnvelope` (with loop variants)
- Supports multiple VST instances with unique IDs
- Implements looping envelopes with OSC output at 100Hz

### 3. VST Plugin Setup (`vstplugin-setup.scd`)
- Searches for VST plugins (excludes Komplete Kontrol)
- Creates synth instances for VST hosting
- Initializes VSTManager singleton
- Loads specific VSTs (e.g., SWAM Bass Tuba instances)
- Creates and manages VST groups

### 4. VST Management GUI (`vst-management.scd`)
**Features**:
- Load VSTs from predefined list
- Add/remove VST instances dynamically
- Create and organize VST groups
- Assign MIDI keyboard to groups
- MIDI override controls (Expression, Velocity, Multi-Instrument Mode)

### 5. MIDI Setup (`midi-setup.scd`)
- Creates MIDIController instance
- Configures for multi-channel operation
- Sets MIDIMix controller preset
- Integrates with VST Manager for dynamic targeting

### 6. MIDI Control Mapping (`midi-control-mapping.scd`)
**Architecture**:
- **Control Templates**: Define parameter mappings
- **Row Mappings**: Assign controller rows to VST groups
- **Group Parameters**: Store per-group values
- **State Persistence**: Save/load configurations

### 7. OSC Setup (`osc-setup.scd`)
**Handlers**:
- `/bend` - Pitch bend routing
- `/expression` - CC to first layer
- `/expression2` - CC to second layer

### 8. Clip Management (`clip-management.scd`)
**Features**:
- MIDI clip recording with timing preservation
- ProcMod-based loop playback
- Multiple loop modes (forward, reverse, ping-pong, random)
- Quantized playback to beat grid
- JSON-based file storage

## Sketch System Components

### 1. Main Loader (`load-sketch.scd`)

**Critical Global Variables**:
```supercollider
// Performance parameters
~bpm = 298;
~noteDuration = 0.2;
~noteRest = 0.2;
~noteOffset = -12;
~repetitions = 1;

// Active state tracking
~activeCCSynths = Dictionary.new;
~activeNotes = Dictionary.new;
~activeVSTGroup = nil;
~lastFermataChord = nil;  // For chord mode fermata tracking

// Mode flags
~modes = (
    noteOffset: false,
    fermata: false,
    melodyRestMode: false,
    pauseNotesMode: false,
    removeLast: false,
    velocityMultiply: false,
    manualLooping: true,    // false = progressive (auto-advance), true = manual (stay on current)
    chordProgression: false,  // false = melody mode, true = chord mode
    sustainMode: false      // true = disable noteOff messages, false = normal noteOff behavior
);

// CC control parameters
~ccControl = (
    enabled: true,
    expressionCC: 16,
    expressionMin: 10,
    expressionMax: 120,
    expressionShape: \sin,
    expressionPeakPos: 0.5,
    expressionDurationScalar: 1.0,
    noteDuration: 0.2,
    noteRestTime: 0.2,
    velocity: 100
);

// Chord progression variables
~currentChordProgression = nil;
~currentChordIndex = 0;
~chords = Dictionary.new;
```

### 2. Core Functions (`core-functions.scd`)

**Parameter-Centric Note Processing**:
```supercollider
~processNote = { |note, isFirstNote=false, isLastNote=false, melodyKey|
    var mappingHandlesVelocity = ~anyRowHandlesParameter.(\velocity);
    
    if (mappingHandlesVelocity) {
        velocity = ~ccControl.velocity;  // Use mapped value
    } {
        velocity = ~midiController.getKnobRow1(4).linlin(0, 1, 1, 127);  // Direct fallback
    };
    
    // Apply note offset and velocity multipliers
    [processedNote, velocity];
};
```

### 3. VST Targeting (`vst-targeting.scd`)

**Direct Group Control**:
```supercollider
~setActiveVSTGroup.('Bass Tuba');    // Target specific group
~setActiveVSTGroup.("All");          // Target all instances
~useAllVSTs.();                      // Convenience function
```

**Live Performance Cycling**:
```supercollider
~nextVSTGroup.();     // Cycle to next group
~prevVSTGroup.();     // Cycle to previous group
~useVSTGroup.(0);     // Target by index
```

### 4. Control Systems (`control-systems.scd`)

**MIDI Button Controls** (via MIDIdef.noteOn):
- Note 21: Toggle Melody Rest mode
- Note 22: Previous Melody
- Note 23: Toggle Chord Progression mode
- Note 24: Toggle Fermata mode
- Note 25: Toggle Pause Notes mode
- Note 26: Next Chord (when in chord mode)
- Note 27: Next Melody
- Note 28: Previous Chord (when in chord mode)
- Note 29: Toggle Sustain mode (disable noteOff messages)

**CC Envelope System**: Parameter-aware expression control
**Bend Envelope System**: Per-note bend envelopes synchronized to note duration
**OSC Responders**: `/note/on`, `/note/release`, `/bend`

### 5. Musical Implementation (`musical-implementation.scd`)

**ProcMod-Based Sequencing**:
- Uses ASR envelopes for controlled processes
- Executes user functions within managed environments
- Handles resource cleanup automatically
- Supports real-time parameter updates

**Note Duration System**:
- Expanded range: 0.1 - 10.0 seconds (updated from 0.005-0.5)
- MIDI control via slider or parameter mapping
- Code: `noteDuration = ~midiController.getKnobRow1(2).linlin(0, 1, 0.1, 10.0);`

**Chord Progression Mode**:
- Toggle with MIDI Note 23 or `~modes.chordProgression = true`
- Distributes chord notes across VST instances
- Each VST plays a different note of the current chord
- Navigation with MIDI Notes 26 (next) and 28 (previous)

### 6. Chord Progressions (`chord-progressions.scd`)

**Chord System**:
- Default progression: Simple Triads
- Chord structures: `[[60, 64, 67], [57, 60, 64], [65, 69, 72], [67, 71, 74]]`
- Functions: `~nextChord()`, `~previousChord()`, `~showChordStatus()`
- Load progressions: `~loadChordProgression.(key)`

**Key Functions**:
```supercollider
~getCurrentChord.();              // Get current chord notes
~validateChordVSTMatch.();        // Check chord/VST compatibility
~listChordProgressions.();        // Show available progressions
```

### 7. Bend Envelope System

**Per-Note Bend Envelopes**:
- Synchronized to note duration (replaces looping envelopes)
- Function: `~startNoteBend.(vstKey, vstIndex, noteDuration)`
- Timing ratios: `peakTimeRatio` and `returnTimeRatio` based on note duration
- Automatic cleanup after note completion

### 8. Dual Layer System (`dual-layer-system.scd`)

**Architecture**:
- Complete state duplication for Layer 2
- Row 1 MIDI → Layer 1, Row 2 MIDI → Layer 2
- Independent VST targeting per layer
- Synchronized or independent operation

## Performance System

### Dual-Layer Architecture

**Layer 1**:
- MIDI Row 1 controls
- Primary VST group targeting
- OSC: `/note/on`, `/note/release`

**Layer 2**:
- MIDI Row 2 controls
- Secondary VST group targeting
- OSC: `/note/on2`, `/note/release2`

### Parameter Control Flow

1. **MIDI Input** → Controller knobs send CC data
2. **Mapping System** → Checks if parameter is mapped to a row
3. **Parameter Resolution**:
   - If mapped: Use value from `~ccControl`
   - If not mapped: Read MIDI controller directly
4. **VST Targeting** → Send to appropriate group/instance
5. **Real-time Update** → Parameters update during playback

### Musical Sequencing

**Melody System**:
- Arrays of MIDI note numbers
- Real-time transposition
- Configurable rest periods
- Fermata (hold) support

**Timing Control**:
- Note duration from MIDI or mapping
- Rest duration control
- BPM-based timing (default: 298)
- Beat-synchronized events

## Critical Global Variables

### Setup System
- `~vstManager` - Main VST manager instance
- `~midiController` - MIDI controller interface
- `~controlTemplates` - Parameter mapping templates
- `~rowMappings` - MIDI row→VST group assignments
- `~groupControlParams` - Per-group parameter storage

### Sketch System
- `~modes` - Performance mode flags (including `chordProgression` and `sustainMode`)
- `~currentVSTGroupIndex` - Active group index
- `~ccControl` - Current CC parameter values
- `~activeCCSynths` - Running CC envelope synths
- `~activeBendSynths` - Per-note bend envelope synths
- `~activeNotes` - Currently playing notes
- `~melodies` - Loaded melodic patterns
- `~currentChordProgression` - Active chord progression
- `~currentChordIndex` - Current position in chord progression
- `~lastFermataChord` - Stored fermata chord notes for release

## Usage Patterns

### Basic Performance Setup

```supercollider
// 1. Load the sketch system
(
~projectPath = "/path/to/surfacing/sketch/";
(~projectPath ++ "load-sketch.scd").load;
)

// 2. VSTs and MIDI are auto-configured by setup

// 3. Target a VST group
~setActiveVSTGroup.("Tubas");

// 4. Start performance
~startContinuousLoopSequence.();
```

### Parameter Mapping

```supercollider
// Check if parameter is mapped
if (~anyRowHandlesParameter.(\velocity)) {
    velocity = ~ccControl.velocity;
} else {
    velocity = ~midiController.getKnobRow1(4).linlin(0, 1, 1, 127);
}
```

### VST Program Changes

```supercollider
// Change program for specific VST
~vstManager.setProgramByName("Tuba1", "ff marcato");

// Change all in active group
~vstManager.setProgramByNameAll("pp dolce");

// Change every VST instance
~vstManager.setProgramByNameAllInstances("mf espressivo");
```

## Performance Modes

- **Pause Notes**: Temporarily stop note generation
- **Melody Rest**: Add pauses between phrases
- **Fermata**: Hold specific notes longer
- **Manual Advance**: Step through melodies manually
- **Chord Progression**: Distribute chord notes across VST instances
- **Sustain Mode**: Disable automatic noteOff messages (notes play until manually stopped)

## OSC Communication

### Input Messages
- `/note/on [channel, note, velocity, duration, isFermata, isFirstNote, isLastNote]` - Trigger note with full context
- `/note/release [note]` - Release fermata notes (handles both melody and chord modes)
- `/bend [chanIndex, bendValue]` - Pitch bend control from envelope synths

### Internal Communication
- Components use OSC for loose coupling
- Enables external control integration
- Debug messages via SendTrig

## Best Practices

1. **Always use VSTManager** for VST access - don't store controllers directly
2. **Check parameter mapping** before reading MIDI directly
3. **Use ProcMod** for time-based processes requiring cleanup
4. **Target groups** rather than individual VSTs for flexibility
5. **Handle nil cases** when accessing VST instances

## Troubleshooting

### Common Issues

1. **VSTs not responding**:
   - Check VST is loaded: `~vstManager.getInstances()`
   - Verify group assignment: `~vstManager.getGroupInstances(groupName)`
   - Ensure synth is running

2. **Parameter changes not working**:
   - Check mapping system: `~rowMappings`
   - Verify MIDI controller connection
   - Look for parameter name mismatches

3. **Timing issues**:
   - Check `~bpm` setting
   - Verify ProcMod envelopes
   - Look for blocking operations in functions

## System Integration Summary

### How Everything Connects

1. **Initialization Chain**:
   ```
   _setup-loader.scd → synths → VST plugins → VSTManager → MIDI → Mappings → OSC
   ```

2. **Runtime Signal Flow**:
   ```
   MIDI Hardware → MIDIController → Mapping System → VSTManager → VSTPluginController → VSTPlugin UGen → Audio
   ```

3. **Control Hierarchy**:
   - **VSTPlugin**: Low-level audio processing
   - **VSTPluginController**: Direct plugin control
   - **VSTManager**: Group/instance management
   - **MIDIController**: Hardware interface
   - **ProcMod**: Process lifecycle wrapper

4. **Key Integration Points**:
   - VSTManager stores VSTPluginController references
   - MIDIController gets VST list from VSTManager
   - ProcMod wraps musical sequences that control VSTs
   - Mapping system translates MIDI CCs to parameters
   - OSC provides loose coupling between components

### Design Patterns Used

1. **Singleton**: VSTManager ensures single instance
2. **Observer**: ProcMod broadcasts state changes
3. **Facade**: VSTManager simplifies VST access
4. **Strategy**: Pluggable mapping templates
5. **Command**: ProcMod encapsulates operations

## Extension Points

The system is designed for extension:

1. **New Parameters**: Add to `~controlTemplates`
2. **Custom Modes**: Extend `~modes` dictionary
3. **Additional Layers**: Follow dual-layer pattern
4. **New Controllers**: Implement in control-systems.scd
5. **Custom GUI**: Extend sketch-gui.scd

## Performance Tips

1. **Pre-load VST programs** before performance
2. **Test MIDI mappings** with all parameters
3. **Set appropriate BPM** for your music
4. **Use groups** for quick VST set changes
5. **Monitor CPU** with many VST instances

---

This system represents a professional approach to live electronic music, balancing flexibility with real-time performance requirements. The parameter-centric design and dual-layer architecture provide extensive control for complex musical performances.