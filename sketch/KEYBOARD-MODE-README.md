# Surfacing System - Keyboard Mode Documentation

## Overview

The Surfacing system is a sophisticated live electronic music performance framework built in SuperCollider. The Keyboard Mode transforms the system from sequence-based playback to real-time keyboard performance with dynamic pitch bend envelopes and sustained notes.

## Quick Start

1. **Enable Keyboard Mode**
   - Click the "Keyboard Mode" checkbox in the GUI
   - Or via code: `~modes.keyboardMode = true`

2. **Play Notes**
   - Use your MIDI keyboard to trigger notes (MIDI notes 28 and above)
   - First note creates a ProcMod (duration set by Row 3, Knob 4)
   - Each note gets its own pitch bend envelope
   - Notes play for the remaining ProcMod duration
   - Notes release when ProcMod expires

## MIDI Controls

### Keyboard Mode Specific Controls (Row 3)

| Control | MIDI CC | Function | Range |
|---------|---------|----------|-------|
| **Knob 1** | CC 18 | Pitch Bend Amount | 0 = -1 octave, 0.5 = no bend, 1 = +1 octave |
| **Knob 2** | CC 19 | Bend Peak Time | 0.1-0.9 (ratio of note duration) |
| **Knob 3** | CC 20 | Bend Return Time | Automatically calculated (1.0 - peak time) |
| **Knob 4** | CC 21 | ProcMod Duration | 1-30 seconds |
| **Knob 5** | CC 50 | Envelope Loop Ratio | 10-100% of ProcMod (controls both CC & Bend loops) |

### Global Performance Controls

#### Button Controls (MIDI Notes)
| Button | MIDI Note | Function | Description |
|--------|-----------|----------|-------------|
| Mute 1 | 1 | Toggle Melody Rest | Add pauses between phrases |
| Mute 2 | 4 | Toggle Fermata | Hold notes longer |
| Mute 3 | 7 | Toggle Pause Notes | Temporarily stop note generation |
| Mute 4 | 10 | Toggle Chord Progression | Switch between melody/chord modes |
| Mute 5 | 13 | Toggle Sustain | Disable automatic noteOff messages |
| Mute 8 | 22 | Previous Melody | Navigate to previous melody |
| Rec Arm 1 | 3 | Toggle Keyboard Mode | Enable/disable keyboard mode |
| Bank Left | 25 | Previous Chord | Navigate chords (chord mode only) |
| Bank Right | 26 | Next Chord | Navigate chords (chord mode only) |
| Solo | 27 | Next Melody | Navigate to next melody |

#### Slider Controls (Row 1)
| Slider | MIDI CC | Function | Range |
|--------|---------|----------|-------|
| 1 | CC 0 | Note Duration | 0.1 - 10.0 seconds |
| 2 | CC 1 | Note Rest Time | 0.0001 - 0.4 seconds |
| 3 | CC 2 | Velocity | 1 - 127 |
| 4 | CC 3 | Melody Rest Time | 0.0 - 1.0 seconds |
| 5 | CC 4 | Temporal Accent | 0 - 8x multiplier |

#### Knob Controls (Row 1)
| Knob | Position | MIDI CC | Function | Range |
|------|----------|---------|----------|-------|
| 1 | 0 | CC 16 | Expression Min | 0 - 127 |
| 2 | 1 | CC 17 | Expression Max | 0 - 127 |
| 4 | 3 | CC 19 | Expression Duration | 10% - 100% of melody |
| 7 | 6 | CC 22 | First Note Rest | 1.0 - 2.0x multiplier |

## Keyboard Mode Features

### ProcMod System
- **Duration**: Adjustable 1-30 seconds via MIDI (Row 3, Knob 4)
- **Triggering**: First note creates new ProcMod
- **Sharing**: All notes within active ProcMod share the same instance
- **Expiration**: New ProcMod created when previous expires

### Note Behavior
- **Duration**: Uses remaining ProcMod duration
- **Auto-Release**: Notes release when ProcMod expires
- **Polyphony**: Multiple simultaneous notes supported
- **Routing**: Multi-instrument mode routes notes to different VSTs
- **Independence**: Each note has its own bend envelope

