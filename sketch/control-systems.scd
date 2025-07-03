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

// Toggle Chord Progression mode (Note 23)
~toggleChordMode.free;
~toggleChordMode = MIDIdef.noteOn(\toggleChordMode, { |veloc, note, chan, src|
    if (note == 23 && veloc > 0) {
        // Toggle chord progression mode on every note-on
        ~modes.chordProgression = ~modes.chordProgression.not;
        ["MIDI Note 23: Chord Progression mode toggled to",
            if(~modes.chordProgression, "ON", "OFF")].postln;
        
        if(~modes.chordProgression) {
            ~showChordStatus.();
        };
    };
}, 23);  // Note 23 for chord mode toggle

// Next chord control (Note 26)
~nextChordButton.free;
~nextChordButton = MIDIdef.noteOn(\nextChordButton, { |veloc, note, chan, src|
    if (note == 26 && veloc > 0) {
        if (~modes.chordProgression) {
            ~nextChord.();
        } {
            "MIDI Note 26: Chord mode is OFF - enable it first with Note 23".postln;
        };
    };
}, 26);  // Note 26 for next chord

// Previous chord control (Note 28)
~prevChordButton.free;
~prevChordButton = MIDIdef.noteOn(\prevChordButton, { |veloc, note, chan, src|
    if (note == 28 && veloc > 0) {
        if (~modes.chordProgression) {
            ~previousChord.();
        } {
            "MIDI Note 28: Chord mode is OFF - enable it first with Note 23".postln;
        };
    };
}, 28);  // Note 28 for previous chord

// Toggle Sustain mode (Note 29)
~toggleSustainMode.free;
~toggleSustainMode = MIDIdef.noteOn(\toggleSustainMode, { |veloc, note, chan, src|
    if (note == 29 && veloc > 0) {
        // Toggle sustain mode on every note-on
        ~modes.sustainMode = ~modes.sustainMode.not;
        ["MIDI Note 29: Sustain mode toggled to",
            if(~modes.sustainMode, "ON (notes will not auto-release)", "OFF (normal auto-release)")].postln;
    };
}, 29);  // Note 29 for sustain mode toggle

// Toggle Keyboard mode (Note 30)
~toggleKeyboardModeButton.free;
~toggleKeyboardModeButton = MIDIdef.noteOn(\toggleKeyboardModeButton, { |veloc, note, chan, src|
    if (note == 30 && veloc > 0) {
        if(~modes.keyboardMode) {
            ~keyboardMode.disable();
        } {
            ~keyboardMode.enable();
        };
        ["MIDI Note 30: Keyboard mode toggled to", 
            if(~modes.keyboardMode, "ON", "OFF"),
            "- When ON, keyboard triggers ProcMod with bend envelopes"].postln;
    };
}, 30);  // Note 30 for keyboard mode toggle

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

// Initialize bend envelope parameters
~bendEnvelopeEnabled = false;
~bendEnvelopeParams = (
    start: 8192,      // Center position
    peak: 10240,      // Bend up ~25%
    end: 8192,        // Return to center
    peakTimeRatio: 0.3,    // Ratio of note duration to reach peak
    returnTimeRatio: 0.7,  // Ratio of note duration to return
    bendAmount: 0.25  // Amount of bend (0-1, where 1 = max bend)
);

// Storage for active bend envelope synths
~activeBendSynths = Dictionary.new;

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
    
    // No longer start continuous bend envelopes here - they are per-note now
};

