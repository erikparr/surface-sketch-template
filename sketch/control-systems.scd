/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                            CONTROL SYSTEMS                                   ║
║                         MIDI, OSC, and CC control                            ║
║                            for real-time interaction                         ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         MIDI BUTTON CONTROLS                               │
// └─────────────────────────────────────────────────────────────────────────────┘

// Track last button state to implement toggle logic
~lastButtonState = Dictionary.new;

// Toggle Melody Rest mode (Note 21)
~toggleMelodyRest.free;
~toggleMelodyRest = MIDIdef.noteOn(\toggleMelodyRest, { |veloc, note, chan, src|
    if (note == 21 && veloc > 0) {
        // Toggle the melody rest mode on every note-on
        ~modes.melodyRestMode = ~modes.melodyRestMode.not;
        ["MIDI Note 21: Melody Rest toggled to",
            if(~modes.melodyRestMode, "ON", "OFF"),
            "- Will take effect on next loop cycle"].postln;
    };
}, 21);  // Note 21 for melody rest toggle

// Toggle Fermata mode (Note 24)
~toggleFermata.free;
~toggleFermata = MIDIdef.noteOn(\toggleFermata, { |veloc, note, chan, src|
    if (note == 24 && veloc > 0) {
        // Toggle the fermata mode on every note-on
        ~modes.fermata = ~modes.fermata.not;
    };
}, 24);  // Note 24 for fermata toggle

// Add pause notes toggle control (Note 25)
~togglePauseNotes.free;
~togglePauseNotes = MIDIdef.noteOn(\togglePauseNotes, { |veloc, note, chan, src|
    if (note == 25 && veloc > 0) {
        // Toggle the pause notes mode on every note-on
        ~modes.pauseNotesMode = ~modes.pauseNotesMode.not;
        ["MIDI Note 25: Pause Notes toggled to",
            if(~modes.pauseNotesMode, "ON", "OFF"),
            "- Will take effect on next loop cycle"].postln;
    };
}, 25);  // Note 25 for the button

// Add next melody control (Note 27) - repurposed from cycle control
~nextMelody.free;
~nextMelody = MIDIdef.noteOn(\nextMelody, { |veloc, note, chan, src|
    if (note == 27 && veloc > 0) {
        if (~navigateMelody.notNil) {
            ~navigateMelody.(\next);
        } {
            // Fallback to original behavior if dual layer system not loaded
            if (~currentSequence.notNil && ~currentSequence.size > 0) {
                ~currentLoopIndex = (~currentLoopIndex + 1) % ~currentSequence.size;
                "MIDI Note 27: Next melody - Index: %, Melody: %".format(
                    ~currentLoopIndex, ~currentSequence[~currentLoopIndex]
                ).postln;
            } {
                "MIDI Note 27: No melody sequence available".postln;
            };
        };
    };
}, 27);  // Note 27 for next melody

// Add previous melody control (Note 22) - repurposed from cycle control  
~prevMelody.free;
~prevMelody = MIDIdef.noteOn(\prevMelody, { |veloc, note, chan, src|
    if (note == 22 && veloc > 0) {
        if (~navigateMelody.notNil) {
            ~navigateMelody.(\prev);
        } {
            // Fallback to original behavior if dual layer system not loaded
            if (~currentSequence.notNil && ~currentSequence.size > 0) {
                ~currentLoopIndex = (~currentLoopIndex - 1).wrap(0, ~currentSequence.size - 1);
                "MIDI Note 22: Previous melody - Index: %, Melody: %".format(
                    ~currentLoopIndex, ~currentSequence[~currentLoopIndex]
                ).postln;
            } {
                "MIDI Note 22: No melody sequence available".postln;
            };
        };
    };
}, 22);  // Note 22 for previous melody

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                        MELODY UTILITY FUNCTIONS                            │
// └─────────────────────────────────────────────────────────────────────────────┘

