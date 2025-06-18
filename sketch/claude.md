# Surfacing Core Sketch System - Context Guide

## Overview

The Surfacing Core sketch system is a sophisticated live electronic music performance framework built in SuperCollider. It provides real-time control of VST instruments through MIDI controllers, with support for complex musical sequencing, dual-layer performance, and parameter mapping.

## Architecture Overview

```
Setup System (../setup/) → Sketch System (./sketch/)
     ↓                           ↓
VST Management → VST Targeting & Musical Implementation
     ↓                           ↓
MIDI Controller → Control Systems & Parameter Routing
     ↓                           ↓
Parameter Mapping → ProcMod Sequencing → Live Performance
```

## Core Components

### 1. Main Loader (`load-sketch.scd`)

**Purpose**: Central orchestrator that bootstraps the entire performance system

**Key Responsibilities**:
- Loads setup system from `../setup/_setup-loader.scd`
- Initializes global state variables and control parameters
- Loads core modules in dependency order

**Critical Global Variables**:
```supercollider
// Performance parameters
~bpm = 298;
~noteDuration = 0.2;
~noteRest = 0.2;
~fermataDuration = 1.0;
~noteOffset = -12;
~repetitions = 1;

// Active state tracking
~activeCCSynths = Dictionary.new;     // Active CC envelope synths
~activeNotes = Dictionary.new;        // Currently playing notes
~activeVSTGroup = nil;                // Current VST group target

// Mode flags
~modes = (
    noteOffset: false,        // Apply semitone offset to notes
    fermata: true,           // Enable fermata (held notes) mode
    melodyRestMode: true,    // Add rests between melodies
    pauseNotesMode: false,   // Pause note playback
    removeLast: false,       // Remove last note from patterns
    velocityMultiply: false, // Apply velocity multipliers
    manualLooping: true      // Manual vs automatic melody advance
);

// CC control parameters
~ccControl = (
    enabled: true,
    expressionCC: 16,             // MIDI CC number for expression
    expressionMin: 10,            // Minimum expression value
    expressionMax: 120,           // Maximum expression value
    expressionShape: \sin,        // Envelope curve shape
    expressionPeakPos: 0.5,       // Peak position (0.0-1.0)
    expressionDurationScalar: 1.0, // Duration multiplier
    noteDuration: 0.2,            // Base note duration
    noteRestTime: 0.2,            // Rest between notes
    velocity: 100                 // MIDI velocity
);
```

**Module Loading Order**:
1. `core-functions.scd` - Fundamental building blocks
2. `vst-targeting.scd` - VST group management
3. `control-systems.scd` - MIDI and OSC control
4. `musical-implementation.scd` - ProcMod sequencing
5. `initialization-startup.scd` - Final setup and instructions

### 2. Core Functions (`core-functions.scd`)

**Purpose**: Fundamental building blocks for note processing and control

**Key Features**:

#### Parameter-Centric Routing
Uses intelligent parameter routing that checks mapping system before falling back to direct MIDI reading:

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

#### Utility Functions
- `~switchCycle.(cycleNumber)` - Change musical development cycles
- `~stopAllNotes.()` - Emergency stop all VST instances
- `~setMode.(mode, value)` - Configure system modes
- `~setRepetitions.(num)` - Set pattern repetition count

### 3. VST Targeting (`vst-targeting.scd`)

**Purpose**: Dynamic routing to different VST groups for layered performance

**Core Functions**:

#### Direct Group Control
```supercollider
~setActiveVSTGroup.('Bass Tuba');    // Target specific group
~setActiveVSTGroup.("All");          // Target all instances
~useAllVSTs.();                      // Convenience function
```

#### Live Performance Cycling
```supercollider
~nextVSTGroup.();     // Cycle to next group
~prevVSTGroup.();     // Cycle to previous group
~useVSTGroup.(0);     // Target by index
```

#### Status and Information
```supercollider
~showVSTTargeting.();  // Display current targeting status
~listVSTGroups.();     // Show all available groups with indices
```

**Key Features**:
- Supports both Symbol and String group names
- Handles "All" instances with nil internally
- Provides cycling for live performance
- Validates group existence before switching

### 4. Control Systems (`control-systems.scd`)

