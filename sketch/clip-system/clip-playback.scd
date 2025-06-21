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
// │                         CORE CLIP PLAYBACK                                 │
// └─────────────────────────────────────────────────────────────────────────────┘

// Global clip control parameters
~clipControl = (
    tempoScale: 1.0,        // 1.0 = original speed, 0.5 = half speed, 2.0 = double speed
    minTempoScale: 0.25,    // Minimum tempo scaling (4x slower)
    maxTempoScale: 4.0,     // Maximum tempo scaling (4x faster)
    enabled: true           // Enable/disable clip system
);

// Core clip playback function
~playClip = { |clipData, tempoScale=1.0, targetVSTGroup=nil|
    var notePairs, startTime, targetGroup, task;
    
    // Validate input
    if (clipData.isNil or: { clipData[\clipData].isNil }) {
        "ERROR: Invalid clip data provided".postln;
        nil; // Don't use ^ in deferred contexts
    } {
        notePairs = clipData[\clipData][\notePairs];
        if (notePairs.isNil or: { notePairs.size == 0 }) {
            "ERROR: No note pairs found in clip data".postln;
            nil; // Don't use ^ in deferred contexts
        } {
    
            targetGroup = targetVSTGroup ? ~activeVSTGroup;
            
            "Playing clip with % notes at %x tempo".format(notePairs.size, tempoScale.round(0.01)).postln;
            
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
                            adjustedStartTime.round(0.001),
                            notePair[\startTime].round(0.001)
                        ).postln;
                        
                        nil; // Don't reschedule
                    });
                };
                
                // Wait for clip to complete
                clipDuration = clipData[\clipData][\duration] / tempoScale;
                clipDuration.wait;
                
                "Clip playback completed".postln;
            });
            
            task; // Don't use ^ in deferred contexts
        };
    };
};

// Utility function to get clip duration with tempo scaling
~getClipDuration = { |clipData, tempoScale=1.0|
    if (clipData.isNil or: { clipData[\clipData].isNil }) {
        0; // Don't use ^ in deferred contexts
    } {
        clipData[\clipData][\duration] / tempoScale;
    };
};

// Utility function to validate clip data
~isValidClip = { |melody|
    if (melody.isNil) { 
        false; // Don't use ^ in deferred contexts
    } {
        if (melody[\isClip] != true) { 
            false; // Don't use ^ in deferred contexts
        } {
            if (melody[\clipData].isNil) { 
                false; // Don't use ^ in deferred contexts
            } {
                if (melody[\clipData][\notePairs].isNil) { 
                    false; // Don't use ^ in deferred contexts
                } {
                    if (melody[\clipData][\notePairs].size == 0) { 
                        false; // Don't use ^ in deferred contexts
                    } {
                        true; // Don't use ^ in deferred contexts
                    };
                };
            };
        };
    };
};

"Clip playback system loaded".postln; 