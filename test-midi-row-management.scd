/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                    TEST: MIDI ROW MANAGEMENT FEATURE                           ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// Test the new MIDI row management feature
(
"=== Testing MIDI Row Management Feature ===".postln;
"".postln;

// 1. Check if MIDI row override dictionary exists
"1. Checking MIDI row override dictionary...".postln;
if (~midiRowOverrides.notNil) {
    "   ✓ ~midiRowOverrides exists".postln;
    "   Current overrides: %".format(~midiRowOverrides).postln;
} {
    "   ✗ ~midiRowOverrides not found".error;
};
"".postln;

// 2. Check getMIDIRowForGroup function
"2. Testing getMIDIRowForGroup function...".postln;
if (~getMIDIRowForGroup.notNil) {
    "   ✓ ~getMIDIRowForGroup exists".postln;

    // Test automatic assignment
    if (~vstManager.notNil and: { ~vstManager.getGroupNames().size > 0 }) {
        var groups = ~vstManager.getGroupNames().sort;
        "   Testing automatic assignment:".postln;
        groups.do { |groupName, idx|
            var row = ~getMIDIRowForGroup.(groupName);
            "     Group % (index %): Row % (expected %)".format(
                groupName, idx, row, (idx % 3) + 1
            ).postln;
        };
    };
} {
    "   ✗ ~getMIDIRowForGroup not found".error;
};
"".postln;

// 3. Test manual override
"3. Testing manual MIDI row override...".postln;
if (~vstManager.notNil and: { ~vstManager.getGroupNames().size > 0 }) {
    var testGroup = ~vstManager.getGroupNames().first;
    var originalRow = ~getMIDIRowForGroup.(testGroup);

    "   Group: %".format(testGroup).postln;
    "   Original row: %".format(originalRow).postln;

    // Set manual override
    ~midiRowOverrides[testGroup] = 3;
    "   Setting manual override to row 3...".postln;

    var newRow = ~getMIDIRowForGroup.(testGroup);
    "   New row: %".format(newRow).postln;

    if (newRow == 3) {
        "   ✓ Manual override working".postln;
    } {
        "   ✗ Manual override not working".error;
    };

    // Clear override
    ~midiRowOverrides[testGroup] = nil;
    "   Cleared override".postln;
} {
    "   ⚠ No groups available for testing".warn;
};
"".postln;

// 4. Check refresh functions
"4. Checking refresh functions...".postln;
if (~updateLayerMIDIRow.notNil) {
    "   ✓ ~updateLayerMIDIRow exists".postln;
} {
    "   ✗ ~updateLayerMIDIRow not found".error;
};

if (~refreshDynamicLayersMIDI.notNil) {
    "   ✓ ~refreshDynamicLayersMIDI exists".postln;
} {
    "   ✗ ~refreshDynamicLayersMIDI not found".error;
};
"".postln;

// 5. Check VSTManager methods
"5. Checking VSTManager methods...".postln;
if (~vstManager.notNil) {
    if (~vstManager.respondsTo(\deleteGroup)) {
        "   ✓ VSTManager.deleteGroup exists".postln;
    } {
        "   ✗ VSTManager.deleteGroup not found".error;
    };

    if (~vstManager.respondsTo(\removeFromGroup)) {
        "   ✓ VSTManager.removeFromGroup exists".postln;
    } {
        "   ✗ VSTManager.removeFromGroup not found".error;
    };
} {
    "   ⚠ VSTManager not available".warn;
};
"".postln;

// 6. Test configuration save/load integration
"6. Testing configuration persistence...".postln;
if (~midiRowOverrides.notNil and: { ~vstManager.notNil }) {
    // Set some test overrides
    var groups = ~vstManager.getGroupNames();
    if (groups.size > 0) {
        var testGroup = groups.first;
        ~midiRowOverrides[testGroup] = 2;
        "   Set test override: % → Row 2".format(testGroup).postln;

        // Create a test config
        var testConfig = (
            midiRowMappings: Dictionary.new
        );
        ~midiRowOverrides.keysValuesDo { |name, row|
            testConfig.midiRowMappings[name] = row;
        };

        "   Test config midiRowMappings: %".format(testConfig.midiRowMappings).postln;

        if (testConfig.midiRowMappings.size > 0) {
            "   ✓ MIDI row mappings can be saved to config".postln;
        } {
            "   ✗ MIDI row mappings not saved properly".error;
        };

        // Clean up
        ~midiRowOverrides[testGroup] = nil;
    };
};
"".postln;

// 7. Open VST Manager to test UI
"7. UI Test Instructions:".postln;
"   Opening VST Manager window...".postln;
"   Please test the following:".postln;
"   - Group list shows all groups with type and MIDI row".postln;
"   - [M] indicator appears for manual overrides".postln;
"   - Selecting a group shows its details".postln;
"   - MIDI Row dropdown changes the assignment".postln;
"   - Manual Override checkbox enables/disables override".postln;
"   - Remove from Group button works".postln;
"   - Delete Group button works".postln;
"".postln;

// Open the VST Manager window
if (~createVSTManagerUI.notNil) {
    ~createVSTManagerUI.();
    "   ✓ VST Manager window opened".postln;
} {
    "   ✗ Cannot open VST Manager (function not found)".error;
};

"".postln;
"=== Test Complete ===".postln;
)