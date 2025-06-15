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
    var vst;

    // Periodic Logging for /bend OSC
    if(~bendLogCounter.isNil) { ~bendLogCounter = 0 };
    ~bendLogCounter = (~bendLogCounter + 1);
    if((~bendLogCounter % 50 == 1) || (bendValue != 8192) ) { // Log frequently if bend is active
         ["[/bend OSC]: VST Index:", chanIndex, "BendVal:", bendValue].postln;
    };

    // Get VST controller using the new VSTManager system
    vst = ~getVSTByChannel.(chanIndex);

    // *** DEBUG VST VARIABLE ***
    "VST lookup result for chanIndex %: %".format(chanIndex, vst).postln;
    "VST is nil: %".format(vst.isNil).postln;
    "VST is notNil: %".format(vst.notNil).postln;

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

// OSC responder for expression control - MVP VERSION (send to all VSTs)
~expressionFuncLayer1.free;
~expressionFuncLayer1 = OSCFunc({ |msg|
    var replyID = msg[2];
    var chanIndex = msg[3].asInteger;
    var ccNum = msg[4].asInteger;
    var exprValue = msg[5].asInteger.clip(0, 127);
    var targetGroup = ~activeVSTGroup; // nil means all instances
    var instances = ~vstManager.getTargetInstances(targetGroup);

    instances.values.do { |vst|
        vst.midi.control(0, ccNum, exprValue);
    };

    "[Layer1] Sent CC% value % to % VSTs (group: %)%".format(
        ccNum, exprValue, instances.size, targetGroup ? "ALL"
    ).postln;
}, '/expression', s.addr);

// OSC responder for expression control - MVP VERSION (send to all VSTs)
~expressionFuncLayer2.free;
~expressionFuncLayer2 = OSCFunc({ |msg|
    var replyID = msg[2];
    var chanIndex = msg[3].asInteger;
    var ccNum = msg[4].asInteger;
    var exprValue = msg[5].asInteger.clip(0, 127);
    var targetGroup = ~activeVSTGroup_2; // nil => all instances
    var instances = ~vstManager.getTargetInstances(targetGroup);

    instances.values.do { |vst|
        vst.midi.control(0, ccNum, exprValue);
    };

    "[Layer2] Sent CC% value % to % VSTs (group: %)%".format(
        ccNum, exprValue, instances.size, targetGroup ? "ALL"
    ).postln;
}, '/expression2', s.addr);