**Purpose**: MIDI button controls, CC envelope system, and OSC responders

**Key Components**:

#### MIDI Button Controls
```supercollider
// Note 21: Toggle melody rest mode
~toggleMelodyRest = MIDIdef.noteOn(\toggleMelodyRest, { |veloc, note, chan, src|
    if (note == 21 && veloc > 0) {
        ~modes.melodyRestMode = ~modes.melodyRestMode.not;
        // Takes effect on next loop cycle
    };
}, 21);

// Note 24: Toggle fermata mode  
// Note 25: Toggle pause notes
// Note 22: Previous melody
// Note 27: Next melody
```

#### CC Envelope System
Provides real-time expression control with parameter-aware routing:

```supercollider
~startCCEnvelopes = { |melodyKey|
    // Check if mapping system handles expression parameters
    var mappingHandlesExpressionMin = ~anyRowHandlesParameter.(\expressionMin);
    var mappingHandlesExpressionMax = ~anyRowHandlesParameter.(\expressionMax);
    
    if (mappingHandlesExpressionMin.not && mappingHandlesExpressionMax.not) {
        // Fallback: Read from MIDI knobs directly
        ~ccControl.expressionMin = ~midiController.getKnobRow1(5).linlin(0, 1, 0, 127);
        ~ccControl.expressionMax = ~midiController.getKnobRow1(6).linlin(0, 1, 0, 127);
    };
    
    // Create expression control synths for each target VST
    ~vstManager.getTargetInstances(~activeVSTGroup).keysValuesDo { |vstKey, vst, i|
        var ccSynth = Synth(\ccEnvelope, [
            \start, ~ccControl.expressionMin,
            \peak, ~ccControl.expressionMax,
            \end, ~ccControl.expressionMin,
            \attackTime, attackTime,
            \releaseTime, releaseTime,
            \chanIndex, i,
            \ccNum, ~ccControl.expressionCC
        ]);
        ~activeCCSynths[vstKey] = ccSynth;
    };
};
```

#### OSC Responders
Handle note events and fermata releases:
```supercollider
OSCdef(\noteOn, { |msg, time, addr, recvPort|
    var channel = msg[1].asInteger;
    var note = msg[2].asInteger;
    var velocity = msg[3].asInteger;
    var duration = msg[4].asFloat;
    var isFermata = msg[5].asInteger == 1;
    
    // Route to target VST instances
    ~vstManager.getTargetInstances(~activeVSTGroup).keysValuesDo { |vstName, vst|
        vst.midi.noteOn(0, note, velocity);
        
        if(duration.notNil && isFermata.not) {
            SystemClock.sched(duration, {
                vst.midi.noteOff(0, note, 0);
            });
        };
    };
}, '/note/on');
```

### 5. Musical Implementation (`musical-implementation.scd`)

**Purpose**: ProcMod-based sequencing system for live performance

#### ProcMod Integration

**What is ProcMod?**
ProcMod is a SuperCollider class for creating envelope-controlled musical processes. It provides:
- **Envelope Control**: Uses EnvGen.kr with ASR (Attack-Sustain-Release) envelopes
- **Function Execution**: Runs user-defined functions within controlled environments  
- **Resource Management**: Handles synth groups, buses, and cleanup automatically
- **Timing Control**: Supports custom tempos and time scaling

**Key ProcMod Methods**:
- `ProcMod.new(env, amp, id, group, addAction, target, function)` - Create instance
- `.play()` - Start the process with envelope control
- `.release()` - Release with envelope timing
- `.kill()` - Immediate stop and cleanup
- `.amp_(newamp)` - Real-time amplitude control

#### Melody ProcMod Creation

