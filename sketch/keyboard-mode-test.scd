// Keyboard Mode Implementation Tests
// Test critical assumptions before implementation

(
// Test 1: Verify ProcMod with 10-second envelope behavior
~testProcModTiming = {
    var startTime, procMod;
    
    "=== Test 1: ProcMod 10-second timing ===".postln;
    
    startTime = Main.elapsedTime;
    
    procMod = ProcMod(
        env: Env([0, 1, 1, 0], [0.01, 9.98, 0.01]), // 10 second total
        amp: 1,
        id: "test_timing",
        server: s,
        function: { |group, envbus, server|
            "ProcMod started at group: %".format(group).postln;
            // Return time for verification
            startTime;
        },
        onReleaseFunc: {
            var duration = Main.elapsedTime - startTime;
            "ProcMod released after % seconds".format(duration).postln;
        }
    );
    
    procMod.play;
    procMod;
};

// Test 2: Multiple independent bend envelopes on same group
~testMultipleBendEnvelopes = {
    var group, synths;
    
    "=== Test 2: Multiple bend envelopes ===".postln;
    
    group = Group.new;
    synths = [];
    
    // Create test bend envelope synthdef
    SynthDef(\testBendEnv, { |note = 60, bendRange = 2, dur = 5|
        var env = EnvGen.kr(
            Env([0, bendRange, 0], [dur * 0.5, dur * 0.5], \sin),
            doneAction: 2
        );
        SendReply.kr(Impulse.kr(10), '/testBend', [note, env]);
    }).add;
    
    s.sync;
    
    // Create 3 bend envelopes with different parameters
    3.do { |i|
        var synth = Synth(\testBendEnv, [
            \note, 60 + (i * 4),
            \bendRange, i + 1,
            \dur, 3 + i
        ], group);
        synths = synths.add(synth);
        "Created bend envelope for note %".format(60 + (i * 4)).postln;
    };
    
    group;
};

// Test 3: VST MIDI routing with sustained notes
~testSustainedNotes = {
    var notes, startTime;
    
    "=== Test 3: Sustained note behavior ===".postln;
    
    notes = Dictionary.new;
    startTime = Main.elapsedTime;
    
    // Simulate note-on without note-off
    [60, 64, 67].do { |pitch|
        notes[pitch] = (
            startTime: Main.elapsedTime,
            sustained: true
        );
        "Note % started (will sustain)".format(pitch).postln;
    };
    
    // Schedule cleanup after "ProcMod duration"
    SystemClock.sched(10, {
        notes.keysValuesDo { |pitch, info|
            var duration = Main.elapsedTime - info.startTime;
            "Note % sustained for % seconds".format(pitch, duration).postln;
        };
        notes.clear;
        nil;
    });
    
    notes;
};

// Test 4: Verify existing CC envelope behavior
~testCCEnvelopeIntegration = {
    "=== Test 4: CC Envelope with ProcMod ===".postln;
    
    // Check if looping CC envelopes can coexist with keyboard mode
    if(~loopingCCEnvelopes.notNil) {
        "Current CC envelope state: %".format(~loopingCCEnvelopes).postln;
    };
    
    // Test CC control values
    if(~ccControl.notNil) {
        "CC Control settings:".postln;
        "  Expression CC: %".format(~ccControl.expressionCC).postln;
        "  Expression Range: % - %".format(~ccControl.expressionMin, ~ccControl.expressionMax).postln;
        "  Duration Scalar: %".format(~ccControl.expressionDurationScalar).postln;
    };
};

// Test 5: MIDI handler integration points
~testMIDIIntegration = {
    "=== Test 5: MIDI Integration Points ===".postln;
    
    // Check if we can access modes from MIDI context
    if(~modes.notNil) {
        "Modes accessible: %".format(~modes.keys).postln;
    };
    
    // Check MIDI controller instance
    if(~midiController.notNil) {
        "MIDI Controller available".postln;
        "Note handling enabled: %".format(~midiController.noteHandlingEnabled).postln;
    };
};

// Run tests
fork {
    ~testProcModTiming.value;
    2.wait;
    
    ~testMultipleBendEnvelopes.value;
    2.wait;
    
    ~testSustainedNotes.value;
    2.wait;
    
    ~testCCEnvelopeIntegration.value;
    1.wait;
    
    ~testMIDIIntegration.value;
    
    "\n=== All tests completed ===".postln;
}
)

// Cleanup test
(
// Stop any running test ProcMods
~testProcMod.notNil.if { ~testProcMod.release };

// Free test groups
~testGroup.notNil.if { ~testGroup.free };

"Test cleanup completed".postln;
)