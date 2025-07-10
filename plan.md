# Dependent Layer Playback System Design Plan

## Overview
Design a synchronized multi-layer playback system where multiple layers (each with their own melody sequences) start and stop together, sharing the same duration and timing structure. Unlike the independent dual-layer system, these layers are temporally locked.

## Core Concepts

### 1. ProcMod Architecture Analysis
ProcMod provides:
- **Envelope Control**: ASR envelopes with configurable attack/release times
- **Group Management**: Each ProcMod creates/manages its own synth group
- **Task Execution**: Executes Functions/Tasks/Routines within controlled environment
- **Resource Management**: Automatic cleanup of groups, buses, responders
- **Re-triggerable**: If function returns Task/Routine, can overlap instances
- **Hierarchical Structure**: Groups can be nested (parent/child relationships)

### 2. Design Approach: Parent-Child ProcMod Structure

#### Parent ProcMod (Container)
- Controls overall timing and envelope
- Manages synchronized start/stop/release
- Contains collection of child ProcMods
- Ensures all children have same duration
- Single point of control for all layers

#### Child ProcMods (Layer Players)
- Each represents one layer
- Has own melody sequence
- Shares parent's timing structure
- Executes within parent's group
- Synchronized lifecycle with siblings

## Detailed Design

### Phase 1: Core Architecture

#### 1.1 Layer Container Structure
```supercollider
~layerContainer = (
    parentProc: nil,          // Parent ProcMod instance
    childProcs: Dictionary(), // layerName -> child ProcMod
    layerConfigs: Dictionary(), // layerName -> config
    totalDuration: 0,         // Calculated total duration
    isPlaying: false
);

~layerConfig = (
    melodyList: [],           // List of melody keys
    vstGroup: nil,            // Target VST group
    ccParams: Dictionary(),   // Layer-specific CC parameters
    enabled: true             // Enable/disable layer
);
```

#### 1.2 Duration Calculation System
- Calculate duration for each melody in each layer
- Find maximum duration across all layers
- Apply padding/synchronization as needed
- Handle fermata and rest times consistently

#### 1.3 Parent ProcMod Creation
```supercollider
~createParentProcMod = { |layerConfigs|
    var env = Env.asr(0.01, 1.0, 0.1);
    var parentId = "layerParent_" ++ Date.getDate.stamp;
    
    ProcMod.new(
        env, 1.0, parentId, nil, 0, 1,
        { |parentGroup, envbus|
            // Create and manage child ProcMods here
            // All children run in parentGroup
        },
        { |parentGroup, envbus|
            // Release all children
        },
        { |parentGroup, envbus|
            // Cleanup on release
        }
    );
};
```

### Phase 2: Synchronization Mechanism

#### 2.1 Timing Synchronization
- **Shared Clock**: All layers use parent's clock
- **Unified Wait Times**: Calculate wait times based on longest layer
- **Synchronization Points**: Define points where layers must align
- **Padding Strategy**: Add rests to shorter sequences

#### 2.2 Layer Coordination
```supercollider
~coordinatedLayerTask = { |layerConfigs, parentGroup, envbus|
    Task({
        var tasks = [];
        var maxDuration = ~calculateMaxDuration.(layerConfigs);
        
        // Create synchronized tasks for each layer
        layerConfigs.keysValuesDo { |layerName, config|
            var layerTask = Task({
                // Play layer melodies with synchronized timing
            });
            tasks = tasks.add(layerTask);
        };
        
        // Start all tasks simultaneously
        tasks.do(_.play);
        
        // Wait for completion
        maxDuration.wait;
    });
};
```

### Phase 3: Layer Management

#### 3.1 Layer Definition Structure
```supercollider
~defineLayer = { |layerName, melodyList, vstGroup, ccParams|
    var config = (
        melodyList: melodyList,
        vstGroup: vstGroup,
        ccParams: ccParams ? Dictionary(),
        enabled: true,
        duration: 0  // Calculated later
    );
    ~layerConfigs[layerName] = config;
};
```

