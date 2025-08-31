// layers-osc-integration.scd
// Integration example showing OSC control with the layers system

"=== Layers System OSC Integration Example ===".postln;

// Step 1: Create enhanced MIDI controller for layers system
"Step 1: Creating enhanced MIDI controller for layers...".postln;
if (~midiController.class != MIDIControllerEnhanced) {
    "Creating new enhanced MIDI controller...".postln;
    if (~midiController.notNil) {
        ~midiController.free;  // Clean up old controller
    };
    
    ~midiController = MIDIControllerEnhanced.new(
        ~vstInstances,
        ~oscNetAddr,
        debug: true,
        enableOSC: true
    );
    
    "Enhanced MIDI controller created".postln;
} {
    "Using existing enhanced MIDI controller".postln;
};

// Step 2: Enable OSC for layer-relevant parameters
"Step 2: Enabling OSC for layer control parameters...".postln;

// Enable OSC for key layer control knobs
var layerControlKnobs = [
    [1, 8, "Global duration control"],
    [1, 4, "Global timing offset"],
    [1, 2, "Layer 1 note duration scalar"],
    [1, 3, "Layer 1 velocity"],
    [2, 2, "Layer 2 note duration scalar"], 
    [2, 3, "Layer 2 velocity"],
    [3, 2, "Layer 3 note duration scalar"],
    [3, 3, "Layer 3 velocity"]
];

layerControlKnobs.do { |knobInfo|
    var row = knobInfo[0];
    var pos = knobInfo[1];
    var description = knobInfo[2];
    var oscAddr = ~midiController.enableOSCForKnob(row, pos);
    "  %: %".format(description, oscAddr).postln;
};

// Step 3: Create layer-specific parameter mappings
"Step 3: Creating layer-specific OSC addresses...".postln;

// Register layer-specific parameters
var layerParams = [
    ["layer1_velocity", ControlSpec(1, 127, \lin, 1, 100), "Layer 1 Velocity"],
    ["layer2_velocity", ControlSpec(1, 127, \lin, 1, 100), "Layer 2 Velocity"],
    ["layer3_velocity", ControlSpec(1, 127, \lin, 1, 100), "Layer 3 Velocity"],
    ["global_duration", ControlSpec(0.01, 10, \exp, 0, 4), "Global Duration"],
    ["global_timing_offset", ControlSpec(-0.45, 0.45, \lin, 0, 0), "Global Timing Offset"],
    ["layer1_note_duration_scalar", ControlSpec(0.01, 1.5, \lin, 0, 1.0), "Layer 1 Note Duration"],
    ["layer2_note_duration_scalar", ControlSpec(0.01, 1.5, \lin, 0, 1.0), "Layer 2 Note Duration"],
    ["layer3_note_duration_scalar", ControlSpec(0.01, 1.5, \lin, 0, 1.0), "Layer 3 Note Duration"],
];

layerParams.do { |paramInfo|
    var id = paramInfo[0];
    var spec = paramInfo[1];
    var description = paramInfo[2];
    
    ~midiController.parameterRegistry.registerParameter(id, spec, (description: description));
    var oscAddr = ~midiController.enableOSCForParameter(id);
    "  %: %".format(description, oscAddr).postln;
};

// Step 4: Set up parameter change callbacks for layers integration
"Step 4: Setting up layer integration callbacks...".postln;

// Global duration callback
~midiController.parameterRegistry.onParameterChange("global_duration", { |id, oldVal, newVal, source|
    "Global duration changed to % seconds (source: %)".format(newVal.round(0.01), source).postln;
    // This would integrate with ~getLayersDurationFromKnob if needed
});

// Layer velocity callbacks
["layer1_velocity", "layer2_velocity", "layer3_velocity"].do { |paramId|
    ~midiController.parameterRegistry.onParameterChange(paramId, { |id, oldVal, newVal, source|
        var layerNum = id.asString.split($_)[0].last.asString;
        "Layer % velocity changed to % (source: %)".format(layerNum, newVal.asInteger, source).postln;
        // This would integrate with layer velocity override system
    });
};

// Step 5: Create OSC control functions for layers
"Step 5: Creating OSC control functions...".postln;

// Function to start layers via OSC
~startLayersOSC = { |duration=nil|
    var effectiveDuration = duration ?? {
        ~midiController.parameterRegistry.getParameterValue("global_duration") ? 4.0
    };
    "Starting layers with duration % (via OSC)".format(effectiveDuration).postln;
    ~startLayers.(effectiveDuration);
};

