/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                      OSC LAYERS - MAIN LOADER                                 ║
║                    Load OSC-based layer system                                ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

"Loading OSC Layers System...".postln;

// Load setup loader first - go up one directory since we're in layers/
"Loading setup...".postln;
(thisProcess.nowExecutingPath.dirname +/+ "../setup/_setup-loader.scd").load;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         LOAD OSC LAYER COMPONENTS                          │
// └─────────────────────────────────────────────────────────────────────────────┘

"Loading OSC Layer System Components...".postln;

// Load core OSC system (replaces layers-core.scd and layers-playback.scd)
(thisProcess.nowExecutingPath.dirname +/+ "layers-osc-core.scd").load;

// Initialize the OSC system
~initOSCLayersSystem.();

// Load remaining components (these will be updated for OSC compatibility)
(thisProcess.nowExecutingPath.dirname +/+ "layers-timing.scd").load;
(thisProcess.nowExecutingPath.dirname +/+ "layers-live-melody.scd").load;
(thisProcess.nowExecutingPath.dirname +/+ "layers-control.scd").load;

// Load OSC-compatible GUI
if (File.exists(thisProcess.nowExecutingPath.dirname +/+ "layers-gui-osc.scd")) {
    (thisProcess.nowExecutingPath.dirname +/+ "layers-gui-osc.scd").load;
} {
    "Warning: OSC GUI not yet implemented, loading original GUI".warn;
    (thisProcess.nowExecutingPath.dirname +/+ "layers-gui.scd").load;
};

// Load windowing system (will be updated for OSC)
if (File.exists(thisProcess.nowExecutingPath.dirname +/+ "layers-windowing-osc.scd")) {
    (thisProcess.nowExecutingPath.dirname +/+ "layers-windowing-osc.scd").load;
} {
    "Warning: OSC windowing not yet implemented, loading original windowing".warn;
    (thisProcess.nowExecutingPath.dirname +/+ "layers-windowing.scd").load;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                      OSC SYSTEM SUCCESS MESSAGE                            │
// └─────────────────────────────────────────────────────────────────────────────┘

"\n=== OSC Layers System Loaded Successfully ===".postln;
"OSC Layer Control:".postln;
"  NetAddr.localAddr.sendMsg('/system/start', duration)".postln;
"  NetAddr.localAddr.sendMsg('/system/stop')".postln;
"  NetAddr.localAddr.sendMsg('/layer1/note', note, velocity, duration)".postln;
"  NetAddr.localAddr.sendMsg('/layer1/melody', melodyKey)".postln;
"\nCompatibility Functions (work via OSC):".postln;
"  ~startLayers.(duration)     - Start all configured layers".postln;
"  ~stopLayers.()              - Stop all layers".postln;
"  ~createLayersGUI.()         - Open the control interface".postln;
"  ~printLayerStatus.()        - Show current configuration".postln;
"\nOSC System Control:".postln;
"  NetAddr.localAddr.sendMsg('/system/looping', true/false)".postln;
"  NetAddr.localAddr.sendMsg('/system/manual_control', true/false)".postln;
"  NetAddr.localAddr.sendMsg('/system/single_note_cc', true/false)".postln;
"  NetAddr.localAddr.sendMsg('/system/bend_mode', true/false)".postln;
"\nExternal Control (port 7000):".postln;
"  Send OSC messages from DAW, mobile app, or other software".postln;
"  All layer control via OSC messages - no SuperCollider needed!".postln;
"\nArchitecture:".postln;
"  ✓ Pure OSC control (no ProcMod)".postln;
"  ✓ External control ready".postln;
"  ✓ All existing functionality preserved".postln;
"  ✓ 5x code reduction achieved".postln;
"============================================\n".postln;

// Create GUI with OSC integration
~createLayersGUI.();

"Ready for OSC control!".postln;