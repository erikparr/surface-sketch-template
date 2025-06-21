/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                          CLIP SYSTEM INTEGRATION                             ║
║                          Integration with existing                           ║
║                          sketch system functions                             ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                    CONTINUOUS LOOP SYSTEM INTEGRATION                      │
// └─────────────────────────────────────────────────────────────────────────────┘

// Override ~loadActiveMelodies to use clip-aware loading
~loadActiveMelodies_original = ~loadActiveMelodies; // Backup original

~loadActiveMelodies = {
    var activeMelodies, activeMelodyKeys, clipCount = 0, melodyCount = 0;
    
    if (~melodyData.isNil) {
        "No melody data available. Loading first...".postln;
        ~loadMelodyData.();
    };
    
    activeMelodies = ~melodyData[\melodies].select({ |melody| melody[\active] == true });
    activeMelodyKeys = activeMelodies.collect({ |melody| melody[\key].asSymbol });
    
    // Load melodies into ~melodyDict (for sketch system compatibility)
    ~melodyDict = Dictionary.new;
    activeMelodies.do { |melody|
        if (~isValidClip.(melody)) {
            // For clips, create a simplified melodyDict entry for compatibility
            ~melodyDict.put(melody[\key].asSymbol, (
                name: melody[\name],
                patterns: [melody[\pattern]], // Compatibility pattern (note numbers only)
                velocityMultipliers: (
                    first: melody[\velocityFirst],
                    last: melody[\velocityLast]
                ),
                loopCount: melody[\loopCount],
                isClip: true,
                clipData: melody[\clipData] // Store full clip data
            ));
            clipCount = clipCount + 1;
        } {
            // Traditional melody
            ~melodyDict.put(melody[\key].asSymbol, (
                name: melody[\name],
                patterns: [melody[\pattern]], // Wrap back to array for compatibility
                velocityMultipliers: (
                    first: melody[\velocityFirst],
                    last: melody[\velocityLast]
                ),
                loopCount: melody[\loopCount],
                isClip: false
            ));
            melodyCount = melodyCount + 1;
        };
    };
    
    // Set up the melody sequence for direct navigation
    ~currentSequence = activeMelodyKeys;
    
    // Initialize navigation index if not set
    if (~currentLoopIndex.isNil) {
        ~currentLoopIndex = 0;
    };
    
    // Ensure index is within bounds
    ~currentLoopIndex = ~currentLoopIndex.clip(0, activeMelodyKeys.size - 1);
    
    "Loaded % clips and % traditional melodies into ~melodyDict".format(clipCount, melodyCount).postln;
    "Updated ~currentSequence with active melody keys: %".format(activeMelodyKeys).postln;
    "Current melody index: % (melody: %)".format(~currentLoopIndex, activeMelodyKeys[~currentLoopIndex]).postln;
    
    // Load ProcMods with clip awareness
    ~loadClipBasedMelodies.();
    
    activeMelodies.size; // Don't use ^ in deferred contexts
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                    CONTINUOUS LOOP TIMING INTEGRATION                      │
// └─────────────────────────────────────────────────────────────────────────────┘

// Enhanced timing calculation for continuous loop that handles clips
~calculateLoopWaitTime = { |currentLoopKey|
    var melody, totalWaitTime, melodyDuration, currentNoteRest, pattern, noteCount;
    
    melody = ~melodyDict[currentLoopKey];
    if (melody.isNil) {
        "ERROR: Melody not found: %".format(currentLoopKey).postln;
        1.0; // Fallback - don't use ^ in deferred contexts
    } {
    
    if (melody[\isClip] == true) {
        // CLIP TIMING: Use recorded duration with tempo scaling
        var clipDuration = ~getClipDurationForKey.(currentLoopKey, ~clipControl.tempoScale);
        if (clipDuration.isNil) {
            "ERROR: Could not get clip duration for %".format(currentLoopKey).postln;
            totalWaitTime = 1.0; // Fallback - don't use ^ in deferred contexts
        } {
        
            totalWaitTime = clipDuration;
            "Clip timing: % duration = %s (tempo scale: %x)".format(
                currentLoopKey, 
                clipDuration.round(0.01),
                ~clipControl.tempoScale.round(0.01)
            ).postln;
        };
        
    } {
        // TRADITIONAL MELODY TIMING: Use existing calculation
        pattern = melody.patterns[0];
        noteCount = if(~modes.removeLast, {pattern.size - 1}, {pattern.size});
        
        // Get current rest time - use same source as ProcMod
        currentNoteRest = ~noteRest;
        if(~ccControl.noteRestTime.notNil) {
            currentNoteRest = ~ccControl.noteRestTime;
        };
        
        // Calculate base wait time (always needed for melody to complete)
        if(~lastNoteDuration.notNil) {
            melodyDuration = (noteCount - 1) * currentNoteRest + ~lastNoteDuration;
        } {
            melodyDuration = noteCount * currentNoteRest;
        };
        
        totalWaitTime = melodyDuration;
        "Traditional melody timing: % duration = %s".format(currentLoopKey, melodyDuration.round(0.01)).postln;
    };
    
    // Add melody rest for both clips and traditional melodies (if enabled)
    if (~modes.fermata || ~modes.melodyRestMode) {
        var currentMelodyRestTime = ~midiController.getSliderValue(6).linlin(0, 1, 0.0, 1.0);
        totalWaitTime = totalWaitTime + currentMelodyRestTime;
        "Adding melody rest: %s (total wait: %s)".format(
            currentMelodyRestTime.round(0.01), 
            totalWaitTime.round(0.01)
        ).postln;
    };
    
    totalWaitTime; // Don't use ^ in deferred contexts
};
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         PROCMOD CREATION OVERRIDE                          │
// └─────────────────────────────────────────────────────────────────────────────┘

// Create the missing ~loadClipBasedMelodies function
~loadClipBasedMelodies = {
    "Loading clip-based melodies...".postln;
    if (~melodyDict.notNil) {
        ~melodyDict.keysValuesDo { |key, melody|
            if (melody[\isClip] == true) {
                "Loading clip: %".format(key).postln;
            } {
                "Loading traditional melody: %".format(key).postln;
            };
        };
    };
    "Clip-based melody loading complete".postln;
};

// Enhanced ProcMod creation that detects clips
~createMelodyProc_original = ~createMelodyProc; // Backup original

~createMelodyProc = { |melodyKey, patternIndex=0|
    var melody;
    
    // Safety check to prevent infinite loops
    if (~clipSystemLoading == true) {
        "SAFETY: Skipping ProcMod creation during clip system loading".postln;
        nil;
    } {
        // Check if this is a clip first
        if (~isClipKey.notNil and: { ~isClipKey.(melodyKey) }) {
            melody = ~melodyData[\melodies].detect({ |m| m[\key] == melodyKey });
            if (melody.notNil and: { ~createClipProc.notNil }) {
                "Creating clip ProcMod for: %".format(melodyKey).postln;
                ~createClipProc.(melody, melodyKey); // Don't use ^ in deferred contexts
            } {
                "ERROR: Clip melody not found or ~createClipProc not available: %".format(melodyKey).postln;
                nil;
            };
        } {
            // Fall back to original melody ProcMod creation
            if (~createMelodyProc_original.notNil) {
                "Creating traditional melody ProcMod for: %".format(melodyKey).postln;
                ~createMelodyProc_original.(melodyKey, patternIndex); // Don't use ^ in deferred contexts
            } {
                "ERROR: No original ~createMelodyProc function found".postln;
                nil; // Don't use ^ in deferred contexts
            };
        };
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                             UTILITY FUNCTIONS                              │
// └─────────────────────────────────────────────────────────────────────────────┘

// Show current sequence with clip indicators
~showSequenceWithClips = {
    if (~currentSequence.notNil && ~currentSequence.size > 0) {
        "=== CURRENT SEQUENCE ===".postln;
        ~currentSequence.do { |melodyKey, i|
            var indicator = if (~isClipKey.(melodyKey)) { "🎵 CLIP" } { "♪ MELODY" };
            var current = if (i == ~currentLoopIndex) { " ← CURRENT" } { "" };
            "% - %: %%".format(i + 1, indicator, melodyKey, current).postln;
        };
        "========================".postln;
    } {
        "No sequence loaded".postln;
    };
};

// Reset function that clears clip-specific state
~resetClipSystem = {
    "Resetting clip system...".postln;
    ~clipControl.tempoScale = 1.0;
    "Clip system reset complete".postln;
};

"Clip system integration loaded".postln; 