// Function to stop all CC envelopes
~stopCCEnvelopes = {
    ~activeCCSynths.do { |synth|
        synth.free;
    };
    ~activeCCSynths.clear;
    "All CC envelopes stopped".postln;
    
    // Also stop bend envelopes
    ~stopBendEnvelopes.();
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                        BEND ENVELOPE SYSTEM                                │
// └─────────────────────────────────────────────────────────────────────────────┘

// Function to update bend parameters from MIDI knobs
~updateBendParametersFromKnobs = {
    if (~midiController.notNil && ~bendEnvelopeEnabled) {
        // Row 3 knobs for bend control:
        // Knob 1 (pos 1): Bend amount (0-100%)
        // Knob 2 (pos 2): Peak time ratio (0.1-0.9 of note duration)
        // Knob 3 (pos 3): Return time ratio (automatically calculated)
        
        var bendAmount = ~midiController.getKnobRow3(1);  // 0-1
        var peakTimeRatio = ~midiController.getKnobRow3(2).linlin(0, 1, 0.1, 0.9);
        var returnTimeRatio = 1.0 - peakTimeRatio;
        
        // Store bend amount directly
        ~bendEnvelopeParams.bendAmount = bendAmount;
        
        // Convert bend amount to MIDI bend value
        // 0 = no bend (8192), 1 = max bend up (16383)
        ~bendEnvelopeParams.peak = (8192 + (bendAmount * 8191)).asInteger;
        ~bendEnvelopeParams.peakTimeRatio = peakTimeRatio;
        ~bendEnvelopeParams.returnTimeRatio = returnTimeRatio;
        
        ["Updated bend params: amount=%, peakRatio=%, returnRatio=%".format(
            bendAmount.round(0.01), peakTimeRatio.round(0.01), returnTimeRatio.round(0.01)
        )].postln;
    };
};

// Function to start bend envelopes
~startBendEnvelopes = { |melodyKey|
    if (~bendEnvelopeEnabled.not) {
        "Bend envelopes disabled".postln;
        ^nil;
    };
    
    // Update parameters from knobs
    ~updateBendParametersFromKnobs.();
    
    // Free any existing bend synths
    ~activeBendSynths.do { |synth|
        synth.free;
    };
    ~activeBendSynths = Dictionary.new;
    
    // Create bend envelope synths for each VST
    ~vstManager.getTargetInstances(~activeVSTGroup).keysValuesDo { |vstKey, vst, i|
        var bendSynth;
        
        // Create looping bend envelope synth (using the existing SynthDef)
        bendSynth = Synth(\BendEnvelopeLoop, [
            \start, ~bendEnvelopeParams.start,
            \peak, ~bendEnvelopeParams.peak,
            \end, ~bendEnvelopeParams.end,
            \peakTime, ~bendEnvelopeParams.peakTime,
            \returnTime, ~bendEnvelopeParams.returnTime,
            \loopDuration, ~bendEnvelopeParams.loopDuration,
            \chanIndex, i
        ]);
        
        // Store the synth
        ~activeBendSynths[vstKey] = bendSynth;
        
        "Created bend envelope synth for % (chan %)".format(vstKey, i).postln;
    };
    
    "Bend envelope synths started".postln;
};

// Function to stop all bend envelopes
~stopBendEnvelopes = {
    ~activeBendSynths.do { |synth|
        synth.free;
    };
    ~activeBendSynths.clear;
    
    // Reset pitch bend to center on all VSTs
    ~vstManager.getTargetInstances(~activeVSTGroup).keysValuesDo { |vstKey, vst|
        vst.midi.bend(0, 8192); // Reset to center
    };
    
    "All bend envelopes stopped and reset".postln;
};

// Function to start per-note bend envelope
~startNoteBend = { |vstKey, vstIndex, noteDuration|
    var bendSynth, peakTime, returnTime;
    
    if (~bendEnvelopeEnabled.not) {
        ^nil;
    };
    
    // Update parameters from knobs
    ~updateBendParametersFromKnobs.();
    
    // Calculate actual times based on note duration and ratios
    peakTime = noteDuration * ~bendEnvelopeParams.peakTimeRatio;
    returnTime = noteDuration * ~bendEnvelopeParams.returnTimeRatio;
    
    // Create non-looping bend envelope synth (using the standard BendEnvelope)
    bendSynth = Synth(\BendEnvelope, [
        \start, ~bendEnvelopeParams.start,
        \peak, ~bendEnvelopeParams.peak,
        \end, ~bendEnvelopeParams.end,
        \peakTime, peakTime,
        \returnTime, returnTime,
        \chanIndex, vstIndex
    ]);
    
    // Store the synth temporarily
    ~activeBendSynths[vstKey ++ "_" ++ UniqueID.next] = bendSynth;
    
    // Schedule cleanup after note duration
    SystemClock.sched(noteDuration, {
        bendSynth.free;
        nil;
    });
    
    "Per-note bend started for % (duration: %s, peak: %s, return: %s)".format(
        vstKey, noteDuration.round(0.01), peakTime.round(0.01), returnTime.round(0.01)
    ).postln;
};

// Toggle function for bend envelope mode
~toggleBendEnvelope = { |enabled|
    ~bendEnvelopeEnabled = enabled;
    
    if (enabled) {
        "Bend envelope mode ENABLED (per-note)".postln;
        // No longer start continuous bend envelopes
    } {
        "Bend envelope mode DISABLED".postln;
        ~stopBendEnvelopes.();
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                           OSC RESPONDERS                                   │
// └─────────────────────────────────────────────────────────────────────────────┘

// Clear any existing OSC responders
"Clearing existing OSC responders...".postln;
OSCdef(\noteOn).free;
OSCdef(\noteOff).free;
OSCdef(\releaseFermata).free;
OSCdef(\bend).free;
"OSC responders cleared".postln;

// OSC responder for note events
OSCdef(\noteOn, { |msg, time, addr, recvPort|
    var channel = msg[1].asInteger;
    var note = msg[2].asInteger;
    var velocity = msg[3].asInteger;
    var duration = msg[4].asFloat;
    var isFermata = msg[5].asInteger == 1;
    var isFirstNote = msg[6].asInteger == 1;
    var isLastNote = msg[7].asInteger == 1;
    var instances, currentChord;

    "=== OSC HANDLER ENTRY ===".postln;
    ["Full OSC message:", msg].postln;

    // Apply note offset if mode is enabled
    if(~modes.noteOffset) {
        note = (note + ~noteOffset).clip(0, 127);
    };

    ["OSC Received:", "channel:", channel, "note:", note, "vel:", velocity,
     "dur:", duration, "fermata:", isFermata, "first:", isFirstNote, "last:", isLastNote].postln;

    ["DEBUG: activeVSTGroup:", ~activeVSTGroup].postln;
    instances = ~vstManager.getTargetInstances(~activeVSTGroup);
    ["DEBUG: Retrieved instances:", instances, "size:", instances.size].postln;
    
    // Check if we're in chord mode
    ["DEBUG: Chord mode check - chordProgression:", ~modes.chordProgression, "currentChordProgression:", ~currentChordProgression.notNil].postln;
    
    if(~modes.chordProgression && ~currentChordProgression.notNil) {
        currentChord = ~getCurrentChord.();
        ["DEBUG: Got current chord:", currentChord].postln;
        
        // Skip validation for now - debug VST instances
        ["DEBUG: Skipping validation, proceeding to VST instances"].postln;
        
        // Debug VST instances
        ["DEBUG: CHORD MODE - Found % VST instances".format(instances.size)].postln;
        if (instances.size == 0) {
            ["ERROR: No VST instances found! Check ~activeVSTGroup and VST setup"].postln;
            ["DEBUG: Available VST groups:", ~vstManager.getGroupNames].postln;
            ["DEBUG: All VST instances:", ~vstManager.getInstances.keys].postln;
        };
        
        instances.keysValuesDo { |vstName, vst|
            ["DEBUG: VST instance:", vstName, "controller:", vst, "midi:", vst.midi].postln;
        };
        
        // Play chord notes distributed across VST instances
        instances.keysValuesDo { |vstName, vst, i|
            var chordNote;
            
            ["DEBUG: CHORD DISTRIBUTION - Processing VST % (index %) of % total".format(vstName, i, instances.size)].postln;
            ["DEBUG: Current chord size:", currentChord.size, "chord:", currentChord].postln;
            
            if(i < currentChord.size) {
                chordNote = currentChord[i];
                
                // Apply note offset if enabled
                if(~modes.noteOffset) {
                    chordNote = (chordNote + ~noteOffset).clip(0, 127);
                    ["DEBUG: Applied note offset, new note:", chordNote].postln;
                };
                
                ["DEBUG: MIDI SEND - About to play chord note:", chordNote, "on VST:", vstName, "(voice", i, ") velocity:", velocity].postln;
                
                try {
                    vst.midi.noteOn(0, chordNote, velocity);
                    ["DEBUG: MIDI SUCCESS - noteOn sent to", vstName].postln;
                } { |error|
                    ["ERROR: MIDI FAILED - could not send noteOn to", vstName, "error:", error].postln;
                };
                
                // Start per-note bend if enabled and duration is provided
                if(~bendEnvelopeEnabled && duration.notNil) {
                    ["DEBUG: Starting bend envelope for", vstName].postln;
                    ~startNoteBend.(vstName, i, duration);
                } {
                    ["DEBUG: No bend envelope (enabled:", ~bendEnvelopeEnabled, "duration:", duration, ")"].postln;
                };
                
                // Schedule note off if duration is provided AND it's not a fermata note AND sustain mode is off
                if(duration.notNil && isFermata.not && ~modes.sustainMode.not) {
                    ["DEBUG: Scheduling noteOff in", duration, "seconds for", vstName].postln;
                    SystemClock.sched(duration, {
                        try {
                            vst.midi.noteOff(0, chordNote, 0);
                            ["DEBUG: Auto-released chord note:", chordNote, "on VST:", vstName].postln;
                        } { |error|
                            ["ERROR: Could not release note on", vstName, "error:", error].postln;
                        };
                        nil;
                    });
                } {
                    if(isFermata) {
                        ["DEBUG: Fermata chord note:", chordNote, "on VST:", vstName, "- will be released manually"].postln;
                        // Store all chord notes for fermata release
                        ~lastFermataChord = ~lastFermataChord ? [];
                        ~lastFermataChord = ~lastFermataChord.add([vstName, chordNote]);
                    } {
                        if(~modes.sustainMode) {
                            ["DEBUG: Sustain mode ON - note will not auto-release"].postln;
                        } {
                            ["DEBUG: No duration provided, note will not auto-release"].postln;
                        };
                    };
                };
            } {
                ["DEBUG: Skipping VST", vstName, "- index", i, ">=", currentChord.size, "(not enough notes in chord)"].postln;
            };
        };
        
        ["DEBUG: CHORD MODE - Finished processing all VST instances"].postln;
    } {
        // Melody mode - play same note on all VST instances
        instances.keysValuesDo { |vstName, vst, i|
            ["Playing on VST:", vstName].postln;
            vst.midi.noteOn(0, note, velocity);
            
            // Start per-note bend if enabled and duration is provided
            if(~bendEnvelopeEnabled && duration.notNil) {
                ~startNoteBend.(vstName, i, duration);
            };

            // Schedule note off if duration is provided AND it's not a fermata note AND sustain mode is off
            if(duration.notNil && isFermata.not && ~modes.sustainMode.not) {
                SystemClock.sched(duration, {
                    vst.midi.noteOff(0, note, 0);
                    ["Auto-released note:", note, "on VST:", vstName, "(normal duration)"].postln;
                    nil;
                });
            } {
                if(isFermata) {
                    ["Fermata note:", note, "on VST:", vstName, "- will be released manually"].postln;
                } {
                    if(~modes.sustainMode) {
                        ["Sustain mode ON - melody note will not auto-release"].postln;
                    };
                };
            };
        };
    };
}, '/note/on');

"✓ OSC responder for '/note/on' created successfully".postln;

// Add a new OSC responder for releasing fermata notes
OSCdef(\releaseFermata, { |msg, time, addr, recvPort|
    var note, instances;

    note = msg[1].asInteger;
    instances = ~vstManager.getTargetInstances(~activeVSTGroup);

    // Check if we're in chord mode and have fermata chord notes stored
    if(~modes.chordProgression && ~lastFermataChord.notNil) {
        ["Releasing fermata chord"].postln;
        
        // Release each chord note on its respective VST
        ~lastFermataChord.do { |noteInfo|
            var vstName = noteInfo[0];
            var chordNote = noteInfo[1];
            var vst = instances[vstName];
            
            if(vst.notNil) {
                vst.midi.noteOff(0, chordNote, 0);
                ["Released chord note:", chordNote, "on VST:", vstName].postln;
            };
        };
        
        // Clear the fermata chord storage
        ~lastFermataChord = nil;
    } {
        // Melody mode - release same note on all VST instances
        ["Releasing fermata note:", note].postln;
        
        instances.keysValuesDo { |vstName, vst|
            vst.midi.noteOff(0, note, 0);
            ["Released note:", note, "on VST:", vstName].postln;
        };
    };
}, '/note/release');

// OSC responder for bend messages from bend envelope synths
OSCdef(\bend, { |msg, time, addr, recvPort|
    var chanIndex = msg[3].asInteger;
    var bendValue = msg[4].asInteger;
    var instances;
    
    if (~bendEnvelopeEnabled && bendValue.inclusivelyBetween(0, 16383)) {
        instances = ~vstManager.getTargetInstances(~activeVSTGroup);
        
        // Apply bend to the VST at the corresponding index
        if (instances.size > 0) {
            var vstKeys = instances.keys.asArray.sort;
            var vstIndex = chanIndex % vstKeys.size;
            var vstKey = vstKeys[vstIndex];
            var vst = instances[vstKey];
            
            if (vst.notNil) {
                vst.midi.bend(0, bendValue);
            };
        };
    };
}, '/bend'); 

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                    MIDI CONTROL MAPPING INTEGRATION                        │
// └─────────────────────────────────────────────────────────────────────────────┘

// Refresh MIDI control mapping integration if available
if (~refreshMIDIControlMappingIntegration.notNil) {
    ~refreshMIDIControlMappingIntegration.();
}; 