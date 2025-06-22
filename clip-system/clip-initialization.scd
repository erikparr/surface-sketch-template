/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                          CLIP SYSTEM INITIALIZATION                          ║
║                          Ensure ProcMods are created and                     ║
║                          system is ready for use                             ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         PROCMOD INITIALIZATION                             │
// └─────────────────────────────────────────────────────────────────────────────┘

// Initialize clip system - similar to sketch system's initialization-startup.scd
~initializeClipSystem = {
    "=== CLIP SYSTEM INITIALIZATION ===".postln;
    
    // Ensure ~melodyProcs dictionary exists
    if (~melodyProcs.isNil) {
        ~melodyProcs = Dictionary.new;
        "Created ~melodyProcs dictionary".postln;
    };
    
    // Load melodies if not already loaded
    if (~melodyData.isNil or: { ~melodyData[\melodies].isNil }) {
        "Loading melody data for clip system...".postln;
        if (~loadMelodyData.notNil) {
            ~loadMelodyData.();
        };
    };
    
    // Load active melodies into system
    if (~loadActiveMelodies.notNil) {
        "Loading active melodies...".postln;
        ~loadActiveMelodies.();
    };
    
    // Create ProcMods for all clips and melodies in current sequence
    if (~currentSequence.notNil and: { ~currentSequence.size > 0 }) {
        var clipCount = 0, melodyCount = 0;
        
        "Creating ProcMods for % items in sequence...".format(~currentSequence.size).postln;
        
        ~currentSequence.do { |melodyKey|
            var melody = ~melodyData[\melodies].detect({ |m| m[\key] == melodyKey });
            
            if (melody.notNil) {
                if (~melodyProcs[melodyKey].isNil) {
                    if (~isValidClip.(melody)) {
                        // Create clip ProcMod
                        ~melodyProcs[melodyKey] = ~createClipProc.(melody, melodyKey);
                        clipCount = clipCount + 1;
                        "✓ Created clip ProcMod: %".format(melodyKey).postln;
                    } {
                        // Create traditional melody ProcMod
                        if (~createMelodyProc.notNil) {
                            ~melodyProcs[melodyKey] = ~createMelodyProc.(melodyKey);
                            melodyCount = melodyCount + 1;
                            "✓ Created melody ProcMod: %".format(melodyKey).postln;
                        };
                    };
                } {
                    "ProcMod already exists for: %".format(melodyKey).postln;
                };
            } {
                "WARNING: Melody not found in data: %".format(melodyKey).postln;
            };
        };
        
        "✅ Initialized % clip ProcMods and % melody ProcMods".format(clipCount, melodyCount).postln;
    } {
        "No sequence available - ProcMods will be created as needed".postln;
    };
    
    // Validate system readiness
    ~validateClipSystem.();
    
    "=== CLIP SYSTEM INITIALIZATION COMPLETE ===".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         SYSTEM VALIDATION                                  │
// └─────────────────────────────────────────────────────────────────────────────┘

// Validate that the clip system is ready for use
~validateClipSystem = {
    var issues = [], warnings = [];
    
    "=== CLIP SYSTEM VALIDATION ===".postln;
    
    // Check critical functions
    if (~createClipProc.isNil) {
        issues = issues ++ ["~createClipProc function missing"];
    };
    if (~isValidClip.isNil) {
        issues = issues ++ ["~isValidClip function missing"];
    };
    if (~playClip.isNil) {
        issues = issues ++ ["~playClip function missing"];
    };
    
    // Check data structures
    if (~melodyProcs.isNil) {
        issues = issues ++ ["~melodyProcs dictionary missing"];
    };
    if (~melodyData.isNil) {
        warnings = warnings ++ ["~melodyData not loaded"];
    };
    
    // Check VST integration
    if (~vstManager.isNil) {
        warnings = warnings ++ ["~vstManager not available - VST integration may not work"];
    };
    if (OSCdef(\noteOn).isNil) {
        warnings = warnings ++ ["OSC responder /note/on not active"];
    };
    
    // Check sequence
    if (~currentSequence.notNil and: { ~currentSequence.size > 0 }) {
        var procModCount = ~currentSequence.count({ |key| ~melodyProcs[key].notNil });
        "✓ Sequence loaded: % items, % have ProcMods".format(~currentSequence.size, procModCount).postln;
        
        if (procModCount < ~currentSequence.size) {
            warnings = warnings ++ ["Not all sequence items have ProcMods"];
        };
    } {
        warnings = warnings ++ ["No sequence loaded"];
    };
    
    // Report results
    if (issues.size > 0) {
        "❌ CRITICAL ISSUES:".postln;
        issues.do({ |issue| ("  - " ++ issue).postln; });
    };
    
    if (warnings.size > 0) {
        "⚠️  WARNINGS:".postln;
        warnings.do({ |warning| ("  - " ++ warning).postln; });
    };
    
    if (issues.size == 0 and: { warnings.size == 0 }) {
        "✅ All systems operational".postln;
    };
    
    "==============================".postln;
    
    (issues.size == 0); // Return true if no critical issues
};

"Clip system initialization functions loaded".postln;