// Function to set layer velocity via OSC
~setLayerVelocityOSC = { |layerNum, velocity|
    var paramId = "layer" ++ layerNum ++ "_velocity";
    ~midiController.parameterRegistry.updateParameter(paramId, velocity, \osc);
    "Set layer % velocity to % (via OSC)".format(layerNum, velocity).postln;
};

// Function to set global duration via OSC
~setGlobalDurationOSC = { |duration|
    ~midiController.parameterRegistry.updateParameter("global_duration", duration, \osc);
    "Set global duration to % seconds (via OSC)".format(duration).postln;
};

// Step 6: Set up OSC responders for high-level layer control
"Step 6: Setting up high-level layer OSC control...".postln;

// High-level layer control OSC addresses
var layerControlOSC = [
    ["/layers/start", { |msg| ~startLayersOSC.(msg[1]) }],
    ["/layers/stop", { |msg| ~stopLayers.() }],
    ["/layers/kill", { |msg| ~killLayers.() }],
    ["/layers/duration", { |msg| ~setGlobalDurationOSC.(msg[1]) }],
    ["/layers/layer1/velocity", { |msg| ~setLayerVelocityOSC.(1, msg[1]) }],
    ["/layers/layer2/velocity", { |msg| ~setLayerVelocityOSC.(2, msg[1]) }],
    ["/layers/layer3/velocity", { |msg| ~setLayerVelocityOSC.(3, msg[1]) }],
];

layerControlOSC.do { |controlInfo|
    var address = controlInfo[0];
    var handler = controlInfo[1];
    
    OSCFunc(handler, address.asSymbol);
    "  Registered OSC handler: %".format(address).postln;
};

// Step 7: Enable bidirectional sync and add TouchOSC client example
"Step 7: Setting up bidirectional sync...".postln;
~midiController.enableBidirectionalOSC(true);

// Add example OSC client (TouchOSC, etc.)
// ~midiController.addOSCClient("192.168.1.100", 9000);  // Uncomment for real client

// Step 8: Create usage examples
"Step 8: Usage examples...".postln;

~layerOSCExamples = {
    var testAddr = NetAddr("127.0.0.1", 57121);
    
    "\\n=== Layer OSC Control Examples ===".postln;
    "// Set global duration to 2.5 seconds".postln;
    "NetAddr(\"127.0.0.1\", 57121).sendMsg(\"/param/global/duration\", 2.5)".postln;
    
    "// Set layer 1 velocity to 120".postln;
    "NetAddr(\"127.0.0.1\", 57121).sendMsg(\"/param/layer1/velocity\", 120)".postln;
    
    "// Start layers with 3 second duration".postln;
    "NetAddr(\"127.0.0.1\", 57121).sendMsg(\"/layers/start\", 3.0)".postln;
    
    "// Control via MIDI row/position addresses".postln;
    "NetAddr(\"127.0.0.1\", 57121).sendMsg(\"/midi/row1/pos8\", 0.3)  // Duration knob".postln;
    "NetAddr(\"127.0.0.1\", 57121).sendMsg(\"/midi/row1/pos3\", 110)  // Layer 1 velocity".postln;
    
    "// High-level layer control".postln;
    "NetAddr(\"127.0.0.1\", 57121).sendMsg(\"/layers/stop\")".postln;
    "NetAddr(\"127.0.0.1\", 57121).sendMsg(\"/layers/kill\")".postln;
    
    "\\n=== Available OSC Addresses ===".postln;
    ~midiController.listOSCAddresses().keysValuesDo { |paramId, address|
        "  %".format(address).postln;
    };
};

// Step 9: Test integration
"Step 9: Testing integration...".postln;
fork {
    var testAddr = NetAddr("127.0.0.1", 57121);
    
    2.wait;
    
    "Testing parameter updates...".postln;
    testAddr.sendMsg("/param/global/duration", 1.5);
    
    0.5.wait;
    testAddr.sendMsg("/param/layer1/velocity", 115);
    
    1.wait;
    "Test complete - check parameter values".postln;
    
    "Current parameter values:".postln;
    ["global_duration", "layer1_velocity"].do { |paramId|
        var value = ~midiController.parameterRegistry.getParameterValue(paramId);
        "  %: %".format(paramId, value).postln;
    };
};

// Completion
"\\n=== Layers OSC Integration Complete ===".postln;
"Use ~layerOSCExamples.() to see usage examples".postln;
"Use ~midiController.printParameterState() to see full state".postln;
"Layers system now supports both MIDI and OSC control!".postln;