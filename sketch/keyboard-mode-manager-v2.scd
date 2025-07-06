/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                           KEYBOARD MODE MANAGER V2                             ║
║                                                                                ║
║  Simplified implementation to avoid lockup issues                              ║
║                                                                                ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// Ensure required SynthDefs exist
if(SynthDescLib.global[\procmodenv_5216].isNil) {
    "Keyboard Mode: Creating procmodenv_5216 SynthDef...".postln;
    SynthDef(\procmodenv_5216, {arg pgate = 1, outbus, amp = 1, timeScale = 1, lag = 0.01;
        var env;
        env = EnvGen.kr(
            Control.names(\env).kr(Env.newClear(30)), pgate,
            1, 0, timeScale, doneAction: 13) * Lag2.kr(amp, lag);
        Out.kr(outbus, env);
    }).add;
};

// Initialize keyboard mode state
~keyboardModeState = (
    enabled: false,
    currentProcMod: nil,
    procModStartTime: nil,
    procModDuration: 10,  // Adjustable 1-30 seconds via MIDI
    ccEnvelopeLoopRatio: 0.5,  // Default 50% - controls envelope loop duration as ratio of ProcMod
    activeNotes: Dictionary.new,
    keyboardMIDIFuncs: nil,
    ccEnvelopeSynth: nil
);

// Enable keyboard mode function
~enableKeyboardMode = {
    "Keyboard Mode: Starting enable process...".postln;
    
    if(~keyboardModeState.enabled) { 
        "Keyboard Mode: Already enabled".postln;
        ^nil;
    };
    
    // Verify dependencies
    if(~midiController.isNil) {
        "Keyboard Mode: ERROR - MIDIController not found".error;
        ^nil;
    };
    
    // Stop any running sequences
    if(~stopContinuousLoopSequence.notNil) {
        ~stopContinuousLoopSequence.();
    };
    
    // Disable MIDIController note handling
    ~midiController.setNoteHandlingEnabled(false);
    
    // Set up keyboard mode MIDI handlers
    ~keyboardModeState.keyboardMIDIFuncs = (
        noteOn: MIDIFunc.noteOn({ |veloc, pitch, chan, src|
            "Keyboard Mode: Note ON - pitch: %, velocity: %".format(pitch, veloc).postln;
            ~handleKeyboardNoteOn.(pitch, veloc);
        }),
        noteOff: MIDIFunc.noteOff({ |veloc, pitch, chan|
            "Keyboard Mode: Note OFF ignored - pitch: %".format(pitch).postln;
            // Ignore note offs in keyboard mode
        })
    );
    
    // Update state
    ~keyboardModeState.enabled = true;
    ~modes.keyboardMode = true;
    
    "Keyboard Mode: Enabled successfully".postln;
};

// Disable keyboard mode function
~disableKeyboardMode = {
    if(~keyboardModeState.enabled.not) {
        "Keyboard Mode: Already disabled".postln;
        ^nil;
    };
    
    // Clean up all resources
    ~cleanupKeyboardMode.();
    
    // Re-enable MIDIController note handling
    if(~midiController.notNil) {
        ~midiController.setNoteHandlingEnabled(true);
    };
    
    // Update state
    ~keyboardModeState.enabled = false;
    ~modes.keyboardMode = false;
    
    "Keyboard Mode: Disabled".postln;
};