#### 3.2 Dynamic Layer Control
- Add/remove layers before playback
- Enable/disable layers
- Update VST targeting per layer
- Modify CC parameters per layer

### Phase 4: Implementation Steps

#### 4.1 Create Base Functions
1. `~createDependentLayerSystem` - Initialize the system
2. `~addDependentLayer` - Add a layer configuration
3. `~calculateLayerDuration` - Calculate duration for single layer
4. `~calculateMaxDuration` - Find maximum across all layers
5. `~createLayerTask` - Create Task for single layer
6. `~synchronizeLayers` - Ensure timing alignment

#### 4.2 Melody Iteration Logic
```supercollider
~iterateLayerMelodies = { |config, parentGroup, maxDuration|
    var currentTime = 0;
    var melodyIndex = 0;
    
    while { currentTime < maxDuration } {
        var melodyKey = config.melodyList.wrapAt(melodyIndex);
        var melodyDuration = ~calculateMelodyDuration.(melodyKey);
        
        // Play melody
        ~playMelodyInLayer.(melodyKey, config.vstGroup);
        
        // Wait for melody completion or padding
        min(melodyDuration, maxDuration - currentTime).wait;
        
        currentTime = currentTime + melodyDuration;
        melodyIndex = melodyIndex + 1;
    };
};
```

#### 4.3 VST Routing per Layer
- Each layer targets its own VST group
- Maintain separate OSC responders per layer
- Route CC envelopes to correct instances
- Handle note-on/off per layer

### Phase 5: Integration Points

#### 5.1 MIDI Control Integration
- Map MIDI controls to layer parameters
- Layer selection via MIDI
- Global vs layer-specific parameters
- Synchronized parameter changes

#### 5.2 GUI Considerations
- Visual representation of layers
- Layer enable/disable toggles
- Duration visualization
- Synchronization status display

### Phase 6: Advanced Features

#### 6.1 Layer Relationships
- **Master/Slave**: One layer drives timing
- **Equal Partners**: All layers weighted equally
- **Hierarchical**: Nested layer groups
- **Sequential**: Layers can hand off to each other

#### 6.2 Synchronization Modes
- **Hard Sync**: Strict alignment at all points
- **Soft Sync**: Align at major boundaries only
- **Free Running**: Layers loop independently
- **Quantized**: Snap to rhythmic grid

#### 6.3 Transition Handling
- Crossfade between layer sets
- Smooth parameter transitions
- Layer morphing capabilities
- Dynamic layer allocation

## Implementation Priority

### Phase 1 (Core - Week 1)
1. Create basic parent-child ProcMod structure
2. Implement duration calculation
3. Test with 2 simple layers

### Phase 2 (Synchronization - Week 2)
1. Implement timing synchronization
2. Add padding/alignment logic
3. Test with complex patterns

### Phase 3 (Integration - Week 3)
1. Integrate with existing VST system
2. Add MIDI control mappings
3. Create usage examples

### Phase 4 (Polish - Week 4)
1. Add GUI components
2. Implement advanced features
3. Optimize performance
4. Write documentation

## Key Design Decisions

### 1. Parent ProcMod Approach
**Pros:**
- Single control point
- Guaranteed synchronization
- Clean resource management
- Hierarchical organization

**Cons:**
- More complex than flat structure
- Potential latency in setup
- Less flexible for dynamic changes

### 2. Duration Matching Strategy
**Options:**
1. **Pad to Longest**: Add silence to shorter layers
2. **Loop Shorter**: Repeat shorter patterns
3. **Stretch Timing**: Adjust note durations
4. **Hybrid**: Combination based on context

**Recommendation:** Start with "Pad to Longest" for simplicity

### 3. Resource Management
- Parent group contains all child groups
- Shared envelope bus for synchronized amplitude
- Individual control buses per layer
- Cleanup cascade from parent to children

## Testing Strategy

### 1. Unit Tests
- Duration calculation accuracy
- Synchronization timing
- Resource cleanup
- State management

