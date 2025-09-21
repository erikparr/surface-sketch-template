/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                        OSC LAYERS - TEST SCRIPT                               ║
║                      Test the OSC layers system                               ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

"Testing OSC Layers System...".postln;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         BASIC SYSTEM TEST                                  │
// └─────────────────────────────────────────────────────────────────────────────┘

~testOSCLayers = {
    "=== OSC Layers System Test ===".postln;

    // Test 1: Check if OSC system is loaded
    if (~oscLayers.isNil) {
        "ERROR: OSC layers system not loaded!".postln;
        ^false;
    };

    "✓ OSC layers system loaded".postln;

    // Test 2: Check coordinator
    if (~oscLayers.coordinator.isNil) {
        "ERROR: OSC coordinator not created!".postln;
        ^false;
    };

    "✓ OSC coordinator created".postln;

    // Test 3: Check layer configs
    [\layer1, \layer2, \layer3].do { |layerKey|
        if (~oscLayers.configs[layerKey].isNil) {
            "ERROR: Layer % config missing!".format(layerKey).postln;
            ^false;
        };
    };

    "✓ All layer configs present".postln;

    // Test 4: Check OSC responders
    [\layer1, \layer2, \layer3].do { |layerKey|
        if (~oscLayers.responders[layerKey].isNil) {
            "WARNING: Layer % OSC responders not found".format(layerKey).postln;
        };
    };

    if (~oscLayers.responders[\system].isNil) {
        "WARNING: System OSC responders not found".postln;
    };

    "✓ OSC responders checked".postln;

    // Test 5: Check compatibility functions
    if (~startLayers.isNil) {
        "ERROR: ~startLayers function missing!".postln;
        ^false;
    };

    if (~stopLayers.isNil) {
        "ERROR: ~stopLayers function missing!".postln;
        ^false;
    };

    "✓ Compatibility functions present".postln;

    "=== All Tests Passed ===".postln;
    true;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         INDIVIDUAL LAYER TEST                              │
// └─────────────────────────────────────────────────────────────────────────────┘

~testIndividualLayer = { |layerNum|
    layerNum = layerNum ? 1;

    "Testing individual layer %...".format(layerNum).postln;

    // Test single note
    "Sending test note to layer %...".format(layerNum).postln;
    NetAddr.localAddr.sendMsg('/layer' ++ layerNum ++ '/note', 60, 100, 1.0);

    "Test note sent to layer %".format(layerNum).postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         SYSTEM CONTROL TEST                                │
// └─────────────────────────────────────────────────────────────────────────────┘

~testSystemControl = {
    "Testing system control...".postln;

    // Test looping mode
    "Setting looping mode...".postln;
    NetAddr.localAddr.sendMsg('/system/looping', true);
    0.1.wait;
    NetAddr.localAddr.sendMsg('/system/looping', false);

    // Test manual control
    "Setting manual control...".postln;
    NetAddr.localAddr.sendMsg('/system/manual_control', true);
    0.1.wait;
    NetAddr.localAddr.sendMsg('/system/manual_control', false);

    // Test bend mode
    "Setting bend mode...".postln;
    NetAddr.localAddr.sendMsg('/system/bend_mode', true);
    0.1.wait;
    NetAddr.localAddr.sendMsg('/system/bend_mode', false);

    "System control test complete".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         FULL SYSTEM TEST                                   │
// └─────────────────────────────────────────────────────────────────────────────┘

~testFullSystem = {
    var testMelody = [60, 62, 64, 65, 67, 69, 71, 72];

    "=== Full System Test ===".postln;

    // Create a test melody if needed
    if (~melodyDict.isNil) {
        ~melodyDict = Dictionary.new;
    };

    if (~melodyDict[\testMelody].isNil) {
        ~melodyDict[\testMelody] = (
            patterns: [testMelody],
            velocities: testMelody.collect({ 100 }),
            noteDurations: testMelody.collect({ 0.5 })
        );
        "Created test melody".postln;
    };

    // Set test melody on layer 1
    "Setting test melody on layer 1...".postln;
    NetAddr.localAddr.sendMsg('/layer1/melody', \testMelody);

    // Enable layer 1
    "Enabling layer 1...".postln;
    NetAddr.localAddr.sendMsg('/layer1/enabled', true);

    // Start system for 4 seconds
    "Starting system for 4 seconds...".postln;
    NetAddr.localAddr.sendMsg('/system/start', 4.0);

    // Schedule stop after 5 seconds
    SystemClock.sched(5.0, {
        "Stopping system...".postln;
        NetAddr.localAddr.sendMsg('/system/stop');
        "Full system test complete".postln;
    });

    "Full system test initiated".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         DEMO SCRIPT                                        │
// └─────────────────────────────────────────────────────────────────────────────┘

~demoOSCLayers = {
    "=== OSC Layers Demo ===".postln;
    "\nAvailable test functions:".postln;
    "  ~testOSCLayers.()           - Basic system test".postln;
    "  ~testIndividualLayer.(1)    - Test single layer".postln;
    "  ~testSystemControl.()       - Test system controls".postln;
    "  ~testFullSystem.()          - Full system demo".postln;
    "\nDirect OSC control:".postln;
    "  NetAddr.localAddr.sendMsg('/layer1/note', 60, 100, 1.0)".postln;
    "  NetAddr.localAddr.sendMsg('/system/start', 4.0)".postln;
    "  NetAddr.localAddr.sendMsg('/system/stop')".postln;
    "\nCompatibility functions:".postln;
    "  ~startLayers.(4.0)          - Start via compatibility layer".postln;
    "  ~stopLayers.()              - Stop via compatibility layer".postln;
    "========================".postln;
};

// Auto-run basic test
if (~oscLayers.notNil) {
    ~testOSCLayers.();
    ~demoOSCLayers.();
} {
    "OSC Layers system not loaded. Please load first:".postln;
    "(thisProcess.nowExecutingPath.dirname +/+ \"load-layers-osc.scd\").load;".postln;
};

"OSC Layers test script loaded".postln;