// Handle note on
~handleKeyboardNoteOn = { |pitch, velocity|
    var targetVSTs, vstIndex, bendSynth;
    
    // Ignore control notes (MIDI notes 27 and below are reserved for buttons)
    if(pitch <= 27) {
        "Keyboard Mode: Ignoring control note %".format(pitch).postln;
        ^nil;
    };
    
    "Keyboard Mode: handleKeyboardNoteOn called".postln;
    "Keyboard Mode: Current state - procMod: %, startTime: %".format(
        ~keyboardModeState.currentProcMod, 
        ~keyboardModeState.procModStartTime
    ).postln;
    
    // Check/create ProcMod
    try {
        if(~isKeyboardProcModActive.().not) {
            "Keyboard Mode: ProcMod not active, creating new one".postln;
            ~createKeyboardProcMod.();
        } {
            "Keyboard Mode: ProcMod already active".postln;
        };
    } { |error|
        "Keyboard Mode: Error checking ProcMod: %".format(error).error;
        "Keyboard Mode: Creating new ProcMod anyway...".postln;
        ~createKeyboardProcMod.();
    };
    
    // Get target VSTs
    "Keyboard Mode: Getting target VSTs...".postln;
    "Keyboard Mode: ~vstManager is %".format(~vstManager).postln;
    
    targetVSTs = if(~vstManager.notNil) {
        // Use getTargetInstances which returns name->controller dictionary
        var instances = ~vstManager.getTargetInstances(~vstManager.getActiveGroupName());
        "Keyboard Mode: Got % active instances from group '%'".format(instances.size, ~vstManager.getActiveGroupName()).postln;
        instances
    } { 
        "Keyboard Mode: WARNING - vstManager is nil!".postln;
        Dictionary.new 
    };
    
    if(targetVSTs.isNil || targetVSTs.size == 0) {
        "Keyboard Mode: No active VSTs found".warn;
        ^nil;
    };
    
    // Determine VST routing
    if(~midiController.notNil && (~midiController.multiInstrumentMode == true) && (targetVSTs.size > 1)) {
        vstIndex = ~keyboardModeState.activeNotes.size % targetVSTs.size;
        "Keyboard Mode: Multi-instrument mode - routing to VST index %".format(vstIndex).postln;
    } {
        vstIndex = nil;  // Send to all
        "Keyboard Mode: Sending to all VSTs".postln;
    };
    
    
    // Create per-note bend envelope (will use remaining ProcMod time)
    bendSynth = ~createKeyboardBendEnvelope.(pitch, vstIndex);
    
    // Store note data
    ~keyboardModeState.activeNotes[pitch] = (
        vstIndex: vstIndex,
        bendSynth: bendSynth,
        startTime: Process.elapsedTime,
        velocity: velocity,
        targetVSTs: targetVSTs  // Store for release
    );
    
    // Send note to VST(s)
    if(vstIndex.isNil) {
        "Keyboard Mode: Sending note to all % VSTs".format(targetVSTs.size).postln;
        targetVSTs.do { |vst, key|
            if(vst.notNil) {
                "Keyboard Mode: Sending note to VST % (controller: %)".format(key, vst.class).postln;
                if(vst.respondsTo(\midi)) {
                    vst.midi.noteOn(0, pitch, velocity);
                } {
                    "Keyboard Mode: WARNING - VST % does not have MIDI interface".format(key).warn;
                };
            } {
                "Keyboard Mode: WARNING - VST % is nil!".format(key).warn;
            };
        };
    } {
        var vstKeys = targetVSTs.keys.asArray.sort;
        var vstKey = vstKeys[vstIndex];
        var vst = targetVSTs[vstKey];
        if(vst.notNil) {
            "Keyboard Mode: Sending note to VST %".format(vstKey).postln;
            if(vst.respondsTo(\midi)) {
                vst.midi.noteOn(0, pitch, velocity);
            } {
                "Keyboard Mode: WARNING - VST % does not have MIDI interface".format(vstKey).warn;
            };
        } {
            "Keyboard Mode: WARNING - Selected VST % is nil".format(vstKey).warn;
        };
    };
    
    "Keyboard Mode: Note handling complete".postln;
};

// Check if ProcMod is active
~isKeyboardProcModActive = {
    var currentTime = Process.elapsedTime;
    
    if(~keyboardModeState.currentProcMod.notNil && ~keyboardModeState.procModStartTime.notNil) {
        // Only do the time check if both exist
        ((currentTime - ~keyboardModeState.procModStartTime) < ~keyboardModeState.procModDuration)
    } {
        false  // Not active if either is nil
    }
};