### 2. Integration Tests
- VST routing correctness
- MIDI control response
- Multi-layer coordination
- Performance under load

### 3. User Tests
- Musical results
- Timing feel
- Control responsiveness
- System stability

## API Design

### Core Functions
```supercollider
// System initialization
~initDependentLayers.();

// Layer management
~addLayer.(name, melodies, vstGroup, params);
~removeLayer.(name);
~updateLayer.(name, key, value);

// Playback control
~playDependentLayers.();
~stopDependentLayers.();
~releaseDependentLayers.(time);

// State queries
~getDependentLayerState.();
~getLayerDuration.(name);
~getTotalDuration.();
```

## UI Control Design

### Overview
Expand the existing sketch-gui.scd to add controls for exactly 3 dependent layers. The UI will provide simple, essential controls as requested.

### Core Requirements
- Start/stop button controls ALL layers together
- Each of 3 layers has: melody selection, enable/disable switch
- MIDI Row 1 controls timing for all layers (they share timing)
- Simple, essential features only

### GUI Layout

#### 1. Window Extension
Expand the existing sketch-gui.scd window:
```supercollider
// Modify existing window size to accommodate layer controls
win = Window("Sketch Control", Rect(100, 100, 300, 600)); // Increased height
```

#### 2. Transport Section (Modified)
Update existing transport to control all layers:
```supercollider
startButton = Button()
    .states_([["Start All Layers"]])
    .action_({
        if (~startDependentLayers.notNil) {
            ~startDependentLayers.();
            "All layers started".postln;
        } {
            "Dependent layer function not available".postln;
        };
    });

stopButton = Button()
    .states_([["Stop All Layers"]])
    .action_({
        if (~stopDependentLayers.notNil) {
            ~stopDependentLayers.();
            "All layers stopped".postln;
        } {
            "Stop function not available".postln;
        };
    });
```

### Layer Controls (3 Layers)

#### Fixed 3-Layer Implementation
```supercollider
// After modes section, add layer controls
layout.add(StaticText().string_("LAYERS").font_(Font.default.size_(12).bold_(true)));

// Create exactly 3 layers
3.do { |i|
    var layerName = ("layer" ++ (i+1)).asSymbol;
    var enableBox, melodyMenu;
    
    layout.add(StaticText().string_("Layer " ++ (i+1)).font_(Font.default.bold_(true)));
    
    // Enable/disable checkbox
    enableBox = CheckBox()
        .string_("Enabled")
        .value_(true)
        .action_({ |cb|
            ~layerConfigs[layerName].enabled = cb.value;
            ("Layer " ++ (i+1) ++ " enabled: " ++ cb.value).postln;
        });
    layout.add(enableBox);
    
    // Melody selection
    layout.add(HLayout(
        StaticText().string_("Melody:"),
        melodyMenu = PopUpMenu()
            .items_(~melodyData.collect { |m| m.key.asString })
            .action_({ |menu|
                var selectedKey = ~melodyData[menu.value].key;
                ~layerConfigs[layerName].melodyList = [selectedKey];
                ("Layer " ++ (i+1) ++ " melody: " ++ selectedKey).postln;
            })
    ));
    
    // Simple status indicator
    layout.add(
        UserView()
            .drawFunc_({ |view|
                var enabled = ~layerConfigs[layerName].enabled;
                Pen.fillColor = if(enabled, Color.green, Color.gray);
                Pen.fillRect(view.bounds);
            })
            .fixedHeight_(3)
    );
    
    layout.add(10); // spacing between layers
};
```

### MIDI Timing Display

```supercollider
// Add MIDI timing info section
layout.add(StaticText().string_("MIDI TIMING").font_(Font.default.size_(12).bold_(true)));
layout.add(StaticText().string_("Row 1 controls timing for all layers:").font_(Font.default.size_(10)));
layout.add(StaticText().string_("• Knob 1: Attack time").font_(Font.default.size_(9)));
layout.add(StaticText().string_("• Knobs 2-8: Duration params").font_(Font.default.size_(9)));
```

### Integration with Existing GUI

