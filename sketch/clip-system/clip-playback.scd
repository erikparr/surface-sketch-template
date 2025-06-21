/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                           CLIP PLAYBACK SYSTEM                               ║
║                           Core timing-based playback                         ║
║                           with tempo scaling                                 ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         CONFIGURATION CONSTANTS                            │
// └─────────────────────────────────────────────────────────────────────────────┘

// Centralized configuration for clip system
~clipSystemConfig = (
    // MIDI Control Numbers
    defaultTempoCC: 20,
    defaultModeButton: 26,
    
    // Tempo Scaling Limits
    minTempoScale: 0.25,    // Minimum tempo scaling (4x slower)
    maxTempoScale: 4.0,     // Maximum tempo scaling (4x faster)
    defaultTempoScale: 1.0, // Default tempo scaling
    
    // Envelope Settings
    envelopeAttack: 0.01,   // Quick attack time
    envelopeRelease: 0.1,   // Quick release time
    envelopeCurve: \lin,    // Linear curve
    
    // System Settings
    initializationDelay: 0.5, // Delay before system initialization
    timingPrecision: 0.001,   // Timing display precision (milliseconds)
    displayPrecision: 0.01    // General display precision
);

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         CORE CLIP PLAYBACK                                 │
// └─────────────────────────────────────────────────────────────────────────────┘

// Global clip control parameters
~clipControl = (
    tempoScale: ~clipSystemConfig.defaultTempoScale,
    minTempoScale: ~clipSystemConfig.minTempoScale,
    maxTempoScale: ~clipSystemConfig.maxTempoScale,
    enabled: true           // Enable/disable clip system
);

// Core clip playback function
~playClip = { |clipData, tempoScale=1.0, targetVSTGroup=nil|
    var notePairs, startTime, targetGroup, task, result = nil;
    
    // Validate input
    if (clipData.isNil or: { clipData[\clipData].isNil }) {
        "ERROR: Invalid clip data provided".postln;
    } {
        notePairs = clipData[\clipData][\notePairs];
        if (notePairs.isNil or: { notePairs.size == 0 }) {
            "ERROR: No note pairs found in clip data".postln;
        } {
            targetGroup = targetVSTGroup ? ~activeVSTGroup;
            
            // DIAGNOSTIC: Verify VST system setup
            ~verifyVSTSetup = {
                var issues = [];
                
                if (~vstManager.isNil) {
                    issues = issues ++ ["~vstManager is nil - VST system not initialized"];
                } {
                    var instances = ~vstManager.getTargetInstances(targetGroup);
                    "🎯 Target VST group: % (% instances available)".format(
                        targetGroup ? "ALL", 
                        instances.size
                    ).postln;
                    if (instances.size == 0) {
                        issues = issues ++ ["No VST instances found for target group: %".format(targetGroup)];
                    } {
                        "   VST instances: %".format(instances.keys.asArray).postln;
                    };
                };
                
                if (OSCdef(\noteOn).isNil) {
                    issues = issues ++ ["OSC responder for /note/on not found - control-systems.scd not loaded?"];
                } {
                    "✅ OSC responder active: /note/on".postln;
                };
                
                if (~activeVSTGroup.isNil) {
                    issues = issues ++ ["~activeVSTGroup not set - use ~setActiveVSTGroup.('groupName') or ~useAllVSTs.()"];
                };
                
                if (issues.size > 0) {
                    "⚠️  VST SETUP ISSUES DETECTED:".postln;
                    issues.do({ |issue, i|
                        "   %: %".format(i + 1, issue).postln;
                    });
                    "   → Try: ~setActiveVSTGroup.('Bass Tuba') or ~useAllVSTs.()".postln;
                    "   → Ensure sketch system is fully loaded first".postln;
                };
                
                issues.size == 0;
            };
            
            if (~verifyVSTSetup.()) {
                "✅ VST system verified - proceeding with clip playback".postln;
            } {
                "⚠️  Continuing clip playback despite setup issues (notes may not sound)".postln;
            };
            
            "🎵 Playing clip with % notes at %x tempo".format(notePairs.size, tempoScale.round(~clipSystemConfig.displayPrecision)).postln;
            
            // Create task to schedule all notes based on recorded timing
            task = Task({
                var clipDuration;
                
                notePairs.do { |notePair, i|
                    var adjustedStartTime = notePair[\startTime] / tempoScale;
                    var adjustedDuration = notePair[\duration] / tempoScale;
                    
                    // Schedule this note
                    SystemClock.sched(adjustedStartTime, {
                        // Send OSC message compatible with existing system
                        NetAddr.localAddr.sendMsg('/note/on', 0, 
                            notePair[\note],           // Note number
                            notePair[\velocity],       // Recorded velocity
                            adjustedDuration,          // Scaled duration
                            0,                         // isFermata (clips handle their own timing)
                            (i == 0).asInteger,        // isFirstNote
                            (i == (notePairs.size - 1)).asInteger  // isLastNote
                        );
                        
                        "Clip note: % at %s (scaled from %s)".format(
                            notePair[\note], 
                            adjustedStartTime.round(~clipSystemConfig.timingPrecision),
                            notePair[\startTime].round(~clipSystemConfig.timingPrecision)
                        ).postln;
                        
                        nil; // Don't reschedule
                    });
                };
                
                // Wait for clip to complete
                clipDuration = clipData[\clipData][\duration] / tempoScale;
                clipDuration.wait;
                
                "Clip playback completed".postln;
            });
            
            result = task;
        };
    };
    
    result;
};

// Utility function to get clip duration with tempo scaling
~getClipDuration = { |clipData, tempoScale=1.0|
    var duration = 0;
    
    if (clipData.notNil and: { clipData[\clipData].notNil }) {
        duration = clipData[\clipData][\duration] / tempoScale;
    };
    
    duration;
};

// Utility function to validate clip data
~isValidClip = { |melody|
    var isValid = true;
    
    // Guard clauses for cleaner validation logic
    if (melody.isNil) { isValid = false };
    if (isValid && (melody[\isClip] != true)) { isValid = false };
    if (isValid && melody[\clipData].isNil) { isValid = false };
    if (isValid && melody[\clipData][\notePairs].isNil) { isValid = false };
    if (isValid && (melody[\clipData][\notePairs].size == 0)) { isValid = false };
    
    isValid;
};

"Clip playback system loaded".postln; 