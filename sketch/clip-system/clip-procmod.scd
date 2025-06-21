/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                           CLIP PROCMOD INTEGRATION                           ║
║                           ProcMod instances for clips                        ║
║                           using recorded timing data                         ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                        CLIP PROCMOD CREATION                               │
// └─────────────────────────────────────────────────────────────────────────────┘

// Create a ProcMod for a clip (similar to ~createMelodyProc but for clips)
~createClipProc = { |melody, melodyKey|
    var clipData, id, env, totalClipDuration;
    
    // Validate clip data
    if (~isValidClip.(melody).not) {
        "ERROR: Invalid clip data for ~createClipProc".postln;
        ^nil;
    };
    
    clipData = melody[\clipData];
    id = (melodyKey ++ "_clip").asSymbol;
    totalClipDuration = clipData[\duration];
    
    // Create ASR envelope: quick attack, sustain at 1, quick release
    env = Env.asr(
        attackTime: ~clipSystemConfig.envelopeAttack, 
        sustainLevel: 1.0, 
        releaseTime: ~clipSystemConfig.envelopeRelease, 
        curve: ~clipSystemConfig.envelopeCurve
    );
    
    // Create ProcMod instance using existing ProcMod class
    ProcMod.new(
        env,          // ASR envelope for control
        1.0,          // Amplitude
        id,           // Unique identifier
        nil,          // Group (create new)
        0,            // addAction
        1,            // target
        
        // Main function executed when ProcMod plays
        { |group, envbus|
            var task, tempoScale, adjustedClipDuration;
            
            task = Task({
                // Get current tempo scale (from global clip control)
                tempoScale = ~clipControl.tempoScale;
                adjustedClipDuration = totalClipDuration / tempoScale;
                
                "Starting clip playback: % (tempo scale: %x)".format(melodyKey, tempoScale.round(0.01)).postln;
                
                // Play the clip using recorded timing
                ~playClip.(melody, tempoScale, ~activeVSTGroup);
                
                // Wait for clip to complete
                adjustedClipDuration.wait;
                
                // Handle melody rest if enabled (clips don't use fermata - they have their own timing)
                if (~modes.melodyRestMode) {
                    var melodyRestTime = ~midiController.getSliderValue(6).linlin(0, 1, 0.0, 1.0);
                    "Clip melody rest: %s".format(melodyRestTime.round(0.01)).postln;
                    melodyRestTime.wait;
                };
                
                "Clip playback completed: %".format(melodyKey).postln;
            });
            
            task; // Return task for ProcMod to manage
        },
        
        // Release function - executes after ProcMod has fully released
        { |group, envbus|
            "ProcMod for clip % has completed release".format(id).postln;
        },
        
        // onReleaseFunc
        { |group, envbus|
            "Releasing ProcMod for clip %".format(id).postln;
            // Stop any active notes if needed
            ~stopAllNotes.();
        }
    );
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                       CLIP DETECTION AND ROUTING                           │
// └─────────────────────────────────────────────────────────────────────────────┘

// Enhanced melody loading that detects clips and routes them appropriately
~loadClipBasedMelodies = {
    var clipCount = 0, melodyCount = 0, result = nil;
    
    if (~melodyData.isNil or: { ~melodyData[\melodies].isNil }) {
        "No melody data available for clip-based loading".postln;
    } {
    
    ~melodyData[\melodies].do { |melody|
        if (~isValidClip.(melody)) {
            // Create clip-based ProcMod
            ~melodyProcs[melody[\key]] = ~createClipProc.(melody, melody[\key]);
            clipCount = clipCount + 1;
            "Created clip ProcMod: %".format(melody[\key]).postln;
        } {
            // Use existing melody ProcMod for non-clips
            if (~createMelodyProc.notNil) {
                ~melodyProcs[melody[\key]] = ~createMelodyProc.(melody[\key]);
                melodyCount = melodyCount + 1;
            };
        };
    };
    
        "Loaded % clips and % traditional melodies into ProcMod system".format(clipCount, melodyCount).postln;
        result = (clips: clipCount, melodies: melodyCount);
    };
    
    result;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                          INTEGRATION HELPERS                               │
// └─────────────────────────────────────────────────────────────────────────────┘

// Check if a melody key refers to a clip
~isClipKey = { |melodyKey|
    var melody, result = false;
    
    if (~melodyData.notNil and: { ~melodyData[\melodies].notNil }) {
        melody = ~melodyData[\melodies].detect({ |m| m[\key] == melodyKey });
        if (melody.notNil) {
            result = ~isValidClip.(melody);
        };
    };
    
    result;
};

// Get clip duration for timing calculations (used in continuous loop system)
~getClipDurationForKey = { |melodyKey, tempoScale=nil|
    var melody, clipData, duration = nil;
    
    melody = ~melodyData[\melodies].detect({ |m| m[\key] == melodyKey });
    if (melody.notNil and: { ~isValidClip.(melody) }) {
        clipData = melody[\clipData];
        tempoScale = tempoScale ? ~clipControl.tempoScale;
        duration = clipData[\duration] / tempoScale;
    };
    
    duration;
};

"Clip ProcMod integration loaded".postln; 