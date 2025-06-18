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
                    noteDuration = ~midiController.getKnobRow1(2).linlin(0, 1, 0.005, 0.5);
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
                // Get melody rest time from slider 7 (CC 55) which is index 6
                ~melodyRestTime = ~midiController.getSliderValue(6).linlin(0, 1, 0.0, 1.0);

                // First note rest multiplier functionality removed
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
                            // Only first note gets temporal accent
                            actualDuration = noteDuration * 1;
                        } {
                            if(isLastNote) {
                                // Only last note gets the last note duration scalar
                                actualDuration = noteDuration * temporalAccent;
                            } {
                                // Middle notes get the base duration with no modifier
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

                        // Play the note with OSC
                        ["Playing note:", processedNote[0], "duration:", actualDuration,
                            "noteIndex:", noteIndex, "fermata:", isFermata,
                            "first:", isFirstNote, "last:", isLastNote,
                            if(isFermata, {"[FERMATA MODE - will hold for" + ~fermataDuration + "s]"}, {""})
                        ].postln;

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
                    ["Holding fermata note:", ~lastFermataNote, "for", ~fermataDuration, "seconds"].postln;
                    ~fermataDuration.wait;
                    
                    ["Releasing fermata note:", ~lastFermataNote].postln;
                    NetAddr.localAddr.sendMsg('/note/release', ~lastFermataNote);
                    
                    // Short rest after fermata release
                    ["Fermata release rest:", ~fermataReleaseRest, "seconds"].postln;
                    ~fermataReleaseRest.wait;
                    
                    ~lastFermataNote = nil;
                };

                // Then handle melody rest if enabled
                if(~modes.melodyRestMode) {
                    ["Taking melody rest:", ~melodyRestTime, "seconds (controlled by slider 4)"].postln;
                    ~melodyRestTime.wait;
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

    ["Starting continuous loop sequence with", ~currentSequence.size, "melodies"].postln;
    ["Current melody index:", ~currentLoopIndex, "- Melody:", ~currentSequence[~currentLoopIndex]].postln;

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

                // Get current rest time
                currentNoteRest = ~noteRest;
                if(~midiController.notNil) {
                    // Get note rest time from knob 3
                    currentNoteRest = ~midiController.getKnobRow1(3).linlin(0, 1, 0.0001, 0.4);
                };

                // Calculate base wait time (always needed for melody to complete)
                if(~lastNoteDuration.notNil) {
                    melodyDuration = (noteCount - 1) * currentNoteRest + ~lastNoteDuration;
                } {
                    melodyDuration = noteCount * currentNoteRest;
                };

                totalWaitTime = melodyDuration;

                // Add fermata duration if fermata mode is enabled
                if(~modes.fermata) {
                    ["Adding fermata duration of", ~fermataDuration, "seconds"].postln;
                    totalWaitTime = totalWaitTime + ~fermataDuration + ~fermataReleaseRest;
                };

                // Only add melody rest if melody rest mode is enabled
                if(~modes.melodyRestMode) {
                    ["Adding melody rest of", ~melodyRestTime, "seconds (controlled by slider 4)"].postln;
                    totalWaitTime = totalWaitTime + ~melodyRestTime;
                } {
                    ["No melody rest (CC 45 is OFF)"].postln;
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