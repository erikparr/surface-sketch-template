/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                   OSC LAYERS - EXTERNAL CONTROL DEMO                          ║
║                 Demonstrate external OSC control capabilities                 ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

"Loading External Control Demo...".postln;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                      EXTERNAL OSC SERVER SETUP                             │
// └─────────────────────────────────────────────────────────────────────────────┘

~setupExternalOSCControl = { |port = 7000|
    var externalAddr;

    "Setting up external OSC control on port %...".format(port).postln;

    // Open UDP port for external control
    thisProcess.openUDPPort(port);
    externalAddr = NetAddr("0.0.0.0", port);

    // External control responders
    ~externalOSCResponders = [
        // External system control with acknowledgment
        OSCFunc({|msg, time, addr|
            var duration = msg[1] ? 2.0;
            "EXTERNAL OSC: Start request from % (duration: %s)".format(addr.ip, duration).postln;

            // Start the system
            NetAddr.localAddr.sendMsg('/system/start', duration);

            // Send acknowledgment back to sender
            addr.sendMsg('/ack', '/external/start', 'started', duration);
        }, '/external/start'),

        OSCFunc({|msg, time, addr|
            "EXTERNAL OSC: Stop request from %".format(addr.ip).postln;

            // Stop the system
            NetAddr.localAddr.sendMsg('/system/stop');

            // Send acknowledgment
            addr.sendMsg('/ack', '/external/stop', 'stopped');
        }, '/external/stop'),

        // External layer control
        OSCFunc({|msg, time, addr|
            var layerNum = msg[1];
            var note = msg[2];
            var velocity = msg[3] ? 100;
            var duration = msg[4] ? 1.0;

            "EXTERNAL OSC: Layer % note % from %".format(layerNum, note, addr.ip).postln;

            // Send to layer
            NetAddr.localAddr.sendMsg('/layer' ++ layerNum ++ '/note', note, velocity, duration);

            // Send acknowledgment
            addr.sendMsg('/ack', '/external/note', layerNum, note, 'played');
        }, '/external/note'),

        // External melody updates
        OSCFunc({|msg, time, addr|
            var layerNum = msg[1];
            var melodyData = msg[2];

            "EXTERNAL OSC: Melody update for layer % from %".format(layerNum, addr.ip).postln;

            // Parse melody data (expecting array of MIDI notes)
            if (melodyData.isKindOf(Array)) {
                var melodyKey = ('external_' ++ Date.getDate.stamp).asSymbol;

                // Create melody entry
                if (~melodyDict.isNil) { ~melodyDict = Dictionary.new };
                ~melodyDict[melodyKey] = (
                    patterns: [melodyData],
                    velocities: melodyData.collect({ 100 }),
                    noteDurations: melodyData.collect({ 0.5 })
                );

                // Set melody for layer
                NetAddr.localAddr.sendMsg('/layer' ++ layerNum ++ '/melody', melodyKey);

                // Send acknowledgment
                addr.sendMsg('/ack', '/external/melody', layerNum, melodyData.size, 'updated');
            } {
                addr.sendMsg('/error', '/external/melody', 'invalid_format');
            };
        }, '/external/melody'),

        // External parameter control
        OSCFunc({|msg, time, addr|
            var layerNum = msg[1];
            var ccNum = msg[2];
            var value = msg[3];

            "EXTERNAL OSC: CC control layer % CC % = % from %".format(layerNum, ccNum, value, addr.ip).postln;

            // Send CC message
            NetAddr.localAddr.sendMsg('/layer' ++ layerNum ++ '/cc', ccNum, value);

            // Send acknowledgment
            addr.sendMsg('/ack', '/external/cc', layerNum, ccNum, value);
        }, '/external/cc'),

        // External system state queries
        OSCFunc({|msg, time, addr|
            var layerNum = msg[1];
            var config = ~oscLayers.configs[('layer' ++ layerNum).asSymbol];

            "EXTERNAL OSC: Status query for layer % from %".format(layerNum, addr.ip).postln;

            if (config.notNil) {
                addr.sendMsg('/status', layerNum,
                    config.enabled.asInteger,
                    config.vstGroup,
                    config.melodyList.size,
                    ~oscLayers.state.isRunning.asInteger
                );
            } {
                addr.sendMsg('/error', '/external/status', 'invalid_layer');
            };
        }, '/external/status')
    ];

    "External OSC control enabled on port %".format(port).postln;
    "Send OSC messages to this computer on port % to control layers".format(port).postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         DEMO SEQUENCES                                     │
// └─────────────────────────────────────────────────────────────────────────────┘

// Demo: Simulated external controller
~simulateExternalController = {
    var externalAddr = NetAddr("127.0.0.1", 57120); // Send to ourselves for demo

    "=== Simulating External Controller ===".postln;

    Task({
        // 1. Send external start command
        "1. External start...".postln;
        externalAddr.sendMsg('/external/start', 3.0);
        2.0.wait;

        // 2. Send individual notes from "external" source
        "2. External note control...".postln;
        [60, 62, 64, 67].do { |note, i|
            externalAddr.sendMsg('/external/note', 1, note, 100, 0.8);
            0.5.wait;
        };

        2.0.wait;

        // 3. Update melody externally
        "3. External melody update...".postln;
        externalAddr.sendMsg('/external/melody', 2, [72, 71, 69, 67, 65, 64, 62, 60]);
        1.0.wait;

        // 4. Start with new melody
        "4. External start with new melody...".postln;
        externalAddr.sendMsg('/external/start', 4.0);
        3.0.wait;

        // 5. External CC control
        "5. External CC control...".postln;
        10.do { |i|
            var ccValue = (i * 12).clip(0, 127);
            externalAddr.sendMsg('/external/cc', 1, 11, ccValue);
            0.2.wait;
        };

        1.0.wait;

        // 6. External stop
        "6. External stop...".postln;
        externalAddr.sendMsg('/external/stop');

        "=== External Controller Demo Complete ===".postln;
    }).play;
};

// Demo: DAW Integration example
~simulateDAWIntegration = {
    var dawAddr = NetAddr("127.0.0.1", 57120);

    "=== Simulating DAW Integration ===".postln;
    "Imagine this is Ableton Live sending transport and parameter data...".postln;

    Task({
        // DAW sends transport start
        "DAW: Transport start".postln;
        dawAddr.sendMsg('/external/start', 8.0);

        // DAW sends tempo-synced parameter automation
        32.do { |i|
            var phase = i / 32 * 2pi;
            var ccValue = (sin(phase) * 63 + 64).round;
            dawAddr.sendMsg('/external/cc', 1, 11, ccValue);
            0.25.wait; // 16th notes at 120 BPM
        };

        "DAW: Transport stop".postln;
        dawAddr.sendMsg('/external/stop');

        "=== DAW Integration Demo Complete ===".postln;
    }).play;
};

// Demo: Mobile app simulation
~simulateMobileApp = {
    var mobileAddr = NetAddr("127.0.0.1", 57120);

    "=== Simulating Mobile App Control ===".postln;
    "Imagine this is a phone app controlling the layers...".postln;

    Task({
        // App sends melody patterns
        "Mobile: Sending melody patterns...".postln;

        // Pattern 1 - ascending
        mobileAddr.sendMsg('/external/melody', 1, [60, 62, 64, 65, 67, 69, 71, 72]);
        0.5.wait;

        // Pattern 2 - arpeggios
        mobileAddr.sendMsg('/external/melody', 2, [60, 64, 67, 72, 67, 64]);
        0.5.wait;

        // Pattern 3 - descending
        mobileAddr.sendMsg('/external/melody', 3, [84, 81, 79, 77, 74, 72, 69, 67]);
        0.5.wait;

        // App starts performance
        "Mobile: Starting performance...".postln;
        mobileAddr.sendMsg('/external/start', 6.0);

        // App sends real-time expression control
        "Mobile: Real-time expression control...".postln;
        24.do { |i|
            var layer = (i % 3) + 1;
            var ccValue = [20, 40, 60, 80, 100, 120].choose;
            mobileAddr.sendMsg('/external/cc', layer, 11, ccValue);
            0.25.wait;
        };

        "Mobile: Performance complete".postln;
        mobileAddr.sendMsg('/external/stop');

        "=== Mobile App Demo Complete ===".postln;
    }).play;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         NETWORK DISCOVERY                                  │
// └─────────────────────────────────────────────────────────────────────────────┘

~announceOSCService = {
    "=== OSC Layers Network Service ===".postln;
    "Available for external control at:".postln;
    "  IP: % (all interfaces)".format("0.0.0.0").postln;
    "  Port: 7000".postln;
    "\nExternal OSC Commands:".postln;
    "  /external/start <duration>".postln;
    "  /external/stop".postln;
    "  /external/note <layer> <note> <velocity> <duration>".postln;
    "  /external/melody <layer> [note1, note2, ...]".postln;
    "  /external/cc <layer> <ccNum> <value>".postln;
    "  /external/status <layer>".postln;
    "\nAll commands return acknowledgments to sender".postln;
    "=================================".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         MAIN DEMO FUNCTION                                 │
// └─────────────────────────────────────────────────────────────────────────────┘

~runExternalControlDemo = {
    "=== External Control Demo ===".postln;
    "\nAvailable demos:".postln;
    "  ~simulateExternalController.() - General external control".postln;
    "  ~simulateDAWIntegration.()     - DAW transport & automation".postln;
    "  ~simulateMobileApp.()          - Mobile app-style control".postln;
    "\nSetup functions:".postln;
    "  ~setupExternalOSCControl.()    - Enable external control".postln;
    "  ~announceOSCService.()         - Show network info".postln;
    "\nTo enable external control from other devices:".postln;
    "  1. Run ~setupExternalOSCControl.()".postln;
    "  2. Send OSC to this computer's IP on port 7000".postln;
    "  3. Use /external/* commands for control".postln;
    "===========================".postln;
};

// Auto-setup if OSC layers system is loaded
if (~oscLayers.notNil) {
    ~setupExternalOSCControl.();
    ~runExternalControlDemo.();
} {
    "External control demo loaded. Load OSC layers system first:".postln;
    "(thisProcess.nowExecutingPath.dirname +/+ \"load-layers-osc.scd\").load;".postln;
};

"External Control Demo ready".postln;