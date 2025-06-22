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

// "[3/4] Loading system integration...".postln;
// (~clipSystemDir +/+ "clip-integration.scd").load;
// NOTE: Integration with melody system disabled - clip system is independent

"[4/5] Loading control system...".postln;
(~clipSystemDir +/+ "clip-controls.scd").load;

"[5/6] Loading file management...".postln;
(~clipSystemDir +/+ "clip-filemanager.scd").load;

"[6/6] Loading clip management GUI...".postln;
(~clipSystemDir.dirname +/+ "setup/clip-management.scd").load;

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
~testClipPlayback = { |clipKey|
    var result = nil, clip;
    
    if (clipKey.isNil) {
        if (~clipMgmtData.notNil and: { ~clipMgmtData.clips.size > 0 }) {
            clip = ~clipMgmtData.clips[0];  // Test first available clip
            clipKey = clip[\key];
        } {
            "No clip key provided and no clips available".postln;
        };
    };
    
    if (clipKey.notNil) {
        // Find clip in clip management data
        if (~clipMgmtData.notNil) {
            clip = ~clipMgmtData.clips.detect({ |c| c[\key] == clipKey });
            if (clip.notNil) {
                "Testing clip playback: %".format(clipKey).postln;
                // Use clip management playback
                if (~playSelectedClip.notNil) {
                    // Set selected index to this clip
                    var clipIndex = ~clipMgmtData.clips.indexOf(clip);
                    if (clipIndex.notNil) {
                        ~clipMgmtData.selectedClipIndex = clipIndex;
                        ~playSelectedClip.();
                    };
                } {
                    "Clip playback function not available".postln;
                };
            } {
                "Clip not found: %".format(clipKey).postln;
            };
        } {
            "No clip management data available".postln;
        };
    };
    
    result;
};

// Load clips from clip management data 
~loadClipsFromData = {
    "Loading clips from clip management data...".postln;
    
    if (~clipMgmtData.notNil and: { ~clipMgmtData.clips.notNil }) {
        var clipCount = ~clipMgmtData.clips.size;
        "✅ Found % clips in clip management data".format(clipCount).postln;
        ~refreshClipSequence.();
    } {
        "⚠️  No clip management data found - record some clips first".postln;
    };
};

// Quick refresh of current sequence after loading clips
~refreshClipSequence = {
    var activeClips, activeClipKeys;
    
    if (~clipMgmtData.notNil and: { ~clipMgmtData.clips.notNil }) {
        activeClips = ~clipMgmtData.clips.select({ |clip| clip[\active] == true });
        activeClipKeys = activeClips.collect({ |clip| clip[\key].asSymbol });
        
        "✅ Clip sequence refreshed: % active clips".format(activeClipKeys.size).postln;
        "Active clips: %".format(activeClipKeys).postln;
    } {
        "No clip data to refresh".postln;
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
    
    // Stop all clip ProcMods
    if (~clipPlaybackProcs.notNil) {
        "Stopping all clip ProcMods...".postln;
        ~clipPlaybackProcs.keysValuesDo({ |key, proc| 
            if (proc.notNil && proc.isRunning) { 
                "Killing ProcMod: %".format(key).postln;
                proc.kill;  // Use kill instead of release for immediate stop
            }; 
        });
        ~clipPlaybackProcs.clear;
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
    if (~clipPlaybackProcs.notNil) {
        ~clipPlaybackProcs.keysValuesDo({ |key, proc| 
            if (proc.notNil && proc.isRunning) { 
                "Releasing clip: %".format(key).postln;
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
║  • ~loadClipsFromData.()       - Load clips from clip management data        ║
║  • ~refreshClipSequence.()     - Refresh clip sequence display               ║
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