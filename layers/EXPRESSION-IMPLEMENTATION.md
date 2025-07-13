# Layer-Specific Expression Control Implementation

## Overview
Successfully implemented independent CC envelope control for each of the 3 layers in the dependent layers system. Each layer now has its own expression envelope that can be controlled via MIDI knobs.

## Key Changes

### 1. SynthDefs (`setup/synths-setup.scd`)
- Added `ccEnvelope1` - sends to `/expression1` for Layer 1
- Added `ccEnvelope3` - sends to `/expression3` for Layer 3  
- Kept backward compatible `ccEnvelope` that sends to `/expression`
- Already had `ccEnvelope2` that sends to `/expression2`

### 2. OSC Responders (`setup/osc-setup.scd`)
- `~expressionFuncLayer1` - handles `/expression1` → Layer 1 VST group
- `~expressionFuncLayer2` - handles `/expression2` → Layer 2 VST group
- `~expressionFuncLayer3` - handles `/expression3` → Layer 3 VST group
- Kept backward compatible `~expressionFunc` for `/expression`

### 3. Layer Configuration (`layers/layers-core.scd`)
Each layer now has a `ccControl` dictionary with:
```supercollider
ccControl: (
    enabled: true,
    expressionCC: 11,
    expressionMin: 10,
    expressionMax: 120,
    expressionShape: \sin,
    expressionPeakPos: 0.5,
    expressionDurationScalar: 1.0
)
```

### 4. Playback Integration (`layers/layers-playback.scd`)
- `~updateLayerExpressionParams` - reads MIDI knob values for a layer
- `~startLayerCCEnvelope` - creates expression envelope synth
- Expression parameters are updated before each loop iteration
- CC envelopes are created with timing that matches parent duration

### 5. Control API (`layers/layers-control.scd`)
New functions for expression control:
- `~setLayerExpressionEnabled` - enable/disable per layer
- `~setLayerExpressionCC` - set CC number
- `~setLayerExpressionParams` - set min/max/shape/peak
- `~printLayerExpressionSettings` - debug info
- Preset system updated to save/load expression settings

## MIDI Control Mapping

### MIDIMix Layout (3 rows × 8 knobs)
- **Row 1** → Layer 1 expression control
- **Row 2** → Layer 2 expression control  
- **Row 3** → Layer 3 expression control

### For each row:
- **Position 4** (CC 28/29/30): Expression duration scalar (0.1-1.0)
- **Position 5** (CC 46/47/48): Expression minimum (0-127)
- **Position 6** (CC 50/51/52): Expression maximum (0-127)

## Usage Example

```supercollider
// Enable expression for all layers
~enableAllLayerExpression.();

// Enable MIDI control
~setLayersManualControl.(true);

// Start layers - expression will be controlled by MIDI knobs
~startLayers.(10);

// Adjust knobs during playback - changes apply on next loop
```

## Testing
All functionality has been tested and verified:
- ✓ SynthDefs load correctly
- ✓ OSC responders route to correct VST groups
- ✓ MIDI knobs control correct layers
- ✓ Expression envelopes sync with parent duration
- ✓ Parameters update on each loop iteration

## Files Modified
1. `setup/synths-setup.scd` - Added ccEnvelope1 and ccEnvelope3
2. `setup/osc-setup.scd` - Updated responders for layer-specific routing
3. `layers/layers-core.scd` - Added ccControl to layer configs
4. `layers/layers-playback.scd` - Integrated expression envelope creation
5. `layers/layers-control.scd` - Added expression control API
6. `layers/TODO.md` - Updated with implementation details
7. `layers/test-layers.scd` - Created test examples

## Notes
- Expression envelopes are created fresh for each loop iteration
- Envelope duration is scaled by `expressionDurationScalar` parameter
- All layers use MIDI channel 0 for VST control
- The system maintains backward compatibility with the original sketch system