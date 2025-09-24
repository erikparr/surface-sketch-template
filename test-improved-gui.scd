/*
Test script for improved OSC Layers GUI
Tests the new global melody loading functionality
*/

// Load the improved GUI
(thisProcess.nowExecutingPath.dirname +/+ "layers/layers-gui-osc.scd").load;

// Test the global melody loading function
~testGlobalMelodyLoading = {
    var testFile = thisProcess.nowExecutingPath.dirname +/+ "data/layer-melodies.json";

    "Testing global melody loading with file: %".format(testFile).postln;

    ~loadGlobalMelodyFile.(testFile, { |success, melodyCount, filename|
        if (success) {
            "✓ SUCCESS: Loaded % melodies from %".format(melodyCount, filename).postln;
            "Available melodies: %".format(~melodyDict.keys.asArray.sort).postln;
        } {
            "✗ FAILED to load melody file".postln;
        };
    });
};

"Test script loaded. Run ~testGlobalMelodyLoading.() to test.".postln;