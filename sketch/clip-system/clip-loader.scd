/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                             CLIP SYSTEM LOADER                               ║
║                             Main entry point for                             ║
║                             clip timing playback                             ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                           SYSTEM INFORMATION                               │
// └─────────────────────────────────────────────────────────────────────────────┘

"
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                         CLIP SYSTEM LOADING                                  ║
║                         Phase 2: Clip Playback                               ║
║                                                                               ║
║  Integrates recorded MIDI timing data with existing ProcMod system           ║
║  Preserves expressive timing while enabling real-time tempo scaling          ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
".postln;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                            LOAD DEPENDENCIES                               │
// └─────────────────────────────────────────────────────────────────────────────┘

// Get the directory path for clip system files
~clipSystemDir = thisProcess.nowExecutingPath.dirname;

"Loading clip system from: %".format(~clipSystemDir).postln;

// Load core clip system files in dependency order
"[1/4] Loading core clip playback...".postln;
(~clipSystemDir +/+ "clip-playback.scd").load;

"[2/4] Loading ProcMod integration...".postln;
(~clipSystemDir +/+ "clip-procmod.scd").load;

"[3/4] Loading system integration...".postln;
(~clipSystemDir +/+ "clip-integration.scd").load;

"[4/5] Loading control system...".postln;
(~clipSystemDir +/+ "clip-controls.scd").load;

"[5/6] Loading file management...".postln;
(~clipSystemDir +/+ "clip-filemanager.scd").load;

"[6/6] Loading clip management GUI...".postln;
(~clipSystemDir +/+ "../../setup/clip-management.scd").load;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                           SYSTEM INITIALIZATION                            │
// └─────────────────────────────────────────────────────────────────────────────┘

"[7/7] Loading clip initialization...".postln;
(~clipSystemDir +/+ "clip-initialization.scd").load;

// Initialize clip system - synchronous like sketch system
"Initializing clip system...".postln;

// Set safety flag to prevent infinite loops during loading
~clipSystemLoading = true;

// Initialize MIDI controls
~initializeClipControls.();

// Initialize file management
~initializeClipFileManager.();

// Initialize the core clip system (ProcMods, etc.)
~initializeClipSystem.();

// Clear safety flag
~clipSystemLoading = false;

// Create GUI
if (~createClipManagerGUI.notNil) {
    "Opening Clip Management GUI...".postln;
    ~createClipManagerGUI.();
} {
    "WARNING: ~createClipManagerGUI function not available".postln;
};

"Clip system initialization complete".postln;

// Show status
~showClipControlStatus.();
~showActiveClips.();

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                            USAGE FUNCTIONS                                 │
// └─────────────────────────────────────────────────────────────────────────────┘

// Quick status check
~clipStatus = {
    "=== CLIP SYSTEM STATUS ===".postln;
    ~showClipControlStatus.();
    ~showActiveClips.();
    ~showSequenceWithClips.();
    
    // Check VST system integration
    "=== VST INTEGRATION STATUS ===".postln;
    if (~vstManager.isNil) {
        "❌ ~vstManager not found - sketch system not loaded".postln;
        "   → Load sketch system first: \"sketch/load-sketch.scd\".load".postln;
    } {
        var instances = ~vstManager.getTargetInstances(~activeVSTGroup);
        "✅ VST Manager active".postln;
        "🎯 Active VST Group: %".format(~activeVSTGroup ? "ALL").postln;
        "🎹 Available VST Instances: % (%Total)".format(instances.keys.asArray, instances.size).postln;
        
        if (instances.size == 0) {
            "⚠️  No VST instances available for current target".postln;
            "   → Try: ~setActiveVSTGroup.('Bass Tuba') or ~useAllVSTs.()".postln;
        };
    };
    
    if (OSCdef(\noteOn).isNil) {
        "❌ OSC responder /note/on not active".postln;
        "   → Load control-systems.scd from sketch system".postln;
    } {
        "✅ OSC responder active: /note/on".postln;
    };
    "===============================".postln;
};

