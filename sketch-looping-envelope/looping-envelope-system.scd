// Looping Envelope System
// Manages looping pitch bend and expression envelopes for VST instruments

(
// Initialize envelope tracking dictionaries
~bendSynths = Dictionary.new;
~exprSynths = Dictionary.new;
~envelopeGroups = Dictionary.new;

// Default envelope parameters
~defaultEnvelopeParams = (
    // Bend parameters
    bendPercent: 20,
    bendDuration: 10.0,
    bendCurve: \sin,
    
    // Expression parameters  
    exprLevel: 100,
    exprDuration: 1.0,
    exprCurve: \sin,
    
    // Common parameters
    loopEnabled: true,
    timeOffset: 0
);

// Group-specific envelope parameters
~groupEnvelopeParams = Dictionary.new;

// Initialize parameters for common groups
~groupEnvelopeParams[\Strings] = ~defaultEnvelopeParams.deepCopy;
~groupEnvelopeParams[\Winds] = ~defaultEnvelopeParams.deepCopy;
~groupEnvelopeParams[\Brass] = ~defaultEnvelopeParams.deepCopy;

// Helper function to calculate bend value from percentage
~calcBendPercent = { |percent|
    var bendRange = 8192; // 14-bit MIDI bend range
    var bendOffset = (percent / 100 * bendRange).asInteger;
    var bendValue = 8192 + bendOffset; // Center + offset
    bendValue.clip(0, 16383);
};

// Start looping envelopes for a VST instance
~startLoopingEnvelopes = { |vstName, vstController, channelIndex = 0, note = 60, velocity = 100, groupName = nil|
    var params, vstKey, existingBend, existingExpr, bendValue, bendDur;
    
    // Get parameters for the group or use defaults
    params = if(groupName.notNil) {
        ~groupEnvelopeParams[groupName] ? ~defaultEnvelopeParams
    } {
        ~defaultEnvelopeParams
    };
    
    vstKey = vstName.asSymbol;
    
    // Free any existing synths for this VST
    existingBend = ~bendSynths[vstKey];
    existingExpr = ~exprSynths[vstKey];
    
    if(existingBend.notNil) { existingBend.free };
    if(existingExpr.notNil) { existingExpr.free };
    
    // Send note on
    vstController.midi.noteOn(channelIndex, note, velocity);
    
    // Start bend envelope if enabled
    if(params.loopEnabled) {
        bendValue = ~calcBendPercent.value(params.bendPercent);
        bendDur = params.bendDuration;
        
        ~bendSynths[vstKey] = Synth(\BendEnvelopeLoop, [
            \start, 8192,         // Center
            \peak, bendValue,     // Calculated bend
            \end, 8192,           // Return to center
            \delayTime, 0,
            \peakTime, bendDur,
            \returnTime, bendDur * 0.5,
            \loopDuration, bendDur * 2,
            \chanIndex, channelIndex,
            \timeOffset, params.timeOffset,
            \peakCurve, params.bendCurve,
            \returnCurve, params.bendCurve
        ]);
        
        // Start expression envelope
        ~exprSynths[vstKey] = Synth(\ExpressionEnvelopeLoop, [
            \start, 0,
            \peak, params.exprLevel,
            \end, 0,
            \delayTime, 0,
            \attackTime, params.exprDuration,
            \releaseTime, params.exprDuration * 0.5,
            \loopDuration, params.exprDuration * 2,
            \chanIndex, channelIndex,
            \ccNum, 11,  // Expression CC
            \timeOffset, params.timeOffset * 0.5,
            \attackCurve, params.exprCurve,
            \releaseCurve, params.exprCurve
        ]);
        
        ("Started looping envelopes for " ++ vstName ++ 
         " - Bend: " ++ params.bendPercent ++ "%, " ++
         "Expr: " ++ params.exprLevel).postln;
    };
};

// Stop looping envelopes for a VST instance
~stopLoopingEnvelopes = { |vstName, vstController, channelIndex = 0, note = 60|
    var vstKey = vstName.asSymbol;
    var bendSynth = ~bendSynths[vstKey];
    var exprSynth = ~exprSynths[vstKey];
    
    // Free envelope synths
    if(bendSynth.notNil) { 
        bendSynth.free;
        ~bendSynths[vstKey] = nil;
    };
    
    if(exprSynth.notNil) { 
        exprSynth.free;
        ~exprSynths[vstKey] = nil;
    };
    
    // Send note off and reset
    if(vstController.notNil) {
        vstController.midi.noteOff(channelIndex, note, 0);
        vstController.midi.bend(channelIndex, 8192); // Reset bend to center
        vstController.midi.control(channelIndex, 11, 0); // Reset expression
    };
    
    ("Stopped looping envelopes for " ++ vstName).postln;
};

// Update envelope parameters from MIDI sliders
~updateEnvelopeParamsFromMIDI = { |groupName|
    var params, groupIndex, sliderBase;
    
    params = ~groupEnvelopeParams[groupName];
    if(params.isNil) { params = ~defaultEnvelopeParams.deepCopy };
    
    // Map sliders to parameters based on group index
    groupIndex = [\Strings, \Winds, \Brass].indexOf(groupName) ? 0;
    sliderBase = groupIndex * 2; // Each group gets 2 sliders
    
    // Slider mapping (assuming 8 sliders):
    // 0-1: Strings (bend%, duration)
    // 2-3: Winds (bend%, duration) 
    // 4-5: Brass (bend%, duration)
    // 6: Global expression level
    // 7: Global expression duration
    
    if(sliderBase < 6) {
        params.bendPercent = ~midiController.getSliderValue(sliderBase).linlin(0, 127, 0, 100);
        params.bendDuration = ~midiController.getSliderValue(sliderBase + 1).linlin(0, 127, 0.5, 15.0);
    };
    
    // Global expression controls
    params.exprLevel = ~midiController.getSliderValue(6).linlin(0, 127, 0, 127);
    params.exprDuration = ~midiController.getSliderValue(7).linlin(0, 127, 0.1, 5.0);
    
    ~groupEnvelopeParams[groupName] = params;
    
    // Update any active synths for this group
    ~updateActiveEnvelopes.value(groupName);
};

// Update active envelope synths with new parameters
~updateActiveEnvelopes = { |groupName|
    var params, instances, vstKey, bendSynth, exprSynth, bendValue;
    
    params = ~groupEnvelopeParams[groupName];
    instances = ~vstManager.getGroupInstances(groupName);
    
    instances.do { |instance|
        vstKey = instance.name.asSymbol;
        bendSynth = ~bendSynths[vstKey];
        exprSynth = ~exprSynths[vstKey];
        
        if(bendSynth.notNil && params.notNil) {
            bendValue = ~calcBendPercent.value(params.bendPercent);
            bendSynth.set(
                \peak, bendValue,
                \peakTime, params.bendDuration,
                \returnTime, params.bendDuration * 0.5,
                \loopDuration, params.bendDuration * 2
            );
        };
        
        if(exprSynth.notNil && params.notNil) {
            exprSynth.set(
                \peak, params.exprLevel,
                \attackTime, params.exprDuration,
                \releaseTime, params.exprDuration * 0.5,
                \loopDuration, params.exprDuration * 2
            );
        };
    };
};

// Routine to continuously update parameters from MIDI
~envelopeUpdateRoutine = Routine({
    inf.do {
        // Update each group's parameters
        [\Strings, \Winds, \Brass].do { |groupName|
            ~updateEnvelopeParamsFromMIDI.value(groupName);
        };
        0.1.wait; // Update at 10Hz
    };
});

// Start envelope for a group of VSTs
~startGroupEnvelopes = { |groupName|
    var instances, params, controller, channelIndex, timeOffset, instanceParams;
    
    instances = ~vstManager.getGroupInstances(groupName);
    params = ~groupEnvelopeParams[groupName] ? ~defaultEnvelopeParams;
    
    instances.do { |instance, i|
        controller = instance.controller;
        channelIndex = i % 16; // MIDI channel cycling
        timeOffset = i * 0.5; // Stagger start times
        
        // Create custom params with time offset
        instanceParams = params.deepCopy;
        instanceParams.timeOffset = timeOffset;
        
        ~startLoopingEnvelopes.value(
            instance.name,
            controller,
            channelIndex,
            60 + (i * 4), // Spread notes
            100,
            groupName
        );
    };
    
    ("Started envelopes for group: " ++ groupName).postln;
};

// Stop envelope for a group of VSTs
~stopGroupEnvelopes = { |groupName|
    var instances, controller, channelIndex;
    
    instances = ~vstManager.getGroupInstances(groupName);
    
    instances.do { |instance, i|
        controller = instance.controller;
        channelIndex = i % 16;
        
        ~stopLoopingEnvelopes.value(
            instance.name,
            controller,
            channelIndex,
            60 + (i * 4)
        );
    };
    
    ("Stopped envelopes for group: " ++ groupName).postln;
};

// Emergency stop all envelopes
~stopAllEnvelopes = {
    ~bendSynths.keysValuesDo { |key, synth|
        if(synth.notNil) { synth.free };
    };
    ~bendSynths.clear;
    
    ~exprSynths.keysValuesDo { |key, synth|
        if(synth.notNil) { synth.free };
    };
    ~exprSynths.clear;
    
    // Reset all VSTs
    ~vstManager.getInstances.keysValuesDo { |name, controller|
        16.do { |chan|
            controller.midi.allNotesOff(chan);
            controller.midi.bend(chan, 8192);
            controller.midi.control(chan, 11, 0);
        };
    };
    
    "All envelopes stopped and VSTs reset".postln;
};

"Looping Envelope System loaded".postln;
)