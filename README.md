# Surfacing - Live Electronic Music Performance System

A sophisticated SuperCollider-based system for live electronic music performance with multiple VST instruments, real-time gestural control, automated musical sequencing, and dual-layer performance capabilities.

## Project Overview

This system provides a complete framework for live electronic music performance featuring:

- **Multi-VST Management**: Dynamic loading and control of multiple VST instrument instances with group-based targeting
- **Dual-Layer Performance**: Independent primary and secondary musical layers with separate MIDI control
- **Gestural Control**: Real-time MIDI control with automated expression envelopes (CC 16 and CC 17)
- **Musical Sequencing**: ProcMod-based melody playback with development cycle management
- **Parameter Automation**: Sophisticated CC control system with looping envelopes for both layers
- **Live Performance**: Hot-swappable VSTs, cycle switching, pause/resume, and independent layer control

## System Architecture

The system is built with a modular architecture where each component has clear responsibilities and integration points:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   surfacing.scd │    │   VSTManager.sc  │    │ MIDIController  │
│  (Primary Layer)│◄──►│  (VST Registry)  │◄──►│ (Hardware I/O)  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│second-layer.scd │    │  VSTPluginCtrl   │    │   MIDI Input    │
│ (Second Layer)  │    │  (VST Instances) │    │ (Row 1 & 2 Knobs│
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   OSC Bridge    │    │   Audio Engine   │    │   GUI Manager   │
│ (Layer Comm.)   │    │  (Dual CC Envs)  │    │ (VST Interface) │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Core Components

### 1. Setup Files and Initialization Process

The system's initialization is orchestrated by `setup/_setup-loader.scd`. This script defines the core setup directory and loads a sequence of files to establish the performance environment.

The loading order and purpose of each file are as follows:

#### **1. `setup/_setup-loader.scd` - The Orchestrator**
- **Purpose**: Initializes the setup process by loading other critical setup files in a specific order.
- **Key Actions**:
    - Defines the path to the `setup` directory.
    - Executes a loading function (`~loadWithDependencies`) that loads the following files sequentially.

#### **2. `setup/synths-setup.scd` - Synthesizer Definitions and Audio Foundation**
- **Purpose**: Defines the core audio processing units (`SynthDef`s) used throughout the system.
- **Key Actions**:
    - Creates `SynthDef`s like `\insert`, `\vstHost`, `\BendEnvelope`, `\ccEnvelope`, etc., which are essential for hosting VST plugins and generating control signals.
    - Configures basic audio routing and bus structures.
    - Defines envelopes for pitch bend and CC automation.

#### **3. `setup/vstplugin-setup.scd` - VST Plugin Integration**
- **Purpose**: Manages the discovery, loading, and initial configuration of VST plugins.
- **Key Actions**:
    - Searches for available VST3 plugins on the system (excluding specified ones like "Komplete Kontrol.vst3").
    - Creates `Synth` instances (e.g., using `\vstHost`) to host VSTs.
    - Initializes the `~vstManager` (an instance of `VSTManager`), which is central to managing VSTs.
    - Loads a predefined set of VST plugins (e.g., SWAM instruments) into the `~vstManager`.
    - Creates VST groups (e.g., 'Tuba').
    - Can open VST plugin editors automatically.

#### **4. `setup/vst-management.scd` - VST Management User Interface**
- **Purpose**: Provides a graphical user interface (GUI) for managing VST plugins at runtime.
- **Key Actions**:
    - Creates a window titled "VST Manager".
    - Allows users to load VSTs from a list defined in `data/vst-list.txt`.
    - Dynamically assigns output buses to loaded VSTs.
    - Provides controls to remove VST instances.
    - Integrates with a MIDI mapper (`setup/vst-midi-mapper.scd`).
    - Manages VST groups and allows assigning keyboard focus to specific groups.
    - Includes UI elements for MIDI control overrides like manual velocity.

#### **5. `setup/midi-setup.scd` - MIDI Hardware and Mapping Configuration**
- **Purpose**: Initializes MIDI input devices and sets up the mapping between MIDI controls and system parameters.
- **Key Actions**:
    - Initializes `~midiController` (an instance of `MIDIController`), providing it with the list of VST instances from `~vstManager`.
    - Configures `~midiController` presets (e.g., for 'midiMix').
    - Manages loading and saving of MIDI mappings from/to `surfacing/midi-mappings/midi-mappings.scd` in the user's application support directory.
    - Provides a mechanism (`~updateMIDIController`) to update the `MIDIController`'s VST list based on the `VSTManager`'s active group.

#### **6. `setup/osc-setup.scd` - Open Sound Control (OSC) Communication**
- **Purpose**: Handles incoming OSC messages for real-time control of VST parameters.
- **Key Actions**:
    - Defines `OSCFunc`s to respond to messages on paths like `/bend` and `/expression`.
    - Implements a helper `~getVSTByChannel` to retrieve VST controllers based on a channel index, using `~vstManager` to get the current instances and their order.
    - Routes pitch bend and expression CC values received via OSC to the appropriate VST instances.

#### **Auxiliary Setup Components:**

##### **`data/vst-list.txt`**
- **Purpose**: A simple text file listing the file paths to VST plugins that can be loaded through the `VST Manager` GUI. Each line should be a full path to a `.vst3` or other compatible VST file.
- **Used by**: `setup/vst-management.scd`.

##### **`snapshotData/snapshot-functions.scd`**
- **Purpose**: Provides a set of global utility functions that act as convenient wrappers around the `MIDIController`'s snapshot capabilities. While not loaded by `_setup-loader.scd`'s main dependency loader, it's available for use in compositional sketches.
- **Key Functions**:
    - `~saveSnapshot`, `~loadSnapshot`, `~listSnapshots`, `~deleteSnapshot`.
    - `~saveSnapshotsToFile`, `~loadSnapshotsFromFile` (for persisting snapshots in the `snapshotData` directory).
    - `~enableProgrammedMode`, `~disableProgrammedMode`.
    - `~getSliderValue`, `~getKnobValue` for accessing current control values.
- **Used by**: Composition files (e.g., `surfacing.scd`) for managing and recalling MIDI controller states.

### 2. Core Classes

#### **VSTManager.sc** - Central VST Registry
```supercollider
// Singleton pattern managing all VST instances
VSTManager {
    var <vstInstances, <groups, <activeGroup;
    
    // Returns controllers for MIDI communication
    getInstances {
        var instances = Dictionary.new;
        vstInstances.keysValuesDo { |name, instance|
            instances[name] = instance.controller;
        };
        ^instances;
    }
}
```

**Key Responsibilities:**
- VST instance lifecycle management
- Group-based organization
- Parameter control coordination
- Instance registry and lookup

#### **MIDIController.sc** - Hardware Interface
```supercollider
// Comprehensive MIDI handling
*new { |vstList, oscNetAddr, bendSynth, numKnobs, startCC, debug|
    // Maps CC 0-7 to sliders, CC 16-23 to knobs
    // Supports snapshots, button toggles, bend control
}
```

**Features:**
- Multi-channel MIDI routing
- Snapshot system for preset management
- Button toggle handling
- Velocity control and bend automation
- Debug and monitoring capabilities

### 3. Primary Layer (surfacing.scd)

#### **Musical Structure - Development Cycles**
```supercollider
~developmentCycles = Dictionary.new;
~developmentCycles.put(1, (name: "Second Cycle", sequence: [\part5a]));
~developmentCycles.put(2, (name: "Second Cycle", sequence: [\part5b]));
// Different musical sections for performance structure
```

#### **ProcMod Integration - Gestural Control**
```supercollider
~createMelodyProc = { |melodyKey, patternIndex=0|
    // Creates ASR envelope for sustained control
    var env = Env.asr(attackTime: 0.01, sustainLevel: 1.0, releaseTime: 0.1);
    
    ProcMod.new(env, 1.0, id, nil, 0, 1,
        // Main function - executes melody sequence
        { |group, envbus| /* melody playback logic */ },
        // Release function - cleanup
        { |group, envbus| /* resource cleanup */ }
    );
};
```

#### **Primary Layer CC Control System (CC 16)**
```supercollider
~startCCEnvelopes = { |melodyKey|
    // Creates expression envelopes for each VST using CC 16
    ~vstManager.getTargetInstances(~activeVSTGroup).keysValuesDo { |vstKey, vst, i|
        ccSynth = Synth(\ccEnvelope, [
            \chanIndex, i,  // VST index for OSC routing
            \ccNum, ~ccControl.expressionCC  // CC 16 for primary layer
        ]);
    };
};
```

#### **VST Group Targeting**
```supercollider
// Direct group control
~setActiveVSTGroup.("Tuba");     // Target specific VST group
~setActiveVSTGroup.("All");      // Target all instances

// Live performance cycling
~nextVSTGroup.value;             // Cycle to next group
~prevVSTGroup.value;             // Cycle to previous group
```

### 4. Second Layer (second-layer.scd)

#### **Independent Layer System**
The second layer operates completely independently from the primary layer:

```supercollider
// Second layer state management
~layer2 = (
    enabled: true,               // Start enabled by default
    currentMelodyKey: nil,       // Current melody being played
    noteIndex: 0,                // Current position in melody
    activeVSTGroup: nil,         // Independent VST group targeting
    
    // MIDI-controlled parameters (row 2 knobs)
    noteDuration: 0.2,           // CC 21 (row 2, pos 2)
    noteRestTime: 0.2,           // CC 25 (row 2, pos 3)
    velocity: 100,               // CC 29 (row 2, pos 4)
    noteOffset: -12,             // Independent note offset
    
    // Expression control (row 2 knobs)
    expressionMin: 10,           // CC 47 (row 2, pos 5)
    expressionMax: 120,          // CC 51 (row 2, pos 6)
    expressionDurationScalar: 1.0 // CC 55 (row 2, pos 7)
);
```

#### **OSC Communication Between Layers**
```supercollider
// Primary layer triggers second layer on first notes
if(isFirstNote) {
    NetAddr.localAddr.sendMsg('/layer2/trigger', melodyKey);
};

// Second layer receives triggers via OSC
OSCdef(\layer2Trigger, { |msg, time, addr, recvPort|
    var melodyKey = msg[1].asSymbol;
    ~layer2TriggerNote.(melodyKey);
}, '/layer2/trigger');
```

#### **Independent VST Targeting**
```supercollider
// Second layer has its own VST group targeting
~layer2SetVSTGroup.("Trumpet");  // Target different group than primary
~layer2UseAllVSTs.value;         // Or target all instances independently
```

## Data Flow Architecture

### 1. **MIDI Input Pipeline**
```
MIDI Controller → MIDIController.sc → Parameter Updates → Performance Control
```

### 2. **Musical Sequence Pipeline**
```
ProcMod → OSC Messages → OSCdef Responders → VST MIDI Notes
```

### 3. **Expression Control Pipeline**
```
Synth Envelopes → OSC '/expression' → osc-setup.scd → VST CC Parameters
```

### 4. **VST Management Pipeline**
```
GUI Actions → VSTManager → VST Loading/Removal → UI Updates → MIDI Routing
```

## Key Integration Points

### **VSTManager as Central Hub**
All components reference VSTManager for VST instance access:
```supercollider
~vstManager.getInstances()  // Returns Dict[name -> VSTPluginController]
```

### **OSC Communication Bridge**
Synths communicate with VSTs via OSC messaging:
```supercollider
// Synth sends OSC data
SendReply.kr(Impulse.kr(100), '/expression', [chanIndex, ccNum, env]);

// OSC responder distributes to all VSTs
instances.do { |vst| vst.midi.control(0, ccNum, exprValue); };
```

### **Dynamic Bus Assignment**
Automatic audio routing prevents conflicts:
```supercollider
outputBus = 2 + ((existingInstances * 2) % numOutputChannels);
// Each VST gets unique ADAT output (2,4,6,8...)
```

## Performance Features

### **Real-time Control**
- **Cycle Switching**: MIDI buttons (CC 58/59) for musical section changes
- **Pause/Resume**: CC 41 toggles note playback without stopping envelopes
- **Expression Control**: Automated CC 17 envelopes synchronized to melody timing
- **Velocity Control**: MIDI knob 7 or input velocity for dynamic control

### **Musical Structure**
- **Development Cycles**: Organized musical sections with different melody sequences
- **Continuous Loops**: Automatic cycling through melody sets with configurable repetitions
- **Fermata Control**: Hold/release functionality for expressive timing
- **Note Processing**: Configurable offset, velocity scaling, and temporal accents

### **System Management**
- **Hot-swapping**: Load/remove VSTs during performance without interruption
- **Parameter Mapping**: Real-time MIDI CC to VST parameter assignments
- **Snapshot System**: Save/recall complete parameter states
- **Debug Monitoring**: Comprehensive logging and status reporting

## MIDI Control Mapping

### **Primary Layer Controls (Row 1)**

#### **Sliders**
- **Slider 2 (CC 23)**: Current Note Rest (0.0001-1.0s)
- **Slider 7 (CC 57)**: Melody Rest Time (0.0-1.0s)
- **Slider 8 (CC 61)**: Temporal Accent (0-8x multiplier)

#### **Row 1 Knobs**
- **Knob 2 (CC 20)**: Note Duration (0.005-0.5s)
- **Knob 3 (CC 24)**: Note Rest Time (0.0001-0.4s)
- **Knob 4 (CC 28)**: Note Velocity (1-127)
- **Knob 5 (CC 46)**: Expression Min (0-127)
- **Knob 6 (CC 50)**: Expression Max (0-127)
- **Knob 7 (CC 54)**: Duration Scalar (0.1-1.0)

#### **Primary Layer Buttons**
- **CC 25**: Toggle Pause Notes mode
- **CC 45**: Toggle Melody Rest mode
- **CC 22**: Previous Cycle
- **CC 27**: Next Cycle

### **Second Layer Controls (Row 2)**

#### **Row 2 Knobs**
- **Knob 2 (CC 21)**: Note Duration (0.005-0.5s)
- **Knob 3 (CC 25)**: Note Rest Time (0.0001-0.4s)
- **Knob 4 (CC 29)**: Note Velocity (1-127)
- **Knob 5 (CC 47)**: Expression Min (0-127)
- **Knob 6 (CC 51)**: Expression Max (0-127)
- **Knob 7 (CC 55)**: Duration Scalar (0.1-1.0)

#### **Second Layer Buttons**
- **CC 46**: Toggle Second Layer (enable/disable)

## Usage Instructions

### **Starting a Performance**
```supercollider
// Load the primary layer
(PathName(thisProcess.nowExecutingPath).pathOnly ++ "surfacing.scd").load;

// Load the second layer (optional)
(PathName(thisProcess.nowExecutingPath).pathOnly ++ "second-layer.scd").load;

// Start continuous sequence playback (primary layer)
~startContinuousLoopSequence.value;

// Configure second layer (if loaded)
~layer2SetVSTGroup.("Trumpet");     // Target specific VST group
~layer2ShowStatus.value;            // Check second layer status

// Emergency stop all notes
~stopAllNotes.value;
```

### **VST Management**
- Use VST Manager GUI to load instruments from predefined list
- Click "Open MIDI Mapper" for real-time parameter control
- VSTs are automatically assigned to ADAT outputs (3/4, 5/6, 7/8, 1/2)

### **Real-time Control**
- Use MIDI controller sliders/knobs for performance parameters
- Use buttons for structural changes (cycles, pause, melody rest)
- Monitor post window for system status and debug information

## MIDI Control Mapping System

For detailed documentation on the advanced MIDI Control Mapping system that enables dynamic assignment of MIDI knob rows to different VST groups, see [midi-control-mapping-readme.md](midi-control-mapping-readme.md).

**Key Features:**
- Dynamic row-to-group assignments (Row 1→Strings, Row 2→Winds, etc.)
- Two control templates: Expression Control and Timing Control  
- Group-specific parameter storage with real-time updates
- GUI configuration interface with save/load functionality
- Full backward compatibility with existing control systems

## Technical Requirements

- **SuperCollider 3.12+** with VSTPlugin extension
- **VST3 Instruments** (currently configured for SWAM instruments)
- **MIDI Controller** (supports CC messages)
- **Audio Interface** with ADAT outputs (configured for RME Babyface Pro)
- **macOS** (paths currently hardcoded for macOS)

## File Structure

```
surfacing/
├── surfacing.scd                 # Primary layer application
├── second-layer.scd              # Secondary layer system
├── readme.md                     # Main documentation
├── midi-control-mapping-readme.md # MIDI Control Mapping documentation
├── setup/
│   ├── _setup-loader.scd         # Initialization coordinator
│   ├── synths-setup.scd          # SynthDef definitions
│   ├── vstplugin-setup.scd       # VST infrastructure
│   ├── vst-management.scd        # GUI interface
│   ├── midi-setup.scd            # MIDI integration
│   ├── midi-control-mapping.scd  # MIDI knob row mapping system
│   └── osc-setup.scd             # OSC communication
├── VSTManager/
│   └── VSTManager.sc             # Central VST management
├── reference/
│   └── MIDIController/
│       └── MIDIController.sc     # MIDI handling class
└── data/
    ├── vst-list.txt              # Available VST list
    ├── midi-control-mappings.scd # MIDI mapping configurations
    └── sketch-melody.scd      # Musical content
```

## Dual-Layer Performance System

### **Layer Communication**
- **Primary Layer**: Continuous melody sequences with ProcMod-based timing
- **Second Layer**: Triggered single notes synchronized to primary layer's first notes
- **OSC Bridge**: `/layer2/trigger` messages coordinate between layers
- **Independent Control**: Each layer has separate MIDI control rows and VST targeting

### **Expression Control**
- **Primary Layer**: CC 16 envelopes synchronized to melody duration
- **Second Layer**: CC 17 envelopes (planned) for independent expression control
- **Looping Envelopes**: Continuous expression automation during musical sequences
- **Real-time Control**: MIDI knobs adjust envelope parameters during performance

This system provides a robust, modular framework for live electronic music performance with sophisticated dual-layer control, automated musical sequencing, independent expression systems, and comprehensive VST management capabilities.
