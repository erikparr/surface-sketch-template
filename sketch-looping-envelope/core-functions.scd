// Core Functions - Adapted for Looping Envelope System
// Basic utilities and helper functions

(
// Initialize core variables
~currentDevelopment = 0;
~currentCycle = 0;
~isPlaying = false;
~currentTarget = \All;
~layer2Target = nil;

// Note processing functions
~processNoteWithEnvelope = { |note, velocity, duration, vstName, channelIndex = 0|
    var controller = ~vstManager.getInstances[vstName];
    
    if(controller.notNil && controller.isOpen) {
        // Start the note with envelope
        ~startLoopingEnvelopes.value(
            vstName,
            controller,
            channelIndex,
            note,
            velocity,
            ~vstManager.vstInstances[vstName].group
        );
        
        // Schedule note off
        {
            duration.wait;
            ~stopLoopingEnvelopes.value(
                vstName,
                controller,
                channelIndex,
                note
            );
        }.fork;
    };
};

// Process a chord with staggered envelopes
~processChordWithEnvelopes = { |notes, velocities, duration, groupName|
    var instances = ~vstManager.getGroupInstances(groupName);
    var numNotes = notes.size.min(instances.size);
    
    numNotes.do { |i|
        var instance = instances[i];
        var controller = instance.controller;
        var note = notes.wrapAt(i);
        var velocity = velocities.wrapAt(i);
        var channelIndex = i % 16;
        
        // Add time offset for staggering
        var timeOffset = i * 0.2;
        
        {
            timeOffset.wait;
            ~processNoteWithEnvelope.value(
                note,
                velocity,
                duration,
                instance.name,
                channelIndex
            );
        }.fork;
    };
};

// Convert MIDI note number to note name
~midiToNoteName = { |midiNote|
    var noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
    var octave = (midiNote / 12).floor - 1;
    var noteName = noteNames[midiNote % 12];
    noteName ++ octave;
};

// Scale velocity based on expression envelope
~scaleVelocity = { |baseVelocity, expressionLevel|
    (baseVelocity * (expressionLevel / 127.0)).round.asInteger.clip(0, 127);
};

// Calculate note duration with envelope consideration
~calculateNoteDuration = { |baseDuration, envelopeParams|
    var attackTime = envelopeParams.exprDuration ? 1.0;
    var releaseTime = attackTime * 0.5;
    baseDuration.max(attackTime + releaseTime + 0.5); // Ensure minimum duration
};

// Get current melody data
~getCurrentMelody = {
    if(~melodyData.notNil) {
        var developments = ~melodyData.melodies.keys.asArray.sort;
        var currentDev = developments.wrapAt(~currentDevelopment);
        ~melodyData.melodies[currentDev];
    } {
        nil;
    };
};

// Advance to next development
~nextDevelopment = {
    ~currentDevelopment = ~currentDevelopment + 1;
    ~currentCycle = 0;
    ("Advanced to development " ++ ~currentDevelopment).postln;
};

// Reset playback state
~resetPlayback = {
    ~currentDevelopment = 0;
    ~currentCycle = 0;
    ~isPlaying = false;
    ~stopAllEnvelopes.value();
    "Playback reset".postln;
};

// Utility to get group from VST name
~getGroupFromVST = { |vstName|
    var instance = ~vstManager.vstInstances[vstName];
    if(instance.notNil) {
        instance.group;
    } {
        nil;
    };
};

// Check if a group has active envelopes
~groupHasActiveEnvelopes = { |groupName|
    var instances = ~vstManager.getGroupInstances(groupName);
    var hasActive = false;
    
    instances.do { |instance|
        var vstKey = instance.name.asSymbol;
        if(~bendSynths[vstKey].notNil || ~exprSynths[vstKey].notNil) {
            hasActive = true;
        };
    };
    
    hasActive;
};

// Debug function to print envelope states
~printEnvelopeStates = {
    "=== Active Envelope States ===".postln;
    "Bend Synths:".postln;
    ~bendSynths.keysValuesDo { |key, synth|
        if(synth.notNil) {
            ("  " ++ key ++ ": active").postln;
        };
    };
    
    "Expression Synths:".postln;
    ~exprSynths.keysValuesDo { |key, synth|
        if(synth.notNil) {
            ("  " ++ key ++ ": active").postln;
        };
    };
    
    "Group Parameters:".postln;
    ~groupEnvelopeParams.keysValuesDo { |group, params|
        ("  " ++ group ++ ": bend=" ++ params.bendPercent ++ 
         "%, expr=" ++ params.exprLevel).postln;
    };
};

"Core Functions loaded".postln;
)