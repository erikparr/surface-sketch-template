// Test Parameter Monitor GUI
"=== Testing Parameter Monitor GUI ===".postln;

try {
    // Create MIDI controller with OSC enabled
    "Creating MIDIController with OSC enabled...".postln;
    ~testController = MIDIController.new(
        nil,           // No VST instances
        nil,           // No OSC address  
        debug: false,  // Disable debug to reduce output
        enableOSC: true // Enable OSC for full functionality
    );
    "✓ MIDIController with OSC created successfully".postln;
    
    // Load parameter monitor GUI
    "Loading Parameter Monitor GUI...".postln;
    (thisProcess.nowExecutingPath.dirname +/+ "setup/parameter-monitor-gui.scd").load;
    "✓ Parameter Monitor GUI loaded".postln;
    
    // Open the GUI
    "Opening Parameter Monitor GUI...".postln;
    ~parameterGUI = ~createParameterMonitorGUI.(~testController);
    "✓ Parameter Monitor GUI opened".postln;
    
    // Test enabling OSC for a few parameters
    fork {
        2.wait;
        "Testing OSC parameter enablement...".postln;
        ~testController.enableOSCForKnob(1, 8);
        ~testController.enableOSCForKnob(2, 3);
        ~testController.enableOSCForSlider(0);
        "✓ Enabled OSC for test parameters".postln;
    };
    
} { |error|
    "✗ Test failed: %".format(error.errorString).postln;
    error.postln;
};