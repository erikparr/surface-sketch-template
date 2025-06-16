/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                        MIDI CONTROLLER SLIDER TEST                           ║
║                      Debug slider value storage issues                       ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// Test function to check slider mappings and values
~testSliderValues = {
    "=== MIDI CONTROLLER SLIDER TEST ===".postln;
    
    // Check if MIDI controller exists
    if(~midiController.isNil) {
        "ERROR: ~midiController is nil! Load the system first.".postln;
        ^nil;
    };
    
    // Show current preset info
    "Current preset: %".format(~midiController.getControllerPreset).postln;
    
    // Show slider CC mappings from preset
    if(~midiController.activePreset.notNil) {
        "Slider CCs in preset: %".format(~midiController.activePreset.sliders).postln;
        
        // Show the mapping: Index -> CC Number
        ~midiController.activePreset.sliders.do { |cc, index|
            "  Index % -> CC %".format(index, cc).postln;
        };
    };
    
    "".postln;
    "Current slider values (sliderValues array):".postln;
    ~midiController.sliderValues.do { |val, index|
        var cc = ~midiController.activePreset.sliders[index];
        "  Index % (CC %): %".format(index, cc, val).postln;
    };
    
    "".postln;
    "Testing getSliderValue() method:".postln;
    9.do { |i|
        var val = ~midiController.getSliderValue(i);
        var cc = ~midiController.activePreset.sliders[i];
        "  getSliderValue(%) -> % (CC %)".format(i, val, cc).postln;
    };
    
    "".postln;
    "Mapping mode status: %".format(~midiController.mappingMode).postln;
    "Row mappings: %".format(~midiController.rowMappings.notNil).postln;
    
    "=== END TEST ===".postln;
};

// Test function to manually set a slider value and verify
~testSetSliderValue = { |index, value|
    "=== MANUALLY SETTING SLIDER VALUE ===".postln;
    "Setting slider index % to value %".format(index, value).postln;
    
    if(~midiController.notNil) {
        var retrievedValue;
        ~midiController.sliderValues[index] = value;
        "Set complete. Verifying...".postln;
        
         retrievedValue = ~midiController.getSliderValue(index);
        "Retrieved value: %".format(retrievedValue).postln;
        
        if(retrievedValue == value) {
            "✓ SUCCESS: Values match!".postln;
        } {
            "✗ ERROR: Values don't match! Expected %, got %".format(value, retrievedValue).postln;
        };
    } {
        "ERROR: ~midiController is nil!".postln;
    };
    "=== END MANUAL TEST ===".postln;
};

// Test specific CC processing bypass
~testDirectCCProcessing = { |ccNum, value|
    "=== TESTING DIRECT CC PROCESSING ===".postln;
    "Simulating CC % with value % (normalized: %)".format(ccNum, value, value/127.0).postln;
    
    if(~midiController.notNil && ~midiController.activePreset.notNil) {
        var sliders = ~midiController.activePreset.sliders;
        var sliderIndex = sliders.indexOf(ccNum);
        var normalizedVal;
        var retrievedValue;
        if(sliderIndex.notNil) {
            "CC % maps to slider index %".format(ccNum, sliderIndex).postln;
            
            // Directly set the slider value (bypassing mapping system)
             normalizedVal = value / 127.0;
            ~midiController.sliderValues[sliderIndex] = normalizedVal;
            
            // Verify
             retrievedValue = ~midiController.getSliderValue(sliderIndex);
            "Direct set result: %".format(retrievedValue).postln;
            
            if(retrievedValue == normalizedVal) {
                "✓ SUCCESS: Direct setting works!".postln;
            } {
                "✗ ERROR: Direct setting failed!".postln;
            };
        } {
            "CC % is not mapped to any slider in current preset".format(ccNum).postln;
            "Available slider CCs: %".format(sliders).postln;
        };
    } {
        "ERROR: MIDI controller or preset not available!".postln;
    };
    "=== END DIRECT CC TEST ===".postln;
};

// Run basic test
"Slider test functions loaded. Usage:".postln;
"~testSliderValues.() - Show current state".postln;
"~testSetSliderValue.(index, value) - Manually test setting".postln;
"~testDirectCCProcessing.(ccNum, midiValue) - Test CC processing".postln;
"".postln;
"Running basic test now...".postln;
~testSliderValues.(); 