/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                              CORE FUNCTIONS                                  ║
║                           Helper functions for                               ║
║                        note processing and control                           ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         NOTE PROCESSING                                    │
// └─────────────────────────────────────────────────────────────────────────────┘

// Function to process a note based on current settings
~processNote = { |note, isFirstNote=false, isLastNote=false, melodyKey|
    var processedNote = note;
    var velocity, velocityMultiplier = 1.0;
    var mappingHandlesVelocity;
    
    // NEW: Parameter-centric approach - check if ANY row handles velocity parameter
    "=== VELOCITY PARAMETER ROUTING DEBUG ===".postln;
    
    // Check if any enabled row handles velocity parameter
    mappingHandlesVelocity = ~anyRowHandlesParameter.(\velocity);
    
    // Use mapping value if available, otherwise fall back to direct knob reading
    if (mappingHandlesVelocity) {
        velocity = ~ccControl.velocity;
        "✓ MAPPING SYSTEM: velocity = % (from ~ccControl)".format(velocity).postln;
    } {
        velocity = ~midiController.getKnobRow1(4).linlin(0, 1, 1, 127);
        "⚠ FALLBACK: velocity = % (direct from knob 4)".format(velocity).postln;
    };
    
    "=== END VELOCITY DEBUG ===".postln;

    // Apply note offset if enabled
    if(~modes.noteOffset) {
        processedNote = (note + ~noteOffset).clip(0, 1);
    };

    // Apply velocity multipliers if enabled
    if(~modes.velocityMultiply) {
        if(isFirstNote) {
            // Get the numeric value from the 'first' key
            velocityMultiplier = ~melodyDict[melodyKey].velocityMultipliers[\first].asFloat;
        };
        if(isLastNote) {
            // Get the numeric value from the 'last' key
            velocityMultiplier = ~melodyDict[melodyKey].velocityMultipliers[\last].asFloat;
        };
        velocity = (velocity * velocityMultiplier).asInteger.clip(1, 127);
    };

    [processedNote, velocity];
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         CYCLE MANAGEMENT                                   │
// └─────────────────────────────────────────────────────────────────────────────┘

// Function to switch to a specific cycle
~switchCycle = { |cycleNumber|
    if(~developmentCycles.includesKey(cycleNumber)) {
        ~currentCycle = cycleNumber;
        ~currentSequence = ~developmentCycles[cycleNumber].sequence;
        ~currentMelodySetIndex = 0;
        ["Switching to cycle:", ~developmentCycles[cycleNumber].name].postln;
        ["Sequence:", ~currentSequence.collect({ |key| ~melodyDict[key].name })].postln;
    } {
        "Invalid cycle number".postln;
    };
};

// Function to advance to the next cycle
~advanceCycle = {
    var nextCycle = ~currentCycle + 1;
    if(~developmentCycles.includesKey(nextCycle)) {
        ~switchCycle.value(nextCycle);
        ["Advancing to cycle:", nextCycle].postln;
    } {
        ["Staying in final cycle:", ~currentCycle].postln;
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         UTILITY FUNCTIONS                                  │
// └─────────────────────────────────────────────────────────────────────────────┘

// Function to stop all notes regardless of melody state
~stopAllNotes = {
    // Stop each VST instance
    ~vstManager.getTargetInstances(~activeVSTGroup).do { |vst|
        5.do { |channel|
            vst.midi.allNotesOff(channel);
        };
    };

    // Stop all CC envelopes
    ~stopCCEnvelopes.value;

    // Reset tracking variables
    ~lastFermataNote = nil;
    ~activeNotes.clear;
};

// Set a mode
~setMode = { |mode, value|
    if(~modes.includesKey(mode)) {
        ~modes[mode] = value;
        ["Mode", mode, "set to", value].postln;
    } {
        ["Invalid mode:", mode].postln;
    };
};

// Set repetitions
~setRepetitions = { |num|
    ~repetitions = num;
    ["Repetitions set to", num].postln;
};

// Set note offset
~setNoteOffset = { |offset|
    ~noteOffset = offset;
    ["Note offset set to", offset, "semitones"].postln;
};

// Set fermata duration
~setFermataDuration = { |duration|
    ~fermataDuration = duration;
    ["Fermata duration set to", duration, "seconds"].postln;
}; 