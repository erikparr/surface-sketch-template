# Dependent Layer Playback System - Implementation Plan

## Executive Summary

This document outlines the implementation plan for a synchronized multi-layer playback system in the Surfacing project. The system will allow exactly 3 layers to play simultaneously with shared timing, each targeting different VST groups while maintaining perfect synchronization through a parent-child ProcMod architecture.

## System Architecture Overview

### Core Design Pattern: Parent-Child ProcMod Structure

```
Parent ProcMod (Container)
├── Timing Control (shared across all layers)
├── Envelope Management (ASR)
├── Resource Management
└── Child ProcMods (3 Layers)
    ├── Layer 1: Independent melody, VST targeting
    ├── Layer 2: Independent melody, VST targeting
    └── Layer 3: Independent melody, VST targeting
```

### Key Architectural Decisions

1. **Parent ProcMod Approach**: Single control point ensures perfect synchronization
2. **Fixed 3-Layer System**: Simplifies implementation and UI design
3. **Shared Timing**: All layers use MIDI Row 1 for timing parameters
4. **Duration Strategy**: Pad shorter layers to match longest duration

## Implementation Phases

### Phase 1: Core Infrastructure (Days 1-3)

#### 1.1 Data Structures
Create fundamental data structures for the dependent layer system:

```supercollider
// File: sketch/dependent-layers-core.scd

// Layer configuration structure
~dependentLayers = (
    parentProc: nil,              // Parent ProcMod instance
    childProcs: Dictionary(),     // layerName -> child ProcMod
    configs: Dictionary(),        // layerName -> configuration
    state: (
        isPlaying: false,
        totalDuration: 0,
        currentCycle: 0
    )
);

// Individual layer configuration
~createLayerConfig = { |melodyList, vstGroup|
    (
        melodyList: melodyList,
        vstGroup: vstGroup,
        enabled: true,
        currentMelodyIndex: 0,
        duration: 0
    )
};

// Initialize 3 layers
~initializeDependentLayers = {
    3.do { |i|
        var layerName = ("layer" ++ (i+1)).asSymbol;
        ~dependentLayers.configs[layerName] = ~createLayerConfig.([], nil);
    };
};
```

#### 1.2 Duration Calculation System
Implement duration calculation for synchronization:

```supercollider
// Calculate duration for a single melody
~calculateMelodyDuration = { |melodyKey|
    var pattern = ~melodyDict[melodyKey].patterns[0];
    var noteCount = pattern.size;
    var noteDuration = ~ccControl.noteDuration;
    var noteRestTime = ~ccControl.noteRestTime;
    var melodyRestTime = ~melodyRestTime ? 0.5;
    
    // Total time = (notes * (duration + rest)) + melody rest
    (noteCount * (noteDuration + noteRestTime)) + melodyRestTime
};

// Calculate total duration for a layer
~calculateLayerDuration = { |config|
    var totalDuration = 0;
    config.melodyList.do { |melodyKey|
        totalDuration = totalDuration + ~calculateMelodyDuration.(melodyKey);
    };
    totalDuration
};

// Find maximum duration across all enabled layers
~calculateMaxDuration = {
    var maxDuration = 0;
    ~dependentLayers.configs.keysValuesDo { |layerName, config|
        if (config.enabled) {
            var layerDuration = ~calculateLayerDuration.(config);
            maxDuration = max(maxDuration, layerDuration);
        };
    };
    maxDuration
};
```

#### 1.3 Parent ProcMod Creation
Implement the parent ProcMod that manages all layers:

```supercollider
~createParentProcMod = {
    var env = Env.asr(0.01, 1.0, 0.1, \lin);
    var parentId = ("dependentParent_" ++ Date.getDate.stamp).asSymbol;
    
    ProcMod.new(
        env, 1.0, parentId, nil, 0, 1,
        // Main function - executes when parent plays
        { |parentGroup, envbus|
            var maxDuration = ~calculateMaxDuration.();
            var layerTasks = [];
            
            "Starting dependent layers with duration: %".format(maxDuration).postln;
            
            // Create synchronized tasks for each layer
            ~dependentLayers.configs.keysValuesDo { |layerName, config|
                if (config.enabled and: (config.melodyList.size > 0)) {
                    var layerTask = ~createLayerTask.(
                        layerName, config, parentGroup, maxDuration
                    );
                    layerTasks = layerTasks.add(layerTask);
                };
            };
            
            // Start all layer tasks simultaneously
            Task({
                layerTasks.do(_.play);
                maxDuration.wait;
                "All layers completed".postln;
            });
        }
    );
};
```

