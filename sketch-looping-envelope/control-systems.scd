// Control Systems - Enhanced for Looping Envelopes
// MIDI control mapping and parameter management

(
// Control state
~controlState = (
    sliderValues: Array.fill(8, 64), // Default to center
    knobValues: Array.fill(8, 64),
    buttonStates: Array.fill(8, false),
    lastUpdateTime: 0
);

// Slider mapping for envelopes
~sliderMappings = (
    // Sliders 0-5: Group-specific controls
    0: { |val| ~updateGroupBendPercent.value(\Strings, val) },
    1: { |val| ~updateGroupBendDuration.value(\Strings, val) },
    2: { |val| ~updateGroupBendPercent.value(\Winds, val) },
    3: { |val| ~updateGroupBendDuration.value(\Winds, val) },
    4: { |val| ~updateGroupBendPercent.value(\Brass, val) },
    5: { |val| ~updateGroupBendDuration.value(\Brass, val) },
    
    // Sliders 6-7: Global expression controls
    6: { |val| ~updateGlobalExpressionLevel.value(val) },
    7: { |val| ~updateGlobalExpressionDuration.value(val) }
);

// Update group bend percentage
~updateGroupBendPercent = { |groupName, midiVal|
    var percent = midiVal.linlin(0, 127, 0, 100);
    var params = ~groupEnvelopeParams[groupName];
    
    if(params.isNil) {
        params = ~defaultEnvelopeParams.deepCopy;
        ~groupEnvelopeParams[groupName] = params;
    };
    
    params.bendPercent = percent;
    ~applyEnvelopeToTarget.value(groupName, params);
    
    ("Updated " ++ groupName ++ " bend: " ++ percent.round(0.1) ++ "%").postln;
};

// Update group bend duration
~updateGroupBendDuration = { |groupName, midiVal|
    var duration = midiVal.linlin(0, 127, 0.5, 15.0);
    var params = ~groupEnvelopeParams[groupName];
    
    if(params.isNil) {
        params = ~defaultEnvelopeParams.deepCopy;
        ~groupEnvelopeParams[groupName] = params;
    };
    
    params.bendDuration = duration;
    ~applyEnvelopeToTarget.value(groupName, params);
    
    ("Updated " ++ groupName ++ " bend duration: " ++ duration.round(0.1) ++ "s").postln;
};

// Update global expression level
~updateGlobalExpressionLevel = { |midiVal|
    var level = midiVal.linlin(0, 127, 0, 127);
    
    // Update all groups
    [\Strings, \Winds, \Brass].do { |groupName|
        var params = ~groupEnvelopeParams[groupName];
        if(params.notNil) {
            params.exprLevel = level;
            ~applyEnvelopeToTarget.value(groupName, params);
        };
    };
    
    ("Updated global expression level: " ++ level).postln;
};

// Update global expression duration
~updateGlobalExpressionDuration = { |midiVal|
    var duration = midiVal.linlin(0, 127, 0.1, 5.0);
    
    // Update all groups
    [\Strings, \Winds, \Brass].do { |groupName|
        var params = ~groupEnvelopeParams[groupName];
        if(params.notNil) {
            params.exprDuration = duration;
            ~applyEnvelopeToTarget.value(groupName, params);
        };
    };
    
    ("Updated global expression duration: " ++ duration.round(0.1) ++ "s").postln;
};

// Initialize MIDI handlers for envelope control
~initEnvelopeControlHandlers = {
    // Slider handlers
    8.do { |i|
        MIDIFunc.cc({ |val, ccNum, chan, src|
            ~controlState.sliderValues[i] = val;
            ~controlState.lastUpdateTime = SystemClock.seconds;
            
            // Execute mapping function if it exists
            if(~sliderMappings[i].notNil) {
                ~sliderMappings[i].value(val);
            };
        }, i, 0); // CC 0-7 on channel 1
    };
    
    // Knob handlers for envelope curves and additional parameters
    8.do { |i|
        MIDIFunc.cc({ |val, ccNum, chan, src|
            ~controlState.knobValues[i] = val;
            
            // Knob mappings
            switch(i,
                0, { ~updateEnvelopeCurve.value(\Strings, \bend, val) },
                1, { ~updateEnvelopeCurve.value(\Strings, \expr, val) },
                2, { ~updateEnvelopeCurve.value(\Winds, \bend, val) },
                3, { ~updateEnvelopeCurve.value(\Winds, \expr, val) },
                4, { ~updateEnvelopeCurve.value(\Brass, \bend, val) },
                5, { ~updateEnvelopeCurve.value(\Brass, \expr, val) },
                6, { ~updateTimeOffset.value(val) },
                7, { ~updateLoopEnabled.value(val) }
            );
        }, i + 16, 0); // CC 16-23 on channel 1
    };
    
    "Envelope control handlers initialized".postln;
};

// Update envelope curve type
~updateEnvelopeCurve = { |groupName, envType, midiVal|
    var curves = [\lin, \sin, \exp, \cub];
    var curveIndex = (midiVal * curves.size / 128).floor.clip(0, curves.size - 1);
    var curve = curves[curveIndex];
    var params = ~groupEnvelopeParams[groupName];
    
    if(params.notNil) {
        if(envType == \bend) {
            params.bendCurve = curve;
        } {
            params.exprCurve = curve;
        };
        
        ("Updated " ++ groupName ++ " " ++ envType ++ " curve: " ++ curve).postln;
    };
};

// Update time offset for staggering
~updateTimeOffset = { |midiVal|
    var offset = midiVal.linlin(0, 127, 0, 2.0);
    ~defaultEnvelopeParams.timeOffset = offset;
    ("Updated default time offset: " ++ offset.round(0.01) ++ "s").postln;
};

// Toggle loop enabled
~updateLoopEnabled = { |midiVal|
    var enabled = midiVal > 64;
    ~defaultEnvelopeParams.loopEnabled = enabled;
    ("Looping " ++ if(enabled) { "enabled" } { "disabled" }).postln;
};

// Performance control mappings
~performanceControls = (
    // Play/Stop
    play: { ~startPerformance.value() },
    stop: { ~stopPerformance.value() },
    
    // Target cycling
    cycleTarget: { ~cycleTarget.value() },
    
    // Development control
    nextDevelopment: { ~nextDevelopment.value() },
    
    // Envelope presets
    loadEnvelopePreset: { |presetName|
        ~loadEnvelopePreset.value(presetName);
    },
    
    saveEnvelopePreset: { |presetName|
        ~saveEnvelopePreset.value(presetName);
    }
);

// Save current envelope settings as preset
~saveEnvelopePreset = { |name|
    var preset, path;
    preset = (
        groups: Dictionary.new,
        defaults: ~defaultEnvelopeParams.deepCopy,
        timestamp: Date.localtime.stamp
    );
    
    ~groupEnvelopeParams.keysValuesDo { |groupName, params|
        preset.groups[groupName] = params.deepCopy;
    };
    
    // Save to file
    path = Platform.userAppSupportDir +/+ "SuperCollider/EnvelopePresets" +/+ name ++ ".scd";
    preset.writeArchive(path);
    
    ("Saved envelope preset: " ++ name).postln;
};

// Load envelope preset
~loadEnvelopePreset = { |name|
    var path;
    path = Platform.userAppSupportDir +/+ "SuperCollider/EnvelopePresets" +/+ name ++ ".scd";
    
    if(File.exists(path)) {
        var preset;
        preset = Object.readArchive(path);
        
        ~defaultEnvelopeParams = preset.defaults;
        preset.groups.keysValuesDo { |groupName, params|
            ~groupEnvelopeParams[groupName] = params;
        };
        
        // Apply to active envelopes
        ~vstManager.getGroupNames.do { |groupName|
            ~applyEnvelopeToTarget.value(groupName, ~groupEnvelopeParams[groupName]);
        };
        
        ("Loaded envelope preset: " ++ name).postln;
    } {
        ("Preset not found: " ++ name).warn;
    };
};

// Get current control state for display
~getControlState = {
    var state = ~controlState.deepCopy;
    
    // Add interpreted values
    state.interpretedValues = (
        stringsBend: ~controlState.sliderValues[0].linlin(0, 127, 0, 100),
        stringsBendDur: ~controlState.sliderValues[1].linlin(0, 127, 0.5, 15.0),
        windsBend: ~controlState.sliderValues[2].linlin(0, 127, 0, 100),
        windsBendDur: ~controlState.sliderValues[3].linlin(0, 127, 0.5, 15.0),
        brassBend: ~controlState.sliderValues[4].linlin(0, 127, 0, 100),
        brassBendDur: ~controlState.sliderValues[5].linlin(0, 127, 0.5, 15.0),
        globalExpr: ~controlState.sliderValues[6],
        globalExprDur: ~controlState.sliderValues[7].linlin(0, 127, 0.1, 5.0)
    );
    
    state;
};

// Initialize control system
~initEnvelopeControlHandlers.value();

"Control Systems loaded".postln;
)