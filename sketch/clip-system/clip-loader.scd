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

"[4/4] Loading control system...".postln;
(~clipSystemDir +/+ "clip-controls.scd").load;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                           SYSTEM INITIALIZATION                            │
// └─────────────────────────────────────────────────────────────────────────────┘

// Initialize clip system with delay to ensure all files loaded
AppClock.sched(0.5, {
    "Initializing clip system...".postln;
    
    // Set safety flag to prevent infinite loops during loading
    ~clipSystemLoading = true;
    
    // Initialize MIDI controls
    ~initializeClipControls.();
    
    // If melody data is already loaded, update it for clip awareness
    if (~melodyData.notNil) {
        "Updating existing melody data for clip awareness...".postln;
        ~loadActiveMelodies.();
    };
    
    // Clear safety flag
    ~clipSystemLoading = false;
    
    "Clip system initialization complete".postln;
    
    // Show status
    ~showClipControlStatus.();
    ~showActiveClips.();
    
    nil; // Don't reschedule
});

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                            USAGE FUNCTIONS                                 │
// └─────────────────────────────────────────────────────────────────────────────┘

// Quick status check
~clipStatus = {
    "=== CLIP SYSTEM STATUS ===".postln;
    ~showClipControlStatus.();
    ~showActiveClips.();
    ~showSequenceWithClips.();
};

// Quick clip playback test
~testClipPlayback = { |melodyKey|
    if (melodyKey.isNil) {
        if (~currentSequence.notNil && ~currentSequence.size > 0) {
            melodyKey = ~currentSequence[~currentLoopIndex];
        } {
            "No melody key provided and no current sequence available".postln;
            nil; // Don't use ^nil in deferred contexts
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
};

// Reset everything
~resetClipSystem = {
    "Resetting clip system...".postln;
    ~clipControl.tempoScale = 1.0;
    if (~melodyProcs.notNil) {
        ~melodyProcs.do({ |proc| 
            if (proc.notNil && proc.isRunning) { 
                proc.release; 
            }; 
        });
    };
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
║  PHASE 2: Clip playback system is now integrated                             ║
║                                                                               ║
║  Available functions:                                                         ║
║  • ~clipStatus.()              - Show current status                         ║
║  • ~testClipPlayback.(key)     - Test clip playback                          ║
║  • ~setClipTempo.(scale)       - Set tempo scale                             ║
║  • ~halfSpeed.()               - Set to half speed                           ║
║  • ~normalSpeed.()             - Set to normal speed                         ║
║  • ~doubleSpeed.()             - Set to double speed                         ║
║  • ~showActiveClips.()         - Show clips in sequence                      ║
║  • ~resetClipSystem.()         - Reset system                                ║
║                                                                               ║
║  MIDI Controls:                                                               ║
║  • CC 20: Tempo scale (0.25x - 4.0x)                                         ║
║  • Note 26: Cycle tempo presets                                              ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
".postln; 