# Live Melody Updates During Playback - Implementation Plan

## Problem Statement

The current live melody system successfully receives and queues OSC updates, but these updates only take effect when layers are stopped and restarted. This is unacceptable for live performance where melody changes must happen seamlessly during continuous playback.

**Root Cause**: Child ProcMods are created once with static melody data and continue looping with that fixed data. They don't check for melody updates during their loop iterations.

## Architecture Solution: Dynamic Melody Reference System

Replace static melody passing with dynamic melody getter functions that child ProcMods call at the start of each loop iteration.

### Core Concept

Instead of:
```supercollider
// CURRENT: Static melody data passed once
childProc.playFunc = { |playingNode|
    var melodyData = staticMelodyData;  // Fixed at creation time
    // ... use melodyData forever
};
```

Implement:
```supercollider
// NEW: Dynamic melody getter called each loop
childProc.playFunc = { |playingNode|
    Task({
        while { ~layers.state.loopingMode } {
            var melodyData = ~getLayerMelodyDynamic.(layerName);  // Fresh each loop
            // ... use current melodyData for this iteration
            ~layers.timingData.totalDuration.wait;
        };
    }).play;
};
```

## Implementation Steps

### Step 1: Create Dynamic Melody Getter Functions
**File**: `layers-live-melody.scd` (add to existing file)

```supercollider
~getLayerMelodyDynamic = { |layerName|
    var config = ~layers.configs[layerName];
    var melodyKey, melodyData;
    
    // Check for pending live updates first
    if (~layers.state.liveMelodyMode and: { 
        ~layers.state.pendingUpdates[layerName].notNil 
    }) {
        // Apply pending update immediately
        ~applyPendingUpdateForLayer.(layerName);
    };
    
    // Return current melody data
    if (config.melodyList.notNil and: { config.melodyList.size > 0 }) {
        melodyKey = config.melodyList[0];
        melodyData = ~melodyDict[melodyKey];
    };
    
    melodyData
};

~applyPendingUpdateForLayer = { |layerName|
    var melodyData = ~layers.state.pendingUpdates[layerName];
    var tempKey = ("live_" ++ layerName).asSymbol;
    var config = ~layers.configs[layerName];
    
    if (melodyData.notNil) {
        // Convert and store
        ~melodyDict[tempKey] = ~convertLiveMelodyData.(melodyData);
        config.melodyList = [tempKey];
        
        // Apply expression overrides if present
        if (melodyData.expressionOverride.notNil) {
            var override = melodyData.expressionOverride;
            var ccControl = config.ccControl;
            
            if (override.expressionMin.notNil) {
                ccControl.expressionMin = override.expressionMin;
            };
            if (override.expressionMax.notNil) {
                ccControl.expressionMax = override.expressionMax;
            };
            if (override.expressionDurationScalar.notNil) {
                ccControl.expressionDurationScalar = override.expressionDurationScalar;
            };
        };
        
        // Clear pending update
        ~layers.state.pendingUpdates[layerName] = nil;
        
        "LIVE UPDATE APPLIED: % during playback".format(layerName).postln;
    };
};
```

### Step 2: Modify Child ProcMod Creation
**File**: `layers-playback.scd` (modify existing function)

Replace the static melody approach in `~createLayerProcMod` with dynamic melody fetching:

```supercollider
~createLayerProcMod = { |layerName, config|
    var layerProc;
    
    layerProc = ProcMod.new;
    layerProc.playFunc = { |playingNode|
        var currentIteration = 0;
        
        Task({
            while { ~layers.state.loopingMode } {
                var melodyData, patterns, timing, velocities, noteDurations;
                var noteCount, noteInterval, noteIndex = 0;
                var totalDuration, expressionSynth;
                
                // GET DYNAMIC MELODY DATA - FRESH EACH LOOP ⭐
                melodyData = ~getLayerMelodyDynamic.(layerName);
                
                if (melodyData.notNil) {
                    patterns = melodyData.patterns[currentIteration % melodyData.patterns.size];
                    velocities = melodyData.velocities;
                    timing = ~layers.timingData[layerName] ? melodyData.timing;
                    noteDurations = melodyData.noteDurations;
                    totalDuration = ~layers.timingData.totalDuration;
                    
                    noteCount = patterns.size;
                    
                    // Start expression envelope if enabled
                    if (config.ccControl.enabled) {
                        expressionSynth = ~startLayerExpressionEnvelope.(layerName, totalDuration);
                    };
                    
                    // Play notes using existing timing logic
                    if (timing.notNil) {
                        // Custom timing
                        timing.do { |timeFraction, i|
                            if (i < noteCount) {
                                var waitTime = timeFraction * totalDuration;
                                waitTime.wait;
                                ~playLayerNote.(
                                    layerName,
                                    patterns[i],
                                    velocities[i] ? 127,
                                    noteDurations[i] ? 0.5
                                );
                            } else {
                                (timeFraction * totalDuration).wait;
                            };
                        };
                    } {
                        // Equal timing
                        noteInterval = totalDuration / noteCount;
                        patterns.do { |note, i|
                            ~playLayerNote.(
                                layerName,
                                note,
                                velocities[i] ? 127,
                                noteDurations[i] ? 0.5
                            );
                            noteInterval.wait;
                        };
                    };
                    
                    // Clean up expression synth
                    if (expressionSynth.notNil) {
                        expressionSynth.release;
                    };
                } {
                    // No melody data, just wait
                    (~layers.timingData.totalDuration ? 1.0).wait;
                };
                
                currentIteration = currentIteration + 1;
            };
        }).play;
    };
    
    layerProc
};
```

### Step 3: Remove Bulk Update Processing
**File**: `layers-playback.scd` (modify existing function)

Remove the bulk update check from parent ProcMod since individual layers now handle their own updates:

```supercollider
~createLayersParentProc = { |duration|
    var parentProc;
    
    parentProc = ProcMod.new;
    parentProc.playFunc = { |playingNode|
        var sustainNode = playingNode.sustainNode;
        
        Task({
            while { ~layers.state.loopingMode } {
                // REMOVED: Bulk update processing - individual layers handle updates now
                
                "Loop iteration starting (duration: %s)".format(duration.round(0.1)).postln;
                duration.wait;
            };
            
            sustainNode.release;
        }).play;
    };
    
    parentProc
};
```

### Step 4: Update Live Melody Functions
**File**: `layers-live-melody.scd` (modify existing function)

Simplify `~applyPendingMelodyUpdates` since individual updates are now handled per-layer:

```supercollider
~applyPendingMelodyUpdates = {
    "INFO: Bulk update function called, but individual layers now handle updates automatically".postln;
    "Pending updates: %".format(~layers.state.pendingUpdates.keys).postln;
    
    // This function is now mainly for debugging/status
    ^nil;
};
```

## Testing Plan

### Test 1: Basic Live Update
1. Start layers playing with different melodies
2. Send OSC update to layer1: `~testRawJSON.()`
3. Verify layer1 changes melody on next loop iteration
4. Verify layer2 and layer3 continue with original melodies

### Test 2: Multiple Layer Updates
1. Start all layers playing
2. Send updates to layer1, then layer2, then layer3
3. Verify each layer updates independently
4. Verify timing remains synchronized

### Test 3: Rapid Updates
1. Start layers playing
2. Send multiple updates to same layer rapidly
3. Verify only latest update is applied
4. Verify no audio glitches or timing issues

### Test 4: Expression Override Updates
1. Start layers with expression enabled
2. Send update with expressionOverride data
3. Verify CC envelope parameters update dynamically

## Benefits

✅ **True Live Updates**: Updates apply during playback without stopping
✅ **Seamless Transitions**: Changes happen at loop boundaries  
✅ **No Audio Glitches**: No child ProcMod recreation needed
✅ **Individual Layer Control**: Each layer updates independently
✅ **Backward Compatible**: Existing melody system unchanged
✅ **Performance Friendly**: Minimal overhead, only check when needed

## Files to Modify

1. **layers-live-melody.scd**: Add dynamic getter functions
2. **layers-playback.scd**: Modify child ProcMod creation and parent loop
3. **test-live-melody.scd**: Update tests for new behavior

## Success Criteria

- OSC melody updates apply during continuous playback
- No stopping/starting required for updates
- Each layer updates independently
- Timing synchronization maintained
- Expression overrides work dynamically
- No audio artifacts during updates