```supercollider
~createMelodyProc = { |melodyKey, patternIndex=0|
    var pattern = ~melodyDict[melodyKey].patterns[patternIndex];
    var id = (melodyKey ++ "_" ++ patternIndex).asSymbol;
    
    // ASR envelope: quick attack, sustain at 1, quick release
    var env = Env.asr(attackTime: 0.01, sustainLevel: 1.0, releaseTime: 0.1, curve: \lin);
    
    ProcMod.new(
        env,          // ASR envelope for control
        1.0,          // Amplitude
        id,           // Unique identifier
        nil,          // Group (create new)
        0,            // addAction
        1,            // target
        
        // Main function executed when ProcMod plays
        { |group, envbus|
            var task = Task({
                // Parameter routing with mapping awareness
                var mappingHandlesNoteDuration = ~anyRowHandlesParameter.(\noteDuration);
                var mappingHandlesNoteRestTime = ~anyRowHandlesParameter.(\noteRestTime);
                
                if (mappingHandlesNoteDuration) {
                    noteDuration = ~ccControl.noteDuration;
                } {
                    noteDuration = ~midiController.getKnobRow1(2).linlin(0, 1, 0.005, 0.5);
                };
                
                // Play through pattern with timing and expression control
                ~repetitions.do { |repIndex|
                    effectiveLength.do { |noteIndex|
                        var note = pattern[noteIndex];
                        var isFirstNote = (noteIndex == 0);
                        var isLastNote = (noteIndex == (effectiveLength - 1));
                        var isFermata = isLastNote && ~modes.fermata;
                        
                        // Process note (apply offset, velocity, etc.)
                        var processedNote = ~processNote.value(note, isFirstNote, isLastNote, melodyKey);
                        
                        // Send via OSC to control systems
                        NetAddr.localAddr.sendMsg('/note/on', 0, processedNote[0], processedNote[1],
                            actualDuration, isFermata.asInteger,
                            isFirstNote.asInteger, isLastNote.asInteger);
                        
                        // Trigger Layer 2 on first note
                        if(isFirstNote) {
                            NetAddr.localAddr.sendMsg('/layer2/trigger', melodyKey);
                        };
                        
                        actualWaitTime.wait;
                        noteIndex = noteIndex + 1;
                    };
                };
                
                // Handle fermata timing and melody rest
                // ... (fermata and rest logic)
            });
            
            task; // Return task for ProcMod to manage
        }
    );
};
```

#### Continuous Loop System

Provides automatic or manual melody sequencing:

```supercollider
~startContinuousLoopSequence = {
    ~continuousLoopTask = Task({
        inf.do { |iteration|
            var melodyKey = ~currentSequence[~currentLoopIndex];
            
            // Start CC envelopes for expression control
            ~startCCEnvelopes.value(melodyKey);
            
            // Create or retrieve ProcMod for this melody
            if(~melodyProcs[melodyKey].isNil) {
                ~melodyProcs[melodyKey] = ~createMelodyProc.value(melodyKey);
            };
            
            // Play the melody
            ~melodyProcs[melodyKey].play;
            
            // Wait for completion or manual advance
            if(~modes.manualLooping.not) {
                // Automatic progression
                ~currentLoopIndex = (~currentLoopIndex + 1) % ~currentSequence.size;
            };
            
            waitTime.wait;
        };
    });
    
    ~continuousLoopTask.play;
    ~continuousLoopRunning = true;
};
```

### 6. Dual Layer System (`dual-layer-system.scd`)

**Purpose**: Independent Layer 1 and Layer 2 with separate parameter control

**Key Features**:
- **Independent VST targeting**: `~activeVSTGroup` vs `~activeVSTGroup_2`
- **Separate parameter sets**: `~ccControl` vs `~ccControl_2`
- **Independent mode settings**: `~modes` vs `~modes_2`
- **MIDI row mapping**: Row 1 → Layer 1, Row 2 → Layer 2

**Layer 2 Setup**:
```supercollider
// Layer 2 state variables
~activeVSTGroup_2 = nil;
~ccControl_2 = (/* separate parameter set */);
~modes_2 = (/* separate mode flags */);

// Layer 2 VST targeting
~setActiveVSTGroup_2 = { |groupName|
    // Similar to Layer 1 but uses Layer 2 variables
};

// Layer 2 melody creation
~createMelodyProc_2 = { |melodyKey, patternIndex=0|
    // Uses Layer 2 parameters directly
    noteDuration = ~ccControl_2.noteDuration;
    noteRestTime = ~ccControl_2.noteRestTime;
    // ... rest of Layer 2 implementation
};
```

### 7. Initialization & Startup (`initialization-startup.scd`)

**Purpose**: Final setup and usage instructions

