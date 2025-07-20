// Simple OSC test without JSON conversion
(
"=== Simple OSC Test ===".postln;

// Test 1: Check if live melody mode is enabled
"Live melody mode enabled: %".format(~layers.state.liveMelodyMode).postln;

// Test 2: Send raw JSON string
~testRawJSON = {
    var addr = NetAddr("127.0.0.1", 57120);
    var jsonString = "{\"notes\":[{\"midi\":60,\"vel\":0.8,\"dur\":0.5}]}";
    
    "Sending raw JSON string: %".format(jsonString).postln;
    addr.sendMsg('/liveMelody/update/layer1', jsonString);
};

// Test 3: Simple JSON test
~testSimpleJSON = {
    var addr = NetAddr("127.0.0.1", 57120);
    var jsonString = "{\"notes\":[{\"midi\":62,\"vel\":0.9,\"dur\":0.4},{\"midi\":64,\"vel\":0.7,\"dur\":0.6}]}";
    
    "Sending simple melody JSON: %".format(jsonString).postln;
    addr.sendMsg('/liveMelody/update/layer1', jsonString);
};

// Test 3: Check if conversion function exists
"~convertEventToDict exists: %".format(~convertEventToDict.notNil).postln;

// Test 4: Test conversion function directly
if (~convertEventToDict.notNil) {
    var testData = (notes: [(midi: 60, vel: 0.8, dur: 0.5)]);
    var converted = ~convertEventToDict.(testData);
    "Conversion test result: %".format(converted).postln;
};

"Run ~testRawJSON.() to test with raw JSON".postln;
)