/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                   SIMPLIFIED LAYER TIMING                                    ║
║            Single MIDI knob controls layer spread (0-1 second)               ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

"Loading Simplified Layer Timing...".postln;

// Single function to calculate layer offsets
~getLayerOffsets = {
    var sliderValue = if (~midiController.notNil) {
        ~midiController.getSliderValue(0) / 127.0  // Slider 1 (index 0): 0.0 - 1.0
    } {
        0.5  // Default fallback when MIDI not available
    };

    // Layer timing pattern: L1 at 0s, L2 at half offset, L3 at full offset
    (
        layer1: 0.0,
        layer2: sliderValue * 0.5,
        layer3: sliderValue
    )
};

"Simplified Layer Timing loaded".postln;
"MIDI Control: Slider 1 - Layer spread (0=sync, 1=1sec apart)".postln;