# Sketch Looping Envelope System

A SuperCollider performance system that integrates looping pitch bend and expression envelopes with the VST-based sketch system.

## Overview

This system extends the original sketch system with continuous looping envelopes for:
- **Pitch Bend**: Automated pitch modulation with configurable percentage and duration
- **Expression Control**: Dynamic volume/timbre control via MIDI CC
- **Group-based Control**: Independent envelope settings for Strings, Winds, and Brass
- **Real-time MIDI Control**: Live parameter adjustment via MIDI sliders

## Features

### Looping Envelopes
- Continuous pitch bend envelopes (start → peak → return → loop)
- Expression envelopes for dynamic control
- Per-group parameter settings
- Time offset for staggered effects

### MIDI Control Mapping
- **Sliders 1-2**: Strings (bend percentage, duration)
- **Sliders 3-4**: Winds (bend percentage, duration)  
- **Sliders 5-6**: Brass (bend percentage, duration)
- **Slider 7**: Global expression level (0-127)
- **Slider 8**: Global expression duration (0.1-5.0s)

### VST Integration
- Works with existing VSTManager groups
- Automatic routing to target instances
- OSC-based envelope communication
- Support for multiple MIDI channels

## Quick Start

### Load the System
```supercollider
(PathName(thisProcess.nowExecutingPath).pathOnly ++ "load-sketch-looping-envelope.scd").load;
```

### Basic Usage
```supercollider
// Start performance with default settings
~startPerformance.value();

// Stop performance
~stopPerformance.value();

// Test a specific group
~testEnvelopePlayback.value(\Strings);

// Check envelope status
~printEnvelopeStates.value();
```

### Envelope Control
```supercollider
// Update group parameters manually
~groupEnvelopeParams[\Strings].bendPercent = 30;
~groupEnvelopeParams[\Strings].bendDuration = 5.0;
~applyEnvelopeToTarget.value(\Strings, ~groupEnvelopeParams[\Strings]);

// Start/stop group envelopes
~startGroupEnvelopes.value(\Winds);
~stopGroupEnvelopes.value(\Winds);
```

### Targeting
```supercollider
// Set target for playback
~setTarget.value(\Strings);  // Target strings only
~setTarget.value(\All);      // Target all groups

// Cycle through targets
~cycleTarget.value();
```

## System Architecture

### Core Components
1. **looping-envelope-system.scd**: Main envelope management
2. **osc-envelope-setup.scd**: OSC routing for bend/expression
3. **control-systems.scd**: MIDI mapping and parameter control
4. **musical-implementation.scd**: Musical playback with envelopes
5. **vst-targeting.scd**: Group targeting system

### Envelope Parameters
- **bendPercent**: Pitch bend amount (0-100%)
- **bendDuration**: Time to reach peak bend
- **exprLevel**: Expression level (0-127)
- **exprDuration**: Expression envelope duration
- **bendCurve/exprCurve**: Envelope curve type (\lin, \sin, \exp, \cub)
- **loopEnabled**: Enable/disable looping
- **timeOffset**: Offset for staggered starts

## GUI Controls

The system includes a comprehensive GUI with:
- Transport controls (Play/Stop)
- Group-specific envelope controls
- Real-time parameter display
- Active envelope indicators
- Emergency stop button

Access the GUI:
```supercollider
~createEnvelopeGUI.value();
```

## Troubleshooting

### Emergency Reset
```supercollider
~emergencyReset.value();  // Stops all envelopes and resets VSTs
```

### Check Active Envelopes
```supercollider
~printEnvelopeStates.value();  // Shows all active envelope synths
```

### Manual Envelope Stop
```supercollider
~stopAllEnvelopes.value();  // Force stop all envelopes
```

## Integration Notes

This system is designed to work with:
- VSTPlugin extension
- Existing VSTManager setup
- MIDI controller with 8+ sliders
- VST3 instruments (tested with SWAM)

The system uses OSC paths `/bend` and `/expression` for envelope communication, with `/expression2` available for dual-layer setups.