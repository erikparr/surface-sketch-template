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
    procModDuration: 10,
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
    
    // Create per-note bend envelope
    bendSynth = ~createKeyboardBendEnvelope.(pitch, vstIndex);
    
    // Store note data
    ~keyboardModeState.activeNotes[pitch] = (
        vstIndex: vstIndex,
        bendSynth: bendSynth,
        startTime: Process.elapsedTime,
        velocity: velocity
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
    "Keyboard Mode: Creating new ProcMod...".postln;
    
    // Clean up previous
    if(~keyboardModeState.currentProcMod.notNil) {
        ~keyboardModeState.currentProcMod.release;
    };
    
    // Create new ProcMod
    ~keyboardModeState.currentProcMod = ProcMod.play(
        env: Env([0, 1, 1, 0], [0.01, 9.98, 0.01]),
        amp: 1,
        id: "keyboard_" ++ Date.getDate.stamp,
        function: { |group, envbus, server, procmod|
            "Keyboard Mode: ProcMod function executing...".postln;
            
            // Simple CC envelope
            if(~ccControl.enabled) {
                // Try to use existing synth def if available
                if(SynthDescLib.global[\ccEnvelope].notNil) {
                    ~keyboardModeState.ccEnvelopeSynth = Synth(\ccEnvelope, [
                        \start, ~ccControl.expressionMin,
                        \peak, ~ccControl.expressionMax,
                        \end, ~ccControl.expressionMin,
                        \attackTime, ~keyboardModeState.procModDuration * 0.5,
                        \releaseTime, ~keyboardModeState.procModDuration * 0.5,
                        \chanIndex, 0,
                        \ccNum, ~ccControl.expressionCC,
                        \attackCurve, \sin,
                        \releaseCurve, \sin
                    ], group);
                } {
                    "Keyboard Mode: WARNING - ccEnvelope SynthDef not found, CC envelope disabled".warn;
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
    var bendSynth, remainingDuration;
    var bendAmount = ~bendEnvelopeParams.bendAmount ? 2;
    
    // Check if procModStartTime exists
    if(~keyboardModeState.procModStartTime.notNil) {
        remainingDuration = ~keyboardModeState.procModDuration - 
            (Process.elapsedTime - ~keyboardModeState.procModStartTime);
        remainingDuration = remainingDuration.max(0.1);
    } {
        // Default to full duration if no start time yet
        remainingDuration = ~keyboardModeState.procModDuration;
    };
    
    if(~bendEnvelopeEnabled) {
        if(SynthDescLib.global[\BendEnvelopeLoop].notNil) {
            var bendCenter = 8192;  // MIDI pitch bend center (no bend)
            // bendAmount is in semitones, convert to pitch bend units
            // 8192 units = 12 semitones (1 octave), so 682.67 units per semitone
            var bendRange = (bendAmount * 8192 / 12).round.asInteger;
            
            bendSynth = Synth(\BendEnvelopeLoop, [
                \start, bendCenter,
                \peak, (bendCenter + bendRange).clip(0, 16383),  // Ensure we stay in valid MIDI range
                \end, bendCenter,
                \loopDuration, remainingDuration,
                \peakTime, 0.5 * remainingDuration,
                \returnTime, 0.5 * remainingDuration,
                \chanIndex, vstIndex ? 0
            ]);
            
            "Keyboard Mode: Bend envelope created for pitch % (duration: %s)".format(pitch, remainingDuration.round(0.01)).postln;
        } {
            "Keyboard Mode: WARNING - BendEnvelopeLoop SynthDef not found, bend envelope disabled".warn;
        };
    };
    
    bendSynth;
};

// Release all notes
~releaseAllKeyboardNotes = {
    var targetVSTs = if(~vstManager.notNil) {
        ~vstManager.getTargetInstances(~vstManager.getActiveGroupName())
    } { 
        Dictionary.new 
    };
    
    ~keyboardModeState.activeNotes.keysValuesDo { |pitch, noteData|
        // Free bend envelope
        if(noteData.bendSynth.notNil) {
            noteData.bendSynth.free;
        };
        
        // Send note off
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
    
    ~keyboardModeState.activeNotes.clear;
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