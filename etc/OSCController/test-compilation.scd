// test-compilation.scd  
// Simple compilation test for the new OSC parameter control system

"=== Testing Class Compilation ===".postln;

// Test 1: Create ParameterRegistry
"Creating LiveParameterRegistry...".postln;
try {
    ~testRegistry = LiveParameterRegistry.new(debug: true);
    "✓ LiveParameterRegistry created successfully".postln;
} { |error|
    "✗ LiveParameterRegistry failed: %".format(error.errorString).postln;
};

// Test 2: Create InputRouter  
"Creating LiveInputRouter...".postln;
try {
    ~testRouter = LiveInputRouter.new(~testRegistry, debug: true);
    "✓ LiveInputRouter created successfully".postln;
} { |error|
    "✗ LiveInputRouter failed: %".format(error.errorString).postln;
};

// Test 3: Create OSCController
"Creating LiveOSCController...".postln;
try {
    ~testOSC = LiveOSCController.new(~testRouter, ~testRegistry, debug: true);
    "✓ LiveOSCController created successfully".postln;
} { |error|
    "✗ LiveOSCController failed: %".format(error.errorString).postln;
};

// Test 4: Test basic functionality
"Testing basic parameter functionality...".postln;
try {
    var value;
    // Register a test parameter
    ~testRegistry.registerParameter("test_param", ControlSpec(0, 127, \lin, 1, 64));
    
    // Update the parameter
    ~testRegistry.updateParameter("test_param", 100, \test);
    
    // Get the value back
    value = ~testRegistry.getParameterValue("test_param");
    "✓ Parameter functionality works. Test value: %".format(value).postln;
} { |error|
    "✗ Parameter functionality failed: %".format(error.errorString).postln;
};

// Test 5: Test OSC address generation
"Testing OSC address generation...".postln;
try {
    var address;
    address = ~testOSC.generateOSCAddress("test_param");
    "✓ OSC address generated: %".format(address).postln;
} { |error|
    "✗ OSC address generation failed: %".format(error.errorString).postln;
};

// Test 6: Create enhanced MIDI controller (if VST instances available)
"Creating MIDIControllerEnhanced...".postln;
try {
    ~testEnhancedMIDI = MIDIControllerEnhanced.new(
        nil,           // No VST instances for test
        nil,           // No OSC net address for test  
        debug: true,
        enableOSC: true
    );
    "✓ MIDIControllerEnhanced created successfully".postln;
} { |error|
    "✗ MIDIControllerEnhanced failed: %".format(error.errorString).postln;
};

// Cleanup
"Cleaning up test objects...".postln;
try {
    if (~testOSC.notNil) { ~testOSC.free };
    if (~testRouter.notNil) { ~testRouter.free };
    if (~testRegistry.notNil) { ~testRegistry.free };
    if (~testEnhancedMIDI.notNil) { ~testEnhancedMIDI.free };
    "✓ Cleanup completed".postln;
} { |error|
    "✗ Cleanup failed: %".format(error.errorString).postln;
};

"=== Compilation Test Complete ===".postln;