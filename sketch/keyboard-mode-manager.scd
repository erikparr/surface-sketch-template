/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                           KEYBOARD MODE MANAGER                                ║
║                                                                                ║
║  Transforms the system from sequence-based playback to real-time              ║
║  keyboard-triggered note and envelope events.                                  ║
║                                                                                ║
║  Features:                                                                     ║
║  - First note triggers 10-second ProcMod                                      ║
║  - Each note gets independent bend envelope                                   ║
║  - Notes sustain for ProcMod duration (ignore note-off)                       ║
║  - CC envelope triggers once per ProcMod                                      ║
║                                                                                ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

~keyboardMode = (
    // State tracking
    enabled: false,
    currentProcMod: nil,
    procModStartTime: nil,
    procModDuration: 10,
    activeNotes: Dictionary.new,  // pitch -> (vstIndex, bendSynth, startTime, velocity)
    keyboardMIDIFuncs: nil,
    ccEnvelopeSynth: nil,  // Track CC envelope synth
    
    // Enable keyboard mode
    enable: {
        "Keyboard Mode: Starting enable process...".postln;
        
        if(~keyboardMode.enabled) { 
            "Keyboard Mode: Already enabled".postln;
            ^this;
        };
        
        "Keyboard Mode: Checking dependencies...".postln;
        
        // Verify dependencies
        if(~midiController.isNil) {
            "Keyboard Mode: ERROR - MIDIController not found".error;
            ^this;
        };
        
        "Keyboard Mode: Stopping sequences...".postln;
        
        // Stop any running sequences
        if(~stopContinuousLoopSequence.notNil) {
            ~stopContinuousLoopSequence.();
        };
        
        "Keyboard Mode: Disabling MIDIController note handling...".postln;
        
        // Disable MIDIController note handling
        ~midiController.setNoteHandlingEnabled(false);
        
        "Keyboard Mode: Setting up MIDI handlers...".postln;
        
        // Set up keyboard mode MIDI handlers
        ~keyboardMode.keyboardMIDIFuncs = (
            noteOn: MIDIFunc.noteOn({ |veloc, pitch, chan, src|
                "Keyboard Mode: MIDI noteOn received - pitch: %, velocity: %".format(pitch, veloc).postln;
                ~keyboardMode.handleNoteOn(pitch, veloc);
            }),
            noteOff: MIDIFunc.noteOff({ |veloc, pitch, chan|
                "Keyboard Mode: MIDI noteOff received - pitch: %".format(pitch).postln;
                ~keyboardMode.handleNoteOff(pitch);  // Will be ignored
            })
        );
        
        "Keyboard Mode: Updating state...".postln;
        
        // Update state
        ~keyboardMode.enabled = true;
        ~modes.keyboardMode = true;
        
        "Keyboard Mode: Enabled successfully".postln;
        "Keyboard Mode: Play notes to trigger ProcMod and bend envelopes".postln;
    },
    
    // Disable keyboard mode
    disable: {
        if(~keyboardMode.enabled.not) {
            "Keyboard Mode: Already disabled".postln;
            ^this;
        };
        
        // Clean up all resources
        ~keyboardMode.cleanup.();
        
        // Re-enable MIDIController note handling
        if(~midiController.notNil) {
            ~midiController.setNoteHandlingEnabled(true);
        };
        
        // Update state
        ~keyboardMode.enabled = false;
        ~modes.keyboardMode = false;
        
        "Keyboard Mode: Disabled".postln;
    },
    
    // Handle note on events
    handleNoteOn: { |pitch, velocity|
        var targetVSTs, vstIndex, bendSynth;
        
        // Check/create ProcMod
        if(~keyboardMode.isProcModActive.().not) {
            ~keyboardMode.createNewProcMod.();
        };
        
        // Get target VSTs (respecting active group)
        targetVSTs = if(~vstManager.notNil) {
            ~vstManager.getActiveInstances()
        } { 
            Dictionary.new 
        };
        
        if(targetVSTs.size == 0) {
            "Keyboard Mode: No active VSTs found".warn;
            ^this;
        };
        
        // Determine VST routing (respect multi-instrument mode)
        if(~midiController.multiInstrumentMode && targetVSTs.size > 1) {
            // Distribute notes across VSTs
            vstIndex = ~keyboardMode.activeNotes.size % targetVSTs.size;
        } {
            // All VSTs play all notes
            vstIndex = nil;  // nil means send to all
        };
        
        // Create per-note bend envelope
        bendSynth = ~keyboardMode.createNoteBendEnvelope.(pitch, vstIndex);
        
        // Store note data
        ~keyboardMode.activeNotes[pitch] = (
            vstIndex: vstIndex,
            bendSynth: bendSynth,
            startTime: Process.elapsedTime,
            velocity: velocity
        );
        
        // Send note to appropriate VST(s)
        if(vstIndex.isNil) {
            // Send to all VSTs
            targetVSTs.do { |vst|
                vst.midi.noteOn(0, pitch, velocity);
            };
        } {
            // Send to specific VST
            var vstKeys = targetVSTs.keys.asArray.sort;
            var vstKey = vstKeys[vstIndex];
            var vst = targetVSTs[vstKey];
            if(vst.notNil) {
                vst.midi.noteOn(0, pitch, velocity);
            };
        };
        
        // Send OSC message for consistency
        if(~midiController.oscNetAddr.notNil) {
            ~midiController.oscNetAddr.sendMsg('/keyOn', vstIndex ? 0, pitch, velocity);
        };
        
        "Keyboard Mode: Note ON - pitch: %, velocity: %, vst: %"
            .format(pitch, velocity, vstIndex ? "all").postln;
    },
    
    // Handle note off events (ignored in keyboard mode)
    handleNoteOff: { |pitch|
        // In keyboard mode, we IGNORE note-offs
        // Notes sustain for full ProcMod duration
        if(~keyboardMode.enabled && ~modes.keyboardMode) {
            "Keyboard Mode: Note-off ignored for pitch % (sustain mode)".format(pitch).postln;
        };
    },
    
    // Check if ProcMod is currently active
    isProcModActive: {
        var currentTime = Process.elapsedTime;
        
        ~keyboardMode.currentProcMod.notNil && 
        ~keyboardMode.procModStartTime.notNil &&
        ((currentTime - ~keyboardMode.procModStartTime) < ~keyboardMode.procModDuration)
    },
    
    // Create new ProcMod instance
    createNewProcMod: {
        var newProcMod;
        
        "Keyboard Mode: Creating new ProcMod...".postln;
        
        // Clean up previous ProcMod
        if(~keyboardMode.currentProcMod.notNil) {
            "Keyboard Mode: Releasing previous ProcMod...".postln;
            ~keyboardMode.currentProcMod.release;
        };
        
        try {
            // Create new ProcMod
            newProcMod = ProcMod.play(
                env: Env([0, 1, 1, 0], [0.01, 9.98, 0.01]),  // 10 second total
                amp: 1,
                id: "keyboard_" ++ Date.getDate.stamp,
                function: { |group, envbus, server, procmod|
                    "Keyboard Mode: ProcMod function executing...".postln;
                    
                    // Start CC envelope for this ProcMod
                    if(~startCCEnvelopeForGroup.notNil) {
                        "Keyboard Mode: Using startCCEnvelopeForGroup...".postln;
                        ~keyboardMode.ccEnvelopeSynth = ~startCCEnvelopeForGroup.(group, envbus);
                    } {
                        "Keyboard Mode: Creating fallback CC envelope...".postln;
                        // Fallback: create basic CC envelope
                        ~keyboardMode.ccEnvelopeSynth = Synth(\ccEnvelopeExp, [
                            \outbus, envbus,
                            \dur, ~keyboardMode.procModDuration,
                            \expressionCC, ~ccControl.expressionCC,
                            \expressionMin, ~ccControl.expressionMin,
                            \expressionMax, ~ccControl.expressionMax
                        ], group);
                    };
                    
                    "Keyboard Mode: CC envelope started".postln;
                },
                onReleaseFunc: {
                    // ProcMod expired - release all notes
                    "Keyboard Mode: ProcMod expired, releasing all notes".postln;
                    ~keyboardMode.releaseAllNotes.();
                    ~keyboardMode.currentProcMod = nil;
                    ~keyboardMode.procModStartTime = nil;
                    ~keyboardMode.ccEnvelopeSynth = nil;
                }
            );
            
            ~keyboardMode.currentProcMod = newProcMod;
            ~keyboardMode.procModStartTime = Process.elapsedTime;
            
            "Keyboard Mode: New ProcMod created successfully (10s duration)".postln;
            
        } { |error|
            "Keyboard Mode: ERROR creating ProcMod - %".format(error).error;
        };
    },
    
    // Create per-note bend envelope
    createNoteBendEnvelope: { |pitch, vstIndex|
        var bendSynth, remainingDuration;
        var bendAmount, peakTimeRatio, returnTimeRatio;
        
        // Get bend parameters
        bendAmount = ~bendEnvelopeParams.bendAmount ? 2;
        peakTimeRatio = ~bendEnvelopeParams.peakTimeRatio ? 0.5;
        returnTimeRatio = ~bendEnvelopeParams.returnTimeRatio ? 0.5;
        
        // Calculate remaining ProcMod time
        remainingDuration = ~keyboardMode.procModDuration - (Process.elapsedTime - ~keyboardMode.procModStartTime);
        remainingDuration = remainingDuration.max(0.1);  // Minimum duration
        
        // Create bend envelope
        bendSynth = Synth(\BendEnvelopeLoop, [
            \dur, remainingDuration,
            \bend, bendAmount * 682,  // Convert semitones to bend units
            \peakTime, peakTimeRatio * remainingDuration,
            \returnTime, returnTimeRatio * remainingDuration,
            \chanIndex, vstIndex ? 0  // Channel index for routing
        ]);
        
        "Creating bend envelope for pitch % (range: +/- % semitones, dur: %s)"
            .format(pitch, bendAmount, remainingDuration.round(0.01)).postln;
        
        bendSynth;
    },
    
    // Release all active notes
    releaseAllNotes: {
        var targetVSTs = if(~vstManager.notNil) {
            ~vstManager.getActiveInstances()
        } { 
            Dictionary.new 
        };
        
        ~keyboardMode.activeNotes.keysValuesDo { |pitch, noteData|
            // Free bend envelope
            if(noteData.bendSynth.notNil) {
                noteData.bendSynth.free;
            };
            
            // Send note off to appropriate VST(s)
            if(noteData.vstIndex.isNil) {
                // Was sent to all VSTs
                targetVSTs.do { |vst|
                    vst.midi.noteOff(0, pitch, 0);
                };
            } {
                // Was sent to specific VST
                var vstKeys = targetVSTs.keys.asArray.sort;
                var vstKey = vstKeys[noteData.vstIndex];
                var vst = targetVSTs[vstKey];
                if(vst.notNil) {
                    vst.midi.noteOff(0, pitch, 0);
                };
            };
            
            // Send OSC note off
            if(~midiController.oscNetAddr.notNil) {
                ~midiController.oscNetAddr.sendMsg('/keyOff', noteData.vstIndex ? 0, pitch);
            };
        };
        
        "Keyboard Mode: Released % notes".format(~keyboardMode.activeNotes.size).postln;
        ~keyboardMode.activeNotes.clear;
    },
    
    // Clean up all resources
    cleanup: {
        // Free keyboard MIDI handlers
        if(~keyboardMode.keyboardMIDIFuncs.notNil) {
            ~keyboardMode.keyboardMIDIFuncs.do(_.free);
            ~keyboardMode.keyboardMIDIFuncs = nil;
        };
        
        // Release current ProcMod
        if(~keyboardMode.currentProcMod.notNil) {
            ~keyboardMode.currentProcMod.release;
            ~keyboardMode.currentProcMod = nil;
        };
        
        // Release all notes
        ~keyboardMode.releaseAllNotes.();
        
        // Clear state
        ~keyboardMode.procModStartTime = nil;
        ~keyboardMode.ccEnvelopeSynth = nil;
        
        "Keyboard Mode: All resources cleaned up".postln;
    }
);

"✓ Keyboard mode manager loaded".postln;