// Create new ProcMod
~createKeyboardProcMod = {
    // Read ProcMod duration from MIDI controller if available
    if(~midiController.notNil) {
        // Read from Row 3, Knob 4 (CC 21) - map to 1-30 seconds
        var knobValue = ~midiController.getKnobRow3(4).linlin(0, 127, 0, 1);
        ~keyboardModeState.procModDuration = knobValue.linlin(0, 1, 1, 30);
        "Keyboard Mode: ProcMod duration set to % seconds".format(
            ~keyboardModeState.procModDuration.round(0.1)
        ).postln;
        
        // Read from Row 3, Knob 5 (CC 50) - map to 10-100% loop ratio
        knobValue = ~midiController.getKnobRow3(5).linlin(0, 127, 0, 1);
        ~keyboardModeState.ccEnvelopeLoopRatio = knobValue.linlin(0, 1, 0.1, 1.0);
        "Keyboard Mode: CC envelope loop ratio set to %% of ProcMod duration".format(
            (~keyboardModeState.ccEnvelopeLoopRatio * 100).round(0.1)
        ).postln;
    };
    
    "Keyboard Mode: Creating new ProcMod...".postln;
    
    // Clean up previous
    if(~keyboardModeState.currentProcMod.notNil) {
        ~keyboardModeState.currentProcMod.release;
    };
    
    // Create new ProcMod with dynamic duration
    ~keyboardModeState.currentProcMod = ProcMod.play(
        env: Env([0, 1, 1, 0], 
            [0.01, ~keyboardModeState.procModDuration - 0.02, 0.01]),
        amp: 1,
        id: "keyboard_" ++ Date.getDate.stamp,
        function: { |group, envbus, server, procmod|
            "Keyboard Mode: ProcMod function executing...".postln;
            
            // Looping CC envelope
            if(~ccControl.enabled) {
                // Try to use existing synth def if available
                if(SynthDescLib.global[\ccEnvelopeLoop].notNil) {
                    var loopDuration = ~keyboardModeState.procModDuration * ~keyboardModeState.ccEnvelopeLoopRatio;
                    var attackTime = loopDuration * 0.5;  // 50% of loop for attack
                    var releaseTime = loopDuration * 0.5;  // 50% of loop for release
                    
                    "Keyboard Mode: Creating looping CC envelope - duration: %s (% loops in %s ProcMod)".format(
                        loopDuration.round(0.01),
                        (~keyboardModeState.procModDuration / loopDuration).round(0.1),
                        ~keyboardModeState.procModDuration.round(0.1)
                    ).postln;
                    
                    ~keyboardModeState.ccEnvelopeSynth = Synth(\ccEnvelopeLoop, [
                        \start, ~ccControl.expressionMin,
                        \peak, ~ccControl.expressionMax,
                        \end, ~ccControl.expressionMin,
                        \loopDuration, loopDuration,
                        \delayTime, 0,  // No delay
                        \attackTime, attackTime,
                        \releaseTime, releaseTime,
                        \chanIndex, 0,
                        \ccNum, ~ccControl.expressionCC,
                        \attackCurve, \sin,
                        \releaseCurve, \sin
                    ], group);
                } {
                    "Keyboard Mode: WARNING - ccEnvelopeLoop SynthDef not found, CC envelope disabled".warn;
                };
            };
        },
        onReleaseFunc: {
            "Keyboard Mode: ProcMod expired".postln;
            ~releaseAllKeyboardNotes.();
            ~keyboardModeState.currentProcMod = nil;
            ~keyboardModeState.procModStartTime = nil;
        }
    );
    
    ~keyboardModeState.procModStartTime = Process.elapsedTime;
    "Keyboard Mode: ProcMod created".postln;
};