```supercollider
// Modify the existing ~createSketchGUI function
~createSketchGUI = {
    var win, layout, startButton, stopButton;
    var layer1Enable, layer1Melody, layer2Enable, layer2Melody, layer3Enable, layer3Melody;
    
    // Create window
    win = Window("Sketch Control", Rect(100, 100, 300, 700));
    layout = VLayout();
    
    // Transport buttons
    layout.add(StaticText().string_("TRANSPORT").font_(Font.default.size_(14).bold_(true)));
    
    // Modified start/stop for dependent layers
    startButton = Button()
        .states_([["Start All Layers"]])
        .action_({
            if (~startDependentLayers.notNil) {
                ~startDependentLayers.();
            } {
                // Fallback to original
                if (~startContinuousLoopSequence.notNil) {
                    ~startContinuousLoopSequence.();
                };
            };
        });
    layout.add(startButton);
    
    stopButton = Button()
        .states_([["Stop All Layers"]])
        .action_({
            if (~stopDependentLayers.notNil) {
                ~stopDependentLayers.();
            } {
                // Fallback to original
                if (~stopContinuousLoopSequence.notNil) {
                    ~stopContinuousLoopSequence.();
                };
            };
        });
    layout.add(stopButton);
    
    // Existing modes section
    layout.add(StaticText().string_("MODES").font_(Font.default.size_(12).bold_(true)));
    if (~modes.notNil) {
        ~modes.keysValuesDo { |key, value|
            var checkbox = CheckBox()
                .string_(key.asString)
                .value_(value)
                .action_({ |cb|
                    ~modes[key] = cb.value;
                });
            layout.add(checkbox);
        };
    };
    
    // Layer controls section
    layout.add(20); // spacing
    layout.add(StaticText().string_("LAYER CONTROLS").font_(Font.default.size_(12).bold_(true)));
    
    // Exactly 3 layers
    3.do { |i|
        var layerName = ("layer" ++ (i+1)).asSymbol;
        
        layout.add(StaticText().string_("Layer " ++ (i+1)).font_(Font.default.bold_(true)));
        
        // Enable checkbox
        layout.add(
            CheckBox()
                .string_("Enabled")
                .value_(true)
                .action_({ |cb|
                    if (~layerConfigs.notNil) {
                        ~layerConfigs[layerName].enabled = cb.value;
                    };
                })
        );
        
        // Melody dropdown
        if (~melodyData.notNil) {
            layout.add(HLayout(
                StaticText().string_("Melody:"),
                PopUpMenu()
                    .items_(~melodyData.collect { |m| m.key.asString })
                    .action_({ |menu|
                        if (~layerConfigs.notNil) {
                            var selectedKey = ~melodyData[menu.value].key;
                            ~layerConfigs[layerName].melodyList = [selectedKey];
                        };
                    })
            ));
        };
        
        layout.add(10); // spacing
    };
    
    // MIDI info
    layout.add(20);
    layout.add(StaticText().string_("MIDI: Row 1 controls all layer timing").font_(Font.default.size_(10).italic_(true)));
    
    // Set layout and show
    win.layout = layout;
    win.onClose = { ~sketchGUIWindow = nil; };
    win.front;
    
    ~sketchGUIWindow = win;
};
```

## Next Steps

1. **Prototype**: Build minimal version with 2 layers
2. **Validate**: Test synchronization accuracy
3. **Refine**: Adjust based on musical results
4. **Expand**: Add features incrementally
5. **Document**: Create usage examples and guides

## Considerations

### Performance
- Pre-calculate all durations
- Minimize real-time calculations
- Efficient task scheduling
- Resource pooling where possible

### Flexibility
- Easy layer addition/removal
- Dynamic parameter updates
- Multiple synchronization modes
- Extensible architecture

### Reliability
- Robust error handling
- State consistency checks
- Graceful degradation
- Clear failure modes

This design provides a solid foundation for implementing a sophisticated dependent layer system that maintains the flexibility of ProcMod while ensuring tight synchronization across multiple musical layers.