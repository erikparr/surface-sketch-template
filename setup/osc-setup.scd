~oscFunc.free;
~expressionFunc.free;
~triggerResponder.free;

// Helper function to get VST controller by channel index
~getVSTByChannel = { |chanIndex|
    var instances, vstArray, vstNames, vst;

    if(~vstManager.isNil) {
        "VSTManager not available".warn;
        ^nil;
    };

    instances = ~vstManager.getInstances();
    if(instances.isNil or: { instances.size == 0 }) {
        "No VST instances available".warn;
        ^nil;
    };

    // Get VST names in a consistent order for reliable channel mapping
    // Use the group order if available, otherwise use alphabetical order
    if(~vstManager.groups.notNil && ~vstManager.groups['allVSTs'].notNil) {
        vstNames = ~vstManager.groups['allVSTs'];
    } {
        vstNames = instances.keys.asArray.sort;
    };

    if(chanIndex >= vstNames.size) {
        "Channel index % out of range (max: %)".format(chanIndex, vstNames.size - 1).warn;
        ^nil;
    };

    vst = instances[vstNames[chanIndex]];
    if(vst.isNil) {
        "VST not found for channel % (name: %)".format(chanIndex, vstNames[chanIndex]).warn;
    };

    ^vst;
};

// OSC Function for pitch bend with VSTManager integration
~oscFunc = OSCFunc({ |msg|
    var replyID = msg[2];
    var chanIndex = msg[3].asInteger; // This is the VST index (0, 1, 2...)
    var bendValue = msg[4].asInteger;
    var vst, targetGroupName, instances;

    // Periodic Logging for /bend OSC
    if(~bendLogCounter.isNil) { ~bendLogCounter = 0 };
    ~bendLogCounter = (~bendLogCounter + 1);
    if((~bendLogCounter % 50 == 1) || (bendValue != 8192) ) { // Log frequently if bend is active
         ["[/bend OSC]: VST Index:", chanIndex, "BendVal:", bendValue].postln;
    };

    // NEW: Layer-encoded replyID routing (replyID >= 100)
    if(replyID >= 100 and: { ~layers.notNil } and: { ~layers.configs.notNil }) {
        var layerNum = (replyID / 100).floor.asInteger;  // Ensure integer
        var vstIndex = replyID % 100;
        var layerKey = ('layer' ++ layerNum).asSymbol;
        var config = ~layers.configs[layerKey];
        var targetGroup = if(config.notNil) { config.vstGroup } { nil };

        if(targetGroup.notNil) {
            instances = ~vstManager.getTargetInstances(targetGroup);
            if(instances.notNil and: { instances.size > 0 }) {
                var vstKeys = instances.keys.asArray.sort;
                if(vstIndex < vstKeys.size) {
                    var vstKey = vstKeys[vstIndex];
                    var targetVst = instances[vstKey];

                    if(targetVst.notNil and: { bendValue.inclusivelyBetween(0, 16383) }) {
                        targetVst.midi.bend(0, bendValue);

                        // Reduced logging for layer-encoded messages
                        if((~bendLogCounter % 100 == 1) || (bendValue != 8192)) {
                            ["[/bend LAYER]: Layer% VST% (%): %".format(layerNum, vstIndex, vstKey, bendValue)].postln;
                        };
                    };
                };
                ^nil; // Exit early - we've handled the layer-encoded message
            };
        };
    };

    // EXISTING: Map chanIndex to layer VST groups for layers system compatibility
    if(~layers.notNil and: { ~layers.configs.notNil }) {
        // Layer system is active - use layer VST groups
        targetGroupName = switch(chanIndex,
            0, { ~layers.configs[\layer1].vstGroup },
            1, { ~layers.configs[\layer2].vstGroup },
            2, { ~layers.configs[\layer3].vstGroup },
            { nil } // Fallback
        );

        if(targetGroupName.notNil) {
            instances = ~vstManager.getTargetInstances(targetGroupName);
            if(instances.notNil and: { instances.size > 0 }) {
                if((~bendLogCounter % 50 == 1) || (bendValue != 8192) ) {
                    ["[/bend OSC]: Routing to layer VST group:", targetGroupName, "instances:", instances.size].postln;
                };

                instances.values.do { |vst|
                    if(vst.notNil && (bendValue >= 0) && (bendValue <= 16383)) {
                        vst.midi.bend(0, bendValue); // Send to all VSTs in the group
                    };
                };
                ^nil; // Exit early - we've handled the message
            };
        };
    };

    // FALLBACK: Original single VST lookup for backwards compatibility
    vst = ~getVSTByChannel.(chanIndex);

    if(vst.notNil && (bendValue >= 0) && (bendValue <= 16383)) {
        // Send bend on MIDI Channel 0, not chanIndex
        if((~bendLogCounter % 50 == 1) || (bendValue != 8192) ) {
            [" -> Applying bend to VST index", chanIndex, "on MIDI Chan 0"].postln;
        };
        vst.midi.bend(0, bendValue); // Use MIDI channel 0
    } {
        if(vst.isNil) {
            "Error: VST not found for channel index %".format(chanIndex).postln;
        } {
            "Error: Invalid bend value: %".format(bendValue).postln;
        };
    };
}, '/bend', s.addr);

