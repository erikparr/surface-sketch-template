# Dual Layer MIDI Control System

A SuperCollider system that enables independent control of two musical layers using separate MIDI controller rows, allowing for complex polyphonic performances with real-time parameter manipulation.

## Overview

The Dual Layer MIDI Control System extends existing SuperCollider musical sketches to support two independent musical layers, each controlled by different rows of a MIDI controller. This enables musicians to perform complex arrangements where each layer can have different VST instruments, timing parameters, and expression controls.

## Key Features

### 🎵 **Independent Musical Layers**
- **Layer 1**: Original musical system with existing functionality
- **Layer 2**: Complete duplicate system with independent state and control
- Each layer can target different VST groups simultaneously
- Independent melody sequences, timing, and expression parameters

### 🎛️ **MIDI Row Mapping**
- **Row 1 Controls** → Layer 1 parameters (velocity, note duration, expression, etc.)
- **Row 2 Controls** → Layer 2 parameters (independent parameter control)
- Real-time parameter updates during playback
- Automatic parameter validation and range checking

### 🎹 **VST Integration**
- Independent VST group assignment per layer
- Support for multiple VST instances per layer
- Expression envelope control via CC messages
- Multi-channel MIDI output support

### 🖥️ **GUI Management**
- Intuitive control interface for layer management
- VST group assignment dropdowns
- Transport controls (start/stop) for each layer
- Real-time status monitoring
- Dual layer mode toggle

## Architecture

```
┌─────────────────┐    ┌─────────────────┐
│   MIDI Row 1    │───▶│    Layer 1      │───▶ VST Group A
│  (Knobs 1-8)    │    │  (~ccControl)   │
└─────────────────┘    └─────────────────┘

┌─────────────────┐    ┌─────────────────┐
│   MIDI Row 2    │───▶│    Layer 2      │───▶ VST Group B
│  (Knobs 9-16)   │    │ (~ccControl_2)  │
└─────────────────┘    └─────────────────┘
```

### Core Components

1. **Layer 2 State Management**: Complete duplication of Layer 1 variables with `_2` suffix
2. **MIDI Row Mapping**: Automatic routing of Row 2 controls to Layer 2 parameters
3. **VST Group Targeting**: Independent VST group assignment per layer
4. **Parameter Synchronization**: Real-time updates during melody playback
5. **GUI Interface**: Comprehensive control and monitoring system

## Installation & Setup

### Prerequisites
- SuperCollider with VSTPlugin extension
- Existing musical sketch system (melody dictionaries, VST manager, MIDI controller)
- MIDI controller with at least 2 rows of knobs/controls

### Quick Start

1. **Load the system:**
   ```supercollider
   // Load your existing sketch system first, then:
   "sketch/dual-layer-system.scd".loadRelative;
   ```

2. **Open the GUI:**
   ```supercollider
   ~showDualLayerGUI.();
   ```

3. **Configure layers:**
   - Select VST groups for Layer 1 and Layer 2
   - Enable "Dual Layer Mode"
   - Click "Setup Row 2 → Layer 2 Mapping"

4. **Start performance:**
   - Use GUI transport controls or manual commands
   - Row 1 knobs control Layer 1, Row 2 knobs control Layer 2

## Usage

### GUI Control (Recommended)
```supercollider
~showDualLayerGUI.();  // Opens complete control interface
```

### Manual Control
```supercollider
// Layer setup
~setupLayer1.("VSTGroupName1");
~setupLayer2.("VSTGroupName2");

// Transport control
~startContinuousLoopSequence.();      // Start Layer 1
~startContinuousLoopSequence_2.();    // Start Layer 2
~stopContinuousLoopSequence.();       // Stop Layer 1
~stopContinuousLoopSequence_2.();     // Stop Layer 2
```

### MIDI Parameter Mapping

| Row 1 (Layer 1) | Row 2 (Layer 2) | Parameter |
|------------------|------------------|-----------|
| Knob 1 | Knob 9 | Velocity |
| Knob 2 | Knob 10 | Note Duration |
| Knob 3 | Knob 11 | Note Rest Time |
| Knob 4 | Knob 12 | Expression Duration Scalar |
| Knob 5 | Knob 13 | Expression Min |
| Knob 6 | Knob 14 | Expression Max |

## Technical Details

### State Variables
- **Layer 1**: `~activeVSTGroup`, `~ccControl`, `~modes`, etc.
- **Layer 2**: `~activeVSTGroup_2`, `~ccControl_2`, `~modes_2`, etc.

### Key Functions
- `~createMelodyProc_2`: Layer 2 melody creation
- `~startContinuousLoopSequence_2`: Layer 2 loop control
- `~setupRow2ToLayer2Mapping`: MIDI mapping configuration
- `~dualLayerUtils`: Utility functions with error handling

### MIDI Integration
- Automatic Row 2 → Layer 2 parameter routing
- Real-time parameter updates during playback
- Fallback to direct knob reading when mapping unavailable
- Parameter validation and range checking

## Performance Workflow

1. **Setup Phase**:
   - Load VST instruments into different groups
   - Assign Layer 1 to one VST group, Layer 2 to another
   - Configure Row 2 → Layer 2 mapping

2. **Performance Phase**:
   - Start both layers independently or together
   - Use Row 1 knobs to control Layer 1 expression and timing
   - Use Row 2 knobs to control Layer 2 expression and timing
   - Real-time parameter changes affect ongoing melodies

3. **Monitoring**:
   - GUI shows current VST assignments and running status
   - Console output provides detailed parameter update information
   - Status bar shows layer states and mapping configuration

## Troubleshooting

### Common Issues
- **"VST Group not found"**: Ensure VST groups exist before assignment
- **"MIDI mapping not available"**: Check that MIDI controller is connected and configured
- **Layer not responding**: Verify VST group assignment and Row 2 mapping setup

### Debug Information
The system provides extensive console output for monitoring:
- Parameter updates: `"Row 2 → Layer 2: parameter = value"`
- Layer status: `"Layer 2 - Using current noteRestTime: 0.2"`
- VST targeting: `"Layer 2 VST Group targeting set to: GroupName"`

## Integration

This system is designed to integrate with existing SuperCollider musical sketches that include:
- Melody dictionary system (`~melodyDict`)
- VST manager (`~vstManager`)
- MIDI controller (`~midiController`)
- Expression control system (`~ccControl`)

The dual layer system extends these components without modifying the original Layer 1 functionality.

## License

This system is designed for use with existing SuperCollider musical performance systems. Ensure compatibility with your specific setup and requirements. 