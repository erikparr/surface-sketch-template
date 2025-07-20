# LiveMelody Mode Implementation Plan

## Overview
LiveMelody mode enables real-time melody updates via OSC messages while layers are looping. Updates are queued and applied seamlessly at loop boundaries without interrupting playback.

## Architecture

### 1. OSC Message Format
```
/liveMelody/update/<layerName> <jsonData>
```

Where `<layerName>` is: `layer1`, `layer2`, or `layer3`

### 2. JSON Data Structure
```json
{
  "notes": [
    {
      "midi": 60,        // MIDI note number (0-127)
      "vel": 0.8,        // Velocity (0.0-1.0)
      "dur": 0.5         // Duration in seconds
    }
  ],
  "timing": [0.1, 0.2, 0.5, 0.2],  // Optional - fractional timing (must sum to 1.0)
  "metadata": {
    "durationType": "absolute",     // "absolute" or "fractional"
    "totalDuration": 4.0,          // Total loop duration
    "key": "C",                    // Optional metadata
    "scale": "major"               // Optional metadata
  },
  "expressionOverride": {          // Optional CC control override
    "expressionMin": 20,
    "expressionMax": 100,
    "expressionDurationScalar": 0.8
  }
}
```

### 3. Data Fields Explanation

#### Required Fields:
- **notes**: Array of note objects
  - **midi**: MIDI note number (0-127)
  - **vel**: Velocity as float (0.0-1.0, will be converted to 0-127)
  - **dur**: Note duration in seconds

#### Optional Fields:
- **timing**: Array of fractional time values (length = notes.length + 1)
  - First value: wait before first note
  - Middle values: inter-onset intervals
  - Last value: wait after last note
  - Must sum to 1.0
  - If omitted, notes are equally spaced

- **metadata**: Additional information
  - **durationType**: "absolute" (durations in seconds) or "fractional" (relative to available time)
  - **totalDuration**: Suggested total duration (may be overridden by current loop settings)
  - Other fields for documentation purposes

- **expressionOverride**: Override layer's CC expression settings
  - **expressionMin**: Minimum CC value (0-127)
  - **expressionMax**: Maximum CC value (0-127)
  - **expressionDurationScalar**: Duration multiplier (0.1-1.0)

## Implementation Steps

### Phase 1: Core Infrastructure
1. **Create layers-live-melody.scd**
   - OSC receiver setup
   - Data validation functions
   - Queue management
   - Data conversion utilities

2. **Modify layers-core.scd**
   - Add liveMelodyMode flag to state
   - Add pendingUpdates Dictionary
   - Add temporary melody storage

3. **Modify layers-playback.scd**
   - Check for pending updates at loop start
   - Apply updates without disrupting playback
   - Handle expression overrides

### Phase 2: Integration
4. **Update load-layers.scd**
   - Load layers-live-melody.scd after timing utilities

5. **Create test file**
   - Example OSC sender code
   - Test melodies with various timing patterns
   - Validation test cases

### Phase 3: UI Enhancement (Optional)
6. **Update layers-gui.scd**
   - Add liveMelody mode toggle
   - Show pending update indicators
   - Display current melody source (live vs preset)

## Key Design Decisions

1. **Non-disruptive Updates**: Updates only apply at loop boundaries to avoid glitches
2. **Queue System**: Multiple updates can be queued, latest overwrites previous
3. **Validation**: All data is validated before queuing to prevent runtime errors
4. **Backwards Compatible**: Works alongside existing melody system
5. **Expression Control**: Can override CC parameters per melody update

## Usage Example

### From SuperCollider:
```supercollider
// Enable live melody mode
~enableLiveMelodyMode.();

// Send update from SC (for testing)
~sendLiveMelodyUpdate.(\layer1, (
    notes: [
        (midi: 60, vel: 0.8, dur: 0.5),
        (midi: 62, vel: 0.7, dur: 0.5)
    ],
    timing: [0.2, 0.3, 0.5]
));
```

### From External Application:
```python
# Python example using python-osc
from pythonosc import udp_client
import json

client = udp_client.SimpleUDPClient("127.0.0.1", 57120)

melody_data = {
    "notes": [
        {"midi": 60, "vel": 0.8, "dur": 0.5},
        {"midi": 62, "vel": 0.7, "dur": 0.5}
    ],
    "timing": [0.2, 0.3, 0.5]
}

client.send_message("/liveMelody/update/layer1", json.dumps(melody_data))
```

## Testing Strategy

1. **Basic Functionality**
   - Single layer update
   - Multiple layer updates
   - Rapid successive updates

2. **Edge Cases**
   - Invalid JSON
   - Missing required fields
   - Timing array validation
   - Updates while not looping

3. **Performance**
   - High-frequency updates
   - Large melodies
   - CPU usage monitoring

## Future Enhancements

1. **Melody Interpolation**: Smooth transitions between melodies
2. **Pattern Library**: Store and recall live melodies
3. **MIDI Input**: Convert live MIDI input to melody updates
4. **Networked Collaboration**: Multiple users updating different layers
5. **Visual Feedback**: Real-time visualization of incoming melodies