// Create bend envelope
~createKeyboardBendEnvelope = { |pitch, vstIndex|
    var bendSynth, bendAmount, bendDuration, knobValue;
    
    // Read bend amount directly from MIDI controller if available
    if(~midiController.notNil) {
        // Read from Row 3, Knob 1 (CC 18) - returns 0-127
        knobValue = ~midiController.getKnobRow3(1).linlin(0, 127, 0, 1);  // Normalize to 0-1
        // Map: 0 = -1 octave, 0.5 = no bend, 1 = +1 octave
        bendAmount = (knobValue - 0.5) * 2;  // Convert to -1 to +1 range
        "Keyboard Mode: MIDI knob: %, Bend amount: % octaves".format(
            knobValue.round(0.01), bendAmount.round(0.01)
        ).postln;
    } {
        // Fall back to stored parameter or default (0 = no bend)
        bendAmount = 0;
    };
    
    // Use loop ratio to calculate bend envelope loop duration
    bendDuration = ~keyboardModeState.procModDuration * ~keyboardModeState.ccEnvelopeLoopRatio;
    "Keyboard Mode: Bend envelope loop duration: % seconds (% loops in %s ProcMod)".format(
        bendDuration.round(0.01),
        (~keyboardModeState.procModDuration / bendDuration).round(0.1),
        ~keyboardModeState.procModDuration.round(0.1)
    ).postln;
    
    if(~bendEnvelopeEnabled) {
        if(SynthDescLib.global[\BendEnvelopeLoop].notNil) {
            var bendCenter = 8192;  // MIDI pitch bend center (no bend)
            // bendAmount is now -1 to +1, multiply by 8192 for full octave range
            var bendRange = (bendAmount * 8192).round.asInteger;  
            var peakTimeRatio, returnTimeRatio, peakValue;
            
            // Read peak time ratio from Row 3, Knob 2 if available
            if(~midiController.notNil) {
                peakTimeRatio = ~midiController.getKnobRow3(2).linlin(0, 1, 0.1, 0.9);
                returnTimeRatio = 1.0 - peakTimeRatio;
                "Keyboard Mode: Peak time ratio: %, Return time ratio: %".format(
                    peakTimeRatio.round(0.01), returnTimeRatio.round(0.01)
                ).postln;
            } {
                peakTimeRatio = 0.5;
                returnTimeRatio = 0.5;
            };
            
            peakValue = bendCenter + bendRange;
            "Keyboard Mode: Bend calc - center: %, range: %, peak before clip: %".format(
                bendCenter, bendRange, peakValue
            ).postln;
            
            peakValue = peakValue.clip(0, 16383);
            "Keyboard Mode: Peak after clip: %".format(peakValue).postln;
            
            bendSynth = Synth(\BendEnvelopeLoop, [
                \start, bendCenter,
                \peak, peakValue,
                \end, bendCenter,
                \loopDuration, bendDuration,
                \peakTime, peakTimeRatio * bendDuration,
                \returnTime, returnTimeRatio * bendDuration,
                \chanIndex, vstIndex ? 0
            ]);
            
            "Keyboard Mode: Bend envelope created for pitch % (duration: %s)".format(pitch, bendDuration.round(0.01)).postln;
        } {
            "Keyboard Mode: WARNING - BendEnvelopeLoop SynthDef not found, bend envelope disabled".warn;
        };
    };
    
    bendSynth;
};

// Release individual note
~releaseKeyboardNote = { |pitch|
    var noteData, targetVSTs;
    
    noteData = ~keyboardModeState.activeNotes[pitch];
    
    if(noteData.notNil) {
        // Free bend envelope
        if(noteData.bendSynth.notNil) {
            noteData.bendSynth.free;
        };
        
        
        // Send note off to VST(s)
        targetVSTs = noteData.targetVSTs;
        if(targetVSTs.notNil) {
            if(noteData.vstIndex.isNil) {
                targetVSTs.do { |vst, key|
                    if(vst.notNil && vst.respondsTo(\midi)) {
                        vst.midi.noteOff(0, pitch, 0);
                    };
                };
            } {
                var vstKeys = targetVSTs.keys.asArray.sort;
                var vstKey = vstKeys[noteData.vstIndex];
                var vst = targetVSTs[vstKey];
                if(vst.notNil && vst.respondsTo(\midi)) {
                    vst.midi.noteOff(0, pitch, 0);
                };
            };
        };
        
        // Remove from active notes
        ~keyboardModeState.activeNotes.removeAt(pitch);
        "Keyboard Mode: Released note %".format(pitch).postln;
    };
};

// Release all notes
~releaseAllKeyboardNotes = {
    var targetVSTs = if(~vstManager.notNil) {
        ~vstManager.getTargetInstances(~vstManager.getActiveGroupName())
    } { 
        Dictionary.new 
    };
    
    // Release each note individually
    ~keyboardModeState.activeNotes.keys.do { |pitch|
        ~releaseKeyboardNote.(pitch);
    };
    "Keyboard Mode: Released all notes".postln;
};

// Clean up keyboard mode
~cleanupKeyboardMode = {
    // Free MIDI handlers
    if(~keyboardModeState.keyboardMIDIFuncs.notNil) {
        ~keyboardModeState.keyboardMIDIFuncs.do(_.free);
        ~keyboardModeState.keyboardMIDIFuncs = nil;
    };
    
    // Release ProcMod
    if(~keyboardModeState.currentProcMod.notNil) {
        ~keyboardModeState.currentProcMod.release;
        ~keyboardModeState.currentProcMod = nil;
    };
    
    // Release all notes
    ~releaseAllKeyboardNotes.();
    
    // Clear state
    ~keyboardModeState.procModStartTime = nil;
    ~keyboardModeState.ccEnvelopeSynth = nil;
};

// For compatibility with existing code
~keyboardMode = (
    enable: ~enableKeyboardMode,
    disable: ~disableKeyboardMode,
    enabled: { ~keyboardModeState.enabled }
);

"✓ Keyboard mode manager V2 loaded".postln;