### Pitch Bend Envelopes
- **Per-Note**: Each note gets independent bend control
- **Looping**: Continuously loops using same ratio as CC envelope
- **Loop Duration**: Controlled by Row 3, Knob 5 (shared with CC envelope)
- **Shape**: Start → Peak → Return to center → Loop
- **Range**: ±1 octave (adjustable via MIDI)
- **Auto-Stop**: Bend envelope stops when ProcMod expires

### CC Expression Envelope
- **Looping**: Continuously loops throughout ProcMod duration
- **Loop Duration**: Controlled by Row 3, Knob 5 (10-100% of ProcMod)
- **Envelope Shape**: Attack (50%) → Peak → Release (50%)
- **Example**: 50% ratio with 10s ProcMod = 5s loop cycle (2 loops total)
- **Control**: Uses existing expression parameters (min/max values)

## VST Group Management

### Targeting VST Groups
```supercollider
// Target specific group
~setActiveVSTGroup.("Bass Tuba");

// Target all VSTs
~setActiveVSTGroup.("All");

// Cycle through groups
~nextVSTGroup.();
~prevVSTGroup.();
```

### Multi-Instrument Mode
When enabled, notes are distributed across VST instances in round-robin fashion:
- Note 1 → VST 1
- Note 2 → VST 2
- Note 3 → VST 3
- Note 4 → VST 1 (cycles back)

## Technical Details

### State Management
The keyboard mode maintains state in `~keyboardModeState`:
- `enabled`: Mode on/off
- `currentProcMod`: Active ProcMod instance
- `procModStartTime`: When ProcMod started
- `activeNotes`: Dictionary of playing notes
- `keyboardMIDIFuncs`: MIDI handler references

### MIDI Routing
When keyboard mode is enabled:
1. MIDIController note handling is disabled
2. Keyboard mode sets up its own MIDI handlers
3. MIDI notes 1-27 are reserved for control buttons and ignored
4. Only MIDI notes 28 and above trigger musical notes
5. Notes are routed directly to VST instances
6. Note-offs are ignored (sustained playback)

### Integration Points
- **GUI**: Checkbox in sketch-gui.scd
- **MIDI**: Direct integration with MIDIController
- **VST**: Uses VSTManager for instance access
- **ProcMod**: Leverages existing lifecycle management

## Troubleshooting

### Common Issues

1. **No Sound**
   - Check VST group is selected
   - Verify VSTs are loaded in VSTManager
   - Ensure MIDI controller is connected

2. **Bend Not Working**
   - Enable bend envelopes first
   - Check Row 3 knobs are sending CC 18/19
   - Verify BendEnvelopeLoop SynthDef is loaded

3. **Notes Cut Off Early**
   - This is normal - notes sustain for ProcMod duration
   - Adjust timing if needed

4. **MIDI Conflicts**
   - Keyboard mode disables normal note handling
   - Check mapping system isn't intercepting CCs
   - Verify Row 3 is not mapped to other parameters

## Advanced Usage

### Custom ProcMod Duration
```supercollider
~keyboardModeState.procModDuration = 20;  // 20 seconds
```

### Manual Bend Control
```supercollider
// Bypass MIDI, set bend directly
~bendEnvelopeParams.bendAmount = 0.5;  // Half octave up
```

### Debug Mode
Monitor keyboard mode activity:
```supercollider
// Watch console for detailed logging
// All keyboard mode actions are prefixed with "Keyboard Mode:"
```

## Performance Tips

1. **Bend Control**: Keep knob centered (0.5) for no bend during normal playing
2. **Peak Time**: Shorter peak times (0.1-0.3) create snappier bends
3. **Expression**: CC envelope still triggers - adjust for musical effect
4. **Polyphony**: System handles multiple notes well but monitor CPU
5. **Mode Switching**: Stop all notes before toggling keyboard mode

## Quick Reference Card

### Essential Controls
- **Enable**: GUI Checkbox or `~modes.keyboardMode = true`
- **Bend Amount**: Row 3, Knob 1 (CC 18)
- **Bend Timing**: Row 3, Knob 2 (CC 19)
- **VST Target**: `~setActiveVSTGroup.("groupName")`

### Key Concepts
- Adjustable ProcMod duration (1-30 seconds)
- Notes use remaining ProcMod time
- Per-note bend envelopes (synchronized to remaining ProcMod time)
- Automatic note release when ProcMod expires
- Multi-instrument routing

---

For more information about the complete Surfacing system, see the main documentation in `/sketch/claude.md`