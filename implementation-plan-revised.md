# Dependent Layer System - Revised Implementation Plan

## Architecture Decision: Separate Directory Structure

Based on analysis, we'll create a **new `layers/` directory** rather than modifying the existing sketch system. This provides:
- Clean separation of concerns
- No risk to existing functionality  
- Easier debugging and testing
- Optional loading

## Directory Structure

```
surfacing/
├── setup/           (existing)
├── sketch/          (existing single-layer system)
├── layers/          (NEW dependent layer system)
│   ├── layers-core.scd       # Core data structures and initialization
│   ├── layers-playback.scd   # ProcMod and playback logic
│   ├── layers-control.scd    # API functions
│   ├── layers-gui.scd        # GUI integration
│   └── load-layers.scd       # Main loader
└── claude.md        (update with loading instructions)
```

## Key Design Changes Based on Feedback

### 1. Correct ProcMod Pattern
```supercollider
// Parent ProcMod with minimal validation
~createParentProcMod = {
    var env = Env.asr(0.05, 1.0, 0.05, \lin);  // Short fade in/out
    var parentId = "layerParent_" ++ Date.getDate.stamp;
    
    ProcMod.new(
        env, 1.0, parentId.asSymbol, nil, 0, 1,
        { |parentGroup, envbus|
            // Return a Task, don't execute inline
            Task({
                var maxDuration = ~calculateMaxDuration.();
                // Layer logic here
                maxDuration.wait;
            })
        }
    )
};
```

### 2. Minimal Validation
```supercollider
// BAD - Avoid excessive nil checks
if (~something.notNil and: { ~other.notNil }) { ... }

// GOOD - Trust the system is initialized
~layerConfigs.keysValuesDo { |name, config|
    // Direct usage without validation
}
```

### 3. Default VST Groups
```supercollider
// Initialize with default groups from vstplugin-setup.scd
~initializeLayers = {
    ~layerConfigs = Dictionary[
        \layer1 -> (
            melodyList: [],
            vstGroup: 'Layer1',  // Default from vstplugin-setup
            enabled: true
        ),
        \layer2 -> (
            melodyList: [],
            vstGroup: 'Layer2',  // Default from vstplugin-setup
            enabled: true
        ),
        \layer3 -> (
            melodyList: [],
            vstGroup: 'Layer3',  // Default from vstplugin-setup
            enabled: true
        )
    ];
};
```

### 4. No Automatic Progression
```supercollider
// Melodies loop at their current position
~playLayerMelody = { |config, maxDuration|
    var currentTime = 0;
    var melodyIndex = 0;
    
    while { currentTime < maxDuration } {
        var melodyKey = config.melodyList[0];  // Always play first melody
        // NO automatic advancement
    };
};
```

## Implementation Files

### 1. layers/layers-core.scd
```supercollider
// Core data structures
~layers = (
    parentProc: nil,
    configs: Dictionary.new,
    state: (isPlaying: false)
);

// Initialize with defaults
~initializeLayers = {
    ~layers.configs[\layer1] = (
        melodyList: [],
        vstGroup: 'Layer1',
        enabled: true
    );
    ~layers.configs[\layer2] = (
        melodyList: [],
        vstGroup: 'Layer2',
        enabled: true
    );
    ~layers.configs[\layer3] = (
        melodyList: [],
        vstGroup: 'Layer3',
        enabled: true
    );
};
```

### 2. layers/layers-playback.scd
```supercollider
// Duration calculation without validation
~calculateMelodyDuration = { |melodyKey|
    var pattern = ~melodyDict[melodyKey].patterns[0];
    var noteCount = pattern.size;
    var noteDuration = ~ccControl.noteDuration;
    var noteRestTime = ~ccControl.noteRestTime;
    
    (noteCount * (noteDuration + noteRestTime))
};

// Parent ProcMod creation
~createLayersParentProc = {
    var env = Env.asr(0.05, 1.0, 0.05, \lin);
    var id = "layersParent";
    
    ProcMod.new(
        env, 1.0, id.asSymbol, nil, 0, 1,
        { |parentGroup, envbus|
            Task({
                var maxDuration = 0;
                var layerTasks = [];
                
                // Calculate max duration
                ~layers.configs.keysValuesDo { |name, config|
                    if (config.enabled) {
                        var duration = 0;
                        config.melodyList.do { |melody|
                            duration = duration + ~calculateMelodyDuration.(melody);
                        };
                        maxDuration = max(maxDuration, duration);
                    };
                };
                
                // Create layer tasks
                ~layers.configs.keysValuesDo { |name, config|
                    if (config.enabled) {
                        var task = ~createLayerTask.(name, config, parentGroup, maxDuration);
                        layerTasks = layerTasks.add(task);
                    };
                };
                
                // Start all tasks
                layerTasks.do(_.play);
                maxDuration.wait;
            })
        }
    )
};

// Individual layer task
~createLayerTask = { |layerName, config, parentGroup, maxDuration|
    Task({
        var currentTime = 0;
        var melodyKey = config.melodyList[0];  // Play first melody only
        var previousGroup = ~activeVSTGroup;
        
        // Set VST targeting
        ~setActiveVSTGroup.(config.vstGroup);
        
        while { currentTime < maxDuration } {
            var duration = ~calculateMelodyDuration.(melodyKey);
            var playDuration = min(duration, maxDuration - currentTime);
            
            // Play melody segment
            ~playLayerMelodySegment.(melodyKey, layerName, playDuration);
            
            playDuration.wait;
            currentTime = currentTime + playDuration;
        };
        
        // Restore VST targeting
        ~setActiveVSTGroup.(previousGroup);
    })
};
```

