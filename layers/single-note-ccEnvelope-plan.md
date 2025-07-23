# Single Note CC Envelope Mode - Implementation Plan

## Overview
Add a new mode where CC envelopes trigger once per note instead of once per melody loop. This creates more dynamic expression control that follows individual notes.

## Current System Analysis

### Current Behavior
- CC envelopes trigger once per layer per loop in parent ProcMod
- Duration equals layer duration × expressionDurationScalar
- Each layer has independent CC envelope synths (ccEnvelope1/2/3)
- Expression parameters controlled via MIDI knobs on respective rows

### Key Code Locations
1. **Envelope Triggering**: `layers-playback.scd` lines 193-201 (parent ProcMod)
2. **Note Playback**: `layers-playback.scd` lines 380-384, 419-424 (child ProcMod)
3. **SynthDefs**: `setup/synths-setup.scd` - ccEnvelope1/2/3 definitions
4. **Configuration**: `layers-core.scd` - ccControl dictionaries per layer

## Implementation Steps

### Step 1: Add Mode Toggle to State
**File**: `layers/layers-core.scd`
```supercollider
state: (
    // ... existing state ...
    singleNoteCCMode: false,  // Toggle for per-note CC envelopes
    ccEnvelopeDurationScalar: 1.0,  // Scale envelope duration (0.1-2.0)
    ccEnvelopeMaxScalar: 1.0  // Scale envelope max value (0.1-2.0)
)
```

### Step 2: Move CC Envelope Triggering
**File**: `layers/layers-playback.scd`

1. **Remove from parent ProcMod** (lines 193-201)
   - Keep the envelope parameter update (~updateAllLayerExpressionParams)
   - Remove ~startLayerCCEnvelope calls

2. **Add to child ProcMod** (~playLayerNote function)
   - Trigger CC envelope per note when singleNoteCCMode is enabled
   - Use note duration as base envelope duration
   - Apply scalars from MIDI knobs

### Step 3: Create Per-Note CC Envelope Function
**File**: `layers/layers-playback.scd`
```supercollider
~startPerNoteCCEnvelope = { |layerName, noteDuration|
    var config = ~layers.configs[layerName];
    var ccControl = config.ccControl;
    var synthDefName = switch(layerName,
        \layer1, { \ccEnvelope1 },
        \layer2, { \ccEnvelope2 },
        \layer3, { \ccEnvelope3 }
    );
    
    if (ccControl.notNil && ccControl.enabled && ~layers.state.singleNoteCCMode) {
        var durationScalar = ~layers.state.ccEnvelopeDurationScalar;
        var maxScalar = ~layers.state.ccEnvelopeMaxScalar;
        var scaledDuration = noteDuration * durationScalar;
        var scaledMax = ccControl.expressionMax * maxScalar;
        var attackTime = scaledDuration * ccControl.expressionPeakPos;
        var releaseTime = scaledDuration * (1.0 - ccControl.expressionPeakPos);
        
        Synth(synthDefName, [
            \start, ccControl.expressionMin,
            \peak, scaledMax.clip(0, 127),
            \end, ccControl.expressionMin,
            \attackTime, attackTime,
            \releaseTime, releaseTime,
            \chanIndex, 0,
            \ccNum, ccControl.expressionCC,
            \attackCurve, ccControl.expressionShape,
            \releaseCurve, ccControl.expressionShape
        ]);
    };
};
```

### Step 4: Modify Note Playback
**File**: `layers/layers-playback.scd` (~playLayerNote)
```supercollider
~playLayerNote = { |layerName, note, velocity, duration|
    // ... existing VST routing code ...
    
    // Trigger per-note CC envelope if enabled
    if (~layers.state.singleNoteCCMode) {
        ~startPerNoteCCEnvelope.(layerName, duration);
    };
};
```

### Step 5: Add MIDI Knob Control
**File**: `layers/layers-control.scd`