### Phase 2: Layer Task Implementation (Days 4-6)

#### 2.1 Layer Task Creation
Implement individual layer task logic:

```supercollider
~createLayerTask = { |layerName, config, parentGroup, maxDuration|
    Task({
        var currentTime = 0;
        var melodyIndex = 0;
        
        // Set VST targeting for this layer
        var previousVSTGroup = ~activeVSTGroup;
        ~setActiveVSTGroup.(config.vstGroup);
        
        while { currentTime < maxDuration } {
            var melodyKey = config.melodyList.wrapAt(melodyIndex);
            var melodyDuration = ~calculateMelodyDuration.(melodyKey);
            var remainingTime = maxDuration - currentTime;
            var playDuration = min(melodyDuration, remainingTime);
            
            // Play melody with layer-specific targeting
            "Layer % playing melody: %".format(layerName, melodyKey).postln;
            ~playLayerMelody.(melodyKey, layerName, playDuration);
            
            // Wait for melody completion or remaining time
            playDuration.wait;
            
            currentTime = currentTime + playDuration;
            melodyIndex = melodyIndex + 1;
        };
        
        // Restore previous VST targeting
        ~setActiveVSTGroup.(previousVSTGroup);
        "Layer % completed".format(layerName).postln;
    });
};
```

#### 2.2 Melody Playback for Layers
Adapt existing melody playback for layer system:

```supercollider
~playLayerMelody = { |melodyKey, layerName, duration|
    var pattern = ~melodyDict[melodyKey].patterns[0];
    var noteIndex = 0;
    var startTime = Main.elapsedTime;
    
    Task({
        while { 
            (noteIndex < pattern.size) and: 
            ((Main.elapsedTime - startTime) < duration) 
        } {
            var note = pattern[noteIndex];
            var processedNote = ~processNote.(note, 
                noteIndex == 0, 
                noteIndex == (pattern.size - 1),
                melodyKey
            );
            
            // Send note with layer identifier
            NetAddr.localAddr.sendMsg(
                '/layer/note/on',
                layerName,
                processedNote[0],  // note
                processedNote[1],  // velocity
                ~ccControl.noteDuration
            );
            
            (~ccControl.noteDuration + ~ccControl.noteRestTime).wait;
            noteIndex = noteIndex + 1;
        };
    }).play;
};
```

#### 2.3 OSC Responders for Layers
Create layer-aware OSC responders:

```supercollider
// Layer-specific note handler
OSCdef(\layerNoteOn, { |msg, time, addr, recvPort|
    var layerName = msg[1].asSymbol;
    var note = msg[2].asInteger;
    var velocity = msg[3].asInteger;
    var duration = msg[4].asFloat;
    
    var config = ~dependentLayers.configs[layerName];
    if (config.notNil and: { config.vstGroup.notNil }) {
        ~vstManager.getTargetInstances(config.vstGroup).do { |vst|
            vst.midi.noteOn(0, note, velocity);
            if(duration.notNil) {
                SystemClock.sched(duration, {
                    vst.midi.noteOff(0, note, 0);
                });
            };
        };
    };
}, '/layer/note/on');
```

### Phase 3: Control Interface (Days 7-9)

#### 3.1 API Functions
Create clean API for controlling the system:

