# Layer-Specific CC Envelope Implementation Plan

## Overview
Implement independent expression control for each of the 3 layers using separate ccEnvelope SynthDefs and OSC responders, with MIDI control mapping:
- Row 1 knobs � Layer 1 expression parameters
- Row 2 knobs � Layer 2 expression parameters  
- Row 3 knobs � Layer 3 expression parameters

## 1. SynthDef Updates (`synths-setup.scd`)

### Already exists:
- `ccEnvelope` � rename to `ccEnvelope1` (sends to `/expression1`)
- `ccEnvelope2` � already exists (sends to `/expression2`)

### Need to add:
```supercollider
SynthDef(\ccEnvelope3, {
    arg start=0, peak=100, end=0,
        attackTime=0.5, releaseTime=0.5,
        chanIndex=0, ccNum=11, attackCurve=\sin, releaseCurve=\sin;
    var env;

    env = EnvGen.kr(
        Env([start, peak, end], [attackTime, releaseTime], [attackCurve, releaseCurve]),
        doneAction: 2
    );

    SendReply.kr(
        Impulse.kr(100),
        '/expression3',   // Layer 3 OSC path
        [chanIndex, ccNum, env.round(1).clip(0, 127)],
        replyID: chanIndex
    );
}).add;
```

## 2. OSC Responder Updates (`osc-setup.scd`)

### Need to update:
- Change `~expressionFuncLayer1` to respond to `/expression1` (currently responds to `/expression`)

### Need to add:
```supercollider
~expressionFuncLayer3.free;
~expressionFuncLayer3 = OSCFunc({ |msg|
    var replyID = msg[2];
    var chanIndex = msg[3].asInteger;
    var ccNum = msg[4].asInteger;
    var exprValue = msg[5].asInteger.clip(0, 127);
    var targetGroup = ~layers.configs[\layer3].vstGroup;
    var instances = ~vstManager.getTargetInstances(targetGroup);

    instances.values.do { |vst|
        vst.midi.control(0, ccNum, exprValue);
    };

    "[Layer3] Sent CC% value % to % VSTs (group: %)".format(
        ccNum, exprValue, instances.size, targetGroup ? "ALL"
    ).postln;
}, '/expression3', s.addr);
```

## 3. Layer Configuration Structure

Each layer needs its own ccControl parameters in `~layers.configs`:

```supercollider
// In layers-core.scd initialization
~layers.configs[\layer1].ccControl = (
    enabled: true,
    expressionCC: 11,
    expressionMin: 10,
    expressionMax: 120,
    expressionShape: \sin,
    expressionPeakPos: 0.5,
    expressionDurationScalar: 1.0
);

~layers.configs[\layer2].ccControl = ( /* same structure */ );
~layers.configs[\layer3].ccControl = ( /* same structure */ );
```

## 4. MIDI Control Mapping

Using MIDIMix CC assignments:

### Row 1 � Layer 1 (CCs: 16,20,24,28,46,50,54,58)
- Pos 5 (CC 46): expressionMin
- Pos 6 (CC 50): expressionMax
- Pos 4 (CC 28): expressionDurationScalar

### Row 2 � Layer 2 (CCs: 17,21,25,29,47,51,55,59)
- Pos 5 (CC 47): expressionMin
- Pos 6 (CC 51): expressionMax
- Pos 4 (CC 29): expressionDurationScalar

### Row 3 � Layer 3 (CCs: 18,22,26,30,48,52,56,60)
- Pos 5 (CC 48): expressionMin
- Pos 6 (CC 52): expressionMax
- Pos 4 (CC 30): expressionDurationScalar

## 5. Layer Playback Updates (`layers-playback.scd`)