### 3. layers/layers-control.scd
```supercollider
// Simple API without excessive validation
~startLayers = {
    if (~layers.state.isPlaying) {
        "Layers already playing".warn;
    } {
        ~layers.parentProc = ~createLayersParentProc.();
        ~layers.parentProc.play;
        ~layers.state.isPlaying = true;
    };
};

~stopLayers = {
    ~layers.parentProc.release;
    ~layers.state.isPlaying = false;
};

~setLayerMelody = { |layerName, melodyKey|
    ~layers.configs[layerName].melodyList = [melodyKey];
};

~setLayerEnabled = { |layerName, enabled|
    ~layers.configs[layerName].enabled = enabled;
};
```

### 4. layers/layers-gui.scd
```supercollider
// GUI integration
~createLayersGUI = {
    var win, layout;
    
    win = Window("Layer Control", Rect(100, 100, 300, 400));
    layout = VLayout();
    
    // Transport
    layout.add(HLayout(
        Button()
            .states_([["Start Layers"]])
            .action_({ ~startLayers.() }),
        Button()
            .states_([["Stop Layers"]])
            .action_({ ~stopLayers.() })
    ));
    
    // Layer controls
    3.do { |i|
        var layerName = ("layer" ++ (i+1)).asSymbol;
        var config = ~layers.configs[layerName];
        
        layout.add(StaticText().string_("Layer " ++ (i+1)));
        
        layout.add(
            CheckBox()
                .string_("Enabled")
                .value_(config.enabled)
                .action_({ |cb| ~setLayerEnabled.(layerName, cb.value) })
        );
        
        layout.add(
            PopUpMenu()
                .items_(~melodyData.collect(_.key.asString))
                .action_({ |menu| 
                    ~setLayerMelody.(layerName, ~melodyData[menu.value].key)
                })
        );
    };
    
    win.layout = layout;
    win.front;
};
```

### 5. layers/load-layers.scd
```supercollider
// Main loader
(
"Loading Dependent Layer System...".postln;

// Load components in order
(thisProcess.nowExecutingPath.dirname +/+ "layers-core.scd").load;
(thisProcess.nowExecutingPath.dirname +/+ "layers-playback.scd").load;
(thisProcess.nowExecutingPath.dirname +/+ "layers-control.scd").load;
(thisProcess.nowExecutingPath.dirname +/+ "layers-gui.scd").load;

// Initialize
~initializeLayers.();

"Dependent Layer System loaded successfully".postln;
"Use ~createLayersGUI.() to open control interface".postln;
)
```

## Integration Strategy

### 1. Update claude.md
```
To use the dependent layer system:
1. Load the sketch system as normal
2. Then load: (thisProcess.nowExecutingPath.dirname +/+ "layers/load-layers.scd").load;
3. Open GUI: ~createLayersGUI.()
```

### 2. Minimal Integration Points
- Uses existing ~melodyDict
- Uses existing ~ccControl for timing
- Uses existing ~setActiveVSTGroup for routing
- No modification to existing sketch files

### 3. Testing Approach
1. Test in isolation first
2. Verify VST routing works
3. Check synchronization
4. Integrate with main system

## Benefits of This Approach

1. **Zero Risk**: No changes to existing code
2. **Clean Architecture**: Clear separation of concerns
3. **Easy Debugging**: Isolated codebase
4. **Optional Feature**: Can be loaded when needed
5. **Simple Testing**: Test without affecting main system

## Next Steps

1. Create `layers/` directory
2. Implement `layers-core.scd` with basic structures
3. Build minimal playback system
4. Test with 2 layers
5. Expand to full 3-layer system
6. Create GUI
7. Document usage