**Key Actions**:
- Loads active melodies: `~loadActiveMelodies.value`
- Initializes ProcMods for current sequence
- Displays comprehensive usage instructions

## Parameter Routing Architecture

### Parameter-Centric Approach

The system uses intelligent parameter routing that prioritizes the mapping system:

1. **Check Mapping System**: `~anyRowHandlesParameter.(\paramName)`
2. **Use Mapped Value**: If mapping exists, use `~ccControl.paramName`
3. **Fallback to Direct**: If no mapping, read MIDI knob directly

### Integration with MIDI Control Mapping

The sketch system integrates with the setup system's MIDI Control Mapping:

```supercollider
// Function from midi-control-mapping.scd
~anyRowHandlesParameter = { |paramName|
    var handled = false;
    ~rowMappings.keysValuesDo { |rowNum, mapping|
        if (mapping.enabled && mapping.template.notNil) {
            var template = ~controlTemplates[mapping.template];
            if (template.notNil) {
                var hasParam = template.knobMappings.any { |knobMap|
                    knobMap.param == paramName
                };
                if (hasParam) { handled = true; };
            };
        };
    };
    handled;
};
```

## Performance Control Flow

### Typical Performance Session

1. **System Initialization**:
   ```supercollider
   // Load the complete system
   "path/to/sketch/load-sketch.scd".load;
   ```

2. **VST Group Setup**:
   ```supercollider
   ~setActiveVSTGroup.('Bass Tuba');  // Target specific instrument group
   ~showVSTTargeting.();              // Verify targeting
   ```

3. **Start Performance**:
   ```supercollider
   ~startContinuousLoopSequence.();   // Begin automatic sequencing
   ```

4. **Live Control**:
   - MIDI buttons for mode toggles and melody navigation
   - MIDI knobs for real-time parameter control (if no mapping active)
   - MIDI mapping system for complex parameter routing

5. **Emergency Stop**:
   ```supercollider
   ~stopAllNotes.();                  // Stop everything immediately
   ```

### MIDI Control Reference

**Button Controls** (via MIDIdef.noteOn):
- **Note 21**: Toggle Melody Rest mode
- **Note 22**: Previous Melody  
- **Note 24**: Toggle Fermata mode
- **Note 25**: Toggle Pause Notes mode
- **Note 27**: Next Melody

**Slider Controls** (via MIDIController):
- **Slider 1**: Note Duration (if not mapped)
- **Slider 2**: Note Rest Time (if not mapped)  
- **Slider 3**: Velocity (if not mapped)
- **Slider 7**: Melody Rest Time
- **Slider 8**: Temporal Accent

**Knob Controls** (via MIDIController, if not mapped):
- **Row 1, Pos 5**: Expression Min
- **Row 1, Pos 6**: Expression Max
- **Row 1, Pos 4**: Expression Duration Scalar

## Key Design Patterns

### 1. Parameter-Centric Architecture
Instead of direct MIDI reading, the system:
- Checks mapping system first
- Uses mapped values when available  
- Falls back to direct reading as backup

### 2. Modular State Management
- Global modes in `~modes` dictionary
- Group-specific parameters in `~groupControlParams` 
- Complete state duplication for dual layers

### 3. ProcMod-Based Sequencing
- Uses ASR envelopes for controlled musical processes
- Integrates with SuperCollider's timing and resource management
- Provides real-time parameter updates during playback

### 4. OSC Communication
- Internal OSC messages for note events: `/note/on`, `/note/release`
- Layer triggering: `/layer2/trigger`  
- Enables loose coupling between components

### 5. Resource Management
- Automatic cleanup of synths and buses
- Proper handling of VST instances and MIDI responders
- Safe shutdown procedures

## File Dependencies

```
load-sketch.scd
├── ../setup/_setup-loader.scd (Setup system)
├── core-functions.scd (Note processing utilities)
├── vst-targeting.scd (VST group management)  
├── control-systems.scd (MIDI/OSC control)
├── musical-implementation.scd (ProcMod sequencing)
├── initialization-startup.scd (Final setup)
└── dual-layer-system.scd (Advanced dual-layer system)
```

This architecture provides a sophisticated, modular system for live electronic music performance with real-time parameter control, dual-layer sequencing, and flexible VST routing capabilities. 