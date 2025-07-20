# Live Melody Mode - Quick Start Guide

## Overview
Live Melody Mode allows external applications to send real-time melody updates to the layers system via OSC messages. Updates are applied seamlessly at loop boundaries without interrupting playback.

## Sending Melody Data

### OSC Message Format
Send to: `/liveMelody/update/<layerName>`  
Where `<layerName>` is: `layer1`, `layer2`, or `layer3`

### JSON Data Structure
```json
{
  "notes": [
    {"midi": 60, "vel": 0.8, "dur": 0.5},
    {"midi": 62, "vel": 0.7, "dur": 0.5}
  ],
  "timing": [0.1, 0.3, 0.4, 0.2],  // Optional
  "metadata": {                     // Optional
    "durationType": "absolute",
    "totalDuration": 4.0,
    "key": "C",
    "scale": "major"
  },
  "expressionOverride": {          // Optional
    "expressionMin": 20,
    "expressionMax": 100,
    "expressionDurationScalar": 0.8
  }
}
```

## Converting from melody-export.json Format

If your application produces data like `melody-export.json`, you need to:
1. Extract each layer's data
2. Send separate OSC messages for each layer
3. Map layer names: `layer0` → `layer1`, `layer1` → `layer2`, `layer2` → `layer3`

### Python Example
```python
import json
from pythonosc import udp_client

# Read the export file
with open('melody-export.json', 'r') as f:
    data = json.load(f)

client = udp_client.SimpleUDPClient("127.0.0.1", 57120)

# Map layer names
layer_mapping = {
    "layer0": "layer1",
    "layer1": "layer2", 
    "layer2": "layer3"
}

# Send each layer
for json_layer, sc_layer in layer_mapping.items():
    if json_layer in data['layers']:
        layer_data = data['layers'][json_layer]
        
        # Create message in expected format
        msg = {
            "notes": layer_data['notes'],
            "timing": layer_data.get('timing'),
            "metadata": layer_data.get('metadata', {})
        }
        
        # Send to SuperCollider
        osc_path = f"/liveMelody/update/{sc_layer}"
        client.send_message(osc_path, json.dumps(msg))
        print(f"Sent {json_layer} to {sc_layer}")
```

## Usage in SuperCollider

### 1. Enable Live Melody Mode
```supercollider
~enableLiveMelodyMode.();
```

### 2. Start Layers Playing
```supercollider
// Set initial melodies (optional)
~setLayerMelody.(\layer1, \melody1);
~setLayerMelody.(\layer2, \melody2);
~setLayerMelody.(\layer3, \melody3);

// Enable looping
~layers.state.loopingMode = true;

// Start playing
~startLayers.(4.0);  // 4 second loops
```

### 3. Send Updates from External App
Your external application can now send melody updates at any time. Updates will be applied at the next loop boundary.

### 4. Monitor Status
```supercollider
~getLiveMelodyStatus.();  // Check pending updates
```

### 5. Disable When Done
```supercollider
~disableLiveMelodyMode.();
```

## Field Descriptions

### Required Fields
- **notes**: Array of note objects
  - **midi**: MIDI note number (0-127)
  - **vel**: Velocity (0.0-1.0, converted to 0-127 internally)
  - **dur**: Note duration in seconds

### Optional Fields
- **timing**: Custom rhythm pattern
  - Array length must be `notes.length + 1`
  - Values are fractions that must sum to 1.0
  - First value: wait before first note
  - Middle values: time between notes
  - Last value: wait after last note

- **metadata**: Additional information
  - **durationType**: "absolute" or "fractional"
  - **totalDuration**: Suggested loop duration (may be overridden)
  - **key**, **scale**: For documentation only

- **expressionOverride**: Override CC expression for this melody
  - **expressionMin**: CC value at start/end (0-127)
  - **expressionMax**: CC value at peak (0-127)
  - **expressionDurationScalar**: Envelope duration multiplier (0.1-1.0)

## Testing

### Test from SuperCollider
```supercollider
(thisProcess.nowExecutingPath.dirname +/+ "test-live-melody.scd").load;
~runFullTestSuite.();  // Run automated tests
```

### Manual Test
```supercollider
// Send a test update
~sendLiveMelodyUpdate.(\layer1, (
    notes: [
        (midi: 60, vel: 0.8, dur: 0.5),
        (midi: 64, vel: 0.7, dur: 0.5),
        (midi: 67, vel: 0.9, dur: 0.5)
    ],
    timing: [0.2, 0.3, 0.3, 0.2]
));
```

## Troubleshooting

### Updates Not Applied?
1. Check live melody mode is enabled: `~layers.state.liveMelodyMode`
2. Check layers are looping: `~layers.state.loopingMode`
3. Check for pending updates: `~getLiveMelodyStatus.()`
4. Look for error messages in SC post window

### Timing Issues?
- Timing array must have exactly `notes.length + 1` elements
- All timing values must sum to 1.0
- All values must be positive

### OSC Not Received?
- Verify SC is listening on port 57120
- Check firewall settings
- Test with loopback address (127.0.0.1)

## Advanced Features

### Rapid Updates
The system queues updates and applies the most recent one at each loop boundary. This allows for smooth real-time control.

### Expression Control
Each layer has independent CC expression control. You can override the expression envelope parameters per melody update.

### Custom Timing
Use the timing array to create complex rhythmic patterns. The system will calculate exact note placement based on the current loop duration.