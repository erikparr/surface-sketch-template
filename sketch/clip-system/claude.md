# MIDI Clip Recording & Playback System

## Overview
Replaces fixed melody timing with **recorded timing data** that preserves expressive performance and enables real-time tempo scaling.

## Core Concept
- **Before**: Fixed `noteDuration`, `noteRestTime` → robotic playback
- **After**: Recorded note timing + velocity → expressive playback with tempo scaling

## System Architecture

### Files & Dependencies
```
clip-system/
├── clip-loader.scd          # Main entry point
├── clip-playback.scd        # Core timing-based playback
├── clip-procmod.scd         # ProcMod integration
├── clip-integration.scd     # Sketch system integration
├── clip-controls.scd        # MIDI tempo controls
└── claude.md               # This documentation
```

**Load Order**: playback → procmod → integration → controls → loader

### Data Structure
```supercollider
// Recorded clip data (preserved timing)
clipData: (
    notePairs: [
        (note: 65, startTime: 0.593, duration: 0.301, velocity: 79, channel: 0),
        (note: 67, startTime: 1.195, duration: 0.303, velocity: 89, channel: 0),
        // ... preserves exact recorded timing
    ],
    duration: 2.316,
    metadata: (recordedAt: timestamp, noteCount: 3, eventCount: 6)
)
```

## Usage

### Loading
```supercollider
"sketch/clip-system/clip-loader.scd".loadRelative;
```

### Core Functions
```supercollider
~clipStatus.()                    // Show system status
~testClipPlayback.(clipKey)       // Test clip playback
~setClipTempo.(scale)            // Set tempo scale (0.25x - 4.0x)
~halfSpeed.() / ~normalSpeed.() / ~doubleSpeed.()
```

### MIDI Controls
- **CC 20**: Tempo scale (0.25x - 4.0x)
- **Note 26**: Cycle tempo presets (0.5x → 1.0x → 2.0x → 0.5x)

## Integration Points

### Melody Management
- Clips stored in `~melodyData` with `isClip: true`
- Compatible with existing melody sequence navigation
- Automatic detection in `~loadActiveMelodies.()`

### Sketch System
- Integrates with `~currentSequence` and `~currentLoopIndex`
- Uses existing ProcMod envelope system
- Routes through `/note/on` OSC messages to VST targets

### Timing Calculation
- `~calculateLoopWaitTime.()` handles both clips and traditional melodies
- Clip timing: `clipDuration / tempoScale`
- Traditional timing: existing `noteRest * noteCount` calculation

## Key Functions

### Playback Engine
```supercollider
~playClip.(clipData, tempoScale, targetVSTGroup)
// Schedules notes using recorded startTime/duration with tempo scaling
```

### ProcMod Creation
```supercollider
~createClipProc.(clipData, procModID)
// Creates ProcMod instance that plays clip with envelope control
```

### Validation
```supercollider
~isValidClip.(melody)           // Check if melody is valid clip
~isClipKey.(melodyKey)          // Check if key references clip
~getClipDuration.(clipData, tempoScale)  // Calculate scaled duration
```

## Technical Details

### Tempo Scaling
- **Formula**: `adjustedTime = recordedTime / tempoScale`
- **Range**: 0.25x (4x slower) to 4.0x (4x faster)
- **Preserves**: Relative timing relationships between notes

### Safety Features
- `~clipSystemLoading` flag prevents infinite loops during initialization
- Null checks for all clip system functions before calling
- Graceful fallback to traditional melody system

### Performance
- Uses `SystemClock.sched()` for precise timing
- Compatible with existing VST routing and parameter mapping
- Maintains sketch system's dual-layer architecture

## Status Indicators
- **🎵 CLIP**: Timing-based playback
- **♪ MELODY**: Traditional fixed timing
- **Current sequence**: Shows active clips vs melodies

## Error Handling
- Invalid clip data → fallback to traditional melody
- Missing functions → error messages with graceful degradation
- Infinite loop protection during system loading

## Future Extensions
- Multiple clip layering
- Clip editing (trim, quantize)
- Velocity scaling per clip
- Note filtering by channel/range 