// Quick clip playback test
~testClipPlayback = { |melodyKey|
    var result = nil;
    
    if (melodyKey.isNil) {
        if (~currentSequence.notNil && ~currentSequence.size > 0) {
            melodyKey = ~currentSequence[~currentLoopIndex];
        } {
            "No melody key provided and no current sequence available".postln;
        };
    };
    
    if (melodyKey.notNil) {
        if (~isClipKey.(melodyKey)) {
            "Testing clip playback: %".format(melodyKey).postln;
            if (~melodyProcs[melodyKey].notNil) {
                ~melodyProcs[melodyKey].play;
            } {
                "No ProcMod found for clip: %".format(melodyKey).postln;
            };
        } {
            "% is not a clip".format(melodyKey).postln;
        };
    };
    
    result;
};

// Safe melody loading that doesn't trigger continuous loop
~loadMelodiesForClips = {
    var originalAutoStart;
    
    "Loading melodies for clip system (no auto-playback)...".postln;
    
    // Stop any existing continuous loop first
    if (~continuousLoopRunning == true) {
        "Stopping existing continuous loop...".postln;
        if (~continuousLoopTask.notNil) {
            ~continuousLoopTask.stop;
        };
        ~continuousLoopRunning = false;
    };
    
    // Set a flag to prevent auto-start during loading
    originalAutoStart = ~autoStartContinuousLoop;
    ~autoStartContinuousLoop = false;
    
    // Now safely load melodies
    if (~melodyData.notNil) {
        ~loadActiveMelodies.();
        "✅ Melodies loaded for clip system".postln;
    } {
        "⚠️  No melody data found - load melody data first".postln;
    };
    
    // Restore original auto-start setting
    ~autoStartContinuousLoop = originalAutoStart;
};

// Quick refresh of current sequence after loading clips
~refreshClipSequence = {
    var activeMelodies, activeMelodyKeys;
    
    if (~melodyData.notNil and: { ~melodyData[\melodies].notNil }) {
        activeMelodies = ~melodyData[\melodies].select({ |melody| melody[\active] == true });
        activeMelodyKeys = activeMelodies.collect({ |melody| melody[\key].asSymbol });
        
        // Update current sequence
        ~currentSequence = activeMelodyKeys;
        
        // Initialize index if needed
        if (~currentLoopIndex.isNil) {
            ~currentLoopIndex = 0;
        };
        
        // Ensure index is within bounds
        ~currentLoopIndex = ~currentLoopIndex.clip(0, activeMelodyKeys.size - 1);
        
        "✅ Sequence refreshed: % active items".format(activeMelodyKeys.size).postln;
        "Current sequence: %".format(activeMelodyKeys).postln;
    } {
        "No melody data to refresh".postln;
    };
};

// Ensure VST system is ready for clip playback
~setupVSTForClips = {
    "🔧 Setting up VST system for clip playback...".postln;
    
    if (~vstManager.isNil) {
        "❌ ERROR: VST Manager not found".postln;
        "   You must load the sketch system first:".postln;
        "   \"sketch/load-sketch.scd\".load".postln;
        false;
    } {
        // If no VST group is set, try to set a sensible default
        if (~activeVSTGroup.isNil) {
            var availableGroups = ~vstManager.data.keys.asArray;
            if (availableGroups.size > 0) {
                ~setActiveVSTGroup.(availableGroups[0]);
                "🎯 Auto-selected VST group: %".format(availableGroups[0]).postln;
            } {
                "⚠️  No VST groups available, using ALL instances".postln;
                ~useAllVSTs.();
            };
        };
        
        // Verify OSC responder
        if (OSCdef(\noteOn).isNil) {
            "❌ ERROR: OSC responder not active".postln;
            "   The sketch control system must be loaded".postln;
            false;
        } {
            var instances = ~vstManager.getTargetInstances(~activeVSTGroup);
            "✅ VST system ready: % instances in group '%'".format(
                instances.size, 
                ~activeVSTGroup ? "ALL"
            ).postln;
            true;
        };
    };
};