```supercollider
// Start all layers
~startDependentLayers = {
    if (~dependentLayers.state.isPlaying.not) {
        ~dependentLayers.parentProc = ~createParentProcMod.();
        ~dependentLayers.parentProc.play;
        ~dependentLayers.state.isPlaying = true;
        "Dependent layers started".postln;
    } {
        "Layers already playing".warn;
    };
};

// Stop all layers
~stopDependentLayers = {
    if (~dependentLayers.state.isPlaying) {
        ~dependentLayers.parentProc.release;
        ~dependentLayers.state.isPlaying = false;
        "Dependent layers stopped".postln;
    };
};

// Configure a layer
~configureLayer = { |layerName, melodyList, vstGroup|
    var config = ~dependentLayers.configs[layerName];
    if (config.notNil) {
        config.melodyList = melodyList;
        config.vstGroup = vstGroup;
        config.duration = ~calculateLayerDuration.(config);
        "Layer % configured".format(layerName).postln;
    } {
        "Invalid layer name: %".format(layerName).warn;
    };
};

// Enable/disable layer
~setLayerEnabled = { |layerName, enabled|
    var config = ~dependentLayers.configs[layerName];
    if (config.notNil) {
        config.enabled = enabled;
        "Layer % enabled: %".format(layerName, enabled).postln;
    };
};
```

#### 3.2 GUI Integration
Modify sketch-gui.scd to add layer controls:

```supercollider
// In sketch-gui.scd, after existing controls
~addDependentLayerControls = { |layout|
    // Section header
    layout.add(20);
    layout.add(StaticText()
        .string_("DEPENDENT LAYERS")
        .font_(Font.default.size_(12).bold_(true))
    );
    
    // Transport controls
    layout.add(HLayout(
        Button()
            .states_([["Start Layers", Color.black, Color.green]])
            .action_({ ~startDependentLayers.() }),
        Button()
            .states_([["Stop Layers", Color.black, Color.red]])
            .action_({ ~stopDependentLayers.() })
    ));
    
    // Layer controls (exactly 3)
    3.do { |i|
        var layerName = ("layer" ++ (i+1)).asSymbol;
        var enableCheck, melodyMenu, vstGroupMenu;
        
        layout.add(10);
        layout.add(StaticText()
            .string_("Layer " ++ (i+1))
            .font_(Font.default.bold_(true))
        );
        
        // Enable checkbox
        enableCheck = CheckBox()
            .string_("Enabled")
            .value_(true)
            .action_({ |cb|
                ~setLayerEnabled.(layerName, cb.value);
            });
        layout.add(enableCheck);
        
        // Melody selection
        melodyMenu = PopUpMenu()
            .items_(["None"] ++ ~melodyData.collect(_.key.asString))
            .action_({ |menu|
                if (menu.value > 0) {
                    var melodyKey = ~melodyData[menu.value - 1].key;
                    var config = ~dependentLayers.configs[layerName];
                    config.melodyList = [melodyKey];
                };
            });
        
        // VST group selection
        vstGroupMenu = PopUpMenu()
            .items_(["None"] ++ ~vstManager.groups.keys.asArray)
            .action_({ |menu|
                if (menu.value > 0) {
                    var groupName = ~vstManager.groups.keys.asArray[menu.value - 1];
                    var config = ~dependentLayers.configs[layerName];
                    config.vstGroup = groupName;
                };
            });
        
        layout.add(HLayout(
            StaticText().string_("Melody:"), melodyMenu
        ));
        layout.add(HLayout(
            StaticText().string_("VST Group:"), vstGroupMenu
        ));
    };
    
    // Timing info
    layout.add(10);
    layout.add(StaticText()
        .string_("MIDI Row 1 controls timing for all layers")
        .font_(Font.default.size_(10).italic_(true))
    );
};
```

### Phase 4: Testing and Refinement (Days 10-12)

#### 4.1 Test Cases

1. **Synchronization Test**
   - Create 3 layers with different length melodies
   - Verify all start and stop together
   - Check padding behavior for shorter layers

2. **VST Routing Test**
   - Assign different VST groups to each layer
   - Verify correct routing during playback
   - Test group switching between cycles

3. **Parameter Control Test**
   - Modify timing parameters during playback
   - Verify all layers respond to shared timing
   - Test enable/disable during playback

4. **Edge Cases**
   - Empty melody lists
   - Disabled layers
   - Very short/long melodies
   - Rapid start/stop cycles

#### 4.2 Performance Optimization

