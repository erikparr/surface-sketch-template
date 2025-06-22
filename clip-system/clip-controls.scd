/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                           CLIP CONTROL SYSTEM                                ║
║                           MIDI tempo control and                             ║
║                           parameter routing                                  ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         CLIP TEMPO CONTROL                                 │
// └─────────────────────────────────────────────────────────────────────────────┘

// MIDI CC control for clip tempo scaling
~clipTempoControl = nil; // Will hold MIDIdef

~setupClipTempoControl = { |ccNumber|
    ccNumber = ccNumber ? ~clipSystemConfig.defaultTempoCC;
    // Clean up existing control
    if (~clipTempoControl.notNil) {
        ~clipTempoControl.free;
    };
    
    // Create new CC responder for clip tempo
    ~clipTempoControl = MIDIdef.cc(\clipTempo, { |val, cc, chan, src|
        var newTempoScale = val.linexp(0, 127, ~clipControl.minTempoScale, ~clipControl.maxTempoScale);
        ~clipControl.tempoScale = newTempoScale;
        
        "Clip tempo scale: %x (CC %: %)".format(
            newTempoScale.round(~clipSystemConfig.displayPrecision), 
            cc, 
            val
        ).postln;
    }, ccNumber);
    
    "Clip tempo control setup on CC %".format(ccNumber).postln;
};

// Direct tempo scale functions
~setClipTempo = { |tempoScale|
    tempoScale = tempoScale.clip(~clipControl.minTempoScale, ~clipControl.maxTempoScale);
    ~clipControl.tempoScale = tempoScale;
    "Clip tempo scale set to: %x".format(tempoScale.round(~clipSystemConfig.displayPrecision)).postln;
};

~halfSpeed = { ~setClipTempo.(0.5); };
~normalSpeed = { ~setClipTempo.(1.0); };
~doubleSpeed = { ~setClipTempo.(2.0); };

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                      PARAMETER ROUTING INTEGRATION                         │
// └─────────────────────────────────────────────────────────────────────────────┘

// Add clip tempo scale to parameter routing system
~getClipTempoScale = {
    var mappingHandlesClipTempo;
    
    // Check if mapping system handles clip tempo (if mapping system exists)
    if (~anyRowHandlesParameter.notNil) {
        mappingHandlesClipTempo = ~anyRowHandlesParameter.(\clipTempoScale);
        if (mappingHandlesClipTempo) {
            // Use mapped value if available
            ^~ccControl.clipTempoScale ? ~clipControl.tempoScale;
        };
    };
    
    // Fallback to global clip control
    ^~clipControl.tempoScale;
};

// Update clip control parameters from parameter routing
~updateClipControlFromMapping = {
    if (~ccControl.notNil and: { ~ccControl.clipTempoScale.notNil }) {
        ~clipControl.tempoScale = ~ccControl.clipTempoScale;
        "Updated clip tempo from mapping: %x".format(~clipControl.tempoScale.round(~clipSystemConfig.displayPrecision)).postln;
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                           BUTTON CONTROLS                                  │
// └─────────────────────────────────────────────────────────────────────────────┘

// MIDI button controls for clip functions
~clipModeToggle = nil;

~setupClipModeControls = { |buttonNumber|
    buttonNumber = buttonNumber ? ~clipSystemConfig.defaultModeButton;
    // Clean up existing control
    if (~clipModeToggle.notNil) {
        ~clipModeToggle.free;
    };
    
    // Create button control for clip mode functions
    ~clipModeToggle = MIDIdef.noteOn(\clipModeToggle, { |veloc, note, chan, src|
        if (note == buttonNumber && veloc > 0) {
            // Toggle between different tempo presets
            var currentTempo = ~clipControl.tempoScale;
            var newTempo = case 
                { currentTempo <= 0.5 } { 1.0 }  // half -> normal
                { currentTempo <= 1.0 } { 2.0 }  // normal -> double  
                { currentTempo <= 2.0 } { 0.5 }  // double -> half
                { 1.0 };  // fallback to normal
            
            ~setClipTempo.(newTempo);
            "MIDI Button %: Clip tempo cycled to %x".format(buttonNumber, newTempo.round(~clipSystemConfig.displayPrecision)).postln;
        };
    }, buttonNumber);
    
    "Clip mode button control setup on Note %".format(buttonNumber).postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                            DISPLAY FUNCTIONS                               │
// └─────────────────────────────────────────────────────────────────────────────┘

// Show current clip control status
~showClipControlStatus = {
    "=== CLIP CONTROL STATUS ===".postln;
    "Tempo Scale: %x (% BPM equivalent)".format(
        ~clipControl.tempoScale.round(~clipSystemConfig.displayPrecision),
        (~bpm * ~clipControl.tempoScale).round(1)
    ).postln;
    "Tempo Range: %x - %x".format(
        ~clipControl.minTempoScale.round(~clipSystemConfig.displayPrecision),
        ~clipControl.maxTempoScale.round(~clipSystemConfig.displayPrecision)
    ).postln;
    "System Enabled: %".format(~clipControl.enabled).postln;
    "==========================".postln;
};

// Show active clips in current sequence
~showActiveClips = {
    var clipCount = 0;
    
    "=== ACTIVE CLIPS ===".postln;
    if (~currentSequence.notNil) {
        ~currentSequence.do { |melodyKey, i|
            if (~isClipKey.(melodyKey)) {
                var duration = ~getClipDurationForKey.(melodyKey);
                var current = if (i == ~currentLoopIndex) { " ← CURRENT" } { "" };
                "% - %: %s duration%".format(
                    i + 1, 
                    melodyKey, 
                    duration.round(~clipSystemConfig.displayPrecision),
                    current
                ).postln;
                clipCount = clipCount + 1;
            };
        };
    };
    
    if (clipCount == 0) {
        "No clips in current sequence".postln;
    } {
        "Total clips: %".format(clipCount).postln;
    };
    "==================".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         INITIALIZATION                                     │
// └─────────────────────────────────────────────────────────────────────────────┘

// Initialize clip controls with default settings
~initializeClipControls = {
    // Ensure ~clipControl exists
    if (~clipControl.isNil) {
        "WARNING: ~clipControl not found, creating default".postln;
        ~clipControl = (
            tempoScale: 1.0,
            minTempoScale: 0.25,
            maxTempoScale: 4.0,
            enabled: true
        );
    };
    
    // Setup default MIDI controls
    ~setupClipTempoControl.();  // Use default CC from config
    ~setupClipModeControls.();  // Use default button from config
    
    "Clip controls initialized".postln;
    "- CC %: Tempo scale (%x - %x)".format(
        ~clipSystemConfig.defaultTempoCC,
        ~clipControl.minTempoScale.round(~clipSystemConfig.displayPrecision),
        ~clipControl.maxTempoScale.round(~clipSystemConfig.displayPrecision)
    ).postln;
    "- Note %: Tempo preset cycling".format(~clipSystemConfig.defaultModeButton).postln;
};

// Cleanup function
~cleanupClipControls = {
    if (~clipTempoControl.notNil) {
        ~clipTempoControl.free;
        ~clipTempoControl = nil;
    };
    if (~clipModeToggle.notNil) {
        ~clipModeToggle.free;
        ~clipModeToggle = nil;
    };
    "Clip controls cleaned up".postln;
};

"Clip control system loaded".postln; 