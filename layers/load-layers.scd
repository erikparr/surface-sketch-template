/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                      DEPENDENT LAYERS - MAIN LOADER                           ║
║                         Load all layer components                             ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// Load setup loader first - go up one directory since we're in surfacing-core/
"Loading setup...".postln;
(thisProcess.nowExecutingPath.dirname +/+ "../setup/_setup-loader.scd").load;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         LOAD LAYER COMPONENTS                              │
// └─────────────────────────────────────────────────────────────────────────────┘

"Loading Dependent Layer System...".postln;

// Load components in order
(thisProcess.nowExecutingPath.dirname +/+ "layers-core.scd").load;

// Initialize the system immediately after core is loaded
~initializeLayers.();

(thisProcess.nowExecutingPath.dirname +/+ "layers-playback.scd").load;

(thisProcess.nowExecutingPath.dirname +/+ "layers-timing.scd").load;

(thisProcess.nowExecutingPath.dirname +/+ "layers-control.scd").load;

(thisProcess.nowExecutingPath.dirname +/+ "layers-gui.scd").load;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                           SUCCESS MESSAGE                                  │
// └─────────────────────────────────────────────────────────────────────────────┘

"\n=== Dependent Layer System Loaded Successfully ===".postln;
"Available functions:".postln;
"  ~createLayersGUI.()     - Open the control interface".postln;
"  ~startLayers.()         - Start all configured layers".postln;
"  ~stopLayers.()          - Stop all layers".postln;
"  ~printLayerStatus.()    - Show current configuration".postln;
"\nTiming data support:".postln;
"  ~importLayerMelodyFromJSON.(jsonPath) - Import melodies with timing".postln;
"  ~createTimingTestMelody.()            - Create test melody with timing".postln;
"\nQuick start:".postln;
"  ~setLayerMelody.(\\layer1, \\yourMelody)".postln;
"  ~setLayerMelody.(\\layer2, \\anotherMelody)".postln;
"  ~startLayers.()".postln;
"===============================================\n".postln;

// Create GUI immediately
~createLayersGUI.();

