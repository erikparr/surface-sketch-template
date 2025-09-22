/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                      DEPENDENT LAYERS - MAIN LOADER                           ║
║                    Load OSC-based layer system (default)                      ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// Load setup loader first - go up one directory since we're in surfacing-core/
"Loading setup...".postln;
(thisProcess.nowExecutingPath.dirname +/+ "../setup/_setup-loader.scd").load;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         LOAD OSC LAYER SYSTEM                              │
// └─────────────────────────────────────────────────────────────────────────────┘

"Loading OSC Layer System (default)...".postln;

// Load core OSC system (replaces layers-core.scd and layers-playback.scd)
(thisProcess.nowExecutingPath.dirname +/+ "layers-osc-core.scd").load;

// Initialize the OSC system
~initOSCLayersSystem.();

// Load remaining components (compatible with OSC system)
(thisProcess.nowExecutingPath.dirname +/+ "layers-timing.scd").load;

(thisProcess.nowExecutingPath.dirname +/+ "layers-live-melody.scd").load;

(thisProcess.nowExecutingPath.dirname +/+ "layers-control.scd").load;

// Load timing controller system
(thisProcess.nowExecutingPath.dirname +/+ "layers-timing-controller.scd").load;

// Load OSC-compatible GUI
(thisProcess.nowExecutingPath.dirname +/+ "layers-gui-osc.scd").load;

// Load timing controller GUI
(thisProcess.nowExecutingPath.dirname +/+ "layers-timing-gui.scd").load;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                        OSC SYSTEM SUCCESS MESSAGE                          │
// └─────────────────────────────────────────────────────────────────────────────┘

"\n=== OSC Layers System Loaded Successfully ===".postln;
"✓ Pure OSC control architecture".postln;
"✓ External control ready on port 7000".postln;
"✓ All existing functionality preserved".postln;
"\nGUI Control (same interface):".postln;
"  ~createLayersGUI.()     - Open the control interface".postln;
"\nCompatible Functions (now via OSC):".postln;
"  ~startLayers.(duration) - Start all configured layers".postln;
"  ~stopLayers.()          - Stop all layers".postln;
"  ~printLayerStatus.()    - Show current configuration".postln;
"\nDirect OSC Control:".postln;
"  NetAddr.localAddr.sendMsg('/system/start', duration)".postln;
"  NetAddr.localAddr.sendMsg('/system/stop')".postln;
"  NetAddr.localAddr.sendMsg('/layer1/note', note, velocity, duration)".postln;
"  NetAddr.localAddr.sendMsg('/layer1/melody', melodyKey)".postln;
"\nExternal Control (from DAW/mobile apps):".postln;
"  Send OSC to this computer's IP on port 7000".postln;
"  Use /external/start, /external/stop, /external/note commands".postln;
"\nTiming & Advanced Features:".postln;
"  ~importLayerMelodyFromJSON.(jsonPath) - Import melodies with timing".postln;
"  ~setLayerWindowing.(\\layer1, true)    - Enable windowing".postln;
"  ~enableLiveMelodyMode.()              - Enable live OSC updates".postln;
"\nNEW: Layer Timing Controller:".postln;
"  Sequential mode with MIDI control (Row 1 Knobs 1&2)".postln;
"  ~setTimingPreset.(\\medium)           - Quick timing presets".postln;
"  ~getTimingControlStatus.()           - Show timing status".postln;
"  Real-time GUI visualization automatically loaded".postln;
"\nQuick start (same as before):".postln;
"  ~setLayerMelody.(\\layer1, \\yourMelody)".postln;
"  ~setLayerMelody.(\\layer2, \\anotherMelody)".postln;
"  ~startLayers.()   // Now powered by OSC!".postln;
"=============================================\n".postln;

// External control is now automatically enabled during OSC system initialization

// Timing controller now integrated directly (no initialization needed)

// Create GUI immediately (now OSC-powered)
~createLayersGUI.();

// Timing controller GUI removed - using direct MIDI knob control only

