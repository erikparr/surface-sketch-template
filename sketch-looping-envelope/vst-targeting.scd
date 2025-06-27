// VST Targeting System - Adapted for Looping Envelopes
// Manages which VSTs receive envelope control

(
// Current targeting state
~currentTarget = \All;
~layer2Target = nil;
~targetingMode = \single; // \single, \dual, \alternate

// Set the current target for layer 1
~setTarget = { |target|
    ~currentTarget = target;
    ("Layer 1 target set to: " ++ target).postln;
    
    // Update any active envelopes for the new target
    if(~isPlaying) {
        ~updateTargetEnvelopes.value();
    };
};

// Set target for layer 2 (dual layer mode)
~setLayer2Target = { |target|
    ~layer2Target = target;
    ("Layer 2 target set to: " ++ target).postln;
};

// Update envelopes based on current targeting
~updateTargetEnvelopes = {
    var targetInstances = ~vstManager.getTargetInstances(~currentTarget);
    
    // Stop envelopes for non-targeted VSTs
    ~vstManager.getInstances.keysValuesDo { |name, controller|
        var vstKey = name.asSymbol;
        
        if(targetInstances[name].isNil) {
            // This VST is not in the target group
            if(~bendSynths[vstKey].notNil) {
                ~bendSynths[vstKey].free;
                ~bendSynths[vstKey] = nil;
            };
            if(~exprSynths[vstKey].notNil) {
                ~exprSynths[vstKey].free;
                ~exprSynths[vstKey] = nil;
            };
        };
    };
};

// Get instances for current target with envelope consideration
~getTargetInstancesWithEnvelopes = { |layerNum = 1|
    var target = if(layerNum == 2) { ~layer2Target } { ~currentTarget };
    var instances = ~vstManager.getTargetInstances(target);
    
    // Filter to only include instances that should have envelopes
    instances.select { |controller, name|
        var groupName = ~getGroupFromVST.value(name);
        var params = ~groupEnvelopeParams[groupName];
        
        controller.notNil && 
        controller.isOpen && 
        (params.notNil && params.loopEnabled)
    };
};

// Target a specific group with envelope activation
~targetGroupWithEnvelopes = { |groupName|
    ~setTarget.value(groupName);
    
    // Start envelopes for this group if playing
    if(~isPlaying) {
        ~startGroupEnvelopes.value(groupName);
    };
};

// Cycle through available targets
~cycleTarget = {
    var groups = ~vstManager.getGroupNames;
    var allTargets = [\All] ++ groups;
    var currentIndex = allTargets.indexOf(~currentTarget) ? 0;
    var nextIndex = (currentIndex + 1) % allTargets.size;
    
    ~setTarget.value(allTargets[nextIndex]);
};

// Set targeting mode
~setTargetingMode = { |mode|
    ~targetingMode = mode;
    
    switch(mode,
        \single, {
            ~layer2Target = nil;
            "Single layer targeting mode".postln;
        },
        \dual, {
            if(~layer2Target.isNil) {
                ~layer2Target = ~currentTarget; // Default to same as layer 1
            };
            "Dual layer targeting mode".postln;
        },
        \alternate, {
            "Alternating layer targeting mode".postln;
        }
    );
};

// Get display info for current targeting
~getTargetingInfo = {
    var info = ();
    info.layer1 = ~currentTarget;
    info.layer2 = ~layer2Target;
    info.mode = ~targetingMode;
    
    // Add instance counts
    info.layer1Count = ~vstManager.getTargetInstances(~currentTarget).size;
    if(~layer2Target.notNil) {
        info.layer2Count = ~vstManager.getTargetInstances(~layer2Target).size;
    };
    
    // Add envelope status
    info.layer1EnvelopesActive = ~groupHasActiveEnvelopes.value(~currentTarget);
    if(~layer2Target.notNil) {
        info.layer2EnvelopesActive = ~groupHasActiveEnvelopes.value(~layer2Target);
    };
    
    info;
};

// Apply envelope parameters to targeted instances
~applyEnvelopeToTarget = { |target, params|
    var instances = ~vstManager.getTargetInstances(target);
    
    instances.keysValuesDo { |name, controller|
        var vstKey = name.asSymbol;
        var bendSynth = ~bendSynths[vstKey];
        var exprSynth = ~exprSynths[vstKey];
        
        // Update existing synths
        if(bendSynth.notNil && params.notNil) {
            var bendValue = ~calcBendPercent.value(params.bendPercent);
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

// Quick target presets
~targetPresets = (
    strings: { ~setTarget.value(\Strings) },
    winds: { ~setTarget.value(\Winds) },
    brass: { ~setTarget.value(\Brass) },
    all: { ~setTarget.value(\All) },
    
    // Dual layer presets
    stringsAndWinds: {
        ~setTargetingMode.value(\dual);
        ~setTarget.value(\Strings);
        ~setLayer2Target.value(\Winds);
    },
    
    brassAndStrings: {
        ~setTargetingMode.value(\dual);
        ~setTarget.value(\Brass);
        ~setLayer2Target.value(\Strings);
    }
);

"VST Targeting System loaded".postln;
)