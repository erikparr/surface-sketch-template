/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║            TEST SCRIPT: MIDI & Chord Group Integration                       ║
║            Tests the fixed dynamic layers MIDI and chord routing             ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// Wait for system to initialize
{
    var testGroup, chordGroup;

    "".postln;
    "╔═══════════════════════════════════════════════════════════════╗".postln;
    "║     MIDI & Chord Group Integration Test Suite                ║".postln;
    "╚═══════════════════════════════════════════════════════════════╝".postln;
    "".postln;

    // ═══════════════════════════════════════════════════════════════
    // TEST 1: Verify Dynamic Layers System
    // ═══════════════════════════════════════════════════════════════
    "TEST 1: Dynamic Layers System Status".postln;
    "──────────────────────────────────────────────────────────────".postln;

    if (~oscLayers.dynamicConfigs.size > 0) {
        "✓ Dynamic layers initialized: % groups".format(~oscLayers.dynamicConfigs.size).postln;

        ~oscLayers.dynamicConfigs.keysValuesDo { |groupName, config|
            var rowNum = ~getMIDIRowForGroup.(groupName);
            "  - %: type=%, row=%, CC=%".format(
                groupName,
                config.groupType,
                rowNum,
                config.expressionCC
            ).postln;
        };
    } {
        "✗ FAIL: No dynamic layers found".error;
        ^nil;
    };

    "".postln;

    // ═══════════════════════════════════════════════════════════════
    // TEST 2: ParameterRegistry Integration
    // ═══════════════════════════════════════════════════════════════
    "TEST 2: ParameterRegistry Integration".postln;
    "──────────────────────────────────────────────────────────────".postln;

    if (~paramRegistry.notNil) {
        var paramCount = ~paramRegistry.getParameterIDs().size;
        "✓ ParameterRegistry initialized: % parameters".format(paramCount).postln;

        // List some registered parameters
        testGroup = ~oscLayers.dynamicConfigs.keys.asArray.sort.first;
        ["expressionMin", "expressionMax", "expressionDurationScalar", "noteDurationScalar"].do { |paramName|
            var paramId = ("group_" ++ testGroup ++ "_" ++ paramName).asSymbol;
            var value = ~paramRegistry.getParameterValue(paramId);
            "  - %: %".format(paramName, value.round(0.001)).postln;
        };
    } {
        "✗ FAIL: ParameterRegistry not initialized".error;
    };

    "".postln;

    // ═══════════════════════════════════════════════════════════════
    // TEST 3: MIDI Controller Integration
    // ═══════════════════════════════════════════════════════════════
    "TEST 3: MIDI Controller Integration".postln;
    "──────────────────────────────────────────────────────────────".postln;

    if (~midiController.notNil) {
        "✓ MIDI controller available".postln;

        // Read current knob values for first group
        testGroup = ~oscLayers.dynamicConfigs.keys.asArray.sort.first;
        var rowNum = ~getMIDIRowForGroup.(testGroup);

        "  Row % knob values for group %:".format(rowNum, testGroup).postln;
        "    Knob 2 (note duration): %".format(~midiController.getKnobRow(rowNum, 2).round(1)).postln;
        "    Knob 4 (expr duration): %".format(~midiController.getKnobRow(rowNum, 4).round(1)).postln;
        "    Knob 5 (expr min): %".format(~midiController.getKnobRow(rowNum, 5).round(1)).postln;
        "    Knob 6 (expr max): %".format(~midiController.getKnobRow(rowNum, 6).round(1)).postln;

        // Trigger manual update
        "".postln;
        "  Testing manual parameter update...".postln;
        ~updateLayerExpressionParams.(testGroup);
        ~updateLayerNoteDurationScalar.(testGroup);
        "  ✓ Parameters updated from MIDI".postln;
    } {
        "✗ WARN: MIDI controller not available".warn;
    };

    "".postln;

    // ═══════════════════════════════════════════════════════════════
    // TEST 4: Chord Group Type Detection
    // ═══════════════════════════════════════════════════════════════
    "TEST 4: Chord Group Type Detection".postln;
    "──────────────────────────────────────────────────────────────".postln;

    if (~vstManager.notNil) {
        var chordGroups = ~vstManager.getChordGroupNames();
        var regularGroups = ~vstManager.getRegularGroupNames();

        "✓ VSTManager group types:".postln;
        "  Chord groups: % - %".format(chordGroups.size, chordGroups).postln;
        "  Regular groups: % - %".format(regularGroups.size, regularGroups).postln;

        // Verify dynamic configs have correct type
        "".postln;
        "  Verifying dynamic layer types:".postln;
        ~oscLayers.dynamicConfigs.keysValuesDo { |groupName, config|
            var vstManagerType = ~vstManager.getGroupType(groupName);
            var layerType = config.groupType;

            if (vstManagerType == layerType) {
                "    ✓ %: % (matches VSTManager)".format(groupName, layerType).postln;
            } {
                "    ✗ %: layer=%, vstManager=%".format(groupName, layerType, vstManagerType).error;
            };
        };
    } {
        "✗ FAIL: VSTManager not available".error;
    };

    "".postln;

    // ═══════════════════════════════════════════════════════════════
    // TEST 5: Expression Envelope with MIDI Values
    // ═══════════════════════════════════════════════════════════════
    "TEST 5: Expression Envelope Test".postln;
    "──────────────────────────────────────────────────────────────".postln;

    testGroup = ~oscLayers.dynamicConfigs.keys.asArray.sort.first;
    if (testGroup.notNil) {
        var config = ~oscLayers.dynamicConfigs[testGroup];
        var sanitizedName = config.sanitizedName;

        "Testing expression envelope on group: %".format(testGroup).postln;
        "  Current expression parameters:".postln;
        "    Min: %".format(config.ccControl.expressionMin).postln;
        "    Max: %".format(config.ccControl.expressionMax).postln;
        "    Duration scalar: %".format(config.ccControl.expressionDurationScalar.round(0.01)).postln;

        "".postln;
        "  Triggering 2-second expression envelope...".postln;
        NetAddr.localAddr.sendMsg('/group/' ++ sanitizedName ++ '/expression', 2.0);
        "  ✓ Expression envelope sent (listen for CC % modulation)".format(config.expressionCC).postln;
    } {
        "✗ FAIL: No groups available for testing".error;
    };

    "".postln;

    // ═══════════════════════════════════════════════════════════════
    // TEST 6: Chord Group Note Routing
    // ═══════════════════════════════════════════════════════════════
    "TEST 6: Chord Group Note Routing".postln;
    "──────────────────────────────────────────────────────────────".postln;

    chordGroup = ~vstManager.getChordGroupNames().first;
    if (chordGroup.notNil) {
        var config = ~oscLayers.dynamicConfigs[chordGroup];
        var sanitizedName = config.sanitizedName;
        var instances = ~vstManager.getTargetInstances(chordGroup);

        "Testing chord group: %".format(chordGroup).postln;
        "  Type: %".format(config.groupType).postln;
        "  VSTs: %".format(instances.size).postln;

        "".postln;
        "  Sending 3-note arpeggio (should route to different VSTs)...".postln;

        [48, 52, 55].do { |note, i|
            SystemClock.sched(i * 0.5, {
                NetAddr.localAddr.sendMsg('/group/' ++ sanitizedName ++ '/note', note, 100, 0.4);
                "    Note % → VST %".format(note, i % instances.size).postln;
            });
        };

        "  ✓ Notes sent (listen for distinct timbres on each note)".postln;
    } {
        "⚠ SKIP: No chord groups available for testing".postln;
    };

    "".postln;

    // ═══════════════════════════════════════════════════════════════
    // TEST 7: Regular Group Note Routing
    // ═══════════════════════════════════════════════════════════════
    "TEST 7: Regular Group Note Routing".postln;
    "──────────────────────────────────────────────────────────────".postln;

    testGroup = ~vstManager.getRegularGroupNames().first;
    if (testGroup.notNil) {
        var config = ~oscLayers.dynamicConfigs[testGroup];
        var sanitizedName = config.sanitizedName;
        var instances = ~vstManager.getTargetInstances(testGroup);

        "Testing regular group: %".format(testGroup).postln;
        "  Type: %".format(config.groupType).postln;
        "  VSTs: %".format(instances.size).postln;

        "".postln;
        "  Sending single note (should broadcast to ALL VSTs)...".postln;

        SystemClock.sched(0.5, {
            NetAddr.localAddr.sendMsg('/group/' ++ sanitizedName ++ '/note', 60, 100, 0.5);
            "  ✓ Note sent (should hear all % VSTs playing)".format(instances.size).postln;
        });
    } {
        "⚠ SKIP: No regular groups available for testing".postln;
    };

    "".postln;

    // ═══════════════════════════════════════════════════════════════
    // SUMMARY
    // ═══════════════════════════════════════════════════════════════
    3.wait;  // Wait for audio tests to complete
    "".postln;
    "╔═══════════════════════════════════════════════════════════════╗".postln;
    "║                      TEST SUITE COMPLETE                      ║".postln;
    "╚═══════════════════════════════════════════════════════════════╝".postln;
    "".postln;
    "MANUAL VERIFICATION STEPS:".postln;
    "1. Change MIDI knobs on Row 1 - parameters should auto-update".postln;
    "2. Trigger expression again - should use new MIDI values".postln;
    "3. For chord groups: Notes should sound on different VSTs".postln;
    "4. For regular groups: Same note should sound on all VSTs".postln;
    "".postln;
    "Use ~paramRegistry.printState to see all parameter mappings".postln;
    "".postln;

}.fork;
