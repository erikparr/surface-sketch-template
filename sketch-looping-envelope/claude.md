# Sketch Looping Envelope System - Technical Documentation

## System Overview

The sketch-looping-envelope system is an advanced SuperCollider performance framework that extends the original sketch system with continuous looping envelopes for pitch bend and expression control. It integrates seamlessly with the VSTManager infrastructure while adding sophisticated real-time modulation capabilities.

## Architecture

### Core Design Principles

1. **Modular Envelope Management**: Each VST instance can have independent pitch bend and expression envelopes
2. **Group-Based Control**: Envelopes are organized by instrument groups (Strings, Winds, Brass)
3. **Real-Time Parameter Updates**: MIDI sliders provide continuous control during performance
4. **OSC-Based Communication**: Envelopes communicate with VSTs via OSC messages

### System Components

#### 1. Looping Envelope System (`looping-envelope-system.scd`)
The heart of the system, managing:
- **Synth Tracking**: Dictionaries tracking bend/expression synths per VST
- **Parameter Management**: Group-specific envelope settings
- **Envelope Lifecycle**: Start/stop/update functions
- **MIDI Update Routine**: 10Hz parameter polling

Key data structures:
```supercollider
~bendSynths = Dictionary.new;        // vstName -> bend synth
~exprSynths = Dictionary.new;        // vstName -> expression synth
~groupEnvelopeParams = Dictionary.new; // groupName -> parameter set
```

#### 2. OSC Envelope Setup (`osc-envelope-setup.scd`)
Handles envelope-to-VST communication:
- **`/bend` OSC path**: Routes pitch bend values (0-16383)
- **`/expression` OSC path**: Routes expression CC values (0-127)
- **`/expression2` OSC path**: Alternative path for dual-layer setup
- **Target-aware routing**: Sends to appropriate VST instances based on current target

#### 3. Control Systems (`control-systems.scd`)
MIDI control mapping with intelligent parameter scaling:
- **Sliders 0-5**: Group-specific bend percentage and duration
- **Sliders 6-7**: Global expression level and duration
- **Knobs 16-23**: Envelope curves and additional parameters
- **Real-time updates**: Parameters applied immediately to active envelopes

#### 4. Musical Implementation (`musical-implementation.scd`)
Integration with ProcMod-based playback:
- **Envelope-aware note processing**: Notes trigger appropriate envelopes
- **Chord processing**: Staggered envelope starts for natural phrasing
- **Pattern library**: Pre-configured musical patterns with envelope settings
- **Layer support**: Independent envelope control for dual layers

### Envelope Mechanics

#### Pitch Bend Envelope
Uses `BendEnvelopeLoop` SynthDef:
- **Stages**: start → peak → return (looping)
- **Parameters**: 
  - `bendPercent`: 0-100% of pitch bend range
  - `bendDuration`: Time to reach peak
  - `bendCurve`: Envelope shape (\lin, \sin, \exp, \cub)
- **MIDI Range**: 0-16383 (center at 8192)

#### Expression Envelope
Uses `ExpressionEnvelopeLoop` SynthDef:
- **Stages**: start → peak → end (looping)
- **Parameters**:
  - `exprLevel`: 0-127 MIDI CC value
  - `exprDuration`: Attack time
  - `exprCurve`: Envelope shape
- **CC Number**: 11 (expression) by default

### Integration Points

#### VSTManager Integration
- Leverages existing VST instance registry
- Uses group membership for targeting
- Maintains compatibility with hot-swapping

#### ProcMod Integration
- Envelopes tied to ProcMod lifecycle
- Automatic cleanup on release
- Support for re-triggerable events

#### MIDI Controller Integration
- Uses existing MIDIController infrastructure
- Slider values polled continuously
- Direct parameter mapping without intermediary

### Performance Optimizations

1. **Efficient OSC Messaging**: 100Hz update rate balances responsiveness and CPU
2. **Lazy Evaluation**: Envelopes only created when needed
3. **Group Updates**: Batch parameter changes for efficiency
4. **Resource Management**: Automatic synth cleanup prevents memory leaks

### Advanced Features

#### Time Offset System
- Per-instance time offsets create natural staggering
- Configurable via knob control
- Prevents phase-locked modulation

#### Envelope Presets
- Save/load complete envelope configurations
- Stored in user app support directory
- Includes all group parameters and defaults

#### Emergency Systems
- `~emergencyReset`: Complete system reset
- `~stopAllEnvelopes`: Force stop all modulation
- Automatic VST reset (bend to center, expression to 0)

### Usage Patterns

#### Basic Performance Flow
1. System loads and initializes envelope parameters
2. User adjusts MIDI sliders for desired modulation
3. Performance starts, triggering notes with envelopes
4. Real-time parameter adjustments affect active envelopes
5. System cleanup on stop

#### Dynamic Control Flow
```
MIDI Slider → Control System → Parameter Update → Active Envelope Update → OSC Message → VST Parameter
```

#### Musical Event Flow
```
ProcMod Event → Note Processing → Envelope Start → Continuous Modulation → Note Off → Envelope Stop
```

### Extension Points

1. **Custom Envelope Shapes**: Add new SynthDefs for different modulation types
2. **Additional CC Control**: Extend beyond expression to filter, pan, etc.
3. **Preset Morphing**: Interpolate between saved presets
4. **Pattern Recording**: Capture and replay envelope performances

### Best Practices

1. **Parameter Ranges**: Keep bend percentages reasonable (10-30%) for musicality
2. **Duration Matching**: Align envelope durations with musical phrases
3. **Group Coordination**: Use consistent settings within instrument families
4. **CPU Management**: Monitor synth count with many active envelopes

### Technical Considerations

1. **OSC Timing**: Small latency between envelope generation and VST response
2. **MIDI Resolution**: 7-bit MIDI values scaled appropriately
3. **Synth Ordering**: Envelopes run in parallel with audio processing
4. **Memory Usage**: Each envelope uses minimal resources but scales with instance count

This system represents a sophisticated integration of modular synthesis concepts with modern VST hosting, providing expressive real-time control while maintaining the flexibility of the original sketch architecture.