/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                         LIVE MELODY MODE TEST FILE                            ║
║                   Test scenarios for live melody updates                       ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

(
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                           TEST SETUP                                        │
// └─────────────────────────────────────────────────────────────────────────────┘

"=== Live Melody Mode Test Suite ===".postln;

// Ensure layers system is loaded
if (~layers.isNil) {
    "ERROR: Layers system not loaded. Please load layers first:".error;
    "(thisProcess.nowExecutingPath.dirname +/+ \"layers/load-layers.scd\").load;".postln;
} {
    "Layers system detected. Starting tests...".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                        TEST MELODY DATA                                     │
// └─────────────────────────────────────────────────────────────────────────────┘

// Test 1: Simple melody without timing
~testMelody1 = (
    notes: [
        (midi: 60, vel: 0.8, dur: 0.3),
        (midi: 62, vel: 0.7, dur: 0.3),
        (midi: 64, vel: 0.6, dur: 0.3),
        (midi: 65, vel: 0.9, dur: 0.5)
    ]
);

// Test 2: Melody with even timing
~testMelody2 = (
    notes: [
        (midi: 67, vel: 0.9, dur: 0.4),
        (midi: 65, vel: 0.8, dur: 0.4),
        (midi: 64, vel: 0.7, dur: 0.4)
    ],
    timing: [0.25, 0.25, 0.25, 0.25]  // Equal spacing
);

// Test 3: Melody with uneven timing
~testMelody3 = (
    notes: [
        (midi: 72, vel: 1.0, dur: 0.2),
        (midi: 71, vel: 0.8, dur: 0.2),
        (midi: 69, vel: 0.6, dur: 0.2),
        (midi: 67, vel: 0.4, dur: 0.8)
    ],
    timing: [0.1, 0.1, 0.2, 0.5, 0.1],  // Accelerando then long note
    metadata: (
        durationType: "absolute",
        key: "C",
        scale: "major"
    )
);

// Test 4: Melody with expression override
~testMelody4 = (
    notes: [
        (midi: 48, vel: 0.5, dur: 1.0),
        (midi: 50, vel: 0.6, dur: 1.0)
    ],
    timing: [0.2, 0.4, 0.4],
    expressionOverride: (
        expressionMin: 30,
        expressionMax: 90,
        expressionDurationScalar: 0.5
    )
);

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         TEST FUNCTIONS                                      │
// └─────────────────────────────────────────────────────────────────────────────┘

// Function to setup a basic test scenario
~setupLiveMelodyTest = {
    fork {
        "\n--- Setting up live melody test ---".postln;
        
        // Set up some initial melodies
        ~setLayerMelody.(\layer1, \melody1);
        ~setLayerMelody.(\layer2, \melody2);
        ~setLayerMelody.(\layer3, \melody3);
        
        // Enable looping mode
        ~layers.state.loopingMode = true;
        
        // Start layers
        ~startLayers.(4.0);  // 4 second loops
        
        2.wait;  // Let it play for a bit
        
        // Enable live melody mode
        ~enableLiveMelodyMode.();
        
        "Test setup complete. Layers are playing in loop mode.".postln;
    };
};

// Function to send test updates
~sendTestUpdates = {
    fork {
        "\n--- Sending test melody updates ---".postln;
        
        // Update layer 1
        ~sendLiveMelodyUpdate.(\layer1, ~testMelody1);
        "Sent update 1 to layer1 (simple melody)".postln;
        
        2.wait;
        
        // Update layer 2
        ~sendLiveMelodyUpdate.(\layer2, ~testMelody2);
        "Sent update 2 to layer2 (even timing)".postln;
        
        2.wait;
        
        // Update layer 3
        ~sendLiveMelodyUpdate.(\layer3, ~testMelody3);
        "Sent update 3 to layer3 (uneven timing)".postln;
        
        2.wait;
        
        // Update layer 1 again with expression
        ~sendLiveMelodyUpdate.(\layer1, ~testMelody4);
        "Sent update 4 to layer1 (with expression override)".postln;
    };
};

// Function to test error handling
~testErrorHandling = {
    fork {
        "\n--- Testing error handling ---".postln;
        
        // Test 1: Invalid JSON
        NetAddr("127.0.0.1", 57120).sendMsg('/liveMelody/update/layer1', "not valid json");
        "Sent invalid JSON".postln;
        
        0.5.wait;
        
        // Test 2: Missing notes field
        ~sendLiveMelodyUpdate.(\layer2, (timing: [0.5, 0.5]));
        "Sent data missing notes field".postln;
        
        0.5.wait;
        
        // Test 3: Invalid MIDI note
        ~sendLiveMelodyUpdate.(\layer3, (
            notes: [(midi: 200, vel: 0.5, dur: 0.5)]  // MIDI > 127
        ));
        "Sent invalid MIDI note".postln;
        
        0.5.wait;
        
        // Test 4: Invalid timing sum
        ~sendLiveMelodyUpdate.(\layer1, (
            notes: [(midi: 60, vel: 0.5, dur: 0.5)],
            timing: [0.3, 0.3]  // Doesn't sum to 1.0
        ));
        "Sent invalid timing sum".postln;
    };
};

// Function to test rapid updates
~testRapidUpdates = {
    fork {
        "\n--- Testing rapid updates ---".postln;
        
        10.do { |i|
            var note = 60 + (i * 2);
            ~sendLiveMelodyUpdate.(\layer1, (
                notes: [
                    (midi: note, vel: 0.8, dur: 0.2),
                    (midi: note + 1, vel: 0.6, dur: 0.2)
                ]
            ));
            "Rapid update % sent".format(i + 1).postln;
            0.2.wait;
        };
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                      INTERACTIVE TEST MENU                                  │
// └─────────────────────────────────────────────────────────────────────────────┘

~runLiveMelodyTests = {
    "\n=== Live Melody Test Menu ===".postln;
    "1. Run full test suite".postln;
    "2. Setup and start layers".postln;
    "3. Send test updates".postln;
    "4. Test error handling".postln;
    "5. Test rapid updates".postln;
    "6. Check status".postln;
    "7. Stop and cleanup".postln;
    "\nRun individual tests with:".postln;
    "  ~setupLiveMelodyTest.()".postln;
    "  ~sendTestUpdates.()".postln;
    "  ~testErrorHandling.()".postln;
    "  ~testRapidUpdates.()".postln;
};

// Full test suite
~runFullTestSuite = {
    fork {
        "Starting full test suite...".postln;
        
        ~setupLiveMelodyTest.();
        4.wait;
        
        ~sendTestUpdates.();
        8.wait;
        
        ~testErrorHandling.();
        3.wait;
        
        ~testRapidUpdates.();
        4.wait;
        
        // Check final status
        "Final status:".postln;
        ~getLiveMelodyStatus.().postln;
        
        2.wait;
        
        // Cleanup
        ~stopLayers.();
        ~disableLiveMelodyMode.();
        
        "\nTest suite complete!".postln;
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                    EXTERNAL APPLICATION EXAMPLE                             │
// └─────────────────────────────────────────────────────────────────────────────┘

~pythonExample = {
    "\n=== Python Example Code ===".postln;
    "Save this as 'send_melody.py' and run with Python 3:".postln;
    "\n".postln;
    
    "from pythonosc import udp_client
import json
import time

# Create OSC client
client = udp_client.SimpleUDPClient(\"127.0.0.1\", 57120)

# Define melody
melody = {
    \"notes\": [
        {\"midi\": 60, \"vel\": 0.8, \"dur\": 0.5},
        {\"midi\": 62, \"vel\": 0.7, \"dur\": 0.5},
        {\"midi\": 64, \"vel\": 0.9, \"dur\": 0.5}
    ],
    \"timing\": [0.1, 0.3, 0.3, 0.3],
    \"metadata\": {
        \"key\": \"C\",
        \"scale\": \"major\"
    }
}

# Send to layer1
client.send_message(\"/liveMelody/update/layer1\", json.dumps(melody))
print(\"Melody sent to layer1\")

# Send variations to other layers
for i, layer in enumerate([\"layer2\", \"layer3\"]):
    # Transpose melody
    transposed = melody.copy()
    transposed[\"notes\"] = [
        {\"midi\": n[\"midi\"] + (i+1)*2, \"vel\": n[\"vel\"], \"dur\": n[\"dur\"]}
        for n in melody[\"notes\"]
    ]
    
    client.send_message(f\"/liveMelody/update/{layer}\", json.dumps(transposed))
    print(f\"Transposed melody sent to {layer}\")
    time.sleep(0.5)
".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         PRINT INSTRUCTIONS                                  │
// └─────────────────────────────────────────────────────────────────────────────┘

"\n=== Live Melody Mode Tests Loaded ===".postln;
"Run ~runLiveMelodyTests.() to see test menu".postln;
"Run ~runFullTestSuite.() to run all tests automatically".postln;
"Run ~pythonExample.() to see external application example".postln;
"\nMake sure layers are loaded before running tests!".postln;

);