// OSC responder for expression control - Layer 1
~expressionFuncLayer1.free;
~expressionFuncLayer1 = OSCFunc({ |msg|
    var replyID = msg[2];
    var chanIndex = msg[3].asInteger;
    var ccNum = msg[4].asInteger;
    var exprValue = msg[5].asInteger.clip(0, 127);
    var targetGroup = if(~layers.notNil && ~layers.configs.notNil && ~layers.configs[\layer1].notNil, { 
        ~layers.configs[\layer1].vstGroup 
    }, { 
        ~activeVSTGroup  // Fallback to sketch system's global variable
    });
    var instances = ~vstManager.getTargetInstances(targetGroup);

    instances.values.do { |vst|
        vst.midi.control(0, ccNum, exprValue);
    };
}, '/expression1', s.addr);

// Keep backward compatibility OSC responder for /expression
~expressionFunc.free;
~expressionFunc = OSCFunc({ |msg|
    var replyID = msg[2];
    var chanIndex = msg[3].asInteger;
    var ccNum = msg[4].asInteger;
    var exprValue = msg[5].asInteger.clip(0, 127);
    var targetGroup = ~activeVSTGroup; // nil means all instances
    var instances = ~vstManager.getTargetInstances(targetGroup);

    instances.values.do { |vst|
        vst.midi.control(0, ccNum, exprValue);
    };
}, '/expression', s.addr);

// OSC responder for expression control - Layer 2
~expressionFuncLayer2.free;
~expressionFuncLayer2 = OSCFunc({ |msg|
    var replyID = msg[2];
    var chanIndex = msg[3].asInteger;
    var ccNum = msg[4].asInteger;
    var exprValue = msg[5].asInteger.clip(0, 127);
    var targetGroup = if(~layers.notNil && ~layers.configs.notNil && ~layers.configs[\layer2].notNil, { 
        ~layers.configs[\layer2].vstGroup 
    }, { 
        ~activeVSTGroup_2  // Fallback to sketch system's global variable
    });
    var instances = ~vstManager.getTargetInstances(targetGroup);

    instances.values.do { |vst|
        vst.midi.control(0, ccNum, exprValue);
    };
}, '/expression2', s.addr);

// OSC responder for expression control - Layer 3
~expressionFuncLayer3.free;
~expressionFuncLayer3 = OSCFunc({ |msg|
    var replyID = msg[2];
    var chanIndex = msg[3].asInteger;
    var ccNum = msg[4].asInteger;
    var exprValue = msg[5].asInteger.clip(0, 127);
    var targetGroup = if(~layers.notNil && ~layers.configs.notNil && ~layers.configs[\layer3].notNil, { 
        ~layers.configs[\layer3].vstGroup 
    }, { 
        'Layer3'  // Fallback to default Layer3 group
    });
    var instances = ~vstManager.getTargetInstances(targetGroup);
    
    // Debug logging for layer 3
    if(~layer3LogCounter.isNil) { ~layer3LogCounter = 0 };
    ~layer3LogCounter = (~layer3LogCounter + 1);
    if(~layer3LogCounter % 50 == 1) {  // Log every 50th message
        "[Layer3 Expression] Target group: %, Instances count: %, CC%: %".format(
            targetGroup, instances.size, ccNum, exprValue
        ).postln;
    };

    instances.values.do { |vst|
        vst.midi.control(0, ccNum, exprValue);
    };
}, '/expression3', s.addr);
