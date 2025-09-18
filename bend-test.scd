/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                    BEND MODE IMPLEMENTATION TEST                              ║
║                      Test basic bend functionality                            ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

"Testing basic bend mode implementation...".postln;

// Test 1: Check if bend mode can be enabled
if (~setLayersBendMode.notNil) {
    "✓ ~setLayersBendMode function available".postln;
    ~setLayersBendMode.(true);
} {
    "✗ ~setLayersBendMode function not found".postln;
};

// Test 2: Check if bend control functions exist
if (~getLayerBendAmount.notNil) {
    "✓ ~getLayerBendAmount function available".postln;
    "  Current bend amount: % octaves".format(~getLayerBendAmount.().round(0.01)).postln;
} {
    "✗ ~getLayerBendAmount function not found".postln;
};

if (~getLayerBendPeakTime.notNil) {
    "✓ ~getLayerBendPeakTime function available".postln;
    "  Current peak time: %".format(~getLayerBendPeakTime.().round(0.01)).postln;
} {
    "✗ ~getLayerBendPeakTime function not found".postln;
};

// Test 3: Check if layer configurations have bend control
if (~layers.notNil and: { ~layers.configs.notNil }) {
    "✓ Layers system available".postln;

    ~layers.configs.keysValuesDo { |layerName, config|
        if (config.bendControl.notNil) {
            "✓ Layer % has bend control configuration".format(layerName).postln;
            "  Enabled: %".format(config.bendControl.enabled).postln;
            "  Active synths: %".format(config.bendControl.activeBendSynths.size).postln;
        } {
            "✗ Layer % missing bend control configuration".format(layerName).postln;
        };
    };
} {
    "✗ Layers system not available".postln;
};

// Test 4: Check if GUI state includes bend mode
if (~layers.notNil and: { ~layers.state.notNil }) {
    "✓ Layers state available".postln;
    "  Bend mode: %".format(~layers.state.bendMode).postln;
} {
    "✗ Layers state not available".postln;
};

// Test 5: Check if bend envelope SynthDef is available
if (SynthDescLib.global[\BendEnvelope].notNil) {
    "✓ BendEnvelope SynthDef available".postln;
} {
    "⚠ BendEnvelope SynthDef not found - bend envelopes will be disabled".postln;
};

"Bend mode implementation test complete.".postln;
"Note: This test only checks function availability, not full functionality.".postln;
"To fully test, load the layers system and try playing with bend mode enabled.".postln;