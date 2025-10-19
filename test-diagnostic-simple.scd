/*
═══════════════════════════════════════════════════════════════
  MIDI PARAMETER SCALING DIAGNOSTIC
═══════════════════════════════════════════════════════════════
*/

(
"═══════════════════════════════════════════════════════════════".postln;
"  MIDI PARAMETER SCALING DIAGNOSTIC".postln;
"═══════════════════════════════════════════════════════════════".postln;
"".postln;

// Test 1: What does getKnobRow return?
"► TEST 1: Raw getKnobRow() Return Values".postln;
{
    var val5, val6, class5, class6;
    
    val5 = ~midiController.getKnobRow(1, 5);
    val6 = ~midiController.getKnobRow(1, 6);
    class5 = val5.class;
    class6 = val6.class;
    
    "  Row 1 Knob 5 raw value: % (class: %)".format(val5, class5).postln;
    "  Row 1 Knob 6 raw value: % (class: %)".format(val6, class6).postln;
    
    // Range detection
    if (val5 > 1.0 or: { val6 > 1.0 }) {
        "  ⚠ Values > 1.0 detected - appears to be CC range (0-127)".postln;
        "  → Scaling by 127 will cause overflow!".postln;
    } {
        "  ✓ Values ≤ 1.0 - appears to be normalized (0.0-1.0)".postln;
        "  → Scaling by 127 should work".postln;
    };
}.value;
"".postln;

// Test 2: Check if using ParameterRegistry
"► TEST 2: Parameter Registry Integration".postln;
{
    var usingRegistry;
    usingRegistry = ~midiController.oscEnabled and: { ~midiController.parameterRegistry.notNil };
    
    "  OSC Enabled: %".format(~midiController.oscEnabled).postln;
    "  Parameter Registry: %".format(~midiController.parameterRegistry.notNil).postln;
    "  Using Registry: %".format(usingRegistry).postln;
    
    if (usingRegistry) {
        "  → getKnobRow() uses ParameterRegistry (returns normalized)".postln;
    } {
        "  → getKnobRow() uses direct CC (returns 0-127)".postln;
    };
}.value;
"".postln;

// Test 3: Current config values
"► TEST 3: Current Expression Parameters".postln;
{
    var config;
    config = ~oscLayers.dynamicConfigs['chordGroup1'];
    if (config.notNil) {
        "  Expression Min: %".format(config.ccControl.expressionMin).postln;
        "  Expression Max: %".format(config.ccControl.expressionMax).postln;
        
        if (config.ccControl.expressionMax > 127) {
            "  ✗ OVERFLOW DETECTED: Max > 127".error;
        } {
            "  ✓ Values in valid range".postln;
        };
    };
}.value;
"".postln;

// Test 4: Manual update test
"► TEST 4: Manual Parameter Update Test".postln;
"  Calling ~updateLayerExpressionParams.('chordGroup1')...".postln;
~updateLayerExpressionParams.('chordGroup1');
{
    var config;
    config = ~oscLayers.dynamicConfigs['chordGroup1'];
    "  After update:".postln;
    "    Min: %".format(config.ccControl.expressionMin).postln;
    "    Max: %".format(config.ccControl.expressionMax).postln;
}.value;
"".postln;

"═══════════════════════════════════════════════════════════════".postln;
"  RECOMMENDATION".postln;
"═══════════════════════════════════════════════════════════════".postln;
"".postln;
"  Based on results above, apply appropriate fix:".postln;
"  1. If values > 1.0: Remove *127 scaling (already in CC range)".postln;
"  2. If values ≤ 1.0: Keep *127 scaling (normalized range)".postln;
"  3. If mixed: Add conditional logic to handle both cases".postln;
"".postln;
)
