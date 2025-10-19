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

(thisProcess.nowExecutingPath.dirname +/+ "layers-control.scd").load;

// Load timing controller system
(thisProcess.nowExecutingPath.dirname +/+ "layers-timing-controller.scd").load;

// GUI removed - system controlled via OSC only
// (thisProcess.nowExecutingPath.dirname +/+ "layers-gui-osc.scd").load;
// (thisProcess.nowExecutingPath.dirname +/+ "layers-timing-gui.scd").load;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                        OSC SYSTEM SUCCESS MESSAGE                          │
// └─────────────────────────────────────────────────────────────────────────────┘

"\n=== OSC Layers System Loaded Successfully ===".postln;
"✓ Pure OSC control architecture".postln;
"✓ External control ready on port 7000".postln;
"✓ Dynamic layers system will initialize when VST groups are ready".postln;
"\nPRIMARY EXTERNAL CONTROL:".postln;
"  Send melody JSON to /melody with metadata.targetGroup index".postln;
"  Port 7000 for incoming, Port 7001 for /melody/complete notifications".postln;
"  Example: NetAddr(\"127.0.0.1\", 7000).sendMsg('/melody', jsonString)".postln;
"\nOSC Control (Advanced):".postln;
"  /system/start, /system/stop - System control".postln;
"  /group/<name>/note - Direct note triggering".postln;
"  /group/<name>/melody - Assign melody by key".postln;
"\nDynamic Layers Functions:".postln;
"  ~initDynamicLayersSystem.()          - Initialize dynamic layers".postln;
"  ~startDynamicGroupPlayback.(group)   - Start single group".postln;
"  ~startAllDynamicGroups.(duration)    - Start all groups".postln;
"\nMIDI Control:".postln;
"  Row 1 Knob 8: BPM (60-400)".postln;
"  Row 1 Knob 3: Note velocity".postln;
"  Row 1 Knob 2: Note duration scalar".postln;
"  Slider 2: Melody rest time (0-1s)".postln;
"=============================================\n".postln;

// External control is now automatically enabled during OSC system initialization
// GUI removed - control via OSC only

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                    INITIALIZE DYNAMIC LAYERS SYSTEM                        │
// └─────────────────────────────────────────────────────────────────────────────┘

// Wait for VST setup to complete, then initialize dynamic layers
{
	// Wait 7 seconds for setup files and VST configuration to complete
	7.wait;

	// Initialize dynamic layers system if VST groups exist
	if (~initDynamicLayersSystem.notNil) {
		if (~vstManager.notNil and: { ~vstManager.getGroupNames().size > 0 }) {
			"Initializing Dynamic Layers System...".postln;
			~initDynamicLayersSystem.();
		} {
			"Warning: VST groups not ready yet, deferring dynamic layers initialization".warn;
			// Try again after another delay
			{
				2.wait;
				if (~vstManager.notNil and: { ~vstManager.getGroupNames().size > 0 }) {
					"Initializing Dynamic Layers System (delayed)...".postln;
					~initDynamicLayersSystem.();
				} {
					"ERROR: VST groups still not available for dynamic layers".error;
				};
			}.fork;
		};
	} {
		// Function not loaded yet - this is expected during initial startup
		"Dynamic layers system will be initialized once all components are loaded".postln;
	};
}.fork;