1. **Add knob reading function**:
```supercollider
~updateSingleNoteCCParams = {
    if (~midiController.notNil) {
        // Row 1, Knob 7: CC envelope duration scalar (0.1-2.0)
        var knob7 = ~midiController.getKnobRow1(7);
        ~layers.state.ccEnvelopeDurationScalar = knob7.linlin(0, 127, 0.1, 2.0);
        
        // Row 1, Knob 1: CC envelope max scalar (0.1-2.0)
        var knob1 = ~midiController.getKnobRow1(1);
        ~layers.state.ccEnvelopeMaxScalar = knob1.linlin(0, 127, 0.1, 2.0);
    };
};
```

2. **Call in parent ProcMod loop** (before each iteration)

### Step 6: Update Playback Logic
**File**: `layers/layers-playback.scd`

Modify parent ProcMod to handle both modes:
```supercollider
// In parent ProcMod loop (around line 193)
if (~layers.state.singleNoteCCMode) {
    // Update MIDI parameters for single note mode
    ~updateSingleNoteCCParams.();
    // Don't start CC envelopes here - they'll trigger per note
} {
    // Original behavior - one envelope per layer per loop
    ~layers.configs.keysValuesDo { |layerName, config|
        if (config.enabled and: { config.melodyList.size > 0 }) {
            var ccSynth = ~startLayerCCEnvelope.(layerName, currentDuration);
            if (ccSynth.notNil) {
                ~layers.timingData[layerName].ccSynth = ccSynth;
            };
        };
    };
};
```

### Step 7: Add Control API
**File**: `layers/layers-control.scd`
```supercollider
// Enable/disable single note CC mode
~setSingleNoteCCMode = { |enabled|
    ~layers.state.singleNoteCCMode = enabled;
    "Single note CC envelope mode: %".format(enabled).postln;
};

// Get current mode status
~getSingleNoteCCMode = {
    ~layers.state.singleNoteCCMode
};
```

### Step 8: Update GUI
**File**: `layers/layers-gui.scd`

Add checkbox for single note CC mode:
```supercollider
// After manual control checkbox
singleNoteCCCheck = CheckBox()
    .string_("Single Note CC Mode")
    .value_(~layers.state.singleNoteCCMode)
    .action_({ |cb|
        ~setSingleNoteCCMode.(cb.value);
    });
```

## MIDI Knob Mapping

### Row 1 (Global Controls)
- **Knob 1** (CC 19): CC envelope max scalar (0.1-2.0)
- **Knob 7** (CC 25): CC envelope duration scalar (0.1-2.0)

### Existing Mappings (Preserved)
- **Knob 2**: Note duration scalar (manual mode)
- **Knob 3**: Note velocity (manual mode)
- **Knob 8**: Loop duration (manual mode)

## Testing Plan

1. **Basic Functionality**
   - Enable single note CC mode
   - Verify CC envelopes trigger per note
   - Check envelope duration matches note duration

2. **MIDI Control**
   - Test duration scalar affects envelope length
   - Test max scalar affects peak value
   - Verify changes apply in real-time

3. **Mode Switching**
   - Switch between normal and single note modes
   - Ensure smooth transitions
   - Verify no stuck envelopes

4. **Performance**
   - Test with fast note sequences
   - Monitor CPU usage with many envelopes
   - Check for timing accuracy

## Considerations

1. **CPU Usage**: Per-note envelopes create more synths - monitor performance
2. **Envelope Overlap**: Fast notes may create overlapping envelopes
3. **Note Duration**: Very short notes may need minimum envelope duration
4. **Cleanup**: Ensure envelopes complete even if notes are interrupted

## Future Enhancements

1. **Per-Layer Toggle**: Allow single note mode per layer instead of global
2. **Envelope Shapes**: Different shapes for attack vs sustain notes
3. **CC Target**: Allow different CC targets per note type
4. **Velocity Scaling**: Scale envelope based on note velocity