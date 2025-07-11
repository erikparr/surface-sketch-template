/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                        VST ROUTING TEST                                      ║
║                     Isolate and verify VST targeting                         ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// This test file verifies if VST routing is working correctly
// Run each section step by step to isolate the issue

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         TEST 1: VERIFY VST GROUPS                          │
// └─────────────────────────────────────────────────────────────────────────────┘

// First, check what VST groups and instances are available
(
"=== TEST 1: Available VST Groups ===".postln;
if (~vstManager.notNil) {
    "VST Manager is available".postln;
    "Groups: %".format(~vstManager.groups.keys.asArray.sort).postln;
    
    ~vstManager.groups.keysValuesDo { |groupName, instances|
        "\nGroup '%' contains:".format(groupName).postln;
        instances.do { |vstKey|
            var vst = ~vstManager.vstInstances[vstKey];
            "  - % (VST: %)".format(vstKey, vst.notNil).postln;
        };
    };
} {
    "ERROR: VST Manager not available".postln;
};
)

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                     TEST 2: VERIFY getTargetInstances                      │
// └─────────────────────────────────────────────────────────────────────────────┘

// Test if getTargetInstances returns the correct instances
(
"=== TEST 2: Testing getTargetInstances ===".postln;
if (~vstManager.notNil) {
    ['Bass Tuba 01', 'Bass Tuba 02', 'Bass Tuba 03', nil].do { |groupName|
        var instances = ~vstManager.getTargetInstances(groupName);
        var label = groupName ? "ALL";
        "\nGroup '%': % instances".format(label, instances.size).postln;
        "Instance keys: %".format(instances.keys.asArray.sort).postln;
    };
} {
    "ERROR: VST Manager not available".postln;
};
)

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                     TEST 3: DIRECT NOTE TEST                               │
// └─────────────────────────────────────────────────────────────────────────────┘

// Send notes directly to specific VST groups
(
"=== TEST 3: Direct Note Test ===".postln;
"This will play C4 (note 60) on each VST group separately".postln;
"You should hear only one note per group\n".postln;

fork {
    ['Bass Tuba 01', 'Bass Tuba 02', 'Bass Tuba 03'].do { |groupName|
        "Playing note on group: %".format(groupName).postln;
        
        var instances = ~vstManager.getTargetInstances(groupName);
        "Found % instances: %".format(instances.size, instances.keys.asArray).postln;
        
        instances.do { |vst, vstKey|
            "  Sending noteOn to: %".format(vstKey).postln;
            vst.midi.noteOn(0, 60, 100);
        };
        
        1.wait;  // Hold note for 1 second
        
        instances.do { |vst, vstKey|
            "  Sending noteOff to: %".format(vstKey).postln;
            vst.midi.noteOff(0, 60, 0);
        };
        
        1.wait;  // Wait before next group
    };
    
    "Test complete".postln;
}
)

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                     TEST 4: SIMULATE LAYER NOTES                           │
// └─────────────────────────────────────────────────────────────────────────────┘

// Simulate what the layers system does
(
"=== TEST 4: Simulating Layer System ===".postln;
"This simulates the OSC message handling from layers".postln;

// Temporarily replace the OSC handler to add more debugging
OSCdef(\testLayerNoteOn, { |msg, time, addr, recvPort|
    var layerName = msg[1].asSymbol;
    var note = msg[2].asInteger;
    var velocity = msg[3].asInteger;
    var duration = msg[4].asFloat;
    
    "\n[OSC] Received note for layer: %".format(layerName).postln;
    
    // Get the VST group for this layer
    var config = ~layers.configs[layerName];
    if (config.notNil) {
        var vstGroup = config.vstGroup;
        "[OSC] Layer % maps to VST group: %".format(layerName, vstGroup).postln;
        
        // Get instances
        var instances = ~vstManager.getTargetInstances(vstGroup);
        "[OSC] Found % instances for group '%'".format(instances.size, vstGroup).postln;
        "[OSC] Instance keys: %".format(instances.keys.asArray).postln;
        
        // Send to each instance
        instances.keysValuesDo { |vstKey, vst|
            "[OSC] Sending noteOn to instance: %".format(vstKey).postln;
            vst.midi.noteOn(0, note, velocity);
            
            if (duration > 0) {
                SystemClock.sched(duration, {
                    "[OSC] Sending noteOff to instance: %".format(vstKey).postln;
                    vst.midi.noteOff(0, note, 0);
                    nil
                });
            };
        };
    } {
        "[OSC] ERROR: No config found for layer %".format(layerName).postln;
    };
}, '/test/layer/note/on');

// Send test messages
fork {
    // Make sure layers are configured
    ~layers.configs.keysValuesDo { |layerName, config|
        "Layer % configured with VST group: %".format(layerName, config.vstGroup).postln;
    };
    
    0.5.wait;
    
    // Send notes to each layer
    [\layer1, \layer2, \layer3].do { |layerName, i|
        var note = 60 + (i * 2);  // C4, D4, E4
        "\nSending note % to layer %".format(note, layerName).postln;
        NetAddr.localAddr.sendMsg('/test/layer/note/on', layerName, note, 100, 0.5);
        1.5.wait;
    };
    
    "Test complete - cleaning up".postln;
    OSCdef(\testLayerNoteOn).free;
}
)

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                     TEST 5: CHECK VST INSTANCES                            │
// └─────────────────────────────────────────────────────────────────────────────┘

// Deep inspection of VST instances
(
"=== TEST 5: VST Instance Inspection ===".postln;
if (~vstManager.notNil && ~vstManager.vstInstances.notNil) {
    ~vstManager.vstInstances.keysValuesDo { |vstKey, vst|
        "\nVST Instance: %".format(vstKey).postln;
        "  - Class: %".format(vst.class).postln;
        "  - Has MIDI: %".format(vst.midi.notNil).postln;
        if (vst.midi.notNil) {
            "  - MIDI Class: %".format(vst.midi.class).postln;
        };
        
        // Check which groups contain this instance
        var containingGroups = [];
        ~vstManager.groups.keysValuesDo { |groupName, instances|
            if (instances.includes(vstKey)) {
                containingGroups = containingGroups.add(groupName);
            };
        };
        "  - Member of groups: %".format(containingGroups).postln;
    };
} {
    "ERROR: VST Manager or vstInstances not available".postln;
};
)

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                           INSTRUCTIONS                                     │
// └─────────────────────────────────────────────────────────────────────────────┘

"
=== HOW TO USE THIS TEST ===

1. Run each test section one by one
2. Listen carefully during TEST 3 and TEST 4
3. In TEST 3, you should hear each note played by only ONE VST instance
4. In TEST 4, each layer should trigger only its assigned VST group
5. If you hear multiple instances playing the same note, the issue is confirmed

Expected behavior:
- Layer 1 → Bass Tuba 01 only
- Layer 2 → Bass Tuba 02 only  
- Layer 3 → Bass Tuba 03 only

Report back which tests show unexpected behavior!
".postln;