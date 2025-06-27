// OSC Envelope Setup
// Handles OSC communication for pitch bend and expression envelopes

(
// Free any existing OSC functions
if(~oscBendFunc.notNil) { ~oscBendFunc.free };
if(~oscExpressionFunc.notNil) { ~oscExpressionFunc.free };
if(~oscExpression2Func.notNil) { ~oscExpression2Func.free };

// Initialize log counter
~logCounter = 0;

// OSC Function for pitch bend
~oscBendFunc = OSCFunc({ |msg|
    var replyID = msg[2];
    var chanIndex = msg[3].asInteger;
    var bendValue = msg[4].asInteger;
    
    // Route to appropriate VST based on channel index
    // This will be enhanced to use proper VST targeting
    var targetInstances = ~vstManager.getTargetInstances(~currentTarget);
    
    targetInstances.keysValuesDo { |name, controller|
        if(controller.notNil && controller.isOpen) {
            controller.midi.bend(chanIndex, bendValue);
        };
    };
    
    // Debug logging (every 100 messages)
    ~logCounter = ~logCounter + 1;
    if(~logCounter % 100 == 0) {
        ("Bend OSC: chan: " ++ chanIndex ++ ", bend: " ++ bendValue).postln;
    };
}, '/bend', s.addr);

// OSC Function for expression control (layer 1)
~oscExpressionFunc = OSCFunc({ |msg|
    var replyID = msg[2];
    var chanIndex = msg[3].asInteger;
    var ccNum = msg[4].asInteger;
    var exprValue = msg[5].asInteger.clip(0, 127);
    
    // Route to layer 1 VSTs
    var targetInstances = ~vstManager.getTargetInstances(~currentTarget);
    
    targetInstances.keysValuesDo { |name, controller|
        if(controller.notNil && controller.isOpen) {
            controller.midi.control(chanIndex, ccNum, exprValue);
        };
    };
}, '/expression', s.addr);

// OSC Function for expression control (layer 2)
~oscExpression2Func = OSCFunc({ |msg|
    var replyID = msg[2];
    var chanIndex = msg[3].asInteger;
    var ccNum = msg[4].asInteger;
    var exprValue = msg[5].asInteger.clip(0, 127);
    
    // Route to layer 2 VSTs (if dual layer is active)
    if(~layer2Target.notNil) {
        var targetInstances = ~vstManager.getTargetInstances(~layer2Target);
        
        targetInstances.keysValuesDo { |name, controller|
            if(controller.notNil && controller.isOpen) {
                controller.midi.control(chanIndex, ccNum, exprValue);
            };
        };
    };
}, '/expression2', s.addr);

// Debug trigger responder for envelope events
~triggerResponder = OSCFunc({ |msg|
    var nodeID = msg[1];
    var triggerID = msg[2];
    var value = msg[3];
    
    // Bend envelope triggers (0-15)
    if(triggerID < 16) {
        ("Bend envelope started - Channel: " ++ triggerID ++ ", Value: " ++ value).postln;
    };
    
    // Expression envelope triggers (100-115)
    if((triggerID >= 100) && (triggerID < 116)) {
        var chan = triggerID - 100;
        ("Expression envelope started - Channel: " ++ chan ++ ", Value: " ++ value).postln;
    };
    
    // Debug triggers (200+)
    if(triggerID >= 200) {
        var chan = triggerID - 200;
        ("Debug - Channel: " ++ chan ++ ", Expr Value: " ++ value).postln;
    };
}, '/tr', s.addr);

// Helper function to test OSC routing
~testOSCRouting = {
    "Testing OSC routing...".postln;
    
    // Send test bend message
    s.sendMsg('/bend', 999, 0, 8192 + 2048); // 25% bend up
    
    // Send test expression message
    s.sendMsg('/expression', 999, 0, 11, 100);
    
    "Test messages sent".postln;
};

"OSC Envelope Setup loaded".postln;
)