```supercollider
// Pre-calculate durations when melodies change
~updateLayerDurations = {
    ~dependentLayers.configs.keysValuesDo { |layerName, config|
        config.duration = ~calculateLayerDuration.(config);
    };
    ~dependentLayers.state.totalDuration = ~calculateMaxDuration.();
};

// Cache frequently accessed values
~dependentLayers.cache = (
    vstInstances: Dictionary(),
    melodyPatterns: Dictionary()
);
```

### Phase 5: Documentation and Examples (Days 13-14)

#### 5.1 Usage Examples

```supercollider
// Example 1: Basic 3-layer setup
~configureLayer.(\layer1, [\melody1, \melody2], \BassTuba);
~configureLayer.(\layer2, [\melody3], \Strings);
~configureLayer.(\layer3, [\melody4, \melody5], \Brass);
~startDependentLayers.();

// Example 2: Dynamic layer control
~setLayerEnabled.(\layer2, false);  // Disable layer 2
~configureLayer.(\layer1, [\newMelody], \BassTuba);  // Change melody
~stopDependentLayers.();
~startDependentLayers.();  // Restart with new config

// Example 3: Integration with existing system
~modes.fermata = true;  // Affects all layers
~ccControl.noteDuration = 0.3;  // Shared timing
```

#### 5.2 API Reference

| Function | Parameters | Description |
|----------|------------|-------------|
| `~initializeDependentLayers` | None | Initialize the 3-layer system |
| `~configureLayer` | layerName, melodyList, vstGroup | Configure a specific layer |
| `~setLayerEnabled` | layerName, enabled | Enable/disable a layer |
| `~startDependentLayers` | None | Start all enabled layers |
| `~stopDependentLayers` | None | Stop all layers |
| `~calculateMaxDuration` | None | Get total duration of longest layer |

## File Structure

```
sketch/
├── load-sketch.scd (modified to load dependent layers)
├── dependent-layers-core.scd (new - core implementation)
├── dependent-layers-tasks.scd (new - task logic)
├── dependent-layers-api.scd (new - API functions)
└── sketch-gui.scd (modified to add layer controls)
```

## Integration Points

### 1. With Existing ProcMod System
- Parent ProcMod integrates seamlessly with existing infrastructure
- Reuses envelope control and resource management
- Compatible with existing release/kill mechanisms

### 2. With VST Management
- Each layer can target different VST groups
- Maintains compatibility with existing VST routing
- Supports dynamic group assignment

### 3. With MIDI Control
- Shared timing parameters from Row 1
- Individual layer control possible through mapping
- Compatible with existing parameter routing system

### 4. With Existing Modes
- Fermata, offset, and other modes affect all layers
- Melody rest mode applies globally
- Manual looping controls all layers together

## Risk Mitigation

### Technical Risks
1. **Timing Drift**: Use single parent clock for all layers
2. **Resource Conflicts**: Careful VST group management
3. **Performance Issues**: Pre-calculate durations, efficient task scheduling

### Musical Risks
1. **Phase Issues**: Ensure precise synchronization points
2. **Transition Artifacts**: Implement smooth parameter changes
3. **Complexity**: Keep UI simple and intuitive

## Success Criteria

1. **Perfect Synchronization**: All layers start/stop together
2. **Independent Control**: Each layer has own melody and VST targeting
3. **Shared Timing**: Single timing control affects all layers
4. **Simple UI**: Easy to understand and use
5. **Stable Performance**: No timing drift or resource issues
6. **Seamless Integration**: Works with existing Surfacing features

## Timeline Summary

- **Days 1-3**: Core infrastructure (data structures, duration calc, parent ProcMod)
- **Days 4-6**: Layer implementation (tasks, playback, OSC)
- **Days 7-9**: Control interface (API, GUI integration)
- **Days 10-12**: Testing and optimization
- **Days 13-14**: Documentation and examples

Total estimated time: 2 weeks for complete implementation

## Next Steps

1. Create `dependent-layers-core.scd` with basic structures
2. Implement duration calculation system
3. Build minimal 2-layer prototype for validation
4. Expand to full 3-layer system
5. Integrate with existing GUI
6. Comprehensive testing
7. Documentation and examples