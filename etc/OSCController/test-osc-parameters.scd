// test-osc-parameters.scd
// Comprehensive test examples for OSC parameter control system

"=== OSC Parameter Control System Tests ===".postln;

// Test 1: Create enhanced MIDI controller with OSC support
"Test 1: Creating enhanced MIDI controller with OSC...".postln;
~enhancedMidiController = MIDIControllerEnhanced.new(
    ~vstInstances,           // Use existing VST instances
    ~oscNetAddr,            // Use existing OSC address
    debug: true,            // Enable debug output
    enableOSC: true         // Enable OSC functionality
);

// Wait for initialization
1.wait;

// Test 2: Enable OSC for specific knobs
"Test 2: Enabling OSC for specific knobs...".postln;
~enhancedMidiController.enableOSCForKnob(1, 8);  // Duration knob
~enhancedMidiController.enableOSCForKnob(1, 3);  // Velocity knob
~enhancedMidiController.enableOSCForKnob(2, 5);  // Expression min knob

// Test 3: Enable OSC for all knobs (bulk operation)
"Test 3: Enabling OSC for all knobs...".postln;
~oscAddresses = ~enhancedMidiController.enableOSCForAllKnobs();
"Generated % OSC addresses".format(~oscAddresses.size).postln;

// Test 4: List OSC addresses
"Test 4: Listing OSC addresses...".postln;
~enhancedMidiController.listOSCAddresses().keysValuesDo { |paramId, address|
    "  %: %".format(paramId, address).postln;
};

// Test 5: Enable bidirectional sync
"Test 5: Enabling bidirectional OSC sync...".postln;
~enhancedMidiController.enableBidirectionalOSC(true);

// Test 6: Add OSC client for sync
"Test 6: Adding OSC client...".postln;
~enhancedMidiController.addOSCClient("127.0.0.1", 57122);

// Test 7: Test parameter updates via OSC
"Test 7: Testing OSC parameter updates...".postln;
fork {
    var testAddr;
    testAddr = NetAddr("127.0.0.1", 57121);
    
    // Test different parameter types
    1.wait;
    "Sending /midi/row1/pos8 0.5...".postln;
    testAddr.sendMsg("/midi/row1/pos8", 0.5);
    
    1.wait;
    "Sending /midi/row1/pos3 100...".postln;
    testAddr.sendMsg("/midi/row1/pos3", 100);
    
    1.wait;
    "Sending /midi/row2/pos5 64...".postln;
    testAddr.sendMsg("/midi/row2/pos5", 64);
    
    "OSC test messages sent".postln;
};

// Test 8: Verify backward compatibility
"Test 8: Testing backward compatibility...".postln;
fork {
    2.wait;  // Wait for OSC messages to process
    
    "Original API still works:".postln;
    "  getKnobRow(1, 8): %".format(~enhancedMidiController.getKnobRow(1, 8)).postln;
    "  getKnobRow(1, 3): %".format(~enhancedMidiController.getKnobRow(1, 3)).postln;
    "  getKnobRow(2, 5): %".format(~enhancedMidiController.getKnobRow(2, 5)).postln;
    
    "Enhanced API provides additional info:".postln;
    ~enhancedMidiController.getParameterIDs.do { |paramId|
        var value, oscAddr;
        value = ~enhancedMidiController.parameterRegistry.getParameterValue(paramId);
        oscAddr = ~enhancedMidiController.getParameterOSCAddress(paramId);
        if (oscAddr.notNil) {
            "  %: % = %".format(paramId, oscAddr, value).postln;
        };
    };
};

// Test 9: Parameter change callbacks
"Test 9: Testing parameter change callbacks...".postln;
~enhancedMidiController.parameterRegistry.onParameterChange("midi_row1_pos8", { |id, oldVal, newVal, source|
    "Parameter % changed: % -> % (source: %)".format(id, oldVal, newVal, source).postln;
});

// Test 10: Input source priority testing
"Test 10: Testing input source priorities...".postln;
fork {
    var testAddr;
    3.wait;
    
    // Simulate conflicting inputs
    testAddr = NetAddr("127.0.0.1", 57121);
    
    "Sending OSC input...".postln;
    testAddr.sendMsg("/midi/row1/pos8", 0.8);
    
    0.5.wait;
    
    "Moving physical MIDI knob should override OSC due to higher priority".postln;
    // (Physical MIDI movement would happen here in real scenario)
};

// Utility function to print full system state
~printFullState = {
    "\\n=== Full System State ===".postln;
    ~enhancedMidiController.printParameterState();
};

// Test completion
"\\n=== Tests Complete ===".postln;
"Use ~printFullState.() to see full system state".postln;
"Use ~enhancedMidiController.listOSCAddresses() to see OSC addresses".postln;
"Send OSC messages to test: NetAddr(\"127.0.0.1\", 57121).sendMsg(\"/midi/row1/pos8\", 0.5)".postln;