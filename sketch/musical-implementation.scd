/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                         MUSICAL IMPLEMENTATION                               ║
║                         ProcMod and sequencing                               ║
║                         for live performance                                 ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                          PROCMOD SYSTEM                                    │
// └─────────────────────────────────────────────────────────────────────────────┘

// Variables to store ProcMod instances
~melodyProcs = Dictionary.new;
~activeMelodyProc = nil;

// Create a ProcMod for a melody
~createMelodyProc = { |melodyKey, patternIndex=0|
    var pattern = ~melodyDict[melodyKey].patterns[patternIndex];
    var id = (melodyKey ++ "_" ++ patternIndex).asSymbol;

    // Create an ASR envelope: quick attack, sustain at 1, quick release.
    // This sustains until ProcMod.release is called.
    var env = Env.asr(attackTime: 0.01, sustainLevel: 1.0, releaseTime: 0.1, curve: \lin);

    // Create the ProcMod for this melody
    ProcMod.new(
        env,          // Use ASR envelope
        1.0,          // Amplitude
        id,           // Unique ID
        nil,          // Group (create new)
        0,            // addAction
        1,            // target

        // Main function - this will be executed when ProcMod plays
        { |group, envbus|
            var currentNote = pattern[0];
            var noteIndex = 0;
            var repetitionCount = 0;
            var effectiveLength = if(~modes.removeLast, {pattern.size - 1}, {pattern.size});
            var notePlaying = false;
            var task;
            var noteDuration = ~noteDuration;
            var noteRestTime = ~noteRest;
            var temporalAccent = 1;
            var knobRawValue; // Declare knobRawValue here

            // Use MIDI controller values if available
            if(~midiController.notNil) {
                // NEW: Parameter-centric approach - check if ANY row handles timing parameters
                var mappingHandlesNoteDuration, mappingHandlesNoteRestTime;
                
                "=== TIMING PARAMETER ROUTING DEBUG ===".postln;
                
                // Check if any enabled row handles these parameters
                mappingHandlesNoteDuration = ~anyRowHandlesParameter.(\noteDuration);
                mappingHandlesNoteRestTime = ~anyRowHandlesParameter.(\noteRestTime);
                
                // Use mapping values if available, otherwise fall back to direct knob reading
                if (mappingHandlesNoteDuration) {
                    noteDuration = ~ccControl.noteDuration;
                    "✓ MAPPING SYSTEM: noteDuration = % (from ~ccControl)".format(noteDuration).postln;
                } {
                    noteDuration = ~midiController.getKnobRow1(2).linlin(0, 1, 0.1, 10.0);
                    "⚠ FALLBACK: noteDuration = % (direct from knob 2)".format(noteDuration).postln;
                };
                
                if (mappingHandlesNoteRestTime) {
                    noteRestTime = ~ccControl.noteRestTime;
                    "✓ MAPPING SYSTEM: noteRestTime = % (from ~ccControl)".format(noteRestTime).postln;
                } {
                    noteRestTime = ~midiController.getKnobRow1(3).linlin(0, 1, 0.0001, 0.4);
                    "⚠ FALLBACK: noteRestTime = % (direct from knob 3)".format(noteRestTime).postln;
                };
                
                "=== END TIMING DEBUG ===".postln;
                
                // Temporal accent is not part of mapping system, always read from slider
                temporalAccent = ~midiController.getSliderValue(7).linlin(0, 1, 0, 8);  // Slider 8 (CC 61) is index 7
                ("temporalAccent set to: " ++ temporalAccent).postln; // DEBUG

                // Note: melody rest time is now read fresh each time it's needed (real-time control)
                // No more caching of ~melodyRestTime to ensure clean separation when mode is OFF
            };

            // Store the ID of the active melody
            ~activeMelodyProc = id;

            // Log start
            ["Starting melody:", melodyKey, "with", effectiveLength, "notes"].postln;

            // Play each note with proper timing
            task = Task({
                // Repeat the pattern the specified number of times
                ~repetitions.do { |repIndex|
                    // Reset note index for this repetition
                    noteIndex = 0;

                    // Play through each note in the pattern
                    while({ noteIndex < effectiveLength }) {
                        var note = pattern[noteIndex];
                        var isFirstNote = (noteIndex == 0);
                        var isLastNote = (noteIndex == (effectiveLength - 1));
                        var isFermata = isLastNote && ~modes.fermata;  // Fermata no longer depends on melodyRestMode
                        var actualDuration, processedNote;
                        var actualWaitTime;
                        // Process the note (apply offset, etc.)
                        processedNote = ~processNote.value(note, isFirstNote, isLastNote, melodyKey);

                        // Calculate note duration based on position in melody - clear if/else structure
                        if(isFirstNote) {
                            // First note gets base duration
                            actualDuration = noteDuration * 1;
                        } {
                            if(isLastNote && isFermata) {
                                // Only last note gets temporal accent when fermata is ON
                                actualDuration = noteDuration * temporalAccent;
                            } {
                                // All other notes (middle notes and last note when fermata is OFF) get base duration
                                actualDuration = noteDuration;
                            };
                        };

                        // Debug the duration calculation
                        ["DEBUG - Duration calculation:",
                            "note:", processedNote[0],
                            "isFirst:", isFirstNote,
                            "isLast:", isLastNote,
                            "baseDur:", noteDuration,
                            "actualDur:", actualDuration,
                            if(isLastNote, {"accentMult:" ++ temporalAccent}, {""})
                        ].postln;

                        // Store last note duration for loop timing adjustment
                        if(isLastNote) {
                            ~lastNoteDuration = actualDuration;
                            ["Setting ~lastNoteDuration to:", ~lastNoteDuration].postln;
                        };

                        // Release any previous fermata note
                        if(~lastFermataNote.notNil) {
                            ["Releasing previous fermata note:", ~lastFermataNote].postln;
                            NetAddr.localAddr.sendMsg('/note/release', ~lastFermataNote);
                            ~lastFermataNote = nil;
                        };

                        NetAddr.localAddr.sendMsg('/note/on', 0, processedNote[0], processedNote[1],
                            actualDuration, isFermata.asInteger,
                            isFirstNote.asInteger, isLastNote.asInteger);

                        // Trigger second layer on first note of melody
                        if(isFirstNote) {
                            NetAddr.localAddr.sendMsg('/layer2/trigger', melodyKey);
                        };

                        // Store fermata note for later release
                        if(isFermata) {
                            ~lastFermataNote = processedNote[0];
                        };

                        // Wait logic for first note rest multiplier
                        actualWaitTime = noteRestTime; // Default wait time
                        if (isFirstNote) {
                            actualWaitTime = noteRestTime;
                            ["First note's rest time:", actualWaitTime.round(0.001), "seconds"].postln;
                        } {
                            ["Subsequent note's rest: using base noteRestTime:", noteRestTime.round(0.01)].postln;
                        };
                        actualWaitTime.wait;

                        // Advance to next note
                        noteIndex = noteIndex + 1;
                    };

                    // Post-pattern logic
                    if(repIndex < (~repetitions - 1)) {
                        // Add a brief wait between repetitions
                        (noteRestTime * 2).wait;
                    };
                };

                // Handle fermata note timing FIRST (if present)
                if(~lastFermataNote.notNil) {
                    // Use melodyRestTime for fermata duration (unified system)
                    var currentMelodyRestTime = ~midiController.getSliderValue(6).linlin(0, 1, 0.0, 1.0);
                    ["Holding fermata note:", ~lastFermataNote, "for", currentMelodyRestTime, "seconds (using melodyRestTime)"].postln;
                    currentMelodyRestTime.wait;
                    
                    ["Releasing fermata note:", ~lastFermataNote].postln;
                    NetAddr.localAddr.sendMsg('/note/release', ~lastFermataNote);
                    
                    // No delay after fermata release - go directly to next step
                    ["Fermata released - proceeding immediately to next step"].postln;
                    
                    ~lastFermataNote = nil;
                };

                // Handle melody rest for non-fermata cases (fermata already handled melodyRestTime above)
                if(~modes.melodyRestMode && ~lastFermataNote.isNil) {
                    // Read melody rest time fresh from MIDI slider (real-time control)
                    var currentMelodyRestTime = ~midiController.getSliderValue(6).linlin(0, 1, 0.0, 1.0);
                    ["Taking melody rest:", currentMelodyRestTime, "seconds (melody rest mode, no fermata)"].postln;
                    currentMelodyRestTime.wait;
                };

                // Signal completion
                ["Melody", melodyKey, "completed"].postln;
                ["**** DEBUG: Melody task complete for", melodyKey, "- exact time:", Main.elapsedTime.round(0.001)].postln;
            });

            // Start the task
            task.play;

            // Return the task so ProcMod can track it
            task;
        },

        // Release function - executes after ProcMod has fully released
        { |group, envbus|
            ["ProcMod for", id, "has completed release"].postln;
            ["**** DEBUG: ProcMod fully released for", id, "- exact time:", Main.elapsedTime.round(0.001)].postln;

            // Clean up resources if needed
            ~activeNotes.clear;
        },

        // onReleaseFunc - executes when release is triggered
        { |group, envbus|
            ["Releasing ProcMod for", id].postln;

            // Release any fermata notes
            if(~lastFermataNote.notNil) {
                ["Releasing fermata note:", ~lastFermataNote].postln;
                NetAddr.localAddr.sendMsg('/note/release', ~lastFermataNote);
                ~lastFermataNote = nil;
            };

            // Release any active notes
            ~activeNotes.keysValuesDo { |key, noteInfo|
                ["Releasing note:", noteInfo.note].postln;
                ~vstManager.getTargetInstances(~activeVSTGroup).keysValuesDo { |vstName, vst|
                    vst.midi.noteOff(0, noteInfo.note, 0);
                    ["Released note:", noteInfo.note, "on VST:", vstName, "(release handler)"].postln;
                };
            };

            // Clear active notes
            ~activeNotes.clear;
        }
    );
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         CHORD PLAYBACK                                     │
// └─────────────────────────────────────────────────────────────────────────────┘

// Function to play a single chord
~playChord = {
    var currentChord, noteDuration, velocity, instances;
    
    if(~currentChordProgression.isNil || ~getCurrentChord.().isNil) {
        "No chord progression loaded".postln;
        ^nil;
    };
    
    currentChord = ~getCurrentChord.();
    instances = ~vstManager.getTargetInstances(~activeVSTGroup);
    
    // Get timing parameters
    if(~midiController.notNil) {
        noteDuration = ~midiController.getKnobRow1(2).linlin(0, 1, 0.1, 10.0);
        velocity = ~midiController.getKnobRow1(4).linlin(0, 1, 1, 127).asInteger;
    } {
        noteDuration = 1.0;  // Default 1 second
        velocity = 100;
    };
    
    // Apply velocity multiplier for this chord if available
    if(~currentChordProgression.velocityMultipliers.notNil) {
        var multiplier = ~currentChordProgression.velocityMultipliers[~currentChordIndex];
        if(multiplier.notNil) {
            velocity = (velocity * multiplier).asInteger.clip(1, 127);
        };
    };
    
    ["Playing chord", ~currentChordIndex + 1, ":", currentChord, "duration:", noteDuration, "velocity:", velocity].postln;
    
    // Send the chord via OSC (the OSC handler will distribute notes)
    // Use first chord note as the "note" parameter for compatibility
    NetAddr.localAddr.sendMsg('/note/on', 0, currentChord[0], velocity, noteDuration, 0, 1, 0);
    
    // Return the duration for timing
    noteDuration;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                      CONTINUOUS LOOP SEQUENCE                              │
// └─────────────────────────────────────────────────────────────────────────────┘

// Function to start playing all loops sequentially
~startContinuousLoopSequence = {
    // Stop any currently playing melody or loop
    if(~continuousLoopTask.notNil) {
        ~continuousLoopTask.stop;
    };

    // Reset tracking variables
    ~currentLoopIteration = 0;
    ~continuousLoopRunning = true;

    // Check if we're in chord progression mode
    if(~modes.chordProgression) {
        if(~currentChordProgression.isNil) {
            "ERROR: Chord progression mode enabled but no chord progression loaded!".postln;
            "Use ~loadChordProgression.(key) to load a progression first.".postln;
            ~listChordProgressions.();
            ^nil;
        };
        ["Starting continuous loop in CHORD mode with progression:", ~currentChordProgression.name].postln;
        ["Current chord:", ~currentChordIndex + 1, "of", ~currentChordProgression.chords.size].postln;
    } {
        if(~currentSequence.isNil || (~currentSequence.size == 0)) {
            "ERROR: Melody mode but no melody sequence loaded!".postln;
            "Load melodies first.".postln;
            ^nil;
        };
        ["Starting continuous loop sequence with", ~currentSequence.size, "melodies"].postln;
        ["Current melody index:", ~currentLoopIndex, "- Melody:", ~currentSequence[~currentLoopIndex]].postln;
    };

    // Create a task to manage the continuous loop sequence
    ~continuousLoopTask = Task({
        var currentLoopKey, loopCount, pattern, noteCount, currentNoteRest;
        var melodyDuration, totalWaitTime, proc, isPaused = false;

        // Continue until manually stopped
        while({ ~continuousLoopRunning }) {
            
            // Check if we need to pause
            if(~modes.pauseNotesMode) {
                // Only print the message once when entering pause mode
                if(isPaused.not) {
                    ["PAUSED: Waiting until pause mode is disabled (CC 25)"].postln;
                    isPaused = true;
                };

                // Wait briefly then check again
                0.1.wait;
                // Continue to next iteration of while loop
            } {
                // Normal playback mode (not paused)
                
                // If we were paused and now we're not, print a message
                if(isPaused) {
                    ["RESUMING: Pause mode disabled, continuing playback"].postln;
                    isPaused = false;
                };

                // Handle chord mode vs melody mode
                if(~modes.chordProgression) {
                    // CHORD MODE
                    var chordDuration, restTime;
                    
                    // Play current chord
                    chordDuration = ~playChord.();
                    
                    if(chordDuration.notNil) {
                        // Get rest time between chords
                        if(~midiController.notNil) {
                            restTime = ~midiController.getKnobRow1(3).linlin(0, 1, 0.0001, 0.4);
                        } {
                            restTime = 0.2;  // Default rest
                        };
                        
                        // Wait for chord duration plus rest time
                        (chordDuration + restTime).wait;
                        
                        // Advance to next chord if not in manual mode
                        if(~modes.manualLooping.not) {
                            ~nextChord.();
                        };
                        
                        ~currentLoopIteration = ~currentLoopIteration + 1;
                    } {
                        // Error playing chord, wait briefly
                        0.5.wait;
                    };
                } {
                    // MELODY MODE (original code)
                    // Get the current melody to play based on current index
                    currentLoopKey = ~currentSequence[~currentLoopIndex];
                    loopCount = ~melodyDict[currentLoopKey].loopCount ? 1; // Default to 1 if not specified

                // Show current melody info
                ["Playing melody: % (% of %) - iteration %".format(
                    currentLoopKey, 
                    ~currentLoopIndex + 1, 
                    ~currentSequence.size,
                    ~currentLoopIteration + 1
                )].postln;

                // Get pattern info
                pattern = ~melodyDict[currentLoopKey].patterns[0];
                noteCount = if(~modes.removeLast, {pattern.size - 1}, {pattern.size});

                // Get current rest time - use same source as ProcMod
                currentNoteRest = ~noteRest;
                "LOOP DEBUG 1: Initial currentNoteRest (from ~noteRest) = %".format(currentNoteRest).postln;
                
                if(~ccControl.noteRestTime.notNil) {
                    "LOOP DEBUG 2: ~ccControl.noteRestTime exists = %".format(~ccControl.noteRestTime).postln;
                    // Use the same note rest time that ProcMod uses (from mapping system)
                    currentNoteRest = ~ccControl.noteRestTime;
                    "LOOP DEBUG 3: Updated currentNoteRest (from ~ccControl) = %".format(currentNoteRest).postln;
                } {
                    "LOOP DEBUG 2: ~ccControl.noteRestTime is NIL - using fallback".postln;
                };

                "LOOP DEBUG 4: Final currentNoteRest before calculation = %".format(currentNoteRest).postln;

                // DEBUG - Show all timing values
                ["DEBUG - MIDI knob raw value:", ~midiController.getKnobRow1(3)].postln;
                ["DEBUG - currentNoteRest from MIDI:", currentNoteRest].postln;
                ["DEBUG - ~ccControl.noteRestTime:", ~ccControl.noteRestTime].postln;
                ["DEBUG - noteCount:", noteCount].postln;
                ["DEBUG - ~lastNoteDuration:", ~lastNoteDuration].postln;

                // Calculate base wait time (always needed for melody to complete)
                if(~lastNoteDuration.notNil) {
                    melodyDuration = (noteCount - 1) * currentNoteRest + ~lastNoteDuration;
                } {
                    melodyDuration = noteCount * currentNoteRest;
                };

                totalWaitTime = melodyDuration;

                ["DEBUG - melodyDuration calculation:", melodyDuration].postln;
                ["DEBUG - totalWaitTime final:", totalWaitTime].postln;

                // Unified melody rest system: fermata mode = held note + melodyRestTime, melody rest mode = melodyRestTime only
                if(~modes.fermata || ~modes.melodyRestMode) {
                    // Read melody rest time fresh from MIDI slider each iteration (real-time control)
                    var currentMelodyRestTime = ~midiController.getSliderValue(6).linlin(0, 1, 0.0, 1.0);
                    
                    if(~modes.fermata && ~modes.melodyRestMode) {
                        ["Adding melody rest of", currentMelodyRestTime, "seconds (fermata + melody rest: held note + rest time)"].postln;
                    } {
                        if(~modes.fermata) {
                            ["Adding melody rest of", currentMelodyRestTime, "seconds (fermata mode: held note + rest time)"].postln;
                        } {
                            ["Adding melody rest of", currentMelodyRestTime, "seconds (melody rest mode: rest time only)"].postln;
                        };
                    };
                    
                    totalWaitTime = totalWaitTime + currentMelodyRestTime;
                } {
                    ["No melody rest (both fermata and melody rest modes OFF)"].postln;
                    // totalWaitTime remains as melodyDuration (no addition)
                };

                // Create and play a new ProcMod for this iteration
                proc = ~createMelodyProc.value(currentLoopKey);
                ~melodyProcs[currentLoopKey] = proc;

                // Start CC envelopes
                ~startCCEnvelopes.value(currentLoopKey);

                // Play immediately
                proc.play;

                // Wait for melody to complete
                ["Waiting", totalWaitTime, "seconds before next iteration"].postln;
                totalWaitTime.wait;

                // Increment iteration counter
                ~currentLoopIteration = ~currentLoopIteration + 1;

                // Check manual looping mode
                if(~modes.manualLooping) {
                    // Manual mode: stay on current melody indefinitely, ignore loopCount
                    ["Manual looping mode: staying on melody", currentLoopKey, "- iteration", ~currentLoopIteration].postln;
                } {
                    // Progressive mode: advance automatically when loopCount reached
                    if(~currentLoopIteration >= loopCount) {
                        // Move to next melody
                        ~currentLoopIteration = 0;
                        ~currentLoopIndex = (~currentLoopIndex + 1) % ~currentSequence.size;
                        ["Auto-advancing to next melody:", ~currentSequence[~currentLoopIndex]].postln;
                    };
                };
                }; // End of melody mode
            };
        };
    }).play;
};

// Function to stop the continuous loop sequence
~stopContinuousLoopSequence = {
    ["Stopping continuous loop sequence"].postln;
    ~continuousLoopRunning = false;

    if(~continuousLoopTask.notNil) {
        ~continuousLoopTask.stop;
        ~continuousLoopTask = nil;
    };

    // Stop any currently playing melody
    ~stopAllNotes.value;
}; 