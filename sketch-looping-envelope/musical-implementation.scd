// Musical Implementation - Integrated with Looping Envelopes
// Handles musical playback with envelope control

(
// Musical state
~musicalState = (
    currentBeat: 0,
    currentMeasure: 0,
    tempo: 120,
    isPlaying: false,
    currentProcMod: nil,
    layer2ProcMod: nil
);

// Create ProcMod for musical playback with envelopes
~createEnvelopeProcMod = { |layerNum = 1|
    var env = Env([0, 1, 1, 0], [0.5, 10, 0.5], \sin, 1);
    var procMod = ProcMod.new(env, 1.0, id: ("layer" ++ layerNum).asSymbol);
    
    procMod.function_({ |group, envbus, server|
        var target = if(layerNum == 2) { ~layer2Target } { ~currentTarget };
        var melodyData = ~getCurrentMelody.value();
        
        if(melodyData.notNil) {
            Task({
                var loopCount = melodyData.loopCount ? 1;
                var melodies = melodyData.melodies;
                
                loopCount.do { |loopIndex|
                    melodies.do { |melody, melodyIndex|
                        var notes = melody.notes;
                        var velocities = melody.velocities ? Array.fill(notes.size, 0.8);
                        var durations = melody.durations ? Array.fill(notes.size, 1.0);
                        
                        // Process based on target type
                        if(target == \All) {
                            // Play on all groups with staggered timing
                            [\Strings, \Winds, \Brass].do { |groupName, groupIndex|
                                {
                                    (groupIndex * 0.2).wait;
                                    ~processChordWithEnvelopes.value(
                                        notes,
                                        velocities,
                                        durations.sum,
                                        groupName
                                    );
                                }.fork;
                            };
                        } {
                            // Play on specific group
                            ~processChordWithEnvelopes.value(
                                notes,
                                velocities,
                                durations.sum,
                                target
                            );
                        };
                        
                        // Wait for melody to complete
                        durations.sum.wait;
                        
                        // Small gap between melodies
                        0.5.wait;
                    };
                };
                
                // Advance to next development
                ~currentCycle = ~currentCycle + 1;
                if(~currentCycle >= loopCount) {
                    ~nextDevelopment.value();
                };
            }).play;
        };
    });
    
    procMod.releaseFunc_({
        ("Layer " ++ layerNum ++ " released").postln;
        ~stopTargetEnvelopes.value(if(layerNum == 2) { ~layer2Target } { ~currentTarget });
    });
    
    procMod;
};

// Start musical performance with envelopes
~startPerformance = {
    if(~isPlaying.not) {
        ~isPlaying = true;
        
        // Start envelope update routine
        ~envelopeUpdateRoutine.reset.play;
        
        // Create and play layer 1
        ~musicalState.currentProcMod = ~createEnvelopeProcMod.value(1);
        ~musicalState.currentProcMod.play;
        
        // Create and play layer 2 if in dual mode
        if(~targetingMode == \dual && ~layer2Target.notNil) {
            ~musicalState.layer2ProcMod = ~createEnvelopeProcMod.value(2);
            ~musicalState.layer2ProcMod.play;
        };
        
        "Performance started with looping envelopes".postln;
        ~printEnvelopeStates.value();
    } {
        "Performance already running".warn;
    };
};

// Stop musical performance
~stopPerformance = {
    if(~isPlaying) {
        ~isPlaying = false;
        
        // Stop envelope update routine
        ~envelopeUpdateRoutine.stop;
        
        // Release ProcMods
        if(~musicalState.currentProcMod.notNil) {
            ~musicalState.currentProcMod.release;
        };
        
        if(~musicalState.layer2ProcMod.notNil) {
            ~musicalState.layer2ProcMod.release;
        };
        
        // Stop all envelopes after a short delay
        {
            2.wait;
            ~stopAllEnvelopes.value();
        }.fork;
        
        "Performance stopped".postln;
    };
};

// Stop envelopes for a specific target
~stopTargetEnvelopes = { |target|
    var instances = ~vstManager.getTargetInstances(target);
    
    instances.keysValuesDo { |name, controller|
        var vstKey = name.asSymbol;
        
        // Free envelope synths
        if(~bendSynths[vstKey].notNil) {
            ~bendSynths[vstKey].free;
            ~bendSynths[vstKey] = nil;
        };
        
        if(~exprSynths[vstKey].notNil) {
            ~exprSynths[vstKey].free;
            ~exprSynths[vstKey] = nil;
        };
        
        // Reset VST
        16.do { |chan|
            controller.midi.allNotesOff(chan);
            controller.midi.bend(chan, 8192);
            controller.midi.control(chan, 11, 0);
        };
    };
};

// Play a single note with envelope on specific VST
~playNoteWithEnvelope = { |vstName, note, velocity = 100, duration = 2.0|
    var controller = ~vstManager.getInstances[vstName];
    
    if(controller.notNil) {
        ~processNoteWithEnvelope.value(
            note,
            velocity,
            duration,
            vstName,
            0
        );
    } {
        ("VST not found: " ++ vstName).warn;
    };
};

// Test envelope playback
~testEnvelopePlayback = { |groupName = \Strings|
    var testNotes = [60, 64, 67, 72];
    var testVelocities = [100, 90, 80, 70];
    
    "Testing envelope playback on group: ".post; groupName.postln;
    
    ~processChordWithEnvelopes.value(
        testNotes,
        testVelocities,
        4.0,
        groupName
    );
};

// Musical patterns with envelope consideration
~musicalPatterns = (
    // Sustained chord with slow bend
    sustainedChord: {
        ~groupEnvelopeParams[\Strings].bendPercent = 15;
        ~groupEnvelopeParams[\Strings].bendDuration = 8.0;
        ~groupEnvelopeParams[\Strings].exprLevel = 90;
        ~groupEnvelopeParams[\Strings].exprDuration = 3.0;
        
        ~processChordWithEnvelopes.value(
            [48, 52, 55, 60],
            [80, 80, 80, 80],
            10.0,
            \Strings
        );
    },
    
    // Fast arpeggios with quick bends
    arpeggioPattern: {
        ~groupEnvelopeParams[\Winds].bendPercent = 25;
        ~groupEnvelopeParams[\Winds].bendDuration = 0.5;
        ~groupEnvelopeParams[\Winds].exprLevel = 110;
        ~groupEnvelopeParams[\Winds].exprDuration = 0.3;
        
        Task({
            [60, 64, 67, 72, 67, 64].do { |note|
                ~playNoteWithEnvelope.value(
                    ~vstManager.getGroupInstances(\Winds)[0].name,
                    note,
                    100,
                    0.5
                );
                0.25.wait;
            };
        }).play;
    },
    
    // Brass fanfare with expression swells
    brassFanfare: {
        ~groupEnvelopeParams[\Brass].bendPercent = 10;
        ~groupEnvelopeParams[\Brass].bendDuration = 2.0;
        ~groupEnvelopeParams[\Brass].exprLevel = 127;
        ~groupEnvelopeParams[\Brass].exprDuration = 1.5;
        
        ~processChordWithEnvelopes.value(
            [36, 43, 48, 55],
            [120, 110, 100, 90],
            4.0,
            \Brass
        );
    }
);

// Tempo and timing control
~setTempo = { |bpm|
    ~musicalState.tempo = bpm;
    ~beatDuration = 60.0 / bpm;
    ("Tempo set to " ++ bpm ++ " BPM").postln;
};

// Initialize tempo
~setTempo.value(120);

"Musical Implementation loaded".postln;
)