// Function to show current melody status
~showMelodyStatus = {
    if (~currentSequence.notNil && ~currentSequence.size > 0) {
        ["Current melody: % of % - %".format(
            ~currentLoopIndex + 1, 
            ~currentSequence.size, 
            ~currentSequence[~currentLoopIndex]
        )].postln;
        ["Use MIDI Note 22 (Previous) / 27 (Next) to navigate"].postln;
    } {
        ["No melody sequence available"].postln;
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                        CC ENVELOPE SYSTEM                                  │
// └─────────────────────────────────────────────────────────────────────────────┘

// Function to update expression range from MIDI knobs
~updateExpressionRangeFromKnobs = {
    // NEW: Parameter-centric approach - check if ANY row handles expression parameters
    var mappingHandlesExpressionMin, mappingHandlesExpressionMax;
    
    "=== EXPRESSION RANGE DEBUG ===".postln;
    
    // Check if any enabled row handles these parameters
    mappingHandlesExpressionMin = ~anyRowHandlesParameter.(\expressionMin);
    mappingHandlesExpressionMax = ~anyRowHandlesParameter.(\expressionMax);
    
    if (mappingHandlesExpressionMin.not && mappingHandlesExpressionMax.not) {
        // FALLBACK: Only read knobs if NO mapping system handles these parameters
        if (~midiController.notNil) {
            "⚠ FALLBACK: Reading expression range from Row 1 knobs directly".postln;
            "Knob 5 value: %".format(~midiController.getKnobRow1(5)).postln;
            "Knob 6 value: %".format(~midiController.getKnobRow1(6)).postln;

            // CC 47 (knob row 1, pos 5) controls expression min
            ~ccControl.expressionMin = ~midiController.getKnobRow1(5).linlin(0, 1, 0, 127).asInteger;
            
            // CC 51 (knob row 1, pos 6) controls expression max  
            ~ccControl.expressionMax = ~midiController.getKnobRow1(6).linlin(0, 1, 0, 127).asInteger;

            "ccControl.expressionMin: %".format(~ccControl.expressionMin).postln;
            "ccControl.expressionMax: %".format(~ccControl.expressionMax).postln;
            
            // Ensure max is always greater than min
            if (~ccControl.expressionMax <= ~ccControl.expressionMin) {
                ~ccControl.expressionMax = ~ccControl.expressionMin + 1;
            };
            
            ["Updated expression range: % - %".format(~ccControl.expressionMin, ~ccControl.expressionMax)].postln;
        };
    } {
        "✓ MAPPING SYSTEM: Using expression range values from ~ccControl (updated by mapping system)".postln;
        "expressionMin: % (mapped: %), expressionMax: % (mapped: %)".format(
            ~ccControl.expressionMin, mappingHandlesExpressionMin,
            ~ccControl.expressionMax, mappingHandlesExpressionMax
        ).postln;
    };
    
    "=== END EXPRESSION RANGE DEBUG ===".postln;
    
    // ALWAYS: Ensure max > min regardless of source (mapping or knobs)
    if (~ccControl.expressionMax <= ~ccControl.expressionMin) {
        ~ccControl.expressionMax = ~ccControl.expressionMin + 1;
        "Validation: Ensured expressionMax (%) > expressionMin (%)".format(~ccControl.expressionMax, ~ccControl.expressionMin).postln;
    };
};

// Function to update expression duration scalar from MIDI knob
~updateExpressionDurationScalarFromKnob = {
    // NEW: Parameter-centric approach - check if ANY row handles expression duration scalar
    var mappingHandlesDurationScalar;
    
    "=== EXPRESSION DURATION SCALAR DEBUG ===".postln;
    
    // Check if any enabled row handles this parameter
    mappingHandlesDurationScalar = ~anyRowHandlesParameter.(\expressionDurationScalar);
    
    if (mappingHandlesDurationScalar.not) {
        // FALLBACK: Only read knob if NO mapping system handles this parameter
        if (~midiController.notNil) {
            "⚠ FALLBACK: Reading duration scalar from Row 1 knob directly".postln;
            "Knob 3 value: %".format(~midiController.getKnob(3)).postln;
            // Knob row 1, pos 4 (index 3) controls expression duration scalar
            ~ccControl.expressionDurationScalar = ~midiController.getKnob(3).linlin(0, 1, 0.1, 1.0);
            ["Updated expression duration scalar: %".format(~ccControl.expressionDurationScalar)].postln;
        };
    } {
        "✓ MAPPING SYSTEM: Using duration scalar value from ~ccControl (updated by mapping system)".postln;
        "expressionDurationScalar: % (mapped: %)".format(
            ~ccControl.expressionDurationScalar, mappingHandlesDurationScalar
        ).postln;
    };
    
    "=== END DURATION SCALAR DEBUG ===".postln;
    
    // ALWAYS: Ensure duration scalar is within valid range
    ~ccControl.expressionDurationScalar = ~ccControl.expressionDurationScalar.clip(0.1, 1.0);
};

// Function to calculate envelope duration based on current melody
~calcEnvelopeDuration = { |activeNoteRest|
    var melodyKey = ~currentSequence[~currentMelodySetIndex];
    var pattern = ~melodyDict[melodyKey].patterns[0];
    var noteCount = if(~modes.removeLast, {pattern.size - 1}, {pattern.size});
    var totalNoteDuration = noteCount * activeNoteRest * ~repetitions;

    totalNoteDuration;
};

// Function to start CC envelopes for the current melody
~startCCEnvelopes = { |melodyKey|
    var currentActualNoteRest, duration;
    var attackTime, releaseTime;
    var scaledExpressionDuration;

    // Update expression range from knobs AND duration scalar before creating envelopes
    ~updateExpressionRangeFromKnobs.value;
    ~updateExpressionDurationScalarFromKnob.value;

    // Determine the actual noteRestTime to be used
    if(~midiController.notNil) {
        currentActualNoteRest = ~midiController.getSliderValue(1).linlin(0, 1, 0.0001, 1.0);  // Slider 2 (CC 23) is index 1
    } { // No MIDI controller, use global default
        currentActualNoteRest = ~noteRest;
    };

    duration = ~calcEnvelopeDuration.value(currentActualNoteRest); // This is the trueMelodyDuration
    scaledExpressionDuration = duration * ~ccControl.expressionDurationScalar;

    // Concise logging
    "Starting CC envelopes for true melody duration: %, scaled expr duration: %".format(duration, scaledExpressionDuration).postln;

    // Free any existing synths
    ~activeCCSynths.do { |synth|
        synth.free;
    };
    ~activeCCSynths = Dictionary.new;

    if(~ccControl.enabled) {
        // Calculate timing parameters based on SCALED expression envelope duration
        attackTime = scaledExpressionDuration * ~ccControl.expressionPeakPos;
        releaseTime = scaledExpressionDuration * (1.0 - ~ccControl.expressionPeakPos);
            "expressionMin: %".format(~ccControl.expressionMin).postln;
            "expressionMax: %".format(~ccControl.expressionMax).postln;

        // Create expression control synths for each VST
        ~vstManager.getTargetInstances(~activeVSTGroup).keysValuesDo { |vstKey, vst, i|
            var ccSynth;
            // log the vstKey
            "vstKey: %".format(vstKey).postln;
            // Create a single control synth for each VST
            ccSynth = Synth(\ccEnvelope, [
                \start, ~ccControl.expressionMin,
                \peak, ~ccControl.expressionMax,
                \end, ~ccControl.expressionMin,
                \attackTime, attackTime,
                \releaseTime, releaseTime,
                \chanIndex, i, // Use i to differentiate the VSTs
                \ccNum, ~ccControl.expressionCC,
                \attackCurve, ~ccControl.expressionShape,
                \releaseCurve, ~ccControl.expressionShape
            ]);

            // Store the synth in the dictionary with a key that includes the vstKey
            ~activeCCSynths[vstKey] = ccSynth;

            "Created CC envelope synth for %".format(vstKey).postln;
        };

        "CC control synths started".postln;
    }  {
        "CC Control disabled".postln;
    };
};

// Function to stop all CC envelopes
~stopCCEnvelopes = {
    ~activeCCSynths.do { |synth|
        synth.free;
    };
    ~activeCCSynths.clear;
    "All CC envelopes stopped".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                           OSC RESPONDERS                                   │
// └─────────────────────────────────────────────────────────────────────────────┘

// Clear any existing OSC responders
OSCdef(\noteOn).free;
OSCdef(\noteOff).free;
OSCdef(\releaseFermata).free;

// OSC responder for note events
OSCdef(\noteOn, { |msg, time, addr, recvPort|
    var channel = msg[1].asInteger;
    var note = msg[2].asInteger;
    var velocity = msg[3].asInteger;
    var duration = msg[4].asFloat;
    var isFermata = msg[5].asInteger == 1;
    var isFirstNote = msg[6].asInteger == 1;
    var isLastNote = msg[7].asInteger == 1;

    // Apply note offset if mode is enabled
    if(~modes.noteOffset) {
        note = (note + ~noteOffset).clip(0, 1);
    };

    ["OSC Received:", "channel:", channel, "note:", note, "vel:", velocity,
     "dur:", duration, "fermata:", isFermata, "first:", isFirstNote, "last:", isLastNote].postln;

    // Play note on all VST instances
    ~vstManager.getTargetInstances(~activeVSTGroup).keysValuesDo { |vstName, vst|
        ["Playing on VST:", vstName].postln;
        vst.midi.noteOn(0, note, velocity);

        // Schedule note off if duration is provided AND it's not a fermata note
        if(duration.notNil && isFermata.not) {
            SystemClock.sched(duration, {
                vst.midi.noteOff(0, note, 0);
                ["Auto-released note:", note, "on VST:", vstName, "(normal duration)"].postln;
                nil;
            });
        } {
            if(isFermata) {
                ["Fermata note:", note, "on VST:", vstName, "- will be released manually"].postln;
            };
        };
    };
}, '/note/on');

// Add a new OSC responder for releasing fermata notes
OSCdef(\releaseFermata, { |msg, time, addr, recvPort|
    var note, instances;

    note = msg[1].asInteger;
    instances = ~vstManager.getTargetInstances(~activeVSTGroup);

    ["Releasing fermata note:", note].postln;

    // Release the note on all VST instances
    instances.keysValuesDo { |vstName, vst|
        vst.midi.noteOff(0, note, 0);
        ["Released note:", note, "on VST:", vstName].postln;
    };
}, '/note/release'); 

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                    MIDI CONTROL MAPPING INTEGRATION                        │
// └─────────────────────────────────────────────────────────────────────────────┘

// Refresh MIDI control mapping integration if available
if (~refreshMIDIControlMappingIntegration.notNil) {
    ~refreshMIDIControlMappingIntegration.();
}; 