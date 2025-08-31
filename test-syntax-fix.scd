// Quick syntax check for the fixed files
"=== Testing Syntax Fix ===".postln;

// Test that all classes can be instantiated
try {
    "Testing LiveParameterRegistry...".postln;
    ~testParam = LiveParameterRegistry.new(true);
    "✓ LiveParameterRegistry syntax OK".postln;
} { |error|
    "✗ LiveParameterRegistry error: %".format(error.errorString).postln;
};

try {
    "Testing LiveInputRouter...".postln;
    ~testInput = LiveInputRouter.new(~testParam, true);  
    "✓ LiveInputRouter syntax OK".postln;
} { |error|
    "✗ LiveInputRouter error: %".format(error.errorString).postln;
};

try {
    "Testing LiveOSCController...".postln;
    ~testOSC = LiveOSCController.new(~testInput, ~testParam, debug: true);
    "✓ LiveOSCController syntax OK".postln;
} { |error|
    "✗ LiveOSCController error: %".format(error.errorString).postln;
};

try {
    "Testing MIDIControllerEnhanced...".postln;
    ~testMIDI = MIDIControllerEnhanced.new(nil, nil, debug: true, enableOSC: false);
    "✓ MIDIControllerEnhanced syntax OK".postln;
} { |error|
    "✗ MIDIControllerEnhanced error: %".format(error.errorString).postln;
};

// Cleanup
[~testParam, ~testInput, ~testOSC, ~testMIDI].do { |obj|
    if (obj.notNil) { try { obj.free } };
};

"=== Syntax Test Complete ===".postln;