// Emergency stop function - stops EVERYTHING
~emergencyStop = {
    "🛑 EMERGENCY STOP - Stopping all playback...".postln;
    
    // Stop continuous loop
    if (~continuousLoopRunning == true) {
        "Stopping continuous loop...".postln;
        if (~continuousLoopTask.notNil) {
            ~continuousLoopTask.stop;
        };
        ~continuousLoopRunning = false;
    };
    
    // Stop all ProcMods
    if (~melodyProcs.notNil) {
        "Stopping all ProcMods...".postln;
        ~melodyProcs.do({ |proc| 
            if (proc.notNil && proc.isRunning) { 
                proc.kill;  // Use kill instead of release for immediate stop
            }; 
        });
    };
    
    // Stop all notes
    if (~stopAllNotes.notNil) {
        ~stopAllNotes.();
    };
    
    "✅ Emergency stop complete".postln;
};

// Simple stop function - what should have been there from the start!
~stopClips = {
    "Stopping all clip playback...".postln;
    if (~melodyProcs.notNil) {
        ~melodyProcs.do({ |proc| 
            if (proc.notNil && proc.isRunning) { 
                proc.release; 
            }; 
        });
    };
    "All clips stopped".postln;
};

// Reset everything
~resetClipSystem = {
    "Resetting clip system...".postln;
    ~stopClips.();
    ~clipControl.tempoScale = 1.0;
    "Clip system reset complete".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                            SUCCESS MESSAGE                                 │
// └─────────────────────────────────────────────────────────────────────────────┘

"
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                     ✅ CLIP SYSTEM LOADED SUCCESSFULLY                        ║
║                                                                               ║
║  PHASE 2: Clip playback system + Management GUI integrated                   ║
║                                                                               ║
║  Available functions:                                                         ║
║  • ~clipStatus.()              - Show current status                         ║
║  • ~setupVSTForClips.()        - Verify and setup VST system                 ║
║  • ~loadMelodiesForClips.()    - Safe melody loading (no auto-playback)      ║
║  • ~refreshClipSequence.()     - Refresh sequence after loading clips        ║
║  • ~testClipPlayback.(key)     - Test clip playback                          ║
║  • ~emergencyStop.()           - EMERGENCY STOP (stops everything)           ║
║  • ~stopClips.()               - Stop all clip playback                      ║
║  • ~createClipManagerGUI.()    - Re-open clip management GUI                 ║
║  • ~setClipTempo.(scale)       - Set tempo scale                             ║
║  • ~halfSpeed.()               - Set to half speed                           ║
║  • ~normalSpeed.()             - Set to normal speed                         ║
║  • ~doubleSpeed.()             - Set to double speed                         ║
║  • ~showActiveClips.()         - Show clips in sequence                      ║
║  • ~resetClipSystem.()         - Reset system                                ║
║                                                                               ║
║  File Management:                                                             ║
║  • ~saveClip.(key, filename)   - Save individual clip                        ║
║  • ~loadClip.(filename)        - Load individual clip                        ║
║  • ~saveClipLibrary.(name)     - Save clip collection                        ║
║  • ~loadClipLibrary.(name)     - Load clip collection                        ║
║  • ~listClipFiles.()           - List available clip files                   ║
║  • ~listClipLibraries.()       - List available libraries                    ║
║  • ~quickSaveActiveClips.()    - Quick save all active clips                 ║
║                                                                               ║
║  Clip Management GUI:                                                         ║
║  • ~createClipManagerGUI.()    - Open clip management window                 ║
║  • ~startClipRecording.()      - Start MIDI recording                        ║
║  • ~stopClipRecording.()       - Stop and process recording                  ║
║                                                                               ║
║  MIDI Controls:                                                               ║
║  • CC 20: Tempo scale (0.25x - 4.0x)                                         ║
║  • Note 26: Cycle tempo presets                                              ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
".postln; 