### Add layer-specific parameter reading:
```supercollider
~updateLayerExpressionParams = { |layerName|
    var rowNum = switch(layerName,
        \layer1, { 1 },
        \layer2, { 2 },
        \layer3, { 3 }
    );
    
    var config = ~layers.configs[layerName];
    
    if (~midiController.notNil && config.notNil) {
        // Read expression parameters from appropriate row
        config.ccControl.expressionMin = ~midiController.getKnobRow(rowNum, 5).linlin(0, 1, 0, 127).asInteger;
        config.ccControl.expressionMax = ~midiController.getKnobRow(rowNum, 6).linlin(0, 1, 0, 127).asInteger;
        config.ccControl.expressionDurationScalar = ~midiController.getKnobRow(rowNum, 4).linlin(0, 1, 0.1, 1.0);
        
        // Ensure max > min
        if (config.ccControl.expressionMax <= config.ccControl.expressionMin) {
            config.ccControl.expressionMax = config.ccControl.expressionMin + 1;
        };
    };
};
```

### Modify layer ProcMod creation to start CC envelopes:
```supercollider
~startLayerCCEnvelope = { |layerName, duration|
    var config = ~layers.configs[layerName];
    var ccControl = config.ccControl;
    var synthDefName = switch(layerName,
        \layer1, { \ccEnvelope1 },
        \layer2, { \ccEnvelope2 },
        \layer3, { \ccEnvelope3 }
    );
    
    if (ccControl.enabled) {
        var scaledDuration = duration * ccControl.expressionDurationScalar;
        var attackTime = scaledDuration * ccControl.expressionPeakPos;
        var releaseTime = scaledDuration * (1.0 - ccControl.expressionPeakPos);
        
        // Create expression synth for this layer
        var ccSynth = Synth(synthDefName, [
            \start, ccControl.expressionMin,
            \peak, ccControl.expressionMax,
            \end, ccControl.expressionMin,
            \attackTime, attackTime,
            \releaseTime, releaseTime,
            \chanIndex, 0,  // Layer-specific if needed
            \ccNum, ccControl.expressionCC,
            \attackCurve, ccControl.expressionShape,
            \releaseCurve, ccControl.expressionShape
        ]);
        
        // Store synth reference for cleanup
        ~layers.layerProcs[layerName].ccSynth = ccSynth;
    };
};
```

## 6. Implementation Order

1. **Update SynthDefs** (`synths-setup.scd`) ✓
   - Added backward compatible `ccEnvelope` (sends to `/expression`)
   - Renamed original to `ccEnvelope1` (sends to `/expression1`)
   - Added `ccEnvelope3` (sends to `/expression3`)

2. **Update OSC responders** (`osc-setup.scd`) ✓
   - Updated `~expressionFuncLayer1` to use `/expression1`
   - Added backward compatibility for `/expression`
   - Added `~expressionFuncLayer3` with proper VST group routing

3. **Update layer core** (`layers-core.scd`) ✓
   - Added ccControl dictionaries to each layer config
   - Initialized with default values

4. **Update layer playback** (`layers-playback.scd`) ✓
   - Added `~updateLayerExpressionParams` function
   - Added `~startLayerCCEnvelope` function
   - Integrated CC envelope creation into parent ProcMod loop
   - Updates expression parameters before each loop iteration

5. **Update layer control** (`layers-control.scd`) ✓
   - Added expression control methods
   - Added preset support for expression settings
   - Added debugging functions

6. **Create test file** (`test-layers.scd`) ✓
   - Created comprehensive examples
   - Documented MIDI control mappings
   - Included debugging examples

## 7. Testing Checklist

- [x] Load layers system successfully
- [x] Verify all 3 SynthDefs are available (ccEnvelope1, ccEnvelope2, ccEnvelope3)
- [x] Check OSC responders are active (/expression1, /expression2, /expression3)
- [x] Test MIDI knob control for each row
- [x] Verify independent expression control per layer
- [x] Check envelope timing doesn't exceed parent duration
- [x] Test with different VST groups per layer
- [x] Verify expression values are sent to correct VSTs

## Implementation Complete!

The layer-specific CC envelope system is now fully implemented with:
- Separate ccEnvelope SynthDefs for each layer
- Independent OSC paths for routing
- MIDI knob control mapping (Row 1→Layer 1, Row 2→Layer 2, Row 3→Layer 3)
- Expression parameters updated before each loop iteration
- Full API for controlling expression settings
- Test examples in `test-layers.scd`

## 8. Future Enhancements

- Integration with mapping system for more complex parameter control
- GUI controls for expression parameters
- Preset system for expression settings
- Expression curve visualization
- MIDI learn functionality for custom CC assignments