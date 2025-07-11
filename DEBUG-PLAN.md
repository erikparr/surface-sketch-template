# Debug Plan for Layers System Errors

## Overview
The layers system is failing when clicking "Start All Layers" in the GUI. Based on code analysis, the system depends heavily on the sketch system and requires careful initialization order.

## Current Understanding

### System Architecture
1. **Order of Operations:**
   - SuperCollider boots automatically
   - Setup files load via `_setup-loader.scd`
   - Sketch system loads via `sketch/load-sketch.scd`
   - Layers system is loaded manually after

2. **Dependencies:**
   - Layers depend on sketch system variables: `~melodyDict`, `~processNote`, `~ccControl`
   - Layers depend on VST Manager: `~vstManager`, `~setActiveVSTGroup`
   - Layers use ProcMod for playback control

### Potential Issues

1. **Missing Dependencies**
   - `~melodyDict` might be nil (no melodies loaded)
   - `~vstManager` might not be initialized
   - Sketch system functions might not be available

2. **Timing Issues**
   - Layers GUI loads immediately but systems may not be ready
   - VST groups might not be loaded when GUI starts

3. **Melody Data**
   - No melodies may be loaded into the system
   - Melody format mismatch between systems

## Debug Steps

### Step 1: Verify Basic System State
```supercollider
// Check if core systems are loaded
~melodyDict.postln;           // Should show loaded melodies
~vstManager.postln;           // Should show VST manager
~ccControl.postln;            // Should show CC control state
~processNote.postln;          // Should be a function
~setActiveVSTGroup.postln;    // Should be a function
```

### Step 2: Check Layers Initialization
```supercollider
// Check layers state
~layers.postln;               // Should show the layers structure
~layers.configs.postln;       // Should show 3 layer configs
~printLayerStatus.();         // Should print current status
```

### Step 3: Load Test Melodies
```supercollider
// Create simple test melodies if none exist
if (~melodyDict.isNil) {
    ~melodyDict = Dictionary.new;
};

// Add test melodies
~melodyDict[\testMelody1] = (
    name: "Test Melody 1",
    patterns: [[60, 62, 64, 65, 67]],
    velocityMultipliers: (first: 1.0, last: 1.0),
    loopCount: 1
);

~melodyDict[\testMelody2] = (
    name: "Test Melody 2", 
    patterns: [[67, 65, 64, 62, 60]],
    velocityMultipliers: (first: 1.0, last: 1.0),
    loopCount: 1
);

// Configure layers with test melodies
~setLayerMelody.(\layer1, \testMelody1);
~setLayerMelody.(\layer2, \testMelody2);
~printLayerStatus.();
```

### Step 4: Check VST Groups
```supercollider
// Check if VST groups exist
~vstManager.getGroupNames().postln;

// If no groups, wait and refresh
if (~vstManager.isNil or: { ~vstManager.getGroupNames().size == 0 }) {
    "Waiting for VST groups to load...".postln;
    // Click the "Refresh VST Groups" button in the GUI
};
```

### Step 5: Test Playback with Debug Info
```supercollider
// Add debug wrapper
(
~startLayersDebug = {
    "=== DEBUG: Starting Layers ===".postln;
    
    // Check prerequisites
    "Active layer count: %".format(~getActiveLayerCount.()).postln;
    "Ready layers: %".format(~getReadyLayers.()).postln;
    
    if (~layers.parentProc.notNil) {
        "WARNING: Parent proc already exists!".postln;
    };
    
    // Try to start
    try {
        ~startLayers.();
    } { |error|
        "ERROR starting layers: %".format(error).postln;
        error.reportError;
    };
};

~startLayersDebug.();
)
```

### Step 6: Add Error Checking to Core Functions

Add safety checks to `layers-playback.scd`:

1. Check if `~melodyDict` exists before accessing
2. Verify VST groups are available
3. Add fallbacks for missing sketch functions

### Step 7: Create Minimal Test
```supercollider
// Test ProcMod creation directly
(
var testProc = ProcMod.new(
    Env.asr(0.1, 1.0, 0.1),
    1.0,
    \test,
    nil, 0, 1,
    { |group, envbus|
        "Test ProcMod running in group %".format(group).postln;
        Task({ 
            "Playing test note".postln;
            1.wait;
            "Test complete".postln;
        })
    }
);

testProc.play;
SystemClock.sched(2, { testProc.release; nil });
)
```

## Solutions

### Fix 1: Add Initialization Checks
Modify `layers-control.scd` to verify dependencies before starting.

### Fix 2: Add Default Melodies
Include simple default melodies in the layers system.

### Fix 3: Improve Error Messages
Add specific error messages for each failure case.

### Fix 4: Create Setup Verification
Add a function to verify all systems are ready before allowing playback.

## Next Steps

1. Run diagnostic code blocks above in order
2. Identify which dependency is missing
3. Apply appropriate fix
4. Test with GUI again
5. Document findings

## Notes
- The GUI shows "Auto-loading VST Groups..." which suggests VST manager isn't ready
- The system expects melodies to be pre-loaded from the sketch system
- ProcMod requires careful envelope and timing management