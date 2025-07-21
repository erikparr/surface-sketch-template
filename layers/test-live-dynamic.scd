/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                         LIVE DYNAMIC MELODY TEST                              ║
║                 Test true live updates during playback                        ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

(
"=== Testing Live Dynamic Melody Updates ===".postln;

// Test 1: Check if new functions exist
"Checking dynamic melody functions...".postln;
"~getLayerMelodyDynamic exists: %".format(~getLayerMelodyDynamic.notNil).postln;
"~applyPendingUpdateForLayer exists: %".format(~applyPendingUpdateForLayer.notNil).postln;

// Test 2: Enable live melody mode
"Enabling live melody mode...".postln;
~enableLiveMelodyMode.();

// Test 3: Check status
"Live melody mode enabled: %".format(~layers.state.liveMelodyMode).postln;
"Pending updates dictionary: %".format(~layers.state.pendingUpdates.notNil).postln;

// Test 4: Create simple test melody for sending
~createTestMelody = {
    var testData = (
        notes: [
            (midi: 60, vel: 0.8, dur: 0.5),
            (midi: 62, vel: 0.7, dur: 0.5),
            (midi: 64, vel: 0.9, dur: 0.5)
        ]
    );
    testData
};

// Test 5: Send update during playback
~sendTestUpdate = { |layerName|
    var melodyData = ~createTestMelody.();
    "Sending test update to %...".format(layerName).postln;
    ~sendLiveMelodyUpdate.(layerName, melodyData);
};

// Test 6: Manual update test (without OSC)
~manualUpdateTest = { |layerName|
    var melodyData = ~createTestMelody.();
    var validatedData;
    
    "Testing manual update for %...".format(layerName).postln;
    
    // Validate data
    validatedData = ~validateLiveMelodyData.(melodyData);
    
    if (validatedData.notNil) {
        // Queue the update
        ~layers.state.pendingUpdates[layerName] = validatedData;
        "Update queued successfully for %".format(layerName).postln;
        
        // Test dynamic getter
        "Testing dynamic getter...".postln;
        var result = ~getLayerMelodyDynamic.(layerName);
        if (result.notNil) {
            "Dynamic getter returned melody: %".format(result.name ? "unnamed").postln;
        } {
            "Dynamic getter returned nil".postln;
        };
    } {
        "Validation failed".postln;
    };
};

// Test 7: Check if layers are ready for testing
"Checking layer system status...".postln;
if (~layers.notNil and: { ~layers.configs.notNil }) {
    "Layer configs available: %".format(~layers.configs.keys).postln;
    
    ~layers.configs.keysValuesDo { |layerName, config|
        "Layer %: enabled=%, melody=%".format(
            layerName, 
            config.enabled ? false,
            if (config.melodyList.notNil and: { config.melodyList.size > 0 }) {
                config.melodyList[0]
            } { "none" }
        ).postln;
    };
} {
    "Layer system not initialized".postln;
};

"=== Test Functions Created ===".postln;
"Run these to test:".postln;
"~manualUpdateTest.(\layer1);".postln;
"~sendTestUpdate.(\layer1);".postln;

// Test 8: Check if currently playing
if (~layers.parentProc.notNil and: { ~layers.parentProc.isRunning }) {
    "Layers are currently playing - ready for live updates!".postln;
} {
    "Layers are not playing - start them first with ~startLayers.()".postln;
};
)